const express = require("express");
const router = express.Router();

const {
    createOffer,
    createSurpriseBasket,
    getAllOffers,
    getSurpriseBaskets,
    getOfferById,
    getMyOffers,
    updateOffer,
    deleteOffer
} = require("../controllers/offerController");

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");

// Routes publiques
router.get("/", getAllOffers);

// Bonus Surprise Basket (must stay above "/:id")
router.get("/surprise-baskets", getSurpriseBaskets);

router.get("/:id", getOfferById);

// Routes Merchant
router.post(
    "/",
    verifyToken,
    verifyRole("merchant"),
    createOffer
);

router.post(
    "/surprise-baskets",
    verifyToken,
    verifyRole("merchant"),
    createSurpriseBasket
);

router.get(
    "/merchant/my-offers",
    verifyToken,
    verifyRole("merchant"),
    getMyOffers
);

router.put(
    "/:id",
    verifyToken,
    verifyRole("merchant"),
    updateOffer
);

router.delete(
    "/:id",
    verifyToken,
    verifyRole("merchant"),
    deleteOffer
);

module.exports = router;
