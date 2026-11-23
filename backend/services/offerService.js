
const { db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const {
    LISTED_OFFER_STATUSES,
    OFFER_TYPES,
    STANDARD_OFFER,
    SURPRISE_BASKET,
    getOfferOwnerId,
    isOfferBookable,
    isSurpriseBasket,
    normalizeOffer
} = require("../utils/offerFields");
const {
    isHttpUrl,
    isNonEmptyText,
    isOptionalText,
    validateBasketItems,
    validatePickupWindow
} = require("../utils/validation");

// A deleted offer is kept (status "deleted") so that its reservations can
// still be cancelled, rejected or shown in the history.
const DELETED_STATUS = "deleted";

// Surprise basket defaults and rule: the basket is sold at most at half of
// its estimated value (originalPrice), so the student always gets a real deal.
const BASKET_DEFAULT_NAME = "Panier surprise";
const BASKET_DEFAULT_CATEGORY = "Panier surprise";
const BASKET_MAX_PRICE_RATIO = 0.5;

const checkBasketPrice = (originalPrice, discountPrice) => {
    if (discountPrice > originalPrice * BASKET_MAX_PRICE_RATIO) {
        throw new Error(
            "A surprise basket must cost at most 50% of its estimated value (originalPrice)."
        );
    }
};

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
const createOffer = async (uid, rawOfferData) => {
    const offerType = rawOfferData.offerType ?? STANDARD_OFFER;

    if (!OFFER_TYPES.includes(offerType)) {
        throw new Error(`offerType must be one of: ${OFFER_TYPES.join(", ")}.`);
    }

    const isBasket = offerType === SURPRISE_BASKET;

    if (!isBasket && rawOfferData.basketItems !== undefined) {
        throw new Error("basketItems can only be set on a surprise basket.");
    }

    // A surprise basket gets a default name and category when none is given.
    const offerData = isBasket
        ? {
            ...rawOfferData,
            name: rawOfferData.name || BASKET_DEFAULT_NAME,
            category: rawOfferData.category || BASKET_DEFAULT_CATEGORY
        }
        : rawOfferData;

    const basketItems = isBasket ? validateBasketItems(offerData.basketItems) : null;

    if (isBasket) {
        checkBasketPrice(Number(offerData.originalPrice), Number(offerData.discountPrice));
    }

    if (!isNonEmptyText(offerData.name) || !isNonEmptyText(offerData.category)) {
        throw new Error("Name and category must be non-empty texts of at most 100 characters.");
    }

    validatePickupWindow(offerData.pickupStart, offerData.pickupEnd);

    if (offerData.imageURL && !isHttpUrl(offerData.imageURL)) {
        throw new Error("imageURL must be a valid http(s) URL.");
    }

    if (!isOptionalText(offerData.description)) {
        throw new Error("description must be a text of at most 1000 characters.");
    }

    const shop = await getApprovedShop(uid);

    const offerRef = offersCollection.doc();

    const newOffer = {
        offerId: offerRef.id,
        shopId: shop.shopId || shop.id,
        shopName: shop.name || "",
        ownerId: uid,

        name: offerData.name,
        description: (offerData.description || "").trim(),
        category: offerData.category,
        originalPrice: Number(offerData.originalPrice),
        discountPrice: Number(offerData.discountPrice),
        quantity: Number(offerData.quantity),
        availableQuantity: Number(offerData.quantity),

        pickupStart: offerData.pickupStart,
        pickupEnd: offerData.pickupEnd,
        imageURL: offerData.imageURL || "",

        offerType,
        ...(isBasket ? { basketItems } : {}),

        status: "available",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
    };

    await offerRef.set(newOffer);

    return {
        ...normalizeOffer(offerRef.id, newOffer),
        createdAt: null,
        updatedAt: null
    };
};

// Récupérer toutes les offres disponibles
// Case- and accent-insensitive text ("Pâtes" matches "pates").
const normalizeText = (value) =>
    String(value ?? "")
        .normalize("NFD")
        .replace(/[̀-ͯ]/g, "")
        .toLowerCase()
        .trim();

// Public offer listing and search.
// Filters are applied in memory: the price is stored as "discountPrice"
// or "discountedPrice" depending on who created the offer, and this
// also avoids needing composite Firestore indexes.
//   q        : words searched in product name, description, category and shop name
//   product  : product name contains
//   shop     : shop name contains
//   category : exact category (case-insensitive)
//   type     : "standard" or "surprise_basket"
//   shopId, maxPrice
const getAllOffers = async (filters = {}) => {
    const snapshot = await offersCollection
        .where("status", "in", LISTED_OFFER_STATUSES)
        .get();

    // Expired (pickup window ended) and sold-out offers are not listed.
    let offers = snapshot.docs
        .map((doc) => normalizeOffer(doc.id, doc.data()))
        .filter((offer) => isOfferBookable(offer));

    // Only offers of approved shops are public. The shop name is taken
    // from the shop document (some offers do not store it).
    const shopIds = [...new Set(offers.map((offer) => offer.shopId).filter(Boolean))];
    const shopSnapshots = shopIds.length > 0
        ? await db.getAll(...shopIds.map((id) => shopsCollection.doc(id)))
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
            shopName: shops.get(offer.shopId).name || offer.shopName || ""
        }));

    if (filters.type) {
        offers = offers.filter((offer) => offer.offerType === filters.type);
    }

    if (filters.category) {
        const category = normalizeText(filters.category);
        offers = offers.filter((offer) => normalizeText(offer.category) === category);
    }

    if (filters.product) {
        const product = normalizeText(filters.product);
        offers = offers.filter((offer) => normalizeText(offer.name).includes(product));
    }

    if (filters.shop) {
        const shop = normalizeText(filters.shop);
        offers = offers.filter((offer) => normalizeText(offer.shopName).includes(shop));
    }

    if (filters.q) {
        const words = normalizeText(filters.q).split(/\s+/).filter(Boolean);

        offers = offers.filter((offer) => {
            const text = normalizeText(
                [
                    offer.name,
                    offer.description,
                    offer.category,
                    offer.shopName,
                    ...(offer.basketItems || [])
                ].join(" ")
            );
            return words.every((word) => text.includes(word));
        });
    }

    if (filters.shopId) {
        offers = offers.filter((offer) => offer.shopId === filters.shopId);
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

// Récupérer une offre par son ID
const getOfferById = async (offerId) => {
    const offerDoc = await offersCollection.doc(offerId).get();

    if (!offerDoc.exists || offerDoc.data().status === DELETED_STATUS) {
        return null;
    }

    return normalizeOffer(offerDoc.id, offerDoc.data());
};

// Récupérer les offres du commerçant connecté
// The owner is stored as "ownerId" or "merchantId" depending on who
// created the offer.
const getMyOffers = async (uid) => {
    const [ownerSnapshot, merchantSnapshot] = await Promise.all([
        offersCollection.where("ownerId", "==", uid).get(),
        offersCollection.where("merchantId", "==", uid).get()
    ]);

    const offersById = new Map();

    [...ownerSnapshot.docs, ...merchantSnapshot.docs]
        .filter((doc) => doc.data().status !== DELETED_STATUS)
        .forEach((doc) => {
            offersById.set(doc.id, normalizeOffer(doc.id, doc.data()));
        });

    return [...offersById.values()];
};

// Modifier une offre
// The read, the checks and the write run in one transaction: reservations
// change availableQuantity in transactions too, so a quantity change can
// never overwrite stock taken or returned in the meantime.
const updateOffer = async (uid, offerId, updateData) => {
    const offerRef = offersCollection.doc(offerId);

    await db.runTransaction(async (transaction) => {
        const offerDoc = await transaction.get(offerRef);

        if (!offerDoc.exists || offerDoc.data().status === DELETED_STATUS) {
            throw new Error("Offer not found.");
        }

        if (getOfferOwnerId(offerDoc.data()) !== uid) {
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
            "imageURL",
            "basketItems"
        ];

        // offerType is fixed at creation: it is not in the list above.
        const cleanData = {};

        for (const field of allowedFields) {
            if (updateData[field] !== undefined) {
                cleanData[field] = updateData[field];
            }
        }

        if (Object.keys(cleanData).length === 0) {
            throw new Error("No valid fields provided for update.");
        }

        const rawCurrent = offerDoc.data();
        const current = normalizeOffer(offerDoc.id, rawCurrent);
        const isBasket = isSurpriseBasket(rawCurrent);

        if (cleanData.basketItems !== undefined) {
            if (!isBasket) {
                throw new Error("basketItems can only be set on a surprise basket.");
            }

            cleanData.basketItems = validateBasketItems(cleanData.basketItems);
        }

        if (cleanData.description !== undefined) {
            if (!isOptionalText(cleanData.description)) {
                throw new Error("description must be a text of at most 1000 characters.");
            }

            cleanData.description = (cleanData.description || "").trim();
        }

        for (const field of ["name", "category"]) {
            if (cleanData[field] !== undefined && !isNonEmptyText(cleanData[field])) {
                throw new Error(`${field} must be a non-empty text of at most 100 characters.`);
            }
        }

        if (
            cleanData.imageURL !== undefined &&
            cleanData.imageURL !== "" &&
            !isHttpUrl(cleanData.imageURL)
        ) {
            throw new Error("imageURL must be a valid http(s) URL.");
        }

        if (cleanData.pickupStart !== undefined || cleanData.pickupEnd !== undefined) {
            validatePickupWindow(
                cleanData.pickupStart ?? current.pickupStart,
                cleanData.pickupEnd ?? current.pickupEnd
            );
        }

        for (const field of ["originalPrice", "discountPrice"]) {
            if (cleanData[field] !== undefined) {
                cleanData[field] = Number(cleanData[field]);

                if (!Number.isFinite(cleanData[field])) {
                    throw new Error("Prices must be valid numbers.");
                }
            }
        }

        if (cleanData.quantity !== undefined) {
            const newQuantity = Number(cleanData.quantity);

            if (!Number.isInteger(newQuantity) || newQuantity <= 0) {
                throw new Error("Quantity must be a positive integer.");
            }

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

        if (isBasket) {
            checkBasketPrice(finalOriginalPrice, finalDiscountPrice);
        }

        // Offers created by another client use other field names: keep those
        // in sync too, so every client sees the same values.
        const legacyFields = { name: "title", discountPrice: "discountedPrice", imageURL: "imageUrl" };

        for (const [field, legacyField] of Object.entries(legacyFields)) {
            if (cleanData[field] !== undefined && rawCurrent[legacyField] !== undefined) {
                cleanData[legacyField] = cleanData[field];
            }
        }

        cleanData.updatedAt = FieldValue.serverTimestamp();

        transaction.update(offerRef, cleanData);
    });

    const updatedDoc = await offerRef.get();

    return normalizeOffer(updatedDoc.id, updatedDoc.data());
};

// Supprimer une offre
// Soft delete: the offer disappears from the listing and can no longer be
// reserved or edited, but the document stays so that its reservations can
// still be cancelled / rejected (stock is returned to it) and dashboards
// keep the original price for the savings history.
const deleteOffer = async (uid, offerId) => {
    const offerRef = offersCollection.doc(offerId);

    await db.runTransaction(async (transaction) => {
        const offerDoc = await transaction.get(offerRef);

        if (!offerDoc.exists || offerDoc.data().status === DELETED_STATUS) {
            throw new Error("Offer not found.");
        }

        if (getOfferOwnerId(offerDoc.data()) !== uid) {
            throw new Error("You are not allowed to delete this offer.");
        }

        transaction.update(offerRef, {
            status: DELETED_STATUS,
            deletedAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
        });
    });

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
