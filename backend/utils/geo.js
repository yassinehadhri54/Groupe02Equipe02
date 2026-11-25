// Bonus "Campus Radar": positions and distances.

const EARTH_RADIUS_METERS = 6371008.8;

// A coordinate sent as a number or as a text ("36.8065"); anything else is refused.
const toCoordinate = (value) => {
    if (typeof value === "number") return value;

    if (typeof value === "string" && value.trim() !== "") {
        return Number(value);
    }

    return NaN;
};

// Validates a latitude / longitude pair. Both are required together.
// Returns { latitude, longitude } as numbers; throws a 400-style Error.
const parseCoordinates = (latitude, longitude) => {
    if (latitude === undefined || latitude === null || longitude === undefined || longitude === null) {
        throw new Error("latitude and longitude must be provided together.");
    }

    const lat = toCoordinate(latitude);
    const lng = toCoordinate(longitude);

    if (!Number.isFinite(lat) || lat < -90 || lat > 90) {
        throw new Error("latitude must be a number between -90 and 90.");
    }

    if (!Number.isFinite(lng) || lng < -180 || lng > 180) {
        throw new Error("longitude must be a number between -180 and 180.");
    }

    return { latitude: lat, longitude: lng };
};

const toRadians = (degrees) => (degrees * Math.PI) / 180;

// Distance in meters between two points (haversine formula).
const distanceMeters = (from, to) => {
    const dLat = toRadians(to.latitude - from.latitude);
    const dLng = toRadians(to.longitude - from.longitude);

    const a =
        Math.sin(dLat / 2) ** 2 +
        Math.cos(toRadians(from.latitude)) *
        Math.cos(toRadians(to.latitude)) *
        Math.sin(dLng / 2) ** 2;

    return 2 * EARTH_RADIUS_METERS * Math.asin(Math.min(1, Math.sqrt(a)));
};

module.exports = {
    parseCoordinates,
    distanceMeters
};
