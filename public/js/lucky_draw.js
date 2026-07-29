// =============================================================
// lucky_draw.js  —  Lucky Draw feature for StallConnect portals
//
// Add to organizer.html before </body>:
//   <script>
//     const LD_API_BASE = "/api/v1/organizer/events";
//     const LD_TOKEN_FN = () => sessionStorage.getItem("org_token") || "";
//   </script>
//   <script src="/js/lucky_draw.js"></script>
//
// Add to admin.html before </body>:
//   <script>
//     const LD_API_BASE = "/api/v1/super_admin/events";
//     const LD_TOKEN_FN = () => localStorage.getItem("lk_admin_token") || "";
//   </script>
//   <script src="/js/lucky_draw.js"></script>
//
// In both portals, inside showEventDetails, after loading event data add:
//   detailsState.eventEndDate = e.end_date || null;
// =============================================================

(function () {
  "use strict";

  // ── Internal state ──────────────────────────────────────────
  const LD = {
    spinning:     false,
    currentAngle: 0,
  };

  // ── Token helper ────────────────────────────────────────────
  function ldToken() {
    return (typeof LD_TOKEN_FN === "function" ? LD_TOKEN_FN() : "") || "";
  }

  // ── API base helper ─────────────────────────────────────────
  function ldBase() {
    return (typeof LD_API_BASE !== "undefined" ? LD_API_BASE : "/api/v1/organizer/events");
  }

  // ── Event ended check ───────────────────────────────────────
  // Returns true ONLY after the end date day is fully over.
  // If today IS the end date, lucky draw is still allowed.
  function ldEventEnded() {
    const endDate = detailsState?.eventEndDate;
    if (!endDate) return false;
    const end = new Date(endDate);
    end.setHours(23, 59, 59, 999); // allow until midnight of end date
    return new Date() > end;
  }

  // ── Inject CSS once ─────────────────────────────────────────
  function ldInjectStyles() {
    if (document.getElementById("ld-styles")) return;
    const s = document.createElement("style");
    s.id = "ld-styles";
    s.textContent = `
      @keyframes ldFadeIn {
        from { opacity:0; transform:translateY(10px) scale(.97); }
        to   { opacity:1; transform:none; }
      }
      @keyframes ldWinnerPop {
        0%   { transform:scale(.85); opacity:0; }
        70%  { transform:scale(1.04); }
        100% { transform:scale(1);   opacity:1; }
      }
      @keyframes ldSpinPulse {
        0%,100% { box-shadow:0 4px 16px rgba(245,158,11,.45); }
        50%     { box-shadow:0 4px 28px rgba(245,158,11,.8);  }
      }
      #ld-spin-btn { transition:transform .15s, box-shadow .15s; }
      #ld-spin-btn:hover:not(:disabled) { transform:translateY(-2px); }
      #ld-spin-btn:disabled { opacity:.65; cursor:not-allowed; animation:ldSpinPulse .7s infinite; }
      .ld-winner-row { transition:background .15s; }
      .ld-winner-row:hover { background:rgba(255,255,255,.04); }
      .ld-ended-badge {
        display:inline-flex; align-items:center; gap:6px;
        background:rgba(239,68,68,.12); color:#ef4444;
        border:1px solid rgba(239,68,68,.25);
        border-radius:8px; padding:6px 14px;
        font-size:12px; font-weight:700;
      }
    `;
    document.head.appendChild(s);
  }

  // ── Section HTML ────────────────────────────────────────────
  function ldRenderSection(eventEnded) {
    return `
    <div id="lucky-draw-section"
         style="background:var(--bg2);border:1px solid var(--border);border-radius:14px;
                overflow:hidden;margin-bottom:20px;box-shadow:var(--shadow)">

      <!-- Header -->
      <div style="padding:16px 20px;border-bottom:1px solid var(--border);
                  display:flex;align-items:center;justify-content:space-between;
                  flex-wrap:wrap;gap:10px">
        <div style="display:flex;align-items:center;gap:12px">
          <div style="width:38px;height:38px;border-radius:10px;
                      background:linear-gradient(135deg,#f59e0b,#d97706);
                      display:flex;align-items:center;justify-content:center;
                      font-size:20px;box-shadow:0 4px 12px rgba(245,158,11,.4)">🎰</div>
          <div>
            <div style="font-size:15px;font-weight:700;color:var(--text)">Lucky Draw</div>
            <div style="font-size:12px;color:var(--text3);margin-top:1px">
              Spin to pick a random winner — results saved permanently
            </div>
          </div>
        </div>
        <div id="ld-header-actions"
             style="display:flex;gap:8px;align-items:center;flex-wrap:wrap">
          ${ldHeaderActions(eventEnded)}
        </div>
      </div>

      <!-- Wheel + winner reveal -->
      <div style="padding:28px 20px;display:flex;flex-direction:column;
                  align-items:center;gap:24px">

        <!-- Wheel canvas -->
        <div style="position:relative;width:240px;height:240px">
          <canvas id="ld-canvas" width="240" height="240"
                  style="border-radius:50%;display:block;
                         box-shadow:0 8px 32px rgba(0,0,0,.4);
                         ${eventEnded ? 'filter:grayscale(.65);opacity:.7;' : ''}"></canvas>
          <!-- Arrow pointer -->
          <div style="position:absolute;top:-14px;left:50%;transform:translateX(-50%);
                      width:0;height:0;
                      border-left:12px solid transparent;
                      border-right:12px solid transparent;
                      border-bottom:26px solid ${eventEnded ? '#6b7280' : '#f59e0b'};
                      filter:drop-shadow(0 2px 6px rgba(0,0,0,.5));z-index:3"></div>
          <!-- Centre pin -->
          <div style="position:absolute;top:50%;left:50%;
                      transform:translate(-50%,-50%);
                      width:30px;height:30px;background:var(--bg2);
                      border:3px solid rgba(255,255,255,.2);border-radius:50%;z-index:4;
                      display:flex;align-items:center;justify-content:center;
                      font-size:14px;box-shadow:0 2px 8px rgba(0,0,0,.4)">⭐</div>
        </div>

        <!-- Winner reveal card (hidden until first spin) -->
        <div id="ld-winner-card"
             style="display:none;width:100%;max-width:440px;
                    background:linear-gradient(135deg,rgba(245,158,11,.13),rgba(217,119,6,.07));
                    border:1.5px solid rgba(245,158,11,.4);border-radius:16px;
                    padding:22px 28px;text-align:center">
          <div style="font-size:32px;margin-bottom:10px">🏆</div>
          <div style="font-size:11px;font-weight:800;text-transform:uppercase;
                      letter-spacing:.12em;color:#f59e0b;margin-bottom:8px">
            Round <span id="ld-winner-round"></span> Winner
          </div>
          <div id="ld-winner-name"
               style="font-size:24px;font-weight:800;color:var(--text);margin-bottom:6px"></div>
          <div id="ld-winner-meta"
               style="font-size:13px;color:var(--text2);line-height:1.8"></div>
          <div style="margin-top:12px;display:flex;justify-content:center;
                      gap:8px;flex-wrap:wrap">
            <span id="ld-winner-code"
                  style="background:rgba(108,99,255,.12);color:#6c63ff;
                         border-radius:20px;padding:3px 14px;
                         font-size:11px;font-weight:700"></span>
            <span id="ld-winner-time"
                  style="background:rgba(255,255,255,.06);color:var(--text3);
                         border-radius:20px;padding:3px 14px;font-size:11px"></span>
          </div>
          <div id="ld-winner-drawn-by"
               style="margin-top:10px;font-size:11px;color:var(--text3)"></div>
        </div>

      </div>

      <!-- Past winners table -->
      <div style="border-top:1px solid var(--border)">
        <div style="padding:14px 20px;display:flex;align-items:center;
                    justify-content:space-between">
          <div style="font-size:13px;font-weight:700;color:var(--text)">
            Past Winners
            <span id="ld-count-badge"
                  style="margin-left:6px;background:rgba(245,158,11,.15);color:#f59e0b;
                         border-radius:20px;padding:1px 10px;
                         font-size:11px;font-weight:700"></span>
          </div>
          <button onclick="ldLoadHistory()"
            style="background:none;border:none;color:var(--accent);font-size:12px;
                   cursor:pointer;font-family:'Inter',sans-serif;
                   font-weight:600;padding:4px 8px">
            ↻ Refresh
          </button>
        </div>
        <div id="ld-history" style="padding:0 20px 20px">
          <div style="color:var(--text3);font-size:13px;
                      text-align:center;padding:24px 0">⏳ Loading…</div>
        </div>
      </div>

    </div>`;
  }

  // ── Header action buttons (spin + clear / ended badge) ──────
  function ldHeaderActions(eventEnded) {
    if (eventEnded) {
      return `<div class="ld-ended-badge">
        🔒 Event ended — Lucky Draw is closed. Results are view-only.
      </div>`;
    }
    return `
      <button id="ld-clear-btn" onclick="ldClearAll()"
        style="background:none;border:1px solid var(--border);color:var(--text3);
               border-radius:8px;padding:7px 14px;font-size:12px;cursor:pointer;
               font-family:'Inter',sans-serif;transition:all .2s"
        onmouseover="this.style.borderColor='#ef4444';this.style.color='#ef4444'"
        onmouseout="this.style.borderColor='var(--border)';this.style.color='var(--text3)'">
        🗑 Clear All
      </button>
      <button id="ld-spin-btn" onclick="ldSpin()"
        style="background:linear-gradient(135deg,#f59e0b,#d97706);color:#fff;
               border:none;border-radius:10px;padding:10px 22px;font-size:14px;
               font-weight:700;cursor:pointer;font-family:'Inter',sans-serif;
               box-shadow:0 4px 16px rgba(245,158,11,.45)">
        🎲 Spin the Wheel
      </button>`;
  }

  // ── Update header actions dynamically ───────────────────────
  function ldSyncButtons() {
    const container = document.getElementById("ld-header-actions");
    if (!container) return;
    const ended = ldEventEnded();
    container.innerHTML = ldHeaderActions(ended);

    // Grey out the wheel canvas if ended
    const canvas = document.getElementById("ld-canvas");
    if (canvas) {
      canvas.style.filter  = ended ? "grayscale(.65)" : "";
      canvas.style.opacity = ended ? "0.7" : "1";
    }

    // Update arrow colour
    // (arrow is inline-styled so we re-draw the wheel which handles it)
    ldDraw(LD.currentAngle, ended);
  }

  // ── Wheel colours ───────────────────────────────────────────
  const WHEEL_COLORS = [
    "#f59e0b","#3b82f6","#22c55e","#a855f7",
    "#ef4444","#06b6d4","#f97316","#8b5cf6",
    "#14b8a6","#ec4899","#eab308","#6366f1"
  ];

  function ldDraw(angleDeg, greyed) {
    const canvas = document.getElementById("ld-canvas");
    if (!canvas) return;
    const ctx = canvas.getContext("2d");
    const cx = 120, cy = 120, r = 116;
    const slices = 12, sa = (2 * Math.PI) / slices;
    const offset = (angleDeg * Math.PI) / 180;

    ctx.clearRect(0, 0, 240, 240);

    for (let i = 0; i < slices; i++) {
      const start = offset + i * sa;
      const end   = start + sa;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, r, start, end);
      ctx.closePath();
      ctx.fillStyle = greyed
        ? (i % 2 === 0 ? "#374151" : "#4b5563")
        : WHEEL_COLORS[i % WHEEL_COLORS.length];
      ctx.fill();
      ctx.strokeStyle = "rgba(0,0,0,.2)";
      ctx.lineWidth = 1.5;
      ctx.stroke();

      // Decorative dots
      const mid = start + sa / 2;
      ctx.beginPath();
      ctx.arc(
        cx + r * .68 * Math.cos(mid),
        cy + r * .68 * Math.sin(mid),
        5, 0, 2 * Math.PI
      );
      ctx.fillStyle = "rgba(255,255,255,.3)";
      ctx.fill();
    }

    // Outer ring
    ctx.beginPath();
    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
    ctx.strokeStyle = "rgba(255,255,255,.12)";
    ctx.lineWidth = 4;
    ctx.stroke();
  }

  // ── Ease-out animation ──────────────────────────────────────
  function ldAnimate(totalRotation, duration, onDone) {
    const start = performance.now();
    const from  = LD.currentAngle;

    function frame(now) {
      const t    = Math.min((now - start) / duration, 1);
      const ease = 1 - Math.pow(1 - t, 4); // ease-out quart
      const angle = (from + totalRotation * ease) % 360;
      ldDraw(angle, false);
      if (t < 1) {
        requestAnimationFrame(frame);
      } else {
        LD.currentAngle = angle;
        onDone();
      }
    }
    requestAnimationFrame(frame);
  }

  // ── Spin ─────────────────────────────────────────────────────
  window.ldSpin = async function () {
    if (LD.spinning || ldEventEnded()) return;
    const eventId = detailsState?.eventId;
    if (!eventId) return;

    LD.spinning = true;

    const btn = document.getElementById("ld-spin-btn");
    if (btn) { btn.disabled = true; btn.textContent = "⏳ Spinning…"; }

    // Hide previous winner card
    const card = document.getElementById("ld-winner-card");
    if (card) card.style.display = "none";

    const rotations    = (5 + Math.floor(Math.random() * 4)) * 360 + Math.random() * 360;
    const spinDuration = 3400 + Math.random() * 800;

    let apiResult = null;
    let apiDone   = false;
    let animDone  = false;

    function tryReveal() {
      if (!apiDone || !animDone) return;
      if (apiResult) {
        ldRevealWinner(apiResult);
        ldLoadHistory();
      }
      LD.spinning = false;
      if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin Again"; }
    }

    // Hit the backend to pick and store the winner
    fetch(`${ldBase()}/${eventId}/lucky_draw_results`, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${ldToken()}`
      }
    })
    .then(r => r.json())
    .then(res => {
      if (res.success) {
        apiResult = res.data;
      } else {
        alert(res.error || "Failed to pick a winner.");
        LD.spinning = false;
        if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin the Wheel"; }
      }
      apiDone = true;
      tryReveal();
    })
    .catch(() => {
      alert("Network error — please try again.");
      LD.spinning = false;
      if (btn) { btn.disabled = false; btn.innerHTML = "🎲 Spin the Wheel"; }
    });

    // Run wheel animation in parallel
    ldAnimate(rotations, spinDuration, () => {
      animDone = true;
      tryReveal();
    });
  };

  // ── Reveal winner card ──────────────────────────────────────
  function ldRevealWinner(result) {
    const card    = document.getElementById("ld-winner-card");
    const roundEl = document.getElementById("ld-winner-round");
    const nameEl  = document.getElementById("ld-winner-name");
    const metaEl  = document.getElementById("ld-winner-meta");
    const codeEl  = document.getElementById("ld-winner-code");
    const timeEl  = document.getElementById("ld-winner-time");
    const byEl    = document.getElementById("ld-winner-drawn-by");
    if (!card || !nameEl) return;

    const v = result.visitor;
    roundEl.textContent = result.round;
    nameEl.textContent  = v.full_name || "Unknown";

    const parts = [];
    if (v.mobile_number)     parts.push(`📱 ${v.mobile_number}`);
    if (v.business_name)     parts.push(`🏢 ${v.business_name}`);
    if (v.business_category) parts.push(`🏷 ${v.business_category}`);
    if (v.location)          parts.push(`📍 ${v.location}`);
    metaEl.innerHTML = parts.join("&emsp;");

    codeEl.textContent = v.visitor_id_code || v.id;
    timeEl.textContent = ldFormatTime(result.drawn_at);
    if (byEl) byEl.textContent = result.drawn_by ? `Spun by: ${result.drawn_by}` : "";

    card.style.display = "block";
    void card.offsetWidth; // force reflow for animation restart
    card.style.animation = "none";
    setTimeout(() => {
      card.style.animation = "ldWinnerPop .45s cubic-bezier(.34,1.56,.64,1)";
    }, 10);
  }

  // ── Load & render history ───────────────────────────────────
  window.ldLoadHistory = async function () {
    const eventId = detailsState?.eventId;
    if (!eventId) return;

    const el    = document.getElementById("ld-history");
    const badge = document.getElementById("ld-count-badge");
    if (!el) return;

    try {
      const res = await fetch(`${ldBase()}/${eventId}/lucky_draw_results`, {
        headers: { "Authorization": `Bearer ${ldToken()}` }
      }).then(r => r.json());

      const results = res.data || [];
      if (badge) {
        badge.textContent = results.length
          ? `${results.length} winner${results.length !== 1 ? "s" : ""}`
          : "";
      }

      if (!results.length) {
        const ended = ldEventEnded();
        el.innerHTML = `
          <div style="color:var(--text3);font-size:13px;text-align:center;padding:24px 0">
            ${ended
              ? "No draws were run for this event."
              : "No winners yet — hit <strong>Spin the Wheel</strong> to start!"}
          </div>`;
        return;
      }

      el.innerHTML = `
        <div style="overflow-x:auto">
          <table style="width:100%;border-collapse:collapse;min-width:700px">
            <thead>
              <tr>
                ${["#","Visitor ID","Name","Mobile","Business",
                   "Category","Location","Spun By","Drawn At"]
                  .map(h => `
                    <th style="text-align:left;padding:9px 14px;font-size:11px;
                               font-weight:700;text-transform:uppercase;
                               letter-spacing:.06em;color:var(--text3);
                               border-bottom:1px solid var(--border);
                               white-space:nowrap">${h}</th>`)
                  .join("")}
              </tr>
            </thead>
            <tbody>
              ${results.map((r, i) => {
                const v         = r.visitor;
                const isLatest  = i === results.length - 1;
                const isAdmin   = r.drawn_by_type === "SuperAdmin";
                const byBg      = isAdmin
                  ? "rgba(99,102,241,.12);color:#6366f1"
                  : "rgba(34,197,94,.1);color:#16a34a";
                return `
                <tr class="ld-winner-row"
                    style="${isLatest ? "background:rgba(245,158,11,.06);" : ""}">
                  <td style="padding:10px 14px;font-size:13px;
                             font-weight:800;color:#f59e0b">
                    ${r.round}
                    ${isLatest
                      ? `<span style="font-size:10px;background:rgba(245,158,11,.2);
                                     color:#f59e0b;border-radius:10px;
                                     padding:1px 7px;font-weight:700;
                                     margin-left:4px">LATEST</span>`
                      : ""}
                  </td>
                  <td style="padding:10px 14px">
                    <span style="background:rgba(108,99,255,.1);color:#6c63ff;
                                 border-radius:20px;padding:3px 10px;
                                 font-size:11px;font-weight:700">
                      ${v.visitor_id_code || "—"}
                    </span>
                  </td>
                  <td style="padding:10px 14px;font-weight:600;
                             color:var(--text);white-space:nowrap">
                    ${v.full_name || "—"}
                  </td>
                  <td style="padding:10px 14px;font-family:monospace;font-size:13px">
                    ${v.mobile_number || "—"}
                  </td>
                  <td style="padding:10px 14px;color:var(--text2)">
                    ${v.business_name || "—"}
                  </td>
                  <td style="padding:10px 14px;color:var(--text2)">
                    ${v.business_category || "—"}
                  </td>
                  <td style="padding:10px 14px;color:var(--text2)">
                    ${v.location || "—"}
                  </td>
                  <td style="padding:10px 14px">
                    <span style="background:${byBg};border-radius:20px;
                                 padding:3px 10px;font-size:11px;font-weight:700">
                      ${r.drawn_by || "—"}
                    </span>
                  </td>
                  <td style="padding:10px 14px;font-size:12px;
                             color:var(--text3);white-space:nowrap">
                    ${ldFormatTime(r.drawn_at)}
                  </td>
                </tr>`;
              }).join("")}
            </tbody>
          </table>
        </div>`;
    } catch {
      el.innerHTML = `
        <div style="color:var(--text3);font-size:13px;
                    text-align:center;padding:20px">
          Failed to load history. <a href="#" onclick="ldLoadHistory();return false"
          style="color:var(--accent)">Retry</a>
        </div>`;
    }
  };

  // ── Clear all winners ───────────────────────────────────────
  window.ldClearAll = async function () {
    if (ldEventEnded()) return; // extra guard
    const eventId = detailsState?.eventId;
    if (!eventId) return;
    if (!confirm("Clear ALL lucky draw results for this event?\nThis cannot be undone.")) return;

    const btn = document.getElementById("ld-clear-btn");
    if (btn) { btn.disabled = true; btn.textContent = "Clearing…"; }

    try {
      await fetch(`${ldBase()}/${eventId}/lucky_draw_results`, {
        method: "DELETE",
        headers: { "Authorization": `Bearer ${ldToken()}` }
      });

      const card = document.getElementById("ld-winner-card");
      if (card) card.style.display = "none";
      LD.currentAngle = 0;
      ldDraw(0, false);
      ldLoadHistory();
    } finally {
      if (btn) { btn.disabled = false; btn.innerHTML = "🗑 Clear All"; }
    }
  };

  // ── Inject section into event detail page ───────────────────
  function ldInjectSection() {
    const ended = ldEventEnded();

    // Section already mounted — just sync buttons + refresh data
    if (document.getElementById("lucky-draw-section")) {
      ldSyncButtons();
      ldLoadHistory();
      return;
    }

    const anchor = document.getElementById("event-analytics-section");
    if (!anchor) return;

    const div = document.createElement("div");
    div.innerHTML = ldRenderSection(ended);
    anchor.parentNode.insertBefore(div.firstElementChild, anchor);

    ldDraw(0, ended);
    ldLoadHistory();
  }

  // ── Hook into showEventDetails ──────────────────────────────
  function ldHook() {
    const orig = window.showEventDetails;
    if (!orig || orig._ldHooked) return;

    window.showEventDetails = async function (...args) {
      // Remove old section so it fully re-renders for the new event
      const old = document.getElementById("lucky-draw-section");
      if (old) old.remove();

      await orig.apply(this, args);
      setTimeout(ldInjectSection, 120);
    };

    window.showEventDetails._ldHooked = true;
  }

  // ── Date formatter ──────────────────────────────────────────
  function ldFormatTime(iso) {
    if (!iso) return "—";
    try {
      return new Date(iso).toLocaleString("en-IN", {
        day:    "2-digit",
        month:  "short",
        year:   "numeric",
        hour:   "2-digit",
        minute: "2-digit"
      });
    } catch { return iso; }
  }

  // ── Bootstrap ───────────────────────────────────────────────
  function ldInit() {
    ldInjectStyles();
    ldHook();
  }

  if (document.readyState === "loading") {
    document.addEventListener("DOMContentLoaded", ldInit);
  } else {
    ldInit();
  }

})();