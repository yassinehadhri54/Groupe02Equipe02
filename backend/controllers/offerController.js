
const offerService = require("../services/offerService");
const { OFFER_TYPES, SURPRISE_BASKET } = require("../utils/offerFields");

// Créer une offre
// body.offerType = "standard" (default) or "surprise_basket".
// forcedType is used by POST /api/offers/surprise-baskets.
const createOffer = async (req, res, forcedType) => {
    try {
        const body = req.body || {};
        const {
            name = body.title,
            description,
            category,
            originalPrice,
            discountPrice = body.discountedPrice,
            quantity,
            pickupStart,
            pickupEnd,
            imageURL = body.imageUrl,
            address,
            basketItems,
            foodInfo,
            allergenInfo
        } = body;

        const offerType =
            typeof forcedType === "string" ? forcedType : (req.body || {}).offerType;

        // A surprise basket gets a default name and category.
        const isBasket = offerType === SURPRISE_BASKET;

        if (
            (!name && !isBasket) ||
            (!category && !isBasket) ||
            originalPrice === undefined ||
            discountPrice === undefined ||
            quantity === undefined ||
            !pickupStart ||
            !pickupEnd
        ) {
            return res.status(400).json({
                success: false,
                message: "All required fields must be provided."
            });
        }

        const original = Number(originalPrice);
        const discount = Number(discountPrice);
        const qty = Number(quantity);

        if (
            !Number.isFinite(original) ||
            !Number.isFinite(discount) ||
            original <= 0 ||
            discount <= 0 ||
            discount >= original
        ) {
            return res.status(400).json({
                success: false,
                message: "Prices must be positive and discount price must be lower than original price."
            });
        }

        if (!Number.isInteger(qty) || qty <= 0) {
            return res.status(400).json({
                success: false,
                message: "Quantity must be a positive integer."
            });
        }

        const offer = await offerService.createOffer(
            req.user.uid,
            {
                name,
                description,
                category,
                originalPrice: original,
                discountPrice: discount,
                quantity: qty,
                pickupStart,
                pickupEnd,
                imageURL,
                address,
                offerType,
                basketItems,
                foodInfo,
                allergenInfo
            }
        );

        return res.status(201).json({
            success: true,
            message: isBasket
                ? "Surprise basket created successfully."
                : "Offer created successfully.",
            data: offer,
            offer
        });

    } catch (error) {
        console.error("Create offer error:", error.message);

        const statusCode =
            error.message.includes("approved shop") ? 403 : 400;

        return res.status(statusCode).json({
            success: false,
            message: error.message
        });
    }
};

// Bonus Surprise Basket: POST /api/offers/surprise-baskets
const createSurpriseBasket = (req, res) =>
    createOffer(req, res, SURPRISE_BASKET);

// Afficher toutes les offres disponibles
// ?type=standard|surprise_basket filters by offer type.
// forcedType is used by GET /api/offers/surprise-baskets.
const getAllOffers = async (req, res, forcedType) => {
    try {
        const { category, shopId, q, product, shop } = req.query;

        const type = typeof forcedType === "string" ? forcedType : req.query.type;

        if (type !== undefined && !OFFER_TYPES.includes(type)) {
            return res.status(400).json({
                success: false,
                message: `type must be one of: ${OFFER_TYPES.join(", ")}.`
            });
        }

        // An empty "max price" box (?maxPrice=) means no price filter,
        // not "free offers only".
        const maxPrice = req.query.maxPrice === "" ? undefined : req.query.maxPrice;

        // Text filters must be single strings (not repeated params) of reasonable length.
        const textFilters = { category, shopId, q, product, shop };
        for (const [name, value] of Object.entries(textFilters)) {
            if (
                value !== undefined &&
                (typeof value !== "string" || value.length > 100)
            ) {
                return res.status(400).json({
                    success: false,
                    message: `${name} must be a text of at most 100 characters.`
                });
            }
        }

        if (
            maxPrice !== undefined &&
            (typeof maxPrice !== "string" || !Number.isFinite(Number(maxPrice)) || Number(maxPrice) < 0)
        ) {
            return res.status(400).json({
                success: false,
                message: "maxPrice must be a valid positive number."
            });
        }

        const offers = await offerService.getAllOffers({
            type,
            category,
            shopId,
            maxPrice,
            q,
            product,
            shop
        });

        return res.status(200).json({
            success: true,
            count: offers.length,
            data: offers,
            offers
        });

    } catch (error) {
        console.error("Get offers error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Could not retrieve offers."
        });
    }
};

// Bonus Surprise Basket: GET /api/offers/surprise-baskets (same filters)
const getSurpriseBaskets = (req, res) =>
    getAllOffers(req, res, SURPRISE_BASKET);

// Afficher une offre par ID
const getOfferById = async (req, res) => {
    try {
        const offer = await offerService.getOfferById(req.params.id);

        if (!offer) {
            return res.status(404).json({
                success: false,
                message: "Offer not found."
            });
        }

        return res.status(200).json({
            success: true,
            data: offer,
            offer
        });

    } catch (error) {
        console.error("Get offer error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Could not retrieve offer."
        });
    }
};

// Afficher les offres du commerçant connecté
const getMyOffers = async (req, res) => {
    try {
        const offers = await offerService.getMyOffers(req.user.uid);

        return res.status(200).json({
            success: true,
            count: offers.length,
            data: offers,
            offers
        });

    } catch (error) {
        console.error("Get my offers error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Could not retrieve your offers."
        });
    }
};

// Modifier une offre
const updateOffer = async (req, res) => {
    try {
        const offer = await offerService.updateOffer(
            req.user.uid,
            req.params.id,
            req.body || {}
        );

        return res.status(200).json({
            success: true,
            message: "Offer updated successfully.",
            data: offer,
            offer
        });

    } catch (error) {
        console.error("Update offer error:", error.message);

        let statusCode = 400;

        if (error.message === "Offer not found.") {
            statusCode = 404;
        } else if (
            error.message === "You are not allowed to modify this offer."
        ) {
            statusCode = 403;
        }

        return res.status(statusCode).json({
            success: false,
            message: error.message
        });
    }
};

// Supprimer une offre
const deleteOffer = async (req, res) => {
    try {
        const result = await offerService.deleteOffer(
            req.user.uid,
            req.params.id
        );

        return res.status(200).json({
            success: true,
            message: "Offer deleted successfully.",
            data: result
        });

    } catch (error) {
        console.error("Delete offer error:", error.message);

        let statusCode = 400;

        if (error.message === "Offer not found.") {
            statusCode = 404;
        } else if (
            error.message === "You are not allowed to delete this offer."
        ) {
            statusCode = 403;
        }

        return res.status(statusCode).json({
            success: false,
            message: error.message
        });
    }
};

module.exports = {
    createOffer,
    createSurpriseBasket,
    getAllOffers,
    getSurpriseBaskets,
    getOfferById,
    getMyOffers,
    updateOffer,
    deleteOffer
};
