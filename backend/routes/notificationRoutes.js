
const express = require("express");
const router = express.Router();

const {
    registerToken,
    removeToken,
    getMyNotifications,
    markAsRead
} = require("../controllers/notificationController");

const { verifyToken } = require("../middlewares/authMiddleware");

// Every role can receive notifications; a user only manages their own.
router.use(verifyToken);

router.post("/token", registerToken);
router.delete("/token", removeToken);
router.get("/", getMyNotifications);
router.put("/:id/read", markAsRead);

module.exports = router;
