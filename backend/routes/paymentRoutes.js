
const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middlewares/authMiddleware");
const paymentController = require("../controllers/paymentController");

// Public Konnect notification (GET ?payment_ref=...).
// Must stay above router.use(verifyToken): Konnect sends no Firebase token.
router.get("/webhook", paymentController.konnectWebhook);

// Protect every other payment endpoint
router.use(verifyToken);

// Student initiates a payment
router.post("/initiate", paymentController.initiatePayment);

// Student verifies a Sandbox payment
router.post("/:id/verify", paymentController.verifyPayment);

// Student cancels a pending payment (mock: immediately;
// sandbox: only after the Konnect link expired unpaid)
router.post("/:id/cancel", paymentController.cancelPayment);

// Test-only Mock confirmation
router.post("/:id/confirm-mock", paymentController.confirmMockPayment);

// Get all payments belonging to the logged-in student
router.get("/my-payments", paymentController.getMyPayments);

// Get one payment
router.get("/:id", paymentController.getPayment);

module.exports = router;
