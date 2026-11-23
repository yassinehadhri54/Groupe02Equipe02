// Offline test of the e-mail receipt sent after a confirmed payment.
// Real paymentService, receiptService and emailService with a fake Firestore,
// a fake Konnect (mock + sandbox) and a fake Nodemailer: no SMTP server, no
// Internet, no real payment.
const Module = require("module");
const path = require("path");
const assert = require("assert");

const BACKEND = path.join(__dirname, "..");

// ---------------- fake Firestore (transactions run one at a time) ----------------
const store = {};
let autoId = 0;
const coll = (name) => (store[name] ||= {});
const ts = (ms) => ({ toMillis: () => ms, toDate: () => new Date(ms) });
const DELETE = Symbol("delete");

const applyUpdate = (target, data) => {
    for (const [k, v] of Object.entries(data)) {
        if (v === DELETE) delete target[k];
        else target[k] = v;
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
let txQueue = Promise.resolve();
const db = {
    collection(name) {
        const q = makeQuery(name);
        return { ...q, doc(id) { return makeDocRef(name, id || "auto" + ++autoId); } };
    },
    runTransaction(fn) {
        const run = async () => {
            const writes = [];
            const tx = {
                async get(x) { return x.get(); },
                update(ref, data) { writes.push(() => applyUpdate(coll(ref._name)[ref.id], data)); },
                set(ref, data) { writes.push(() => { coll(ref._name)[ref.id] = { ...data }; }); }
            };
            const r = await fn(tx);
            writes.forEach((w) => w());
            return r;
        };
        const result = txQueue.then(run);
        txQueue = result.catch(() => {});
        return result;
    }
};
const firestoreStub = {
    FieldValue: { serverTimestamp: () => "SERVER_TS", delete: () => DELETE },
    Timestamp: { fromMillis: ts }
};

// ---------------- fake Nodemailer ----------------
const SMTP = {
    SMTP_HOST: "smtp.test.invalid",
    SMTP_PORT: "587",
    SMTP_USER: "test-user-account",
    SMTP_PASS: "test-secret-password-123",
    EMAIL_FROM: "CampusSave <no-reply@campussave.test>"
};
Object.assign(process.env, SMTP);

const mail = { sent: [], failWith: null, delay: 0 };
const fakeNodemailer = {
    createTransport() {
        return {
            async sendMail(message) {
                if (mail.delay) await new Promise((r) => setTimeout(r, mail.delay));
                if (mail.failWith) throw mail.failWith;
                mail.sent.push(message);
                return { messageId: "<id" + mail.sent.length + "@test>" };
            }
        };
    }
};

const konnectConfig = {
    mode: "mock", baseURL: "https://fake", apiKey: "k", walletId: "w",
    webhookURL: null, publicBaseURL: "http://localhost:0"
};
const konnectApi = { payments: {}, refN: 0 };
const fakeAxios = {
    create: () => ({
        async post(url, body) {
            const ref = "ref" + ++konnectApi.refN;
            konnectApi.payments[ref] = { status: "pending", token: "TND", amount: body.amount, reachedAmount: 0, expirationDate: new Date(Date.now() + 10 * 60000).toISOString() };
            return { data: { payUrl: "https://pay/" + ref, paymentRef: ref } };
        },
        async get(url) {
            return { data: { payment: konnectApi.payments[decodeURIComponent(url.split("/").pop())] } };
        }
    })
};
const fakeNotif = { async notifyUser() {}, async notifyShopOwner() {} };

const origLoad = Module._load;
Module._load = function (request) {
    if (request === "../config/firebase") return { db };
    if (request === "../config/konnect") return konnectConfig;
    if (request === "firebase-admin/firestore") return firestoreStub;
    if (request === "axios") return fakeAxios;
    if (request === "nodemailer") return fakeNodemailer;
    if (request === "./notificationService") return fakeNotif;
    return origLoad.apply(this, arguments);
};

const svc = require(path.join(BACKEND, "services", "paymentService.js"));
const receipts = require(path.join(BACKEND, "services", "receiptService.js"));
const emailService = require(path.join(BACKEND, "services", "emailService.js"));

const flush = () => new Promise((r) => setTimeout(r, 40));
const rejects = async (p, re) => {
    try { await p; } catch (e) { assert.match(e.message, re); return e; }
    throw new Error("expected rejection " + re);
};

const seedStudent = (id, extra = {}) => {
    coll("users")[id] = { uid: id, fullName: "Amine Ben Salah", email: id + "@student.test", role: "student", ...extra };
};
const seedReservation = (id, studentId, extra = {}) => {
    coll("reservations")[id] = {
        reservationId: id, studentId, status: "pending", paymentStatus: "unpaid",
        shopId: "shop1", shopName: "Campus Food", offerName: "Lablebi", quantity: 2,
        unitPrice: 3.25, totalPrice: 6.5, ...extra
    };
};
// Mock mode: what the fake Konnect does when the student clicks "Payer".
const payMock = async (payment) => {
    await require(path.join(BACKEND, "services", "konnect.js")).completeMockPayment(payment.paymentRef);
};

(async () => {
    let n = 0;
    const ok = (m) => console.log(`ok ${++n} - ${m}`);

    // ================= 1. successful payment -> one e-mail =================
    seedStudent("stuA");
    seedReservation("r1", "stuA");
    const p1 = await svc.createPayment("stuA", "r1");
    assert.strictEqual(coll("payments")[p1.paymentId].receiptEmailStatus, undefined);
    await flush();
    assert.strictEqual(mail.sent.length, 0);
    ok("a pending payment (link created, not paid) has no receipt state and sends nothing");

    await payMock(p1);
    let r = await svc.handleKonnectWebhook(p1.paymentRef);
    assert.strictEqual(r.status, "paid");
    await flush();

    assert.strictEqual(mail.sent.length, 1);
    const msg = mail.sent[0];
    assert.strictEqual(msg.to, "stuA@student.test");
    assert.strictEqual(msg.subject, "CampusSave – Payment Confirmation & Electronic Receipt");
    assert.strictEqual(msg.from, SMTP.EMAIL_FROM);
    for (const text of [
        "CampusSave", "Amine Ben Salah", "r1", "Campus Food", "Lablebi",
        "3.250 TND", "6.500 TND", "Confirmed",
        "Thank you for using CampusSave! Your payment has been successfully confirmed. Here are the details of your reservation."
    ]) {
        assert.ok(msg.html.includes(text), "html is missing: " + text);
    }
    assert.match(msg.html, /Quantity<\/td>\s*<td[^>]*>2<\/td>/);
    assert.match(msg.html, /Payment date/);
    assert.ok(msg.text.includes("Total amount paid: 6.500 TND"));
    assert.match(msg.html, /name="viewport"/);
    const stored = coll("payments")[p1.paymentId];
    assert.strictEqual(stored.receiptEmailStatus, "sent");
    assert.strictEqual(stored.receiptSentAt, "SERVER_TS");
    assert.ok(!("receiptEmailError" in stored));
    assert.strictEqual(coll("reservations").r1.paymentStatus, "paid");
    ok("successful payment -> exactly one receipt with all details, recorded as sent");

    // No secrets in the e-mail
    for (const secret of [SMTP.SMTP_PASS, SMTP.SMTP_USER, p1.paymentRef, "mock_"]) {
        assert.ok(!msg.html.includes(secret) && !msg.text.includes(secret), "leaked: " + secret);
    }
    ok("the e-mail contains no SMTP credentials, Konnect reference or token");

    // ================= 5. duplicate webhook / verify -> no second e-mail =================
    await svc.handleKonnectWebhook(p1.paymentRef);
    await svc.verifyKonnectPayment("stuA", p1.paymentId);
    await svc.confirmMockPayment("stuA", p1.paymentId);
    await Promise.all([svc.handleKonnectWebhook(p1.paymentRef), svc.handleKonnectWebhook(p1.paymentRef)]);
    await flush();
    assert.strictEqual(mail.sent.length, 1);
    ok("duplicate webhook, /verify and confirm-mock on a paid payment -> no duplicate receipt");

    // Two sending attempts at the very same time -> a single e-mail
    seedReservation("r1b", "stuA");
    const p1b = await svc.createPayment("stuA", "r1b");
    await payMock(p1b);
    mail.delay = 30;
    await Promise.all([
        svc.handleKonnectWebhook(p1b.paymentRef),
        svc.handleKonnectWebhook(p1b.paymentRef),
        receipts.sendReceiptForPayment(p1b.paymentId),
        receipts.sendReceiptForPayment(p1b.paymentId)
    ]);
    await new Promise((res) => setTimeout(res, 150));
    mail.delay = 0;
    assert.strictEqual(mail.sent.length, 2);
    assert.strictEqual(coll("payments")[p1b.paymentId].receiptEmailStatus, "sent");
    assert.strictEqual(coll("payments")[p1b.paymentId].receiptEmailAttempts, 1);
    ok("simultaneous webhooks and send attempts -> one claim, one e-mail");

    // ================= 2-4. failed / pending / cancelled / expired -> no e-mail =================
    const before = mail.sent.length;

    // pending: the webhook arrives but Konnect says the payment is not completed
    seedReservation("r2", "stuA");
    const p2 = await svc.createPayment("stuA", "r2");
    r = await svc.handleKonnectWebhook(p2.paymentRef);
    assert.strictEqual(r.status, "pending");
    assert.deepStrictEqual(await receipts.sendReceiptForPayment(p2.paymentId), { status: "skipped", reason: "not_paid" });
    assert.strictEqual(coll("payments")[p2.paymentId].receiptEmailStatus, undefined);
    ok("pending payment (webhook arrives, Konnect not completed) -> no e-mail, even if a send is forced");

    // cancelled
    await svc.cancelPayment("stuA", p2.paymentId);
    assert.strictEqual(coll("payments")[p2.paymentId].status, "cancelled");
    assert.deepStrictEqual(await receipts.sendReceiptForPayment(p2.paymentId), { status: "skipped", reason: "not_paid" });
    await rejects(receipts.retryReceipt("stuA", p2.paymentId), /not eligible for a receipt/);
    ok("cancelled payment -> no e-mail, manual retry refused");

    // expired (never paid)
    seedReservation("r3", "stuA");
    const p3 = await svc.createPayment("stuA", "r3");
    coll("payments")[p3.paymentId].expiresAt = ts(Date.now() - 6 * 60000);
    r = await svc.verifyKonnectPayment("stuA", p3.paymentId);
    assert.strictEqual(r.status, "expired");
    assert.deepStrictEqual(await receipts.sendReceiptForPayment(p3.paymentId), { status: "skipped", reason: "not_paid" });
    ok("expired payment -> no e-mail");

    // failed: sandbox Konnect "completed" but the amount is too low -> refused, never paid
    konnectConfig.mode = "sandbox";
    seedReservation("r4", "stuA", { totalPrice: 4, unitPrice: 4, quantity: 1 });
    const p4 = await svc.createPayment("stuA", "r4");
    Object.assign(konnectApi.payments[p4.paymentRef], { status: "completed", reachedAmount: 1000 });
    await rejects(svc.handleKonnectWebhook(p4.paymentRef), /does not match/);
    // failed: Konnect reports a failed attempt (status stays pending on its side)
    seedReservation("r4b", "stuA", { totalPrice: 5, unitPrice: 5, quantity: 1 });
    const p4b = await svc.createPayment("stuA", "r4b");
    konnectApi.payments[p4b.paymentRef].status = "failed";
    r = await svc.handleKonnectWebhook(p4b.paymentRef);
    assert.strictEqual(r.status, "pending");
    // failed: initiation failed
    coll("payments").failedInit = { paymentId: "failedInit", reservationId: "r4", studentId: "stuA", status: "failed", amount: 4 };
    assert.deepStrictEqual(await receipts.sendReceiptForPayment("failedInit"), { status: "skipped", reason: "not_paid" });
    await flush();
    assert.strictEqual(coll("payments")[p4.paymentId].status, "pending");
    assert.strictEqual(coll("payments")[p4b.paymentId].status, "pending");
    assert.strictEqual(mail.sent.length, before);
    ok("failed payments (amount mismatch, Konnect failure, failed initiation) -> no e-mail");

    // sandbox success also sends exactly one e-mail
    seedReservation("r5", "stuA", { totalPrice: 8, unitPrice: 4, quantity: 2 });
    const p5 = await svc.createPayment("stuA", "r5");
    Object.assign(konnectApi.payments[p5.paymentRef], { status: "completed", reachedAmount: 8000 });
    await svc.handleKonnectWebhook(p5.paymentRef);
    await svc.handleKonnectWebhook(p5.paymentRef);
    await flush();
    assert.strictEqual(mail.sent.length, before + 1);
    assert.ok(mail.sent.at(-1).html.includes("8.000 TND"));
    konnectConfig.mode = "mock";
    ok("Konnect sandbox: verified completed payment -> one receipt (webhook sent twice)");

    // ================= 6. e-mail failure: payment stays paid, status recorded =================
    seedReservation("r6", "stuA");
    const p6 = await svc.createPayment("stuA", "r6");
    await payMock(p6);
    const authError = Object.assign(new Error("Invalid login for test-user-account at smtp.test.invalid: 535 secret"), { code: "EAUTH", responseCode: 535 });
    mail.failWith = authError;
    const count6 = mail.sent.length;
    r = await svc.handleKonnectWebhook(p6.paymentRef);
    await flush();
    let p = coll("payments")[p6.paymentId];
    assert.strictEqual(r.status, "paid");
    assert.strictEqual(p.status, "paid");
    assert.strictEqual(coll("reservations").r6.paymentStatus, "paid");
    assert.strictEqual(p.receiptEmailStatus, "failed");
    assert.strictEqual(p.receiptEmailError, "SMTP authentication failed.");
    for (const secret of [SMTP.SMTP_PASS, SMTP.SMTP_USER, SMTP.SMTP_HOST]) {
        assert.ok(!JSON.stringify(p).includes(secret), "stored: " + secret);
    }
    assert.strictEqual(mail.sent.length, count6);
    ok("SMTP failure -> payment and reservation stay paid, receipt 'failed' with a safe message (no credentials stored)");

    // A duplicate webhook does not retry on its own; the student retries explicitly
    await svc.handleKonnectWebhook(p6.paymentRef);
    await flush();
    assert.strictEqual(coll("payments")[p6.paymentId].receiptEmailAttempts, 1);
    await rejects(receipts.retryReceipt("stuB", p6.paymentId), /not allowed/);
    mail.failWith = null;
    const retried = await receipts.retryReceipt("stuA", p6.paymentId);
    assert.strictEqual(retried.receiptEmailStatus, "sent");
    p = coll("payments")[p6.paymentId];
    assert.strictEqual(p.receiptEmailStatus, "sent");
    assert.ok(!("receiptEmailError" in p));
    assert.strictEqual(mail.sent.length, count6 + 1);
    await rejects(receipts.retryReceipt("stuA", p6.paymentId), /already been sent/);
    assert.strictEqual(mail.sent.length, count6 + 1);
    ok("retry after a failure -> sent once; owner only; a sent receipt can never be sent again");

    // Retry limit
    seedReservation("r6b", "stuA");
    const p6b = await svc.createPayment("stuA", "r6b");
    await payMock(p6b);
    mail.failWith = Object.assign(new Error("x"), { code: "ETIMEDOUT" });
    await svc.handleKonnectWebhook(p6b.paymentRef);
    await flush();
    assert.strictEqual(coll("payments")[p6b.paymentId].receiptEmailError, "The SMTP server could not be reached.");
    for (let i = 0; i < receipts.MAX_ATTEMPTS - 1; i++) {
        assert.strictEqual((await receipts.retryReceipt("stuA", p6b.paymentId)).receiptEmailStatus, "failed");
    }
    await rejects(receipts.retryReceipt("stuA", p6b.paymentId), /not eligible for another attempt/);
    mail.failWith = null;
    ok("manual retries are limited");

    // ================= 7. missing student e-mail =================
    seedStudent("stuNoMail", { email: undefined });
    delete coll("users").stuNoMail.email;
    seedReservation("r7", "stuNoMail");
    const p7 = await svc.createPayment("stuNoMail", "r7");
    await payMock(p7);
    const count7 = mail.sent.length;
    r = await svc.handleKonnectWebhook(p7.paymentRef);
    await flush();
    p = coll("payments")[p7.paymentId];
    assert.strictEqual(r.status, "paid");
    assert.strictEqual(p.status, "paid");
    assert.strictEqual(coll("reservations").r7.paymentStatus, "paid");
    assert.strictEqual(p.receiptEmailStatus, "failed");
    assert.strictEqual(p.receiptEmailError, "The student has no valid e-mail address.");
    assert.strictEqual(mail.sent.length, count7);
    // user document deleted altogether
    seedReservation("r7b", "ghost");
    coll("payments").ghost = { paymentId: "ghost", reservationId: "r7b", studentId: "ghost", status: "paid", receiptEmailStatus: "pending", amount: 2 };
    assert.deepStrictEqual(await receipts.sendReceiptForPayment("ghost"), { status: "failed" });
    assert.strictEqual(coll("payments").ghost.receiptEmailStatus, "failed");
    ok("missing student e-mail (or profile) -> payment stays paid, failure recorded, nothing sent, no crash");

    // ================= configuration =================
    for (const name of Object.keys(SMTP)) delete process.env[name];
    seedReservation("r8", "stuA");
    const p8 = await svc.createPayment("stuA", "r8");
    await payMock(p8);
    await svc.handleKonnectWebhook(p8.paymentRef);
    await flush();
    assert.strictEqual(coll("payments")[p8.paymentId].status, "paid");
    assert.strictEqual(coll("payments")[p8.paymentId].receiptEmailStatus, "failed");
    assert.strictEqual(coll("payments")[p8.paymentId].receiptEmailError, "The e-mail service is not configured.");
    Object.assign(process.env, SMTP);
    assert.strictEqual((await receipts.retryReceipt("stuA", p8.paymentId)).receiptEmailStatus, "sent");
    ok("no SMTP settings -> payment unaffected, receipt 'failed'; works after the settings are added (retry)");

    // A claim abandoned by a crash can be taken again after the lock expires
    coll("payments")[p8.paymentId].receiptEmailStatus = "sending";
    coll("payments")[p8.paymentId].receiptEmailLockedUntil = Date.now() + 60000;
    assert.deepStrictEqual(await receipts.sendReceiptForPayment(p8.paymentId), { status: "skipped", reason: "in_progress" });
    coll("payments")[p8.paymentId].receiptEmailLockedUntil = Date.now() - 1;
    assert.strictEqual((await receipts.sendReceiptForPayment(p8.paymentId)).status, "sent");
    ok("a 'sending' claim blocks other attempts, and is released if the server stopped");

    // ================= template safety =================
    const html = emailService.buildReceiptHtml({
        studentName: "<img src=x onerror=alert(1)>", reservationId: "rX", shopName: "A&B \"Shop\"",
        offerName: "<script>alert(1)</script>", quantity: 1, unitPrice: 1, totalAmount: 1, currency: "TND", paidAt: new Date()
    });
    assert.ok(!html.includes("<script>") && !html.includes("<img src=x"));
    assert.ok(html.includes("&lt;script&gt;") && html.includes("A&amp;B &quot;Shop&quot;"));
    const bad = await emailService.sendPaymentReceiptEmail({ to: "not an email", reservationId: "rX" });
    assert.deepStrictEqual(bad, { success: false, error: "The student has no valid e-mail address." });
    ok("names are HTML-escaped; an invalid address is refused before any SMTP call");

    console.log(`\nALL ${n} TESTS PASSED`);
})().catch((e) => { console.error("TEST FAILED:", e); process.exit(1); });
