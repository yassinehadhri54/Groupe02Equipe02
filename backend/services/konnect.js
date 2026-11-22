// Talks to Konnect: creates a payment link and reads a payment's status.
//
// Two modes, chosen in .env (see config/konnect.js):
// - mock (KONNECT_MOCK=true): a fake Konnect run by this backend. The
//   payment link opens our own test page (GET /api/payments/mock-checkout/:ref)
//   with a "Payer" button. No Konnect account and no Internet needed.
// - sandbox (KONNECT_MOCK=false): the real Konnect test API.
//
// The rest of the backend uses the same two functions in both modes, so the
// payment flow (init -> payment page -> webhook -> status check) is identical.

const axios = require("axios");
const crypto = require("crypto");
const { db } = require("../config/firebase");
const konnectConfig = require("../config/konnect");

// Payment link lifetime, in minutes (Konnect "lifespan").
const PAYMENT_LIFESPAN_MINUTES = 10;

// Values documented by Konnect: "wallet", "bank_card", "e-DINAR".
const ACCEPTED_PAYMENT_METHODS = ["bank_card", "wallet", "e-DINAR"];

const paymentsCollection = db.collection("payments");

const isMock = () => konnectConfig.mode === "mock";

// URL Konnect calls after a payment. In mock mode the fake Konnect calls our
// own server, so a local URL works.
const getWebhookURL = () => {
    if (konnectConfig.webhookURL) {
        return konnectConfig.webhookURL;
    }

    return isMock()
        ? `${konnectConfig.publicBaseURL}/api/payments/webhook`
        : null;
};

// Konnect down (5xx), unreachable or too slow: a clear message the API
// returns as 503, instead of a raw "Request failed with status code 502".
// Errors returned by Konnect for our request (4xx) keep Konnect's message.
const PROVIDER_UNAVAILABLE_MESSAGE =
    "Konnect is temporarily unavailable. Please try again in a few minutes.";

const toProviderError = (error) => {
    const status = error.response?.status;

    if (!error.response || status >= 500 || error.code === "ECONNABORTED") {
        const wrapped = new Error(PROVIDER_UNAVAILABLE_MESSAGE);
        wrapped.cause = error;
        return wrapped;
    }

    const providerMessage =
        typeof error.response.data === "object"
            ? error.response.data?.errors?.[0]?.message || error.response.data?.message
            : null;

    const wrapped = new Error(
        providerMessage
            ? `Konnect refused the request: ${providerMessage}`
            : `Konnect refused the request (HTTP ${status}).`
    );
    wrapped.cause = error;
    return wrapped;
};

const getSandboxClient = () => {
    if (konnectConfig.mode !== "sandbox") {
        throw new Error("Konnect Sandbox is not enabled.");
    }

    if (!konnectConfig.apiKey || !konnectConfig.walletId) {
        throw new Error("Konnect Sandbox credentials are missing.");
    }

    return axios.create({
        baseURL: konnectConfig.baseURL,
        timeout: 15000,
        headers: {
            "x-api-key": konnectConfig.apiKey,
            "Content-Type": "application/json"
        }
    });
};

// --------------------------------------------------
// CREATE A PAYMENT LINK
// amountMillimes: 6.500 TND -> 6500. orderId: our payment ID.
// Returns { paymentRef, payUrl, expiresAtMillis }.
// --------------------------------------------------

const initPayment = async ({ amountMillimes, orderId, description }) => {
    if (!Number.isInteger(amountMillimes) || amountMillimes <= 0) {
        throw new Error("Invalid payment amount.");
    }

    const expiresAtMillis = Date.now() + PAYMENT_LIFESPAN_MINUTES * 60 * 1000;

    if (isMock()) {
        // Random, unguessable reference: it is the only key to the test page.
        const paymentRef = `mock_${crypto.randomBytes(16).toString("hex")}`;

        return {
            paymentRef,
            payUrl: `${konnectConfig.publicBaseURL}/api/payments/mock-checkout/${paymentRef}`,
            expiresAtMillis
        };
    }

    const requestBody = {
        receiverWalletId: konnectConfig.walletId,
        amount: amountMillimes,
        token: "TND",
        type: "immediate",
        description,
        acceptedPaymentMethods: ACCEPTED_PAYMENT_METHODS,
        lifespan: PAYMENT_LIFESPAN_MINUTES,
        checkoutForm: true,
        addPaymentFeesToAmount: false,
        orderId
    };

    const webhookURL = getWebhookURL();

    if (webhookURL) {
        requestBody.webhook = webhookURL;
    }

    const client = getSandboxClient();
    let response;

    try {
        response = await client.post("/payments/init-payment", requestBody);
    } catch (error) {
        throw toProviderError(error);
    }

    const providerData = response.data || {};
    const payUrl = providerData.payUrl;
    const paymentRef =
        providerData.paymentRef ||
        providerData.paymentId ||
        providerData.id;

    if (!payUrl || !paymentRef) {
        throw new Error("Konnect returned an invalid payment response.");
    }

    return { paymentRef, payUrl, expiresAtMillis };
};

// --------------------------------------------------
// READ A PAYMENT FROM KONNECT
// Returns Konnect's payment object: { status, token, amount,
// reachedAmount, expirationDate }. Only "completed" means paid.
// --------------------------------------------------

const getPayment = async (paymentRef) => {
    if (isMock()) {
        const snapshot = await paymentsCollection
            .where("paymentRef", "==", paymentRef)
            .limit(1)
            .get();

        if (snapshot.empty) {
            throw new Error("Payment not found.");
        }

        const payment = snapshot.docs[0].data();
        const completed = payment.mockProviderStatus === "completed";

        return {
            status: completed ? "completed" : "pending",
            token: "TND",
            amount: payment.amountMillimes,
            reachedAmount: completed ? payment.amountMillimes : 0,
            expirationDate:
                payment.expiresAt && typeof payment.expiresAt.toDate === "function"
                    ? payment.expiresAt.toDate().toISOString()
                    : null
        };
    }

    const client = getSandboxClient();
    let response;

    try {
        response = await client.get(`/payments/${encodeURIComponent(paymentRef)}`);
    } catch (error) {
        throw toProviderError(error);
    }

    const providerPayment = response.data?.payment || response.data;

    if (!providerPayment) {
        throw new Error("Unable to retrieve payment details from Konnect.");
    }

    return providerPayment;
};

// --------------------------------------------------
// FAKE KONNECT (mock mode only)
// What Konnect does when the student clicks "Payer": record the payment as
// completed on the provider side, then call the webhook. The backend then
// checks the status again with getPayment() before marking anything paid.
// --------------------------------------------------

const completeMockPayment = async (paymentRef) => {
    if (!isMock()) {
        throw new Error("Mock payments are disabled.");
    }

    const snapshot = await paymentsCollection
        .where("paymentRef", "==", paymentRef)
        .limit(1)
        .get();

    if (snapshot.empty) {
        throw new Error("Payment not found.");
    }

    await snapshot.docs[0].ref.update({ mockProviderStatus: "completed" });
};

// Calls the webhook like Konnect would: GET <webhook>?payment_ref=...
const callMockWebhook = async (paymentRef) => {
    const url = getWebhookURL();

    await axios.get(url, {
        params: { payment_ref: paymentRef },
        timeout: 10000
    });
};

module.exports = {
    PROVIDER_UNAVAILABLE_MESSAGE,
    PAYMENT_LIFESPAN_MINUTES,
    ACCEPTED_PAYMENT_METHODS,
    isMock,
    initPayment,
    getPayment,
    completeMockPayment,
    callMockWebhook
};
