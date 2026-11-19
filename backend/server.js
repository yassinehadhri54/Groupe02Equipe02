
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
const paymentRoutes = require("./routes/paymentRoutes");

// Initialize Express
const app = express();

// ================================
// MIDDLEWARES
// ================================

app.use(cors());
app.use(express.json());

// ================================
// WELCOME ROUTE
// ================================

app.get("/", (req, res) => {
    res.status(200).json({
        success: true,
        message: "Welcome to CampusSave API!",
        version: "1.0.0"
    });
});

// ================================
// HEALTH CHECK
// ================================

app.get("/api/health", (req, res) => {
    res.status(200).json({
        success: true,
        message: "CampusSave Backend is running",
        timestamp: new Date().toISOString()
    });
});

// ================================
// FIREBASE CONNECTION TEST
// ================================

app.get("/api/firebase-test", async (req, res) => {
    try {
        await db.listCollections();

        return res.status(200).json({
            success: true,
            message: "Firebase connected successfully!"
        });

    } catch (error) {
        console.error("Firebase test error:", error);

        return res.status(500).json({
            success: false,
            message: "Firebase connection failed."
        });
    }
});

// ================================
// API ROUTES
// ================================

app.use("/api/auth", authRoutes);
app.use("/api/users", userRoutes);
app.use("/api/shops", shopRoutes);
app.use("/api/offers", offerRoutes);
app.use("/api/reservations", reservationRoutes);
app.use("/api/payments", paymentRoutes);

// ================================
// 404 - ROUTE NOT FOUND
// ================================

app.use((req, res) => {
    return res.status(404).json({
        success: false,
        message: "Route not found."
    });
});

// ================================
// GLOBAL ERROR HANDLER
// ================================

app.use((error, req, res, next) => {
    console.error("Global server error:", error);

    if (res.headersSent) {
        return next(error);
    }

    return res.status(500).json({
        success: false,
        message: "Internal server error."
    });
});

// ================================
// START SERVER
// ================================

const PORT = process.env.PORT || 5000;

app.listen(PORT, () => {
    console.log("----------------------------------");
    console.log("       CAMPUSSAVE BACKEND");
    console.log("----------------------------------");

    console.log(`Server running on port ${PORT}`);
    console.log(`Local URL: http://localhost:${PORT}`);

    console.log("----------------------------------");
    console.log("API ROUTES:");
    console.log("----------------------------------");

    console.log("Authentication: /api/auth");
    console.log("Users:          /api/users");
    console.log("Shops:          /api/shops");
    console.log("Offers:         /api/offers");
    console.log("Reservations:   /api/reservations");
    console.log("Payments:       /api/payments");

    console.log("----------------------------------");
    console.log("Firebase:        Configured");
    console.log("Backend:         Ready");
    console.log("----------------------------------");
});
