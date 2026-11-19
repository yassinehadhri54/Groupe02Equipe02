
const express = require("express");
const router = express.Router();

const {
    createOfferController,
    getAllOffersController,
    getMyOffersController,
    updateOfferController,
    deleteOfferController
} = require("../controllers/offerController");

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");
const { verifyActiveMerchant } = require("../middlewares/activeMerchantMiddleware");

// Consulter toutes les offres : utilisateurs connectés
router.get(
    "/",
    verifyToken,
    getAllOffersController
);

// Consulter ses offres : commerçant approuvé
router.get(
    "/my",
    verifyToken,
    verifyActiveMerchant,
    getMyOffersController
);

// Publier une offre : commerçant approuvé
router.post(
    "/",
    verifyToken,
    verifyActiveMerchant,
    createOfferController
);

// Modifier une offre : commerçant approuvé
router.put(
    "/:id",
    verifyToken,
    verifyActiveMerchant,
    updateOfferController
);

// Supprimer une offre : commerçant approuvé ou administrateur
router.delete(
    "/:id",
    verifyToken,
    verifyRole("merchant", "admin"),
    (req, res, next) => {
        if (req.user.role === "admin") return next();
        return verifyActiveMerchant(req, res, next);
    },
    deleteOfferController
);

module.exports = router;
