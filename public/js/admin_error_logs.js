// =============================================================
// admin_error_logs.js
// Add before </body> in admin.html:
//   <script src="/js/admin_error_logs.js"></script>
// OR paste this entire block inside the existing <script> tag
// in admin.html before the closing })() or end of script
// =============================================================

// ── Load error logs ───────────────────────────────────────────
let elCurrentPage = 1;
let elCurrentLogId = null;

async function elLoadLogs(page) {
  elCurrentPage = page || 1;
  const source   = document.getElementById("el-filter-source")?.value   || "";
  const severity = document.getElementById("el-filter-severity")?.value || "";
  const resolved = document.getElementById("el-filter-resolved")?.value;
  const search   = document.getElementById("el-search")?.value          || "";

  let path = `/super_admin/error_logs?page=${elCurrentPage}&per_page=25`;
  if (source)   path += `&source=${source}`;
  if (severity) path += `&severity=${severity}`;
  if (resolved !== undefined && resolved !== "") path += `&resolved=${resolved}`;
  if (search)   path += `&search=${encodeURIComponent(search)}`;

  const res = await apiFetch(path);
  if (!res.success) return;

  const logs = res.data   || [];
  const meta = res.meta   || {};
  const sum  = meta.summary || {};

  // Update summary cards
  elSetText("el-total",     sum.total     || 0);
  elSetText("el-unresolved",sum.unresolved || 0);
  elSetText("el-errors",    sum.errors    || 0);
  elSetText("el-warnings",  sum.warnings  || 0);

  // Update nav badge
  const badge = document.getElementById("error-logs-badge");
  if (badge) {
    if (sum.unresolved > 0) {
      badge.textContent = sum.unresolved;
      badge.style.display = "inline-block";
    } else {
      badge.style.display = "none";
    }
  }

  // Update subtitle
  elSetText("el-subtitle", `${sum.total || 0} total · ${sum.unresolved || 0} unresolved`);

  // Render table
  const tbody = document.getElementById("el-tbody");
  if (!tbody) return;

  if (!logs.length) {
    tbody.innerHTML = `<tr><td colspan="7" style="padding:40px;text-align:center;color:var(--text3)">
      <div style="font-size:32px;margin-bottom:8px">✅</div>
      No error logs found
    </td></tr>`;
    return;
  }

  tbody.innerHTML = logs.map(l => {
    const sevColor  = l.severity === "error"   ? "#ef4444"
                    : l.severity === "warning" ? "#f59e0b"
                    : "#6c63ff";
    const sevBg     = l.severity === "error"   ? "rgba(239,68,68,.1)"
                    : l.severity === "warning" ? "rgba(245,158,11,.1)"
                    : "rgba(108,99,255,.1)";
    const srcColor  = { api:"#6c63ff", sidekiq:"#f59e0b", frontend:"#22c55e", ocr:"#3b82f6" }[l.source] || "#6b7280";
    const endpoint  = l.job_class || l.endpoint || "—";
    const time      = l.occurred_at ? new Date(l.occurred_at).toLocaleString("en-IN", { day:"2-digit", month:"short", hour:"2-digit", minute:"2-digit" }) : "—";

    return `<tr style="border-bottom:1px solid rgba(255,255,255,.04);${l.resolved ? "opacity:.5" : ""}"
              onmouseover="this.style.background='rgba(255,255,255,.02)'"
              onmouseout="this.style.background=''">
      <td style="padding:10px 14px;font-size:12px;color:var(--text3);white-space:nowrap">${time}</td>
      <td style="padding:10px 14px">
        <span style="background:${srcColor}22;color:${srcColor};border-radius:20px;padding:2px 10px;font-size:11px;font-weight:700;text-transform:uppercase">
          ${l.source}
        </span>
      </td>
      <td style="padding:10px 14px">
        <span style="background:${sevBg};color:${sevColor};border-radius:20px;padding:2px 10px;font-size:11px;font-weight:700">
          ${l.severity}
        </span>
      </td>
      <td style="padding:10px 14px;max-width:280px">
        <div style="font-size:13px;color:var(--text);overflow:hidden;text-overflow:ellipsis;white-space:nowrap;max-width:280px" title="${elEscape(l.message)}">
          ${elEscape(l.message)}
        </div>
        ${l.error_type ? `<div style="font-size:11px;color:var(--text3);margin-top:2px">${l.error_type}</div>` : ""}
      </td>
      <td style="padding:10px 14px;font-size:12px;color:var(--text3);max-width:180px;overflow:hidden;text-overflow:ellipsis;white-space:nowrap" title="${elEscape(endpoint)}">
        ${elEscape(endpoint.replace("/api/v1/", "/"))}
      </td>
      <td style="padding:10px 14px">
        ${l.resolved
          ? `<span style="color:#22c55e;font-size:12px">✓ Resolved</span>`
          : `<span style="color:#ef4444;font-size:12px">● Open</span>`
        }
      </td>
      <td style="padding:10px 14px">
        <button onclick="elShowDetail('${l.id}')"
          style="background:rgba(108,99,255,.12);border:1px solid rgba(108,99,255,.25);color:#a5b4fc;border-radius:7px;padding:4px 10px;font-size:11px;font-weight:600;cursor:pointer;font-family:inherit">
          View
        </button>
      </td>
    </tr>`;
  }).join("");

  // Pagination
  elRenderPagination(meta.page, meta.pages);
}

// ── Show detail modal ─────────────────────────────────────────
async function elShowDetail(id) {
  elCurrentLogId = id;
  const modal = document.getElementById("el-modal");
  if (modal) modal.style.display = "block";
  const body = document.getElementById("el-modal-body");
  if (body) body.innerHTML = `<div style="text-align:center;padding:20px;color:var(--text3)">Loading...</div>`;

  const res = await apiFetch(`/super_admin/error_logs/${id}`);
  if (!res.success || !body) return;

  const l = res.data;

  const row = (label, val, mono) => val
    ? `<div style="display:flex;gap:12px;padding:8px 0;border-bottom:1px solid rgba(255,255,255,.04)">
        <div style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:var(--text3);min-width:110px;flex-shrink:0;padding-top:2px">${label}</div>
        <div style="font-size:13px;color:var(--text);word-break:break-all;${mono ? "font-family:monospace;font-size:12px" : ""}">${elEscape(String(val))}</div>
       </div>`
    : "";

  const sevColor = l.severity === "error" ? "#ef4444" : l.severity === "warning" ? "#f59e0b" : "#6c63ff";

  body.innerHTML = `
    <div style="display:flex;gap:8px;flex-wrap:wrap;margin-bottom:16px">
      <span style="background:rgba(255,255,255,.08);color:var(--text);border-radius:20px;padding:3px 12px;font-size:12px;font-weight:700;text-transform:uppercase">${l.source}</span>
      <span style="background:${sevColor}22;color:${sevColor};border-radius:20px;padding:3px 12px;font-size:12px;font-weight:700">${l.severity}</span>
      ${l.status_code ? `<span style="background:rgba(239,68,68,.1);color:#fca5a5;border-radius:20px;padding:3px 12px;font-size:12px;font-weight:700">HTTP ${l.status_code}</span>` : ""}
      ${l.resolved ? `<span style="background:rgba(34,197,94,.1);color:#86efac;border-radius:20px;padding:3px 12px;font-size:12px;font-weight:700">✓ Resolved</span>` : ""}
    </div>

    <div style="background:rgba(239,68,68,.06);border:1px solid rgba(239,68,68,.12);border-radius:10px;padding:14px;margin-bottom:16px">
      <div style="font-size:14px;font-weight:600;color:#fff;word-break:break-all">${elEscape(l.message)}</div>
      ${l.error_type ? `<div style="font-size:12px;color:rgba(255,255,255,.4);margin-top:4px">${l.error_type}</div>` : ""}
    </div>

    ${row("Occurred", l.occurred_at ? new Date(l.occurred_at).toLocaleString("en-IN") : null)}
    ${row("Endpoint", l.endpoint)}
    ${row("Method", l.http_method)}
    ${row("Job Class", l.job_class)}
    ${row("Job ID", l.job_id, true)}
    ${row("IP Address", l.ip_address)}
    ${row("User Type", l.user_type)}
    ${row("Request ID", l.request_id, true)}
    ${row("Event ID", l.event_id, true)}
    ${row("Stall Owner", l.stall_owner_id, true)}
    ${row("Organizer", l.organizer_id, true)}

    ${l.request_params && Object.keys(l.request_params).length
      ? `<div style="margin-top:12px">
           <div style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:var(--text3);margin-bottom:6px">Request Params</div>
           <pre style="background:rgba(0,0,0,.3);border-radius:8px;padding:12px;font-size:12px;color:rgba(255,255,255,.7);overflow-x:auto;white-space:pre-wrap;word-break:break-all">${elEscape(JSON.stringify(l.request_params, null, 2))}</pre>
         </div>`
      : ""}

    ${l.backtrace
      ? `<div style="margin-top:12px">
           <div style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:var(--text3);margin-bottom:6px">Backtrace</div>
           <pre style="background:rgba(0,0,0,.3);border-radius:8px;padding:12px;font-size:11px;color:rgba(255,255,255,.5);overflow-x:auto;white-space:pre-wrap;max-height:200px;overflow-y:auto">${elEscape(l.backtrace)}</pre>
         </div>`
      : ""}

    ${l.context && Object.keys(l.context).length
      ? `<div style="margin-top:12px">
           <div style="font-size:11px;font-weight:700;text-transform:uppercase;letter-spacing:.07em;color:var(--text3);margin-bottom:6px">Context</div>
           <pre style="background:rgba(0,0,0,.3);border-radius:8px;padding:12px;font-size:12px;color:rgba(255,255,255,.7);overflow-x:auto;white-space:pre-wrap">${elEscape(JSON.stringify(l.context, null, 2))}</pre>
         </div>`
      : ""}

    ${l.resolved
      ? `<div style="margin-top:16px;background:rgba(34,197,94,.08);border:1px solid rgba(34,197,94,.2);border-radius:10px;padding:12px">
           <div style="font-size:12px;font-weight:600;color:#86efac;margin-bottom:4px">✓ Resolved on ${new Date(l.resolved_at).toLocaleString("en-IN")}</div>
           ${l.resolution_note ? `<div style="font-size:12px;color:rgba(255,255,255,.5)">${elEscape(l.resolution_note)}</div>` : ""}
         </div>`
      : ""}
  `;

  // Hide resolve button if already resolved
  const btn = document.getElementById("el-resolve-btn");
  if (btn) btn.style.display = l.resolved ? "none" : "block";
}

function elCloseModal() {
  const modal = document.getElementById("el-modal");
  if (modal) modal.style.display = "none";
  elCurrentLogId = null;
}

// ── Resolve one ───────────────────────────────────────────────
async function elResolveOne() {
  if (!elCurrentLogId) return;
  const note = document.getElementById("el-resolve-note")?.value || "";
  const res  = await apiFetch(`/super_admin/error_logs/${elCurrentLogId}/resolve`, {
    method: "PATCH",
    body:   JSON.stringify({ note })
  });
  if (res.success) {
    elCloseModal();
    elLoadLogs(elCurrentPage);
  }
}

// ── Resolve all ───────────────────────────────────────────────
async function elResolveAll() {
  const source = document.getElementById("el-filter-source")?.value || "";
  if (!confirm("Mark all unresolved errors as resolved?")) return;
  const body = source ? JSON.stringify({ source }) : JSON.stringify({});
  const res  = await apiFetch("/super_admin/error_logs/resolve_all", { method: "PATCH", body });
  if (res.success) { elLoadLogs(1); }
}

// ── Clear resolved ────────────────────────────────────────────
async function elClearResolved() {
  if (!confirm("Permanently delete all resolved logs? This cannot be undone.")) return;
  const res = await apiFetch("/super_admin/error_logs/clear_resolved", { method: "DELETE" });
  if (res.success) { elLoadLogs(1); }
}

// ── Pagination ────────────────────────────────────────────────
function elRenderPagination(currentPage, totalPages) {
  const el = document.getElementById("el-pagination");
  if (!el || totalPages <= 1) { if (el) el.innerHTML = ""; return; }

  let html = "";
  const btnStyle = (active) =>
    `background:${active ? "var(--accent)" : "var(--bg2)"};border:1px solid ${active ? "var(--accent)" : "var(--border)"};color:${active ? "#000" : "var(--text2)"};border-radius:8px;padding:5px 12px;font-size:12px;font-weight:600;cursor:${active ? "default" : "pointer"};font-family:inherit`;

  if (currentPage > 1) html += `<button onclick="elLoadLogs(${currentPage-1})" style="${btnStyle(false)}">‹ Prev</button>`;

  const start = Math.max(1, currentPage - 2);
  const end   = Math.min(totalPages, currentPage + 2);
  for (let i = start; i <= end; i++) {
    html += `<button onclick="elLoadLogs(${i})" style="${btnStyle(i === currentPage)}" ${i===currentPage?"disabled":""}>${i}</button>`;
  }

  if (currentPage < totalPages) html += `<button onclick="elLoadLogs(${currentPage+1})" style="${btnStyle(false)}">Next ›</button>`;

  el.innerHTML = html;
}

// ── Helpers ───────────────────────────────────────────────────
function elSetText(id, val) {
  const el = document.getElementById(id);
  if (el) el.textContent = val;
}

function elEscape(s) {
  return String(s || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;");
}

// ── Auto-load when page becomes active ───────────────────────
// Hook into existing showPage function
const _origShowPage = window.showPage;
if (typeof _origShowPage === "function") {
  window.showPage = function(name) {
    if (name === "error-logs") {
      // Page might not be loaded yet — wait for it
      const el = document.getElementById("page-error-logs");
      if (!el) {
        fetch("/partials/error_logs_page.html")
          .then(r => r.text())
          .then(html => {
            const div = document.createElement("div");
            div.innerHTML = html;
            document.getElementById("app-screen").appendChild(div.firstElementChild);
            _origShowPage(name);
            elLoadLogs(1);
          });
        return;
      }
    }
    _origShowPage(name);
    if (name === "error-logs") elLoadLogs(1);
  };
}

// ── Load badge count on startup ───────────────────────────────
document.addEventListener("DOMContentLoaded", async function() {
  // Wait for app to load then fetch unresolved count for badge
  setTimeout(async function() {
    try {
      const res = await apiFetch("/super_admin/error_logs?per_page=1&resolved=false");
      if (res.success) {
        const count = res.meta?.summary?.unresolved || 0;
        const badge = document.getElementById("error-logs-badge");
        if (badge && count > 0) {
          badge.textContent = count;
          badge.style.display = "inline-block";
        }
      }
    } catch(e) {}
  }, 2000);
});