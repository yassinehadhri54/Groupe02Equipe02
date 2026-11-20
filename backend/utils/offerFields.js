
// Offers in Firestore exist in two shapes:
//  - created by this backend:      status "available", name, discountPrice, imageURL, ownerId
//  - created by another client:    status "active",    title, discountedPrice, imageUrl, merchantId
// These helpers read both, so the API always returns the canonical fields
// (name, discountPrice, imageURL, ownerId) while keeping the original ones.

const { parsePickupTime } = require("./validation");

// Statuses that make an offer visible in the public listing.
const LISTED_OFFER_STATUSES = ["available", "active"];

const getOfferOwnerId = (offer) =>
    offer.ownerId ?? offer.merchantId ?? null;

const getOfferDiscountPrice = (offer) =>
    offer.discountPrice ?? offer.discountedPrice ?? null;

// An offer is expired when its pickup window has ended.
// Only dated windows ("YYYY-MM-DDTHH:MM") can expire; a time-only window
// ("HH:MM") is a daily pickup slot without a date, so it never expires.
// Dates without a timezone are read in the server's local time.
const isOfferExpired = (offer, now = Date.now()) => {
    const pickupEnd = parsePickupTime(offer.pickupEnd);
    return pickupEnd !== null && pickupEnd.kind === "datetime" && pickupEnd.value <= now;
};

const isOfferSoldOut = (offer) => {
    const available = Number(offer.availableQuantity);
    return !Number.isFinite(available) || available <= 0;
};

// Visible in the public listing and open for reservations.
const isOfferBookable = (offer, now = Date.now()) =>
    LISTED_OFFER_STATUSES.includes(offer.status) &&
    !isOfferExpired(offer, now) &&
    !isOfferSoldOut(offer);

const normalizeOffer = (id, data) => ({
    ...data,
    id,
    name: data.name ?? data.title ?? "",
    discountPrice: getOfferDiscountPrice(data),
    imageURL: data.imageURL ?? data.imageUrl ?? "",
    ownerId: getOfferOwnerId(data),
    isExpired: isOfferExpired(data),
    isSoldOut: isOfferSoldOut(data)
});

module.exports = {
    LISTED_OFFER_STATUSES,
    getOfferOwnerId,
    getOfferDiscountPrice,
    isOfferExpired,
    isOfferSoldOut,
    isOfferBookable,
    normalizeOffer
};
