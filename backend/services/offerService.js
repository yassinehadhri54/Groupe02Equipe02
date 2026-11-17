
const { db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");

const offersCollection = db.collection("offers");
const shopsCollection = db.collection("shops");

// Vérifier que le commerçant possède une boutique approuvée
const getApprovedShop = async (uid) => {
    const snapshot = await shopsCollection
        .where("ownerId", "==", uid)
        .where("status", "==", "approved")
        .limit(1)
        .get();

    if (snapshot.empty) {
        throw new Error("You need an approved shop to publish offers.");
    }

    return {
        id: snapshot.docs[0].id,
        ...snapshot.docs[0].data()
    };
};

// Créer une offre
const createOffer = async (uid, offerData) => {
    const shop = await getApprovedShop(uid);

    const offerRef = offersCollection.doc();

    const newOffer = {
        offerId: offerRef.id,
        shopId: shop.shopId || shop.id,
        shopName: shop.name || "",
        ownerId: uid,

        name: offerData.name,
        description: offerData.description || "",
        category: offerData.category,
        originalPrice: Number(offerData.originalPrice),
        discountPrice: Number(offerData.discountPrice),
        quantity: Number(offerData.quantity),
        availableQuantity: Number(offerData.quantity),

        pickupStart: offerData.pickupStart,
        pickupEnd: offerData.pickupEnd,
        imageURL: offerData.imageURL || "",

        status: "available",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
    };

    await offerRef.set(newOffer);

    return {
        ...newOffer,
        createdAt: null,
        updatedAt: null
    };
};

// Récupérer toutes les offres disponibles
const getAllOffers = async (filters = {}) => {
    let query = offersCollection.where("status", "==", "available");

    if (filters.category) {
        query = query.where("category", "==", filters.category);
    }

    if (filters.shopId) {
        query = query.where("shopId", "==", filters.shopId);
    }

    if (filters.maxPrice !== undefined) {
        query = query.where(
            "discountPrice",
            "<=",
            Number(filters.maxPrice)
        );
    }

    const snapshot = await query.get();

    return snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data()
    }));
};

// Récupérer une offre par son ID
const getOfferById = async (offerId) => {
    const offerDoc = await offersCollection.doc(offerId).get();

    if (!offerDoc.exists) {
        return null;
    }

    return {
        id: offerDoc.id,
        ...offerDoc.data()
    };
};

// Récupérer les offres du commerçant connecté
const getMyOffers = async (uid) => {
    const snapshot = await offersCollection
        .where("ownerId", "==", uid)
        .get();

    return snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data()
    }));
};

// Modifier une offre
const updateOffer = async (uid, offerId, updateData) => {
    const offerRef = offersCollection.doc(offerId);
    const offerDoc = await offerRef.get();

    if (!offerDoc.exists) {
        throw new Error("Offer not found.");
    }

    if (offerDoc.data().ownerId !== uid) {
        throw new Error("You are not allowed to modify this offer.");
    }

    const allowedFields = [
        "name",
        "description",
        "category",
        "originalPrice",
        "discountPrice",
        "quantity",
        "pickupStart",
        "pickupEnd",
        "imageURL"
    ];

    const cleanData = {};

    for (const field of allowedFields) {
        if (updateData[field] !== undefined) {
            cleanData[field] = updateData[field];
        }
    }

    if (Object.keys(cleanData).length === 0) {
        throw new Error("No valid fields provided for update.");
    }

    const current = offerDoc.data();

    if (cleanData.originalPrice !== undefined) {
        cleanData.originalPrice = Number(cleanData.originalPrice);
    }

    if (cleanData.discountPrice !== undefined) {
        cleanData.discountPrice = Number(cleanData.discountPrice);
    }

    if (cleanData.quantity !== undefined) {
        const newQuantity = Number(cleanData.quantity);
        const alreadyReserved =
            current.quantity - current.availableQuantity;

        if (newQuantity < alreadyReserved) {
            throw new Error(
                "Quantity cannot be lower than the quantity already reserved."
            );
        }

        cleanData.quantity = newQuantity;
        cleanData.availableQuantity = newQuantity - alreadyReserved;
    }

    const finalOriginalPrice =
        cleanData.originalPrice ?? current.originalPrice;

    const finalDiscountPrice =
        cleanData.discountPrice ?? current.discountPrice;

    if (
        finalOriginalPrice <= 0 ||
        finalDiscountPrice <= 0 ||
        finalDiscountPrice >= finalOriginalPrice
    ) {
        throw new Error(
            "Discount price must be positive and lower than original price."
        );
    }

    cleanData.updatedAt = FieldValue.serverTimestamp();

    await offerRef.update(cleanData);

    const updatedDoc = await offerRef.get();

    return {
        id: updatedDoc.id,
        ...updatedDoc.data()
    };
};

// Supprimer une offre
const deleteOffer = async (uid, offerId) => {
    const offerRef = offersCollection.doc(offerId);
    const offerDoc = await offerRef.get();

    if (!offerDoc.exists) {
        throw new Error("Offer not found.");
    }

    if (offerDoc.data().ownerId !== uid) {
        throw new Error("You are not allowed to delete this offer.");
    }

    await offerRef.delete();

    return {
        offerId,
        deleted: true
    };
};

module.exports = {
    createOffer,
    getAllOffers,
    getOfferById,
    getMyOffers,
    updateOffer,
    deleteOffer
};
