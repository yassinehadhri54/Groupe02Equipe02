
const { db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const crypto = require("crypto");
const QRCode = require("qrcode");
const { getOfferDiscountPrice } = require("../utils/offerFields");
const notificationService = require("./notificationService");

const reservationsCollection = db.collection("reservations");
const offersCollection = db.collection("offers");
const shopsCollection = db.collection("shops");

// Create a reservation
const createReservation = async (studentId, offerId, quantity) => {
    if (!studentId || !offerId) {
        throw new Error("Student ID and offer ID are required.");
    }

    const requestedQuantity = Number(quantity);

    if (!Number.isInteger(requestedQuantity) || requestedQuantity <= 0) {
        throw new Error("Quantity must be a positive integer.");
    }

    const offerRef = offersCollection.doc(offerId);
    const reservationRef = reservationsCollection.doc();

    return db.runTransaction(async (transaction) => {
        const offerSnapshot = await transaction.get(offerRef);

        if (!offerSnapshot.exists) {
            throw new Error("Offer not found.");
        }

        const offer = offerSnapshot.data();
        const availableQuantity = Number(offer.availableQuantity);

        if (
            !Number.isFinite(availableQuantity) ||
            availableQuantity < requestedQuantity
        ) {
            throw new Error("Not enough offer quantity available.");
        }

        // Discount price is "discountPrice" or "discountedPrice"
        // depending on who created the offer.
        const unitPrice = Number(
            getOfferDiscountPrice(offer) ?? offer.originalPrice
        );

        if (!Number.isFinite(unitPrice) || unitPrice <= 0) {
            throw new Error("Invalid offer price.");
        }

        if (!offer.shopId) {
            throw new Error("Offer is not linked to a shop.");
        }

        const shopRef = shopsCollection.doc(offer.shopId);
        const shopSnapshot = await transaction.get(shopRef);

        if (!shopSnapshot.exists) {
            throw new Error("Shop not found.");
        }

        const shop = shopSnapshot.data();

        const totalPrice = Number(
            (unitPrice * requestedQuantity).toFixed(3)
        );

        const reservationData = {
            reservationId: reservationRef.id,
            studentId,
            offerId,
            shopId: offer.shopId,
            shopName: shop.name || offer.shopName || "",
            offerName: offer.name || offer.title || offer.offerName || "",
            quantity: requestedQuantity,
            unitPrice,
            totalPrice,
            status: "pending",
            paymentStatus: "unpaid",
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
        };

        transaction.update(offerRef, {
            availableQuantity: availableQuantity - requestedQuantity,
            updatedAt: FieldValue.serverTimestamp()
        });

        transaction.set(reservationRef, reservationData);

        return {
            ...reservationData,
            reservationId: reservationRef.id
        };
    });
};


// Get reservations belonging to a student
const getMyReservations = async (studentId) => {
    const snapshot = await reservationsCollection
        .where("studentId", "==", studentId)
        .get();

    return snapshot.docs.map((doc) => ({
        ...doc.data(),
        reservationId: doc.id
    }));
};


// Get reservations belonging to shops managed by a merchant
const getMerchantReservations = async (merchantId) => {
    // Shops are created with "ownerId" (see shopService.createShop).
    // "merchantId" is also checked for older documents, matching the
    // ownership check used in updateReservationStatus / verifyReservationQR.
    const [ownerSnapshot, legacySnapshot] = await Promise.all([
        shopsCollection.where("ownerId", "==", merchantId).get(),
        shopsCollection.where("merchantId", "==", merchantId).get()
    ]);

    const shopIds = [
        ...new Set([
            ...ownerSnapshot.docs.map((doc) => doc.id),
            ...legacySnapshot.docs.map((doc) => doc.id)
        ])
    ];

    if (shopIds.length === 0) {
        return [];
    }
    const reservations = [];

    for (let i = 0; i < shopIds.length; i += 30) {
        const shopIdsBatch = shopIds.slice(i, i + 30);

        const snapshot = await reservationsCollection
            .where("shopId", "in", shopIdsBatch)
            .get();

        snapshot.docs.forEach((doc) => {
            reservations.push({
                ...doc.data(),
                reservationId: doc.id
            });
        });
    }

    return reservations;
};


// Merchant confirms or rejects a reservation.
// Completion is only allowed through QR verification.
const updateReservationStatus = async (
    merchantId,
    reservationId,
    newStatus
) => {
    const allowedStatuses = ["confirmed", "rejected"];

    if (!allowedStatuses.includes(newStatus)) {
        throw new Error(
            "Invalid reservation status. Use QR verification to complete a reservation."
        );
    }

    const reservationRef = reservationsCollection.doc(reservationId);

    return db.runTransaction(async (transaction) => {
        const reservationSnapshot = await transaction.get(reservationRef);

        if (!reservationSnapshot.exists) {
            throw new Error("Reservation not found.");
        }

        const reservation = reservationSnapshot.data();

        const shopRef = shopsCollection.doc(reservation.shopId);
        const shopSnapshot = await transaction.get(shopRef);

        if (!shopSnapshot.exists) {
            throw new Error("Shop not found.");
        }

        const shop = shopSnapshot.data();
        const shopMerchantId =
            shop.merchantId || shop.ownerId || shop.userId;

        if (shopMerchantId !== merchantId) {
            throw new Error(
                "You are not allowed to update this reservation."
            );
        }

        if (newStatus === "confirmed") {
            if (reservation.status !== "pending") {
                throw new Error(
                    "Only pending reservations can be confirmed."
                );
            }

            if (reservation.paymentStatus !== "paid") {
                throw new Error(
                    "Reservation must be paid before confirmation."
                );
            }
        }

        if (newStatus === "rejected") {
            if (reservation.status !== "pending") {
                throw new Error(
                    "Only pending reservations can be rejected."
                );
            }

            if (
                ["processing", "pending", "paid"].includes(
                    reservation.paymentStatus
                )
            ) {
                throw new Error(
                    "Cannot reject a reservation while payment is in progress or paid."
                );
            }

            const offerRef = offersCollection.doc(reservation.offerId);
            const offerSnapshot = await transaction.get(offerRef);

            if (!offerSnapshot.exists) {
                throw new Error("Offer not found.");
            }

            const offer = offerSnapshot.data();
            const currentQuantity = Number(offer.availableQuantity);

            if (!Number.isFinite(currentQuantity)) {
                throw new Error("Invalid offer quantity.");
            }

            transaction.update(offerRef, {
                availableQuantity:
                    currentQuantity + Number(reservation.quantity),
                updatedAt: FieldValue.serverTimestamp()
            });
        }

        transaction.update(reservationRef, {
            status: newStatus,
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            ...reservation,
            reservationId,
            status: newStatus
        };
    });
};


// Generate or refresh a student's QR Code.
// The raw token is returned to the student but only its hash is stored.
const generateReservationQR = async (studentId, reservationId) => {
    if (!studentId || !reservationId) {
        throw new Error("Student ID and reservation ID are required.");
    }

    const reservationRef = reservationsCollection.doc(reservationId);

    // Generate a new unpredictable token.
    const token = crypto.randomBytes(32).toString("hex");

    // Store only the SHA-256 hash.
    const tokenHash = crypto
        .createHash("sha256")
        .update(token)
        .digest("hex");

    // Convert token into a QR image.
    const qrCodeDataURL = await QRCode.toDataURL(token);

    const result = await db.runTransaction(async (transaction) => {
        const reservationSnapshot = await transaction.get(reservationRef);

        if (!reservationSnapshot.exists) {
            throw new Error("Reservation not found.");
        }

        const reservation = reservationSnapshot.data();

        if (reservation.studentId !== studentId) {
            throw new Error(
                "You are not allowed to access this reservation."
            );
        }

        if (reservation.paymentStatus !== "paid") {
            throw new Error(
                "Reservation must be paid before generating QR Code."
            );
        }

        if (
            ["cancelled", "rejected", "completed"].includes(
                reservation.status
            )
        ) {
            throw new Error(
                "QR Code cannot be generated for this reservation."
            );
        }

        transaction.update(reservationRef, {
            qr: {
                tokenHash,
                generatedAt: FieldValue.serverTimestamp(),
                usedAt: null
            },
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            reservationId,
            status: reservation.status,
            paymentStatus: reservation.paymentStatus
        };
    });

    return {
        ...result,
        qrCode: qrCodeDataURL
    };
};


// Merchant verifies the QR Code and completes the reservation.
const verifyReservationQR = async (merchantId, token) => {
    if (
        typeof token !== "string" ||
        !/^[a-f0-9]{64}$/i.test(token)
    ) {
        throw new Error("Invalid QR Code.");
    }

    const tokenHash = crypto
        .createHash("sha256")
        .update(token)
        .digest("hex");

    // Find the reservation using the stored token hash.
    const matchingReservations = await reservationsCollection
        .where("qr.tokenHash", "==", tokenHash)
        .limit(1)
        .get();

    if (matchingReservations.empty) {
        throw new Error("Invalid or expired QR Code.");
    }

    const reservationRef = matchingReservations.docs[0].ref;

    return db.runTransaction(async (transaction) => {
        const reservationSnapshot = await transaction.get(reservationRef);

        if (!reservationSnapshot.exists) {
            throw new Error("Reservation not found.");
        }

        const reservation = reservationSnapshot.data();

        // Verify token again inside the transaction.
        if (reservation.qr?.tokenHash !== tokenHash) {
            throw new Error("Invalid or expired QR Code.");
        }

        if (reservation.qr?.usedAt) {
            throw new Error("QR Code has already been used.");
        }

        if (reservation.paymentStatus !== "paid") {
            throw new Error("Reservation is not paid.");
        }

        if (reservation.status !== "confirmed") {
            throw new Error(
                "Only confirmed reservations can be completed."
            );
        }

        const shopRef = shopsCollection.doc(reservation.shopId);
        const shopSnapshot = await transaction.get(shopRef);

        if (!shopSnapshot.exists) {
            throw new Error("Shop not found.");
        }

        const shop = shopSnapshot.data();
        const shopMerchantId =
            shop.merchantId || shop.ownerId || shop.userId;

        if (shopMerchantId !== merchantId) {
            throw new Error(
                "You are not allowed to verify this reservation."
            );
        }

        // One-time QR validation and reservation completion.
        transaction.update(reservationRef, {
            status: "completed",
            "qr.usedAt": FieldValue.serverTimestamp(),
            completedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            reservationId: reservationRef.id,
            status: "completed",
            paymentStatus: "paid",
            message: "QR Code verified. Reservation completed successfully."
        };
    });
};


// Student cancels a pending reservation
const cancelReservation = async (studentId, reservationId) => {
    const reservationRef = reservationsCollection.doc(reservationId);

    return db.runTransaction(async (transaction) => {
        const reservationSnapshot = await transaction.get(reservationRef);

        if (!reservationSnapshot.exists) {
            throw new Error("Reservation not found.");
        }

        const reservation = reservationSnapshot.data();

        if (reservation.studentId !== studentId) {
            throw new Error(
                "You are not allowed to cancel this reservation."
            );
        }

        if (reservation.status !== "pending") {
            throw new Error(
                "Only pending reservations can be cancelled."
            );
        }

        if (
            ["processing", "pending", "paid"].includes(
                reservation.paymentStatus
            )
        ) {
            throw new Error(
                "Cannot cancel a reservation while payment is in progress or paid."
            );
        }

        const offerRef = offersCollection.doc(reservation.offerId);
        const offerSnapshot = await transaction.get(offerRef);

        if (!offerSnapshot.exists) {
            throw new Error("Offer not found.");
        }

        const offer = offerSnapshot.data();
        const currentQuantity = Number(offer.availableQuantity);

        if (!Number.isFinite(currentQuantity)) {
            throw new Error("Invalid offer quantity.");
        }

        transaction.update(offerRef, {
            availableQuantity:
                currentQuantity + Number(reservation.quantity),
            updatedAt: FieldValue.serverTimestamp()
        });

        transaction.update(reservationRef, {
            status: "cancelled",
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            ...reservation,
            reservationId,
            status: "cancelled"
        };
    });
};


// --------------------------------------------------
// NOTIFICATIONS
// Sent once, after the operation succeeded (never inside a transaction,
// which Firestore may retry). Failures are logged and never break the
// reservation flow. Not awaited, so responses are not delayed.
// --------------------------------------------------

const describe = (reservation) =>
    `${reservation.quantity} × ${reservation.offerName || "offre"}`;

const withCreatedNotification = async (...args) => {
    const reservation = await createReservation(...args);

    void notificationService.notifyShopOwner(reservation.shopId, {
        type: "reservation_created",
        title: "Nouvelle réservation",
        body: `${describe(reservation)} — ${reservation.totalPrice} TND`,
        data: { reservationId: reservation.reservationId }
    });

    return reservation;
};

const withStatusNotification = async (...args) => {
    const reservation = await updateReservationStatus(...args);

    const confirmed = reservation.status === "confirmed";

    void notificationService.notifyUser(reservation.studentId, {
        type: confirmed ? "reservation_confirmed" : "reservation_rejected",
        title: confirmed ? "Réservation confirmée" : "Réservation refusée",
        body: confirmed
            ? `${describe(reservation)} chez ${reservation.shopName} est confirmée. Présentez votre QR code au retrait.`
            : `${describe(reservation)} chez ${reservation.shopName} a été refusée.`,
        data: { reservationId: reservation.reservationId }
    });

    return reservation;
};

const withCancelNotification = async (...args) => {
    const reservation = await cancelReservation(...args);

    void notificationService.notifyShopOwner(reservation.shopId, {
        type: "reservation_cancelled",
        title: "Réservation annulée",
        body: `${describe(reservation)} a été annulée par l'étudiant.`,
        data: { reservationId: reservation.reservationId }
    });

    return reservation;
};

const withPickupNotification = async (...args) => {
    const result = await verifyReservationQR(...args);

    void (async () => {
        const snapshot = await reservationsCollection.doc(result.reservationId).get();

        if (!snapshot.exists) return;

        const reservation = snapshot.data();

        await notificationService.notifyUser(reservation.studentId, {
            type: "reservation_completed",
            title: "Commande récupérée",
            body: `Merci ! ${describe(reservation)} chez ${reservation.shopName} a bien été récupérée.`,
            data: { reservationId: result.reservationId }
        });
    })().catch((error) => console.error("Pickup notification error:", error.message));

    return result;
};

module.exports = {
    createReservation: withCreatedNotification,
    getMyReservations,
    getMerchantReservations,
    updateReservationStatus: withStatusNotification,
    generateReservationQR,
    verifyReservationQR: withPickupNotification,
    cancelReservation: withCancelNotification
};
