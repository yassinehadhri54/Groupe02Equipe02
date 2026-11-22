
const express = require("express");
const router = express.Router();

const {
    getMyProfile,
    updateMyProfile,
    getUsers,
    getUser,
    getPendingMerchantsController,
    approveMerchantController,
    rejectMerchantController,
    updateUserStatus
} = require("../controllers/userController");

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");

// Profil de l'utilisateur connecté.
router.get("/profile", verifyToken, getMyProfile);
router.put("/profile", verifyToken, updateMyProfile);

// Gestion des commerçants : administrateur uniquement.
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

// Gestion des utilisateurs : administrateur uniquement.
router.get(
    "/",
    verifyToken,
    verifyRole("admin"),
    getUsers
);

router.get(
    "/:id",
    verifyToken,
    verifyRole("admin"),
    getUser
);

// Suspendre ou réactiver un utilisateur.
router.put(
    "/:id/status",
    verifyToken,
    verifyRole("admin"),
    updateUserStatus
);

module.exports = router;
