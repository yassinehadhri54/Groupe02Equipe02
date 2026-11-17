
const express = require("express");
const router = express.Router();

const {
    register,
    login,
    getMe
} = require("../controllers/authController");

console.log("REGISTER:", typeof register);
console.log("LOGIN:", typeof login);
console.log("GET ME:", typeof getMe);

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");

// Public routes
router.post("/register", register);
router.post("/login", login);

// Protected route
router.get("/me", verifyToken, getMe);

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
