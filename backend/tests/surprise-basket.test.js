// Offline tests for the bonus "Surprise Basket": creation, validation,
// listing and search, update, the full reservation / QR / EcoPoints flow,
// dashboards, controllers and route order. Same fake Firestore as
// review-fixes.test.js (optimistic transactions).
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
// Dotted field paths ("qr.usedAt"), as Firestore update() and where() accept.
const getPath = (obj, f) => f.split(".").reduce((o, k) => (o == null ? undefined : o[k]), obj);
const applyUpdate = (doc, data) => {
    for (const [key, v] of Object.entries(data)) {
        const parts = key.split(".");
        const k = parts.pop();
        let target = doc;
        for (const p of parts) target = target[p] = { ...(target[p] || {}) };
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
                const val = getPath(coll(name)[id], f);
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
const dashboards = require(path.join(BACKEND, "services", "dashboardService.js"));
const offerCtrl = require(path.join(BACKEND, "controllers", "offerController.js"));
const offerRoutes = require(path.join(BACKEND, "routes", "offerRoutes.js"));

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
    coll("users").stu = { uid: "stu", role: "student", status: "active", fullName: "Test Student", ecoPoints: 0 };
    coll("shops").shop1 = { shopId: "shop1", ownerId: "mer", name: "Campus Food", status: "approved" };
    const pickup = { pickupStart: future(1), pickupEnd: future(5) };
    const basketInput = {
        offerType: "surprise_basket",
        originalPrice: 15, discountPrice: 5, quantity: 4, ...pickup,
        basketItems: [" viennoiseries ", "sandwich", "dessert du jour"]
    };

    // ---------- 1. creation ----------
    const basket = await offers.createOffer("mer", basketInput);
    assert.strictEqual(basket.offerType, "surprise_basket");
    assert.strictEqual(basket.isSurpriseBasket, true);
    assert.strictEqual(basket.name, "Panier surprise");
    assert.strictEqual(basket.category, "Panier surprise");
    assert.deepStrictEqual(basket.basketItems, ["viennoiseries", "sandwich", "dessert du jour"]);
    assert.strictEqual(coll("offers")[basket.offerId].offerType, "surprise_basket");
    ok("surprise basket created with default name/category and cleaned contents");

    const named = await offers.createOffer("mer", { ...basketInput, name: "Panier du soir", category: "Boulangerie", basketItems: undefined });
    assert.strictEqual(named.name, "Panier du soir");
    assert.deepStrictEqual(named.basketItems, []);
    ok("surprise basket keeps a given name and category; contents list is optional");

    const standard = await offers.createOffer("mer", { name: "Sandwich", category: "Repas", originalPrice: 8, discountPrice: 6, quantity: 3, ...pickup });
    assert.strictEqual(standard.offerType, "standard");
    assert.strictEqual(standard.isSurpriseBasket, false);
    assert.strictEqual(standard.basketItems, undefined);
    ok("an offer created without offerType is a standard offer");

    // ---------- 2. validation ----------
    await rejects(offers.createOffer("mer", { ...basketInput, discountPrice: 8 }), /at most 50%/);
    await rejects(offers.createOffer("mer", { ...basketInput, offerType: "mystery" }), /offerType must be one of/);
    await rejects(offers.createOffer("mer", { ...basketInput, basketItems: "pain" }), /basketItems must be a list/);
    await rejects(offers.createOffer("mer", { ...basketInput, basketItems: Array(11).fill("x") }), /at most 10/);
    await rejects(offers.createOffer("mer", { ...basketInput, basketItems: ["  "] }), /1 to 60 characters/);
    await rejects(offers.createOffer("mer", { ...basketInput, basketItems: ["x".repeat(61)] }), /1 to 60 characters/);
    await rejects(offers.createOffer("mer", { name: "Pizza", category: "Repas", originalPrice: 8, discountPrice: 6, quantity: 3, ...pickup, basketItems: ["x"] }), /only be set on a surprise basket/);
    coll("users").mer3 = { uid: "mer3", role: "merchant", status: "active" };
    await rejects(offers.createOffer("mer3", basketInput), /approved shop/);
    ok("refused: price above 50% of value, unknown type, bad contents, contents on a standard offer, no approved shop");

    // ---------- 3. listing and search ----------
    coll("offers").legacy = { name: "Lablebi", category: "Repas", discountedPrice: 3, originalPrice: 5, availableQuantity: 2, quantity: 2, status: "active", shopId: "shop1", ...pickup };
    const all = await offers.getAllOffers();
    const onlyBaskets = await offers.getAllOffers({ type: "surprise_basket" });
    const onlyStandard = await offers.getAllOffers({ type: "standard" });
    assert.strictEqual(all.length, 4);
    assert.deepStrictEqual(onlyBaskets.map((o) => o.id).sort(), [basket.offerId, named.offerId].sort());
    assert.ok(onlyStandard.some((o) => o.id === "legacy") && onlyStandard.some((o) => o.id === standard.offerId));
    assert.ok(!onlyStandard.some((o) => o.offerType === "surprise_basket"));
    const found = await offers.getAllOffers({ q: "viennoiseries" });
    assert.deepStrictEqual(found.map((o) => o.id), [basket.offerId]);
    ok("type filter separates baskets from standard offers (old offers count as standard); search reads basket contents");

    // ---------- 4. update ----------
    const upd = await offers.updateOffer("mer", basket.offerId, { basketItems: ["pain", "fruits"], offerType: "standard" });
    assert.deepStrictEqual(upd.basketItems, ["pain", "fruits"]);
    assert.strictEqual(upd.offerType, "surprise_basket", "offerType cannot change");
    await rejects(offers.updateOffer("mer", basket.offerId, { offerType: "standard" }), /No valid fields/);
    await rejects(offers.updateOffer("mer", basket.offerId, { discountPrice: 9 }), /at most 50%/);
    await rejects(offers.updateOffer("mer", basket.offerId, { basketItems: [42] }), /1 to 60 characters/);
    await rejects(offers.updateOffer("mer", standard.offerId, { basketItems: ["x"] }), /only be set on a surprise basket/);
    ok("update: contents editable, type fixed, 50% rule and contents checked again");

    // ---------- 5. full flow: reserve, pay, QR, pickup ----------
    const r = await reservations.createReservation("stu", basket.offerId, 2);
    assert.strictEqual(r.offerType, "surprise_basket");
    assert.strictEqual(r.unitPrice, 5);
    assert.strictEqual(r.totalPrice, 10);
    assert.strictEqual(coll("offers")[basket.offerId].availableQuantity, 2);
    // payment confirmed (covered by payments.test.js), then merchant confirms
    coll("reservations")[r.reservationId].paymentStatus = "paid";
    await reservations.updateReservationStatus("mer", r.reservationId, "confirmed");
    const qr = await reservations.generateReservationQR("stu", r.reservationId);
    const done = await reservations.verifyReservationQR("mer", qr.token);
    assert.strictEqual(done.status, "completed");
    assert.strictEqual(coll("users").stu.ecoPoints, 20);
    ok("basket goes through reservation, confirmation, QR pickup; 2 baskets = 20 EcoPoints");

    const rs = await reservations.createReservation("stu", standard.offerId, 1);
    assert.strictEqual(rs.offerType, "standard");
    ok("a standard offer's reservation is marked standard");

    // ---------- 6. dashboards ----------
    const student = await dashboards.getStudentDashboard("stu");
    assert.strictEqual(student.impact.surpriseBasketsRescued, 2);
    assert.strictEqual(student.impact.moneySaved, 20);
    const merchant = await dashboards.getMerchantDashboard("mer");
    assert.strictEqual(merchant.surpriseBasketsSold, 2);
    assert.deepStrictEqual(merchant.offers.byType, { standard: 1, surprise_basket: 2 });
    const admin = await dashboards.getAdminDashboard();
    assert.strictEqual(admin.impact.surpriseBasketsRescued, 2);
    assert.deepStrictEqual(admin.offers.byType, { standard: 2, surprise_basket: 2 });
    ok("dashboards count baskets: student rescued 2, merchant sold 2, admin impact 2, offers by type");

    // ---------- 7. controllers and routes ----------
    let resp = res();
    await offerCtrl.createSurpriseBasket(
        { user: { uid: "mer", role: "merchant" }, body: { originalPrice: 12, discountPrice: 4, quantity: 2, ...pickup } },
        resp
    );
    assert.strictEqual(resp.code, 201);
    assert.strictEqual(resp.body.data.offerType, "surprise_basket");
    assert.strictEqual(resp.body.data.name, "Panier surprise");
    ok("POST /offers/surprise-baskets creates a basket without name or category");

    resp = res();
    await offerCtrl.createOffer({ user: { uid: "mer" }, body: { originalPrice: 12, discountPrice: 4, quantity: 2, ...pickup } }, resp, () => {});
    assert.strictEqual(resp.code, 400, "standard offer still needs name and category");
    resp = res();
    await offerCtrl.createOffer({ user: { uid: "mer" }, body: { offerType: "surprise_basket", originalPrice: 12, discountPrice: 7, quantity: 2, ...pickup } }, resp, () => {});
    assert.strictEqual(resp.code, 400);
    assert.match(resp.body.message, /50%/);
    ok("POST /offers: standard offer without name -> 400; basket above 50% -> 400 (Express next() is not taken for a type)");

    resp = res();
    await offerCtrl.getSurpriseBaskets({ query: {} }, resp, () => {});
    assert.strictEqual(resp.code, 200);
    assert.ok(resp.body.count >= 3 && resp.body.data.every((o) => o.offerType === "surprise_basket"));
    resp = res();
    await offerCtrl.getAllOffers({ query: { type: "panier" } }, resp, () => {});
    assert.strictEqual(resp.code, 400);
    resp = res();
    await offerCtrl.getAllOffers({ query: { type: "standard" } }, resp, () => {});
    assert.ok(resp.body.data.every((o) => o.offerType === "standard"));
    ok("GET /offers/surprise-baskets lists only baskets; ?type= filter works and rejects unknown types");

    const paths = offerRoutes.stack.filter((l) => l.route).map((l) => `${Object.keys(l.route.methods)[0]} ${l.route.path}`);
    assert.ok(paths.indexOf("get /surprise-baskets") < paths.indexOf("get /:id"), "route must be declared before /:id");
    assert.ok(paths.includes("post /surprise-baskets"));
    ok("route GET /surprise-baskets is declared before GET /:id");

    console.log(`\nALL ${n} TESTS PASSED`);
    process.exit(0);
})().catch((e) => { console.error("TEST FAILED:", e); process.exit(1); });
