
const express = require("express");
const router = express.Router();

const {
    register,
    login,
    getMe,
    logout
} = require("../controllers/authController");

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");

// Public routes
router.post("/register", register);
router.post("/login", login);

// Protected routes
router.get("/me", verifyToken, getMe);
router.post("/logout", verifyToken, logout);

// Temporary role testing routes
router.get("/student-area", verifyToken, verifyRole("student"), (req, res) => {
    res.status(200).json({
        success: true,
        message: "Welcome to Student Area!",
        user: req.user
    });
});

router.get("/merchant-area", verifyToken, verifyRole("merchant"), (req, res) => {
    res.status(200).json({
        success: true,
        message: "Welcome to Merchant Area!",
        user: req.user
    });
});

router.get("/admin-area", verifyToken, verifyRole("admin"), (req, res) => {
    res.status(200).json({
        success: true,
        message: "Welcome to Admin Area!",
        user: req.user
    });
});

module.exports = router;
