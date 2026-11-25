
const verifyActiveMerchant = (req, res, next) => {
    if (!req.user || req.user.role !== "merchant") {
        return res.status(403).json({
            success: false,
            message: "Accès réservé aux commerçants."
        });
    }

    if (req.user.status !== "active") {
        return res.status(403).json({
            success: false,
            message: "Votre compte commerçant doit être approuvé par un administrateur."
        });
    }

    next();
};

module.exports = { verifyActiveMerchant };
