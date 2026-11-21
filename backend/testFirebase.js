const { db } = require("./config/firebase");

async function testConnection() {
    try {
        await db.listCollections();
        console.log("Firebase Firestore connection successful!");
    } catch (error) {
        console.error("Firebase connection failed:", error.message);
    }
}

testConnection();