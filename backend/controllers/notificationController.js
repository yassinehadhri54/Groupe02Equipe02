
const notificationService = require("../services/notificationService");

const getErrorStatus = (error) => {
    const message = error.message || "";

    if (message.includes("not found")) return 404;
    if (message.includes("not allowed")) return 403;
    if (message.includes("required")) return 400;

    return 500;
};

const handle = (action, successMessage) => async (req, res) => {
    try {
        const data = await action(req);

        return res.status(200).json({
            success: true,
            ...(successMessage ? { message: successMessage } : {}),
            data
        });
    } catch (error) {
        console.error("Notification error:", error.message);

        const status = getErrorStatus(error);

        return res.status(status).json({
            success: false,
            message: status === 500 ? "Notification request failed." : error.message
        });
    }
};

// POST /api/notifications/token   { "token": "<FCM device token>" }
const registerToken = handle(
    (req) => notificationService.registerToken(req.user.uid, req.body?.token),
    "FCM token registered."
);

// DELETE /api/notifications/token { "token": "<FCM device token>" }
// Called on logout so the device stops receiving this user's notifications.
const removeToken = handle(
    (req) => notificationService.removeToken(req.user.uid, req.body?.token),
    "FCM token removed."
);

// GET /api/notifications
const getMyNotifications = handle(
    (req) => notificationService.getMyNotifications(req.user.uid)
);

// PUT /api/notifications/:id/read
const markAsRead = handle(
    (req) => notificationService.markAsRead(req.user.uid, req.params.id),
    "Notification marked as read."
);

module.exports = {
    registerToken,
    removeToken,
    getMyNotifications,
    markAsRead
};
