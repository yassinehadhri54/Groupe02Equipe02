
const { db } = require("../config/firebase");

// Get user profile from Firestore
const getUserById = async (uid) => {
    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        throw new Error("User not found.");
    }

    return {
        uid: userDoc.id,
        ...userDoc.data()
    };
};

// Update user profile
const updateUserProfile = async (uid, updateData) => {
    const allowedFields = ["name", "phone", "photoURL"];

    const filteredData = {};

    for (const field of allowedFields) {
        if (updateData[field] !== undefined) {
            filteredData[field] = updateData[field];
        }
    }

    if (Object.keys(filteredData).length === 0) {
        throw new Error("No valid fields provided for update.");
    }

    filteredData.updatedAt = new Date();

    const userRef = db.collection("users").doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        throw new Error("User not found.");
    }

    await userRef.update(filteredData);

    return await getUserById(uid);
};

module.exports = {
    getUserById,
    updateUserProfile
};
