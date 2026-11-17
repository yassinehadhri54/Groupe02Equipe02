
const express = require("express");
const cors = require("cors");
require("dotenv").config();

const { db } = require("./config/firebase");

const authRoutes = require("./routes/authRoutes");
const userRoutes = require("./routes/userRoutes");

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

// Authentication routes
app.use("/api/auth", authRoutes);

// User routes
app.use("/api/users", userRoutes);

// Start server
const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log(`CampusSave API running on port ${PORT}`);
    console.log("Auth routes mounted successfully!");
    console.log("User routes mounted successfully!");
});
