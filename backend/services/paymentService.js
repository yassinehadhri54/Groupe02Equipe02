
const axios = require("axios");
const { db } = require("../config/firebase");
const { FieldValue } = require("firebase-admin/firestore");
const konnectConfig = require("../config/konnect");

const paymentsCollection = db.collection("payments");
const reservationsCollection = db.collection("reservations");

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
// CREATE PAYMENT
// --------------------------------------------------

const createPayment = async (studentId, reservationId) => {
    if (!studentId || !reservationId) {
        throw new Error("Student ID and reservation ID are required.");
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

        const response = await client.post("/payments/init-payment", {
            receiverWalletId: konnectConfig.walletId,
            amount: result.payment.amountMillimes,
            token: "TND",
            type: "immediate",
            description: `CampusSave reservation ${reservationId}`,
            acceptedPaymentMethods: ["card"],
            lifespan: 10,
            checkoutForm: true,
            addPaymentFees: false,
            orderId: result.paymentId
        });

        const providerData = response.data || {};

        const payUrl = providerData.payUrl;
        const providerPaymentRef =
            providerData.paymentRef ||
            providerData.paymentId ||
            providerData.id;

        if (!payUrl || !providerPaymentRef) {
            throw new Error("Konnect returned an invalid payment response.");
        }

        await paymentDocument.update({
            status: "pending",
            paymentRef: providerPaymentRef,
            payUrl,
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
// VERIFY KONNECT PAYMENT
// --------------------------------------------------

const verifyKonnectPayment = async (studentId, paymentId) => {
    if (konnectConfig.mode !== "sandbox") {
        throw new Error(
            "Payment verification is only available in Sandbox mode."
        );
    }

    const paymentDocument = paymentsCollection.doc(paymentId);
    const paymentSnapshot = await paymentDocument.get();

    if (!paymentSnapshot.exists) {
        throw new Error("Payment not found.");
    }

    const payment = paymentSnapshot.data();

    if (payment.studentId !== studentId) {
        throw new Error("You are not allowed to verify this payment.");
    }

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

    // Never mark a payment paid unless provider confirms completion
    if (providerPayment.status !== "completed") {
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

    // Step 2: Update payment and reservation atomically
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
// CONFIRM MOCK PAYMENT
// TEST MODE ONLY
// --------------------------------------------------

const confirmMockPayment = async (studentId, paymentId) => {
    if (konnectConfig.mode !== "mock") {
        throw new Error("Mock payment confirmation is disabled.");
    }

    const paymentDocument = paymentsCollection.doc(paymentId);
    const reservationDocumentRef = null;

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
    confirmMockPayment,
    getPaymentById,
    getMyPayments
};
