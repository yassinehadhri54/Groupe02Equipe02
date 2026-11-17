
const {
    getUserById,
    updateUserProfile,
    getAllUsers,
    getPendingMerchants,
    approveMerchant,
    rejectMerchant
} = require("../services/userService");

// GET connected user's profile
const getMyProfile = async (req, res) => {
    try {
        const user = await getUserById(req.user.uid);

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
        const user = await updateUserProfile(req.user.uid, req.body);

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

// GET one user (Admin only)
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

// GET pending merchants (Admin only)
const getPendingMerchantsController = async (req, res) => {
    try {
        const merchants = await getPendingMerchants();

        return res.status(200).json({
            success: true,
            count: merchants.length,
            merchants
        });
    } catch (error) {
        console.error("Get pending merchants error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Failed to retrieve pending merchants."
        });
    }
};

// APPROVE merchant (Admin only)
const approveMerchantController = async (req, res) => {
    try {
        const merchant = await approveMerchant(req.params.id);

        return res.status(200).json({
            success: true,
            message: "Merchant approved successfully.",
            merchant
        });
    } catch (error) {
        console.error("Approve merchant error:", error.message);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || "Failed to approve merchant."
        });
    }
};

// REJECT merchant (Admin only)
const rejectMerchantController = async (req, res) => {
    try {
        const merchant = await rejectMerchant(req.params.id);

        return res.status(200).json({
            success: true,
            message: "Merchant rejected successfully.",
            merchant
        });
    } catch (error) {
        console.error("Reject merchant error:", error.message);

        return res.status(error.statusCode || 500).json({
            success: false,
            message: error.message || "Failed to reject merchant."
        });
    }
};

module.exports = {
    getMyProfile,
    updateMyProfile,
    getUsers,
    getUser,
    getPendingMerchantsController,
    approveMerchantController,
    rejectMerchantController
};
