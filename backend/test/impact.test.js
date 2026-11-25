const assert = require("node:assert/strict");
const test = require("node:test");
const { buildImpact } = require("../services/impact");

test("impact uses completion dates, counts distinct shops and skips paid-only orders", () => {
    const result = buildImpact([
        { status: "confirmed", quantity: 99, paymentStatus: "paid", shopId: "hidden" },
        { status: "cancelled", quantity: 99, shopId: "hidden" },
        { status: "completed", quantity: 2, completedAt: "2026-11-25T12:00:00Z",
            originalUnitPrice: 12, unitPrice: 5, shopId: "shop-a" },
        { status: "completed", quantity: 1, completedAt: "2026-11-22T12:00:00Z",
            originalUnitPrice: 10, unitPrice: 5, shopId: "shop-a" },
        { status: "completed", quantity: 3, shopId: "shop-b" }
    ], Date.parse("2026-11-25T18:00:00Z"));

    assert.equal(result.recoveredOrders, 3);
    assert.equal(result.portions, 6);
    assert.equal(result.savings, 19);
    assert.equal(result.participatingShops, 2);
    assert.equal(result.missingPickupDate, 1);
    assert.equal(result.missingSavings, 1);
    assert.equal(result.weekly.at(-1).start, "2026-11-23");
    assert.equal(result.weekly.at(-1).portions, 2);
    assert.equal(result.weekly.at(-2).portions, 1);
    assert.equal(result.monthly.at(-1).recoveredOrders, 2);
    assert.equal(result.monthly.at(-1).participatingShops, 1);
});

test("impact has stable empty periods without awarding any historical points", () => {
    const result = buildImpact([], Date.parse("2026-01-01"));
    assert.equal(result.recoveredOrders, 0);
    assert.equal(result.weekly.length, 8);
    assert.equal(result.monthly.length, 6);
    assert.equal(result.monthly.at(-1).start, "2026-01-01");
});
