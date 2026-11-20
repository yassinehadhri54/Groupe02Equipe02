
const axios = require("axios");
const { db } = require("../config/firebase");
const { FieldValue, Timestamp } = require("firebase-admin/firestore");
const konnectConfig = require("../config/konnect");

const paymentsCollection = db.collection("payments");
const reservationsCollection = db.collection("reservations");

// Konnect payment link lifetime, in minutes (init-payment "lifespan").
const PAYMENT_LIFESPAN_MINUTES = 10;

// Safety margin after the link expiration before an unpaid Konnect
// payment is treated as expired.
const EXPIRATION_GRACE_MS = 5 * 60 * 1000;

// Values documented by Konnect: "wallet", "bank_card", "e-DINAR".
const ACCEPTED_PAYMENT_METHODS = ["bank_card", "wallet", "e-DINAR"];

// --------------------------------------------------
// KONNECT CLIENT
// --------------------------------------------------

const getKonnectClient = () => {
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
// HELPERS
// --------------------------------------------------

// Expiration time in milliseconds: Konnect's expirationDate when available,
// otherwise the expiresAt stored when the payment was initiated.
const getExpirationMillis = (payment, providerPayment) => {
    const providerDate = Date.parse(providerPayment?.expirationDate);

    if (Number.isFinite(providerDate)) {
        return providerDate;
    }

    if (payment.expiresAt && typeof payment.expiresAt.toMillis === "function") {
        return payment.expiresAt.toMillis();
    }

    return null;
};

const isPaymentExpired = (payment, providerPayment) => {
    const expirationMillis = getExpirationMillis(payment, providerPayment);

    return (
        expirationMillis !== null &&
        Date.now() > expirationMillis + EXPIRATION_GRACE_MS
    );
};

// Close a pending payment (expired or cancelled) and release the
// reservation so the student can pay again or cancel it.
const closePendingPayment = async (
    paymentDocument,
    reservationId,
    paymentStatus,
    reservationPaymentStatus,
    extraPaymentFields = {}
) => {
    const reservationDocument = reservationsCollection.doc(reservationId);

    await db.runTransaction(async (transaction) => {
        const freshPaymentSnapshot = await transaction.get(paymentDocument);
        const reservationSnapshot = await transaction.get(reservationDocument);

        if (!freshPaymentSnapshot.exists) {
            throw new Error("Payment not found.");
        }

        if (freshPaymentSnapshot.data().status !== "pending") {
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

    if (payment.mode !== "sandbox" || !payment.paymentRef) {
        throw new Error("Invalid Sandbox payment reference.");
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

    // Retrieve payment details directly from Konnect
    const client = getKonnectClient();

    const response = await client.get(
        `/payments/${encodeURIComponent(payment.paymentRef)}`
    );

    const providerPayment =
        response.data?.payment || response.data;

    if (!providerPayment) {
        throw new Error("Unable to retrieve payment details from Konnect.");
    }

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

    await db.runTransaction(async (transaction) => {
        const freshPaymentSnapshot = await transaction.get(paymentDocument);
        const reservationSnapshot = await transaction.get(reservationDocument);

        if (!freshPaymentSnapshot.exists || !reservationSnapshot.exists) {
            throw new Error("Payment or reservation not found.");
        }

        const freshPayment = freshPaymentSnapshot.data();
        const reservation = reservationSnapshot.data();

        // Idempotency: repeated verification does not duplicate changes
        if (freshPayment.status === "paid") {
            return;
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
            updatedAt: FieldValue.serverTimestamp()
        });

        transaction.update(reservationDocument, {
            paymentStatus: "paid",
            updatedAt: FieldValue.serverTimestamp()
        });
    });

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

    // Sandbox: refresh this student's pending payments for the reservation
    // first, so an expired link is closed instead of blocking a new attempt
    // and a completed one is recorded as paid.
    if (konnectConfig.mode === "sandbox") {
        const previousPayments = await paymentsCollection
            .where("reservationId", "==", reservationId)
            .where("studentId", "==", studentId)
            .get();

        for (const doc of previousPayments.docs) {
            const data = doc.data();

            if (data.mode === "sandbox" && data.status === "pending" && data.paymentRef) {
                try {
                    await syncKonnectPayment(doc.id);
                } catch (error) {
                    console.error(
                        "Konnect sync before new payment failed:",
                        error.response?.data || error.message
                    );
                }
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
            status: konnectConfig.mode === "mock" ? "pending" : "initiating",
            paymentRef: null,
            payUrl: null,
            expiresAt: null,
            createdAt: FieldValue.serverTimestamp(),
            updatedAt: FieldValue.serverTimestamp()
        };

        transaction.set(paymentRef, paymentData);

        transaction.update(reservationRef, {
            paymentStatus:
                konnectConfig.mode === "mock" ? "pending" : "processing",
            updatedAt: FieldValue.serverTimestamp()
        });

        return {
            paymentId: paymentRef.id,
            payment: paymentData,
            reused: false
        };
    });

    // Step 2: Mock mode does not contact Konnect
    if (konnectConfig.mode === "mock" || result.reused) {
        return {
            ...result.payment,
            paymentId: result.paymentId,
            reused: result.reused
        };
    }

    // Step 3: Initiate payment with Konnect Sandbox
    const paymentDocument = paymentsCollection.doc(result.paymentId);

    try {
        const client = getKonnectClient();

        const requestBody = {
            receiverWalletId: konnectConfig.walletId,
            amount: result.payment.amountMillimes,
            token: "TND",
            type: "immediate",
            description: `CampusSave reservation ${reservationId}`,
            acceptedPaymentMethods: ACCEPTED_PAYMENT_METHODS,
            lifespan: PAYMENT_LIFESPAN_MINUTES,
            checkoutForm: true,
            addPaymentFeesToAmount: false,
            orderId: result.paymentId
        };

        if (konnectConfig.webhookURL) {
            requestBody.webhook = konnectConfig.webhookURL;
        }

        const response = await client.post(
            "/payments/init-payment",
            requestBody
        );

        const providerData = response.data || {};

        const payUrl = providerData.payUrl;
        const providerPaymentRef =
            providerData.paymentRef ||
            providerData.paymentId ||
            providerData.id;

        if (!payUrl || !providerPaymentRef) {
            throw new Error("Konnect returned an invalid payment response.");
        }

        const expiresAt = Timestamp.fromMillis(
            Date.now() + PAYMENT_LIFESPAN_MINUTES * 60 * 1000
        );

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
            reused: false
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
    if (konnectConfig.mode !== "sandbox") {
        throw new Error(
            "Payment verification is only available in Sandbox mode."
        );
    }

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
// from the Konnect API before anything is updated.
// --------------------------------------------------

const handleKonnectWebhook = async (paymentRef) => {
    if (konnectConfig.mode !== "sandbox") {
        throw new Error("Konnect webhook is disabled outside Sandbox mode.");
    }

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

    await db.runTransaction(async (transaction) => {
        const freshPaymentSnapshot = await transaction.get(paymentDocument);
        const reservationSnapshot = await transaction.get(reservationDocument);

        if (!freshPaymentSnapshot.exists || !reservationSnapshot.exists) {
            throw new Error("Payment or reservation not found.");
        }

        const freshPayment = freshPaymentSnapshot.data();
        const reservation = reservationSnapshot.data();

        // Do not process an already-paid payment again
        if (freshPayment.status === "paid") {
            return;
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
            updatedAt: FieldValue.serverTimestamp()
        });

        transaction.update(reservationDocument, {
            paymentStatus: "paid",
            updatedAt: FieldValue.serverTimestamp()
        });
    });

    return {
        paymentId,
        status: "paid",
        message: "Mock payment confirmed successfully."
    };
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
    getPaymentById,
    getMyPayments
};
