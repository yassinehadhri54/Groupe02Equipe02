
const axios = require("axios");
const { auth, db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const { removeToken } = require("./notificationService");

// Register
const registerUser = async ({ fullName, email, password, role }) => {
    const userRecord = await auth.createUser({
        email,
        password,
        displayName: fullName,
        emailVerified: false
    });

    try {
        const userProfile = {
            uid: userRecord.uid,
            fullName,
            email,
            role,
            status: role === "merchant" ? "pending" : "active",
            createdAt: FieldValue.serverTimestamp()
        };

        await db.collection("users")
            .doc(userRecord.uid)
            .set(userProfile);

        return {
            uid: userRecord.uid,
            fullName,
            email,
            role,
            status: userProfile.status
        };
    } catch (error) {
        await auth.deleteUser(userRecord.uid);
        throw error;
    }
};

// Login
const loginUser = async ({ email, password }) => {
    const apiKey = process.env.FIREBASE_WEB_API_KEY;

    if (!apiKey) {
        throw new Error("FIREBASE_WEB_API_KEY is missing.");
    }

    const response = await axios.post(
        `https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=${apiKey}`,
        {
            email,
            password,
            returnSecureToken: true
        }
    );

    const { localId, idToken, refreshToken, expiresIn } = response.data;

    const userProfile = await getUserProfile(localId);

    if (!userProfile) {
        throw new Error("USER_PROFILE_NOT_FOUND");
    }

    return {
        uid: localId,
        email: userProfile.email,
        fullName: userProfile.fullName,
        role: userProfile.role,
        status: userProfile.status,
        idToken,
        refreshToken,
        expiresIn
    };
};

// Get Profile
const getUserProfile = async (uid) => {
    const userDoc = await db.collection("users").doc(uid).get();

    if (!userDoc.exists) {
        return null;
    }

    // Device tokens (FCM) are never returned by the API.
    const { fcmTokens, ...profile } = userDoc.data();

    return profile;
};

// Logout
// Firebase ID tokens are stateless, so logout really invalidates the session by
// revoking the user's refresh tokens. verifyToken checks revocation, so ID tokens
// issued before this moment are refused. This signs the user out on ALL devices.
// The client must also delete its stored tokens.
const logoutUser = async (uid, fcmToken) => {
    // Stop push notifications on this device (optional).
    if (fcmToken) {
        try {
            await removeToken(uid, fcmToken);
        } catch (error) {
            console.error("Logout FCM token removal error:", error.message);
        }
    }

    await auth.revokeRefreshTokens(uid);

    return {
        uid,
        revokedAt: new Date().toISOString()
    };
};

module.exports = {
    registerUser,
    loginUser,
    getUserProfile,
    logoutUser
};
