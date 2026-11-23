// Sends e-mails with Nodemailer (SMTP). Only the payment receipt for now.
//
// Everything comes from .env: SMTP_HOST, SMTP_PORT, SMTP_USER, SMTP_PASS and
// EMAIL_FROM. Nothing is read when the file is loaded, so a server without
// e-mail settings still starts: the receipt is then recorded as "failed" and
// can be retried once the settings are added.
//
// Errors returned to the callers are short, fixed messages: the raw SMTP
// error can contain the server name or the account and is never stored or
// returned (payments can be read by the student through Firestore).

const nodemailer = require("nodemailer");

const RECEIPT_SUBJECT = "CampusSave – Payment Confirmation & Electronic Receipt";

const REQUIRED_SETTINGS = ["SMTP_HOST", "SMTP_PORT", "SMTP_USER", "SMTP_PASS", "EMAIL_FROM"];

const SIMPLE_EMAIL_PATTERN = /^[^\s@<>()",;:]+@[^\s@<>()",;:]+\.[^\s@<>()",;:]+$/;

const getMissingSettings = () =>
    REQUIRED_SETTINGS.filter((name) => !String(process.env[name] || "").trim());

let transporter = null;
let transporterKey = null;

// One transporter per configuration (re-created if .env values change).
const getTransporter = () => {
    const port = Number(process.env.SMTP_PORT);
    const key = [process.env.SMTP_HOST, port, process.env.SMTP_USER].join("|");

    if (!transporter || transporterKey !== key) {
        transporter = nodemailer.createTransport({
            host: process.env.SMTP_HOST.trim(),
            port,
            // 465 = implicit TLS; 587 and others upgrade with STARTTLS.
            secure: port === 465,
            auth: {
                user: process.env.SMTP_USER,
                pass: process.env.SMTP_PASS
            },
            connectionTimeout: 10000,
            greetingTimeout: 10000,
            socketTimeout: 20000
        });
        transporterKey = key;
    }

    return transporter;
};

// Raw SMTP error -> fixed message that is safe to store and show.
const describeSendError = (error) => {
    const code = error?.code;

    if (code === "EAUTH") return "SMTP authentication failed.";
    if (code === "EENVELOPE") return "The recipient address was refused.";
    if (
        ["ECONNECTION", "ETIMEDOUT", "ESOCKET", "ECONNREFUSED", "ENOTFOUND", "EDNS"].includes(code)
    ) {
        return "The SMTP server could not be reached.";
    }

    return "The e-mail could not be sent.";
};

// --------------------------------------------------
// TEMPLATE
// --------------------------------------------------

// Offer names, shop names and student names are free text: always escaped.
const escapeHtml = (value) =>
    String(value ?? "").replace(/[&<>"']/g, (char) => ({
        "&": "&amp;",
        "<": "&lt;",
        ">": "&gt;",
        "\"": "&quot;",
        "'": "&#39;"
    })[char]);

const formatAmount = (amount, currency = "TND") =>
    `${Number(amount).toFixed(3)} ${currency}`;

const formatDate = (value) => {
    const date = value instanceof Date && !Number.isNaN(value.getTime()) ? value : new Date();

    return new Intl.DateTimeFormat("en-GB", {
        dateStyle: "long",
        timeStyle: "short",
        timeZone: "Africa/Tunis"
    }).format(date);
};

const toRows = (receipt) => [
    ["Reservation ID", receipt.reservationId],
    ["Shop / restaurant", receipt.shopName || "-"],
    ["Product / offer", receipt.offerName || "-"],
    ["Quantity", String(receipt.quantity)],
    ["Unit price", formatAmount(receipt.unitPrice, receipt.currency)],
    ["Total amount paid", formatAmount(receipt.totalAmount, receipt.currency)],
    ["Payment status", "Confirmed"],
    ["Payment date", formatDate(receipt.paidAt)]
];

const buildReceiptHtml = (receipt) => {
    const rows = toRows(receipt)
        .map(([label, value], index, all) => {
            const isTotal = label === "Total amount paid";
            const isStatus = label === "Payment status";
            const border = index < all.length - 1 ? "border-bottom:1px solid #e2e8f0;" : "";

            return `<tr>
  <td style="padding:12px 0;${border}color:#64748b;font-size:14px;">${escapeHtml(label)}</td>
  <td align="right" style="padding:12px 0;${border}font-size:${isTotal ? "17px" : "14px"};font-weight:${isTotal || isStatus ? "700" : "500"};color:${isStatus ? "#15803d" : "#0f172a"};">${escapeHtml(value)}</td>
</tr>`;
        })
        .join("\n");

    return `<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHtml(RECEIPT_SUBJECT)}</title>
</head>
<body style="margin:0;padding:0;background:#f1f5f9;font-family:Arial,Helvetica,sans-serif;color:#0f172a;">
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f1f5f9;padding:24px 12px;">
<tr><td align="center">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:14px;overflow:hidden;">
    <tr>
      <td align="center" style="background:#0f766e;padding:26px 20px;">
        <div style="font-size:26px;font-weight:700;letter-spacing:.5px;color:#ffffff;">CampusSave</div>
        <div style="font-size:13px;color:#ccfbf1;margin-top:4px;">Electronic receipt</div>
      </td>
    </tr>
    <tr>
      <td style="padding:28px 24px 8px 24px;">
        <p style="margin:0 0 12px 0;font-size:16px;">Hello ${escapeHtml(receipt.studentName)},</p>
        <p style="margin:0;font-size:15px;line-height:1.55;color:#334155;">Thank you for using CampusSave! Your payment has been successfully confirmed. Here are the details of your reservation.</p>
      </td>
    </tr>
    <tr>
      <td style="padding:12px 24px 8px 24px;">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0">
${rows}
        </table>
      </td>
    </tr>
    <tr>
      <td style="padding:16px 24px 28px 24px;">
        <p style="margin:0;font-size:14px;line-height:1.55;color:#334155;">Your QR code is available in the CampusSave app: show it to the shop when you pick up your order.</p>
      </td>
    </tr>
    <tr>
      <td align="center" style="background:#f8fafc;padding:16px 20px;font-size:12px;color:#94a3b8;line-height:1.5;">
        This is an automatic message, please do not reply.<br>
        Keep this e-mail as your proof of payment.
      </td>
    </tr>
  </table>
</td></tr>
</table>
</body>
</html>`;
};

const buildReceiptText = (receipt) =>
    [
        "CampusSave – Electronic receipt",
        "",
        `Hello ${receipt.studentName},`,
        "",
        "Thank you for using CampusSave! Your payment has been successfully confirmed. Here are the details of your reservation.",
        "",
        ...toRows(receipt).map(([label, value]) => `${label}: ${value}`),
        "",
        "Your QR code is available in the CampusSave app.",
        "This is an automatic message, please do not reply."
    ].join("\n");

// --------------------------------------------------
// SEND THE RECEIPT
// receiptData: { to, studentName, reservationId, shopName, offerName,
//                quantity, unitPrice, totalAmount, currency, paidAt }
// Never throws. Returns { success: true, messageId } or
// { success: false, error } with a short message that is safe to store.
// --------------------------------------------------

const sendPaymentReceiptEmail = async (receiptData) => {
    const receipt = receiptData || {};
    const recipient = typeof receipt.to === "string" ? receipt.to.trim() : "";

    if (!recipient || !SIMPLE_EMAIL_PATTERN.test(recipient)) {
        return { success: false, error: "The student has no valid e-mail address." };
    }

    if (!receipt.reservationId) {
        return { success: false, error: "The receipt data is incomplete." };
    }

    const missing = getMissingSettings();

    if (missing.length > 0) {
        // Names only, never values.
        console.error(`Receipt email: missing settings ${missing.join(", ")}.`);
        return { success: false, error: "The e-mail service is not configured." };
    }

    const port = Number(process.env.SMTP_PORT);

    if (!Number.isInteger(port) || port <= 0 || port > 65535) {
        return { success: false, error: "The e-mail service is not configured." };
    }

    try {
        const info = await getTransporter().sendMail({
            from: process.env.EMAIL_FROM.trim(),
            to: recipient,
            subject: RECEIPT_SUBJECT,
            text: buildReceiptText(receipt),
            html: buildReceiptHtml(receipt)
        });

        return { success: true, messageId: info?.messageId || null };
    } catch (error) {
        // Code only: the message may contain the server or account name.
        console.error("Receipt email error:", error?.code || "UNKNOWN", error?.responseCode || "");

        return { success: false, error: describeSendError(error) };
    }
};

module.exports = {
    RECEIPT_SUBJECT,
    sendPaymentReceiptEmail,
    buildReceiptHtml,
    buildReceiptText
};
