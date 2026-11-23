
const { db } = require("../config/firebase");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const konnectConfig = require("../config/konnect");
const konnect = require("./konnect");
const notificationService = require("./notificationService");
const receiptService = require("./receiptService");

const paymentsCollection = db.collection("payments");
const reservationsCollection = db.collection("reservations");

// Safety margin after the link expiration before an unpaid Konnect
// payment is treated as expired.
const EXPIRATION_GRACE_MS = 5 * 60 * 1000;

// Reference format of the fake Konnect (mock mode), see services/konnect.js.
const MOCK_PAYMENT_REF_PATTERN = /^mock_[a-f0-9]{32}$/;

// --------------------------------------------------
// HELPERS
// --------------------------------------------------

// Sent once, only when this call moved the payment to "paid".
// Not awaited and never throws: notifications must not affect payments.
const notifyPaymentConfirmed = (payment) => {
    void (async () => {
        const snapshot = await reservationsCollection.doc(payment.reservationId).get();
        const reservation = snapshot.exists ? snapshot.data() : {};
        const label = `${reservation.quantity || ""} × ${reservation.offerName || "offre"}`.trim();

        await notificationService.notifyUser(payment.studentId, {
            type: "payment_confirmed",
            title: "Paiement confirmé",
            body: `Paiement de ${payment.amount} TND reçu pour ${label}. En attente de confirmation du commerçant.`,
            data: { reservationId: payment.reservationId }
        });

        if (reservation.shopId) {
            await notificationService.notifyShopOwner(reservation.shopId, {
                type: "reservation_paid",
                title: "Réservation payée",
                body: `${label} a été payée (${payment.amount} TND). Vous pouvez la confirmer.`,
                data: { reservationId: payment.reservationId }
            });
        }
    })().catch((error) => console.error("Payment notification error:", error.message));
};

// Expiration time in milliseconds: Konnect's expirationDate when available,
// otherwise the expiresAt stored when the payment was initiated.
// The later of the two dates is used: Konnect's documentation shows
// expirationDate as a date without time ("2020-10-15"), which would be read
// as midnight and close a link the student is still paying with.
const getExpirationMillis = (payment, providerPayment) => {
    const candidates = [];
    const providerDate = Date.parse(providerPayment?.expirationDate);

    if (Number.isFinite(providerDate)) {
        candidates.push(providerDate);
    }

    if (payment.expiresAt && typeof payment.expiresAt.toMillis === "function") {
        candidates.push(payment.expiresAt.toMillis());
    }

    return candidates.length ? Math.max(...candidates) : null;
};

const isPaymentExpired = (payment, providerPayment) => {
    const expirationMillis = getExpirationMillis(payment, providerPayment);

    return (
        expirationMillis !== null &&
        Date.now() > expirationMillis + EXPIRATION_GRACE_MS
    );
};

// A payment stuck in "initiating" for more than 2 minutes: the server
// stopped before Konnect answered (the Konnect call times out after 15 s).
const STALE_INITIATION_MS = 2 * 60 * 1000;

const isStaleInitiation = (payment) => {
    const createdAt =
        payment.createdAt && typeof payment.createdAt.toMillis === "function"
            ? payment.createdAt.toMillis()
            : null;

    return (
        payment.status === "initiating" &&
        createdAt !== null &&
        Date.now() - createdAt > STALE_INITIATION_MS
    );
};

// Close a pending payment (expired or cancelled) and release the
// reservation so the student can pay again or cancel it.
const closePendingPayment = async (
    paymentDocument,
    reservationId,
    paymentStatus,
    reservationPaymentStatus,
    extraPaymentFields = {},
    expectedStatus = "pending"
) => {
    const reservationDocument = reservationsCollection.doc(reservationId);

    await db.runTransaction(async (transaction) => {
        const freshPaymentSnapshot = await transaction.get(paymentDocument);
        const reservationSnapshot = await transaction.get(reservationDocument);

        if (!freshPaymentSnapshot.exists) {
            throw new Error("Payment not found.");
        }

        if (freshPaymentSnapshot.data().status !== expectedStatus) {
            throw new Error("This payment is not pending.");
        }

        transaction.update(paymentDocument, {
            ...extraPaymentFields,
            status: paymentStatus,
            updatedAt: FieldValue.serverTimestamp()
        });

        if (reservationSnapshot.exists) {
            const reservation = reservationSnapshot.data();

            if (
                reservation.status === "pending" &&
                ["pending", "processing"].includes(reservation.paymentStatus)
            ) {
                transaction.update(reservationDocument, {
                    paymentStatus: reservationPaymentStatus,
                    updatedAt: FieldValue.serverTimestamp()
                });
            }
        }
    });
};

// --------------------------------------------------
// SYNC A KONNECT PAYMENT WITH THE PROVIDER
// Used by the student verify endpoint and by the Konnect webhook.
// The payment is only marked paid after Konnect itself confirms it.
// --------------------------------------------------

const syncKonnectPayment = async (paymentId) => {
    const paymentDocument = paymentsCollection.doc(paymentId);
    const paymentSnapshot = await paymentDocument.get();

    if (!paymentSnapshot.exists) {
        throw new Error("Payment not found.");
    }

    const payment = paymentSnapshot.data();

    if (!payment.paymentRef) {
        throw new Error("Invalid payment reference.");
    }

    // A payment can only be checked with the provider that created it.
    if (payment.mode !== konnectConfig.mode) {
        throw new Error(
            `This payment was created in ${payment.mode} mode and must be ` +
            `checked in that mode.`
        );
    }

    if (payment.status === "paid") {
        return {
            paymentId,
            status: "paid",
            message: "Payment has already been confirmed."
        };
    }

    if (payment.status !== "pending") {
        throw new Error("This payment is not pending.");
    }

    // Retrieve payment details directly from Konnect (or the fake Konnect
    // in mock mode). The browser or the webhook caller is never trusted.
    const providerPayment = await konnect.getPayment(payment.paymentRef);

    // Konnect uses "pending" both for "not attempted yet" and "failed".
    // Never mark a payment paid unless the provider reports "completed".
    if (providerPayment.status !== "completed") {
        if (isPaymentExpired(payment, providerPayment)) {
            await closePendingPayment(
                paymentDocument,
                payment.reservationId,
                "expired",
                "failed",
                { providerStatus: providerPayment.status || "unknown" }
            );

            return {
                paymentId,
                status: "expired",
                providerStatus: providerPayment.status || "unknown",
                message:
                    "Payment link expired without a successful payment. " +
                    "Start a new payment or cancel the reservation."
            };
        }

        return {
            paymentId,
            status: payment.status,
            providerStatus: providerPayment.status || "unknown",
            message: "Payment has not been confirmed by Konnect yet."
        };
    }

    const providerCurrency =
        providerPayment.token || providerPayment.currency;

    const reachedAmount = Number(
        providerPayment.reachedAmount ?? providerPayment.amount
    );

    if (
        providerCurrency !== "TND" ||
        !Number.isFinite(reachedAmount) ||
        reachedAmount < payment.amountMillimes
    ) {
        throw new Error(
            "Payment amount or currency does not match the reservation."
        );
    }

    // Update payment and reservation atomically
    const reservationDocument = reservationsCollection.doc(
        payment.reservationId
    );

    const justPaid = await db.runTransaction(async (transaction) => {
        const freshPaymentSnapshot = await transaction.get(paymentDocument);
        const reservationSnapshot = await transaction.get(reservationDocument);

        if (!freshPaymentSnapshot.exists || !reservationSnapshot.exists) {
            throw new Error("Payment or reservation not found.");
        }

        const freshPayment = freshPaymentSnapshot.data();
        const reservation = reservationSnapshot.data();

        // Idempotency: repeated verification does not duplicate changes
        if (freshPayment.status === "paid") {
            return false;
        }

        if (freshPayment.status !== "pending") {
            throw new Error("This payment is not pending.");
        }

        if (reservation.status !== "pending") {
            throw new Error(
                "Reservation is no longer eligible for payment."
            );
        }

        if (reservation.paymentStatus !== "pending") {
            throw new Error("Reservation payment status is invalid.");
        }

        transaction.update(paymentDocument, {
            status: "paid",
            providerStatus: providerPayment.status,
            paidAt: FieldValue.serverTimestamp(),
            // The e-mail receipt is owed from this moment (see receiptService).
            receiptEmailStatus: "pending",
            updatedAt: FieldValue.serverTimestamp()
        });

        transaction.update(reservationDocument, {
            paymentStatus: "paid",
            updatedAt: FieldValue.serverTimestamp()
        });

        return true;
    });

    if (justPaid) {
        notifyPaymentConfirmed(payment);
        receiptService.sendReceiptInBackground(paymentId);
    }

    return {
        paymentId,
        status: "paid",
        message: "Payment successfully verified with Konnect."
    };
};

// --------------------------------------------------
// CREATE PAYMENT
// --------------------------------------------------

const createPayment = async (studentId, reservationId) => {
    if (!studentId || !reservationId) {
        throw new Error("Student ID and reservation ID are required.");
    }

    // Refresh this student's pending payments for the reservation first,
    // so an expired link is closed instead of blocking a new attempt and a
    // completed one is recorded as paid.
    {
        const previousPayments = await paymentsCollection
            .where("reservationId", "==", reservationId)
            .where("studentId", "==", studentId)
            .get();

        for (const doc of previousPayments.docs) {
            const data = doc.data();

            try {
                if (
                    data.mode === konnectConfig.mode &&
                    data.status === "pending" &&
                    data.paymentRef
                ) {
                    await syncKonnectPayment(doc.id);
                } else if (isStaleInitiation(data)) {
                    // The server stopped between "initiating" and the
                    // Konnect answer: release the reservation.
                    await closePendingPayment(
                        doc.ref,
                        data.reservationId,
                        "failed",
                        "failed",
                        { errorMessage: "Payment initiation did not complete." },
                        "initiating"
                    );
                } else if (
                    data.mode !== konnectConfig.mode &&
                    data.status === "pending" &&
                    isPaymentExpired(data, null)
                ) {
                    // Created before a KONNECT_MOCK switch and now expired.
                    await closePendingPayment(doc.ref, data.reservationId, "expired", "failed");
                }
            } catch (error) {
                console.error(
                    "Payment refresh before new payment failed:",
                    error.response?.data || error.message
                );
            }
        }
    }

    const reservationRef = reservationsCollection.doc(reservationId);
    const paymentRef = paymentsCollection.doc();

    // Step 1: Validate reservation and create a payment record
    const result = await db.runTransaction(async (transaction) => {
        const reservationSnapshot = await transaction.get(reservationRef);

        if (!reservationSnapshot.exists) {
            throw new Error("Reservation not found.");
        }

        const reservation = reservationSnapshot.data();

        if (reservation.studentId !== studentId) {
            throw new Error("You are not allowed to pay for this reservation.");
        }

        if (reservation.status !== "pending") {
            throw new Error("This reservation is not eligible for payment.");
        }

        if (reservation.paymentStatus === "paid") {
            throw new Error("This reservation has already been paid.");
        }

        const amount = Number(reservation.totalPrice);

        if (!Number.isFinite(amount) || amount <= 0) {
            throw new Error("Invalid reservation amount.");
        }

        const amountMillimes = Math.round(amount * 1000);

        // Find an existing pending payment for this reservation
        const existingQuery = paymentsCollection
            .where("reservationId", "==", reservationId)
            .where("studentId", "==", studentId);

        const existingSnapshot = await transaction.get(existingQuery);

        const existingPayment = existingSnapshot.docs.find((doc) => {
            const data = doc.data();

            return (
                data.mode === konnectConfig.mode &&
                data.status === "pending" &&
                (
                    konnectConfig.mode === "mock" ||
                    Boolean(data.payUrl)
                )
            );
        });

        // Reuse an existing pending payment
        if (existingPayment) {
            return {
                paymentId: existingPayment.id,
                payment: existingPayment.data(),
                reused: true
            };
        }

        // Prevent a second active payment attempt
        if (
            reservation.paymentStatus === "processing" ||
            reservation.paymentStatus === "pending"
        ) {
            throw new Error(
                "A payment is already in progress for this reservation."
            );
        }

        const paymentData = {
            paymentId: paymentRef.id,
            reservationId,
            studentId,
            amount,
            amountMillimes,
            currency: "TND",
            provider: "konnect",
            mode: konnectConfig.mode,
            status: "initiating",
            paymentRef: null,
            payUrl: null,
            expiresAt: null,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
        };

        transaction.set(paymentRef, paymentData);

        transaction.update(reservationRef, {
            paymentStatus: "processing",
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            paymentId: paymentRef.id,
            payment: paymentData,
            reused: false
        };
    });

    // Step 2: an existing payment link is reused as is.
    // (A mock payment created before the test page existed has no link yet:
    // it gets one below.)
    if (result.reused && result.payment.payUrl) {
        return {
            ...result.payment,
            paymentId: result.paymentId,
            reused: true
        };
    }

    // Step 3: ask Konnect (or the fake Konnect in mock mode) for a payment
    // link. Amount in millimes: 6.500 TND -> 6500.
    const paymentDocument = paymentsCollection.doc(result.paymentId);

    try {
        const {
            paymentRef: providerPaymentRef,
            payUrl,
            expiresAtMillis
        } = await konnect.initPayment({
            amountMillimes: result.payment.amountMillimes,
            orderId: result.paymentId,
            description: `CampusSave reservation ${reservationId}`
        });

        const expiresAt = Timestamp.fromMillis(expiresAtMillis);

        await paymentDocument.update({
            status: "pending",
            paymentRef: providerPaymentRef,
            payUrl,
            expiresAt,
            updatedAt: FieldValue.serverTimestamp()
        });

        await reservationRef.update({
            paymentStatus: "pending",
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            ...result.payment,
            paymentId: result.paymentId,
            status: "pending",
            paymentRef: providerPaymentRef,
            payUrl,
            expiresAt: expiresAt.toDate().toISOString(),
            reused: result.reused
        };

    } catch (error) {
        console.error(
            "Konnect initiation error:",
            error.response?.data || error.message
        );

        await paymentDocument.update({
            status: "failed",
            errorMessage: "Unable to initiate payment with the provider.",
            updatedAt: FieldValue.serverTimestamp()
        });

        await reservationRef.update({
            paymentStatus: "failed",
            updatedAt: FieldValue.serverTimestamp()
        });

        throw new Error(
            error.response?.data?.message ||
            error.message ||
            "Unable to initiate Konnect payment."
        );
    }
};

// --------------------------------------------------
// VERIFY KONNECT PAYMENT (student)
// --------------------------------------------------

const verifyKonnectPayment = async (studentId, paymentId) => {
    const paymentSnapshot = await paymentsCollection.doc(paymentId).get();

    if (!paymentSnapshot.exists) {
        throw new Error("Payment not found.");
    }

    if (paymentSnapshot.data().studentId !== studentId) {
        throw new Error("You are not allowed to verify this payment.");
    }

    return syncKonnectPayment(paymentId);
};

// --------------------------------------------------
// KONNECT WEBHOOK
// Konnect calls GET <webhook>?payment_ref=... with no signature.
// The notification is only a trigger: the status is always re-fetched
// from the Konnect API (or the fake Konnect in mock mode) before anything
// is updated.
// --------------------------------------------------

const handleKonnectWebhook = async (paymentRef) => {
    if (
        typeof paymentRef !== "string" ||
        !/^[A-Za-z0-9_-]{1,64}$/.test(paymentRef)
    ) {
        throw new Error("Invalid payment reference.");
    }

    const snapshot = await paymentsCollection
        .where("paymentRef", "==", paymentRef)
        .limit(1)
        .get();

    if (snapshot.empty) {
        throw new Error("Payment not found.");
    }

    const paymentDoc = snapshot.docs[0];
    const status = paymentDoc.data().status;

    // Duplicate notifications for an already processed payment
    if (status !== "pending") {
        return {
            paymentId: paymentDoc.id,
            status,
            message: "Payment already processed."
        };
    }

    return syncKonnectPayment(paymentDoc.id);
};

// --------------------------------------------------
// CANCEL A PENDING PAYMENT (student)
// Mock: cancelled immediately.
// Sandbox: only once Konnect confirms the link expired unpaid, so a
// payment cannot be cancelled while the student may still be paying.
// --------------------------------------------------

const cancelPayment = async (studentId, paymentId) => {
    const paymentDocument = paymentsCollection.doc(paymentId);
    const paymentSnapshot = await paymentDocument.get();

    if (!paymentSnapshot.exists) {
        throw new Error("Payment not found.");
    }

    const payment = paymentSnapshot.data();

    if (payment.studentId !== studentId) {
        throw new Error("You are not allowed to cancel this payment.");
    }

    if (payment.status === "paid") {
        throw new Error("This payment has already been paid and cannot be cancelled.");
    }

    if (payment.status !== "pending") {
        throw new Error("This payment is not pending.");
    }

    // A Konnect sandbox payment while the server now runs in mock mode:
    // Konnect cannot be asked, so it can only be closed once its link expired.
    if (payment.mode !== "mock" && payment.mode !== konnectConfig.mode) {
        if (!isPaymentExpired(payment, null)) {
            throw new Error(
                `This payment was created in ${payment.mode} mode and must be ` +
                "checked in that mode. Try again after the payment link expires."
            );
        }

        await closePendingPayment(
            paymentDocument,
            payment.reservationId,
            "expired",
            "failed"
        );

        return {
            paymentId,
            status: "expired",
            message: "Payment link expired. Start a new payment or cancel the reservation."
        };
    }

    if (payment.mode === "mock") {
        await closePendingPayment(
            paymentDocument,
            payment.reservationId,
            "cancelled",
            "unpaid",
            { cancelledAt: FieldValue.serverTimestamp() }
        );

        return {
            paymentId,
            status: "cancelled",
            message: "Mock payment cancelled. The reservation can be paid again or cancelled."
        };
    }

    const result = await syncKonnectPayment(paymentId);

    if (result.status === "paid") {
        throw new Error("This payment has already been paid and cannot be cancelled.");
    }

    if (result.status === "expired") {
        return result;
    }

    throw new Error(
        "Payment is still in progress with Konnect. Try again after the payment link expires."
    );
};

// --------------------------------------------------
// CONFIRM MOCK PAYMENT
// TEST MODE ONLY
// --------------------------------------------------

const confirmMockPayment = async (studentId, paymentId) => {
    if (konnectConfig.mode !== "mock") {
        throw new Error("Mock payment confirmation is disabled.");
    }

    const paymentDocument = paymentsCollection.doc(paymentId);

    const paymentSnapshot = await paymentDocument.get();

    if (!paymentSnapshot.exists) {
        throw new Error("Payment not found.");
    }

    const payment = paymentSnapshot.data();

    if (payment.studentId !== studentId) {
        throw new Error("You are not allowed to confirm this payment.");
    }

    if (payment.mode !== "mock") {
        throw new Error("This is not a Mock payment.");
    }

    const reservationDocument = reservationsCollection.doc(
        payment.reservationId
    );

    const justPaid = await db.runTransaction(async (transaction) => {
        const freshPaymentSnapshot = await transaction.get(paymentDocument);
        const reservationSnapshot = await transaction.get(reservationDocument);

        if (!freshPaymentSnapshot.exists || !reservationSnapshot.exists) {
            throw new Error("Payment or reservation not found.");
        }

        const freshPayment = freshPaymentSnapshot.data();
        const reservation = reservationSnapshot.data();

        // Do not process an already-paid payment again
        if (freshPayment.status === "paid") {
            return false;
        }

        if (freshPayment.status !== "pending") {
            throw new Error(
                "This mock payment is not eligible for confirmation."
            );
        }

        if (
            reservation.status !== "pending" ||
            reservation.paymentStatus !== "pending"
        ) {
            throw new Error(
                "This reservation is not eligible for payment confirmation."
            );
        }

        transaction.update(paymentDocument, {
            status: "paid",
            paidAt: FieldValue.serverTimestamp(),
            receiptEmailStatus: "pending",
            updatedAt: FieldValue.serverTimestamp()
        });

        transaction.update(reservationDocument, {
            paymentStatus: "paid",
            updatedAt: FieldValue.serverTimestamp()
        });

        return true;
    });

    if (justPaid) {
        notifyPaymentConfirmed(payment);
        receiptService.sendReceiptInBackground(paymentId);
    }

    return {
        paymentId,
        status: "paid",
        message: "Mock payment confirmed successfully."
    };
};

// --------------------------------------------------
// MOCK PAYMENT PAGE (mock mode only)
// The payUrl of a mock payment opens GET /api/payments/mock-checkout/:ref.
// The random reference in the URL is the only key: the page is opened by
// the student's browser, without a Firebase token, like the Konnect page.
// --------------------------------------------------

const getMockCheckout = async (paymentRef) => {
    if (!konnect.isMock()) {
        throw new Error("Mock payments are disabled.");
    }

    if (
        typeof paymentRef !== "string" ||
        !MOCK_PAYMENT_REF_PATTERN.test(paymentRef)
    ) {
        throw new Error("Invalid payment reference.");
    }

    const snapshot = await paymentsCollection
        .where("paymentRef", "==", paymentRef)
        .limit(1)
        .get();

    if (snapshot.empty) {
        throw new Error("Payment not found.");
    }

    const paymentDoc = snapshot.docs[0];
    const payment = paymentDoc.data();

    const reservationSnapshot = await reservationsCollection
        .doc(payment.reservationId)
        .get();

    const reservation = reservationSnapshot.exists
        ? reservationSnapshot.data()
        : {};

    const expiresAtMillis =
        payment.expiresAt && typeof payment.expiresAt.toMillis === "function"
            ? payment.expiresAt.toMillis()
            : null;

    return {
        paymentId: paymentDoc.id,
        paymentRef,
        reservationId: payment.reservationId,
        amount: payment.amount,
        currency: payment.currency || "TND",
        status: payment.status,
        expired: expiresAtMillis !== null && Date.now() > expiresAtMillis,
        offerName: reservation.offerName || null,
        quantity: reservation.quantity || null,
        shopName: reservation.shopName || null
    };
};

// The student clicked "Payer" on the mock page.
const payMockCheckout = async (paymentRef) => {
    const checkout = await getMockCheckout(paymentRef);

    if (checkout.status === "paid") {
        return checkout;
    }

    if (checkout.status !== "pending") {
        throw new Error("This payment is not pending.");
    }

    if (checkout.expired) {
        throw new Error("This payment link has expired.");
    }

    // 1. The fake Konnect records the payment as completed on its side.
    await konnect.completeMockPayment(paymentRef);

    // 2. It notifies the backend through the webhook, like Konnect does.
    //    The webhook checks the status again before marking anything paid.
    try {
        await konnect.callMockWebhook(paymentRef);
    } catch (error) {
        console.error(
            "Mock webhook call failed, processing directly:",
            error.response?.data || error.message
        );

        await handleKonnectWebhook(paymentRef);
    }

    return getMockCheckout(paymentRef);
};

// --------------------------------------------------
// GET PAYMENT BY ID
// --------------------------------------------------

const getPaymentById = async (studentId, paymentId) => {
    const snapshot = await paymentsCollection.doc(paymentId).get();

    if (!snapshot.exists) {
        throw new Error("Payment not found.");
    }

    const payment = snapshot.data();

    if (payment.studentId !== studentId) {
        throw new Error("You are not allowed to access this payment.");
    }

    return {
        ...payment,
        paymentId: snapshot.id
    };
};

// --------------------------------------------------
// GET ALL STUDENT PAYMENTS
// --------------------------------------------------

const getMyPayments = async (studentId) => {
    const snapshot = await paymentsCollection
        .where("studentId", "==", studentId)
        .get();

    return snapshot.docs.map((doc) => ({
        ...doc.data(),
        paymentId: doc.id
    }));
};

// --------------------------------------------------
// EXPORT FUNCTIONS
// --------------------------------------------------

module.exports = {
    createPayment,
    verifyKonnectPayment,
    handleKonnectWebhook,
    cancelPayment,
    confirmMockPayment,
    getMockCheckout,
    payMockCheckout,
    getPaymentById,
    getMyPayments
};
