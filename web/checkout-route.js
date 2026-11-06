/**
 * Classifies a farmpay.africa path.
 *
 * Payment links are /pay/l/<code> and invoices are /pay/i/<number>.
 * Those segments are not merchant QR ids. A QR checkout is /pay/<merchantId>
 * only when the id is at least 10 characters and is not "l" or "i".
 */
(function (root, factory) {
  const api = factory();
  if (typeof module === "object" && module.exports) {
    module.exports = api;
  }
  root.FarmpayCheckout = api;
})(typeof globalThis !== "undefined" ? globalThis : this, function () {
  function decodePart(value) {
    try {
      return decodeURIComponent(value);
    } catch (_) {
      return value;
    }
  }

  function classifyFarmpayPath(pathname) {
    const parts = String(pathname || "")
      .split("/")
      .filter(Boolean)
      .map(decodePart);
    if (parts[0] !== "pay" || parts.length < 2) return null;
    const second = parts[1];
    if ((second === "l" || second === "i") && parts.length >= 3) {
      const ref = parts.slice(2).join("/");
      if (!ref) return null;
      return { kind: second === "l" ? "link" : "invoice", ref: ref };
    }
    if (parts.length === 2 && second !== "l" && second !== "i" && second !== "success") {
      if (second === "ANYID" || second.length < 10) return null;
      return { kind: "qr", ref: second };
    }
    return null;
  }

  return { classifyFarmpayPath: classifyFarmpayPath };
});
