// Offline test of logout + revoked-token handling with a fake Firebase Auth.
const Module = require("module");
const path = require("path");
const assert = require("assert");
const BACKEND = path.join(__dirname, "..");

const calls = { verify: [], revoke: [], removeToken: [] };
let verifyBehavior = () => ({ uid: "u1", email: "u1@test" });
const fakeAuth = {
    async verifyIdToken(token, checkRevoked) { calls.verify.push({ token, checkRevoked }); return verifyBehavior(); },
    async revokeRefreshTokens(uid) { calls.revoke.push(uid); }
};
const fakeDb = { collection: () => ({ doc: () => ({ get: async () => ({ exists: true, data: () => ({ fullName: "U", role: "student", status: "active" }) }) }) }) };
const fakeNotif = { async removeToken(uid, t) { calls.removeToken.push([uid, t]); if (t === "bad") throw new Error("A valid FCM token is required."); } };

const orig = Module._load;
Module._load = function (req) {
    if (req === "../config/firebase") return { auth: fakeAuth, db: fakeDb };
    if (req === "./notificationService") return fakeNotif;
    return orig.apply(this, arguments);
};

const { verifyToken } = require(path.join(BACKEND, "middlewares", "authMiddleware.js"));
const { logout } = require(path.join(BACKEND, "controllers", "authController.js"));
const res = () => ({ code: 0, body: null, status(c) { this.code = c; return this; }, json(b) { this.body = b; return this; } });

(async () => {
    let n = 0; const ok = (m) => console.log(`ok ${++n} - ${m}`);

    let r = res(); let nextCalled = false;
    const req = { headers: { authorization: "Bearer good" } };
    await verifyToken(req, r, () => { nextCalled = true; });
    assert.ok(nextCalled); assert.strictEqual(calls.verify.at(-1).checkRevoked, true);
    ok("verifyToken checks revocation (checkRevoked = true)");

    for (const [code, re] of [["auth/id-token-revoked", /logged out/], ["auth/id-token-expired", /expired/], ["auth/user-disabled", /disabled/], ["auth/argument-error", /Invalid or expired/]]) {
        verifyBehavior = () => { const e = new Error("x"); e.code = code; throw e; };
        r = res(); nextCalled = false;
        await verifyToken({ headers: { authorization: "Bearer t" } }, r, () => { nextCalled = true; });
        assert.strictEqual(r.code, 401); assert.ok(!nextCalled); assert.match(r.body.message, re);
    }
    ok("revoked / expired / disabled / invalid token -> 401 with a clear message");

    r = res();
    await logout({ user: { uid: "u1" }, body: { fcmToken: "device-token" } }, r);
    assert.strictEqual(r.code, 200);
    assert.deepStrictEqual(calls.revoke, ["u1"]);
    assert.deepStrictEqual(calls.removeToken, [["u1", "device-token"]]);
    ok("logout revokes the user's sessions and removes the device FCM token");

    r = res();
    await logout({ user: { uid: "u1" } }, r);
    assert.strictEqual(r.code, 200); assert.strictEqual(calls.revoke.length, 2); assert.strictEqual(calls.removeToken.length, 1);
    ok("logout without body works (Express 5: req.body undefined)");

    r = res();
    await logout({ user: { uid: "u1" }, body: { fcmToken: "bad" } }, r);
    assert.strictEqual(r.code, 200); assert.strictEqual(calls.revoke.length, 3);
    ok("logout still revokes when FCM token removal fails");

    fakeAuth.revokeRefreshTokens = async () => { throw new Error("network"); };
    r = res();
    await logout({ user: { uid: "u1" }, body: {} }, r);
    assert.strictEqual(r.code, 500); assert.strictEqual(r.body.success, false);
    ok("revocation failure -> 500, never reports a fake success");

    console.log(`\nALL ${n} TESTS PASSED`);
})().catch((e) => { console.error("TEST FAILED:", e); process.exit(1); });
