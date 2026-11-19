
const paymentService = require("../services/paymentService");

const getUserId = (req) => req.user?.uid || req.user?.userId || null;

const isStudent = (req) => req.user?.role === "student";

const getErrorStatus = (error) => {
    const message = error.message || "";

    if (message.includes("not found")) return 404;
    if (
        message.includes("not allowed") ||
        message.includes("not authorized")
    ) return 403;
    if (
        message.includes("already") ||
        message.includes("in progress") ||
        message.includes("not eligible") ||
        message.includes("not pending") ||
        message.includes("not available") ||
        message.includes("must be") ||
        message.includes("status is invalid")
    ) return 409;
    if (
        message.includes("required") ||
        message.includes("Invalid") ||
        message.includes("invalid") ||
        message.includes("disabled")
    ) return 400;

    return 500;
};

// POST /api/payments/initiate
const initiatePayment = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can initiate payments."
            });
        }

        const studentId = getUserId(req);
        const { reservationId } = req.body;

        if (!reservationId) {
            return res.status(400).json({
                success: false,
                message: "Reservation ID is required."
            });
        }

        const payment = await paymentService.createPayment(
            studentId,
            reservationId
        );

        return res.status(payment.reused ? 200 : 201).json({
            success: true,
            message: payment.reused
                ? "Existing payment retrieved successfully."
                : "Payment initiated successfully.",
            data: payment
        });
    } catch (error) {
        console.error("Initiate payment error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to initiate payment."
        });
    }
};

// POST /api/payments/:id/verify
const verifyPayment = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can verify payments."
            });
        }

        const studentId = getUserId(req);
        const paymentId = req.params.id;

        const result = await paymentService.verifyKonnectPayment(
            studentId,
            paymentId
        );

        return res.status(200).json({
            success: true,
            message: result.message,
            data: result
        });
    } catch (error) {
        console.error("Verify payment error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to verify payment."
        });
    }
};

// POST /api/payments/:id/confirm-mock
const confirmMockPayment = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can confirm mock payments."
            });
        }

        const studentId = getUserId(req);
        const paymentId = req.params.id;

        const result = await paymentService.confirmMockPayment(
            studentId,
            paymentId
        );

        return res.status(200).json({
            success: true,
            message: result.message,
            data: result
        });
    } catch (error) {
        console.error("Mock payment confirmation error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to confirm mock payment."
        });
    }
};

// GET /api/payments/:id
const getPayment = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can access their payments."
            });
        }

        const studentId = getUserId(req);
        const paymentId = req.params.id;

        const payment = await paymentService.getPaymentById(
            studentId,
            paymentId
        );

        return res.status(200).json({
            success: true,
            message: "Payment retrieved successfully.",
            data: payment
        });
    } catch (error) {
        console.error("Get payment error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to retrieve payment."
        });
    }
};

// GET /api/payments/my-payments
const getMyPayments = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can access their payments."
            });
        }

        const studentId = getUserId(req);

        const payments = await paymentService.getMyPayments(studentId);

        return res.status(200).json({
            success: true,
            message: "Payments retrieved successfully.",
            data: payments
        });
    } catch (error) {
        console.error("Get my payments error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to retrieve payments."
        });
    }
};

module.exports = {
    initiatePayment,
    verifyPayment,
    confirmMockPayment,
    getPayment,
    getMyPayments
};
