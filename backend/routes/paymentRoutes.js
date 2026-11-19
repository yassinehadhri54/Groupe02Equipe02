
const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middlewares/authMiddleware");
const paymentController = require("../controllers/paymentController");

// Protect every payment endpoint
router.use(verifyToken);

// Student initiates a payment
router.post("/initiate", paymentController.initiatePayment);

// Student verifies a Sandbox payment
router.post("/:id/verify", paymentController.verifyPayment);

// Test-only Mock confirmation
router.post("/:id/confirm-mock", paymentController.confirmMockPayment);

// Get all payments belonging to the logged-in student
router.get("/my-payments", paymentController.getMyPayments);

// Get one payment
router.get("/:id", paymentController.getPayment);

module.exports = router;
