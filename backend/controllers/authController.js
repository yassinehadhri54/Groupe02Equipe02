
const {
    registerUser,
    loginUser,
    getUserProfile,
    logoutUser
} = require("../services/authService");

// Register
const register = async (req, res) => {
    try {
        const { fullName, email, password, role } = req.body;

        if (!fullName || !email || !password || !role) {
            return res.status(400).json({
                success: false,
                message: "All fields are required."
            });
        }

        const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

        if (!emailRegex.test(email)) {
            return res.status(400).json({
                success: false,
                message: "Invalid email format."
            });
        }

        if (password.length < 8) {
            return res.status(400).json({
                success: false,
                message: "Password must contain at least 8 characters."
            });
        }

        if (!["student", "merchant"].includes(role)) {
            return res.status(400).json({
                success: false,
                message: "Invalid role."
            });
        }

        const user = await registerUser({
            fullName,
            email,
            password,
            role
        });

        return res.status(201).json({
            success: true,
            message: "Account created successfully.",
            user
        });

    } catch (error) {
        console.error("Register error:", error.message);

        if (error.code === "auth/email-already-exists") {
            return res.status(409).json({
                success: false,
                message: "Email already exists."
            });
        }

        if (
            error.code === "auth/invalid-email" ||
            error.code === "auth/invalid-password"
        ) {
            return res.status(400).json({
                success: false,
                message: "Invalid email or password."
            });
        }

        return res.status(500).json({
            success: false,
            message: "Registration failed."
        });
    }
};

// Login
const login = async (req, res) => {
    try {
        const { email, password } = req.body;

        if (!email || !password) {
            return res.status(400).json({
                success: false,
                message: "Email and password are required."
            });
        }

        const result = await loginUser({ email, password });

        return res.status(200).json({
            success: true,
            message: "Login successful.",
            user: {
                uid: result.uid,
                email: result.email,
                fullName: result.fullName,
                role: result.role,
                status: result.status
            },
            tokens: {
                idToken: result.idToken,
                refreshToken: result.refreshToken,
                expiresIn: result.expiresIn
            }
        });

    } catch (error) {
        console.error("Login error:", error.response?.data || error.message);

        const firebaseError = error.response?.data?.error?.message;

        if (
            ["EMAIL_NOT_FOUND", "INVALID_PASSWORD",
             "INVALID_LOGIN_CREDENTIALS", "USER_DISABLED"].includes(firebaseError)
        ) {
            return res.status(401).json({
                success: false,
                message: "Invalid email or password."
            });
        }

        if (error.message === "USER_PROFILE_NOT_FOUND") {
            return res.status(404).json({
                success: false,
                message: "User profile not found."
            });
        }

        return res.status(500).json({
            success: false,
            message: "Login failed. Please try again."
        });
    }
};

// Get current user
const getMe = async (req, res) => {
    try {
        const user = await getUserProfile(req.user.uid);

        if (!user) {
            return res.status(404).json({
                success: false,
                message: "User profile not found."
            });
        }

        return res.status(200).json({
            success: true,
            user
        });

    } catch (error) {
        console.error("Get profile error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Could not retrieve user profile."
        });
    }
};

// Logout - POST /api/auth/logout   body (optional): { "fcmToken": "..." }
const logout = async (req, res) => {
    try {
        const result = await logoutUser(req.user.uid, req.body?.fcmToken);

        return res.status(200).json({
            success: true,
            message: "Logged out successfully. Sessions on all devices have been revoked.",
            data: result
        });

    } catch (error) {
        console.error("Logout error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Logout failed."
        });
    }
};

module.exports = {
    register,
    login,
    getMe,
    logout
};