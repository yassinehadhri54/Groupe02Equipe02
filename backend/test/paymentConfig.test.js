const assert = require("node:assert/strict");
const http = require("node:http");
const Module = require("node:module");
const path = require("node:path");
const test = require("node:test");
const express = require("express");

const backendRoot = path.resolve(__dirname, "..");
const routesPath = path.join(backendRoot, "routes", "paymentRoutes.js");
const controllerPath = path.join(
    backendRoot,
    "controllers",
    "paymentController.js"
);
const configPath = path.join(backendRoot, "config", "konnect.js");
const authMiddlewarePath = path.join(
    backendRoot,
    "middlewares",
    "authMiddleware.js"
);

const request = (port, headers = {}) => new Promise((resolve, reject) => {
    http.get(
        {
            hostname: "127.0.0.1",
            port,
            path: "/api/payments/config",
            headers
        },
        (response) => {
            let body = "";
            response.setEncoding("utf8");
            response.on("data", (chunk) => {
                body += chunk;
            });
            response.on("end", () => {
                resolve({
                    status: response.statusCode,
                    body: JSON.parse(body)
                });
            });
        }
    ).on("error", reject);
});

const withPaymentRouter = async (mode, run) => {
    const previousEnvironment = {
        mode: process.env.PAYMENT_MODE,
        apiKey: process.env.KONNECT_API_KEY,
        walletId: process.env.KONNECT_WALLET_ID
    };

    process.env.PAYMENT_MODE = mode;
    if (mode === "sandbox") {
        process.env.KONNECT_API_KEY = "test-api-key";
        process.env.KONNECT_WALLET_ID = "test-wallet-id";
    }

    for (const modulePath of [
        routesPath,
        controllerPath,
        configPath,
        authMiddlewarePath
    ]) {
        delete require.cache[require.resolve(modulePath)];
    }

    const originalLoad = Module._load;
    Module._load = function (requestName, parent, isMain) {
        if (
            parent?.filename === authMiddlewarePath &&
            requestName === "../config/firebase"
        ) {
            return {
                auth: {
                    async verifyIdToken(token) {
                        if (!["student-test-token", "merchant-test-token"].includes(token)) {
                            throw new Error("Invalid test token.");
                        }
                        return {
                            uid: token === "student-test-token"
                                ? "unit-test-student"
                                : "unit-test-merchant",
                            email: "test@example.invalid"
                        };
                    }
                },
                db: {
                    collection() {
                        return {
                            doc(uid) {
                                return {
                                    async get() {
                                        return {
                                            exists: true,
                                            data: () => ({
                                                fullName: "Test User",
                                                role: uid === "unit-test-student"
                                                    ? "student"
                                                    : "merchant",
                                                status: "active"
                                            })
                                        };
                                    }
                                };
                            }
                        };
                    }
                }
            };
        }

        if (
            parent?.filename === controllerPath &&
            requestName === "../services/paymentService"
        ) {
            return {};
        }

        return originalLoad.call(this, requestName, parent, isMain);
    };

    let router;
    try {
        router = require(routesPath);
    } finally {
        Module._load = originalLoad;

        if (previousEnvironment.mode === undefined) {
            delete process.env.PAYMENT_MODE;
        } else {
            process.env.PAYMENT_MODE = previousEnvironment.mode;
        }
        if (previousEnvironment.apiKey === undefined) {
            delete process.env.KONNECT_API_KEY;
        } else {
            process.env.KONNECT_API_KEY = previousEnvironment.apiKey;
        }
        if (previousEnvironment.walletId === undefined) {
            delete process.env.KONNECT_WALLET_ID;
        } else {
            process.env.KONNECT_WALLET_ID = previousEnvironment.walletId;
        }
    }

    const app = express();
    app.use("/api/payments", router);
    const server = http.createServer(app);
    await new Promise((resolve, reject) => {
        server.once("error", reject);
        server.listen(0, "127.0.0.1", resolve);
    });

    try {
        await run(server.address().port);
    } finally {
        await new Promise((resolve, reject) => {
            server.close((error) => error ? reject(error) : resolve());
        });
    }
};

test("payment config reports mock mode and exposes no secrets", async () => {
    await withPaymentRouter("mock", async (port) => {
        const response = await request(port, {
            Authorization: "Bearer student-test-token"
        });

        assert.equal(response.status, 200);
        assert.deepEqual(response.body, {
            success: true,
            data: { mode: "mock" }
        });

        const serialized = JSON.stringify(response.body);
        assert.equal(serialized.includes("KONNECT_API_KEY"), false);
        assert.equal(serialized.includes("KONNECT_WALLET_ID"), false);
        assert.equal(serialized.includes("test-api-key"), false);
        assert.equal(serialized.includes("test-wallet-id"), false);
    });
});

test("payment config reports sandbox mode", async () => {
    await withPaymentRouter("sandbox", async (port) => {
        const response = await request(port, {
            Authorization: "Bearer student-test-token"
        });

        assert.equal(response.status, 200);
        assert.deepEqual(response.body, {
            success: true,
            data: { mode: "sandbox" }
        });
    });
});

test("payment config rejects unauthenticated requests", async () => {
    await withPaymentRouter("mock", async (port) => {
        const response = await request(port);

        assert.equal(response.status, 401);
        assert.equal(response.body.success, false);
    });
});

test("payment config is restricted to students", async () => {
    await withPaymentRouter("mock", async (port) => {
        const response = await request(port, {
            Authorization: "Bearer merchant-test-token"
        });

        assert.equal(response.status, 403);
        assert.equal(response.body.success, false);
    });
});
