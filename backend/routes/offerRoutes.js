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
const { verifyActiveMerchant } = require("../middlewares/activeMerchantMiddleware");
const { verifyAdminOfferAccess } = require("./adminOfferRoutes");
const { getAdminOffers } = require("../controllers/adminOfferController");

// Routes publiques
router.get("/", getAllOffers);

// Bonus Surprise Basket (must stay above "/:id")
router.get("/surprise-baskets", getSurpriseBaskets);

// Compatibility routes used by older web clients.
router.get("/my", verifyToken, verifyActiveMerchant, getMyOffers);
router.get("/admin/all", ...verifyAdminOfferAccess, getAdminOffers);
router.get("/:id", getOfferById);

// Routes Merchant
router.post(
    "/",
    verifyToken,
    verifyActiveMerchant,
    createOffer
);

router.post(
    "/surprise-baskets",
    verifyToken,
    verifyActiveMerchant,
    createSurpriseBasket
);

router.get(
    "/merchant/my-offers",
    verifyToken,
    verifyActiveMerchant,
    getMyOffers
);

router.put(
    "/:id",
    verifyToken,
    verifyActiveMerchant,
    updateOffer
);

router.delete(
    "/:id",
    verifyToken,
    verifyActiveMerchant,
    deleteOffer
);

module.exports = router;
