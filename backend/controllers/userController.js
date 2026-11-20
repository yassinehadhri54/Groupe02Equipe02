
const {
    getUserById,
    updateUserProfile,
    getAllUsers,
    setUserStatus
} = require("../services/userService");

// PUT /api/users/:id/status   { "status": "suspended" | "active" }  (Admin only)
const updateUserStatus = async (req, res) => {
    try {
        const user = await setUserStatus(
            req.user.uid,
            req.params.id,
            req.body?.status
        );

        return res.status(200).json({
            success: true,
            message: user.status === "suspended"
                ? "User suspended."
                : "User reactivated.",
            user
        });
    } catch (error) {
        console.error("Update user status error:", error.message);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.statusCode ? error.message : "Failed to update user status."
        });
    }
};

// GET connected user's profile
const getMyProfile = async (req, res) => {
    try {
        const uid = req.user.uid || req.user.sub;

        const user = await getUserById(uid);

        return res.status(200).json({
            success: true,
            message: "Profile retrieved successfully.",
            user
        });
    } catch (error) {
        console.error("Get profile error:", error.message);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || "Failed to retrieve profile."
        });
    }
};

// UPDATE connected user's profile
const updateMyProfile = async (req, res) => {
    try {
        const uid = req.user.uid || req.user.sub;

        const user = await updateUserProfile(uid, req.body || {});

        return res.status(200).json({
            success: true,
            message: "Profile updated successfully.",
            user
        });
    } catch (error) {
        console.error("Update profile error:", error.message);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || "Failed to update profile."
        });
    }
};

// GET all users (Admin only)
const getUsers = async (req, res) => {
    try {
        const users = await getAllUsers();

        return res.status(200).json({
            success: true,
            count: users.length,
            users
        });
    } catch (error) {
        console.error("Get users error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve users."
        });
    }
};

// GET one user by ID (Admin only)
const getUser = async (req, res) => {
    try {
        const user = await getUserById(req.params.id);

        return res.status(200).json({
            success: true,
            user
        });
    } catch (error) {
        console.error("Get user error:", error.message);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || "Failed to retrieve user."
        });
    }
};

module.exports = {
    getMyProfile,
    updateMyProfile,
    getUsers,
    getUser,
    updateUserStatus
};
