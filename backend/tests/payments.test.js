// Offline test of the Konnect payment flow (mock page + sandbox) with a fake
// Firestore, a fake Konnect API and a real Express server for the routes.
const Module = require("module");
const path = require("path");
const assert = require("assert");

const BACKEND = path.join(__dirname, "..");

// ---------------- fake Firestore ----------------
const store = {};
let autoId = 0;
const coll = (name) => (store[name] ||= {});
const ts = (ms) => ({ toMillis: () => ms, toDate: () => new Date(ms) });

const applyUpdate = (target, data) => {
    for (const [k, v] of Object.entries(data)) {
        if (k.includes(".")) {
            const [a, b] = k.split(".");
            target[a] = { ...(target[a] || {}), [b]: v };
        } else target[k] = v;
    }
};
const makeDocRef = (name, id) => ({
    id, _name: name,
    async get() { return snap(name, id); },
    async update(data) {
        if (!coll(name)[id]) throw new Error("NOT_FOUND " + name + "/" + id);
        applyUpdate(coll(name)[id], data);
    },
    async set(data) { coll(name)[id] = { ...data }; }
});
const snap = (name, id) => {
    const d = coll(name)[id];
    return { id, exists: !!d, data: () => (d ? { ...d } : undefined), ref: makeDocRef(name, id) };
};
const makeQuery = (name, filters = [], lim = Infinity) => ({
    where(f, op, v) { return makeQuery(name, [...filters, [f, op, v]], lim); },
    limit(n) { return makeQuery(name, filters, n); },
    async get() {
        const docs = Object.keys(coll(name))
            .filter((id) => filters.every(([f, op, v]) => {
                if (op === "==") return coll(name)[id][f] === v;
                throw new Error("op " + op);
            }))
            .slice(0, lim)
            .map((id) => snap(name, id));
        return { empty: docs.length === 0, docs };
    }
});
const db = {
    collection(name) {
        const q = makeQuery(name);
        return { ...q, doc(id) { return makeDocRef(name, id || "auto" + ++autoId); } };
    },
    async runTransaction(fn) {
        const writes = [];
        const tx = {
            async get(x) { return x.get(); },
            update(ref, data) { writes.push(() => applyUpdate(coll(ref._name)[ref.id], data)); },
            set(ref, data) { writes.push(() => { coll(ref._name)[ref.id] = { ...data }; }); }
        };
        const r = await fn(tx);
        writes.forEach((w) => w());
        return r;
    }
};
const firestoreStub = {
    FieldValue: { serverTimestamp: () => "SERVER_TS" },
    Timestamp: { fromMillis: ts }
};

// ---------------- fake Konnect sandbox API + webhook HTTP calls ----------------
const konnectConfig = {
    mode: "mock", baseURL: "https://fake", apiKey: "k", walletId: "w",
    webhookURL: null, publicBaseURL: "http://localhost:0"
};
const konnect = { lastInitBody: null, payments: {}, refN: 0 };
const webhookCalls = [];
const fakeAxios = {
    create: () => ({
        async post(url, body) {
            assert.strictEqual(url, "/payments/init-payment");
            konnect.lastInitBody = body;
            const ref = "ref" + ++konnect.refN;
            konnect.payments[ref] = { status: "pending", token: "TND", amount: body.amount, reachedAmount: 0, expirationDate: new Date(Date.now() + 10 * 60000).toISOString() };
            return { data: { payUrl: "https://pay/" + ref, paymentRef: ref } };
        },
        async get(url) {
            return { data: { payment: konnect.payments[decodeURIComponent(url.split("/").pop())] } };
        }
    }),
    // Used by the fake Konnect to call our webhook: a real HTTP request.
    async get(url, { params }) {
        webhookCalls.push(params.payment_ref);
        const r = await fetch(`${url}?payment_ref=${encodeURIComponent(params.payment_ref)}`);
        if (!r.ok) {
            const e = new Error("HTTP " + r.status);
            e.response = { data: await r.json() };
            throw e;
        }
        return { data: await r.json() };
    }
};

const sentNotifs = [];
const fakeNotif = {
    async notifyUser(uid, m) { sentNotifs.push({ to: uid, type: m.type }); },
    async notifyShopOwner(shopId, m) { sentNotifs.push({ to: "shop:" + shopId, type: m.type }); }
};
const fakeAuth = {
    verifyToken(req, res, next) {
        const [uid, role] = String(req.headers["x-test-user"] || "").split(":");
        if (!uid) return res.status(401).json({ success: false });
        req.user = { uid, role };
        next();
    }
};
const flush = () => new Promise((r) => setTimeout(r, 30));

const origLoad = Module._load;
Module._load = function (request) {
    if (request === "../config/firebase") return { db };
    if (request === "../config/konnect") return konnectConfig;
    if (request === "firebase-admin/firestore") return firestoreStub;
    if (request === "axios") return fakeAxios;
    if (request === "./notificationService") return fakeNotif;
    if (request === "../middlewares/authMiddleware") return fakeAuth;
    return origLoad.apply(this, arguments);
};

const express = require(path.join(BACKEND, "node_modules", "express"));
const svc = require(path.join(BACKEND, "services", "paymentService.js"));
const ctrl = require(path.join(BACKEND, "controllers", "paymentController.js"));
const paymentRoutes = require(path.join(BACKEND, "routes", "paymentRoutes.js"));

const newReservation = (id, studentId = "stuA", total = 6.5, extra = {}) => {
    coll("reservations")[id] = { reservationId: id, studentId, status: "pending", paymentStatus: "unpaid", totalPrice: total, ...extra };
};
const res = () => ({ code: 0, body: null, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; } });
const rejects = async (p, re) => {
    try { await p; } catch (e) { assert.match(e.message, re); return e; }
    throw new Error("expected rejection " + re);
};

(async () => {
    const app = express();
    app.use(express.json());
    app.use("/api/payments", paymentRoutes);
    const server = await new Promise((r) => { const s = app.listen(0, () => r(s)); });
    const base = `http://localhost:${server.address().port}`;
    konnectConfig.publicBaseURL = base;
    const api = (method, p, user, body) => fetch(base + "/api/payments" + p, {
        method,
        headers: { "content-type": "application/json", ...(user ? { "x-test-user": user } : {}) },
        body: body ? JSON.stringify(body) : undefined
    });

    let n = 0;
    const ok = (m) => console.log(`ok ${++n} - ${m}`);

    try {
        // ================= MOCK: full flow through HTTP =================
        konnectConfig.mode = "mock";
        newReservation("r1", "stuA", 6.5, { shopId: "shopX", offerName: "Lablebi <b>", quantity: 2, shopName: "Campus Food" });

        let r = await api("POST", "/init", "stuA:student", { reservationId: "r1" });
        let body = await r.json();
        assert.strictEqual(r.status, 201, JSON.stringify(body));
        const p1 = body.data;
        assert.strictEqual(p1.status, "pending");
        assert.strictEqual(p1.amountMillimes, 6500);
        assert.match(p1.paymentRef, /^mock_[a-f0-9]{32}$/);
        assert.strictEqual(p1.payUrl, `${base}/api/payments/mock-checkout/${p1.paymentRef}`);
        assert.ok(p1.expiresAt);
        assert.strictEqual(coll("reservations").r1.paymentStatus, "pending");
        ok("mock: POST /init -> 201, payUrl to local test page, 6.500 DT = 6500 millimes, reservation pending");

        r = await api("POST", "/initiate", "stuA:student", { reservationId: "r1" });
        body = await r.json();
        assert.strictEqual(r.status, 200);
        assert.strictEqual(body.data.paymentId, p1.paymentId);
        assert.strictEqual(body.data.payUrl, p1.payUrl);
        ok("mock: /initiate still works and reuses the same pending link");

        r = await api("POST", "/init", null, { reservationId: "r1" });
        assert.strictEqual(r.status, 401);
        r = await api("POST", "/init", "stuB:student", { reservationId: "r1" });
        assert.strictEqual(r.status, 403);
        ok("mock: /init needs a token (401) and the owner student (403)");

        r = await fetch(p1.payUrl);
        let html = await r.text();
        assert.strictEqual(r.status, 200);
        assert.match(r.headers.get("content-type"), /text\/html/);
        assert.match(html, /6[.,\s ]?500[,.]?0*\s*TND|6,500 TND/);
        assert.match(html, /<button type="submit">Payer<\/button>/);
        assert.match(html, /Lablebi &lt;b&gt;/);
        assert.ok(!html.includes("Lablebi <b>"));
        assert.match(html, /Campus Food/);
        ok("mock page: GET payUrl -> HTML with amount, escaped offer name, Payer button");

        // Webhook before payment: re-check says pending, nothing changes
        r = await api("GET", `/webhook?payment_ref=${p1.paymentRef}`);
        body = await r.json();
        assert.deepStrictEqual(body, { success: true, status: "pending" });
        assert.strictEqual(coll("payments")[p1.paymentId].status, "pending");
        ok("webhook before payment: status re-checked -> still pending (a fake call cannot mark it paid)");

        r = await fetch(`${p1.payUrl}/pay`, { method: "POST" });
        html = await r.text();
        assert.strictEqual(r.status, 200, html);
        assert.match(html, /Paiement réussi/);
        assert.deepStrictEqual(webhookCalls, [p1.paymentRef]);
        assert.strictEqual(coll("payments")[p1.paymentId].status, "paid");
        assert.strictEqual(coll("payments")[p1.paymentId].mockProviderStatus, "completed");
        assert.strictEqual(coll("reservations").r1.paymentStatus, "paid");
        ok("mock page: Payer -> fake Konnect completes, calls the real webhook over HTTP -> payment and reservation paid");

        await flush();
        assert.deepStrictEqual(sentNotifs, [{ to: "stuA", type: "payment_confirmed" }, { to: "shop:shopX", type: "reservation_paid" }]);
        ok("notifications: student + merchant notified once");

        r = await fetch(`${p1.payUrl}/pay`, { method: "POST" });
        assert.strictEqual(r.status, 200);
        r = await fetch(p1.payUrl);
        assert.match(await r.text(), /Paiement réussi/);
        await flush();
        assert.strictEqual(sentNotifs.length, 2);
        assert.strictEqual(webhookCalls.length, 1);
        ok("mock page: paying again / reopening the link shows success, no duplicate notification");

        r = await api("GET", `/${p1.paymentId}`, "stuA:student");
        assert.strictEqual((await r.json()).data.status, "paid");
        ok("GET /:id -> paid");

        // ----- cancelled and expired links -----
        newReservation("r2");
        const p2 = await svc.createPayment("stuA", "r2");
        await svc.cancelPayment("stuA", p2.paymentId);
        r = await fetch(p2.payUrl);
        assert.strictEqual(r.status, 409);
        assert.match(await r.text(), /annulé ou a expiré/);
        r = await fetch(`${p2.payUrl}/pay`, { method: "POST" });
        assert.strictEqual(r.status, 409);
        assert.strictEqual(coll("payments")[p2.paymentId].status, "cancelled");
        assert.strictEqual(coll("reservations").r2.paymentStatus, "unpaid");
        ok("mock page: cancelled payment -> 409 page, Payer refused, reservation stays unpaid");

        const p3 = await svc.createPayment("stuA", "r2");
        assert.notStrictEqual(p3.paymentRef, p2.paymentRef);
        coll("payments")[p3.paymentId].expiresAt = ts(Date.now() - 1000);
        r = await fetch(`${p3.payUrl}/pay`, { method: "POST" });
        assert.strictEqual(r.status, 410);
        assert.match(await r.text(), /expiré/);
        assert.strictEqual(coll("payments")[p3.paymentId].status, "pending");
        ok("mock page: expired link -> 410, nothing paid");

        coll("payments")[p3.paymentId].expiresAt = ts(Date.now() - 6 * 60000);
        const v3 = await svc.verifyKonnectPayment("stuA", p3.paymentId);
        assert.strictEqual(v3.status, "expired");
        assert.strictEqual(coll("reservations").r2.paymentStatus, "failed");
        const p4 = await svc.createPayment("stuA", "r2");
        assert.strictEqual(p4.status, "pending");
        ok("mock: /verify works in mock mode, closes an expired link, a new payment can start");

        // Reservation cancelled between init and Payer
        newReservation("r3");
        const p5 = await svc.createPayment("stuA", "r3");
        coll("reservations").r3.status = "cancelled";
        r = await fetch(`${p5.payUrl}/pay`, { method: "POST" });
        assert.strictEqual(r.status, 409);
        assert.match(await r.text(), /n&#39;accepte plus de paiement/);
        assert.strictEqual(coll("payments")[p5.paymentId].status, "pending");
        ok("mock page: reservation cancelled meanwhile -> 409 page, not marked paid");

        r = await fetch(`${base}/api/payments/mock-checkout/mock_${"0".repeat(32)}`);
        assert.strictEqual(r.status, 404);
        r = await fetch(`${base}/api/payments/mock-checkout/bad<ref>`);
        assert.strictEqual(r.status, 404);
        ok("mock page: unknown or malformed reference -> 404");

        // confirm-mock (Postman path) still works
        newReservation("r4", "stuA", 3);
        const p6 = await svc.createPayment("stuA", "r4");
        r = await api("POST", `/${p6.paymentId}/confirm-mock`, "stuA:student");
        assert.strictEqual(r.status, 200);
        assert.strictEqual(coll("reservations").r4.paymentStatus, "paid");
        ok("mock: confirm-mock (Postman) still works");

        // Legacy mock payment created before the page existed (no payUrl)
        newReservation("r5", "stuA", 2, { paymentStatus: "pending" });
        coll("payments").legacy = { paymentId: "legacy", reservationId: "r5", studentId: "stuA", amount: 2, amountMillimes: 2000, currency: "TND", mode: "mock", status: "pending", paymentRef: null, payUrl: null };
        const p7 = await svc.createPayment("stuA", "r5");
        assert.strictEqual(p7.paymentId, "legacy");
        assert.match(p7.payUrl, /mock-checkout\/mock_/);
        assert.strictEqual(coll("payments").legacy.payUrl, p7.payUrl);
        ok("mock: older pending mock payment without a link gets one");

        // ================= SANDBOX =================
        konnectConfig.mode = "sandbox";
        r = await fetch(p4.payUrl);
        assert.strictEqual(r.status, 404);
        assert.match(await r.text(), /désactivé/);
        ok("sandbox: mock page disabled -> 404");

        r = await api("GET", `/webhook?payment_ref=${p4.paymentRef}`);
        assert.strictEqual(r.status, 409);
        assert.strictEqual(coll("payments")[p4.paymentId].status, "pending");
        ok("sandbox: a mock payment cannot be checked against real Konnect (mode mismatch -> 409)");

        konnectConfig.webhookURL = "https://public.example/api/payments/webhook";
        newReservation("s1", "stuA", 4);
        r = await api("POST", "/init", "stuA:student", { reservationId: "s1" });
        body = await r.json();
        assert.strictEqual(r.status, 201, JSON.stringify(body));
        const s1 = body.data;
        const b = konnect.lastInitBody;
        assert.strictEqual(b.amount, 4000);
        assert.strictEqual(b.token, "TND");
        assert.strictEqual(b.orderId, s1.paymentId);
        assert.strictEqual(b.webhook, konnectConfig.webhookURL);
        assert.deepStrictEqual(b.acceptedPaymentMethods, ["bank_card", "wallet", "e-DINAR"]);
        assert.strictEqual(b.addPaymentFeesToAmount, false);
        assert.strictEqual(b.lifespan, 10);
        assert.strictEqual(s1.payUrl, "https://pay/" + s1.paymentRef);
        ok("sandbox: /init sends 4000 millimes, orderId, webhook to Konnect and returns Konnect's payUrl");

        konnectConfig.webhookURL = null;
        newReservation("s9");
        await svc.createPayment("stuA", "s9");
        assert.ok(!("webhook" in konnect.lastInitBody));
        ok("sandbox: no webhook field when KONNECT_WEBHOOK_URL is empty");

        Object.assign(konnect.payments[s1.paymentRef], { status: "completed", reachedAmount: 3000 });
        let rr = res();
        await ctrl.konnectWebhook({ query: { payment_ref: s1.paymentRef } }, rr);
        assert.strictEqual(coll("payments")[s1.paymentId].status, "pending");
        ok("sandbox webhook: amount too low -> not paid");

        konnect.payments[s1.paymentRef].reachedAmount = 4000;
        r = await api("GET", `/webhook?payment_ref=${s1.paymentRef}`);
        assert.deepStrictEqual(await r.json(), { success: true, status: "paid" });
        assert.strictEqual(coll("reservations").s1.paymentStatus, "paid");
        ok("sandbox webhook: Konnect completed -> paid");

        newReservation("s2");
        const s2 = await svc.createPayment("stuA", "s2");
        await rejects(svc.cancelPayment("stuA", s2.paymentId), /still in progress/);
        // Date-only expirationDate (as in Konnect's docs) must not expire a fresh link
        konnect.payments[s2.paymentRef].expirationDate = new Date().toISOString().slice(0, 10);
        await rejects(svc.cancelPayment("stuA", s2.paymentId), /still in progress/);
        assert.strictEqual(coll("payments")[s2.paymentId].status, "pending");
        konnect.payments[s2.paymentRef].expirationDate = new Date(Date.now() - 6 * 60000).toISOString();
        coll("payments")[s2.paymentId].expiresAt = ts(Date.now() - 6 * 60000);
        assert.strictEqual((await svc.cancelPayment("stuA", s2.paymentId)).status, "expired");
        ok("sandbox: cancel refused while link valid (also with a date-only expirationDate), allowed after expiry");

        // Konnect init failure
        const origCreate = fakeAxios.create;
        // Konnect down (HTML 502 from nginx) -> 503 with a clear message
        fakeAxios.create = () => ({ async post() { const e = new Error("Request failed with status code 502"); e.response = { status: 502, data: "<html>502 Bad Gateway</html>" }; throw e; } });
        newReservation("s3");
        r = await api("POST", "/init", "stuA:student", { reservationId: "s3" });
        body = await r.json();
        assert.strictEqual(r.status, 503);
        assert.match(body.message, /temporarily unavailable/);
        assert.strictEqual(coll("reservations").s3.paymentStatus, "failed");
        r = await api("POST", "/init", "stuA:student", { reservationId: "s3" });
        assert.strictEqual(r.status, 503);
        ok("sandbox: Konnect down (502) -> API 503 with a clear message, reservation unblocked and retry allowed");

        // Konnect refuses our request (4xx) -> 502 with Konnect message
        fakeAxios.create = () => ({ async post() { const e = new Error("Request failed with status code 400"); e.response = { status: 400, data: { errors: [{ message: "receiverWalletId is invalid" }] } }; throw e; } });
        newReservation("s4");
        r = await api("POST", "/init", "stuA:student", { reservationId: "s4" });
        body = await r.json();
        assert.strictEqual(r.status, 502);
        assert.match(body.message, /Konnect refused the request: receiverWalletId is invalid/);
        fakeAxios.create = origCreate;
        ok("sandbox: Konnect refuses the request (400) -> API 502 with Konnect message");

        r = await api("GET", "/webhook?payment_ref=bad%20ref$");
        assert.strictEqual(r.status, 400);
        r = await api("GET", "/webhook");
        assert.strictEqual(r.status, 400);
        r = await api("GET", "/webhook?payment_ref=unknownRef");
        assert.strictEqual(r.status, 404);
        ok("webhook: malformed -> 400, missing -> 400, unknown -> 404");

        console.log(`\nALL ${n} TESTS PASSED`);
    } finally {
        server.close();
    }
})().catch((e) => { console.error("TEST FAILED:", e); process.exit(1); });
