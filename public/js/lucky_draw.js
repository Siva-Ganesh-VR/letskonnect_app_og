// =============================================================
// lucky_draw.js — Lucky Draw + Bumper Draw for StallConnect
//
// USAGE in organizer.html / admin.html before </body>:
//   <script>
//     const LD_API_BASE = "/api/v1/organizer/events";       // or super_admin
//     const LD_TOKEN_FN = () => sessionStorage.getItem("org_token") || "";
//   </script>
//   <script src="/js/lucky_draw.js"></script>
// =============================================================

(function () {
"use strict";

const LD = { spinning: false, bumperSpinning: false, currentAngle: 0, bumperAngle: 0, pastWinnerIds: [] };

function ldToken() {
  return (typeof LD_TOKEN_FN === "function" ? LD_TOKEN_FN() : "") || "";
}
function ldBase() {
  return (typeof LD_API_BASE !== "undefined" ? LD_API_BASE : "/api/v1/organizer/events");
}
function ldEventEnded() {
  var endDate = detailsState && detailsState.eventEndDate;
  if (!endDate) return false;
  var end = new Date(endDate);
  end.setHours(23, 59, 59, 999);
  return new Date() > end;
}
function ldFormatTime(iso) {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString("en-IN", {
      day: "2-digit", month: "short", year: "numeric",
      hour: "2-digit", minute: "2-digit"
    });
  } catch(e) { return iso; }
}

// ── Open Lucky Draw Page ──────────────────────────────────────
window.openLuckyDrawPage = function(eventId, eventName) {
  if (typeof detailsState !== "undefined") {
    detailsState.eventId   = eventId;
    detailsState.eventName = eventName;
  }
  var existing = document.getElementById("ld-page-overlay");
  if (existing) existing.remove();

  var overlay = document.createElement("div");
  overlay.id = "ld-page-overlay";
  overlay.style.cssText = "position:fixed;inset:0;background:var(--bg,#0f0f1a);z-index:5000;overflow-y:auto;display:flex;flex-direction:column";
  overlay.innerHTML = ldPageHTML(eventId, eventName);
  document.body.appendChild(overlay);

  ldInjectPageStyles();
  ldDrawWheel("ld-canvas", LD.currentAngle, false);
  ldDrawWheel("ld-bumper-canvas", LD.bumperAngle, false);
  ldLoadHistory();
};

// ── Close Page ────────────────────────────────────────────────
window.closeLuckyDrawPage = function() {
  var overlay = document.getElementById("ld-page-overlay");
  if (overlay) overlay.remove();
  if (detailsState && detailsState.eventId && typeof showEventDetails === "function") {
    showEventDetails(detailsState.eventId);
  }
};

// ── Page HTML ─────────────────────────────────────────────────
function ldPageHTML(eventId, eventName) {
  var ended = ldEventEnded();
  var spinDisabled = ended ? "disabled" : "";
  var endedBadge = ended
    ? '<div style="background:rgba(239,68,68,.12);border:1px solid rgba(239,68,68,.25);color:#ef4444;border-radius:8px;padding:7px 14px;font-size:12px;font-weight:700">🔒 Event ended — view only</div>'
    : "";

  return (
    '<div style="max-width:1200px;margin:0 auto;padding:24px 20px 80px;width:100%">' +

    // ── Header ────────────────────────────────────────────────
    '<div style="display:flex;align-items:center;gap:16px;margin-bottom:28px;flex-wrap:wrap">' +
      '<button onclick="closeLuckyDrawPage()" style="background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);color:#fff;border-radius:10px;padding:8px 16px;font-size:13px;font-weight:600;cursor:pointer;font-family:inherit">← Back</button>' +
      '<div>' +
        '<div style="font-size:22px;font-weight:800;color:#fff">🎰 Lucky Draw</div>' +
        '<div style="font-size:13px;color:rgba(255,255,255,.5);margin-top:2px">' + (eventName || "Event") + '</div>' +
      '</div>' +
      '<div style="margin-left:auto;display:flex;gap:8px;flex-wrap:wrap">' +
        endedBadge +
        (!ended ? '<button onclick="ldClearAll()" style="background:none;border:1px solid rgba(255,255,255,.12);color:rgba(255,255,255,.5);border-radius:8px;padding:7px 14px;font-size:12px;cursor:pointer;font-family:inherit" onmouseover="this.style.borderColor=\'#ef4444\';this.style.color=\'#ef4444\'" onmouseout="this.style.borderColor=\'rgba(255,255,255,.12)\';this.style.color=\'rgba(255,255,255,.5)\'">🗑 Clear All</button>' : '') +
      '</div>' +
    '</div>' +

    // ══════════════════════════════════════════════════════════
    // SECTION 1 — Regular Lucky Draw (time-window)
    // ══════════════════════════════════════════════════════════
    '<div style="background:rgba(255,255,255,.02);border:1px solid rgba(245,158,11,.15);border-radius:20px;padding:24px;margin-bottom:28px">' +

      '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;flex-wrap:wrap;gap:12px">' +
        '<div>' +
          '<div style="font-size:18px;font-weight:800;color:#f59e0b">🎲 Regular Draw</div>' +
          '<div style="font-size:12px;color:rgba(255,255,255,.4);margin-top:4px">Winners picked from visitors registered since last draw</div>' +
        '</div>' +
        (!ended
          ? '<button id="ld-spin-btn" onclick="ldSpin()" style="background:linear-gradient(135deg,#f59e0b,#d97706);color:#000;border:none;border-radius:10px;padding:10px 24px;font-size:15px;font-weight:800;cursor:pointer;font-family:inherit;box-shadow:0 4px 16px rgba(245,158,11,.4)">🎲 Spin the Wheel</button>'
          : ''
        ) +
      '</div>' +

      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:24px">' +

        // Wheel
        '<div style="display:flex;flex-direction:column;align-items:center;gap:16px">' +
          '<div style="position:relative;width:240px;height:240px">' +
            '<canvas id="ld-canvas" width="240" height="240" style="border-radius:50%;display:block;box-shadow:0 8px 40px rgba(0,0,0,.5)' + (ended ? ';filter:grayscale(.6);opacity:.7' : '') + '"></canvas>' +
            '<div style="position:absolute;top:2px;left:50%;transform:translateX(-50%);width:0;height:0;border-left:12px solid transparent;border-right:12px solid transparent;border-top:26px solid ' + (ended ? '#6b7280' : '#f59e0b') + ';filter:drop-shadow(0 2px 6px rgba(0,0,0,.5));z-index:999"></div>' +
            '<div style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:28px;height:28px;background:var(--bg2,#1a1a2e);border:3px solid rgba(255,255,255,.15);border-radius:50%;z-index:4;display:flex;align-items:center;justify-content:center;font-size:12px">⭐</div>' +
          '</div>' +
          '<div id="ld-spin-status" style="font-size:13px;color:rgba(255,255,255,.4);text-align:center">Tap Spin to pick a winner from the current window</div>' +
          '<div id="ld-progress-wrap" style="display:none;width:100%;background:rgba(0,0,0,.4);border-radius:10px;height:5px;overflow:hidden"><div id="ld-progress-bar" style="height:100%;background:linear-gradient(90deg,#f59e0b,#d97706);width:0%;transition:width .3s;border-radius:10px"></div></div>' +
        '</div>' +

        // Winner card
        '<div style="display:flex;flex-direction:column">' +
          '<div style="font-size:12px;font-weight:700;color:rgba(255,255,255,.35);text-transform:uppercase;letter-spacing:.08em;margin-bottom:12px">Current Winner</div>' +
          '<div id="ld-winner-card" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;min-height:200px;background:rgba(255,255,255,.02);border:1px solid rgba(255,255,255,.06);border-radius:14px;padding:20px">' +
            '<div style="font-size:40px;opacity:.2;margin-bottom:8px">🏆</div>' +
            '<div style="font-size:13px;color:rgba(255,255,255,.3)">No winner yet — spin the wheel!</div>' +
          '</div>' +
        '</div>' +

      '</div>' +

      // Regular winners table
      '<div style="margin-top:24px;border-top:1px solid rgba(255,255,255,.07);padding-top:20px">' +
        '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px">' +
          '<div style="font-size:15px;font-weight:700;color:#fff">Regular Draw Winners <span id="ld-reg-count-badge" style="margin-left:6px;background:rgba(245,158,11,.15);color:#f59e0b;border-radius:20px;padding:2px 10px;font-size:12px;font-weight:700"></span></div>' +
          '<button onclick="ldLoadHistory()" style="background:none;border:none;color:rgba(108,99,255,.8);font-size:12px;cursor:pointer;font-weight:600;font-family:inherit">↻ Refresh</button>' +
        '</div>' +
        '<div id="ld-regular-history"><div style="color:rgba(255,255,255,.3);font-size:13px;text-align:center;padding:20px">⏳ Loading...</div></div>' +
      '</div>' +

    '</div>' + // end regular section

    // ══════════════════════════════════════════════════════════
    // SECTION 2 — Bumper Draw (all-time pool)
    // ══════════════════════════════════════════════════════════
    '<div style="background:rgba(255,255,255,.02);border:1px solid rgba(168,85,247,.2);border-radius:20px;padding:24px">' +

      '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:20px;flex-wrap:wrap;gap:12px">' +
        '<div>' +
          '<div style="font-size:18px;font-weight:800;color:#a855f7">🎯 Bumper Draw</div>' +
          '<div style="font-size:12px;color:rgba(255,255,255,.4);margin-top:4px">Grand prize — picks from ALL registered visitors (no repeats ever)</div>' +
        '</div>' +
        (!ended
          ? '<button id="ld-bumper-btn" onclick="ldBumperSpin()" style="background:linear-gradient(135deg,#a855f7,#7c3aed);color:#fff;border:none;border-radius:10px;padding:10px 24px;font-size:15px;font-weight:800;cursor:pointer;font-family:inherit;box-shadow:0 4px 16px rgba(168,85,247,.4)">🎯 Spin Bumper</button>'
          : ''
        ) +
      '</div>' +

      '<div style="display:grid;grid-template-columns:1fr 1fr;gap:24px">' +

        // Bumper wheel
        '<div style="display:flex;flex-direction:column;align-items:center;gap:16px">' +
          '<div style="position:relative;width:240px;height:240px">' +
            '<canvas id="ld-bumper-canvas" width="240" height="240" style="border-radius:50%;display:block;box-shadow:0 8px 40px rgba(0,0,0,.5)' + (ended ? ';filter:grayscale(.6);opacity:.7' : '') + '"></canvas>' +
            '<div style="position:absolute;top:2px;left:50%;transform:translateX(-50%);width:0;height:0;border-left:12px solid transparent;border-right:12px solid transparent;border-top:26px solid ' + (ended ? '#6b7280' : '#a855f7') + ';filter:drop-shadow(0 2px 6px rgba(0,0,0,.5));z-index:999"></div>' +
            '<div style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:28px;height:28px;background:var(--bg2,#1a1a2e);border:3px solid rgba(255,255,255,.15);border-radius:50%;z-index:4;display:flex;align-items:center;justify-content:center;font-size:12px">🎯</div>' +
          '</div>' +
          '<div id="ld-bumper-status" style="font-size:13px;color:rgba(255,255,255,.4);text-align:center">Grand prize draw — picks from all registered visitors</div>' +
          '<div id="ld-bumper-progress-wrap" style="display:none;width:100%;background:rgba(0,0,0,.4);border-radius:10px;height:5px;overflow:hidden"><div id="ld-bumper-progress-bar" style="height:100%;background:linear-gradient(90deg,#a855f7,#7c3aed);width:0%;transition:width .3s;border-radius:10px"></div></div>' +
        '</div>' +

        // Bumper winner card
        '<div style="display:flex;flex-direction:column">' +
          '<div style="font-size:12px;font-weight:700;color:rgba(255,255,255,.35);text-transform:uppercase;letter-spacing:.08em;margin-bottom:12px">Current Bumper Winner</div>' +
          '<div id="ld-bumper-winner-card" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center;min-height:200px;background:rgba(255,255,255,.02);border:1px solid rgba(168,85,247,.12);border-radius:14px;padding:20px">' +
            '<div style="font-size:40px;opacity:.2;margin-bottom:8px">🎯</div>' +
            '<div style="font-size:13px;color:rgba(255,255,255,.3)">No bumper winner yet — spin to pick!</div>' +
          '</div>' +
        '</div>' +

      '</div>' +

      // Bumper winners table
      '<div style="margin-top:24px;border-top:1px solid rgba(168,85,247,.1);padding-top:20px">' +
        '<div style="display:flex;align-items:center;justify-content:space-between;margin-bottom:14px">' +
          '<div style="font-size:15px;font-weight:700;color:#fff">Bumper Draw Winners <span id="ld-bumper-count-badge" style="margin-left:6px;background:rgba(168,85,247,.15);color:#c084fc;border-radius:20px;padding:2px 10px;font-size:12px;font-weight:700"></span></div>' +
          '<button onclick="ldLoadHistory()" style="background:none;border:none;color:rgba(168,85,247,.8);font-size:12px;cursor:pointer;font-weight:600;font-family:inherit">↻ Refresh</button>' +
        '</div>' +
        '<div id="ld-bumper-history"><div style="color:rgba(255,255,255,.3);font-size:13px;text-align:center;padding:20px">⏳ Loading...</div></div>' +
      '</div>' +

    '</div>' + // end bumper section

    '</div>' + // end page wrap

    // Confetti canvas
    '<canvas id="ld-confetti-canvas" style="position:fixed;inset:0;pointer-events:none;z-index:5001;display:none"></canvas>'
  );
}

// ── Wheel colors & draw ───────────────────────────────────────
var WC_REG    = ["#f59e0b","#3b82f6","#22c55e","#a855f7","#ef4444","#06b6d4","#f97316","#8b5cf6","#14b8a6","#ec4899","#eab308","#6366f1"];
var WC_BUMPER = ["#a855f7","#7c3aed","#c084fc","#8b5cf6","#6d28d9","#a78bfa","#7c3aed","#d8b4fe","#4c1d95","#6d28d9","#7c3aed","#a855f7"];

function ldDrawWheel(canvasId, angleDeg, greyed, isBumper) {
  var canvas = document.getElementById(canvasId);
  if (!canvas) return;
  var ctx = canvas.getContext("2d");
  var cx = 120, cy = 120, r = 117;
  var slices = 12, sa = (2 * Math.PI) / slices;
  var offset = (angleDeg * Math.PI) / 180;
  var colors = isBumper ? WC_BUMPER : WC_REG;
  ctx.clearRect(0, 0, 240, 240);
  for (var i = 0; i < slices; i++) {
    var start = offset + i * sa, end = start + sa;
    ctx.beginPath(); ctx.moveTo(cx, cy); ctx.arc(cx, cy, r, start, end); ctx.closePath();
    ctx.fillStyle = greyed ? (i % 2 === 0 ? "#374151" : "#4b5563") : colors[i % colors.length];
    ctx.fill();
    ctx.strokeStyle = "rgba(0,0,0,.2)"; ctx.lineWidth = 1.5; ctx.stroke();
    var mid = start + sa / 2;
    ctx.beginPath(); ctx.arc(cx + r * .68 * Math.cos(mid), cy + r * .68 * Math.sin(mid), 4, 0, 2*Math.PI);
    ctx.fillStyle = "rgba(255,255,255,.3)"; ctx.fill();
  }
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2*Math.PI);
  ctx.strokeStyle = "rgba(255,255,255,.1)"; ctx.lineWidth = 3; ctx.stroke();
}

function ldAnimate(canvasId, isBumper, totalRotation, duration, onDone) {
  var angleKey = isBumper ? "bumperAngle" : "currentAngle";
  var start = performance.now(), from = LD[angleKey];
  function frame(now) {
    var t = Math.min((now - start) / duration, 1);
    var ease = 1 - Math.pow(1 - t, 4);
    ldDrawWheel(canvasId, (from + totalRotation * ease) % 360, false, isBumper);
    if (t < 1) { requestAnimationFrame(frame); }
    else { LD[angleKey] = (from + totalRotation) % 360; onDone(); }
  }
  requestAnimationFrame(frame);
}

// ── Regular Spin ─────────────────────────────────────────────
window.ldSpin = function() {
  if (LD.spinning || ldEventEnded()) return;
  var eventId = detailsState && detailsState.eventId;
  if (!eventId) return;

  LD.spinning = true;
  var btn      = document.getElementById("ld-spin-btn");
  var status   = document.getElementById("ld-spin-status");
  var pw       = document.getElementById("ld-progress-wrap");
  var pb       = document.getElementById("ld-progress-bar");
  if (btn)    { btn.disabled = true; btn.textContent = "⏳ Spinning..."; }
  if (status)   status.textContent = "Picking a winner from this window...";
  if (pw)       pw.style.display = "block";
  if (pb)       pb.style.width = "10%";

  var rotations    = (5 + Math.floor(Math.random() * 4)) * 360 + Math.random() * 360;
  var spinDuration = 3500 + Math.random() * 1000;
  var apiResult = null, apiDone = false, animDone = false;

  function tryReveal() {
    if (!apiDone || !animDone) return;
    if (pw) pw.style.display = "none";
    if (apiResult) {
      ldRevealWinner(apiResult, false);
      ldFireConfetti();
      ldLoadHistory();
    }
    LD.spinning = false;
    if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin Again"; }
  }

  fetch(ldBase() + "/" + eventId + "/lucky_draw_results", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + ldToken() }
  })
  .then(function(r) { return r.json(); })
  .then(function(res) {
    if (res.success) { apiResult = res.data; if (pb) pb.style.width = "100%"; }
    else {
      if (status) status.textContent = res.error || "Failed to pick a winner.";
      LD.spinning = false;
      if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin the Wheel"; }
      if (pw) pw.style.display = "none";
    }
    apiDone = true; tryReveal();
  })
  .catch(function() {
    if (status) status.textContent = "Network error. Please try again.";
    LD.spinning = false;
    if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin the Wheel"; }
    if (pw) pw.style.display = "none";
  });

  ldAnimate("ld-canvas", false, rotations, spinDuration, function() { animDone = true; tryReveal(); });
};

// ── Bumper Spin ───────────────────────────────────────────────
window.ldBumperSpin = function() {
  if (LD.bumperSpinning || ldEventEnded()) return;
  var eventId = detailsState && detailsState.eventId;
  if (!eventId) return;

  LD.bumperSpinning = true;
  var btn    = document.getElementById("ld-bumper-btn");
  var status = document.getElementById("ld-bumper-status");
  var pw     = document.getElementById("ld-bumper-progress-wrap");
  var pb     = document.getElementById("ld-bumper-progress-bar");
  if (btn)  { btn.disabled = true; btn.textContent = "⏳ Spinning..."; }
  if (status) status.textContent = "Picking from all registered visitors...";
  if (pw)     pw.style.display = "block";
  if (pb)     pb.style.width = "10%";

  var rotations    = (5 + Math.floor(Math.random() * 4)) * 360 + Math.random() * 360;
  var spinDuration = 3500 + Math.random() * 1000;
  var apiResult = null, apiDone = false, animDone = false;

  function tryReveal() {
    if (!apiDone || !animDone) return;
    if (pw) pw.style.display = "none";
    if (apiResult) {
      ldRevealWinner(apiResult, true);
      ldFireConfetti();
      ldLoadHistory();
    }
    LD.bumperSpinning = false;
    if (btn) { btn.disabled = false; btn.innerHTML = "🎯 Spin Again"; }
  }

  fetch(ldBase() + "/" + eventId + "/lucky_draw_results/bumper", {
    method: "POST",
    headers: { "Content-Type": "application/json", "Authorization": "Bearer " + ldToken() }
  })
  .then(function(r) { return r.json(); })
  .then(function(res) {
    if (res.success) { apiResult = res.data; if (pb) pb.style.width = "100%"; }
    else {
      if (status) status.textContent = res.error || "Failed to pick a bumper winner.";
      LD.bumperSpinning = false;
      if (btn) { btn.disabled = false; btn.innerHTML = "🎯 Spin Bumper"; }
      if (pw) pw.style.display = "none";
    }
    apiDone = true; tryReveal();
  })
  .catch(function() {
    if (status) status.textContent = "Network error. Please try again.";
    LD.bumperSpinning = false;
    if (btn) { btn.disabled = false; btn.innerHTML = "🎯 Spin Bumper"; }
    if (pw) pw.style.display = "none";
  });

  ldAnimate("ld-bumper-canvas", true, rotations, spinDuration, function() { animDone = true; tryReveal(); });
};

// ── Reveal winner card ────────────────────────────────────────
function ldRevealWinner(result, isBumper) {
  var cardId = isBumper ? "ld-bumper-winner-card" : "ld-winner-card";
  var card   = document.getElementById(cardId);
  if (!card) return;
  var v        = result.visitor;
  var initials = ((v.full_name || "?").split(" ").map(function(w){return w[0];}).join("").toUpperCase().slice(0,2));
  var colors   = ["#6c63ff","#f59e0b","#22c55e","#ef4444","#3b82f6","#ec4899","#14b8a6"];
  var color    = colors[((v.full_name || "").charCodeAt(0) || 0) % colors.length];
  var accentColor = isBumper ? "#a855f7" : "#f59e0b";
  var label    = isBumper ? "🎯 Bumper Round " : "🏆 Round ";
  var statusEl = document.getElementById(isBumper ? "ld-bumper-status" : "ld-spin-status");
  if (statusEl) statusEl.textContent = isBumper ? "🎉 Bumper winner selected!" : "🎉 Winner selected!";

  // Show window info for regular draws
  var windowInfo = "";
  if (!isBumper && result.window_start && result.window_end) {
    windowInfo = '<div style="margin-top:10px;font-size:11px;color:rgba(255,255,255,.3);background:rgba(255,255,255,.04);border-radius:8px;padding:6px 10px">' +
      '📅 Window: ' + ldFormatTime(result.window_start) + ' → ' + ldFormatTime(result.window_end) +
      '</div>';
  }

  card.innerHTML =
    '<div style="animation:ldWinnerPop .5s cubic-bezier(.34,1.56,.64,1);width:100%">' +
      '<div style="font-size:13px;font-weight:800;text-transform:uppercase;letter-spacing:.1em;color:' + accentColor + ';margin-bottom:14px">' + label + result.round + '</div>' +
      '<div style="width:64px;height:64px;border-radius:50%;background:' + color + ';display:flex;align-items:center;justify-content:center;font-size:22px;font-weight:800;color:#fff;margin:0 auto 12px;box-shadow:0 4px 20px ' + color + '66">' + initials + '</div>' +
      '<div style="font-size:20px;font-weight:800;color:#fff;margin-bottom:8px">' + (v.full_name || "Unknown") + '</div>' +
      '<div style="font-size:13px;color:rgba(255,255,255,.6);line-height:1.8">' +
        (v.mobile_number ? '📱 ' + v.mobile_number + '<br>' : '') +
        (v.business_name ? '🏢 ' + v.business_name + '<br>' : '') +
        (v.location ? '📍 ' + v.location : '') +
      '</div>' +
      '<div style="display:flex;justify-content:center;gap:8px;flex-wrap:wrap;margin-top:12px">' +
        '<span style="background:rgba(108,99,255,.15);color:#a5b4fc;border-radius:20px;padding:3px 12px;font-size:11px;font-weight:700">' + (v.visitor_id_code || v.id) + '</span>' +
        '<span style="background:rgba(255,255,255,.06);color:rgba(255,255,255,.4);border-radius:20px;padding:3px 12px;font-size:11px">' + ldFormatTime(result.drawn_at) + '</span>' +
      '</div>' +
      windowInfo +
      (result.drawn_by ? '<div style="margin-top:8px;font-size:11px;color:rgba(255,255,255,.3)">Spun by: ' + result.drawn_by + '</div>' : '') +
    '</div>';
}

// ── Load history (both regular and bumper) ────────────────────
window.ldLoadHistory = function() {
  var eventId = detailsState && detailsState.eventId;
  if (!eventId) return;

  fetch(ldBase() + "/" + eventId + "/lucky_draw_results", {
    headers: { "Authorization": "Bearer " + ldToken() }
  })
  .then(function(r) { return r.json(); })
  .then(function(res) {
    var all     = res.data || [];
    var regular = all.filter(function(r) { return r.draw_type !== "bumper"; }).reverse();
    var bumper  = all.filter(function(r) { return r.draw_type === "bumper"; }).reverse();

    // Track all winner IDs (for frontend dedup)
    LD.pastWinnerIds = all.map(function(r) { return r.visitor && r.visitor.id; });

    // Update badges
    var regBadge = document.getElementById("ld-reg-count-badge");
    if (regBadge) regBadge.textContent = regular.length ? regular.length + (regular.length > 1 ? " winners" : " winner") : "";
    var bumperBadge = document.getElementById("ld-bumper-count-badge");
    if (bumperBadge) bumperBadge.textContent = bumper.length ? bumper.length + (bumper.length > 1 ? " winners" : " winner") : "";

    // Render regular table
    var regEl = document.getElementById("ld-regular-history");
    if (regEl) regEl.innerHTML = ldBuildTable(regular, false);

    // Render bumper table
    var bumperEl = document.getElementById("ld-bumper-history");
    if (bumperEl) bumperEl.innerHTML = ldBuildTable(bumper, true);
  })
  .catch(function() {
    ["ld-regular-history","ld-bumper-history"].forEach(function(id) {
      var el = document.getElementById(id);
      if (el) el.innerHTML = '<div style="color:rgba(255,255,255,.3);font-size:13px;text-align:center;padding:20px">Failed to load.</div>';
    });
  });
};

function ldBuildTable(results, isBumper) {
  var emptyMsg = isBumper
    ? (ldEventEnded() ? "No bumper draws were run." : "No bumper winners yet — spin the bumper wheel!")
    : (ldEventEnded() ? "No regular draws were run." : "No winners yet — spin the wheel!");

  if (!results.length) {
    return '<div style="color:rgba(255,255,255,.3);font-size:13px;text-align:center;padding:24px">' + emptyMsg + '</div>';
  }

  var colors     = ["#6c63ff","#f59e0b","#22c55e","#ef4444","#3b82f6","#ec4899","#14b8a6"];
  var accentColor = isBumper ? "#c084fc" : "#f59e0b";
  var headers     = isBumper
    ? ["#", "Visitor ID", "Name", "Mobile", "Business", "Location", "Spun By", "Time"]
    : ["#", "Visitor ID", "Name", "Mobile", "Business", "Location", "Window", "Spun By", "Time"];

  return '<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;min-width:600px">' +
    '<thead><tr>' +
    headers.map(function(h) {
      return '<th style="text-align:left;padding:10px 14px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:rgba(255,255,255,.35);border-bottom:1px solid rgba(255,255,255,.07)">' + h + '</th>';
    }).join('') +
    '</tr></thead><tbody>' +
    results.map(function(r, i) {
      var v        = r.visitor;
      var isLatest = i === 0;
      var initials = ((v.full_name || "?").split(" ").map(function(w){return w[0];}).join("").toUpperCase().slice(0,2));
      var color    = colors[((v.full_name || "").charCodeAt(0) || 0) % colors.length];
      var isAdmin  = r.drawn_by_type === "SuperAdmin";
      var byBg     = isAdmin ? "rgba(99,102,241,.15);color:#a5b4fc" : "rgba(34,197,94,.1);color:#86efac";

      var windowCell = isBumper ? "" :
        '<td style="padding:10px 14px;font-size:11px;color:rgba(255,255,255,.4);white-space:nowrap">' +
          (r.window_start ? ldFormatTime(r.window_start) + '<br>→ ' + ldFormatTime(r.window_end) : "—") +
        '</td>';

      return '<tr style="' + (isLatest ? "background:rgba(245,158,11,.04)" : "") + '">' +
        '<td style="padding:10px 14px;font-size:13px;font-weight:800;color:' + accentColor + '">' + r.round + (isLatest ? ' <span style="font-size:10px;background:rgba(245,158,11,.2);color:#f59e0b;border-radius:10px;padding:1px 7px">LATEST</span>' : '') + '</td>' +
        '<td style="padding:10px 14px"><span style="background:rgba(108,99,255,.12);color:#a5b4fc;border-radius:20px;padding:2px 10px;font-size:11px;font-weight:700">' + (v.visitor_id_code || "—") + '</span></td>' +
        '<td style="padding:10px 14px"><div style="display:flex;align-items:center;gap:8px"><div style="width:30px;height:30px;border-radius:50%;background:' + color + ';display:flex;align-items:center;justify-content:center;font-size:11px;font-weight:700;color:#fff;flex-shrink:0">' + initials + '</div><span style="font-weight:600;color:#fff">' + (v.full_name || "—") + '</span></div></td>' +
        '<td style="padding:10px 14px;font-family:monospace;font-size:13px;color:rgba(255,255,255,.7)">' + (v.mobile_number || "—") + '</td>' +
        '<td style="padding:10px 14px;color:rgba(255,255,255,.6)">' + (v.business_name || "—") + '</td>' +
        '<td style="padding:10px 14px;color:rgba(255,255,255,.6)">' + (v.location || "—") + '</td>' +
        windowCell +
        '<td style="padding:10px 14px"><span style="background:' + byBg + ';border-radius:20px;padding:2px 10px;font-size:11px;font-weight:700">' + (r.drawn_by || "—") + '</span></td>' +
        '<td style="padding:10px 14px;font-size:12px;color:rgba(255,255,255,.35);white-space:nowrap">' + ldFormatTime(r.drawn_at) + '</td>' +
      '</tr>';
    }).join('') +
    '</tbody></table></div>';
}

// ── Clear all ─────────────────────────────────────────────────
window.ldClearAll = function() {
  if (ldEventEnded()) return;
  var eventId = detailsState && detailsState.eventId;
  if (!eventId || !confirm("Clear ALL lucky draw and bumper results? This cannot be undone.")) return;
  fetch(ldBase() + "/" + eventId + "/lucky_draw_results", {
    method: "DELETE",
    headers: { "Authorization": "Bearer " + ldToken() }
  })
  .then(function() {
    ["ld-winner-card","ld-bumper-winner-card"].forEach(function(id, i) {
      var el = document.getElementById(id);
      if (el) el.innerHTML = '<div style="font-size:40px;opacity:.2;margin-bottom:8px">' + (i === 0 ? "🏆" : "🎯") + '</div><div style="font-size:13px;color:rgba(255,255,255,.3)">' + (i === 0 ? "No winner yet — spin the wheel!" : "No bumper winner yet — spin to pick!") + '</div>';
    });
    LD.currentAngle = 0; LD.bumperAngle = 0;
    ldDrawWheel("ld-canvas", 0, false, false);
    ldDrawWheel("ld-bumper-canvas", 0, false, true);
    ldLoadHistory();
  });
};

// ── Confetti ──────────────────────────────────────────────────
function ldFireConfetti() {
  var canvas = document.getElementById("ld-confetti-canvas");
  if (!canvas) return;
  canvas.style.display = "block";
  canvas.width = window.innerWidth; canvas.height = window.innerHeight;
  var ctx = canvas.getContext("2d");
  var particles = [];
  var cols = ["#f59e0b","#6c63ff","#22c55e","#ef4444","#3b82f6","#ec4899","#fff","#a855f7"];
  for (var i = 0; i < 150; i++) {
    particles.push({ x: Math.random()*canvas.width, y: Math.random()*canvas.height - canvas.height, r: Math.random()*8+3, d: Math.random()*150+10, color: cols[Math.floor(Math.random()*cols.length)], tilt: Math.random()*10-10, tiltAngle: Math.random()*Math.PI*2, tiltAngleInc: Math.random()*.07+.05 });
  }
  var frame = 0, max = 200;
  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    particles.forEach(function(p) {
      p.tiltAngle += p.tiltAngleInc; p.y += (Math.cos(p.d)+3+p.r/2)*.8; p.tilt = Math.sin(p.tiltAngle)*15;
      ctx.beginPath(); ctx.lineWidth = p.r/2; ctx.strokeStyle = p.color;
      ctx.moveTo(p.x+p.tilt+p.r/4, p.y); ctx.lineTo(p.x+p.tilt, p.y+p.tilt+p.r/4); ctx.stroke();
    });
    frame++;
    if (frame < max) requestAnimationFrame(draw);
    else { ctx.clearRect(0,0,canvas.width,canvas.height); canvas.style.display = "none"; }
  }
  requestAnimationFrame(draw);
}

// ── Inject CSS ────────────────────────────────────────────────
function ldInjectPageStyles() {
  if (document.getElementById("ld-page-styles")) return;
  var s = document.createElement("style");
  s.id = "ld-page-styles";
  s.textContent =
    "@keyframes ldWinnerPop{0%{transform:scale(.8);opacity:0}70%{transform:scale(1.05)}100%{transform:scale(1);opacity:1}}" +
    "#ld-spin-btn,#ld-bumper-btn{transition:transform .15s,box-shadow .15s}" +
    "#ld-spin-btn:hover:not(:disabled),#ld-bumper-btn:hover:not(:disabled){transform:translateY(-2px)}" +
    "#ld-spin-btn:disabled,#ld-bumper-btn:disabled{opacity:.65;cursor:not-allowed}" +
    "#ld-page-overlay *{box-sizing:border-box}" +
    "@media(max-width:640px){#ld-page-overlay .grid-cols-2{grid-template-columns:1fr!important}}";
  document.head.appendChild(s);
}

})();