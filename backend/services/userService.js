
const { db, auth } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const { isHttpUrl } = require("../utils/validation");

const httpError = (statusCode, message) => {
    const error = new Error(message);
    error.statusCode = statusCode;
    return error;
};

// Device tokens (FCM) are never returned by the API.
const toPublicUser = (doc) => {
    const { fcmTokens, ...data } = doc.data();

    return {
        uid: doc.id,
        ...data
    };
};

// Get user profile from Firestore
const getUserById = async (uid) => {
    if (typeof uid !== "string" || uid.trim() === "" || uid.includes("/")) {
        throw httpError(400, "Invalid user ID.");
    }

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        throw httpError(404, "User not found.");
    }

    return toPublicUser(userDoc);
};

// Validate and clean the fields a user may change on their own profile.
// role, status, uid and email can never be changed here.
const validateProfileUpdate = (updateData = {}) => {
    const cleanData = {};

    // "name" is accepted for older clients; the stored field is "fullName".
    const fullName = updateData.fullName ?? updateData.name;

    if (fullName !== undefined) {
        if (typeof fullName !== "string" || fullName.trim().length < 2 || fullName.trim().length > 100) {
            throw httpError(400, "Full name must contain between 2 and 100 characters.");
        }
        cleanData.fullName = fullName.trim();
    }

    if (updateData.phone !== undefined) {
        const phone = String(updateData.phone).replace(/\s+/g, "");

        if (!/^\+?[0-9]{8,15}$/.test(phone)) {
            throw httpError(400, "Phone number must contain 8 to 15 digits (optional leading +).");
        }
        cleanData.phone = phone;
    }

    if (updateData.photoURL !== undefined) {
        const photoURL = updateData.photoURL;

        if (photoURL !== "" && !isHttpUrl(photoURL)) {
            throw httpError(400, "photoURL must be a valid http(s) URL.");
        }
        cleanData.photoURL = photoURL;
    }

    if (Object.keys(cleanData).length === 0) {
        throw httpError(400, "No valid fields provided for update. Allowed: fullName, phone, photoURL.");
    }

    return cleanData;
};

// Update user profile
const updateUserProfile = async (uid, updateData) => {
    const cleanData = validateProfileUpdate(updateData || {});

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        throw httpError(404, "User not found.");
    }

    await userRef.update({
        ...cleanData,
        updatedAt: FieldValue.serverTimestamp()
    });

    // Keep the Firebase Auth display name in sync (non-blocking on failure).
    if (cleanData.fullName) {
        try {
            await auth.updateUser(uid, { displayName: cleanData.fullName });
        } catch (error) {
            console.error("Auth displayName update error:", error.message);
        }
    }

    return await getUserById(uid);
};

// Suspend or reactivate a user (Admin only)
//  - suspend:    Firebase Auth account disabled + sessions revoked (no login,
//                existing tokens refused), status "suspended"; a merchant's
//                shop is suspended too, so its offers disappear and cannot be reserved.
//  - reactivate: previous statuses restored, Auth account enabled.
const setUserStatus = async (adminUid, targetUid, newStatus) => {
    if (!["active", "suspended"].includes(newStatus)) {
        throw httpError(400, 'Status must be "active" or "suspended".');
    }

    if (targetUid === adminUid) {
        throw httpError(400, "You cannot change your own status.");
    }

    const userRef = db.collection("users").doc(targetUid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        throw httpError(404, "User not found.");
    }

    const user = userDoc.data();

    if (user.role === "admin") {
        throw httpError(400, "Admin accounts cannot be suspended.");
    }

    if (newStatus === "suspended" && user.status === "suspended") {
        throw httpError(409, "User is already suspended.");
    }

    if (newStatus === "active" && user.status !== "suspended") {
        throw httpError(409, "Only suspended users can be reactivated.");
    }

    let shopRef = null;
    if (user.role === "merchant") {
        const shopSnapshot = await db.collection("shops")
            .where("ownerId", "==", targetUid)
            .limit(1)
            .get();
        shopRef = shopSnapshot.empty ? null : shopSnapshot.docs[0].ref;
    }

    // Suspension: block Firebase Auth first, so the user is locked out
    // immediately even if the Firestore update fails.
    if (newStatus === "suspended") {
        await auth.updateUser(targetUid, { disabled: true });
        await auth.revokeRefreshTokens(targetUid);
    }

    try {
        await db.runTransaction(async (transaction) => {
            const freshUser = (await transaction.get(userRef)).data();
            const shopDoc = shopRef ? await transaction.get(shopRef) : null;
            const shop = shopDoc && shopDoc.exists ? shopDoc.data() : null;

            if (newStatus === "suspended") {
                transaction.update(userRef, {
                    status: "suspended",
                    statusBeforeSuspension: freshUser.status,
                    suspendedAt: FieldValue.serverTimestamp(),
                    updatedAt: FieldValue.serverTimestamp()
                });

                if (shop && shop.status !== "suspended") {
                    transaction.update(shopRef, {
                        status: "suspended",
                        statusBeforeSuspension: shop.status,
                        updatedAt: FieldValue.serverTimestamp()
                    });
                }
            } else {
                transaction.update(userRef, {
                    status: freshUser.statusBeforeSuspension || "active",
                    statusBeforeSuspension: FieldValue.delete(),
                    suspendedAt: FieldValue.delete(),
                    updatedAt: FieldValue.serverTimestamp()
                });

                if (shop && shop.status === "suspended") {
                    transaction.update(shopRef, {
                        status: shop.statusBeforeSuspension || "approved",
                        statusBeforeSuspension: FieldValue.delete(),
                        updatedAt: FieldValue.serverTimestamp()
                    });
                }
            }
        });
    } catch (error) {
        // Undo the Auth change so Auth and Firestore stay consistent.
        if (newStatus === "suspended") {
            try {
                await auth.updateUser(targetUid, { disabled: false });
            } catch (rollbackError) {
                console.error("Suspension rollback error:", rollbackError.message);
            }
        }
        throw error;
    }

    if (newStatus === "active") {
        await auth.updateUser(targetUid, { disabled: false });
    }

    return getUserById(targetUid);
};

// Get all users (Admin only)
const getAllUsers = async () => {
    const usersSnapshot = await db.collection("users").get();

    return usersSnapshot.docs.map(toPublicUser);
};

module.exports = {
    getUserById,
    updateUserProfile,
    getAllUsers,
    setUserStatus
};
