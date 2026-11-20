
const { db } = require("../config/firebase");
const shopService = require("./shopService");
const offerService = require("./offerService");
const reservationService = require("./reservationService");
const { isOfferBookable, isOfferExpired, normalizeOffer } = require("../utils/offerFields");

// All statistics are computed from Firestore data at request time.
// Revenue and spending only count payments marked "paid", which the
// backend sets only after a verified (Konnect) or mock confirmation.

const RESERVATION_STATUSES = ["pending", "confirmed", "completed", "cancelled", "rejected"];
const CLOSED_RESERVATION_STATUSES = ["cancelled", "rejected"];
const FIRESTORE_IN_LIMIT = 30;
const RECENT_LIMIT = 5;
const TOP_OFFERS_LIMIT = 5;

// --------------------------------------------------
// HELPERS
// --------------------------------------------------

const roundMoney = (value) => Number(Number(value || 0).toFixed(3));

const toNumber = (value) => {
    const number = Number(value);
    return Number.isFinite(number) ? number : 0;
};

// createdAt can be a Firestore Timestamp or a string depending on the client.
const toMillis = (value) => {
    if (!value) return null;
    if (typeof value.toMillis === "function") return value.toMillis();
    if (typeof value === "number") return value;

    const parsed = Date.parse(value);
    return Number.isFinite(parsed) ? parsed : null;
};

const toISO = (value) => {
    const millis = toMillis(value);
    return millis === null ? null : new Date(millis).toISOString();
};

const countBy = (items, getKey, initialKeys = []) => {
    const counts = Object.fromEntries(initialKeys.map((key) => [key, 0]));

    for (const item of items) {
        const key = getKey(item) ?? "unknown";
        counts[key] = (counts[key] || 0) + 1;
    }

    return counts;
};

const sortNewestFirst = (items) =>
    [...items].sort(
        (a, b) => (toMillis(b.createdAt) ?? 0) - (toMillis(a.createdAt) ?? 0)
    );

// Listed = visible to students: listed status, not expired, not sold out.
const isListedOffer = (offer) => isOfferBookable(offer);

const summarizeReservation = (reservation) => ({
    reservationId: reservation.reservationId,
    offerId: reservation.offerId,
    offerName: reservation.offerName || "",
    shopName: reservation.shopName || "",
    quantity: toNumber(reservation.quantity),
    totalPrice: roundMoney(reservation.totalPrice),
    status: reservation.status,
    paymentStatus: reservation.paymentStatus,
    createdAt: toISO(reservation.createdAt)
});

const getDocsByIds = async (collectionName, ids) => {
    const uniqueIds = [...new Set(ids.filter(Boolean))];

    if (uniqueIds.length === 0) {
        return new Map();
    }

    const refs = uniqueIds.map((id) => db.collection(collectionName).doc(id));
    const snapshots = await db.getAll(...refs);

    return new Map(
        snapshots
            .filter((snapshot) => snapshot.exists)
            .map((snapshot) => [snapshot.id, snapshot.data()])
    );
};

// Paid payments for a list of reservations, keyed by reservationId.
const getPaidPaymentsByReservation = async (reservationIds) => {
    const uniqueIds = [...new Set(reservationIds.filter(Boolean))];
    const paidByReservation = new Map();

    for (let i = 0; i < uniqueIds.length; i += FIRESTORE_IN_LIMIT) {
        const batch = uniqueIds.slice(i, i + FIRESTORE_IN_LIMIT);

        const snapshot = await db.collection("payments")
            .where("reservationId", "in", batch)
            .get();

        snapshot.docs.forEach((doc) => {
            const payment = doc.data();

            if (payment.status === "paid") {
                paidByReservation.set(payment.reservationId, payment);
            }
        });
    }

    return paidByReservation;
};

const sumPaidByMode = (payments) => {
    const byMode = {};
    let total = 0;

    for (const payment of payments) {
        const amount = toNumber(payment.amount);
        const mode = payment.mode || "unknown";

        total += amount;
        byMode[mode] = roundMoney((byMode[mode] || 0) + amount);
    }

    return { total: roundMoney(total), byMode };
};

// --------------------------------------------------
// STUDENT DASHBOARD
// --------------------------------------------------

const getStudentDashboard = async (studentId) => {
    const reservations = await reservationService.getMyReservations(studentId);

    const completed = reservations.filter((r) => r.status === "completed");
    const paid = reservations.filter((r) => r.paymentStatus === "paid");

    // Savings use the offer's original price; the reservation stores the
    // price actually paid (unitPrice).
    const offers = await getDocsByIds(
        "offers",
        completed.map((r) => r.offerId)
    );

    let moneySaved = 0;
    let savingsUnavailableFor = 0;

    for (const reservation of completed) {
        const offer = offers.get(reservation.offerId);
        const originalPrice = Number(offer?.originalPrice);
        const unitPrice = Number(reservation.unitPrice);
        const quantity = Number(reservation.quantity);

        if (
            !Number.isFinite(originalPrice) ||
            !Number.isFinite(unitPrice) ||
            !Number.isFinite(quantity)
        ) {
            savingsUnavailableFor += 1;
            continue;
        }

        moneySaved += Math.max(0, originalPrice - unitPrice) * quantity;
    }

    return {
        reservations: {
            total: reservations.length,
            byStatus: countBy(reservations, (r) => r.status, RESERVATION_STATUSES)
        },
        spending: {
            totalPaid: roundMoney(
                paid.reduce((sum, r) => sum + toNumber(r.totalPrice), 0)
            ),
            paidReservations: paid.length
        },
        impact: {
            // Counted on completed (picked up) reservations only.
            itemsRescued: completed.reduce((sum, r) => sum + toNumber(r.quantity), 0),
            moneySaved: roundMoney(moneySaved),
            // Completed reservations whose offer no longer exists.
            savingsUnavailableFor
        },
        recentReservations: sortNewestFirst(reservations)
            .slice(0, RECENT_LIMIT)
            .map(summarizeReservation)
    };
};

// --------------------------------------------------
// MERCHANT DASHBOARD
// --------------------------------------------------

const getMerchantDashboard = async (merchantId) => {
    const [shop, offers, reservations] = await Promise.all([
        shopService.getMyShop(merchantId),
        offerService.getMyOffers(merchantId),
        reservationService.getMerchantReservations(merchantId)
    ]);

    const paidPayments = await getPaidPaymentsByReservation(
        reservations.map((r) => r.reservationId)
    );

    const completed = reservations.filter((r) => r.status === "completed");

    // Product performance: reservations that were not cancelled/rejected.
    const performance = new Map();

    for (const reservation of reservations) {
        if (CLOSED_RESERVATION_STATUSES.includes(reservation.status)) {
            continue;
        }

        const entry = performance.get(reservation.offerId) || {
            offerId: reservation.offerId,
            offerName: reservation.offerName || "",
            reservations: 0,
            quantityReserved: 0,
            paidRevenue: 0
        };

        entry.reservations += 1;
        entry.quantityReserved += toNumber(reservation.quantity);

        const payment = paidPayments.get(reservation.reservationId);
        if (payment) {
            entry.paidRevenue = roundMoney(entry.paidRevenue + toNumber(payment.amount));
        }

        performance.set(reservation.offerId, entry);
    }

    return {
        shop: shop
            ? { id: shop.id, name: shop.name, status: shop.status }
            : null,
        offers: {
            total: offers.length,
            listed: offers.filter(isListedOffer).length,
            soldOut: offers.filter((o) => toNumber(o.availableQuantity) <= 0).length,
            expired: offers.filter((o) => isOfferExpired(o)).length,
            byStatus: countBy(offers, (o) => o.status)
        },
        reservations: {
            total: reservations.length,
            byStatus: countBy(reservations, (r) => r.status, RESERVATION_STATUSES)
        },
        revenue: {
            // Sum of payments with status "paid" for this merchant's reservations.
            paid: sumPaidByMode([...paidPayments.values()]),
            paidReservations: paidPayments.size
        },
        itemsSold: completed.reduce((sum, r) => sum + toNumber(r.quantity), 0),
        topOffers: [...performance.values()]
            .sort((a, b) => b.quantityReserved - a.quantityReserved)
            .slice(0, TOP_OFFERS_LIMIT),
        recentReservations: sortNewestFirst(reservations)
            .slice(0, RECENT_LIMIT)
            .map(summarizeReservation)
    };
};

// --------------------------------------------------
// ADMIN DASHBOARD
// Aggregates only: no personal information is returned.
// --------------------------------------------------

const getAdminDashboard = async () => {
    const [usersSnap, shopsSnap, offersSnap, reservationsSnap, paymentsSnap] =
        await Promise.all(
            ["users", "shops", "offers", "reservations", "payments"].map(
                (name) => db.collection(name).get()
            )
        );

    const users = usersSnap.docs.map((doc) => doc.data());
    const shops = shopsSnap.docs.map((doc) => doc.data());
    const offers = offersSnap.docs.map((doc) => normalizeOffer(doc.id, doc.data()));
    const reservations = reservationsSnap.docs.map((doc) => doc.data());
    const payments = paymentsSnap.docs.map((doc) => doc.data());

    const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;

    return {
        users: {
            total: users.length,
            byRole: countBy(users, (u) => u.role, ["student", "merchant", "admin"]),
            byStatus: countBy(users, (u) => u.status)
        },
        shops: {
            total: shops.length,
            byStatus: countBy(shops, (s) => s.status, ["pending", "approved", "rejected"])
        },
        offers: {
            total: offers.length,
            listed: offers.filter(isListedOffer).length,
            byStatus: countBy(offers, (o) => o.status)
        },
        reservations: {
            total: reservations.length,
            byStatus: countBy(reservations, (r) => r.status, RESERVATION_STATUSES),
            last7Days: reservations.filter(
                (r) => (toMillis(r.createdAt) ?? 0) >= sevenDaysAgo
            ).length,
            itemsRescued: reservations
                .filter((r) => r.status === "completed")
                .reduce((sum, r) => sum + toNumber(r.quantity), 0)
        },
        payments: {
            total: payments.length,
            byStatus: countBy(payments, (p) => p.status),
            // "mock" amounts are test payments, not real money.
            paidVolume: sumPaidByMode(payments.filter((p) => p.status === "paid"))
        }
    };
};

module.exports = {
    getStudentDashboard,
    getMerchantDashboard,
    getAdminDashboard
};
