const offerService = require("../services/offerService");
const { isDocumentId, isNonEmptyText } = require("../utils/validation");

const textFilters = ["q", "category", "status"];
const allowedFilters = new Set([...textFilters, "adminDisabled"]);
const invalid = (res, message) => res.status(400).json({ success: false, message });

const getAdminOffers = async (req, res) => {
    const query = req.query;
    if (Object.keys(query).some(key => !allowedFilters.has(key))) {
        return invalid(res, "Unsupported offer filter.");
    }

    const filters = {};
    for (const key of textFilters) {
        const value = query[key];
        if (value === undefined) continue;
        if (!isNonEmptyText(value)) {
            return invalid(res, `${key} must be text of 1 to 100 characters.`);
        }
        filters[key] = value.trim();
    }
    if (query.adminDisabled !== undefined) {
        if (!["true", "false"].includes(query.adminDisabled)) {
            return invalid(res, "adminDisabled must be true or false.");
        }
        filters.adminDisabled = query.adminDisabled === "true";
    }

    try {
        const data = await offerService.getAdminOffers(filters);
        return res.json({ success: true, count: data.length, data, ...(req.path === "/admin/all" ? { offers: data } : {}) });
    } catch (error) {
        console.error("Admin offer listing failed:", error.code || error.name);
        return res.status(500).json({ success: false, message: "Could not retrieve offers." });
    }
};

const withOffer = (load, failureMessage) => async (req, res) => {
    if (!isDocumentId(req.params.id)) {
        return invalid(res, "A valid offer ID is required.");
    }
    try {
        const data = await load(req);
        if (data === null) {
            return res.status(404).json({ success: false, message: "Offer not found." });
        }
        return res.json({ success: true, data });
    } catch (error) {
        console.error("Admin offer operation failed:", error.code || error.name);
        return res.status(500).json({ success: false, message: failureMessage });
    }
};

const getAdminOffer = withOffer(
    req => offerService.getAdminOffer(req.params.id),
    "Could not retrieve offer."
);

const saveModeration = withOffer(
    req => offerService.setAdminOfferModeration(req.params.id, req.user.uid, {
        adminDisabled: req.body.adminDisabled,
        reason: req.body.reason?.trim()
    }),
    "Could not update offer moderation."
);

const updateModeration = (req, res) => {
    const body = req.body;
    if (!body || Array.isArray(body) || typeof body !== "object" ||
        typeof body.adminDisabled !== "boolean" ||
        Object.keys(body).some(key => key !== "adminDisabled" && key !== "reason")) {
        return invalid(res, "Expected a boolean adminDisabled and an optional reason.");
    }
    if (body.reason !== undefined && !isNonEmptyText(body.reason, 500)) {
        return invalid(res, "reason must be text of 1 to 500 characters.");
    }
    return saveModeration(req, res);
};

module.exports = { getAdminOffers, getAdminOffer, updateModeration };
