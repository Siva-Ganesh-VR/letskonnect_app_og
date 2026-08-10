// =============================================================
// lucky_draw.js — Lucky Draw feature for StallConnect portals
//
// USAGE:
// In organizer.html before </body>:
//   <script>
//     const LD_API_BASE = "/api/v1/organizer/events";
//     const LD_TOKEN_FN = () => sessionStorage.getItem("org_token") || "";
//   </script>
//   <script src="/js/lucky_draw.js"></script>
//
// In admin.html before </body>:
//   <script>
//     const LD_API_BASE = "/api/v1/super_admin/events";
//     const LD_TOKEN_FN = () => localStorage.getItem("lk_admin_token") || "";
//   </script>
//   <script src="/js/lucky_draw.js"></script>
// =============================================================

(function () {
"use strict";

const LD = { spinning: false, currentAngle: 0 };

function ldToken() {
  return (typeof LD_TOKEN_FN === "function" ? LD_TOKEN_FN() : "") || "";
}

function ldBase() {
  return (typeof LD_API_BASE !== "undefined" ? LD_API_BASE : "/api/v1/organizer/events");
}

function ldEventEnded() {
  const endDate = detailsState && detailsState.eventEndDate;
  if (!endDate) return false;
  const end = new Date(endDate);
  end.setHours(23, 59, 59, 999);
  return new Date() > end;
}

// ── Open Lucky Draw Page ──────────────────────────────────────
window.openLuckyDrawPage = function(eventId, eventName) {
  // detailsState is const in portals — update properties, don't reassign
  if (typeof detailsState !== "undefined") {
    detailsState.eventId = eventId;
    detailsState.eventName = eventName;
  }

  // Get back function name from context
  const backFn = typeof showEventDetails === "function" ? "showEventDetails" : null;

  // Create full-page overlay
  var existing = document.getElementById("ld-page-overlay");
  if (existing) existing.remove();

  var overlay = document.createElement("div");
  overlay.id = "ld-page-overlay";
  overlay.style.cssText = "position:fixed;inset:0;background:var(--bg,#0f0f1a);z-index:5000;overflow-y:auto;display:flex;flex-direction:column";

  overlay.innerHTML = ldPageHTML(eventId, eventName);
  document.body.appendChild(overlay);

  ldInjectPageStyles();
  ldDrawWheel(0, false);
  ldLoadHistory();
};

function ldPageHTML(eventId, eventName) {
  var ended = ldEventEnded();
  return '<div style="max-width:900px;margin:0 auto;padding:24px 20px 60px;width:100%">' +
    // Header
    '<div style="display:flex;align-items:center;gap:16px;margin-bottom:28px">' +
      '<button onclick="closeLuckyDrawPage()" style="background:rgba(255,255,255,.06);border:1px solid rgba(255,255,255,.1);color:#fff;border-radius:10px;padding:8px 16px;font-size:13px;font-weight:600;cursor:pointer;font-family:inherit;display:flex;align-items:center;gap:6px">← Back</button>' +
      '<div>' +
        '<div style="font-size:22px;font-weight:800;color:#fff">🎰 Lucky Draw</div>' +
        '<div style="font-size:13px;color:rgba(255,255,255,.5);margin-top:2px">' + (eventName||"Event") + '</div>' +
      '</div>' +
      '<div style="margin-left:auto;display:flex;gap:8px">' +
        (ended ? '<div style="background:rgba(239,68,68,.12);border:1px solid rgba(239,68,68,.25);color:#ef4444;border-radius:8px;padding:7px 14px;font-size:12px;font-weight:700">🔒 Event ended — view only</div>' :
          '<button onclick="ldClearAll()" style="background:none;border:1px solid rgba(255,255,255,.12);color:rgba(255,255,255,.5);border-radius:8px;padding:7px 14px;font-size:12px;cursor:pointer;font-family:inherit" onmouseover="this.style.borderColor=\'#ef4444\';this.style.color=\'#ef4444\'" onmouseout="this.style.borderColor=\'rgba(255,255,255,.12)\';this.style.color=\'rgba(255,255,255,.5)\'">🗑 Clear All</button>' +
          '<button id="ld-spin-btn" onclick="ldSpin()" style="background:linear-gradient(135deg,#f59e0b,#d97706);color:#000;border:none;border-radius:10px;padding:10px 24px;font-size:15px;font-weight:800;cursor:pointer;font-family:inherit;box-shadow:0 4px 16px rgba(245,158,11,.4)">🎲 Spin the Wheel</button>'
        ) +
      '</div>' +
    '</div>' +

    // Two column layout
    '<div style="display:grid;grid-template-columns:1fr 1fr;gap:24px;margin-bottom:28px">' +

      // Left — Wheel
      '<div style="background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.07);border-radius:18px;padding:28px;display:flex;flex-direction:column;align-items:center;gap:20px">' +
        '<div style="font-size:14px;font-weight:700;color:rgba(255,255,255,.5);text-transform:uppercase;letter-spacing:.08em">Spin Wheel</div>' +
        '<div style="position:relative;width:260px;height:260px">' +
          '<canvas id="ld-canvas" width="260" height="260" style="border-radius:50%;display:block;box-shadow:0 8px 40px rgba(0,0,0,.5)' + (ended ? ';filter:grayscale(.6);opacity:.7' : '') + '"></canvas>' +
          '<div style="position:absolute;top:2px;left:50%;transform:translateX(-50%);width:0;height:0;border-left:14px solid transparent;border-right:14px solid transparent;border-top:30px solid ' + (ended ? '#6b7280' : '#f59e0b') + ';filter:drop-shadow(0 2px 6px rgba(0,0,0,.5));z-index:999;"></div>' +
          '<div style="position:absolute;top:50%;left:50%;transform:translate(-50%,-50%);width:32px;height:32px;background:var(--bg2,#1a1a2e);border:3px solid rgba(255,255,255,.15);border-radius:50%;z-index:4;display:flex;align-items:center;justify-content:center;font-size:14px">⭐</div>' +
        '</div>' +
        '<div id="ld-spin-status" style="font-size:13px;color:rgba(255,255,255,.4);text-align:center">Tap Spin the Wheel to pick a random winner</div>' +
        '<div id="ld-progress-wrap" style="display:none;width:100%;background:rgba(0,0,0,.4);border-radius:10px;height:6px;overflow:hidden"><div id="ld-progress-bar" style="height:100%;background:linear-gradient(90deg,#f59e0b,#d97706);width:0%;transition:width .3s;border-radius:10px"></div></div>' +
      '</div>' +

      // Right — Winner card
      '<div style="background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.07);border-radius:18px;padding:28px;display:flex;flex-direction:column">' +
        '<div style="font-size:14px;font-weight:700;color:rgba(255,255,255,.5);text-transform:uppercase;letter-spacing:.08em;margin-bottom:16px">Current Winner</div>' +
        '<div id="ld-winner-card" style="flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;text-align:center">' +
          '<div style="font-size:48px;opacity:.2;margin-bottom:8px">🏆</div>' +
          '<div style="font-size:13px;color:rgba(255,255,255,.3)">No winner yet — spin the wheel!</div>' +
        '</div>' +
      '</div>' +
    '</div>' +

    // Past Winners Table
    '<div style="background:rgba(255,255,255,.03);border:1px solid rgba(255,255,255,.07);border-radius:18px;overflow:hidden">' +
      '<div style="padding:18px 20px;border-bottom:1px solid rgba(255,255,255,.07);display:flex;align-items:center;justify-content:space-between">' +
        '<div style="font-size:16px;font-weight:700;color:#fff">Past Winners <span id="ld-count-badge" style="margin-left:6px;background:rgba(245,158,11,.15);color:#f59e0b;border-radius:20px;padding:2px 10px;font-size:12px;font-weight:700"></span></div>' +
        '<button onclick="ldLoadHistory()" style="background:none;border:none;color:rgba(108,99,255,.8);font-size:12px;cursor:pointer;font-weight:600;font-family:inherit">↻ Refresh</button>' +
      '</div>' +
      '<div id="ld-history" style="padding:20px"><div style="color:rgba(255,255,255,.3);font-size:13px;text-align:center;padding:24px 0">⏳ Loading...</div></div>' +
    '</div>' +

  '</div>' +

  // Confetti canvas
  '<canvas id="ld-confetti-canvas" style="position:fixed;inset:0;pointer-events:none;z-index:5001;display:none"></canvas>';
}

// ── Close Page ────────────────────────────────────────────────
window.closeLuckyDrawPage = function() {
  var overlay = document.getElementById("ld-page-overlay");
  if (overlay) overlay.remove();
  // Go back to event details
  if (detailsState && detailsState.eventId && typeof showEventDetails === "function") {
    showEventDetails(detailsState.eventId);
  }
};

// ── Wheel Colors & Draw ───────────────────────────────────────
var WC = ["#f59e0b","#3b82f6","#22c55e","#a855f7","#ef4444","#06b6d4","#f97316","#8b5cf6","#14b8a6","#ec4899","#eab308","#6366f1"];

function ldDrawWheel(angleDeg, greyed) {
  var canvas = document.getElementById("ld-canvas");
  if (!canvas) return;
  var ctx = canvas.getContext("2d");
  var cx = 130, cy = 130, r = 126;
  var slices = 12, sa = (2 * Math.PI) / slices;
  var offset = (angleDeg * Math.PI) / 180;
  ctx.clearRect(0, 0, 260, 260);
  for (var i = 0; i < slices; i++) {
    var start = offset + i * sa, end = start + sa;
    ctx.beginPath(); ctx.moveTo(cx, cy); ctx.arc(cx, cy, r, start, end); ctx.closePath();
    ctx.fillStyle = greyed ? (i % 2 === 0 ? "#374151" : "#4b5563") : WC[i % WC.length];
    ctx.fill();
    ctx.strokeStyle = "rgba(0,0,0,.2)"; ctx.lineWidth = 1.5; ctx.stroke();
    var mid = start + sa / 2;
    ctx.beginPath(); ctx.arc(cx + r * .68 * Math.cos(mid), cy + r * .68 * Math.sin(mid), 5, 0, 2*Math.PI);
    ctx.fillStyle = "rgba(255,255,255,.3)"; ctx.fill();
  }
  ctx.beginPath(); ctx.arc(cx, cy, r, 0, 2*Math.PI);
  ctx.strokeStyle = "rgba(255,255,255,.1)"; ctx.lineWidth = 4; ctx.stroke();
}

function ldAnimate(totalRotation, duration, onDone) {
  var start = performance.now(), from = LD.currentAngle;
  function frame(now) {
    var t = Math.min((now - start) / duration, 1);
    var ease = 1 - Math.pow(1 - t, 4);
    ldDrawWheel((from + totalRotation * ease) % 360, false);
    if (t < 1) { requestAnimationFrame(frame); }
    else { LD.currentAngle = (from + totalRotation) % 360; onDone(); }
  }
  requestAnimationFrame(frame);
}

// ── Spin ─────────────────────────────────────────────────────
window.ldSpin = function() {
  if (LD.spinning || ldEventEnded()) return;
  var eventId = detailsState && detailsState.eventId;
  if (!eventId) return;

  LD.spinning = true;
  var btn = document.getElementById("ld-spin-btn");
  var status = document.getElementById("ld-spin-status");
  var pw = document.getElementById("ld-progress-wrap");
  var pb = document.getElementById("ld-progress-bar");
  if (btn) { btn.disabled = true; btn.textContent = "⏳ Spinning..."; }
  if (status) status.textContent = "Picking a lucky winner...";
  if (pw) pw.style.display = "block";
  if (pb) pb.style.width = "10%";

  var rotations = (5 + Math.floor(Math.random() * 4)) * 360 + Math.random() * 360;
  var spinDuration = 3500 + Math.random() * 1000;
  var apiResult = null, apiDone = false, animDone = false;

  // function tryReveal() {
  //   if (!apiDone || !animDone) return;
  //   if (pw) pw.style.display = "none";
  //   if (apiResult) {
  //     ldRevealWinner(apiResult);
  //     ldFireConfetti();
  //     ldLoadHistory();
  //   }
  //   LD.spinning = false;
  //   if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin Again"; }
  // }
  function tryReveal() {
    if (!apiDone || !animDone) return;
    if (pw) pw.style.display = "none";
    if (apiResult) {
      // Safety check — warn if backend returned a duplicate winner
      var existingRounds = (LD.pastWinnerIds || []);
      var winnerId = apiResult.visitor && (apiResult.visitor.id || apiResult.visitor.visitor_id_code);
      if (winnerId && existingRounds.indexOf(winnerId) !== -1) {
        var status = document.getElementById("ld-spin-status");
        if (status) status.textContent = "⚠️ This visitor already won — please spin again.";
        LD.spinning = false;
        if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin Again"; }
        return;
      }
      ldRevealWinner(apiResult);
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
    else { alert(res.error || "Failed to pick a winner."); LD.spinning = false; if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin the Wheel"; } if (pw) pw.style.display = "none"; }
    apiDone = true; tryReveal();
  })
  .catch(function() {
    alert("Network error. Please try again.");
    LD.spinning = false; if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin the Wheel"; }
    if (pw) pw.style.display = "none";
  });

  ldAnimate(rotations, spinDuration, function() { animDone = true; tryReveal(); });
};

// ── Reveal winner card ────────────────────────────────────────
function ldRevealWinner(result) {
  var card = document.getElementById("ld-winner-card");
  if (!card) return;
  var v = result.visitor;
  var initials = ((v.full_name || "?").split(" ").map(function(w){return w[0];}).join("").toUpperCase().slice(0,2));
  var colors = ["#6c63ff","#f59e0b","#22c55e","#ef4444","#3b82f6","#ec4899","#14b8a6"];
  var color = colors[((v.full_name || "").charCodeAt(0) || 0) % colors.length];
  var status = document.getElementById("ld-spin-status");
  if (status) status.textContent = "🎉 Winner selected!";

  card.innerHTML =
    '<div style="animation:ldWinnerPop .5s cubic-bezier(.34,1.56,.64,1);width:100%">' +
      '<div style="font-size:13px;font-weight:800;text-transform:uppercase;letter-spacing:.1em;color:#f59e0b;margin-bottom:14px">🏆 Round ' + result.round + ' Winner</div>' +
      '<div style="width:72px;height:72px;border-radius:50%;background:' + color + ';display:flex;align-items:center;justify-content:center;font-size:26px;font-weight:800;color:#fff;margin:0 auto 14px;box-shadow:0 4px 20px ' + color + '66">' + initials + '</div>' +
      '<div style="font-size:22px;font-weight:800;color:#fff;margin-bottom:8px">' + (v.full_name || "Unknown") + '</div>' +
      '<div style="font-size:13px;color:rgba(255,255,255,.6);line-height:1.8">' +
        (v.mobile_number ? '📱 ' + v.mobile_number + '<br>' : '') +
        (v.business_name ? '🏢 ' + v.business_name + '<br>' : '') +
        (v.location ? '📍 ' + v.location : '') +
      '</div>' +
      '<div style="display:flex;justify-content:center;gap:8px;flex-wrap:wrap;margin-top:14px">' +
        '<span style="background:rgba(108,99,255,.15);color:#a5b4fc;border-radius:20px;padding:3px 12px;font-size:11px;font-weight:700">' + (v.visitor_id_code || v.id) + '</span>' +
        '<span style="background:rgba(255,255,255,.06);color:rgba(255,255,255,.4);border-radius:20px;padding:3px 12px;font-size:11px">' + ldFormatTime(result.drawn_at) + '</span>' +
      '</div>' +
      (result.drawn_by ? '<div style="margin-top:10px;font-size:11px;color:rgba(255,255,255,.3)">Spun by: ' + result.drawn_by + '</div>' : '') +
    '</div>';
}

// ── Load history ──────────────────────────────────────────────
window.ldLoadHistory = function() {
  var eventId = detailsState && detailsState.eventId;
  if (!eventId) return;
  var el = document.getElementById("ld-history");
  var badge = document.getElementById("ld-count-badge");
  if (!el) return;

  fetch(ldBase() + "/" + eventId + "/lucky_draw_results", {
    headers: { "Authorization": "Bearer " + ldToken() }
  })
  .then(function(r) { return r.json(); })
  .then(function(res) {
    var results = (res.data || []).slice().reverse(); // latest first
    LD.pastWinnerIds = results.map(function(r) {
      return r.visitor && (r.visitor.id || r.visitor.visitor_id_code);
    });
    if (badge) badge.textContent = results.length ? results.length + (results.length > 1 ? " winners" : " winner") : "";
    if (!results.length) {
      el.innerHTML = '<div style="color:rgba(255,255,255,.3);font-size:13px;text-align:center;padding:24px 0">' + (ldEventEnded() ? "No draws were run for this event." : "No winners yet — spin the wheel to start!") + '</div>';
      return;
    }
    var colors = ["#6c63ff","#f59e0b","#22c55e","#ef4444","#3b82f6","#ec4899","#14b8a6"];
    el.innerHTML = '<div style="overflow-x:auto"><table style="width:100%;border-collapse:collapse;min-width:600px">' +
      '<thead><tr>' +
      ['#','Visitor ID','Name','Mobile','Business','Location','Spun By','Time'].map(function(h){
        return '<th style="text-align:left;padding:10px 14px;font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.06em;color:rgba(255,255,255,.35);border-bottom:1px solid rgba(255,255,255,.07)">' + h + '</th>';
      }).join('') +
      '</tr></thead><tbody>' +
      results.map(function(r, i) {
        var v = r.visitor;
        var isLatest = i === 0; // reversed so first is latest
        var initials = ((v.full_name||"?").split(" ").map(function(w){return w[0];}).join("").toUpperCase().slice(0,2));
        var color = colors[((v.full_name||"").charCodeAt(0)||0) % colors.length];
        var isAdmin = r.drawn_by_type === "SuperAdmin";
        var byBg = isAdmin ? "rgba(99,102,241,.15);color:#a5b4fc" : "rgba(34,197,94,.1);color:#86efac";
        return '<tr style="' + (isLatest ? "background:rgba(245,158,11,.05)" : "") + '">' +
          '<td style="padding:12px 14px;font-size:13px;font-weight:800;color:#f59e0b">' + r.round + (isLatest ? ' <span style="font-size:10px;background:rgba(245,158,11,.2);color:#f59e0b;border-radius:10px;padding:1px 7px">LATEST</span>' : '') + '</td>' +
          '<td style="padding:12px 14px"><span style="background:rgba(108,99,255,.12);color:#a5b4fc;border-radius:20px;padding:2px 10px;font-size:11px;font-weight:700">' + (v.visitor_id_code||"—") + '</span></td>' +
          '<td style="padding:12px 14px"><div style="display:flex;align-items:center;gap:8px"><div style="width:32px;height:32px;border-radius:50%;background:' + color + ';display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;color:#fff;flex-shrink:0">' + initials + '</div><span style="font-weight:600;color:#fff">' + (v.full_name||"—") + '</span></div></td>' +
          '<td style="padding:12px 14px;font-family:monospace;font-size:13px;color:rgba(255,255,255,.7)">' + (v.mobile_number||"—") + '</td>' +
          '<td style="padding:12px 14px;color:rgba(255,255,255,.6)">' + (v.business_name||"—") + '</td>' +
          '<td style="padding:12px 14px;color:rgba(255,255,255,.6)">' + (v.location||"—") + '</td>' +
          '<td style="padding:12px 14px"><span style="background:' + byBg + ';border-radius:20px;padding:2px 10px;font-size:11px;font-weight:700">' + (r.drawn_by||"—") + '</span></td>' +
          '<td style="padding:12px 14px;font-size:12px;color:rgba(255,255,255,.35);white-space:nowrap">' + ldFormatTime(r.drawn_at) + '</td>' +
        '</tr>';
      }).join('') +
      '</tbody></table></div>';
  })
  .catch(function() {
    el.innerHTML = '<div style="color:rgba(255,255,255,.3);font-size:13px;text-align:center;padding:20px">Failed to load history.</div>';
  });
};

// ── Clear all ─────────────────────────────────────────────────
window.ldClearAll = function() {
  if (ldEventEnded()) return;
  var eventId = detailsState && detailsState.eventId;
  if (!eventId || !confirm("Clear all lucky draw results? This cannot be undone.")) return;
  fetch(ldBase() + "/" + eventId + "/lucky_draw_results", {
    method: "DELETE",
    headers: { "Authorization": "Bearer " + ldToken() }
  })
  .then(function() {
    var card = document.getElementById("ld-winner-card");
    if (card) card.innerHTML = '<div style="font-size:48px;opacity:.2;margin-bottom:8px">🏆</div><div style="font-size:13px;color:rgba(255,255,255,.3)">No winner yet — spin the wheel!</div>';
    LD.currentAngle = 0;
    ldDrawWheel(0, false);
    ldLoadHistory();
  });
};

// ── Confetti animation ────────────────────────────────────────
function ldFireConfetti() {
  var canvas = document.getElementById("ld-confetti-canvas");
  if (!canvas) return;
  canvas.style.display = "block";
  canvas.width = window.innerWidth;
  canvas.height = window.innerHeight;
  var ctx = canvas.getContext("2d");
  var particles = [];
  var colors = ["#f59e0b","#6c63ff","#22c55e","#ef4444","#3b82f6","#ec4899","#fff"];
  for (var i = 0; i < 150; i++) {
    particles.push({
      x: Math.random() * canvas.width,
      y: Math.random() * canvas.height - canvas.height,
      r: Math.random() * 8 + 3,
      d: Math.random() * 150 + 10,
      color: colors[Math.floor(Math.random() * colors.length)],
      tilt: Math.random() * 10 - 10,
      tiltAngle: Math.random() * Math.PI * 2,
      tiltAngleInc: (Math.random() * 0.07) + 0.05
    });
  }
  var frameCount = 0;
  var maxFrames = 200;
  function draw() {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    particles.forEach(function(p) {
      p.tiltAngle += p.tiltAngleInc;
      p.y += (Math.cos(p.d) + 3 + p.r / 2) * 0.8;
      p.tilt = Math.sin(p.tiltAngle) * 15;
      ctx.beginPath();
      ctx.lineWidth = p.r / 2;
      ctx.strokeStyle = p.color;
      ctx.moveTo(p.x + p.tilt + p.r / 4, p.y);
      ctx.lineTo(p.x + p.tilt, p.y + p.tilt + p.r / 4);
      ctx.stroke();
    });
    frameCount++;
    if (frameCount < maxFrames) {
      requestAnimationFrame(draw);
    } else {
      ctx.clearRect(0, 0, canvas.width, canvas.height);
      canvas.style.display = "none";
    }
  }
  requestAnimationFrame(draw);
}

// ── Inject page CSS ───────────────────────────────────────────
function ldInjectPageStyles() {
  if (document.getElementById("ld-page-styles")) return;
  var s = document.createElement("style");
  s.id = "ld-page-styles";
  s.textContent =
    "@keyframes ldWinnerPop{0%{transform:scale(.8);opacity:0}70%{transform:scale(1.05)}100%{transform:scale(1);opacity:1}}" +
    "#ld-spin-btn{transition:transform .15s,box-shadow .15s}" +
    "#ld-spin-btn:hover:not(:disabled){transform:translateY(-2px)}" +
    "#ld-spin-btn:disabled{opacity:.65;cursor:not-allowed}" +
    "#ld-page-overlay *{box-sizing:border-box}";
  document.head.appendChild(s);
}

// ── Helpers ───────────────────────────────────────────────────
function ldFormatTime(iso) {
  if (!iso) return "—";
  try {
    return new Date(iso).toLocaleString("en-IN", {
      day: "2-digit", month: "short", year: "numeric",
      hour: "2-digit", minute: "2-digit"
    });
  } catch(e) { return iso; }
}

})();
