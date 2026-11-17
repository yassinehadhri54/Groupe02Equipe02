
const verifyRole = (...allowedRoles) => {
    return (req, res, next) => {
        try {
            // 1. Check authentication
            if (!req.user) {
                return res.status(401).json({
                    success: false,
                    message: "Authentication required."
                });
            }

            // 2. Check user role
            if (!allowedRoles.includes(req.user.role)) {
                return res.status(403).json({
                    success: false,
                    message: "Access denied. Insufficient permissions."
                });
            }

            // 3. Allow access
            next();

        } catch (error) {
            console.error("Authorization error:", error.message);

            return res.status(500).json({
                success: false,
                message: "Authorization error."
            });
        }
    };
};

module.exports = { verifyRole };
