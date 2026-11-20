
const { getMessaging } = require("firebase-admin/messaging");
const { firebaseApp, db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");

const usersCollection = db.collection("users");
const notificationsCollection = db.collection("notifications");
const shopsCollection = db.collection("shops");

// Device tokens are stored on the user document: users/{uid}.fcmTokens
const MAX_TOKENS_PER_USER = 10;
const MAX_TOKEN_LENGTH = 4096;

// FCM errors meaning the token will never work again.
const INVALID_TOKEN_ERRORS = [
    "messaging/registration-token-not-registered",
    "messaging/invalid-registration-token",
    "messaging/invalid-argument"
];

let messagingInstance = null;
const getMessagingInstance = () => {
    if (!messagingInstance) {
        messagingInstance = getMessaging(firebaseApp);
    }
    return messagingInstance;
};

const validateToken = (token) => {
    if (
        typeof token !== "string" ||
        token.trim().length < 20 ||
        token.length > MAX_TOKEN_LENGTH
    ) {
        throw new Error("A valid FCM token is required.");
    }
    return token.trim();
};

// --------------------------------------------------
// DEVICE TOKENS (authenticated user only)
// --------------------------------------------------

const registerToken = async (uid, token) => {
    const cleanToken = validateToken(token);
    const userRef = usersCollection.doc(uid);

    await db.runTransaction(async (transaction) => {
        const userSnapshot = await transaction.get(userRef);

        if (!userSnapshot.exists) {
            throw new Error("User not found.");
        }

        const tokens = (userSnapshot.data().fcmTokens || [])
            .filter((existing) => existing !== cleanToken);

        // Most recent token last; keep only the latest devices.
        tokens.push(cleanToken);

        transaction.update(userRef, {
            fcmTokens: tokens.slice(-MAX_TOKENS_PER_USER),
            updatedAt: FieldValue.serverTimestamp()
        });
    });

    return { registered: true };
};

const removeToken = async (uid, token) => {
    const cleanToken = validateToken(token);

    await usersCollection.doc(uid).update({
        fcmTokens: FieldValue.arrayRemove(cleanToken),
        updatedAt: FieldValue.serverTimestamp()
    });

    return { removed: true };
};

// --------------------------------------------------
// SEND
// Never throws: a notification failure must not break a reservation
// or payment operation that already succeeded.
// --------------------------------------------------

const notifyUser = async (uid, { title, body, type, data = {} }) => {
    if (!uid) {
        return { stored: false, sent: 0 };
    }

    const result = { stored: false, sent: 0, failed: 0, removedTokens: 0 };

    // 1. Store the notification (in-app list for web and mobile)
    try {
        await notificationsCollection.add({
            userId: uid,
            type,
            title,
            body,
            data,
            read: false,
            createdAt: FieldValue.serverTimestamp()
        });
        result.stored = true;
    } catch (error) {
        console.error("Store notification error:", error.message);
    }

    // 2. Push to the user's devices
    try {
        const userSnapshot = await usersCollection.doc(uid).get();
        const tokens = userSnapshot.exists
            ? userSnapshot.data().fcmTokens || []
            : [];

        if (tokens.length === 0) {
            return result;
        }

        // FCM data values must be strings.
        const stringData = Object.fromEntries(
            Object.entries({ type, ...data }).map(([k, v]) => [k, String(v)])
        );

        const response = await getMessagingInstance().sendEachForMulticast({
            tokens,
            notification: { title, body },
            data: stringData
        });

        result.sent = response.successCount;
        result.failed = response.failureCount;

        const invalidTokens = response.responses
            .map((r, index) => (
                !r.success && INVALID_TOKEN_ERRORS.includes(r.error?.code)
                    ? tokens[index]
                    : null
            ))
            .filter(Boolean);

        if (invalidTokens.length > 0) {
            await usersCollection.doc(uid).update({
                fcmTokens: FieldValue.arrayRemove(...invalidTokens)
            });
            result.removedTokens = invalidTokens.length;
        }
    } catch (error) {
        console.error("Push notification error:", error.message);
    }

    return result;
};

// Notify the owner of a shop (merchant).
const notifyShopOwner = async (shopId, message) => {
    try {
        const shopSnapshot = await shopsCollection.doc(shopId).get();

        if (!shopSnapshot.exists) {
            return { stored: false, sent: 0 };
        }

        const shop = shopSnapshot.data();
        const ownerId = shop.ownerId || shop.merchantId || shop.userId;

        return notifyUser(ownerId, message);
    } catch (error) {
        console.error("Notify shop owner error:", error.message);
        return { stored: false, sent: 0 };
    }
};

// --------------------------------------------------
// IN-APP NOTIFICATIONS (authenticated user only)
// --------------------------------------------------

const getMyNotifications = async (uid) => {
    const snapshot = await notificationsCollection
        .where("userId", "==", uid)
        .get();

    return snapshot.docs
        .map((doc) => {
            const data = doc.data();
            return {
                id: doc.id,
                type: data.type,
                title: data.title,
                body: data.body,
                data: data.data || {},
                read: Boolean(data.read),
                createdAt: data.createdAt?.toDate
                    ? data.createdAt.toDate().toISOString()
                    : null
            };
        })
        .sort((a, b) => (b.createdAt || "").localeCompare(a.createdAt || ""))
        .slice(0, 50);
};

const markAsRead = async (uid, notificationId) => {
    const ref = notificationsCollection.doc(notificationId);
    const snapshot = await ref.get();

    if (!snapshot.exists) {
        throw new Error("Notification not found.");
    }

    if (snapshot.data().userId !== uid) {
        throw new Error("You are not allowed to update this notification.");
    }

    await ref.update({ read: true });

    return { id: notificationId, read: true };
};

module.exports = {
    registerToken,
    removeToken,
    notifyUser,
    notifyShopOwner,
    getMyNotifications,
    markAsRead
};
