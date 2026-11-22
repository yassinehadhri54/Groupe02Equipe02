// Payment mode, read from .env:
// - KONNECT_MOCK=true  -> "mock": fake payment page served by this backend.
// - KONNECT_MOCK=false -> "sandbox": real Konnect test mode (needs the keys).
// PAYMENT_MODE=mock|sandbox is still accepted when KONNECT_MOCK is not set.

const readMode = () => {
    const mockFlag = (process.env.KONNECT_MOCK || "").trim().toLowerCase();

    if (mockFlag) {
        if (["true", "1", "yes"].includes(mockFlag)) return "mock";
        if (["false", "0", "no"].includes(mockFlag)) return "sandbox";
        throw new Error("Invalid KONNECT_MOCK (use true or false).");
    }

    return (process.env.PAYMENT_MODE || "mock").trim().toLowerCase();
};

const mode = readMode();

if (!["mock", "sandbox"].includes(mode)) {
    throw new Error("Invalid PAYMENT_MODE.");
}

const konnectConfig = {
    mode,
    baseURL: "https://api.sandbox.konnect.network/api/v2",
    apiKey: process.env.KONNECT_API_KEY || null,
    walletId: process.env.KONNECT_WALLET_ID || null,
    // Optional public URL Konnect calls (GET ?payment_ref=...) after a payment.
    // Example: https://<public-host>/api/payments/webhook
    // Konnect cannot reach "localhost": in sandbox, leave it empty for local
    // tests and use POST /api/payments/:id/verify instead.
    webhookURL: process.env.KONNECT_WEBHOOK_URL || null,
    // Address of this backend as seen by the student's browser. Used for the
    // mock payment page link. Use the PC's IP (http://192.168.x.x:5000) when
    // testing from a phone.
    publicBaseURL: (
        process.env.PUBLIC_BASE_URL ||
        `http://localhost:${process.env.PORT || 5000}`
    ).replace(/\/+$/, "")
};

if (mode === "sandbox") {
    if (!konnectConfig.apiKey || !konnectConfig.walletId) {
        throw new Error("Konnect Sandbox credentials are missing.");
    }
}

module.exports = konnectConfig;
