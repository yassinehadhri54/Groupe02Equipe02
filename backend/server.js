
const express = require("express");
const cors = require("cors");
require("dotenv").config();

const { db } = require("./config/firebase");

// Import routes
const authRoutes = require("./routes/authRoutes");
const userRoutes = require("./routes/userRoutes");
const shopRoutes = require("./routes/shopRoutes");
const offerRoutes = require("./routes/offerRoutes");
const reservationRoutes = require("./routes/reservationRoutes");

const app = express();

// Middlewares
app.use(cors());
app.use(express.json());

// Welcome route
app.get("/", (req, res) => {
    res.json({
        success: true,
        message: "Welcome to CampusSave API!"
    });
});

// Health check
app.get("/api/health", (req, res) => {
    res.json({
        success: true,
        message: "CampusSave Backend is running"
    });
});

// Test Firestore
app.get("/api/firebase-test", async (req, res) => {
    try {
        await db.listCollections();

        res.json({
            success: true,
            message: "Firebase connected successfully!"
        });
    } catch (error) {
        res.status(500).json({
            success: false,
            message: error.message
        });
    }
});

// Mount routes
app.use("/api/auth", authRoutes);
app.use("/api/users", userRoutes);
app.use("/api/shops", shopRoutes);
app.use("/api/offers", offerRoutes);
app.use("/api/reservations", reservationRoutes);

// Start server
const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log(`CampusSave API running on port ${PORT}`);
    console.log("Auth routes mounted successfully!");
    console.log("User routes mounted successfully!");
    console.log("Shop routes mounted successfully!");
    console.log("Offer routes mounted successfully!");
    console.log("Reservation routes mounted successfully!");
});
