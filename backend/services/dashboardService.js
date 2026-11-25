
const { db } = require("../config/firebase");
const { measureFirestore } = require("../utils/requestTiming");
const offerService = require("./offerService");
const reservationService = require("./reservationService");
const {
    OFFER_TYPES,
    SURPRISE_BASKET,
    isOfferBookable,
    isOfferExpired,
    normalizeOffer
} = require("../utils/offerFields");

// All statistics are computed from Firestore data at request time.
// Revenue and spending only count payments marked "paid", which the
// backend sets only after a verified (Konnect) or mock confirmation.

const { buildImpact, toMillis } = require("./impact");
const { ECO_POINTS_PER_ITEM } = reservationService;

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

// Bonus Surprise Basket: baskets picked up, from completed reservations.
// Reservations made before this bonus have no offerType: they are standard.
const countBaskets = (completedReservations) =>
    completedReservations
        .filter((r) => r.offerType === SURPRISE_BASKET)
        .reduce((sum, r) => sum + toNumber(r.quantity), 0);

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

const getPaidPaymentsByReservation = async (reservationIds) => {
    const uniqueIds = [...new Set(reservationIds.filter(Boolean))];
    const paidByReservation = new Map();

    for (let i = 0; i < uniqueIds.length; i += FIRESTORE_IN_LIMIT) {
        const batch = uniqueIds.slice(i, i + FIRESTORE_IN_LIMIT);

        const snapshot = await measureFirestore(() => db.collection("payments").where("reservationId", "in", batch).get());

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

const getStudentDashboard = async (studentId, authenticatedEcoPoints) => {
    const [reservations, ecoPoints] = await Promise.all([
        reservationService.getMyReservations(studentId),
        authenticatedEcoPoints ?? measureFirestore(() => db.collection("users").doc(studentId).get())
            .then((profile) => profile.data()?.ecoPoints)
    ]);

    const completed = reservations.filter((r) => r.status === "completed");
    const paid = reservations.filter((r) => r.paymentStatus === "paid");

    const impact = buildImpact(completed);

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
            ...impact,
            // Counted on completed (picked up) reservations only.
            itemsRescued: completed.reduce((sum, r) => sum + toNumber(r.quantity), 0),
            moneySaved: impact.savings,
            surpriseBasketsRescued: countBaskets(completed),
            savingsUnavailableFor: impact.missingSavings
        },
        // Bonus EcoPoints: earned at each validated pickup.
        ecoPoints: {
            total: toNumber(ecoPoints),
            perItem: ECO_POINTS_PER_ITEM,
            history: completed
                .filter((reservation) => toNumber(reservation.ecoPointsEarned) > 0)
                .sort((a, b) => (toMillis(b.completedAt) ?? 0) - (toMillis(a.completedAt) ?? 0))
                .map((reservation) => ({
                    reservationId: reservation.reservationId,
                    date: toISO(reservation.completedAt),
                    points: reservation.ecoPointsEarned
                }))
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
    const [offers, { shop, reservations }] = await Promise.all([
        offerService.getMyOffers(merchantId),
        reservationService.getMerchantReservationContext(merchantId)
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
            byStatus: countBy(offers, (o) => o.status),
            byType: countBy(offers, (o) => o.offerType, OFFER_TYPES)
        },
        reservations: {
            total: reservations.length,
            byStatus: countBy(reservations, (r) => r.status, RESERVATION_STATUSES)
        },
        impact: buildImpact(completed),
        surpriseBasketsSold: countBaskets(completed),
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
                (name) => measureFirestore(() => db.collection(name).get())
            )
        );

    const users = usersSnap.docs.map((doc) => doc.data());
    const shops = shopsSnap.docs.map((doc) => doc.data());
    const offers = offersSnap.docs.map((doc) => normalizeOffer(doc.id, doc.data()));
    const reservations = reservationsSnap.docs.map((doc) => doc.data());
    const payments = paymentsSnap.docs.map((doc) => doc.data());

    const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;

    const completed = reservations.filter((r) => r.status === "completed");
    const impact = buildImpact(completed);

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
            // Deleted offers are kept only for the reservation history.
            total: offers.filter((o) => o.status !== "deleted").length,
            listed: offers.filter(isListedOffer).length,
            byStatus: countBy(offers, (o) => o.status),
            byType: countBy(
                offers.filter((o) => o.status !== "deleted"),
                (o) => o.offerType,
                OFFER_TYPES
            )
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
        },
        impact: {
            ...impact,
            itemsRescued: completed.reduce((sum, r) => sum + toNumber(r.quantity), 0),
            moneySaved: impact.savings,
            savingsUnavailableFor: impact.missingSavings,
            ecoPointsAwarded: completed.reduce((sum, r) => sum + toNumber(r.ecoPointsEarned), 0),
            surpriseBasketsRescued: countBaskets(completed),
            studentsInvolved: new Set(completed.map((r) => r.studentId)).size
        }
    };
};

module.exports = {
    getStudentDashboard,
    getMerchantDashboard,
    getAdminDashboard
};
