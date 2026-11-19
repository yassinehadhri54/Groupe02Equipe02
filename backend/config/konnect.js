
const mode = (process.env.PAYMENT_MODE || "mock").toLowerCase();

if (!["mock", "sandbox"].includes(mode)) {
    throw new Error("Invalid PAYMENT_MODE.");
}

const konnectConfig = {
    mode,
    baseURL: "https://api.sandbox.konnect.network/api/v2",
    apiKey: process.env.KONNECT_API_KEY || null,
    walletId: process.env.KONNECT_WALLET_ID || null
};

if (mode === "sandbox") {
    if (!konnectConfig.apiKey || !konnectConfig.walletId) {
        throw new Error("Konnect Sandbox credentials are missing.");
    }
}

module.exports = konnectConfig;
