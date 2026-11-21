
const reservationService = require("../services/reservationService");

// Business errors thrown by the service are plain Errors with a message.
// Technical errors (Firestore errors carry a "code", programming errors are
// TypeError/ReferenceError) are reported as 500 without leaking details.
const sendError = (res, error, fallbackMessage) => {
    const isTechnical =
        error.code !== undefined ||
        error instanceof TypeError ||
        error instanceof ReferenceError ||
        error instanceof RangeError;

    if (isTechnical) {
        return res.status(500).json({
            success: false,
            message: fallbackMessage
        });
    }

    const message = error.message || fallbackMessage;
    let status = 400;

    if (message.includes("not found")) status = 404;
    else if (message.includes("not allowed")) status = 403;

    return res.status(status).json({
        success: false,
        message
    });
};

// Create reservation - Student
const createReservation = async (req, res) => {
    try {
        const { offerId, quantity } = req.body || {};

        if (!offerId || quantity === undefined) {
            return res.status(400).json({
                success: false,
                message: "Offer ID and quantity are required."
            });
        }

        if (typeof offerId !== "string" || offerId.includes("/")) {
            return res.status(400).json({
                success: false,
                message: "A valid offer ID is required."
            });
        }

        const reservation = await reservationService.createReservation(
            req.user.uid,
            offerId,
            quantity
        );

        return res.status(201).json({
            success: true,
            message: "Reservation created successfully.",
            data: reservation
        });

    } catch (error) {
        console.error("Create reservation error:", error);
        return sendError(res, error, "Failed to create reservation.");
    }
};


// Get student's reservations
const getMyReservations = async (req, res) => {
    try {
        const reservations = await reservationService.getMyReservations(
            req.user.uid
        );

        return res.status(200).json({
            success: true,
            count: reservations.length,
            data: reservations
        });

    } catch (error) {
        console.error("Get student reservations error:", error);
        return sendError(res, error, "Failed to retrieve reservations.");
    }
};


// Get merchant's reservations
const getMerchantReservations = async (req, res) => {
    try {
        const reservations = await reservationService.getMerchantReservations(
            req.user.uid
        );

        return res.status(200).json({
            success: true,
            count: reservations.length,
            data: reservations
        });

    } catch (error) {
        console.error("Get merchant reservations error:", error);
        return sendError(res, error, "Failed to retrieve merchant reservations.");
    }
};


// Confirm or reject reservation - Merchant
// (completion only happens through QR verification)
const updateReservationStatus = async (req, res) => {
    try {
        const { status } = req.body || {};

        if (!status) {
            return res.status(400).json({
                success: false,
                message: "Status is required."
            });
        }

        const result = await reservationService.updateReservationStatus(
            req.user.uid,
            req.params.id,
            status
        );

        return res.status(200).json({
            success: true,
            message: `Reservation ${status} successfully.`,
            data: result
        });

    } catch (error) {
        console.error("Update reservation error:", error);
        return sendError(res, error, "Failed to update reservation.");
    }
};


// Cancel reservation - Student
const cancelReservation = async (req, res) => {
    try {
        const result = await reservationService.cancelReservation(
            req.user.uid,
            req.params.id
        );

        return res.status(200).json({
            success: true,
            message: "Reservation cancelled successfully.",
            data: result
        });

    } catch (error) {
        console.error("Cancel reservation error:", error);
        return sendError(res, error, "Failed to cancel reservation.");
    }
};


// Generate QR Code - Student
const generateReservationQR = async (req, res) => {
    try {
        const result = await reservationService.generateReservationQR(
            req.user.uid,
            req.params.id
        );

        return res.status(200).json({
            success: true,
            message: "QR Code generated successfully.",
            data: result
        });
    } catch (error) {
        console.error("Generate QR error:", error);
        return sendError(res, error, "Failed to generate QR Code.");
    }
};


// Verify QR Code - Merchant
const verifyReservationQR = async (req, res) => {
    try {
        const { token } = req.body || {};

        if (!token) {
            return res.status(400).json({
                success: false,
                message: "QR Code token is required."
            });
        }

        const result = await reservationService.verifyReservationQR(
            req.user.uid,
            token
        );

        return res.status(200).json({
            success: true,
            message: "QR Code verified successfully.",
            data: result
        });
    } catch (error) {
        console.error("Verify QR error:", error);
        return sendError(res, error, "Failed to verify QR Code.");
    }
};

module.exports = {
    createReservation,
    getMyReservations,
    getMerchantReservations,
    updateReservationStatus,
    cancelReservation,
    generateReservationQR,
    verifyReservationQR
};
