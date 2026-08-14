// ─────────────────────────────────────────────────────────────
// frontend_error_logging.js
// Add this script tag in stall.html, organizer.html, admin.html
// BEFORE </body>:
//   <script src="/js/frontend_error_logging.js"></script>
//
// This captures:
// 1. Uncaught JS errors (window.onerror)
// 2. Unhandled promise rejections
// 3. OCR / card scanner errors
// 4. Manual: logFrontendError("message", { context })
// ─────────────────────────────────────────────────────────────

(function () {
  "use strict";

  // ── Detect current page/user context ─────────────────────────
  function getPageContext() {
    const path = window.location.pathname;
    if (path.includes("stall"))      return { page: "stall",      user_type: "stall_owner" };
    if (path.includes("organizer"))  return { page: "organizer",  user_type: "organizer" };
    if (path.includes("admin"))      return { page: "admin",      user_type: "admin" };
    return { page: path, user_type: "unknown" };
  }

  // ── Send error to backend ─────────────────────────────────────
  function sendError(payload) {
    try {
      const ctx = getPageContext();
      const body = Object.assign({
        source:     "frontend",
        severity:   "error",
        user_agent: navigator.userAgent,
        page_url:   window.location.href,
        user_type:  ctx.user_type,
        page:       ctx.page,
      }, payload);

      // Use sendBeacon for reliability (works even during page unload)
      if (navigator.sendBeacon) {
        const blob = new Blob([JSON.stringify(body)], { type: "application/json" });
        navigator.sendBeacon("/api/v1/error_logs", blob);
      } else {
        fetch("/api/v1/error_logs", {
          method:  "POST",
          headers: { "Content-Type": "application/json" },
          body:    JSON.stringify(body),
          keepalive: true,
        }).catch(() => {}); // silent — don't cause more errors
      }
    } catch (e) {
      // Never throw from error logger
    }
  }

  // ── Global JS error handler ───────────────────────────────────
  window.onerror = function (message, source, lineno, colno, error) {
    // Ignore cross-origin errors (third-party scripts)
    if (!message || message === "Script error.") return false;

    sendError({
      message:    String(message).slice(0, 500),
      error_type: error?.name || "JavaScriptError",
      context:    JSON.stringify({
        file:   source,
        line:   lineno,
        col:    colno,
        stack:  error?.stack?.slice(0, 1000),
      }),
    });

    return false; // Don't suppress the error
  };

  // ── Unhandled promise rejections ──────────────────────────────
  window.addEventListener("unhandledrejection", function (event) {
    const reason = event.reason;
    const msg    = reason?.message || String(reason) || "Unhandled Promise Rejection";

    // Ignore network errors from intentional aborts
    if (msg.includes("AbortError") || msg.includes("NetworkError")) return;

    sendError({
      message:    msg.slice(0, 500),
      error_type: "UnhandledPromiseRejection",
      context:    JSON.stringify({
        stack: reason?.stack?.slice(0, 1000),
      }),
    });
  });

  // ── Manual error logger — call from anywhere in your JS ───────
  // Usage: logFrontendError("QR scan failed", { qr_token: token, lead_id: id })
  window.logFrontendError = function (message, context, severity) {
    sendError({
      message:    String(message).slice(0, 500),
      severity:   severity || "error",
      error_type: "ManualLog",
      context:    JSON.stringify(context || {}),
    });
  };

  // ── OCR / Card scanner error logger ──────────────────────────
  // Automatically called when card scanning fails
  window.logOcrError = function (message, imageInfo) {
    sendError({
      message:    "Card OCR failed: " + String(message).slice(0, 400),
      error_type: "OCRError",
      source:     "ocr",
      severity:   "warning",
      context:    JSON.stringify({
        image_size:   imageInfo?.size,
        image_type:   imageInfo?.type,
        ocr_message:  message,
      }),
    });
  };

  // ── Performance: detect stuck operations (>15s) ───────────────
  window.trackOperation = function (name, timeoutMs) {
    timeoutMs = timeoutMs || 15000;
    const timer = setTimeout(function () {
      sendError({
        message:    "Operation stuck: " + name + " did not complete in " + (timeoutMs/1000) + "s",
        error_type: "StuckOperation",
        severity:   "warning",
        context:    JSON.stringify({ operation: name, timeout_ms: timeoutMs }),
      });
    }, timeoutMs);

    return function clearTrack() { clearTimeout(timer); };
  };

})();