
const axios = require("axios");
const { auth, db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const { removeToken } = require("./notificationService");

// Register
const registerUser = async ({
    fullName,
    email,
    password,
    role,
    shop
}) => {
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
            // Bonus EcoPoints, earned when a pickup QR code is validated.
            ...(role === "student" ? { ecoPoints: 0 } : {}),
            createdAt: FieldValue.serverTimestamp()
        };

        const batch = db.batch();

        const userRef = db.collection("users").doc(userRecord.uid);

        batch.set(userRef, userProfile);

        let createdShopId = null;

        // Create the merchant's shop automatically.
        if (role === "merchant" && shop) {
            const shopRef = db.collection("shops").doc(userRecord.uid);

            createdShopId = shopRef.id;

            const shopData = {
                shopId: shopRef.id,
                ownerId: userRecord.uid,
                ownerName: fullName,
                ownerEmail: email,
                name: shop.name,
                address: shop.address,
                phone: shop.phone,
                email,
                description: shop.description || "",
                status: "pending",
                createdAt: FieldValue.serverTimestamp(),
                updatedAt: FieldValue.serverTimestamp()
            };

            batch.create(shopRef, shopData);
        }

        await batch.commit();

        return {
            uid: userRecord.uid,
            fullName,
            email,
            role,
            status: userProfile.status,
            ...(createdShopId && { shopId: createdShopId })
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

    // Never expose FCM device tokens through the API.
    const { fcmTokens, ...profile } = userDoc.data();

    return profile;
};

// Logout
// Revokes refresh tokens for all devices belonging to this user.
const logoutUser = async (uid, fcmToken) => {
    // Remove this device's notification token when provided.
    if (fcmToken) {
        try {
            await removeToken(uid, fcmToken);
        } catch (error) {
            console.error(
                "Logout FCM token removal error:",
                error.message
            );
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
