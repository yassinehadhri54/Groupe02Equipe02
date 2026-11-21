
const express = require("express");
const router = express.Router();

const {
    getStudentDashboard,
    getMerchantDashboard,
    getAdminDashboard
} = require("../controllers/dashboardController");

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");

router.get("/student", verifyToken, verifyRole("student"), getStudentDashboard);
router.get("/merchant", verifyToken, verifyRole("merchant"), getMerchantDashboard);
router.get("/admin", verifyToken, verifyRole("admin"), getAdminDashboard);

module.exports = router;
