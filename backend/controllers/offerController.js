
const offerService = require("../services/offerService");

// Créer une offre
const createOffer = async (req, res) => {
    try {
        const {
            name,
            description,
            category,
            originalPrice,
            discountPrice,
            quantity,
            pickupStart,
            pickupEnd,
            imageURL
        } = req.body || {};

        if (
            !name ||
            !category ||
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
                imageURL
            }
        );

        return res.status(201).json({
            success: true,
            message: "Offer created successfully.",
            data: offer
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

// Afficher toutes les offres disponibles
const getAllOffers = async (req, res) => {
    try {
        const { category, shopId, q, product, shop } = req.query;

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
            data: offers
        });

    } catch (error) {
        console.error("Get offers error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Could not retrieve offers."
        });
    }
};

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
            data: offer
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
            data: offers
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
            data: offer
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
    getAllOffers,
    getOfferById,
    getMyOffers,
    updateOffer,
    deleteOffer
};
