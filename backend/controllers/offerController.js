
const offerService = require("../services/offerService");

// Créer une offre.
const createOfferController = async (req, res) => {
    try {
        const body = req.body || {};

        const name = body.name ?? body.title;
        const discountPrice =
            body.discountPrice ?? body.discountedPrice;
        const imageURL = body.imageURL ?? body.imageUrl ?? "";

        const offer = await offerService.createOffer(
            req.user.uid,
            {
                name,
                description: body.description,
                category: body.category,
                originalPrice: body.originalPrice,
                discountPrice,
                quantity: body.quantity,
                pickupStart: body.pickupStart,
                pickupEnd: body.pickupEnd,
                imageURL,
                address: body.address || ""
            }
        );

        return res.status(201).json({
            success: true,
            message: "Offer created successfully.",
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

// Afficher toutes les offres disponibles (étudiants).
const getAllOffersController = async (req, res) => {
    try {
        const {
            category,
            shopId,
            maxPrice,
            q,
            product,
            shop
        } = req.query;

        const textFilters = {
            category,
            shopId,
            q,
            product,
            shop
        };

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
            (
                !Number.isFinite(Number(maxPrice)) ||
                Number(maxPrice) < 0
            )
        ) {
            return res.status(400).json({
                success: false,
                message: "Invalid maximum price."
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

// Afficher toutes les offres pour l'administrateur,
// y compris les offres expirées et supprimées.
const getAllOffersForAdminController = async (req, res) => {
    try {
        const offers = await offerService.getAllOffersForAdmin();

        return res.status(200).json({
            success: true,
            count: offers.length,
            data: offers,
            offers
        });

    } catch (error) {
        console.error("Get all offers for admin error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Could not retrieve all offers."
        });
    }
};

// Afficher une offre par son identifiant.
const getOfferByIdController = async (req, res) => {
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

// Afficher les offres du commerçant connecté.
const getMyOffersController = async (req, res) => {
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

// Modifier une offre.
const updateOfferController = async (req, res) => {
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

// Supprimer une offre.
const deleteOfferController = async (req, res) => {
    try {
        const isAdmin = req.user.role === "admin";

        const result = await offerService.deleteOffer(
            req.user.uid,
            req.params.id,
            isAdmin
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

// Export des contrôleurs.
module.exports = {
    createOfferController,
    getAllOffersController,
    getAllOffersForAdminController,
    getOfferByIdController,
    getMyOffersController,
    updateOfferController,
    deleteOfferController,

    // Anciens noms conservés pour compatibilité.
    createOffer: createOfferController,
    getAllOffers: getAllOffersController,
    getOfferById: getOfferByIdController,
    getMyOffers: getMyOffersController,
    updateOffer: updateOfferController,
    deleteOffer: deleteOfferController
};
