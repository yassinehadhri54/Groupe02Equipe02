
const { db } = require("../config/firebase");

const offersCollection = db.collection("offers");

// Créer une offre liée automatiquement à la boutique du commerçant
const createOffer = async (offerData, merchantId) => {
    const initialQuantity = Number(offerData.quantity);

    if (
        !Number.isInteger(initialQuantity) ||
        initialQuantity <= 0
    ) {
        throw new Error("Invalid offer quantity.");
    }

    // Rechercher la boutique du commerçant
    const shopsSnapshot = await db.collection("shops")
        .where("ownerId", "==", merchantId)
        .get();

    if (shopsSnapshot.empty) {
        throw new Error("MERCHANT_SHOP_NOT_FOUND");
    }

    const shopDoc = shopsSnapshot.docs[0];
    const shop = shopDoc.data();

    // Vérifier que la boutique est approuvée
    if (shop.status !== "approved") {
        throw new Error("SHOP_NOT_APPROVED");
    }

    const offer = {
        ...offerData,
        quantity: initialQuantity,
        availableQuantity: initialQuantity,
        merchantId,
        shopId: shopDoc.id,
        shopName: shop.name,
        status: "active",
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
    };

    const docRef = await offersCollection.add(offer);

    return {
        id: docRef.id,
        ...offer
    };
};
// Récupérer toutes les offres
const getAllOffers = async () => {
    const snapshot = await offersCollection
        .orderBy("createdAt", "desc")
        .get();

    return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
    }));
};

// Récupérer les offres d'un commerçant
const getMerchantOffers = async (merchantId) => {
    const snapshot = await offersCollection
        .where("merchantId", "==", merchantId)
        .get();

    return snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data()
    }));
};

// Récupérer une offre par son identifiant
const getOfferById = async (offerId) => {
    const doc = await offersCollection.doc(offerId).get();

    if (!doc.exists) {
        return null;
    }

    return {
        id: doc.id,
        ...doc.data()
    };
};


// Modifier une offre
const updateOffer = async (offerId, merchantId, updateData) => {
    const docRef = offersCollection.doc(offerId);

    return await db.runTransaction(async (transaction) => {
        const doc = await transaction.get(docRef);

        if (!doc.exists) {
            return null;
        }

        const offer = doc.data();

        if (offer.merchantId !== merchantId) {
            throw new Error("FORBIDDEN");
        }

        const allowedFields = [
            "title",
            "description",
            "category",
            "originalPrice",
            "discountedPrice",
            "quantity",
            "imageUrl",
            "pickupStart",
            "pickupEnd",
            "address"
        ];

        const safeData = {};

        allowedFields.forEach(field => {
            if (updateData[field] !== undefined) {
                safeData[field] = updateData[field];
            }
        });

        if (safeData.quantity !== undefined) {
            const newQuantity = Number(safeData.quantity);
            const oldQuantity = Number(offer.quantity);
            const oldAvailable = Number(
                offer.availableQuantity ?? offer.quantity
            );

            if (
                !Number.isInteger(newQuantity) ||
                newQuantity <= 0
            ) {
                throw new Error("Invalid offer quantity.");
            }

            const reservedQuantity = oldQuantity - oldAvailable;

            if (
                !Number.isInteger(reservedQuantity) ||
                reservedQuantity < 0
            ) {
                throw new Error("Invalid offer stock data.");
            }

            const newAvailable = newQuantity - reservedQuantity;

            if (newAvailable < 0) {
                throw new Error(
                    "New quantity cannot be less than already reserved quantity."
                );
            }

            safeData.quantity = newQuantity;
            safeData.availableQuantity = newAvailable;
        }

        safeData.updatedAt = new Date().toISOString();

        transaction.update(docRef, safeData);

        return {
            id: offerId,
            ...offer,
            ...safeData
        };
    });
};


// Supprimer une offre
const deleteOffer = async (offerId, merchantId, isAdmin = false) => {
    const docRef = offersCollection.doc(offerId);
    const doc = await docRef.get();

    if (!doc.exists) {
        return false;
    }

    const offer = doc.data();

    if (!isAdmin && offer.merchantId !== merchantId) {
        throw new Error("FORBIDDEN");
    }

    await docRef.delete();

    return true;
};

module.exports = {
    createOffer,
    getAllOffers,
    getMerchantOffers,
    getOfferById,
    updateOffer,
    deleteOffer
};
