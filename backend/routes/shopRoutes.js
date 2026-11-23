
const express = require("express");
const router = express.Router();

const {
    registerShop,
    getMyShop,
    updateMyShop,
    getAllShops,
    getNearbyShops,
    approveShop,
    rejectShop
} = require("../controllers/shopController");

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");

// Bonus Campus Radar: public, like the offer listing
router.get("/nearby", getNearbyShops);

// Merchant routes
router.post(
    "/register",
    verifyToken,
    verifyRole("merchant"),
    registerShop
);

router.get(
    "/my-shop",
    verifyToken,
    verifyRole("merchant"),
    getMyShop
);

router.put(
    "/my-shop",
    verifyToken,
    verifyRole("merchant"),
    updateMyShop
);

// Admin routes
router.get(
    "/",
    verifyToken,
    verifyRole("admin"),
    getAllShops
);

router.put(
    "/:id/approve",
    verifyToken,
    verifyRole("admin"),
    approveShop
);

router.put(
    "/:id/reject",
    verifyToken,
    verifyRole("admin"),
    rejectShop
);

module.exports = router;
