// Offline tests of the corrections: profile, offer validation, reservation
// checks and status codes, shop transitions. Fake Firestore, no network.
const Module = require("module");
const path = require("path");
const assert = require("assert");
const BACKEND = path.join(__dirname, "..");

// ---------- fake Firestore ----------
const store = {};
let autoId = 0;
const coll = (n) => (store[n] ||= {});
const getPath = (o, p) => p.split(".").reduce((x, k) => (x == null ? undefined : x[k]), o);
const applyUpdate = (t, d) => { for (const [k, v] of Object.entries(d)) { if (v && v.__remove) { t[k] = (t[k] || []).filter((x) => !v.__remove.includes(x)); continue; } if (k.includes(".")) { const [a, b] = k.split("."); t[a] = { ...(t[a] || {}), [b]: v }; } else t[k] = v; } };
const snap = (n, id) => { const d = coll(n)[id]; return { id, exists: !!d, data: () => (d ? JSON.parse(JSON.stringify(d)) : undefined), ref: docRef(n, id) }; };
const docRef = (n, id) => ({ id, _n: n, get: async () => snap(n, id), async update(d) { if (!coll(n)[id]) { const e = new Error("NOT_FOUND"); e.code = 5; throw e; } applyUpdate(coll(n)[id], d); }, async set(d) { coll(n)[id] = JSON.parse(JSON.stringify(d)); }, async delete() { delete coll(n)[id]; } });
const query = (n, f = [], lim = Infinity) => ({ where: (p, op, v) => query(n, [...f, [p, op, v]], lim), limit: (k) => query(n, f, k), async get() { const docs = Object.keys(coll(n)).filter((id) => f.every(([p, op, v]) => { const val = getPath(coll(n)[id], p); return op === "==" ? val === v : op === "in" ? v.includes(val) : false; })).slice(0, lim).map((id) => snap(n, id)); return { empty: !docs.length, docs }; } });
let failNextTransaction = false;
const db = {
    collection: (n) => ({ ...query(n), doc: (id) => docRef(n, id || "auto" + ++autoId), async add(d) { const id = "auto" + ++autoId; coll(n)[id] = d; return docRef(n, id); } }),
    getAll: async (...refs) => refs.map((r) => snap(r._n, r.id)),
    async runTransaction(fn) {
        if (failNextTransaction) { failNextTransaction = false; const e = new Error("DEADLINE_EXCEEDED"); e.code = 4; throw e; }
        const w = []; const tx = { get: (x) => x.get(), update: (r, d) => w.push(() => applyUpdate(coll(r._n)[r.id], d)), set: (r, d) => w.push(() => { coll(r._n)[r.id] = JSON.parse(JSON.stringify(d)); }) };
        const res = await fn(tx); w.forEach((x) => x()); return res;
    }
};
const FieldValue = { serverTimestamp: () => "TS", arrayRemove: (...v) => ({ __remove: v }) };
const authCalls = [];
const fakeAuth = { async updateUser(uid, d) { authCalls.push([uid, d]); } };

const orig = Module._load;
Module._load = function (req) {
    if (req === "../config/firebase") return { db, auth: fakeAuth, firebaseApp: {} };
    if (req === "firebase-admin/firestore") return { FieldValue };
    if (req === "firebase-admin/messaging") return { getMessaging: () => ({ sendEachForMulticast: async () => ({ successCount: 0, failureCount: 0, responses: [] }) }) };
    return orig.apply(this, arguments);
};

const users = require(path.join(BACKEND, "services", "userService.js"));
const offers = require(path.join(BACKEND, "services", "offerService.js"));
const shops = require(path.join(BACKEND, "services", "shopService.js"));
const reservations = require(path.join(BACKEND, "services", "reservationService.js"));
const resCtrl = require(path.join(BACKEND, "controllers", "reservationController.js"));
const shopCtrl = require(path.join(BACKEND, "controllers", "shopController.js"));
const userCtrl = require(path.join(BACKEND, "controllers", "userController.js"));
const authCtrl = require(path.join(BACKEND, "controllers", "authController.js"));
const offerCtrl = require(path.join(BACKEND, "controllers", "offerController.js"));
const payCtrl = require(path.join(BACKEND, "controllers", "paymentController.js"));

const res = () => ({ code: 0, body: null, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; } });
const rejects = async (p, re) => { try { await p; } catch (e) { assert.match(e.message, re); return e; } throw new Error("expected " + re); };

(async () => {
    let n = 0; const ok = (m) => console.log(`ok ${++n} - ${m}`);

    // ---------- PROFILE ----------
    coll("users").stu = { uid: "stu", fullName: "Old Name", email: "s@x.tn", role: "student", status: "active" };
    const u = await users.updateUserProfile("stu", { fullName: "  New Name ", role: "admin", status: "rejected", email: "hack@x", uid: "other" });
    assert.strictEqual(u.fullName, "New Name"); assert.strictEqual(u.role, "student"); assert.strictEqual(u.status, "active"); assert.strictEqual(u.email, "s@x.tn"); assert.strictEqual(u.uid, "stu");
    assert.deepStrictEqual(authCalls.at(-1), ["stu", { displayName: "New Name" }]);
    ok("profile: fullName updated (+ Auth displayName), role/status/email/uid ignored");

    assert.strictEqual((await users.updateUserProfile("stu", { name: "Alias Name" })).fullName, "Alias Name");
    ok("profile: legacy 'name' is saved as fullName");

    await rejects(users.updateUserProfile("stu", { role: "admin" }), /No valid fields/);
    await rejects(users.updateUserProfile("stu", { phone: "abc" }), /Phone number/);
    await rejects(users.updateUserProfile("stu", { fullName: "x" }), /between 2 and 100/);
    await rejects(users.updateUserProfile("stu", { photoURL: "javascript:alert(1)" }), /http\(s\) URL/);
    assert.strictEqual((await users.updateUserProfile("stu", { phone: "+216 22 333 444" })).phone, "+21622333444");
    ok("profile: validation (only role -> 400, bad phone/name/photoURL rejected, phone normalized)");

    let r = res(); await userCtrl.getUser({ params: { id: "nobody" } }, r);
    assert.strictEqual(r.code, 404);
    r = res(); await userCtrl.updateMyProfile({ user: { uid: "stu" }, body: undefined }, r);
    assert.strictEqual(r.code, 400);
    ok("profile: unknown user -> 404 (was 500); empty body -> 400");

    // ---------- OFFERS ----------
    coll("users").mer = { role: "merchant", status: "active" };
    coll("shops").shop1 = { ownerId: "mer", name: "Campus Food", status: "approved" };
    const base = { name: "Sandwich", category: "Sandwichs", originalPrice: 8, discountPrice: 4, quantity: 10, pickupStart: "12:00", pickupEnd: "14:00" };
    await rejects(offers.createOffer("mer", { ...base, pickupStart: "14:00", pickupEnd: "12:00" }), /earlier than/);
    await rejects(offers.createOffer("mer", { ...base, pickupStart: "midi" }), /HH:MM/);
    await rejects(offers.createOffer("mer", { ...base, pickupEnd: "2026-11-20T14:00" }), /same format/);
    await rejects(offers.createOffer("mer", { ...base, imageURL: "not a url" }), /imageURL/);
    await rejects(offers.createOffer("mer", { ...base, name: "   " }), /non-empty/);
    const created = await offers.createOffer("mer", { ...base, pickupStart: "2030-11-21T12:00", pickupEnd: "2030-11-21T14:00", imageURL: "https://img.example/a.jpg" });
    assert.strictEqual(created.status, "available");
    ok("createOffer: pickup order/format, imageURL and name validated; datetime format accepted");

    const id = created.offerId;
    await rejects(offers.updateOffer("mer", id, { originalPrice: "abc" }), /valid numbers/);
    await rejects(offers.updateOffer("mer", id, { quantity: "abc" }), /positive integer/);
    await rejects(offers.updateOffer("mer", id, { quantity: 2.5 }), /positive integer/);
    await rejects(offers.updateOffer("mer", id, { pickupEnd: "2030-11-21T11:00" }), /earlier than/);
    await rejects(offers.updateOffer("mer", id, { imageURL: "ftp://x" }), /imageURL/);
    assert.strictEqual(coll("offers")[id].originalPrice, 8);
    assert.strictEqual((await offers.updateOffer("mer", id, { description: "ok" })).description, "ok");
    ok("updateOffer: NaN prices/quantity, bad pickup and URL refused, nothing saved; valid update OK");

    coll("offers").legacy = { merchantId: "mer", shopId: "shop1", title: "Lablebi", discountedPrice: 7.5, originalPrice: 15, imageUrl: "https://a/b.jpg", quantity: 5, availableQuantity: 5, status: "active", category: "Repas", pickupStart: "2026-11-20T12:00", pickupEnd: "2026-11-24T17:00" };
    const lu = await offers.updateOffer("mer", "legacy", { name: "Lablebi XL", discountPrice: 6 });
    assert.strictEqual(coll("offers").legacy.title, "Lablebi XL"); assert.strictEqual(coll("offers").legacy.discountedPrice, 6);
    assert.strictEqual(lu.name, "Lablebi XL"); assert.strictEqual(lu.discountPrice, 6);
    ok("updateOffer on other-format offer keeps title/discountedPrice in sync");

    r = res(); await offerCtrl.updateOffer({ user: { uid: "mer" }, params: { id }, body: undefined }, r);
    assert.strictEqual(r.code, 400);
    r = res(); await offerCtrl.createOffer({ user: { uid: "mer" }, body: undefined }, r);
    assert.strictEqual(r.code, 400);
    ok("offers: empty body -> 400 (was a TypeError)");

    // ---------- RESERVATIONS ----------
    const call = async (fn, req) => { const x = res(); await fn(req, x); return x; };
    coll("offers").sold = { ...coll("offers")[id], status: "unavailable" };
    let x = await call(resCtrl.createReservation, { user: { uid: "stu" }, body: { offerId: "sold", quantity: 1 } });
    assert.strictEqual(x.code, 400); assert.match(x.body.message, /not available/);
    coll("shops").shopR = { ownerId: "mer2", name: "Rejected", status: "rejected" };
    coll("offers").rej = { ...coll("offers")[id], shopId: "shopR" };
    x = await call(resCtrl.createReservation, { user: { uid: "stu" }, body: { offerId: "rej", quantity: 1 } });
    assert.strictEqual(x.code, 400); assert.match(x.body.message, /not available/);
    assert.strictEqual(coll("offers").rej.availableQuantity, 10);
    ok("reservation refused for unavailable offer or non-approved shop (stock untouched)");

    x = await call(resCtrl.createReservation, { user: { uid: "stu" }, body: { offerId: id, quantity: 99 } });
    assert.strictEqual(x.code, 400); assert.match(x.body.message, /Not enough/);
    x = await call(resCtrl.createReservation, { user: { uid: "stu" }, body: undefined });
    assert.strictEqual(x.code, 400);
    x = await call(resCtrl.createReservation, { user: { uid: "stu" }, body: { offerId: "nope", quantity: 1 } });
    assert.strictEqual(x.code, 404);
    ok("status codes: not enough stock -> 400 (was 500), empty body -> 400, unknown offer -> 404");

    x = await call(resCtrl.createReservation, { user: { uid: "stu" }, body: { offerId: id, quantity: 2 } });
    assert.strictEqual(x.code, 201);
    const rid = x.body.data.reservationId;
    x = await call(resCtrl.updateReservationStatus, { user: { uid: "mer" }, params: { id: rid }, body: { status: "completed" } });
    assert.strictEqual(x.code, 400); assert.match(x.body.message, /QR verification/);
    x = await call(resCtrl.updateReservationStatus, { user: { uid: "mer2" }, params: { id: rid }, body: { status: "rejected" } });
    assert.strictEqual(x.code, 403);
    coll("reservations")[rid].paymentStatus = "paid";
    x = await call(resCtrl.cancelReservation, { user: { uid: "stu" }, params: { id: rid } });
    assert.strictEqual(x.code, 400); assert.match(x.body.message, /payment is in progress or paid/);
    x = await call(resCtrl.cancelReservation, { user: { uid: "other" }, params: { id: rid } });
    assert.strictEqual(x.code, 403);
    ok("status codes: invalid status -> 400, other merchant -> 403, cancel paid -> 400 (were 500), other student -> 403");

    failNextTransaction = true;
    x = await call(resCtrl.createReservation, { user: { uid: "stu" }, body: { offerId: id, quantity: 1 } });
    assert.strictEqual(x.code, 500); assert.ok(!/DEADLINE/.test(x.body.message));
    ok("technical Firestore error -> 500 with generic message (no internal details)");

    // ---------- SHOPS ----------
    coll("users").m3 = { role: "merchant", status: "pending" };
    coll("shops").s3 = { ownerId: "m3", name: "New", status: "pending" };
    x = await call(shopCtrl.approveShop, { params: { id: "s3" } });
    assert.strictEqual(x.code, 200); assert.strictEqual(coll("shops").s3.status, "approved"); assert.strictEqual(coll("users").m3.status, "active");
    x = await call(shopCtrl.approveShop, { params: { id: "s3" } });
    assert.strictEqual(x.code, 409);
    x = await call(shopCtrl.rejectShop, { params: { id: "s3" } });
    assert.strictEqual(x.code, 200); assert.strictEqual(coll("shops").s3.status, "rejected"); assert.strictEqual(coll("users").m3.status, "rejected");
    x = await call(shopCtrl.rejectShop, { params: { id: "s3" } });
    assert.strictEqual(x.code, 409);
    x = await call(shopCtrl.approveShop, { params: { id: "s3" } });
    assert.strictEqual(x.code, 200); assert.strictEqual(coll("users").m3.status, "active");
    x = await call(shopCtrl.approveShop, { params: { id: "missing" } });
    assert.strictEqual(x.code, 404);
    coll("shops").orphan = { ownerId: "ghost", status: "pending" };
    x = await call(shopCtrl.approveShop, { params: { id: "orphan" } });
    assert.strictEqual(x.code, 404); assert.strictEqual(coll("shops").orphan.status, "pending");
    ok("shops: approve/reject update shop + merchant together; repeated -> 409; missing shop/owner -> 404, nothing half-updated");

    // ---------- EXPIRY ----------
    await rejects(offers.createOffer("mer", { ...base, pickupStart: "2020-01-01T12:00", pickupEnd: "2020-01-01T14:00" }), /in the future/);
    await rejects(offers.updateOffer("mer", id, { pickupStart: "2020-01-01T10:00", pickupEnd: "2020-01-01T11:00" }), /in the future/);
    ok("offer cannot be created or moved to a pickup time already over");

    coll("offers").expired = { ...coll("offers")[id], pickupStart: "2020-01-01T12:00", pickupEnd: "2020-01-01T14:00", availableQuantity: 5 };
    x = await call(resCtrl.createReservation, { user: { uid: "stu" }, body: { offerId: "expired", quantity: 1 } });
    assert.strictEqual(x.code, 400); assert.match(x.body.message, /expired/);
    assert.strictEqual(coll("offers").expired.availableQuantity, 5);
    ok("reservation on an expired offer -> 400, stock untouched");

    coll("offers").soldout = { ...coll("offers")[id], availableQuantity: 0 };
    coll("offers").daily = { ...coll("offers")[id], pickupStart: "12:00", pickupEnd: "14:00" };
    const listed = (await offers.getAllOffers()).map((o) => o.id);
    assert.ok(!listed.includes("expired")); assert.ok(!listed.includes("soldout"));
    assert.ok(listed.includes("daily")); assert.ok(listed.includes(id));
    const detail = await offers.getOfferById("expired");
    assert.strictEqual(detail.isExpired, true); assert.strictEqual(detail.isSoldOut, false);
    ok("listing hides expired and sold-out offers; daily HH:MM offers stay; detail shows isExpired");

    // ---------- EMPTY BODIES ----------
    x = await call(authCtrl.register, { body: undefined }); assert.strictEqual(x.code, 400);
    x = await call(authCtrl.login, { body: undefined }); assert.strictEqual(x.code, 400);
    x = await call(payCtrl.initiatePayment, { user: { uid: "stu", role: "student" }, body: undefined }); assert.strictEqual(x.code, 400);
    x = await call(shopCtrl.registerShop, { user: { uid: "mer" }, body: undefined }); assert.strictEqual(x.code, 400);
    ok("empty body -> 400 on register, login, payment initiate, shop register");

    console.log(`\nALL ${n} TESTS PASSED`);
    process.exit(0);
})().catch((e) => { console.error("TEST FAILED:", e); process.exit(1); });
