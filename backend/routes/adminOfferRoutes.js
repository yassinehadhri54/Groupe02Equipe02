const express = require("express");
const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");
const { getAdminOffers, getAdminOffer, updateModeration } = require("../controllers/adminOfferController");

const router = express.Router();
router.use(verifyToken, verifyRole("admin"), (req, res, next) => {
    if (req.user.status !== "active") {
        return res.status(403).json({ success: false, message: "An active administrator account is required." });
    }
    next();
});

router.get("/", getAdminOffers);
router.get("/:id", getAdminOffer);
router.put("/:id/moderation", express.json({ limit: "8kb" }), updateModeration);

router.use((error, req, res, next) => {
    if (error instanceof URIError || error.type === "entity.parse.failed") {
        return res.status(400).json({ success: false, message: "Invalid offer ID or JSON request." });
    }
    if (error.type === "entity.too.large") {
        return res.status(413).json({ success: false, message: "Moderation request is too large." });
    }
    return next(error);
});

module.exports = router;
