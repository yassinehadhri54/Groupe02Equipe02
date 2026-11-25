const assert = require("node:assert/strict");
const { once } = require("node:events");
const Module = require("node:module");
const test = require("node:test");
const express = require("express");

const data = new Map();
let nextId = 0;
let failListing = false;

const fieldValue = (record, field) =>
    field.split(".").reduce((value, key) => value?.[key], record);

function reference(path) {
    return {
        path,
        id: path.split("/").at(-1),
        collection: name => collection(`${path}/${name}`),
        async get() {
            const document = data.get(path);
            return { id: this.id, ref: this, exists: document !== undefined, data: () => document };
        },
        async update(fields) {
            assert(data.has(path));
            const updated = { ...data.get(path) };
            for (const [field, value] of Object.entries(fields)) {
                const [parent, child] = field.split(".");
                if (child === undefined) updated[parent] = value;
                else updated[parent] = { ...updated[parent], [child]: value };
            }
            data.set(path, updated);
        },
        async set(fields) {
            data.set(path, fields);
        }
    };
}

function collection(path, filters = [], maximum) {
    return {
        doc: (id = `test-${++nextId}`) => reference(`${path}/${id}`),
        where: (...filter) => collection(path, [...filters, filter], maximum),
        limit: count => collection(path, filters, count),
        async get() {
            if (failListing && path === "offers") throw new Error("DATABASE_UNAVAILABLE");
            const paths = [...data.keys()].filter(key => {
                if (!key.startsWith(`${path}/`) || key.slice(path.length + 1).includes("/")) return false;
                return filters.every(([field, operator, value]) =>
                    operator === "in"
                        ? value.includes(fieldValue(data.get(key), field))
                        : fieldValue(data.get(key), field) === value
                );
            });
            const docs = await Promise.all(paths.slice(0, maximum ?? paths.length).map(key => reference(key).get()));
            return { docs, empty: docs.length === 0 };
        }
    };
}

const db = {
    collection,
    getAll: (...refs) => Promise.all(refs.map(ref => ref.get())),
    batch() {
        const writes = [];
        return {
            set: (ref, values) => writes.push(() => ref.set(values)),
            create: (ref, values) => writes.push(() => { assert(!data.has(ref.path)); return ref.set(values); }),
            commit: () => Promise.all(writes.map(write => write()))
        };
    },
    async runTransaction(run) {
        const writes = [];
        const result = await run({
            get: ref => ref.get(),
            update: (ref, values) => writes.push(() => ref.update(values)),
            set: (ref, values) => writes.push(() => data.set(ref.path, values)),
            delete: ref => writes.push(() => data.delete(ref.path))
        });
        for (const write of writes) await write();
        return result;
    }
};
const auth = {
    async createUser() { return { uid: "registered-" + ++nextId }; },
    async verifyIdToken(token, checkRevoked) {
        assert.equal(checkRevoked, true);
        if (!data.has(`users/${token}`)) throw new Error("invalid test credential");
        return { uid: token };
    }
};

// Replace all application access to Firebase and FCM before loading the real routers.
const load = Module._load;
let authRoutes, adminRoutes, offerRoutes, reservationRoutes, paymentRoutes, dashboardRoutes;
try {
    Module._load = function (name, parent, isMain) {
        if (name === "../config/firebase") return { auth, db };
        if (name === "./notificationService") {
            return { notifyShopOwner: async () => {}, notifyUser: async () => {} };
        }
        if (name === "../config/konnect") return { mode: "mock" };
        if (name === "axios") {
            return { create: () => assert.fail("The mock scenario must never contact Konnect") };
        }
        return load.call(this, name, parent, isMain);
    };
    authRoutes = require("../routes/authRoutes");
    adminRoutes = require("../routes/adminOfferRoutes");
    offerRoutes = require("../routes/offerRoutes");
    reservationRoutes = require("../routes/reservationRoutes");
    paymentRoutes = require("../routes/paymentRoutes");
    dashboardRoutes = require("../routes/dashboardRoutes");
} finally {
    Module._load = load;
}

const legacy = {
    title: "Pâtés maison", description: "Recette fraîche",
    category: "Repas", merchantId: "merchant",
    shopId: "shop", status: "active",
    originalPrice: 12, discountedPrice: 6,
    pickupStart: "12:00", pickupEnd: "14:00",
    quantity: 5, availableQuantity: 4
};

let server;
test.before(async () => {
    const app = express();
    app.use("/api/admin/offers", adminRoutes);
    app.use(express.json());
    app.use("/api/auth", authRoutes);
    app.use("/api/offers", offerRoutes);
    app.use("/api/reservations", reservationRoutes);
    app.use("/api/payments", paymentRoutes);
    app.use("/api/dashboard", dashboardRoutes);
    server = app.listen(0, "127.0.0.1");
    await once(server, "listening");
});
test.after(async () => {
    server.close();
    await once(server, "close");
});
test.beforeEach(() => {
    data.clear();
    failListing = false;
    data.set("users/admin", { role: "admin", status: "active" });
    data.set("users/student", { role: "student", status: "active" });
    data.set("users/merchant", { role: "merchant", status: "active" });
    data.set("users/suspended", { role: "admin", status: "suspended" });
    data.set("users/pending", { role: "admin", status: "pending" });
    data.set("offers/legacy", { ...legacy });
    data.set("offers/expired", { ...legacy, title: "Ancien", pickupEnd: "2000-01-01T14:00", adminDisabled: true });
    data.set("shops/shop", { name: "Épicerie Centrale", address: "Tunis", status: "approved", ownerId: "merchant" });
    data.set("reservations/previous", {
        studentId: "student", offerId: "legacy", shopId: "shop",
        quantity: 1, status: "pending", paymentStatus: "unpaid"
    });
});

const request = async (path, { token = "admin", method = "GET", body, raw } = {}) => {
    const response = await fetch(`http://127.0.0.1:${server.address().port}${path}`, {
        method,
        headers: {
            ...(token === null ? {} : { Authorization: `Bearer ${token}` }),
            ...(body === undefined && raw === undefined ? {} : { "Content-Type": "application/json" })
        },
        body: raw ?? (body === undefined ? undefined : JSON.stringify(body))
    });
    return { status: response.status, body: await response.json() };
};
const moderate = (adminDisabled, reason) =>
    request("/api/admin/offers/legacy/moderation", {
        method: "PUT", body: { adminDisabled, reason }
    });
const history = () => [...data.entries()].filter(([path]) => path.startsWith("offers/legacy/moderationHistory/"));

test("admin routes require a valid token, admin role and active status", async () => {
    const endpoints = [
        ["/api/admin/offers", "GET"],
        ["/api/admin/offers/legacy", "GET"],
        ["/api/admin/offers/legacy/moderation", "PUT"]
    ];
    for (const [path, method] of endpoints) {
        for (const [token, status] of [[null, 401], ["invalid", 401], ["merchant", 403], ["student", 403], ["suspended", 403], ["pending", 403]]) {
            const result = await request(path, { token, method, body: method === "PUT" ? { adminDisabled: true } : undefined });
            assert.equal(result.status, status, `${method} ${path} for ${token}`);
        }
    }
    assert.equal(history().length, 0);
});

test("merchant registration accepts the two-step flow and validates an optional legacy shop", async () => {
    const body = { fullName: "Test Merchant", email: "merchant@example.test", password: "simulated-password", role: "merchant" };
    const ordinary = await request("/api/auth/register", { method: "POST", token: null, body });
    assert.equal(ordinary.status, 201);
    assert.equal(ordinary.body.user.status, "pending");
    assert.equal(data.has("shops/" + ordinary.body.user.uid), false);
    const invalid = await request("/api/auth/register", { method: "POST", token: null, body: { ...body, shopName: "Only the name" } });
    assert.equal(invalid.status, 400);
    const compatible = await request("/api/auth/register", { method: "POST", token: null, body: { ...body, shopName: "Test Shop", shopAddress: "Tunis", shopPhone: "12345678" } });
    assert.equal(compatible.status, 201);
    const uid = compatible.body.user.uid;
    assert.equal(compatible.body.user.shopId, uid);
    assert.equal(data.get("shops/" + uid).status, "pending");
});

test("legacy listings use canonical permissions and admin cannot delete offers", async () => {
    const compatible = await request("/api/offers/admin/all");
    assert.equal(compatible.status, 200);
    assert.deepEqual(compatible.body.offers, compatible.body.data);
    assert.equal((await request("/api/offers/admin/all", { token: "merchant" })).status, 403);
    assert.equal((await request("/api/offers/admin/all", { token: "pending" })).status, 403);
    assert.equal((await request("/api/offers/my", { token: "merchant" })).status, 200);
    assert.equal((await request("/api/offers/legacy", { method: "DELETE" })).status, 403);
});

test("admin lists legacy and expired offers, filters by text and returns shop details", async () => {
    const all = await request("/api/admin/offers");
    assert.equal(all.status, 200);
    assert.deepEqual(all.body.data.map(offer => [offer.id, offer.adminDisabled]), [["expired", true], ["legacy", false]]);
    const filters = await request("/api/admin/offers?q=pates+epicerie&category=repas&status=active&adminDisabled=false");
    assert.deepEqual(filters.body.data.map(offer => offer.id), ["legacy"]);
    const expired = await request("/api/admin/offers?status=expired");
    assert.deepEqual(expired.body.data.map(offer => offer.id), ["expired"]);
    const disabled = await request("/api/admin/offers?adminDisabled=true");
    assert.deepEqual(disabled.body.data.map(offer => offer.id), ["expired"]);
    const detail = await request("/api/admin/offers/legacy");
    assert.equal(detail.body.data.offer.discountPrice, 6);
    assert.equal(detail.body.data.shop.address, "Tunis");
    assert.equal((await request("/api/admin/offers/missing")).status, 404);
});

test("admin rejects malformed requests and reports backend errors", async () => {
    for (const suffix of ["?adminDisabled=yes", "?q=a&q=b", "?unexpected=true", "/a%2Fb", "/a%GG"]) {
        assert.equal((await request(`/api/admin/offers${suffix}`)).status, 400);
    }
    for (const body of [{}, { adminDisabled: "true" }, { adminDisabled: true, role: "student" }, { adminDisabled: true, reason: "x".repeat(501) }]) {
        const result = await request("/api/admin/offers/legacy/moderation", { method: "PUT", body });
        assert.equal(result.status, 400);
    }
    assert.equal((await request("/api/admin/offers/legacy/moderation", { method: "PUT", raw: "{" })).status, 400);
    assert.equal((await request("/api/admin/offers/missing/moderation", { method: "PUT", body: { adminDisabled: true } })).status, 404);
    assert.equal(history().length, 0);
    failListing = true;
    const failure = await request("/api/admin/offers");
    assert.equal(failure.status, 500);
    assert.equal(failure.body.message, "Could not retrieve offers.");
});

test("moderation blocks new bookings and preserves existing reservations and merchant edits", async () => {
    const disable = await moderate(true, "  Vérification  ");
    assert.equal(disable.status, 200);
    assert.deepEqual(data.get("offers/legacy"), { ...legacy, adminDisabled: true });
    assert.equal(history().length, 1);
    assert.equal(history()[0][1].administratorId, "admin");
    assert.equal(history()[0][1].reason, "Vérification");
    assert.ok(history()[0][1].createdAt);
    await moderate(true);
    assert.equal(history().length, 1);
    assert.deepEqual((await request("/api/offers")).body.data, []);
    const direct = await request("/api/offers/legacy");
    assert.equal(direct.body.data.adminDisabled, true);
    const booking = { token: "student", method: "POST", body: { offerId: "legacy", quantity: 1 } };
    assert.equal((await request("/api/reservations", booking)).status, 400);
    assert.equal(data.get("offers/legacy").availableQuantity, 4);
    assert.equal(data.get("reservations/previous").status, "pending");

    const merchantList = await request("/api/offers/merchant/my-offers", { token: "merchant" });
    assert.equal(merchantList.body.data[0].adminDisabled, true);
    const update = await request("/api/offers/legacy", {
        token: "merchant", method: "PUT", body: { name: "Nom modifié", adminDisabled: false, status: "available" }
    });
    assert.equal(update.status, 200);
    assert.equal(update.body.data.adminDisabled, true);
    assert.equal(update.body.data.status, "active");
    assert.equal(update.body.data.title, "Nom modifié");
    assert.equal((await request("/api/offers/legacy", { token: "merchant", method: "DELETE" })).status, 403);

    const cancel = await request("/api/reservations/previous/cancel", { token: "student", method: "PUT" });
    assert.equal(cancel.status, 200);
    assert.equal(data.get("reservations/previous").status, "cancelled");
    assert.equal(data.get("offers/legacy").availableQuantity, 5);
    assert.equal(data.get("offers/legacy").adminDisabled, true);

    assert.equal((await moderate(false)).status, 200);
    assert.equal(history().length, 2);
    assert.equal(history()[1][1].adminDisabled, false);
    assert.equal((await request("/api/offers")).body.data.length, 1);
    assert.equal((await request("/api/reservations", booking)).status, 201);
});

test("lifting the admin block still respects shop approval, stock, lifecycle and expiry", async () => {
    for (const [fields, shopStatus] of [
        [{}, "suspended"], [{ availableQuantity: 0 }, "approved"],
        [{ status: "deleted" }, "approved"], [{ pickupEnd: "2000-01-01T14:00" }, "approved"]
    ]) {
        data.set("offers/legacy", { ...legacy, ...fields, adminDisabled: true });
        data.set("shops/shop", { ...data.get("shops/shop"), status: shopStatus });
        assert.equal((await moderate(false)).status, 200);
        assert.equal(data.get("offers/legacy").adminDisabled, false);
        assert.equal((await request("/api/offers")).body.data.length, 0);
        assert.equal((await request("/api/reservations", {
            token: "student", method: "POST", body: { offerId: "legacy", quantity: 1 }
        })).status, 400);
    }
});

test("merchant can still create and delete an unmoderated offer", async () => {
    const created = await request("/api/offers", {
        method: "POST", token: "merchant",
        body: {
            name: "Repas test", category: "Repas", originalPrice: 10,
            discountPrice: 5, quantity: 2, pickupStart: "12:00", pickupEnd: "14:00",
            adminDisabled: true
        }
    });
    assert.equal(created.status, 201);
    const id = created.body.data.offerId;
    assert.equal(data.get(`offers/${id}`).adminDisabled, undefined);
    assert.equal((await request(`/api/offers/${id}`, { method: "DELETE", token: "merchant" })).status, 200);
    assert.equal(data.has(`offers/${id}`), false);
});

test("three-role journey completes with mock payment and single-use QR after moderation", async () => {
    const student = { token: "student" };
    const merchant = { token: "merchant" };
    const post = (path, role, body) => request(path, { ...role, method: "POST", body });

    const published = await post("/api/offers", merchant, {
        name: "Panier QA isolé", category: "Repas", originalPrice: 12,
        discountPrice: 5, quantity: 3, pickupStart: "12:00", pickupEnd: "14:00"
    });
    assert.equal(published.status, 201);
    const offerId = published.body.data.offerId;
    const catalogue = await request("/api/offers?q=panier+qa", { token: null });
    assert.deepEqual(catalogue.body.data.map(offer => offer.id), [offerId]);

    const booked = await post("/api/reservations", student, { offerId, quantity: 2 });
    assert.equal(booked.status, 201);
    const reservation = booked.body.data;
    const id = reservation.reservationId;
    const bookingPath = `/api/reservations/${id}`;
    assert.equal(reservation.status, "pending");
    assert.equal(reservation.paymentStatus, "unpaid");
    assert.equal(reservation.totalPrice, 10);
    assert.equal(data.get(`offers/${offerId}`).availableQuantity, 1);
    assert.equal((await request(`${bookingPath}/qr`, student)).status, 400);

    assert.equal((await request(`/api/admin/offers/${offerId}/moderation`, {
        method: "PUT", body: { adminDisabled: true }
    })).status, 200);
    assert.equal((await request("/api/offers?q=panier+qa", student)).body.count, 0);
    assert.equal((await post("/api/reservations", student, { offerId, quantity: 1 })).status, 400);
    assert.equal(data.get(`offers/${offerId}`).availableQuantity, 1);
    assert.equal((await request("/api/reservations/my-reservations", student)).body.data.find(r => r.reservationId === id).status, "pending");
    assert.equal((await request(`/api/admin/offers/${offerId}`)).body.data.offer.adminDisabled, true);

    assert.equal((await request("/api/payments/config", student)).body.data.mode, "mock");
    const payment = await post("/api/payments/initiate", student, { reservationId: id });
    assert.equal(payment.status, 201);
    assert.equal(payment.body.data.status, "pending");
    assert.equal(payment.body.data.mode, "mock");
    assert.equal(payment.body.data.payUrl, null);
    assert.equal(data.get(`reservations/${id}`).paymentStatus, "pending");
    const paymentId = payment.body.data.paymentId;
    const repeated = await post("/api/payments/initiate", student, { reservationId: id });
    assert.equal(repeated.status, 200);
    assert.equal(repeated.body.data.paymentId, paymentId);
    assert.equal((await post(`/api/payments/${paymentId}/confirm-mock`, student)).body.data.status, "paid");
    assert.equal((await request(`/api/payments/${paymentId}`, student)).body.data.status, "paid");
    assert.equal(data.get(`reservations/${id}`).status, "pending");
    assert.equal(data.get(`reservations/${id}`).paymentStatus, "paid");

    const orders = await request("/api/reservations/merchant", merchant);
    assert.equal(orders.body.data.find(r => r.reservationId === id).paymentStatus, "paid");
    const qr = await request(`${bookingPath}/qr`, student);
    assert.equal(qr.status, 200);
    assert.match(qr.body.data.qrCode, /^data:image\/png;base64,/);
    assert.match(qr.body.data.token, /^[a-f0-9]{64}$/);
    const storedQr = data.get(`reservations/${id}`).qr;
    assert.notEqual(storedQr.tokenHash, qr.body.data.token);
    assert.equal(storedQr.usedAt, null);
    const pickup = token => post("/api/reservations/verify-qr", merchant, { token });
    assert.equal((await pickup("invalide")).status, 400);
    assert.equal((await pickup(qr.body.data.token)).status, 400);

    assert.equal((await request(`${bookingPath}/status`, {
        ...merchant, method: "PUT", body: { status: "confirmed" }
    })).body.data.status, "confirmed");
    const completed = await pickup(qr.body.data.token);
    assert.equal(completed.status, 200);
    assert.equal(completed.body.data.status, "completed");
    assert.equal(completed.body.data.paymentStatus, "paid");
    assert.ok(data.get(`reservations/${id}`).qr.usedAt);
    const replay = await pickup(qr.body.data.token);
    assert.equal(replay.status, 400);
    assert.match(replay.body.message, /already been used/);
    assert.equal(data.get(`offers/${offerId}`).availableQuantity, 1);

    const dashboard = await request("/api/dashboard/admin");
    assert.equal(dashboard.status, 200);
    assert.equal(dashboard.body.data.reservations.byStatus.completed, 1);
    assert.equal(dashboard.body.data.reservations.itemsRescued, 2);
    assert.equal(dashboard.body.data.payments.paidVolume.byMode.mock, 10);
    assert.equal((await request("/api/dashboard/admin", student)).status, 403);
});
