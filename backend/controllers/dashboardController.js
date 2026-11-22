
const dashboardService = require("../services/dashboardService");

const sendDashboard = (loader, label) => async (req, res) => {
    try {
        const data = await loader(req);

        return res.status(200).json({
            success: true,
            data
        });
    } catch (error) {
        console.error(`${label} dashboard error:`, error.message);

        return res.status(500).json({
            success: false,
            message: "Could not load dashboard statistics."
        });
    }
};

// GET /api/dashboard/student
const getStudentDashboard = sendDashboard(
    (req) => dashboardService.getStudentDashboard(req.user.uid),
    "Student"
);

// GET /api/dashboard/merchant
const getMerchantDashboard = sendDashboard(
    (req) => dashboardService.getMerchantDashboard(req.user.uid),
    "Merchant"
);

// GET /api/dashboard/admin
const getAdminDashboard = sendDashboard(
    () => dashboardService.getAdminDashboard(),
    "Admin"
);

module.exports = {
    getStudentDashboard,
    getMerchantDashboard,
    getAdminDashboard
};
