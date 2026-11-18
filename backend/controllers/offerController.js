
const offerService = require("../services/offerService");

// Créer une offre (commerçant)
const createOfferController = async (req, res) => {
    try {
        const {
            title,
            description,
            category,
            originalPrice,
            discountedPrice,
            quantity,
            imageUrl,
            pickupStart,
            pickupEnd,
            address
        } = req.body;

        if (
            !title ||
            !description ||
            !category ||
            originalPrice === undefined ||
            discountedPrice === undefined ||
            quantity === undefined
        ) {
            return res.status(400).json({
                success: false,
                message: "Veuillez remplir tous les champs obligatoires."
            });
        }

        if (
            !Number.isFinite(Number(originalPrice)) ||
            !Number.isFinite(Number(discountedPrice)) ||
            Number(originalPrice) <= 0 ||
            Number(discountedPrice) < 0 ||
            Number(discountedPrice) >= Number(originalPrice)
        ) {
            return res.status(400).json({
                success: false,
                message: "Les prix sont invalides."
            });
        }

        if (!Number.isInteger(Number(quantity)) || Number(quantity) <= 0) {
            return res.status(400).json({
                success: false,
                message: "La quantité doit être un entier positif."
            });
        }

        const offer = await offerService.createOffer({
            title: String(title).trim(),
            description: String(description).trim(),
            category: String(category).trim(),
            originalPrice: Number(originalPrice),
            discountedPrice: Number(discountedPrice),
            quantity: Number(quantity),
            imageUrl: imageUrl || "",
            pickupStart: pickupStart || "",
            pickupEnd: pickupEnd || "",
            address: address || ""
        }, req.user.uid);

        return res.status(201).json({
            success: true,
            message: "Offre créée avec succès.",
            offer
        });

    } catch (error) {
        console.error("Create offer error:", error);

        return res.status(500).json({
            success: false,
            message: "Erreur lors de la création de l'offre."
        });
    }
};

// Toutes les offres (étudiants et administrateurs)
const getAllOffersController = async (req, res) => {
    try {
        const offers = await offerService.getAllOffers();

        return res.status(200).json({
            success: true,
            count: offers.length,
            offers
        });

    } catch (error) {
        console.error("Get offers error:", error);

        return res.status(500).json({
            success: false,
            message: "Erreur lors de la récupération des offres."
        });
    }
};

// Offres du commerçant connecté
const getMyOffersController = async (req, res) => {
    try {
        const offers = await offerService.getMerchantOffers(req.user.uid);

        return res.status(200).json({
            success: true,
            count: offers.length,
            offers
        });

    } catch (error) {
        console.error("Get merchant offers error:", error);

        return res.status(500).json({
            success: false,
            message: "Erreur lors de la récupération de vos offres."
        });
    }
};

// Modifier une offre
const updateOfferController = async (req, res) => {
    try {
        const offer = await offerService.updateOffer(
            req.params.id,
            req.user.uid,
            req.body
        );

        if (!offer) {
            return res.status(404).json({
                success: false,
                message: "Offre introuvable."
            });
        }

        return res.status(200).json({
            success: true,
            message: "Offre modifiée avec succès.",
            offer
        });

    } catch (error) {
        if (error.message === "FORBIDDEN") {
            return res.status(403).json({
                success: false,
                message: "Vous ne pouvez modifier que vos propres offres."
            });
        }

        console.error("Update offer error:", error);

        return res.status(500).json({
            success: false,
            message: "Erreur lors de la modification de l'offre."
        });
    }
};

// Supprimer une offre
const deleteOfferController = async (req, res) => {
    try {
        const isAdmin = req.user.role === "admin";

        const deleted = await offerService.deleteOffer(
            req.params.id,
            req.user.uid,
            isAdmin
        );

        if (!deleted) {
            return res.status(404).json({
                success: false,
                message: "Offre introuvable."
            });
        }

        return res.status(200).json({
            success: true,
            message: "Offre supprimée avec succès."
        });

    } catch (error) {
        if (error.message === "FORBIDDEN") {
            return res.status(403).json({
                success: false,
                message: "Vous ne pouvez supprimer que vos propres offres."
            });
        }

        console.error("Delete offer error:", error);

        return res.status(500).json({
            success: false,
            message: "Erreur lors de la suppression de l'offre."
        });
    }
};

module.exports = {
    createOfferController,
    getAllOffersController,
    getMyOffersController,
    updateOfferController,
    deleteOfferController
};
