// Offline test of admin suspension / reactivation (fake Firestore + fake Auth).
const Module = require("module");
const path = require("path");
const assert = require("assert");
const BACKEND = path.join(__dirname, "..");

const store = {};
const coll = (n) => (store[n] ||= {});
const getPath = (o, p) => p.split(".").reduce((x, k) => (x == null ? undefined : x[k]), o);
const applyUpdate = (t, d) => { for (const [k, v] of Object.entries(d)) { if (v && v.__delete) { delete t[k]; continue; } t[k] = v; } };
const snap = (n, id) => { const d = coll(n)[id]; return { id, exists: !!d, data: () => (d ? JSON.parse(JSON.stringify(d)) : undefined), ref: docRef(n, id) }; };
const docRef = (n, id) => ({ id, _n: n, get: async () => snap(n, id), async update(d) { applyUpdate(coll(n)[id], d); } });
const query = (n, f = [], lim = Infinity) => ({ where: (p, op, v) => query(n, [...f, [p, op, v]], lim), limit: (k) => query(n, f, k), async get() { const docs = Object.keys(coll(n)).filter((id) => f.every(([p, , v]) => getPath(coll(n)[id], p) === v)).slice(0, lim).map((id) => snap(n, id)); return { empty: !docs.length, docs }; } });
let failTx = false;
const db = {
    collection: (n) => ({ ...query(n), doc: (id) => docRef(n, id) }),
    async runTransaction(fn) {
        if (failTx) { failTx = false; const e = new Error("ABORTED"); e.code = 10; throw e; }
        const w = []; const tx = { get: (x) => x.get(), update: (r, d) => w.push(() => applyUpdate(coll(r._n)[r.id], d)) };
        const res = await fn(tx); w.forEach((x) => x()); return res;
    }
};
const FieldValue = { serverTimestamp: () => "TS", delete: () => ({ __delete: true }), arrayRemove: () => ({}) };
const authState = {}; const revoked = [];
const fakeAuth = {
    async updateUser(uid, d) { authState[uid] = { ...(authState[uid] || {}), ...d }; },
    async revokeRefreshTokens(uid) { revoked.push(uid); },
    async verifyIdToken() { return { uid: "sus", email: "s@x" }; }
};
const orig = Module._load;
Module._load = function (req) {
    if (req === "../config/firebase") return { db, auth: fakeAuth, firebaseApp: {} };
    if (req === "firebase-admin/firestore") return { FieldValue };
    return orig.apply(this, arguments);
};
const users = require(path.join(BACKEND, "services", "userService.js"));
const ctrl = require(path.join(BACKEND, "controllers", "userController.js"));
const { verifyToken } = require(path.join(BACKEND, "middlewares", "authMiddleware.js"));
const res = () => ({ code: 0, body: null, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; } });
const call = async (req) => { const r = res(); await ctrl.updateUserStatus(req, r); return r; };

(async () => {
    let n = 0; const ok = (m) => console.log(`ok ${++n} - ${m}`);
    coll("users").adm = { role: "admin", status: "active" };
    coll("users").adm2 = { role: "admin", status: "active" };
    coll("users").stu = { role: "student", status: "active" };
    coll("users").mer = { role: "merchant", status: "active" };
    coll("users").pend = { role: "merchant", status: "pending" };
    coll("shops").shop = { ownerId: "mer", status: "approved" };
    coll("shops").pshop = { ownerId: "pend", status: "pending" };

    let r = await call({ user: { uid: "adm" }, params: { id: "stu" }, body: { status: "suspended" } });
    assert.strictEqual(r.code, 200); assert.strictEqual(r.body.user.status, "suspended");
    assert.strictEqual(authState.stu.disabled, true); assert.ok(revoked.includes("stu"));
    assert.strictEqual(coll("users").stu.statusBeforeSuspension, "active");
    ok("suspend student: status suspended, Auth disabled, sessions revoked");

    r = res(); let next = false;
    await verifyToken({ headers: { authorization: "Bearer t" } }, r, () => { next = true; });
    coll("users").sus = { role: "student", status: "suspended" };
    r = res(); next = false;
    await verifyToken({ headers: { authorization: "Bearer t" } }, r, () => { next = true; });
    assert.strictEqual(r.code, 403); assert.ok(!next); assert.match(r.body.message, /suspended/);
    ok("middleware: suspended user -> 403 even with a valid token");

    r = await call({ user: { uid: "adm" }, params: { id: "stu" }, body: { status: "suspended" } });
    assert.strictEqual(r.code, 409);
    r = await call({ user: { uid: "adm" }, params: { id: "stu" }, body: { status: "active" } });
    assert.strictEqual(r.code, 200); assert.strictEqual(r.body.user.status, "active");
    assert.strictEqual(authState.stu.disabled, false); assert.ok(!("statusBeforeSuspension" in coll("users").stu));
    r = await call({ user: { uid: "adm" }, params: { id: "stu" }, body: { status: "active" } });
    assert.strictEqual(r.code, 409);
    ok("reactivate: previous status restored, Auth enabled; repeated actions -> 409");

    r = await call({ user: { uid: "adm" }, params: { id: "mer" }, body: { status: "suspended" } });
    assert.strictEqual(r.code, 200); assert.strictEqual(coll("shops").shop.status, "suspended");
    r = await call({ user: { uid: "adm" }, params: { id: "mer" }, body: { status: "active" } });
    assert.strictEqual(coll("shops").shop.status, "approved"); assert.strictEqual(coll("users").mer.status, "active");
    ok("merchant: shop suspended with the account, restored to approved on reactivation");

    await call({ user: { uid: "adm" }, params: { id: "pend" }, body: { status: "suspended" } });
    await call({ user: { uid: "adm" }, params: { id: "pend" }, body: { status: "active" } });
    assert.strictEqual(coll("users").pend.status, "pending"); assert.strictEqual(coll("shops").pshop.status, "pending");
    ok("pending merchant goes back to pending (not silently approved)");

    for (const [req, code] of [
        [{ user: { uid: "adm" }, params: { id: "adm" }, body: { status: "suspended" } }, 400],
        [{ user: { uid: "adm" }, params: { id: "adm2" }, body: { status: "suspended" } }, 400],
        [{ user: { uid: "adm" }, params: { id: "stu" }, body: { status: "deleted" } }, 400],
        [{ user: { uid: "adm" }, params: { id: "stu" }, body: undefined }, 400],
        [{ user: { uid: "adm" }, params: { id: "ghost" }, body: { status: "suspended" } }, 404]
    ]) { r = await call(req); assert.strictEqual(r.code, code, JSON.stringify(req) + " -> " + r.code); }
    ok("refused: self (400), another admin (400), invalid status (400), empty body (400), unknown user (404)");

    failTx = true;
    r = await call({ user: { uid: "adm" }, params: { id: "stu" }, body: { status: "suspended" } });
    assert.strictEqual(r.code, 500); assert.strictEqual(authState.stu.disabled, false); assert.strictEqual(coll("users").stu.status, "active");
    ok("Firestore failure during suspension -> Auth change rolled back, 500 with generic message");

    console.log(`\nALL ${n} TESTS PASSED`);
})().catch((e) => { console.error("TEST FAILED:", e); process.exit(1); });
