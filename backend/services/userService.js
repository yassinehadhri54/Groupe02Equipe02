
const { db, auth } = require("../config/firebase");

// Get user profile from Firestore
const getUserById = async (uid) => {
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        const error = new Error("User not found.");
        error.statusCode = 404;
        throw error;
    }

    return {
        uid: userDoc.id,
        ...userDoc.data()
    };
};

// Get all users
const getAllUsers = async () => {
    const snapshot = await db.collection("users").get();

    return snapshot.docs.map(doc => ({
        uid: doc.id,
        ...doc.data()
    }));
};

// Get merchants pending approval
const getPendingMerchants = async () => {
    const snapshot = await db.collection("users")
        .where("role", "==", "merchant")
        .where("status", "==", "pending")
        .get();

    return snapshot.docs.map(doc => ({
        uid: doc.id,
        ...doc.data()
    }));
};

// Update connected user's profile
const updateUserProfile = async (uid, updateData) => {
    const allowedFields = ["name", "phone", "photoURL"];
    const filteredData = {};

    for (const field of allowedFields) {
        if (updateData[field] !== undefined) {
            filteredData[field] = updateData[field];
        }
    }

    if (Object.keys(filteredData).length === 0) {
        const error = new Error("No valid fields provided for update.");
        error.statusCode = 400;
        throw error;
    }

    filteredData.updatedAt = new Date();

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        const error = new Error("User not found.");
        error.statusCode = 404;
        throw error;
    }

    await userRef.update(filteredData);

    return await getUserById(uid);
};

// Approve merchant
const approveMerchant = async (uid) => {
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        const error = new Error("Merchant not found.");
        error.statusCode = 404;
        throw error;
    }

    const user = userDoc.data();

    if (user.role !== "merchant") {
        const error = new Error("This user is not a merchant.");
        error.statusCode = 400;
        throw error;
    }

    if (user.status !== "pending") {
        const error = new Error("This merchant is not pending approval.");
        error.statusCode = 400;
        throw error;
    }

    await userRef.update({
        status: "active",
        updatedAt: new Date()
    });

    return await getUserById(uid);
};

// Reject merchant
const rejectMerchant = async (uid) => {
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        const error = new Error("Merchant not found.");
        error.statusCode = 404;
        throw error;
    }

    const user = userDoc.data();

    if (user.role !== "merchant") {
        const error = new Error("This user is not a merchant.");
        error.statusCode = 400;
        throw error;
    }

    if (user.status !== "pending") {
        const error = new Error("This merchant is not pending approval.");
        error.statusCode = 400;
        throw error;
    }

    await userRef.update({
        status: "rejected",
        updatedAt: new Date()
    });

    return await getUserById(uid);
};

module.exports = {
    getUserById,
    updateUserProfile,
    getAllUsers,
    getPendingMerchants,
    approveMerchant,
    rejectMerchant
};
