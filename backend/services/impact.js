const DAY = 86_400_000;

const toMillis = (value) => {
    if (value == null) return null;
    const millis = typeof value.toMillis === "function" ? value.toMillis()
        : typeof value === "number" ? value : Date.parse(value);
    return Number.isFinite(millis) && Number.isFinite(new Date(millis).getTime())
        ? millis : null;
};

const emptyPeriod = () => ({
    recoveredOrders: 0, portions: 0, savings: 0, missingSavings: 0,
    participatingShops: new Set()
});

const summarize = ({ participatingShops, savings, ...counts }) => ({
    ...counts,
    savings: Number(savings.toFixed(3)),
    participatingShops: participatingShops.size
});

const dateKey = (date) => date.toISOString().slice(0, 10);

const add = (period, reservation) => {
    const quantity = Number(reservation.quantity);
    const original = Number(reservation.originalUnitPrice);
    const paid = Number(reservation.unitPrice);
    const validQuantity = Number.isSafeInteger(quantity) && quantity > 0;
    period.recoveredOrders++;
    if (validQuantity) period.portions += quantity;
    if (reservation.shopId) period.participatingShops.add(reservation.shopId);
    if (validQuantity && reservation.originalUnitPrice != null && Number.isFinite(original) && Number.isFinite(paid)
        && original >= paid && paid > 0) {
        period.savings += (original - paid) * quantity;
    } else {
        period.missingSavings++;
    }
};

// UTC calendar buckets, with Monday as the first day of the week.
const buildImpact = (reservations, now = Date.now()) => {
    const current = new Date(now);
    const today = Date.UTC(current.getUTCFullYear(), current.getUTCMonth(), current.getUTCDate());
    const weekStart = today - ((current.getUTCDay() + 6) % 7) * DAY;
    const weeks = new Map();
    const months = new Map();
    for (let offset = 7; offset >= 0; offset--) {
        weeks.set(dateKey(new Date(weekStart - offset * 7 * DAY)), emptyPeriod());
    }
    for (let offset = 5; offset >= 0; offset--) {
        months.set(dateKey(new Date(Date.UTC(current.getUTCFullYear(), current.getUTCMonth() - offset, 1))), emptyPeriod());
    }

    const total = emptyPeriod();
    let missingPickupDate = 0;
    for (const reservation of reservations) {
        if (reservation.status !== "completed") continue;
        add(total, reservation);
        const time = toMillis(reservation.completedAt);
        if (time === null || time > now) {
            missingPickupDate++;
            continue;
        }
        const date = new Date(time);
        const day = Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate());
        const monday = day - ((date.getUTCDay() + 6) % 7) * DAY;
        const week = weeks.get(dateKey(new Date(monday)));
        const month = months.get(dateKey(new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), 1))));
        if (week) add(week, reservation);
        if (month) add(month, reservation);
    }

    const series = (buckets) => [...buckets].map(([start, period]) => ({ start, ...summarize(period) }));
    return { ...summarize(total), missingPickupDate, weekly: series(weeks), monthly: series(months) };
};

module.exports = { buildImpact, toMillis };
