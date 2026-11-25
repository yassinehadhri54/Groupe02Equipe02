
const { db, auth } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const { isHttpUrl } = require("../utils/validation");
const { approveShop, rejectShop } = require("./shopService");

const usersCollection = db.collection("users");
const shopsCollection = db.collection("shops");

const httpError = (statusCode, message) => {
    const error = new Error(message);
    error.statusCode = statusCode;
    return error;
};

// Ne jamais exposer les tokens FCM dans les réponses API.
const toPublicUser = (doc) => {
    const { fcmTokens, ...data } = doc.data();

    return {
        uid: doc.id,
        ...data
    };
};

// Récupérer un utilisateur.
const getUserById = async (uid) => {
    if (
        typeof uid !== "string" ||
        uid.trim() === "" ||
        uid.includes("/")
    ) {
        throw httpError(400, "Invalid user ID.");
    }

    const userDoc = await usersCollection.doc(uid).get();

    if (!userDoc.exists) {
        throw httpError(404, "User not found.");
    }

    return toPublicUser(userDoc);
};

// Récupérer tous les utilisateurs.
const getAllUsers = async () => {
    const snapshot = await usersCollection.get();
    return snapshot.docs.map(toPublicUser);
};

// Récupérer les commerçants en attente.
const getPendingMerchants = async () => {
    const snapshot = await usersCollection
        .where("role", "==", "merchant")
        .where("status", "==", "pending")
        .get();

    return snapshot.docs.map(toPublicUser);
};

// Valider les informations modifiables du profil.
const validateProfileUpdate = (updateData = {}) => {
    const cleanData = {};

    // Compatibilité avec les anciens clients utilisant "name".
    const fullName = updateData.fullName ?? updateData.name;

    if (fullName !== undefined) {
        if (
            typeof fullName !== "string" ||
            fullName.trim().length < 2 ||
            fullName.trim().length > 100
        ) {
            throw httpError(
                400,
                "Full name must contain between 2 and 100 characters."
            );
        }

        cleanData.fullName = fullName.trim();
    }

    if (updateData.phone !== undefined) {
        const phone = String(updateData.phone).replace(/\s+/g, "");

        if (!/^\+?[0-9]{8,15}$/.test(phone)) {
            throw httpError(
                400,
                "Phone number must contain 8 to 15 digits."
            );
        }

        cleanData.phone = phone;
    }

    if (updateData.photoURL !== undefined) {
        const photoURL = updateData.photoURL;

        if (
            typeof photoURL !== "string" ||
            (photoURL !== "" && !isHttpUrl(photoURL))
        ) {
            throw httpError(400, "Invalid profile photo URL.");
        }

        cleanData.photoURL = photoURL;
    }

    if (Object.keys(cleanData).length === 0) {
        throw httpError(
            400,
            "No valid fields provided for update."
        );
    }

    return cleanData;
};

// Modifier son propre profil.
const updateUserProfile = async (uid, updateData) => {
    const cleanData = validateProfileUpdate(updateData || {});
    const userRef = usersCollection.doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        throw httpError(404, "User not found.");
    }

    await userRef.update({
        ...cleanData,
        updatedAt: FieldValue.serverTimestamp()
    });

    // Synchroniser le nom dans Firebase Authentication.
    if (cleanData.fullName) {
        try {
            await auth.updateUser(uid, {
                displayName: cleanData.fullName
            });
        } catch (error) {
            console.error(
                "Auth displayName update error:",
                error.message
            );
        }
    }

    return getUserById(uid);
};

// Rechercher les boutiques d'un commerçant.
// Compatibilité avec ownerId et merchantId.
const getMerchantShopDocuments = async (uid) => {
    const [ownerSnapshot, merchantSnapshot] = await Promise.all([
        shopsCollection.where("ownerId", "==", uid).get(),
        shopsCollection.where("merchantId", "==", uid).get()
    ]);

    const documents = new Map();

    [...ownerSnapshot.docs, ...merchantSnapshot.docs].forEach((doc) => {
        documents.set(doc.id, doc);
    });

    return [...documents.values()];
};

// Older clients review the merchant by UID. Use the same shop transaction.
const reviewPendingMerchant = async (uid, reviewShop) => {
    const shops = await getMerchantShopDocuments(uid);
    if (!shops.length) throw httpError(404, "Merchant shop not found.");
    if (shops.length !== 1) throw httpError(409, "Merchant has multiple shops.");
    try {
        await reviewShop(shops[0].id, uid);
    } catch (error) {
        if (error.message.startsWith("Only a pending")) throw httpError(409, error.message);
        if (error.message.endsWith("not found.")) throw httpError(404, error.message);
        throw error;
    }
    return getUserById(uid);
};

const approveMerchant = (uid) => reviewPendingMerchant(uid, approveShop);
const rejectMerchant = (uid) => reviewPendingMerchant(uid, rejectShop);

// Suspendre ou réactiver un utilisateur.
const setUserStatus = async (adminUid, targetUid, newStatus) => {
    if (!["active", "suspended"].includes(newStatus)) {
        throw httpError(
            400,
            'Status must be "active" or "suspended".'
        );
    }

    if (targetUid === adminUid) {
        throw httpError(400, "You cannot change your own status.");
    }

    const userRef = usersCollection.doc(targetUid);
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
        throw httpError(
            409,
            "Only suspended users can be reactivated."
        );
    }

    let shopRef = null;

    if (user.role === "merchant") {
        const shops = await getMerchantShopDocuments(targetUid);
        shopRef = shops.length > 0 ? shops[0].ref : null;
    }

    // Bloquer immédiatement l'accès Firebase Auth.
    if (newStatus === "suspended") {
        await auth.updateUser(targetUid, { disabled: true });
        await auth.revokeRefreshTokens(targetUid);
    }

    try {
        await db.runTransaction(async (transaction) => {
            const freshUserDoc = await transaction.get(userRef);

            if (!freshUserDoc.exists) {
                throw httpError(404, "User not found.");
            }

            const freshUser = freshUserDoc.data();

            // Lire la boutique avant toute écriture.
            const shopDoc = shopRef
                ? await transaction.get(shopRef)
                : null;

            const shop = shopDoc?.exists ? shopDoc.data() : null;

            if (newStatus === "suspended") {
                if (freshUser.status === "suspended") {
                    throw httpError(409, "User is already suspended.");
                }

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
                if (freshUser.status !== "suspended") {
                    throw httpError(
                        409,
                        "Only suspended users can be reactivated."
                    );
                }

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
        // Annuler le blocage Auth si la suspension Firestore échoue.
        if (newStatus === "suspended" && error.statusCode !== 409) {
            try {
                await auth.updateUser(targetUid, { disabled: false });
            } catch (rollbackError) {
                console.error(
                    "Suspension rollback error:",
                    rollbackError.message
                );
            }
        }

        throw error;
    }

    if (newStatus === "active") {
        await auth.updateUser(targetUid, { disabled: false });
    }

    return getUserById(targetUid);
};

module.exports = {
    getUserById,
    getAllUsers,
    getPendingMerchants,
    updateUserProfile,
    approveMerchant,
    rejectMerchant,
    setUserStatus
};
