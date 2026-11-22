
const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middlewares/authMiddleware");
const paymentController = require("../controllers/paymentController");

// Public Konnect notification (GET ?payment_ref=...).
// Must stay above router.use(verifyToken): Konnect sends no Firebase token.
router.get("/webhook", paymentController.konnectWebhook);

// Mock payment page (KONNECT_MOCK=true only): the payUrl of a mock payment.
// Public like the Konnect page: opened by the browser, without a token.
router.get("/mock-checkout/:paymentRef", paymentController.showMockCheckout);
router.post("/mock-checkout/:paymentRef/pay", paymentController.submitMockCheckout);

// Protect every other payment endpoint
router.use(verifyToken);

// Student initiates a payment: returns payUrl (Konnect page or mock page).
// "/initiate" is kept for existing clients and the Postman collection.
router.post("/init", paymentController.initiatePayment);
router.post("/initiate", paymentController.initiatePayment);

// Student asks the backend to check the payment status with Konnect
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
