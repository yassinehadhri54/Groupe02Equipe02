// Payment receipt e-mail: who sends it, once, and what is recorded.
//
// The receipt state lives on the payment document (no new collection):
//   receiptEmailStatus  "pending" -> "sending" -> "sent" | "failed"
//   receiptSentAt       set when the e-mail was handed to the SMTP server
//   receiptEmailError   short, safe message when it failed (never a raw error)
//   receiptEmailAttempts, receiptEmailLockedUntil (internal: retry limit, lock)
//
// "pending" is written by paymentService in the same transaction that marks
// the payment "paid". So a payment confirmed by Konnect always has a receipt
// to send, even if the server stops right after, and a payment that is not
// paid never has one.
//
// A receipt is sent from one place only: sendReceiptForPayment(). It first
// claims the payment in a transaction ("sending"), so two webhooks arriving
// together, or a webhook and /verify, can never send two e-mails.

const { db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const emailService = require("./emailService");

const paymentsCollection = db.collection("payments");
const reservationsCollection = db.collection("reservations");
const usersCollection = db.collection("users");

// A "sending" claim older than this is considered abandoned (server stopped
// while sending) and can be taken again.
const SENDING_LOCK_MS = 2 * 60 * 1000;

// Manual retries stop after this many attempts in total.
const MAX_ATTEMPTS = 5;

const toDate = (value) =>
    value && typeof value.toDate === "function" ? value.toDate() : null;

// Claim the payment for one sending attempt.
// Returns { claimed: true, payment } or { claimed: false, reason }.
const claimReceipt = async (paymentId, { manual }) => {
    const paymentRef = paymentsCollection.doc(paymentId);

    return db.runTransaction(async (transaction) => {
        const snapshot = await transaction.get(paymentRef);

        if (!snapshot.exists) {
            return { claimed: false, reason: "not_found" };
        }

        const payment = snapshot.data();

        // Only a payment the backend itself marked "paid" (after checking
        // Konnect) gets a receipt: never pending, failed, cancelled or expired.
        if (payment.status !== "paid") {
            return { claimed: false, reason: "not_paid" };
        }

        const status = payment.receiptEmailStatus;

        if (status === "sent") {
            return { claimed: false, reason: "already_sent" };
        }

        const attempts = Number(payment.receiptEmailAttempts) || 0;

        if (manual && attempts >= MAX_ATTEMPTS) {
            return { claimed: false, reason: "too_many_attempts" };
        }

        if (status === "sending" && Number(payment.receiptEmailLockedUntil) > Date.now()) {
            return { claimed: false, reason: "in_progress" };
        }

        transaction.update(paymentRef, {
            receiptEmailStatus: "sending",
            receiptEmailAttempts: attempts + 1,
            receiptEmailLockedUntil: Date.now() + SENDING_LOCK_MS,
            updatedAt: FieldValue.serverTimestamp()
        });

        return { claimed: true, payment: { ...payment, paymentId } };
    });
};

// Receipt content, read from Firestore (never from the webhook or the client).
const buildReceiptData = async (payment) => {
    const [reservationSnapshot, userSnapshot] = await Promise.all([
        reservationsCollection.doc(payment.reservationId).get(),
        usersCollection.doc(payment.studentId).get()
    ]);

    const reservation = reservationSnapshot.exists ? reservationSnapshot.data() : {};
    const user = userSnapshot.exists ? userSnapshot.data() : {};

    const quantity = Number(reservation.quantity) || 1;
    const totalAmount = Number(payment.amount);

    // Older reservations may not store the unit price: derive it.
    const unitPrice = Number.isFinite(Number(reservation.unitPrice))
        ? Number(reservation.unitPrice)
        : totalAmount / quantity;

    return {
        to: user.email,
        studentName: user.fullName || user.name || "Student",
        reservationId: payment.reservationId,
        shopName: reservation.shopName || "",
        offerName: reservation.offerName || "",
        quantity,
        unitPrice,
        totalAmount,
        currency: payment.currency || "TND",
        paidAt: toDate(payment.paidAt) || new Date()
    };
};

// Send the receipt of a paid payment, at most once.
// Never throws: a receipt problem must never affect the payment itself.
// Returns { status: "sent" | "failed" | "skipped", reason? }.
const sendReceiptForPayment = async (paymentId, { manual = false } = {}) => {
    try {
        const claim = await claimReceipt(paymentId, { manual });

        if (!claim.claimed) {
            return { status: "skipped", reason: claim.reason };
        }

        const paymentRef = paymentsCollection.doc(paymentId);
        let result;

        try {
            // Re-read the payment: paidAt is only resolved after the commit.
            const fresh = (await paymentRef.get()).data() || claim.payment;
            const receiptData = await buildReceiptData({ ...fresh, paymentId });

            result = await emailService.sendPaymentReceiptEmail(receiptData);
        } catch (error) {
            console.error("Receipt preparation error:", error.message);
            result = { success: false, error: "The receipt could not be prepared." };
        }

        await paymentRef.update(
            result.success
                ? {
                    receiptEmailStatus: "sent",
                    receiptSentAt: FieldValue.serverTimestamp(),
                    receiptEmailError: FieldValue.delete(),
                    receiptEmailLockedUntil: FieldValue.delete(),
                    updatedAt: FieldValue.serverTimestamp()
                }
                : {
                    receiptEmailStatus: "failed",
                    receiptEmailError: result.error,
                    receiptEmailLockedUntil: FieldValue.delete(),
                    updatedAt: FieldValue.serverTimestamp()
                }
        );

        return { status: result.success ? "sent" : "failed" };
    } catch (error) {
        console.error("Receipt error:", error.message);
        return { status: "failed", reason: "internal_error" };
    }
};

// Called by paymentService right after a payment became "paid".
// Not awaited by the caller and never throws, like the notifications.
const sendReceiptInBackground = (paymentId) => {
    void sendReceiptForPayment(paymentId);
};

// The student asks to send the receipt again (failed or never sent).
// A receipt already sent is never sent a second time.
const retryReceipt = async (studentId, paymentId) => {
    const snapshot = await paymentsCollection.doc(paymentId).get();

    if (!snapshot.exists) {
        throw new Error("Payment not found.");
    }

    if (snapshot.data().studentId !== studentId) {
        throw new Error("You are not allowed to access this payment.");
    }

    const result = await sendReceiptForPayment(paymentId, { manual: true });

    if (result.status === "skipped") {
        const messages = {
            not_paid: "This payment is not eligible for a receipt: it has not been paid.",
            already_sent: "The receipt has already been sent.",
            in_progress: "The receipt is already in progress.",
            too_many_attempts: "This receipt is not eligible for another attempt.",
            not_found: "Payment not found."
        };

        throw new Error(messages[result.reason] || "The receipt cannot be sent.");
    }

    return {
        paymentId,
        receiptEmailStatus: result.status,
        message:
            result.status === "sent"
                ? "Receipt sent by e-mail."
                : "The receipt could not be sent. You can try again later."
    };
};

module.exports = {
    MAX_ATTEMPTS,
    sendReceiptForPayment,
    sendReceiptInBackground,
    retryReceipt
};
