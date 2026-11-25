const { AsyncLocalStorage } = require("node:async_hooks");
const { performance } = require("node:perf_hooks");

const requestTiming = new AsyncLocalStorage();

const measure = async (kind, operation) => {
    const timing = requestTiming.getStore();
    if (!timing) return operation();

    const interval = { kind, start: performance.now(), end: null };
    timing.intervals.push(interval);
    try {
        return await operation();
    } finally {
        interval.end = performance.now();
    }
};

// Parallel reads contribute their elapsed time once, rather than a sum of RPC durations.
const elapsed = (intervals, now) => {
    let milliseconds = 0;
    let end = 0;
    for (const interval of intervals.toSorted((a, b) => a.start - b.start)) {
        const nextEnd = interval.end ?? now;
        milliseconds += Math.max(0, nextEnd - Math.max(end, interval.start));
        end = Math.max(end, nextEnd);
    }
    return milliseconds;
};

const serverTiming = (_req, res, next) => {
    if (process.env.API_SERVER_TIMING !== "1") return next();
    const start = performance.now();
    const intervals = [];
    const json = res.json;
    res.json = function (body) {
        const now = performance.now();
        const total = now - start;
        const upstream = elapsed(intervals, now);
        const durations = {
            server: total,
            express: Math.max(0, total - upstream),
            firestore: elapsed(intervals.filter(({ kind }) => kind === "firestore"), now),
            firebase_auth: elapsed(intervals.filter(({ kind }) => kind === "firebase_auth"), now)
        };
        this.setHeader("Server-Timing", Object.entries(durations)
            .map(([key, duration]) => key + ";dur=" + duration.toFixed(1)).join(", "));
        return json.call(this, body);
    };
    return requestTiming.run({ intervals }, next);
};

const measureFirestore = (operation) => measure("firestore", operation);
const measureFirebaseAuth = (operation) => measure("firebase_auth", operation);

module.exports = { serverTiming, measureFirestore, measureFirebaseAuth };
