// Offline tests for the fixes from the code review: offer update in a
// transaction, soft delete of offers, shop validation and single shop per
// merchant, empty maxPrice, registration name, payment recovery and
// payment error codes. Fake Firestore with optimistic transactions
// (a transaction is replayed when a document it read changed meanwhile).
const Module = require("module");
const path = require("path");
const assert = require("assert");
const BACKEND = path.join(__dirname, "..");

// ---------------- fake Firestore ----------------
const store = {};
let autoId = 0;
const coll = (name) => (store[name] ||= {});
const version = {};
const bump = (name, id) => { version[name + "/" + id] = (version[name + "/" + id] || 0) + 1; };
const ts = (ms) => ({ toMillis: () => ms, toDate: () => new Date(ms) });

const FieldValue = {
    serverTimestamp: () => ({ __ts: true }),
    increment: (n) => ({ __inc: n }),
    arrayRemove: (...v) => ({ __remove: v }),
    delete: () => ({ __delete: true })
};
const applyUpdate = (target, data) => {
    for (const [k, v] of Object.entries(data)) {
        if (v && v.__inc !== undefined) target[k] = (target[k] || 0) + v.__inc;
        else if (v && v.__ts) target[k] = ts(Date.now());
        else if (v && v.__delete) delete target[k];
        else target[k] = v;
    }
};
const snap = (name, id) => {
    const d = coll(name)[id];
    return { id, exists: !!d, data: () => (d ? { ...d } : undefined), ref: docRef(name, id) };
};
const docRef = (name, id) => ({
    id, _name: name,
    async get() { return snap(name, id); },
    async update(data) { if (!coll(name)[id]) throw new Error("NOT_FOUND"); applyUpdate(coll(name)[id], data); bump(name, id); },
    async set(data) { coll(name)[id] = {}; applyUpdate(coll(name)[id], data); bump(name, id); },
    async delete() { delete coll(name)[id]; bump(name, id); }
});
const query = (name, filters = [], lim = Infinity) => ({
    _query: true, _name: name,
    where: (f, op, v) => query(name, [...filters, [f, op, v]], lim),
    limit: (n) => query(name, filters, n),
    async get() {
        const docs = Object.keys(coll(name))
            .filter((id) => filters.every(([f, op, v]) => {
                const val = coll(name)[id][f];
                if (op === "==") return val === v;
                if (op === "in") return v.includes(val);
                throw new Error("op " + op);
            }))
            .slice(0, lim)
            .map((id) => snap(name, id));
        return { empty: docs.length === 0, docs, size: docs.length };
    }
});
// Hook called after a transaction reads a document (to simulate a
// concurrent write landing between the read and the commit).
let afterTxRead = null;
const db = {
    collection: (name) => ({ ...query(name), doc: (id) => docRef(name, id || "auto" + ++autoId) }),
    async getAll(...refs) { return refs.map((r) => snap(r._name, r.id)); },
    async runTransaction(fn) {
        for (let attempt = 0; attempt < 5; attempt++) {
            const reads = [];
            const writes = [];
            const tx = {
                async get(x) {
                    if (x._query) {
                        const r = await x.get();
                        r.docs.forEach((d) => reads.push([x._name, d.id, version[x._name + "/" + d.id] || 0]));
                        return r;
                    }
                    reads.push([x._name, x.id, version[x._name + "/" + x.id] || 0]);
                    const s = snap(x._name, x.id);
                    if (afterTxRead) { const hook = afterTxRead; afterTxRead = null; await hook(x); }
                    return s;
                },
                update(ref, data) { writes.push(() => { if (!coll(ref._name)[ref.id]) throw new Error("NOT_FOUND"); applyUpdate(coll(ref._name)[ref.id], data); bump(ref._name, ref.id); }); },
                set(ref, data, opts) { writes.push(() => { if (!(opts && opts.merge) || !coll(ref._name)[ref.id]) coll(ref._name)[ref.id] = {}; applyUpdate(coll(ref._name)[ref.id], data); bump(ref._name, ref.id); }); },
                create(ref, data) { writes.push(() => { if (coll(ref._name)[ref.id]) { const e = new Error("ALREADY_EXISTS"); e.code = 6; throw e; } coll(ref._name)[ref.id] = {}; applyUpdate(coll(ref._name)[ref.id], data); bump(ref._name, ref.id); }); }
            };
            const result = await fn(tx);
            const conflict = reads.some(([n, id, v]) => (version[n + "/" + id] || 0) !== v);
            if (conflict) continue; // replay, like Firestore
            writes.forEach((w) => w());
            return result;
        }
        throw new Error("Transaction aborted (too many conflicts)");
    }
};

const konnectConfig = { mode: "mock", baseURL: "https://fake", apiKey: "k", walletId: "w", webhookURL: null, publicBaseURL: "http://localhost:5000" };
const fakeNotif = { async notifyUser() {}, async notifyShopOwner() {} };

const origLoad = Module._load;
Module._load = function (request) {
    if (request === "../config/firebase") return { db, auth: {}, firebaseApp: {} };
    if (request === "../config/konnect") return konnectConfig;
    if (request === "firebase-admin/firestore") return { FieldValue, Timestamp: { fromMillis: ts } };
    if (request === "./notificationService") return fakeNotif;
    return origLoad.apply(this, arguments);
};

const offers = require(path.join(BACKEND, "services", "offerService.js"));
const reservations = require(path.join(BACKEND, "services", "reservationService.js"));
const shops = require(path.join(BACKEND, "services", "shopService.js"));
const payments = require(path.join(BACKEND, "services", "paymentService.js"));
const offerCtrl = require(path.join(BACKEND, "controllers", "offerController.js"));
const authCtrl = require(path.join(BACKEND, "controllers", "authController.js"));
const paymentCtrl = require(path.join(BACKEND, "controllers", "paymentController.js"));

const res = () => ({ code: 0, body: null, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; } });
const rejects = async (p, re) => {
    try { await p; } catch (e) { assert.match(e.message, re); return e; }
    throw new Error("expected rejection " + re);
};
const future = (h) => new Date(Date.now() + h * 3600000).toISOString().slice(0, 16);

(async () => {
    let n = 0;
    const ok = (m) => console.log(`ok ${++n} - ${m}`);

    // ---------- setup ----------
    coll("users").mer = { uid: "mer", role: "merchant", status: "active", fullName: "Malek", email: "m@x.tn" };
    coll("users").stu = { uid: "stu", role: "student", status: "active", fullName: "Test Student" };
    coll("shops").shop1 = { shopId: "shop1", ownerId: "mer", name: "Campus Food", status: "approved" };
    const base = { name: "Sandwich", category: "Repas", originalPrice: 10, discountPrice: 4, quantity: 5, pickupStart: future(1), pickupEnd: future(5), description: "Bon" };
    const offer = await offers.createOffer("mer", base);
    const offerId = offer.offerId;

    // ---------- 1. updateOffer in a transaction ----------
    afterTxRead = async (ref) => {
        // A student reserves 5 items between the merchant's read and write.
        if (ref._name === "offers") await reservations.createReservation("stu", offerId, 5);
    };
    const updated = await offers.updateOffer("mer", offerId, { quantity: 6 });
    assert.strictEqual(updated.quantity, 6);
    assert.strictEqual(updated.availableQuantity, 1, "5 reserved meanwhile -> only 1 left");
    ok("offer quantity change racing a reservation keeps the stock right (6 total, 5 reserved, 1 left)");

    await rejects(offers.updateOffer("mer", offerId, { quantity: 4 }), /lower than the quantity already reserved/);
    await rejects(offers.updateOffer("mer", offerId, { description: "x".repeat(1001) }), /description/);
    await rejects(offers.updateOffer("other", offerId, { name: "Pizza" }), /not allowed/);
    ok("offer update: quantity below reserved, too long description and other merchant refused");

    await rejects(offers.createOffer("mer", { ...base, description: { a: 1 } }), /description/);
    ok("offer create: non-text description refused");

    // ---------- 2. soft delete ----------
    const resId = Object.keys(coll("reservations"))[0];
    const del = await offers.deleteOffer("mer", offerId);
    assert.deepStrictEqual(del, { offerId, deleted: true });
    assert.strictEqual(coll("offers")[offerId].status, "deleted");
    assert.strictEqual(await offers.getOfferById(offerId), null);
    assert.ok(!(await offers.getMyOffers("mer")).some((o) => o.id === offerId));
    assert.ok(!(await offers.getAllOffers()).some((o) => o.id === offerId));
    await rejects(offers.updateOffer("mer", offerId, { name: "Pizza" }), /not found/);
    await rejects(offers.deleteOffer("mer", offerId), /not found/);
    await rejects(reservations.createReservation("stu", offerId, 1), /not available/);
    ok("deleted offer: hidden everywhere, not editable, not reservable, second delete -> not found");

    await reservations.cancelReservation("stu", resId);
    assert.strictEqual(coll("reservations")[resId].status, "cancelled");
    assert.strictEqual(coll("offers")[offerId].availableQuantity, 6);
    ok("reservation of a deleted offer can still be cancelled (stock returned)");

    // Older hard-deleted offer: cancel and reject still work
    const offer2 = await offers.createOffer("mer", base);
    const r2 = await reservations.createReservation("stu", offer2.offerId, 1);
    const r3 = await reservations.createReservation("stu", offer2.offerId, 1);
    delete coll("offers")[offer2.offerId];
    await reservations.cancelReservation("stu", r2.reservationId);
    await reservations.updateReservationStatus("mer", r3.reservationId, "rejected");
    assert.strictEqual(coll("reservations")[r2.reservationId].status, "cancelled");
    assert.strictEqual(coll("reservations")[r3.reservationId].status, "rejected");
    ok("offer removed from the database: cancel and reject still close the reservation");

    // ---------- 3. shop validation ----------
    coll("users").mer2 = { uid: "mer2", role: "merchant", status: "active", fullName: "Sami", email: "s@x.tn" };
    await rejects(shops.createShop("mer2", { name: { a: 1 }, address: [1], phone: true }), /name must be a text/);
    await rejects(shops.createShop("mer2", { name: "Café", address: "Tunis", phone: "12" }), /phone/);
    await rejects(shops.createShop("mer2", { name: "Café", address: "Tunis", phone: "20 000 000", email: "nope" }), /email/);
    const shop = await shops.createShop("mer2", { name: " Café du Campus ", address: "Tunis", phone: "20 000 000" });
    assert.strictEqual(shop.name, "Café du Campus");
    assert.strictEqual(shop.phone, "20000000");
    assert.strictEqual(shop.shopId, "mer2");
    ok("shop registration validates name, address, phone, email and stores cleaned values");

    await rejects(shops.updateMyShop("mer2", { name: "" }), /name must be a text/);
    await rejects(shops.updateMyShop("mer2", { phone: null }), /phone/);
    await rejects(shops.updateMyShop("mer2", { email: "x" }), /email/);
    await rejects(shops.updateMyShop("mer2", { email: "" }), /email/);
    const upd = await shops.updateMyShop("mer2", { description: "Sandwichs", phone: "+21620000001" });
    assert.strictEqual(upd.phone, "+21620000001");
    ok("shop update validates each field (empty name, null phone, bad email refused)");

    // ---------- 4. one shop per merchant, even with two simultaneous requests ----------
    coll("users").mer3 = { uid: "mer3", role: "merchant", status: "active", fullName: "Ali", email: "a@x.tn" };
    const data = { name: "Pizza Uni", address: "Ariana", phone: "22000000" };
    const results = await Promise.allSettled([shops.createShop("mer3", data), shops.createShop("mer3", data)]);
    assert.strictEqual(results.filter((r) => r.status === "fulfilled").length, 1);
    assert.match(results.find((r) => r.status === "rejected").reason.message, /already registered/);
    assert.strictEqual(Object.values(coll("shops")).filter((s) => s.ownerId === "mer3").length, 1);
    await rejects(shops.createShop("mer", data), /already registered/);
    ok("double-click shop registration creates one shop; merchant with an older shop refused");

    // ---------- 5. empty maxPrice ----------
    await offers.createOffer("mer", { ...base, name: "Couscous" });
    let r = res();
    await offerCtrl.getAllOffers({ query: { maxPrice: "", category: "Repas" } }, r);
    assert.strictEqual(r.code, 200);
    assert.ok(r.body.count >= 1, "empty maxPrice must not filter everything out");
    r = res();
    await offerCtrl.getAllOffers({ query: { maxPrice: "3" } }, r);
    assert.strictEqual(r.body.count, 0);
    r = res();
    await offerCtrl.getAllOffers({ query: { maxPrice: ["1", "2"] } }, r);
    assert.strictEqual(r.code, 400);
    ok("search: empty maxPrice ignored, maxPrice=3 filters, repeated maxPrice -> 400");

    // ---------- registration full name ----------
    for (const fullName of ["   ", "A", "x".repeat(101), 42]) {
        r = res();
        await authCtrl.register({ body: { fullName, email: "a@b.tn", password: "12345678", role: "student" } }, r);
        assert.strictEqual(r.code, 400, `fullName ${JSON.stringify(fullName)}`);
    }
    r = res();
    await authCtrl.register({ body: { fullName: "Admin", email: "a@b.tn", password: "12345678", role: "admin" } }, r);
    assert.strictEqual(r.code, 400);
    ok("registration: blank, too short, too long or non-text name -> 400; role admin -> 400");

    // ---------- payment recovery ----------
    coll("reservations").pr1 = { reservationId: "pr1", studentId: "stu", status: "pending", paymentStatus: "processing", totalPrice: 4 };
    coll("payments").stuck = { paymentId: "stuck", reservationId: "pr1", studentId: "stu", mode: "mock", status: "initiating", createdAt: ts(Date.now() - 5 * 60000), amountMillimes: 4000 };
    const p1 = await payments.createPayment("stu", "pr1");
    assert.strictEqual(coll("payments").stuck.status, "failed");
    assert.strictEqual(p1.status, "pending");
    assert.notStrictEqual(p1.paymentId, "stuck");
    ok("payment stuck in 'initiating' (server stopped) is closed and a new payment can start");

    coll("reservations").pr2 = { reservationId: "pr2", studentId: "stu", status: "pending", paymentStatus: "pending", totalPrice: 4 };
    coll("payments").old = { paymentId: "old", reservationId: "pr2", studentId: "stu", mode: "sandbox", status: "pending", paymentRef: "ref1", expiresAt: ts(Date.now() + 5 * 60000), amountMillimes: 4000 };
    await rejects(payments.cancelPayment("stu", "old"), /created in sandbox mode/);
    coll("payments").old.expiresAt = ts(Date.now() - 6 * 60000);
    const c = await payments.cancelPayment("stu", "old");
    assert.strictEqual(c.status, "expired");
    assert.strictEqual(coll("reservations").pr2.paymentStatus, "failed");
    await reservations.cancelReservation("stu", "pr2").catch(() => {});
    ok("sandbox payment after switching to mock: cancel refused while valid, closed once expired");

    // ---------- payment error codes ----------
    for (const [message, expected] of [
        ["Reservation is no longer eligible for payment.", 409],
        ["Payment amount or currency does not match the reservation.", 409],
        ["This payment was created in sandbox mode and must be checked in that mode.", 409],
        ["Konnect is temporarily unavailable. Please try again in a few minutes.", 503]
    ]) {
        // The service throws this message; the controller picks the HTTP code.
        const original = payments.verifyKonnectPayment;
        payments.verifyKonnectPayment = async () => { throw new Error(message); };
        r = res();
        await paymentCtrl.verifyPayment({ user: { uid: "stu", role: "student" }, params: { id: "x" } }, r);
        payments.verifyKonnectPayment = original;
        assert.strictEqual(r.code, expected, message);
    }
    ok("payment errors: no longer eligible / amount mismatch / other mode -> 409, Konnect down -> 503");

    console.log(`\nALL ${n} TESTS PASSED`);
    process.exit(0);
})().catch((e) => { console.error("TEST FAILED:", e); process.exit(1); });
