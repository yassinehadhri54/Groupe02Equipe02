
const { db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const { validateShopFields } = require("../utils/validation");

const shopsCollection = db.collection("shops");
const usersCollection = db.collection("users");

// Create a new shop
const createShop = async (uid, rawShopData) => {
    const shopData = validateShopFields(rawShopData || {});

    const userRef = usersCollection.doc(uid);
    const userDoc = await userRef.get();

    if (!userDoc.exists) {
        throw new Error("User profile not found.");
    }

    const userData = userDoc.data();

    if (userData.role !== "merchant") {
        throw new Error("Only merchants can register a shop.");
    }

    if (userData.status === "rejected") {
        throw new Error("Your merchant account was rejected.");
    }

    // One shop per merchant. The new shop's document ID is the merchant's
    // uid, so two simultaneous registrations cannot both succeed: the
    // second create() fails because the document already exists.
    const shopRef = shopsCollection.doc(uid);
    const existingQuery = shopsCollection.where("ownerId", "==", uid).limit(1);

    const newShop = {
        shopId: shopRef.id,
        ownerId: uid,
        ownerName: userData.fullName,
        ownerEmail: userData.email,

        name: shopData.name,
        address: shopData.address,
        phone: shopData.phone,
        email: shopData.email || userData.email,
        description: shopData.description || "",

        status: "pending",
        createdAt: FieldValue.serverTimestamp(),
        updatedAt: FieldValue.serverTimestamp()
    };

    try {
        await db.runTransaction(async (transaction) => {
            // Shops created before this change have a random document ID.
            const [existingShops, existingDoc] = await Promise.all([
                transaction.get(existingQuery),
                transaction.get(shopRef)
            ]);

            if (!existingShops.empty || existingDoc.exists) {
                throw new Error("You have already registered a shop.");
            }

            transaction.create(shopRef, newShop);
        });
    } catch (error) {
        // ALREADY_EXISTS (gRPC code 6): a concurrent registration won.
        if (error.code === 6) {
            throw new Error("You have already registered a shop.");
        }

        throw error;
    }

    return {
        ...newShop,
        createdAt: null,
        updatedAt: null
    };
};

// Get merchant's own shop
const getMyShop = async (uid) => {
    const snapshot = await shopsCollection
        .where("ownerId", "==", uid)
        .limit(1)
        .get();

    if (snapshot.empty) {
        return null;
    }

    return {
        id: snapshot.docs[0].id,
        ...snapshot.docs[0].data()
    };
};

// Update merchant's own shop
const updateMyShop = async (uid, updateData) => {
    const snapshot = await shopsCollection
        .where("ownerId", "==", uid)
        .limit(1)
        .get();

    if (snapshot.empty) {
        throw new Error("Shop not found.");
    }

    const shopDoc = snapshot.docs[0];

    // Only these fields can be changed, each one validated like at registration.
    const allowedFields = ["name", "address", "phone", "email", "description"];
    const provided = {};

    allowedFields.forEach((field) => {
        if (updateData[field] !== undefined) {
            provided[field] = updateData[field];
        }
    });

    if (provided.email === "" || provided.email === null) {
        throw new Error("email must be a valid email address.");
    }

    const cleanData = validateShopFields(provided, { partial: true });

    if (Object.keys(cleanData).length === 0) {
        throw new Error("No valid fields provided for update.");
    }

    cleanData.updatedAt = FieldValue.serverTimestamp();

    await shopDoc.ref.update(cleanData);

    const updatedDoc = await shopDoc.ref.get();

    return {
        id: updatedDoc.id,
        ...updatedDoc.data()
    };
};

// Get all shops (Admin)
const getAllShops = async (status) => {
    let query = shopsCollection;

    if (status) {
        query = query.where("status", "==", status);
    }

    const snapshot = await query.get();

    return snapshot.docs.map((doc) => ({
        id: doc.id,
        ...doc.data()
    }));
};

// Change a shop's status and its owner's status together (Admin).
// A transaction guarantees the shop and the merchant account never
// end up in different states.
//   approve: pending | rejected -> approved, merchant -> active
//   reject:  pending | approved -> rejected, merchant -> rejected
const SHOP_TRANSITIONS = {
    approved: { from: ["pending", "rejected"], userStatus: "active" },
    rejected: { from: ["pending", "approved"], userStatus: "rejected" }
};

const changeShopStatus = async (shopId, newStatus) => {
    const transition = SHOP_TRANSITIONS[newStatus];
    const shopRef = shopsCollection.doc(shopId);

    return db.runTransaction(async (transaction) => {
        const shopDoc = await transaction.get(shopRef);

        if (!shopDoc.exists) {
            throw new Error("Shop not found.");
        }

        const shopData = shopDoc.data();

        if (shopData.status === newStatus) {
            throw new Error(`Shop is already ${newStatus}.`);
        }

        if (!transition.from.includes(shopData.status)) {
            throw new Error(`A ${shopData.status} shop cannot be ${newStatus}.`);
        }

        const ownerRef = usersCollection.doc(shopData.ownerId);
        const ownerDoc = await transaction.get(ownerRef);

        if (!ownerDoc.exists) {
            throw new Error("Shop owner not found.");
        }

        transaction.update(shopRef, {
            status: newStatus,
            updatedAt: FieldValue.serverTimestamp()
        });

        transaction.update(ownerRef, {
            status: transition.userStatus,
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            shopId,
            status: newStatus,
            previousStatus: shopData.status
        };
    });
};

// Approve a shop (Admin)
const approveShop = (shopId) => changeShopStatus(shopId, "approved");

// Reject a shop (Admin)
const rejectShop = (shopId) => changeShopStatus(shopId, "rejected");

module.exports = {
    createShop,
    getMyShop,
    updateMyShop,
    getAllShops,
    approveShop,
    rejectShop
};
