// Offline test: notificationService + reservation notification wrappers,
// with a fake Firestore, fake FieldValue and fake FCM. No network.
const Module = require("module");
const path = require("path");
const assert = require("assert");
const BACKEND = path.join(__dirname, "..");

// ---------- fake Firestore ----------
const store = {};
let autoId = 0;
const coll = (n) => (store[n] ||= {});
const getPath = (obj, p) => p.split(".").reduce((o, k) => (o == null ? undefined : o[k]), obj);
const applyUpdate = (target, data) => {
    for (const [k, v] of Object.entries(data)) {
        if (v && v.__inc !== undefined) { target[k] = (target[k] || 0) + v.__inc; continue; }
        if (v && v.__remove) { target[k] = (target[k] || []).filter((x) => !v.__remove.includes(x)); continue; }
        if (k.includes(".")) { const [a, b] = k.split("."); target[a] = { ...(target[a] || {}), [b]: v }; }
        else target[k] = v;
    }
};
const snap = (n, id) => { const d = coll(n)[id]; return { id, exists: !!d, data: () => (d ? JSON.parse(JSON.stringify(d)) : undefined), ref: docRef(n, id) }; };
const docRef = (n, id) => ({
    id, _n: n,
    async get() { return snap(n, id); },
    async update(data) { if (!coll(n)[id]) throw new Error("NOT_FOUND"); applyUpdate(coll(n)[id], data); },
    async set(data) { coll(n)[id] = JSON.parse(JSON.stringify(data)); }
});
const query = (n, f = [], lim = Infinity) => ({
    where: (p, op, v) => query(n, [...f, [p, op, v]], lim),
    limit: (k) => query(n, f, k),
    async get() {
        const docs = Object.keys(coll(n)).filter((id) => f.every(([p, op, v]) => {
            const val = getPath(coll(n)[id], p);
            return op === "==" ? val === v : op === "in" ? v.includes(val) : false;
        })).slice(0, lim).map((id) => snap(n, id));
        return { empty: !docs.length, docs };
    }
});
const db = {
    collection: (n) => ({ ...query(n), doc: (id) => docRef(n, id || "auto" + ++autoId), async add(d) { const id = "auto" + ++autoId; coll(n)[id] = JSON.parse(JSON.stringify(d)); return docRef(n, id); } }),
    async runTransaction(fn) {
        const w = [];
        const tx = { get: (x) => x.get(), update: (r, d) => w.push(() => applyUpdate(coll(r._n)[r.id], d)), set: (r, d, o) => w.push(() => { if (o && o.merge) { coll(r._n)[r.id] ||= {}; applyUpdate(coll(r._n)[r.id], d); } else coll(r._n)[r.id] = JSON.parse(JSON.stringify(d)); }) };
        const res = await fn(tx); w.forEach((x) => x()); return res;
    }
};
const FieldValue = { serverTimestamp: () => "TS", arrayRemove: (...v) => ({ __remove: v }), increment: (n) => ({ __inc: n }) };

// ---------- fake FCM ----------
const fcm = { calls: [], invalid: new Set() };
const fakeMessaging = {
    async sendEachForMulticast(msg) {
        fcm.calls.push(msg);
        const responses = msg.tokens.map((t) => fcm.invalid.has(t)
            ? { success: false, error: { code: "messaging/registration-token-not-registered" } }
            : { success: true });
        return { successCount: responses.filter((r) => r.success).length, failureCount: responses.filter((r) => !r.success).length, responses };
    }
};

const orig = Module._load;
Module._load = function (req) {
    if (req === "../config/firebase") return { db, firebaseApp: {} };
    if (req === "firebase-admin/firestore") return { FieldValue };
    if (req === "firebase-admin/messaging") return { getMessaging: () => fakeMessaging };
    return orig.apply(this, arguments);
};

const notif = require(path.join(BACKEND, "services", "notificationService.js"));
const reservations = require(path.join(BACKEND, "services", "reservationService.js"));
const userService = require(path.join(BACKEND, "services", "userService.js"));

const flush = () => new Promise((r) => setTimeout(r, 50));
const stored = (uid) => Object.values(coll("notifications")).filter((n) => n.userId === uid);
const rejects = async (p, re) => { try { await p; } catch (e) { assert.match(e.message, re); return; } throw new Error("expected " + re); };
const T = (i) => "token-" + String(i).padStart(20, "x");

(async () => {
    let n = 0; const ok = (m) => console.log(`ok ${++n} - ${m}`);

    coll("users").stu = { role: "student", status: "active" };
    coll("users").mer = { role: "merchant", status: "active" };
    coll("shops").shop1 = { ownerId: "mer", name: "Campus Food", status: "approved" };
    coll("offers").off1 = { ownerId: "mer", shopId: "shop1", name: "Sandwich", status: "available", originalPrice: 8, discountPrice: 4, quantity: 10, availableQuantity: 10 };

    // ---- tokens ----
    await rejects(notif.registerToken("stu", "short"), /valid FCM token/);
    await rejects(notif.registerToken("stu", undefined), /valid FCM token/);
    await notif.registerToken("stu", T(1));
    await notif.registerToken("stu", T(1));
    assert.deepStrictEqual(coll("users").stu.fcmTokens, [T(1)]);
    ok("register token: validation, no duplicates");

    for (let i = 2; i <= 12; i++) await notif.registerToken("stu", T(i));
    assert.strictEqual(coll("users").stu.fcmTokens.length, 10);
    assert.ok(!coll("users").stu.fcmTokens.includes(T(1)) && coll("users").stu.fcmTokens.includes(T(12)));
    ok("register token: keeps only the 10 latest devices");

    await notif.removeToken("stu", T(12));
    assert.ok(!coll("users").stu.fcmTokens.includes(T(12)));
    ok("remove token (logout)");

    const pub = await userService.getUserById("stu");
    assert.ok(!("fcmTokens" in pub));
    assert.ok((await userService.getAllUsers()).every((u) => !("fcmTokens" in u)));
    ok("device tokens hidden from user API responses");

    // ---- notifyUser ----
    coll("users").stu.fcmTokens = [T(100), T(101)];
    fcm.invalid.add(T(101));
    const r1 = await notif.notifyUser("stu", { type: "test", title: "Hi", body: "B", data: { reservationId: 42 } });
    assert.strictEqual(r1.stored, true);
    assert.strictEqual(r1.sent, 1);
    assert.strictEqual(r1.removedTokens, 1);
    assert.deepStrictEqual(coll("users").stu.fcmTokens, [T(100)]);
    assert.strictEqual(fcm.calls.at(-1).data.reservationId, "42");
    ok("notifyUser: stored, pushed, invalid token removed, data values are strings");

    const r2 = await notif.notifyUser("mer", { type: "t", title: "x", body: "y" });
    assert.strictEqual(r2.stored, true); assert.strictEqual(r2.sent, 0);
    ok("notifyUser without device: stored for in-app list, no push");

    const saved = fakeMessaging.sendEachForMulticast;
    fakeMessaging.sendEachForMulticast = async () => { throw new Error("FCM down"); };
    const r3 = await notif.notifyUser("stu", { type: "t", title: "x", body: "y" });
    assert.strictEqual(r3.stored, true);
    fakeMessaging.sendEachForMulticast = saved;
    ok("notifyUser never throws when FCM fails");

    // ---- in-app list / read ----
    const list = await notif.getMyNotifications("stu");
    assert.ok(list.length >= 2 && list.every((x) => x.title));
    await rejects(notif.markAsRead("mer", list[0].id), /not allowed/);
    await rejects(notif.markAsRead("stu", "nope"), /not found/);
    await notif.markAsRead("stu", list[0].id);
    assert.strictEqual(coll("notifications")[list[0].id].read, true);
    ok("in-app list, mark as read only by owner");

    // ---- reservation events ----
    const before = (uid) => stored(uid).length;
    let m0 = before("mer"), s0 = before("stu");

    const res = await reservations.createReservation("stu", "off1", 2);
    await flush();
    assert.strictEqual(before("mer"), m0 + 1);
    assert.strictEqual(stored("mer").at(-1).type, "reservation_created");
    assert.match(stored("mer").at(-1).body, /2 × Sandwich — 8 TND/);
    ok("create reservation -> merchant notified once");

    await rejects(reservations.updateReservationStatus("mer", res.reservationId, "confirmed"), /paid/);
    await flush();
    assert.strictEqual(before("stu"), s0);
    ok("failed operation -> no notification");

    coll("reservations")[res.reservationId].paymentStatus = "paid";
    await reservations.updateReservationStatus("mer", res.reservationId, "confirmed");
    await flush();
    assert.strictEqual(before("stu"), s0 + 1);
    assert.strictEqual(stored("stu").at(-1).type, "reservation_confirmed");
    ok("merchant confirms -> student notified");

    const qr = await reservations.generateReservationQR("stu", res.reservationId);
    const qrToken = Buffer.from(qr.qrCode.split(",")[1], "base64"); // image, not the token
    assert.ok(qrToken.length > 0);
    // Recover the raw token: regenerate with a known token by reading the hash is impossible,
    // so call verify with a token we control by patching the stored hash.
    const crypto = require("crypto");
    const raw = qr.token;
    assert.match(raw, /^[a-f0-9]{64}$/);
    assert.strictEqual(coll("reservations")[res.reservationId].qr.tokenHash, crypto.createHash("sha256").update(raw).digest("hex"));
    assert.ok(!JSON.stringify(coll("reservations")[res.reservationId]).includes(raw));
    const ecoBefore = coll("users").stu?.ecoPoints || 0;
    const done = await reservations.verifyReservationQR("mer", raw);
    await flush();
    assert.strictEqual(stored("stu").at(-1).type, "reservation_completed");
    assert.strictEqual(done.ecoPointsEarned, 20);
    assert.strictEqual(coll("users").stu.ecoPoints, ecoBefore + 20);
    assert.strictEqual(coll("reservations")[res.reservationId].ecoPointsEarned, 20);
    assert.match(stored("stu").at(-1).body, /\+20 EcoPoints/);
    await rejects(reservations.verifyReservationQR("mer", raw), /already been used/);
    await flush();
    assert.strictEqual(stored("stu").filter((x) => x.type === "reservation_completed").length, 1);
    assert.strictEqual(coll("users").stu.ecoPoints, ecoBefore + 20);
    ok("QR pickup -> student notified once, +20 EcoPoints for 2 items (reuse refused, no duplicate points)");

    const res2 = await reservations.createReservation("stu", "off1", 1);
    await reservations.updateReservationStatus("mer", res2.reservationId, "rejected");
    await flush();
    assert.strictEqual(stored("stu").at(-1).type, "reservation_rejected");
    ok("merchant rejects -> student notified");

    const res3 = await reservations.createReservation("stu", "off1", 1);
    m0 = before("mer");
    await reservations.cancelReservation("stu", res3.reservationId);
    await flush();
    assert.strictEqual(before("mer"), m0 + 1);
    assert.strictEqual(stored("mer").at(-1).type, "reservation_cancelled");
    ok("student cancels -> merchant notified");

    console.log(`\nALL ${n} TESTS PASSED`);
    process.exit(0);
})().catch((e) => { console.error("TEST FAILED:", e); process.exit(1); });
