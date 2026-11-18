
const { db } = require("../config/firebase");

const offersCollection = db.collection("offers");

// Créer une offre
const createOffer = async (offerData, merchantId) => {
    const offer = {
        ...offerData,
        merchantId,
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
    const doc = await docRef.get();

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

    safeData.updatedAt = new Date().toISOString();

    await docRef.update(safeData);

    return {
        id: offerId,
        ...offer,
        ...safeData
    };
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
