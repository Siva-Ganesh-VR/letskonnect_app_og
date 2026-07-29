// =============================================================
// card_scanner.js — Business Card OCR for StallConnect
//
// Tesseract.js runs entirely in the browser — free, no API key.
// UI is embedded directly in stall.html — this file only
// handles OCR processing and field parsing.
//
// Required in stall.html before </body>:
//   <script src="https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js"></script>
//   <script src="/js/card_scanner.js"></script>
// =============================================================

(function () {
  "use strict";

  // ── Open camera / file picker ───────────────────────────────
  window.csTriggerPicker = function () {
    const input = document.getElementById("cs-file-input");
    if (input) { input.value = ""; input.click(); }
  };

  // ── Handle selected image ────────────────────────────────────
  window.csHandleFile = async function (file) {
    if (!file) return;

    // Show card preview
    const preview = document.getElementById("cs-card-preview");
    const panel   = document.getElementById("cs-preview-panel");
    preview.src   = URL.createObjectURL(file);
    panel.style.display = "block";

    // Reset previous results
    document.getElementById("cs-extracted-fields").innerHTML = "";
    document.getElementById("cs-action-row").style.display  = "none";

    // UI — show scanning state
    const btn      = document.getElementById("cs-scan-btn");
    const btnLabel = document.getElementById("cs-btn-label");
    const label    = document.getElementById("cs-progress-label");
    const barWrap  = document.getElementById("cs-progress-bar-wrap");
    const bar      = document.getElementById("cs-progress-bar");

    if (btn)      btn.disabled = true;
    if (btnLabel) btnLabel.textContent = "Scanning…";
    if (label)    label.style.display  = "block";
    if (barWrap)  barWrap.style.display = "block";
    if (bar)      bar.style.width = "5%";

    try {
      if (typeof Tesseract === "undefined") {
        csShowToast("❌ OCR library not loaded. Check your internet connection.");
        return;
      }

      // Run Tesseract OCR
      const result = await Tesseract.recognize(file, "eng", {
        logger: (m) => {
          if (m.status === "recognizing text" && bar) {
            bar.style.width = Math.round(m.progress * 100) + "%";
          }
        }
      });

      if (bar) bar.style.width = "100%";

      const rawText = result.data.text;
      const fields  = csParseCard(rawText);
      window._csExtractedFields = fields;

      csRenderFields(fields, rawText);

      const actionRow = document.getElementById("cs-action-row");
      if (actionRow) actionRow.style.display = "flex";

      csShowToast("✅ Card scanned! Review and tap Fill Form.");

    } catch (err) {
      console.error("OCR error:", err);
      csShowToast("❌ Could not read card. Try better lighting.");
      const ef = document.getElementById("cs-extracted-fields");
      if (ef) ef.innerHTML =
        `<div style="color:#ef4444;font-size:12px">
           Could not read card. Try again with better lighting or a clearer photo.
         </div>`;
    } finally {
      if (btn)      btn.disabled = false;
      if (btnLabel) btnLabel.textContent = "Scan Another Card";
      if (label)    label.style.display  = "none";
      if (barWrap)  barWrap.style.display = "none";
      if (bar)      bar.style.width = "0%";
    }
  };

  // ── Smart parser for Indian business cards ──────────────────
  function csParseCard(raw) {
    const lines = raw
      .split("\n")
      .map(l => l.trim())
      .filter(l => l.length > 1);

    const fields = {
      full_name:     "",
      mobile_number: "",
      email:         "",
      business_name: "",
      designation:   "",
      location:      "",
      website:       "",
    };

    // Email
    const emailMatch = raw.match(/[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/);
    if (emailMatch) fields.email = emailMatch[0].toLowerCase();

    // Website
    const webMatch = raw.match(/(?:www\.|https?:\/\/)[^\s,<>]+/i);
    if (webMatch) fields.website = webMatch[0].replace(/^https?:\/\//i, "www.");

    // Indian mobile — handles +91, 0091, 091, spaces, dashes
    const mobileMatch = raw.replace(/[\s\-().]/g, "")
      .match(/(?:\+?91)?([6-9]\d{9})/);
    if (mobileMatch) fields.mobile_number = mobileMatch[1];

    // Designation — common titles
    const desgRe = /\b(CEO|CTO|CFO|COO|CMO|MD|GM|VP|AVP|SVP|EVP|President|Director|Manager|Head|Lead|Senior|Junior|Associate|Founder|Co-?Founder|Partner|Consultant|Advisor|Executive|Officer|Engineer|Architect|Designer|Developer|Analyst|Specialist|Proprietor|Owner)\b/i;
    for (const line of lines) {
      if (desgRe.test(line) && line.length < 60) {
        fields.designation = csClean(line);
        break;
      }
    }

    // Business name — company suffixes
    const bizRe = /\b(Pvt\.?\s*Ltd\.?|Private\s+Limited|Ltd\.?|Limited|LLP|Inc\.?|Corp\.?|Corporation|Enterprises?|Solutions?|Technologies?|Techno|Infotech|Services?|Systems?|Consultants?|Associates?|Group|Holdings?|Industries?|Ventures?|Works|Exports?)\b/i;
    for (const line of lines) {
      if (bizRe.test(line) && line.length < 80) {
        fields.business_name = csClean(line);
        break;
      }
    }

    // Indian city names
    const cities = [
      "Mumbai","Delhi","Bangalore","Bengaluru","Hyderabad","Ahmedabad",
      "Chennai","Kolkata","Surat","Pune","Jaipur","Lucknow","Kanpur",
      "Nagpur","Indore","Thane","Bhopal","Visakhapatnam","Patna","Vadodara",
      "Ghaziabad","Ludhiana","Agra","Nashik","Meerut","Faridabad","Rajkot",
      "Coimbatore","Madurai","Noida","Gurugram","Gurgaon","Kochi","Ernakulam",
      "Mysuru","Mysore","Trichy","Salem","Chandigarh","Jodhpur","Bhubaneswar",
      "Jabalpur","Raipur","Kota","Gwalior","Vijayawada","Solapur","Hubli",
      "Mangalore","Tiruppur","Warangal","Navi Mumbai","Aurangabad","Amritsar"
    ];
    const cityRe = new RegExp(`\\b(${cities.join("|")})\\b`, "i");
    const cityMatch = raw.match(cityRe);
    if (cityMatch) fields.location = csTitleCase(cityMatch[1]);

    // PIN code fallback for location
    if (!fields.location) {
      const pinMatch = raw.match(/\b([A-Z][a-z]+(?: [A-Z][a-z]+)?)\s*[-–]\s*\d{6}\b/);
      if (pinMatch) fields.location = pinMatch[1];
    }

    // Name — first line that looks like a person's name
    const skipRe = /pvt|ltd|inc|corp|group|enterprise|solution|service|technolog|consultant|associate|http|www|@|mobile|phone|tel|email|address|no\.|#|road|street|nagar|near|opp|plot|floor|building|gst|pan\b/i;
    for (const line of lines) {
      const clean = line.replace(/[^a-zA-Z\s.]/g, "").trim();
      if (
        clean.length >= 3 &&
        clean.length <= 45 &&
        /^[A-Za-z\s.]+$/.test(clean) &&
        !skipRe.test(clean) &&
        clean.split(" ").length >= 1 &&
        clean !== fields.designation &&
        clean !== fields.business_name
      ) {
        fields.full_name = csTitleCase(csClean(clean));
        break;
      }
    }

    return fields;
  }

  // ── Render extracted fields ─────────────────────────────────
  function csRenderFields(fields, rawText) {
    const el = document.getElementById("cs-extracted-fields");
    if (!el) return;

    const rows = [
      { key: "Name",        val: fields.full_name     },
      { key: "Mobile",      val: fields.mobile_number },
      { key: "Email",       val: fields.email         },
      { key: "Company",     val: fields.business_name },
      { key: "Designation", val: fields.designation   },
      { key: "Location",    val: fields.location      },
      { key: "Website",     val: fields.website       },
    ];

    el.innerHTML = rows.map(r => `
      <div style="display:flex;gap:8px;align-items:baseline;padding:4px 0;
                  border-bottom:1px solid rgba(255,255,255,.04)">
        <span style="font-size:10px;font-weight:700;text-transform:uppercase;
                     letter-spacing:.06em;color:rgba(255,255,255,.35);
                     min-width:80px;flex-shrink:0">${r.key}</span>
        <span style="font-size:13px;font-weight:500;
                     color:${r.val ? "#fff" : "rgba(255,255,255,.25)"};
                     ${r.val ? "" : "font-style:italic"}">
          ${r.val || "not detected"}
        </span>
      </div>`
    ).join("") + `
      <details style="margin-top:8px">
        <summary style="font-size:11px;color:rgba(255,255,255,.3);
                        cursor:pointer;user-select:none">
          Raw OCR text
        </summary>
        <pre style="font-size:10px;color:rgba(255,255,255,.3);white-space:pre-wrap;
                    word-break:break-all;margin-top:6px;padding:8px;
                    background:rgba(0,0,0,.3);border-radius:6px;
                    max-height:120px;overflow-y:auto">${csEscape(rawText)}</pre>
      </details>`;
  }

  // ── Apply fields into the form ───────────────────────────────
  window.csApplyFields = function () {
    const f = window._csExtractedFields;
    if (!f) return;

    const set = (id, val) => {
      const el = document.getElementById(id);
      if (el && val) el.value = val;
    };

    set("full_name",     f.full_name);
    set("mobile_number", f.mobile_number);
    set("location",      f.location);
    set("email",         f.email);
    set("designation",   f.designation);
    set("business_name", f.business_name);
    set("website",       f.website);

    // Scroll to name field for review
    const nameEl = document.getElementById("full_name");
    if (nameEl) nameEl.scrollIntoView({ behavior: "smooth", block: "center" });

    csShowToast("✅ Form filled! Please review and submit.");
  };

  // ── Toast ────────────────────────────────────────────────────
  function csShowToast(msg) {
    // Try using the existing stall.html toast function
    if (typeof toast === "function") {
      const type = msg.startsWith("✅") ? "ok" : "err";
      toast(msg, type);
      return;
    }
    // Fallback — create our own toast
    let t = document.getElementById("cs-toast");
    if (!t) {
      t = document.createElement("div");
      t.id = "cs-toast";
      t.style.cssText = `position:fixed;bottom:90px;left:50%;
        transform:translateX(-50%) translateY(20px);
        background:#1e293b;color:#fff;padding:10px 20px;
        border-radius:20px;font-size:13px;font-weight:600;
        opacity:0;transition:all .3s;z-index:9999;
        pointer-events:none;white-space:nowrap;
        box-shadow:0 4px 20px rgba(0,0,0,.4)`;
      document.body.appendChild(t);
    }
    t.textContent = msg;
    t.style.opacity = "1";
    t.style.transform = "translateX(-50%) translateY(0)";
    setTimeout(() => {
      t.style.opacity = "0";
      t.style.transform = "translateX(-50%) translateY(20px)";
    }, 3000);
  }

  // ── Helpers ──────────────────────────────────────────────────
  function csClean(s) {
    return s.replace(/[^\w\s\-.,&()/]/g, "").trim();
  }
  function csTitleCase(s) {
    return s.replace(/\w\S*/g, w =>
      w.charAt(0).toUpperCase() + w.slice(1).toLowerCase()
    );
  }
  function csEscape(s) {
    return s
      .replace(/&/g, "&amp;")
      .replace(/</g, "&lt;")
      .replace(/>/g, "&gt;");
  }

})();