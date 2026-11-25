
const { auth, db } = require("../config/firebase");
const { measureFirestore, measureFirebaseAuth } = require("../utils/requestTiming");

const verifyToken = async (req, res, next) => {
    try {
        // 1. Get token from Authorization header
        const authHeader = req.headers.authorization;

        if (!authHeader || !authHeader.startsWith("Bearer ")) {
            return res.status(401).json({
                success: false,
                message: "Access denied. No token provided."
            });
        }

        // 2. Extract token
        const token = authHeader.split(" ")[1];

        if (!token) {
            return res.status(401).json({
                success: false,
                message: "Invalid authorization token."
            });
        }

        // 3. Verify Firebase ID Token.
        // checkRevoked = true: tokens issued before a logout
        // (revokeRefreshTokens) or for a disabled account are refused.
        const decodedToken = await measureFirebaseAuth(() => auth.verifyIdToken(token, true));

        // 4. Get user profile from Firestore
        const userDoc = await measureFirestore(() => db.collection("users").doc(decodedToken.uid).get());

        if (!userDoc.exists) {
            return res.status(404).json({
                success: false,
                message: "User profile not found."
            });
        }

        const userData = userDoc.data();

        // Suspended by an admin (the Firebase account is also disabled).
        if (userData.status === "suspended") {
            return res.status(403).json({
                success: false,
                message: "This account has been suspended."
            });
        }

        // 5. Attach user information to request
        // Pending merchants can authenticate and register their shop.
        req.user = {
            uid: decodedToken.uid,
            email: decodedToken.email,
            fullName: userData.fullName,
            role: userData.role,
            status: userData.status,
            ecoPoints: userData.ecoPoints ?? 0
        };

        next();

    } catch (error) {
        console.error("Authentication error:", error.code || error.name || "unknown");

        const messages = {
            "auth/id-token-expired": "Session expired. Please log in again.",
            "auth/id-token-revoked": "Session ended (logged out). Please log in again.",
            "auth/user-disabled": "This account has been disabled."
        };

        return res.status(401).json({
            success: false,
            message: messages[error.code] || "Invalid or expired token."
        });
    }
};

module.exports = { verifyToken };
