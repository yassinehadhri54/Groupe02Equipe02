
const reservationService = require("../services/reservationService");

// Create reservation - Student
const createReservation = async (req, res) => {
    try {
        const { offerId, quantity } = req.body;

        if (!offerId || quantity === undefined) {
            return res.status(400).json({
                success: false,
                message: "Offer ID and quantity are required."
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

        const messages = [
            "Offer not found.",
            "This offer is not available.",
            "Not enough quantity available.",
            "Not enough offer quantity available.",
            "Quantity must be a positive integer.",
            "A valid offer ID is required.",
            "Invalid offer price.",
            "Offer information is incomplete."
        ];

        return res.status(messages.includes(error.message) ? 400 : 500).json({
            success: false,
            message: error.message || "Failed to create reservation."
        });
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

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve reservations."
        });
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

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve merchant reservations."
        });
    }
};


// Confirm, reject or complete reservation - Merchant
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

        const messages = [
            "Invalid reservation status.",
            "Reservation not found.",
            "Shop not found.",
            "You are not allowed to update this reservation.",
            "Only pending reservations can be confirmed.",
            "Only pending reservations can be rejected.",
            "Only confirmed reservations can be completed.",
            "Reservation must be paid before confirmation.",
            "Reservation must be paid before completion.",
            "Cannot reject a reservation while payment is in progress or paid.",
            "Offer not found."
        ];

        const statusCode = error.message === "Reservation not found."
            ? 404
            : messages.includes(error.message) ? 400 : 500;

        return res.status(statusCode).json({
            success: false,
            message: error.message || "Failed to update reservation."
        });
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

        const messages = [
            "You are not allowed to cancel this reservation.",
            "Only pending reservations can be cancelled.",
            "Offer not found.",
            "Invalid offer quantity."
        ];

        const statusCode = error.message === "Reservation not found."
            ? 404
            : messages.includes(error.message) ? 400 : 500;

        return res.status(statusCode).json({
            success: false,
            message: error.message || "Failed to cancel reservation."
        });
    }
};


module.exports = {
    createReservation,
    getMyReservations,
    getMerchantReservations,
    updateReservationStatus,
    cancelReservation
};
