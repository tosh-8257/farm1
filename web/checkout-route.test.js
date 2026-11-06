const test = require("node:test");
const assert = require("node:assert/strict");
const { classifyFarmpayPath } = require("./checkout-route.js");

test("payment link and invoice paths are not merchant QR ids", () => {
  assert.deepEqual(classifyFarmpayPath("/pay/l/abcdefgh"), {
    kind: "link",
    ref: "abcdefgh",
  });
  assert.deepEqual(classifyFarmpayPath("/pay/i/INV-2026-AB12CD34"), {
    kind: "invoice",
    ref: "INV-2026-AB12CD34",
  });
  // The QR page used to read path[1]. "l" and "i" are shorter than 10
  // characters, which is the "Invalid QR code" error.
  assert.equal(classifyFarmpayPath("/pay/l"), null);
  assert.equal(classifyFarmpayPath("/pay/i"), null);
});

test("a real merchant id is still a QR checkout", () => {
  assert.deepEqual(classifyFarmpayPath("/pay/merchant1234"), {
    kind: "qr",
    ref: "merchant1234",
  });
  assert.equal(classifyFarmpayPath("/pay/short"), null);
  assert.equal(classifyFarmpayPath("/pay/ANYID"), null);
});
