
const express = require("express");
const router = express.Router();

const {
    getMyProfile,
    updateMyProfile,
    getUsers,
    getUser
} = require("../controllers/userController");

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");

// Connected user
router.get("/profile", verifyToken, getMyProfile);
router.put("/profile", verifyToken, updateMyProfile);

// Admin only
router.get("/", verifyToken, verifyRole("admin"), getUsers);
router.get("/:id", verifyToken, verifyRole("admin"), getUser);

module.exports = router;
