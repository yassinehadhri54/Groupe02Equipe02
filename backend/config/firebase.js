
require("dotenv").config();

const { initializeApp, applicationDefault } = require("firebase-admin/app");
const { getFirestore } = require("firebase-admin/firestore");
const { getAuth } = require("firebase-admin/auth");

// Initialize Firebase Admin
const firebaseApp = initializeApp({
    credential: applicationDefault()
});

// Firebase services
const db = getFirestore(firebaseApp);
const auth = getAuth(firebaseApp);

console.log("Firebase Admin SDK initialized successfully!");

module.exports = {
    firebaseApp,
    db,
    auth
};
