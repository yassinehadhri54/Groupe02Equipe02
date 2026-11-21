
const { db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");

const reservationsCollection = db.collection("reservations");
const offersCollection = db.collection("offers");
const shopsCollection = db.collection("shops");

const getUserId = (user) => user?.uid || user?.userId || null;

// Create a reservation
const createReservation = async (studentId, offerId, quantity) => {
    if (!studentId || !offerId) {
        throw new Error("Student ID and offer ID are required.");
    }

    const requestedQuantity = Number(quantity);

    if (
        !Number.isInteger(requestedQuantity) ||
        requestedQuantity <= 0
    ) {
        throw new Error("Quantity must be a positive integer.");
    }

    const offerRef = offersCollection.doc(offerId);
    const reservationRef = reservationsCollection.doc();

    const reservation = await db.runTransaction(async (transaction) => {
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

       const unitPrice = Number(
    offer.discountPrice ?? offer.discountedPrice ?? offer.price
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

    return reservation;
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
    const shopsSnapshot = await shopsCollection
        .where("ownerId", "==", merchantId)
        .get();

    if (shopsSnapshot.empty) {
        return [];
    }

    const shopIds = shopsSnapshot.docs.map((doc) => doc.id);
    const reservations = [];

    // Firestore "in" queries accept a maximum of 30 values.
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

// Merchant confirms, rejects, or completes a reservation
const updateReservationStatus = async (
    merchantId,
    reservationId,
    newStatus
) => {
    const allowedStatuses = ["confirmed", "rejected", "completed"];

    if (!allowedStatuses.includes(newStatus)) {
        throw new Error("Invalid reservation status.");
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
        const shopMerchantId = shop.merchantId || shop.ownerId || shop.userId;

        if (shopMerchantId !== merchantId) {
            throw new Error("You are not allowed to update this reservation.");
        }

        if (newStatus === "confirmed") {
            if (reservation.status !== "pending") {
                throw new Error("Only pending reservations can be confirmed.");
            }

            if (reservation.paymentStatus !== "paid") {
                throw new Error("Reservation must be paid before confirmation.");
            }
        }

        if (newStatus === "rejected") {
            if (reservation.status !== "pending") {
                throw new Error("Only pending reservations can be rejected.");
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

            transaction.update(offerRef, {
                availableQuantity:
                    currentQuantity + Number(reservation.quantity),
                updatedAt: FieldValue.serverTimestamp()
            });
        }

        if (newStatus === "completed") {
            if (reservation.status !== "confirmed") {
                throw new Error(
                    "Only confirmed reservations can be completed."
                );
            }

            if (reservation.paymentStatus !== "paid") {
                throw new Error("Reservation must be paid before completion.");
            }
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
            throw new Error("You are not allowed to cancel this reservation.");
        }

        if (reservation.status !== "pending") {
            throw new Error("Only pending reservations can be cancelled.");
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

module.exports = {
    createReservation,
    getMyReservations,
    getMerchantReservations,
    updateReservationStatus,
    cancelReservation
};
