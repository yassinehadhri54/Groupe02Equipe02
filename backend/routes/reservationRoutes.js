
const express = require("express");
const router = express.Router();

const { verifyToken } = require("../middlewares/authMiddleware");
const { verifyRole } = require("../middlewares/roleMiddleware");

const reservationController = require("../controllers/reservationController");

// Student routes
router.post(
    "/",
    verifyToken,
    verifyRole("student"),
    reservationController.createReservation
);

router.get(
    "/my-reservations",
    verifyToken,
    verifyRole("student"),
    reservationController.getMyReservations
);

router.put(
    "/:id/cancel",
    verifyToken,
    verifyRole("student"),
    reservationController.cancelReservation
);

// Merchant routes
router.get(
    "/merchant",
    verifyToken,
    verifyRole("merchant"),
    reservationController.getMerchantReservations
);

router.put(
    "/:id/status",
    verifyToken,
    verifyRole("merchant"),
    reservationController.updateReservationStatus
);

module.exports = router;
