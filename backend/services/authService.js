
const axios = require("axios");
const { auth, db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");

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

    return userDoc.data();
};

module.exports = {
    registerUser,
    loginUser,
    getUserProfile
};
