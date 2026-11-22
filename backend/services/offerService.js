
const { db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");

const {
    LISTED_OFFER_STATUSES,
    getOfferOwnerId,
    isOfferBookable,
    normalizeOffer
} = require("../utils/offerFields");

const {
    isHttpUrl,
    isNonEmptyText,
    validatePickupWindow
} = require("../utils/validation");

const offersCollection = db.collection("offers");
const shopsCollection = db.collection("shops");
const reservationsCollection = db.collection("reservations");

// Rechercher une boutique approuvée appartenant au commerçant.
const getApprovedShop = async (uid) => {
    const [ownerSnapshot, legacySnapshot] = await Promise.all([
        shopsCollection
            .where("ownerId", "==", uid)
            .where("status", "==", "approved")
            .limit(1)
            .get(),
        shopsCollection
            .where("merchantId", "==", uid)
            .where("status", "==", "approved")
            .limit(1)
            .get()
    ]);

    const shopDoc =
        ownerSnapshot.docs[0] || legacySnapshot.docs[0];

    if (!shopDoc) {
        throw new Error("You need an approved shop to publish offers.");
    }

    return {
        id: shopDoc.id,
        ...shopDoc.data()
    };
};

// Création d'une offre.
// Les deux formats de données sont acceptés.
const createOffer = async (uid, offerData) => {
    const name = offerData.name ?? offerData.title;
    const discountPrice =
        offerData.discountPrice ?? offerData.discountedPrice;
    const imageURL = offerData.imageURL ?? offerData.imageUrl ?? "";

    if (!isNonEmptyText(name) || !isNonEmptyText(offerData.category)) {
        throw new Error("Name and category must be non-empty texts.");
    }

    if (!isNonEmptyText(offerData.description, 1000)) {
        throw new Error("Description must be a non-empty text.");
    }

    const original = Number(offerData.originalPrice);
    const discount = Number(discountPrice);
    const quantity = Number(offerData.quantity);

    if (
        !Number.isFinite(original) ||
        !Number.isFinite(discount) ||
        original <= 0 ||
        discount <= 0 ||
        discount >= original
    ) {
        throw new Error("Invalid offer prices.");
    }

    if (!Number.isInteger(quantity) || quantity <= 0) {
        throw new Error("Invalid offer quantity.");
    }

    validatePickupWindow(
        offerData.pickupStart,
        offerData.pickupEnd
    );

    if (imageURL && !isHttpUrl(imageURL)) {
        throw new Error("imageURL must be a valid http(s) URL.");
    }

    const shop = await getApprovedShop(uid);
    const offerRef = offersCollection.doc();

    const newOffer = {
        offerId: offerRef.id,
        shopId: shop.shopId || shop.id,
        shopName: shop.name || "",

        ownerId: uid,
        merchantId: uid,

        name: name.trim(),
        title: name.trim(),
        description: offerData.description.trim(),
        category: offerData.category.trim(),

        originalPrice: original,
        discountPrice: discount,
        discountedPrice: discount,

        quantity,
        availableQuantity: quantity,

        pickupStart: offerData.pickupStart,
        pickupEnd: offerData.pickupEnd,

        imageURL,
        imageUrl: imageURL,

        address: offerData.address || "",

        status: "available",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
    };

    await offerRef.set(newOffer);

    return {
        ...newOffer,
        id: offerRef.id,
        createdAt: null,
        updatedAt: null
    };
};

// Normalisation du texte pour les recherches.
const normalizeText = (value) =>
    String(value ?? "")
        .normalize("NFD")
        .replace(/[\u0300-\u036f]/g, "")
        .toLowerCase()
        .trim();

// Récupérer les offres publiques disponibles.
const getAllOffers = async (filters = {}) => {
    const snapshot = await offersCollection
        .where("status", "in", LISTED_OFFER_STATUSES)
        .get();

    let offers = snapshot.docs
        .map((doc) => normalizeOffer(doc.id, doc.data()))
        .filter((offer) => isOfferBookable(offer));

    const shopIds = [
        ...new Set(offers.map((offer) => offer.shopId).filter(Boolean))
    ];

    const shopSnapshots = shopIds.length
        ? await db.getAll(
            ...shopIds.map((id) => shopsCollection.doc(id))
        )
        : [];

    const shops = new Map(
        shopSnapshots
            .filter((shop) => shop.exists)
            .map((shop) => [shop.id, shop.data()])
    );

    offers = offers
        .filter((offer) => shops.get(offer.shopId)?.status === "approved")
        .map((offer) => ({
            ...offer,
            shopName:
                shops.get(offer.shopId).name ||
                offer.shopName ||
                ""
        }));

    if (filters.category) {
        const category = normalizeText(filters.category);
        offers = offers.filter(
            (offer) => normalizeText(offer.category) === category
        );
    }

    if (filters.product) {
        const product = normalizeText(filters.product);
        offers = offers.filter(
            (offer) => normalizeText(offer.name).includes(product)
        );
    }

    if (filters.shop) {
        const shop = normalizeText(filters.shop);
        offers = offers.filter(
            (offer) => normalizeText(offer.shopName).includes(shop)
        );
    }

    if (filters.q) {
        const words = normalizeText(filters.q)
            .split(/\s+/)
            .filter(Boolean);

        offers = offers.filter((offer) => {
            const searchableText = normalizeText([
                offer.name,
                offer.description,
                offer.category,
                offer.shopName
            ].join(" "));

            return words.every((word) =>
                searchableText.includes(word)
            );
        });
    }

    if (filters.shopId) {
        offers = offers.filter(
            (offer) => offer.shopId === filters.shopId
        );
    }

    if (filters.maxPrice !== undefined) {
        const maxPrice = Number(filters.maxPrice);

        offers = offers.filter((offer) => {
            const price = Number(offer.discountPrice);
            return Number.isFinite(price) && price <= maxPrice;
        });
    }

    return offers;
};

// Récupérer toutes les offres pour l'administrateur.
// Inclut les offres actives, expirées et supprimées.
const getAllOffersForAdmin = async () => {
    const snapshot = await offersCollection.get();

    return snapshot.docs.map((doc) =>
        normalizeOffer(doc.id, doc.data())
    );
};

// Récupérer une offre par son identifiant.
const getOfferById = async (offerId) => {
    const doc = await offersCollection.doc(offerId).get();

    if (!doc.exists) {
        return null;
    }

    return normalizeOffer(doc.id, doc.data());
};

// Récupérer les offres d'un commerçant.
// Compatibilité avec ownerId et merchantId.
// Les offres expirées restent visibles.
// Les offres supprimées sont masquées.
const getMyOffers = async (uid) => {
    const [ownerSnapshot, merchantSnapshot] = await Promise.all([
        offersCollection.where("ownerId", "==", uid).get(),
        offersCollection.where("merchantId", "==", uid).get()
    ]);
console.log("UID DU COMMERÇANT :", uid);

console.log(
    "OFFRES TROUVÉES PAR ownerId :",
    ownerSnapshot.docs.map(doc => ({
        id: doc.id,
        data: doc.data()
    }))
);

console.log(
    "OFFRES TROUVÉES PAR merchantId :",
    merchantSnapshot.docs.map(doc => ({
        id: doc.id,
        data: doc.data()
    }))
);
    const offersById = new Map();

    [...ownerSnapshot.docs, ...merchantSnapshot.docs].forEach((doc) => {
        offersById.set(
            doc.id,
            normalizeOffer(doc.id, doc.data())
        );
    });

return [...offersById.values()];
};

// Ancien nom conservé pour compatibilité.
const getMerchantOffers = getMyOffers;

// Modifier une offre avec une transaction Firestore.
const updateOffer = async (uid, offerId, updateData) => {
    const offerRef = offersCollection.doc(offerId);

    return db.runTransaction(async (transaction) => {
        const offerDoc = await transaction.get(offerRef);

        if (!offerDoc.exists) {
            throw new Error("Offer not found.");
        }

        const rawCurrent = offerDoc.data();

        if (getOfferOwnerId(rawCurrent) !== uid) {
            throw new Error("You are not allowed to modify this offer.");
        }

        const current = normalizeOffer(offerDoc.id, rawCurrent);

        if (current.status === "deleted") {
            throw new Error("Cannot modify a deleted offer.");
        }

        const cleanData = {};

        const aliases = {
            name: updateData.name ?? updateData.title,
            discountPrice:
                updateData.discountPrice ?? updateData.discountedPrice,
            imageURL: updateData.imageURL ?? updateData.imageUrl
        };

        const allowedFields = [
            "description",
            "category",
            "originalPrice",
            "quantity",
            "pickupStart",
            "pickupEnd",
            "address"
        ];

        for (const field of allowedFields) {
            if (updateData[field] !== undefined) {
                cleanData[field] = updateData[field];
            }
        }

        for (const [field, value] of Object.entries(aliases)) {
            if (value !== undefined) {
                cleanData[field] = value;
            }
        }

        if (Object.keys(cleanData).length === 0) {
            throw new Error("No valid fields provided for update.");
        }

        if (
            cleanData.name !== undefined &&
            !isNonEmptyText(cleanData.name)
        ) {
            throw new Error("Invalid offer name.");
        }

        if (
            cleanData.category !== undefined &&
            !isNonEmptyText(cleanData.category)
        ) {
            throw new Error("Invalid offer category.");
        }

        if (
            cleanData.description !== undefined &&
            !isNonEmptyText(cleanData.description, 1000)
        ) {
            throw new Error("Invalid offer description.");
        }

        if (
            cleanData.imageURL !== undefined &&
            cleanData.imageURL !== "" &&
            !isHttpUrl(cleanData.imageURL)
        ) {
            throw new Error("Invalid image URL.");
        }

        if (
            cleanData.pickupStart !== undefined ||
            cleanData.pickupEnd !== undefined
        ) {
            validatePickupWindow(
                cleanData.pickupStart ?? current.pickupStart,
                cleanData.pickupEnd ?? current.pickupEnd
            );
        }

        for (const field of ["originalPrice", "discountPrice"]) {
            if (cleanData[field] !== undefined) {
                cleanData[field] = Number(cleanData[field]);

                if (!Number.isFinite(cleanData[field])) {
                    throw new Error("Invalid offer price.");
                }
            }
        }

        if (cleanData.quantity !== undefined) {
            const newQuantity = Number(cleanData.quantity);
            const oldQuantity = Number(current.quantity);
            const oldAvailable = Number(current.availableQuantity);

            if (!Number.isInteger(newQuantity) || newQuantity <= 0) {
                throw new Error("Invalid offer quantity.");
            }

            const reservedQuantity = oldQuantity - oldAvailable;

            if (
                !Number.isInteger(reservedQuantity) ||
                reservedQuantity < 0
            ) {
                throw new Error("Invalid offer stock data.");
            }

            if (newQuantity < reservedQuantity) {
                throw new Error(
                    "Quantity cannot be lower than the quantity already reserved."
                );
            }

            cleanData.quantity = newQuantity;
            cleanData.availableQuantity =
                newQuantity - reservedQuantity;
        }

        const finalOriginal =
            cleanData.originalPrice ?? Number(current.originalPrice);

        const finalDiscount =
            cleanData.discountPrice ?? Number(current.discountPrice);

        if (
            !Number.isFinite(finalOriginal) ||
            !Number.isFinite(finalDiscount) ||
            finalOriginal <= 0 ||
            finalDiscount <= 0 ||
            finalDiscount >= finalOriginal
        ) {
            throw new Error("Invalid offer prices.");
        }

        // Synchroniser les anciens champs pour les clients existants.
        if (cleanData.name !== undefined) {
            cleanData.title = cleanData.name;
        }

        if (cleanData.discountPrice !== undefined) {
            cleanData.discountedPrice = cleanData.discountPrice;
        }

        if (cleanData.imageURL !== undefined) {
            cleanData.imageUrl = cleanData.imageURL;
        }

        cleanData.updatedAt = FieldValue.serverTimestamp();

        transaction.update(offerRef, cleanData);

        return normalizeOffer(offerId, {
            ...rawCurrent,
            ...cleanData,
            updatedAt: null
        });
    });
};

// Suppression logique : les réservations historiques restent intactes.
// L'offre ne sera plus visible ni réservable pour les étudiants.
const deleteOffer = async (uid, offerId, isAdmin = false) => {
    const offerRef = offersCollection.doc(offerId);

    return db.runTransaction(async (transaction) => {
        const offerDoc = await transaction.get(offerRef);

        if (!offerDoc.exists) {
            throw new Error("Offer not found.");
        }

        const offer = offerDoc.data();
// Empêcher la suppression d'une offre déjà supprimée.
if (offer.status === "deleted") {
    throw new Error("Offer is already deleted.");
}

if (!isAdmin && getOfferOwnerId(offer) !== uid) {
            throw new Error("You are not allowed to delete this offer.");
        }

        transaction.update(offerRef, {
            status: "deleted",
            deletedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            offerId,
            deleted: true
        };
    });
};

module.exports = {
    createOffer,
    getAllOffers,
    getAllOffersForAdmin,
    getOfferById,
    getMyOffers,
    getMerchantOffers,
    updateOffer,
    deleteOffer
};
