
const paymentService = require("../services/paymentService");

const getUserId = (req) => req.user?.uid || req.user?.userId || null;

const isStudent = (req) => req.user?.role === "student";

const getErrorStatus = (error) => {
    const message = error.message || "";

    // Konnect side: down / unreachable (503) or refused our request (502).
    if (message.includes("temporarily unavailable")) return 503;
    if (message.startsWith("Konnect refused the request")) return 502;

    if (message.includes("not found")) return 404;
    if (
        message.includes("not allowed") ||
        message.includes("not authorized")
    ) return 403;
    if (
        message.includes("already") ||
        message.includes("in progress") ||
        message.includes("not eligible") ||
        message.includes("no longer eligible") ||
        message.includes("does not match") ||
        message.includes("created in") ||
        message.includes("not pending") ||
        message.includes("not available") ||
        message.includes("must be") ||
        message.includes("status is invalid")
    ) return 409;
    if (
        message.includes("required") ||
        message.includes("Invalid") ||
        message.includes("invalid") ||
        message.includes("disabled")
    ) return 400;

    return 500;
};

// POST /api/payments/initiate
const initiatePayment = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can initiate payments."
            });
        }

        const studentId = getUserId(req);
        const { reservationId } = req.body || {};

        if (!reservationId) {
            return res.status(400).json({
                success: false,
                message: "Reservation ID is required."
            });
        }

        const payment = await paymentService.createPayment(
            studentId,
            reservationId
        );

        return res.status(payment.reused ? 200 : 201).json({
            success: true,
            message: payment.reused
                ? "Existing payment retrieved successfully."
                : "Payment initiated successfully.",
            data: payment
        });
    } catch (error) {
        console.error("Initiate payment error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to initiate payment."
        });
    }
};

// POST /api/payments/:id/verify
const verifyPayment = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can verify payments."
            });
        }

        const studentId = getUserId(req);
        const paymentId = req.params.id;

        const result = await paymentService.verifyKonnectPayment(
            studentId,
            paymentId
        );

        return res.status(200).json({
            success: true,
            message: result.message,
            data: result
        });
    } catch (error) {
        console.error("Verify payment error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to verify payment."
        });
    }
};

// GET /api/payments/webhook?payment_ref=...
// Public: called by Konnect. The status is re-fetched from Konnect,
// so the request itself is never trusted.
const konnectWebhook = async (req, res) => {
    try {
        const paymentRef = req.query.payment_ref;

        if (!paymentRef || typeof paymentRef !== "string") {
            return res.status(400).json({
                success: false,
                message: "payment_ref is required."
            });
        }

        const result = await paymentService.handleKonnectWebhook(paymentRef);

        // Only the status is returned: this endpoint is public.
        return res.status(200).json({
            success: true,
            status: result.status
        });
    } catch (error) {
        console.error(
            "Konnect webhook error:",
            error.response?.data || error.message
        );

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: "Unable to process payment notification."
        });
    }
};

// POST /api/payments/:id/cancel
const cancelPayment = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can cancel payments."
            });
        }

        const result = await paymentService.cancelPayment(
            getUserId(req),
            req.params.id
        );

        return res.status(200).json({
            success: true,
            message: result.message,
            data: result
        });
    } catch (error) {
        console.error("Cancel payment error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to cancel payment."
        });
    }
};

// POST /api/payments/:id/confirm-mock
const confirmMockPayment = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can confirm mock payments."
            });
        }

        const studentId = getUserId(req);
        const paymentId = req.params.id;

        const result = await paymentService.confirmMockPayment(
            studentId,
            paymentId
        );

        return res.status(200).json({
            success: true,
            message: result.message,
            data: result
        });
    } catch (error) {
        console.error("Mock payment confirmation error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to confirm mock payment."
        });
    }
};

// --------------------------------------------------
// MOCK PAYMENT PAGE (KONNECT_MOCK=true only)
// HTML page opened by the student's browser through payUrl.
// --------------------------------------------------

const escapeHtml = (value) =>
    String(value ?? "").replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        "\"": "&quot;",
        "'": "&#39;"
    })[char]);

const formatAmount = (amount) =>
    Number(amount).toLocaleString("fr-TN", {
        minimumFractionDigits: 3,
        maximumFractionDigits: 3
    });

const renderMockPage = ({ title, body, tone = "neutral" }) => {
    const accent = {
        neutral: "#0f766e",
        success: "#15803d",
        error: "#b91c1c"
    }[tone];

    return `<!doctype html>
<html lang="fr">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="robots" content="noindex">
<title>${escapeHtml(title)} · Paiement simulé</title>
<style>
  * { box-sizing: border-box; }
  body { margin: 0; min-height: 100vh; display: grid; place-items: center; padding: 16px;
         font-family: system-ui, -apple-system, "Segoe UI", Roboto, sans-serif;
         background: #f1f5f9; color: #0f172a; }
  .card { width: 100%; max-width: 380px; background: #fff; border-radius: 16px; padding: 28px 24px;
          box-shadow: 0 10px 30px rgba(15, 23, 42, .08); }
  .badge { display: inline-block; font-size: 12px; font-weight: 600; letter-spacing: .04em;
           text-transform: uppercase; color: #92400e; background: #fef3c7; border-radius: 999px; padding: 4px 10px; }
  h1 { font-size: 20px; margin: 16px 0 4px; color: ${accent}; }
  p { margin: 8px 0; line-height: 1.5; color: #334155; }
  .amount { font-size: 34px; font-weight: 700; color: #0f172a; margin: 18px 0 4px; }
  .muted { font-size: 13px; color: #64748b; }
  button { width: 100%; margin-top: 22px; padding: 14px; font-size: 16px; font-weight: 600; color: #fff;
           background: ${accent}; border: 0; border-radius: 10px; cursor: pointer; }
  button:hover { filter: brightness(1.08); }
  button:disabled { opacity: .6; cursor: wait; }
</style>
</head>
<body>
<main class="card">
  <span class="badge">Mode test · Konnect simulé</span>
  ${body}
  <p class="muted">Aucun argent réel n'est débité. Vous pouvez fermer cette page et revenir dans l'application.</p>
</main>
</body>
</html>`;
};

const describeCheckout = (checkout) => {
    const item = [checkout.quantity ? `${checkout.quantity} ×` : "", checkout.offerName]
        .filter(Boolean)
        .join(" ");

    const parts = [
        item ? `<p><strong>${escapeHtml(item)}</strong></p>` : "",
        checkout.shopName ? `<p>${escapeHtml(checkout.shopName)}</p>` : ""
    ];

    return parts.join("");
};

const sendMockPage = (res, status, page) =>
    res.status(status).type("html").send(renderMockPage(page));

const sendMockError = (res, error) => {
    const message = error.message || "";

    let status = 500;
    let text = "Ce paiement n'est pas disponible.";

    if (message.includes("disabled")) {
        status = 404;
        text = "Le paiement simulé est désactivé (KONNECT_MOCK=false).";
    } else if (message.includes("expired")) {
        status = 410;
        text = "Ce lien de paiement a expiré. Relancez le paiement depuis l'application.";
    } else if (message.includes("not pending")) {
        status = 409;
        text = "Ce paiement a été annulé ou a expiré. Relancez le paiement depuis l'application.";
    } else if (message.includes("not found") || message.includes("Invalid")) {
        status = 404;
        text = "Lien de paiement introuvable.";
    } else if (message.includes("eligible") || message.includes("invalid")) {
        status = 409;
        text = "La réservation n'accepte plus de paiement (annulée ou modifiée).";
    }

    return sendMockPage(res, status, {
        title: "Paiement impossible",
        tone: "error",
        body: `<h1>Paiement impossible</h1><p>${escapeHtml(text)}</p>`
    });
};

const paidPage = (checkout) => ({
    title: "Paiement réussi",
    tone: "success",
    body: `<h1>Paiement réussi ✓</h1>
  <div class="amount">${formatAmount(checkout.amount)} ${escapeHtml(checkout.currency)}</div>
  ${describeCheckout(checkout)}
  <p>Votre réservation est payée. Votre QR code est disponible dans l'application.</p>`
});

// GET /api/payments/mock-checkout/:paymentRef
const showMockCheckout = async (req, res) => {
    try {
        const checkout = await paymentService.getMockCheckout(
            req.params.paymentRef
        );

        if (checkout.status === "paid") {
            return sendMockPage(res, 200, paidPage(checkout));
        }

        if (checkout.status !== "pending") {
            throw new Error("This payment is not pending.");
        }

        if (checkout.expired) {
            throw new Error("This payment link has expired.");
        }

        const action = `${req.baseUrl}/mock-checkout/${encodeURIComponent(checkout.paymentRef)}/pay`;

        return sendMockPage(res, 200, {
            title: "Payer",
            body: `<h1>CampusSave</h1>
  <div class="amount">${formatAmount(checkout.amount)} ${escapeHtml(checkout.currency)}</div>
  ${describeCheckout(checkout)}
  <form method="post" action="${escapeHtml(action)}" onsubmit="this.querySelector('button').disabled = true">
    <button type="submit">Payer</button>
  </form>`
        });
    } catch (error) {
        console.error("Mock checkout error:", error.message);

        return sendMockError(res, error);
    }
};

// POST /api/payments/mock-checkout/:paymentRef/pay
const submitMockCheckout = async (req, res) => {
    try {
        const checkout = await paymentService.payMockCheckout(
            req.params.paymentRef
        );

        if (checkout.status !== "paid") {
            throw new Error("Payment has not been confirmed.");
        }

        return sendMockPage(res, 200, paidPage(checkout));
    } catch (error) {
        console.error("Mock checkout payment error:", error.message);

        return sendMockError(res, error);
    }
};

// GET /api/payments/:id
const getPayment = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can access their payments."
            });
        }

        const studentId = getUserId(req);
        const paymentId = req.params.id;

        const payment = await paymentService.getPaymentById(
            studentId,
            paymentId
        );

        return res.status(200).json({
            success: true,
            message: "Payment retrieved successfully.",
            data: payment
        });
    } catch (error) {
        console.error("Get payment error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to retrieve payment."
        });
    }
};

// GET /api/payments/my-payments
const getMyPayments = async (req, res) => {
    try {
        if (!isStudent(req)) {
            return res.status(403).json({
                success: false,
                message: "Only students can access their payments."
            });
        }

        const studentId = getUserId(req);

        const payments = await paymentService.getMyPayments(studentId);

        return res.status(200).json({
            success: true,
            message: "Payments retrieved successfully.",
            data: payments
        });
    } catch (error) {
        console.error("Get my payments error:", error.message);

        return res.status(getErrorStatus(error)).json({
            success: false,
            message: error.message || "Unable to retrieve payments."
        });
    }
};

module.exports = {
    initiatePayment,
    verifyPayment,
    konnectWebhook,
    cancelPayment,
    confirmMockPayment,
    showMockCheckout,
    submitMockCheckout,
    getPayment,
    getMyPayments
};
