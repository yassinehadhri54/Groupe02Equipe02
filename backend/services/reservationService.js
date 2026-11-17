
const { db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");

const offersCollection = db.collection("offers");
const shopsCollection = db.collection("shops");
const reservationsCollection = db.collection("reservations");

// Create a reservation - Student
const createReservation = async (studentId, offerId, quantity) => {
    const qty = Number(quantity);

    if (!Number.isInteger(qty) || qty <= 0) {
        throw new Error("Quantity must be a positive integer.");
    }

    if (!offerId || typeof offerId !== "string") {
        throw new Error("A valid offer ID is required.");
    }

    const offerRef = offersCollection.doc(offerId);
    const reservationRef = reservationsCollection.doc();

    return db.runTransaction(async (transaction) => {
        const offerDoc = await transaction.get(offerRef);

        if (!offerDoc.exists) {
            throw new Error("Offer not found.");
        }

        const offer = offerDoc.data();
        const available = Number(offer.availableQuantity);
        const price = Number(offer.discountPrice);

        if (offer.status !== "available") {
            throw new Error("This offer is not available.");
        }

        if (!Number.isInteger(available) || available < qty) {
            throw new Error("Not enough quantity available.");
        }

        if (!Number.isFinite(price) || price <= 0) {
            throw new Error("Invalid offer price.");
        }

        if (!offer.shopId || !offer.name || !offer.shopName) {
            throw new Error("Offer information is incomplete.");
        }

        const reservation = {
            reservationId: reservationRef.id,
            studentId,
            offerId,
            shopId: offer.shopId,
            shopName: offer.shopName,
            offerName: offer.name,
            quantity: qty,
            unitPrice: price,
            totalPrice: price * qty,
            status: "pending",
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
        };

        transaction.update(offerRef, {
            availableQuantity: available - qty,
            updatedAt: FieldValue.serverTimestamp()
        });

        transaction.set(reservationRef, reservation);

        return {
            ...reservation,
            createdAt: null,
            updatedAt: null
        };
    });
};


// Get reservations of a student
const getMyReservations = async (studentId) => {
    const snapshot = await reservationsCollection
        .where("studentId", "==", studentId)
        .get();

    return snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data()
    }));
};


// Get reservations of a merchant
const getMerchantReservations = async (merchantId) => {
    const shopsSnapshot = await shopsCollection
        .where("ownerId", "==", merchantId)
        .get();

    if (shopsSnapshot.empty) {
        return [];
    }

    const results = await Promise.all(
        shopsSnapshot.docs.map(async (shopDoc) => {
            const reservationsSnapshot = await reservationsCollection
                .where("shopId", "==", shopDoc.id)
                .get();

            return reservationsSnapshot.docs.map((doc) => ({
                id: doc.id,
                ...doc.data()
            }));
        })
    );

    return results.flat().sort((a, b) => {
        const dateA = a.createdAt?.toMillis?.() || 0;
        const dateB = b.createdAt?.toMillis?.() || 0;
        return dateB - dateA;
    });
};


// Update reservation status - Merchant
const updateReservationStatus = async (
    reservationId,
    merchantId,
    newStatus
) => {
    if (!["confirmed", "rejected", "completed"].includes(newStatus)) {
        throw new Error("Invalid reservation status.");
    }

    const reservationRef = reservationsCollection.doc(reservationId);

    return db.runTransaction(async (transaction) => {
        const reservationDoc = await transaction.get(reservationRef);

        if (!reservationDoc.exists) {
            throw new Error("Reservation not found.");
        }

        const reservation = reservationDoc.data();

        if (!reservation.shopId) {
            throw new Error("Reservation has no associated shop.");
        }

        const shopRef = shopsCollection.doc(reservation.shopId);
        const shopDoc = await transaction.get(shopRef);

        if (!shopDoc.exists || shopDoc.data().ownerId !== merchantId) {
            throw new Error("You are not allowed to manage this reservation.");
        }

        let offerRef = null;
        let offerDoc = null;

        if (newStatus === "rejected") {
            offerRef = offersCollection.doc(reservation.offerId);
            offerDoc = await transaction.get(offerRef);

            if (!offerDoc.exists) {
                throw new Error("Offer not found.");
            }
        }

        if (
            ["confirmed", "rejected"].includes(newStatus) &&
            reservation.status !== "pending"
        ) {
            throw new Error("Only pending reservations can be confirmed or rejected.");
        }

        if (
            newStatus === "completed" &&
            reservation.status !== "confirmed"
        ) {
            throw new Error("Only confirmed reservations can be completed.");
        }

        // All reads are completed before writes.
        if (newStatus === "rejected") {
            const currentQuantity = Number(
                offerDoc.data().availableQuantity
            );

            if (!Number.isInteger(currentQuantity) || currentQuantity < 0) {
                throw new Error("Invalid offer quantity.");
            }

            transaction.update(offerRef, {
                availableQuantity: currentQuantity + reservation.quantity,
                updatedAt: FieldValue.serverTimestamp()
            });
        }

        transaction.update(reservationRef, {
            status: newStatus,
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            reservationId,
            status: newStatus
        };
    });
};


// Cancel reservation - Student
const cancelReservation = async (reservationId, studentId) => {
    const reservationRef = reservationsCollection.doc(reservationId);

    return db.runTransaction(async (transaction) => {
        const reservationDoc = await transaction.get(reservationRef);

        if (!reservationDoc.exists) {
            throw new Error("Reservation not found.");
        }

        const reservation = reservationDoc.data();

        if (reservation.studentId !== studentId) {
            throw new Error("You are not allowed to cancel this reservation.");
        }

        if (reservation.status !== "pending") {
            throw new Error("Only pending reservations can be cancelled.");
        }

        const offerRef = offersCollection.doc(reservation.offerId);
        const offerDoc = await transaction.get(offerRef);

        if (!offerDoc.exists) {
            throw new Error("Offer not found.");
        }

        const currentQuantity = Number(
            offerDoc.data().availableQuantity
        );

        if (!Number.isInteger(currentQuantity) || currentQuantity < 0) {
            throw new Error("Invalid offer quantity.");
        }

        // Restore reserved quantity.
        transaction.update(offerRef, {
            availableQuantity: currentQuantity + reservation.quantity,
            updatedAt: FieldValue.serverTimestamp()
        });

        transaction.update(reservationRef, {
            status: "cancelled",
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
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
