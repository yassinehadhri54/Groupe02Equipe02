
// Offers in Firestore exist in two shapes:
//  - created by this backend:      status "available", name, discountPrice, imageURL, ownerId
//  - created by another client:    status "active",    title, discountedPrice, imageUrl, merchantId
// These helpers read both, so the API always returns the canonical fields
// (name, discountPrice, imageURL, ownerId) while keeping the original ones.

// Statuses that make an offer visible in the public listing.
const LISTED_OFFER_STATUSES = ["available", "active"];

const getOfferOwnerId = (offer) =>
    offer.ownerId ?? offer.merchantId ?? null;

const getOfferDiscountPrice = (offer) =>
    offer.discountPrice ?? offer.discountedPrice ?? null;

const normalizeOffer = (id, data) => ({
    ...data,
    id,
    name: data.name ?? data.title ?? "",
    discountPrice: getOfferDiscountPrice(data),
    imageURL: data.imageURL ?? data.imageUrl ?? "",
    ownerId: getOfferOwnerId(data)
});

module.exports = {
    LISTED_OFFER_STATUSES,
    getOfferOwnerId,
    getOfferDiscountPrice,
    normalizeOffer
};
