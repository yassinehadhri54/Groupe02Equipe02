
const mode = (process.env.PAYMENT_MODE || "mock").toLowerCase();

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
    // Konnect cannot reach "localhost": leave empty for local tests and use
    // POST /api/payments/:id/verify instead.
    webhookURL: process.env.KONNECT_WEBHOOK_URL || null
};

if (mode === "sandbox") {
    if (!konnectConfig.apiKey || !konnectConfig.walletId) {
        throw new Error("Konnect Sandbox credentials are missing.");
    }
}

module.exports = konnectConfig;
