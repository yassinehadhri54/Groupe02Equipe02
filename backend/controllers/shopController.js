
const shopService = require("../services/shopService");
const { parseCoordinates } = require("../utils/geo");

const DEFAULT_RADIUS_KM = 2;
const MAX_RADIUS_KM = 50;
const DEFAULT_LIMIT = 50;
const MAX_LIMIT = 100;

// 404: shop/owner missing, 409: invalid status transition, 500: technical.
const getStatusChangeErrorCode = (error) => {
    if (error.code !== undefined) return 500;

    const message = error.message || "";

    if (message.includes("not found")) return 404;
    if (message.includes("already") || message.includes("cannot be")) return 409;

    return 500;
};

// Register a shop
const registerShop = async (req, res) => {
    try {
        const { name, address, phone, email, description, latitude, longitude } = req.body || {};

        if (!name || !address || !phone) {
            return res.status(400).json({
                success: false,
                message: "Name, address and phone are required."
            });
        }

        const shop = await shopService.createShop(
            req.user.uid,
            { name, address, phone, email, description, latitude, longitude }
        );

        return res.status(201).json({
            success: true,
            message: "Shop registered successfully. Waiting for admin approval.",
            data: shop
        });

    } catch (error) {
        console.error("Register shop error:", error.message);

        return res.status(400).json({
            success: false,
            message: error.message
        });
    }
};

// Get merchant's own shop
const getMyShop = async (req, res) => {
    try {
        const shop = await shopService.getMyShop(req.user.uid);

        if (!shop) {
            return res.status(404).json({
                success: false,
                message: "You have not registered a shop yet."
            });
        }

        return res.status(200).json({
            success: true,
            data: shop
        });

    } catch (error) {
        console.error("Get my shop error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Could not retrieve your shop."
        });
    }
};

// Update merchant's own shop
const updateMyShop = async (req, res) => {
    try {
        const shop = await shopService.updateMyShop(
            req.user.uid,
            req.body || {}
        );

        return res.status(200).json({
            success: true,
            message: "Shop updated successfully.",
            data: shop
        });

    } catch (error) {
        console.error("Update shop error:", error.message);

        const statusCode = error.message === "Shop not found." ? 404 : 400;

        return res.status(statusCode).json({
            success: false,
            message: error.message
        });
    }
};

// Get all shops (Admin)
const getAllShops = async (req, res) => {
    try {
        const status = req.query.status;

        const shops = await shopService.getAllShops(status);

        return res.status(200).json({
            success: true,
            count: shops.length,
            data: shops
        });

    } catch (error) {
        console.error("Get all shops error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Could not retrieve shops."
        });
    }
};

// Bonus Campus Radar: GET /api/shops/nearby?lat=&lng=&radius=&limit=&withOffers=
// Public, like the offer listing. radius is in km (default 2, at most 50).
const getNearbyShops = async (req, res) => {
    try {
        const { lat, lng, radius, limit, withOffers } = req.query;

        const isText = (value) => value === undefined || typeof value === "string";

        if (![lat, lng, radius, limit, withOffers].every(isText)) {
            return res.status(400).json({
                success: false,
                message: "Query parameters must be single values."
            });
        }

        let position;

        try {
            position = parseCoordinates(lat, lng);
        } catch (error) {
            return res.status(400).json({
                success: false,
                message: error.message.includes("provided together")
                    ? "lat and lng are required."
                    : error.message.replace("latitude", "lat").replace("longitude", "lng")
            });
        }

        const radiusKm = radius === undefined || radius === "" ? DEFAULT_RADIUS_KM : Number(radius);

        if (!Number.isFinite(radiusKm) || radiusKm <= 0 || radiusKm > MAX_RADIUS_KM) {
            return res.status(400).json({
                success: false,
                message: `radius must be a number of km between 0 and ${MAX_RADIUS_KM}.`
            });
        }

        const maxResults = limit === undefined || limit === "" ? DEFAULT_LIMIT : Number(limit);

        if (!Number.isInteger(maxResults) || maxResults < 1 || maxResults > MAX_LIMIT) {
            return res.status(400).json({
                success: false,
                message: `limit must be a whole number between 1 and ${MAX_LIMIT}.`
            });
        }

        const shops = await shopService.getNearbyShops({
            ...position,
            radiusKm,
            limit: maxResults,
            withOffers: withOffers === "true"
        });

        return res.status(200).json({
            success: true,
            count: shops.length,
            radiusKm,
            data: shops
        });

    } catch (error) {
        console.error("Nearby shops error:", error.message);

        return res.status(500).json({
            success: false,
            message: "Could not retrieve nearby shops."
        });
    }
};

// Approve shop (Admin)
const approveShop = async (req, res) => {
    try {
        const result = await shopService.approveShop(req.params.id);

        return res.status(200).json({
            success: true,
            message: "Shop approved successfully.",
            data: result
        });

    } catch (error) {
        console.error("Approve shop error:", error.message);

        const statusCode = getStatusChangeErrorCode(error);

        return res.status(statusCode).json({
            success: false,
            message: statusCode === 500 ? "Could not update shop status." : error.message
        });
    }
};

// Reject shop (Admin)
const rejectShop = async (req, res) => {
    try {
        const result = await shopService.rejectShop(req.params.id);

        return res.status(200).json({
            success: true,
            message: "Shop rejected successfully.",
            data: result
        });

    } catch (error) {
        console.error("Reject shop error:", error.message);

        const statusCode = getStatusChangeErrorCode(error);

        return res.status(statusCode).json({
            success: false,
            message: statusCode === 500 ? "Could not update shop status." : error.message
        });
    }
};

module.exports = {
    registerShop,
    getMyShop,
    updateMyShop,
    getAllShops,
    getNearbyShops,
    approveShop,
    rejectShop
};
