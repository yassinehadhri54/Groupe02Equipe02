
const express = require("express");
const router = express.Router();

const {
    getMyProfile,
    updateMyProfile,
    getUsers,
    getUser,
    getPendingMerchantsController,
    approveMerchantController,
    rejectMerchantController
} = require("../controllers/userController");

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");

// Connected user
router.get("/profile", verifyToken, getMyProfile);
router.put("/profile", verifyToken, updateMyProfile);

// Admin only: merchant management
router.get(
    "/merchants/pending",
    verifyToken,
    verifyRole("admin"),
    getPendingMerchantsController
);

router.put(
    "/:id/approve",
    verifyToken,
    verifyRole("admin"),
    approveMerchantController
);

router.put(
    "/:id/reject",
    verifyToken,
    verifyRole("admin"),
    rejectMerchantController
);

// Admin only: user management
router.get("/", verifyToken, verifyRole("admin"), getUsers);
router.get("/:id", verifyToken, verifyRole("admin"), getUser);

module.exports = router;
