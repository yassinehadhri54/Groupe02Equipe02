// Offline test of the bonus "Campus Radar": shop position (registration and
// update), GET /api/shops/nearby (distance, radius, order, filters, privacy).
// Real routes, controller and services over HTTP, with a fake Firestore.
const Module = require("module");
const path = require("path");
const assert = require("assert");

const BACKEND = path.join(__dirname, "..");

// ---------------- fake Firestore ----------------
const store = {};
const coll = (name) => (store[name] ||= {});
const docRef = (name, id) => ({
    id, _name: name,
    async get() { return snap(name, id); },
    async update(data) { Object.assign(coll(name)[id], data); },
    async set(data) { coll(name)[id] = { ...data }; }
});
const snap = (name, id) => {
    const d = coll(name)[id];
    return { id, exists: !!d, data: () => (d ? { ...d } : undefined), ref: docRef(name, id) };
};
const query = (name, filters = [], lim = Infinity) => ({
    where: (f, op, v) => query(name, [...filters, [f, op, v]], lim),
    limit: (n) => query(name, filters, n),
    async get() {
        const docs = Object.keys(coll(name))
            .filter((id) => filters.every(([f, op, v]) => {
                if (op === "==") return coll(name)[id][f] === v;
                if (op === "in") return v.includes(coll(name)[id][f]);
                throw new Error("op " + op);
            }))
            .slice(0, lim)
            .map((id) => snap(name, id));
        return { empty: docs.length === 0, docs };
    }
});
const db = {
    collection(name) {
        return { ...query(name), doc: (id) => docRef(name, id || "auto") };
    },
    async runTransaction(fn) {
        const writes = [];
        const tx = {
            async get(x) { return x.get(); },
            create(ref, data) { writes.push(() => { coll(ref._name)[ref.id] = { ...data }; }); },
            update(ref, data) { writes.push(() => Object.assign(coll(ref._name)[ref.id], data)); }
        };
        const r = await fn(tx);
        writes.forEach((w) => w());
        return r;
    }
};
const fakeAuth = {
    verifyToken(req, res, next) {
        const [uid, role] = String(req.headers["x-test-user"] || "").split(":");
        if (!uid) return res.status(401).json({ success: false });
        req.user = { uid, role };
        next();
    }
};

const origLoad = Module._load;
Module._load = function (request) {
    if (request === "../config/firebase") return { db };
    if (request === "firebase-admin/firestore") return { FieldValue: { serverTimestamp: () => "TS" } };
    if (request === "../middlewares/authMiddleware") return fakeAuth;
    return origLoad.apply(this, arguments);
};

const express = require(path.join(BACKEND, "node_modules", "express"));
const shopRoutes = require(path.join(BACKEND, "routes", "shopRoutes.js"));
const { distanceMeters } = require(path.join(BACKEND, "utils", "geo.js"));

// Student position, and shops placed at known distances to the north (1° of latitude ≈ 111.19 km).
const HERE = { lat: 36.8, lng: 10.18 };
const north = (km) => ({ latitude: Number((HERE.lat + km / 111.19).toFixed(6)), longitude: HERE.lng });

const addShop = (id, extra = {}) => {
    coll("shops")[id] = {
        shopId: id, ownerId: "owner-" + id, ownerName: "Private Owner", ownerEmail: id + "@private.test",
        name: "Shop " + id, address: "Rue " + id, phone: "20123456", email: id + "@shop.test",
        description: "", status: "approved", ...extra
    };
};
const addOffer = (id, shopId, extra = {}) => {
    coll("offers")[id] = {
        shopId, name: "Offer " + id, status: "available", availableQuantity: 3,
        pickupStart: "12:00", pickupEnd: "14:00", ...extra
    };
};

(async () => {
    const app = express();
    app.use(express.json());
    app.use("/api/shops", shopRoutes);
    const server = await new Promise((r) => { const s = app.listen(0, () => r(s)); });
    const base = `http://localhost:${server.address().port}/api/shops`;
    const call = async (method, p, user, body) => {
        const r = await fetch(base + p, {
            method,
            headers: { "content-type": "application/json", ...(user ? { "x-test-user": user } : {}) },
            body: body ? JSON.stringify(body) : undefined
        });
        return { status: r.status, body: await r.json() };
    };

    let n = 0;
    const ok = (m) => console.log(`ok ${++n} - ${m}`);

    try {
        // ---------- distance ----------
        const tunisSousse = distanceMeters(
            { latitude: 36.8065, longitude: 10.1815 },
            { latitude: 35.8256, longitude: 10.6369 }
        );
        assert.ok(tunisSousse > 114000 && tunisSousse < 119000, "Tunis-Sousse " + tunisSousse);
        assert.strictEqual(Math.round(distanceMeters({ latitude: 1, longitude: 1 }, { latitude: 1, longitude: 1 })), 0);
        ok("distance (haversine): Tunis-Sousse ≈ 116 km as the crow flies, same point = 0 m");

        // ---------- registration with a position ----------
        coll("users")["m1"] = { role: "merchant", status: "active", fullName: "Merchant One", email: "m1@test.test" };
        coll("users")["m2"] = { role: "merchant", status: "active", fullName: "Merchant Two", email: "m2@test.test" };
        const shopBody = { name: "Café ESSECT", address: "Avenue de l'université", phone: "20123456" };

        let r = await call("POST", "/register", "m1:merchant", { ...shopBody, latitude: 36.8, longitude: "10.18" });
        assert.strictEqual(r.status, 201, JSON.stringify(r.body));
        assert.strictEqual(r.body.data.latitude, 36.8);
        assert.strictEqual(r.body.data.longitude, 10.18);
        assert.strictEqual(coll("shops").m1.latitude, 36.8);
        ok("registration with latitude/longitude (number or text) stores numbers");

        r = await call("POST", "/register", "m2:merchant", shopBody);
        assert.strictEqual(r.status, 201);
        assert.ok(!("latitude" in coll("shops").m2));
        ok("registration without a position still works (position is optional)");

        for (const [body, re] of [
            [{ latitude: 36.8 }, /together/],
            [{ longitude: 10.1 }, /together/],
            [{ latitude: 91, longitude: 10 }, /latitude must be/],
            [{ latitude: 36, longitude: -181 }, /longitude must be/],
            [{ latitude: "abc", longitude: 10 }, /latitude must be/],
            [{ latitude: "", longitude: 10 }, /latitude must be/],
            [{ latitude: null, longitude: 10 }, /together/]
        ]) {
            delete coll("shops").m3;
            coll("users").m3 = { role: "merchant", status: "active", fullName: "M3", email: "m3@test.test" };
            r = await call("POST", "/register", "m3:merchant", { ...shopBody, ...body });
            assert.strictEqual(r.status, 400, JSON.stringify(body));
            assert.match(r.body.message, re);
            assert.ok(!coll("shops").m3);
        }
        ok("invalid positions (one value, out of range, text, empty, null) -> 400, nothing saved");

        // ---------- update ----------
        r = await call("PUT", "/my-shop", "m2:merchant", { latitude: 36.801, longitude: 10.181 });
        assert.strictEqual(r.status, 200, JSON.stringify(r.body));
        assert.strictEqual(coll("shops").m2.latitude, 36.801);
        r = await call("PUT", "/my-shop", "m2:merchant", { latitude: 36.8 });
        assert.strictEqual(r.status, 400);
        r = await call("PUT", "/my-shop", "m2:merchant", { latitude: 100, longitude: 10 });
        assert.strictEqual(r.status, 400);
        assert.strictEqual(coll("shops").m2.latitude, 36.801);
        r = await call("PUT", "/my-shop", "m2:merchant", { name: "Renamed" });
        assert.strictEqual(r.status, 200);
        assert.strictEqual(coll("shops").m2.longitude, 10.181);
        ok("update: position set and corrected; invalid -> 400 unchanged; other updates keep it");

        // ---------- radar ----------
        for (const k of Object.keys(coll("shops"))) delete coll("shops")[k];
        addShop("A", north(0.3));                                   // 300 m, 2 offers (1 basket)
        addShop("B", north(1.5));                                   // 1.5 km, 1 offer
        addShop("F", north(0.9));                                   // 900 m, no offer
        addShop("C", north(5));                                     // 5 km: outside the default radius
        addShop("D", { ...north(0.1), status: "pending" });        // pending shop
        addShop("E");                                               // approved, no position
        addShop("G", { ...north(0.2), status: "suspended" });      // suspended shop
        addShop("H", { ...north(0.4), status: "rejected" });       // rejected shop
        addOffer("o1", "A");
        addOffer("o2", "A", { offerType: "surprise_basket" });
        addOffer("o3", "A", { pickupStart: "2000-01-01T08:00", pickupEnd: "2000-01-01T10:00" }); // expired
        addOffer("o4", "A", { availableQuantity: 0 });                                          // sold out
        addOffer("o5", "A", { status: "deleted" });
        addOffer("o6", "B", { status: "active" });                                              // other client's format
        addOffer("o7", "C");
        addOffer("o8", "D");

        const q = (extra = "") => `/nearby?lat=${HERE.lat}&lng=${HERE.lng}${extra}`;

        r = await call("GET", q());
        assert.strictEqual(r.status, 200, JSON.stringify(r.body));
        assert.strictEqual(r.body.radiusKm, 2);
        assert.deepStrictEqual(r.body.data.map((s) => s.shopId), ["A", "F", "B"]);
        const [a, f, b] = r.body.data;
        assert.ok(Math.abs(a.distanceMeters - 300) <= 3, "A " + a.distanceMeters);
        assert.ok(Math.abs(b.distanceMeters - 1500) <= 15, "B " + b.distanceMeters);
        assert.strictEqual(a.distanceKm, 0.3);
        assert.strictEqual(a.offersCount, 2);
        assert.strictEqual(a.surpriseBasketsCount, 1);
        assert.strictEqual(f.offersCount, 0);
        assert.strictEqual(b.offersCount, 1);
        assert.strictEqual(r.body.count, 3);
        ok("nearby (no token needed): approved shops with a position within 2 km, nearest first, distance in m/km");
        ok("offersCount counts only offers that can be reserved (no expired, sold-out or deleted), baskets counted apart");

        assert.deepStrictEqual(Object.keys(a).sort(), [
            "address", "description", "distanceKm", "distanceMeters", "latitude", "longitude",
            "name", "offersCount", "phone", "shopId", "surpriseBasketsCount"
        ]);
        assert.ok(!JSON.stringify(r.body).includes("private.test") && !JSON.stringify(r.body).includes("Private Owner"));
        ok("only public fields are returned (no owner name, owner e-mail or owner id)");

        for (const id of ["C", "D", "E", "G", "H"]) {
            assert.ok(!r.body.data.some((s) => s.shopId === id), "should be excluded: " + id);
        }
        ok("excluded: too far, pending, suspended, rejected, and shops without a position");

        r = await call("GET", q("&radius=1"));
        assert.deepStrictEqual(r.body.data.map((s) => s.shopId), ["A", "F"]);
        r = await call("GET", q("&radius=10"));
        assert.deepStrictEqual(r.body.data.map((s) => s.shopId), ["A", "F", "B", "C"]);
        r = await call("GET", q("&radius=0.25"));
        assert.deepStrictEqual(r.body.data, []);
        ok("radius is in km and applied (1 km, 10 km, 250 m)");

        r = await call("GET", q("&radius=10&withOffers=true"));
        assert.deepStrictEqual(r.body.data.map((s) => s.shopId), ["A", "B", "C"]);
        r = await call("GET", q("&radius=10&limit=2"));
        assert.deepStrictEqual(r.body.data.map((s) => s.shopId), ["A", "F"]);
        ok("withOffers=true keeps shops with something to reserve; limit keeps the nearest ones");

        // ---------- bad requests ----------
        for (const [p, re] of [
            ["/nearby", /lat and lng are required/],
            [`/nearby?lat=${HERE.lat}`, /lat and lng are required/],
            ["/nearby?lat=abc&lng=10", /lat must be/],
            ["/nearby?lat=95&lng=10", /lat must be/],
            ["/nearby?lat=36&lng=200", /lng must be/],
            [q("&radius=0"), /radius must be/],
            [q("&radius=-3"), /radius must be/],
            [q("&radius=51"), /radius must be/],
            [q("&radius=abc"), /radius must be/],
            [q("&limit=0"), /limit must be/],
            [q("&limit=1.5"), /limit must be/],
            [q("&limit=101"), /limit must be/],
            [`/nearby?lat=1&lat=2&lng=10`, /single values/]
        ]) {
            r = await call("GET", p);
            assert.strictEqual(r.status, 400, p);
            assert.match(r.body.message, re, p);
        }
        ok("missing, non-numeric or out-of-range lat/lng/radius/limit, and repeated parameters -> 400");

        r = await call("GET", "/");
        assert.strictEqual(r.status, 401);
        r = await call("GET", "/", "s1:student");
        assert.strictEqual(r.status, 403);
        ok("/nearby is not shadowed by other routes: the admin list stays protected (401 / 403)");

        console.log(`\nALL ${n} TESTS PASSED`);
    } finally {
        server.close();
    }
})().catch((e) => { console.error("TEST FAILED:", e); process.exit(1); });
