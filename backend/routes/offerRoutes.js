
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

// Consulter toutes les offres : utilisateurs connectés
router.get(
    "/",
    verifyToken,
    getAllOffersController
);

// Consulter ses propres offres : commerçant actif
router.get(
    "/my",
    verifyToken,
    verifyRole("merchant"),
    getMyOffersController
);

// Publier une offre : commerçant actif
router.post(
    "/",
    verifyToken,
    verifyRole("merchant"),
    createOfferController
);

// Modifier une offre : propriétaire commerçant
router.put(
    "/:id",
    verifyToken,
    verifyRole("merchant"),
    updateOfferController
);

// Supprimer une offre : commerçant propriétaire ou administrateur
router.delete(
    "/:id",
    verifyToken,
    verifyRole("merchant", "admin"),
    deleteOfferController
);

module.exports = router;
