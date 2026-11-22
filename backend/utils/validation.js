
// Shared input validation helpers.

const isHttpUrl = (value) => {
    if (typeof value !== "string" || value.length > 2048) return false;

    try {
        const url = new URL(value);
        return url.protocol === "http:" || url.protocol === "https:";
    } catch {
        return false;
    }
};

const isNonEmptyText = (value, maxLength = 100) =>
    typeof value === "string" &&
    value.trim().length > 0 &&
    value.trim().length <= maxLength;

// Pickup hours are stored either as "HH:MM" or as "YYYY-MM-DDTHH:MM"
// (HTML datetime-local), depending on the client.
const TIME_PATTERN = /^([01]\d|2[0-3]):([0-5]\d)$/;
const DATETIME_PATTERN = /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}/;

const parsePickupTime = (value) => {
    if (typeof value !== "string") return null;

    const time = value.match(TIME_PATTERN);
    if (time) {
        return { kind: "time", value: Number(time[1]) * 60 + Number(time[2]) };
    }

    if (DATETIME_PATTERN.test(value)) {
        const millis = Date.parse(value);
        if (Number.isFinite(millis)) {
            return { kind: "datetime", value: millis };
        }
    }

    return null;
};

// Throws a 400-style Error when the pickup window is invalid.
// A dated window must also end in the future (an offer cannot be created
// or moved to a pickup time that is already over).
const validatePickupWindow = (pickupStart, pickupEnd, now = Date.now()) => {
    const start = parsePickupTime(pickupStart);
    const end = parsePickupTime(pickupEnd);

    if (!start || !end) {
        throw new Error("Pickup hours must use HH:MM or YYYY-MM-DDTHH:MM format.");
    }

    if (start.kind !== end.kind) {
        throw new Error("pickupStart and pickupEnd must use the same format.");
    }

    if (start.value >= end.value) {
        throw new Error("pickupStart must be earlier than pickupEnd.");
    }

    if (end.kind === "datetime" && end.value <= now) {
        throw new Error("pickupEnd must be in the future.");
    }
};

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
const PHONE_PATTERN = /^\+?[0-9]{8,15}$/;

// Optional long text (descriptions): a string of at most maxLength characters.
const isOptionalText = (value, maxLength = 1000) =>
    value === undefined ||
    value === null ||
    (typeof value === "string" && value.trim().length <= maxLength);

// Shop form (registration and update). Returns the cleaned fields and throws
// a 400-style Error on invalid input. partial = true for an update, where
// only the provided fields are checked.
const validateShopFields = (data, { partial = false } = {}) => {
    const clean = {};

    const requireText = (field, min, max) => {
        const value = data[field];

        if (value === undefined && partial) return;

        if (typeof value !== "string" || value.trim().length < min || value.trim().length > max) {
            throw new Error(`${field} must be a text of ${min} to ${max} characters.`);
        }

        clean[field] = value.trim();
    };

    requireText("name", 2, 100);
    requireText("address", 2, 200);

    if (data.phone !== undefined || !partial) {
        const phone = typeof data.phone === "string" || typeof data.phone === "number"
            ? String(data.phone).replace(/\s+/g, "")
            : "";

        if (!PHONE_PATTERN.test(phone)) {
            throw new Error("phone must contain 8 to 15 digits (optional leading +).");
        }

        clean.phone = phone;
    }

    if (data.email !== undefined && data.email !== null && data.email !== "") {
        if (typeof data.email !== "string" || !EMAIL_PATTERN.test(data.email.trim())) {
            throw new Error("email must be a valid email address.");
        }

        clean.email = data.email.trim().toLowerCase();
    }

    if (data.description !== undefined) {
        if (!isOptionalText(data.description)) {
            throw new Error("description must be a text of at most 1000 characters.");
        }

        clean.description = (data.description || "").trim();
    }

    return clean;
};

module.exports = {
    EMAIL_PATTERN,
    isHttpUrl,
    isNonEmptyText,
    isOptionalText,
    parsePickupTime,
    validatePickupWindow,
    validateShopFields
};
