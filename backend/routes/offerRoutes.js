
const express = require("express");
const router = express.Router();

const {
    createOfferController,
    getAllOffersController,
    getOfferByIdController,
    getMyOffersController,
    updateOfferController,
    deleteOfferController
} = require("../controllers/offerController");

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");
const {
    verifyActiveMerchant
} = require("../middlewares/activeMerchantMiddleware");

// Consulter toutes les offres.
router.get(
    "/",
    verifyToken,
    getAllOffersController
);

// Consulter les offres du commerçant connecté.
router.get(
    "/my",
    verifyToken,
    verifyActiveMerchant,
    getMyOffersController
);

// Consulter une offre par son identifiant.
router.get(
    "/:id",
    verifyToken,
    getOfferByIdController
);

// Publier une offre.
router.post(
    "/",
    verifyToken,
    verifyActiveMerchant,
    createOfferController
);

// Modifier une offre.
router.put(
    "/:id",
    verifyToken,
    verifyActiveMerchant,
    updateOfferController
);

// Supprimer une offre : commerçant actif ou administrateur.
router.delete(
    "/:id",
    verifyToken,
    verifyRole("merchant", "admin"),
    (req, res, next) => {
        if (req.user.role === "admin") {
            return next();
        }

        return verifyActiveMerchant(req, res, next);
    },
    deleteOfferController
);

module.exports = router;
