// =============================================================
// card_scanner.js — Business Card OCR for StallConnect
//
// Mobile  → uses file input with capture="environment" (rear camera)
// Desktop → opens getUserMedia camera modal, captures a frame
//
// Requires in stall.html before </body>:
//   <script src="https://cdn.jsdelivr.net/npm/tesseract.js@5/dist/tesseract.min.js"></script>
//   <script src="/js/card_scanner.js"></script>
// =============================================================

(function () {
  "use strict";

  let _stream      = null;   // active MediaStream
  let _cameras     = [];     // list of video input devices
  let _activeCamId = null;   // currently selected camera deviceId

  // ── Detect mobile ───────────────────────────────────────────
  function csisMobile() {
    return /Android|iPhone|iPad|iPod|Mobile/i.test(navigator.userAgent);
  }

  // ── Main entry point — smart dispatch ───────────────────────
  window.csTriggerScan = function () {
    if (csisMobile()) {
      // On mobile: open rear camera via file input
      const input = document.getElementById("cs-file-input");
      if (input) {
        input.removeAttribute("capture");
        input.setAttribute("capture", "environment");
        input.value = "";
        input.click();
      }
    } else {
      // On desktop: open getUserMedia camera modal
      csOpenCamera();
    }
  };

  // ── Also keep gallery/upload option accessible ───────────────
  window.csTriggerGallery = function () {
    const input = document.getElementById("cs-file-input");
    if (input) {
      input.removeAttribute("capture");
      input.value = "";
      input.click();
    }
  };

  // ── Open desktop camera modal ─────────────────────────────────
  window.csOpenCamera = async function () {
    const modal = document.getElementById("cs-camera-modal");
    if (modal) modal.style.display = "flex";

    try {
      // Enumerate cameras
      _cameras = (await navigator.mediaDevices.enumerateDevices())
        .filter(d => d.kind === "videoinput");

      // Populate camera select if multiple cameras found
      const sel = document.getElementById("cs-cam-select");
      if (sel) {
        if (_cameras.length > 1) {
          sel.style.display = "block";
          sel.innerHTML = _cameras.map((c, i) =>
            `<option value="${c.deviceId}">${c.label || "Camera " + (i + 1)}</option>`
          ).join("");
          // Default to back camera if available
          const backCam = _cameras.find(c =>
            /back|rear|environment/i.test(c.label)
          );
          if (backCam) {
            sel.value   = backCam.deviceId;
            _activeCamId = backCam.deviceId;
          } else {
            _activeCamId = _cameras[_cameras.length - 1].deviceId;
            sel.value   = _activeCamId;
          }
        } else {
          sel.style.display = "none";
          _activeCamId = _cameras[0]?.deviceId || null;
        }
      }

      await csStartStream(_activeCamId);

    } catch (err) {
      console.error("Camera error:", err);
      csCloseCamera();
      if (err.name === "NotAllowedError") {
        csShowToast("❌ Camera permission denied. Please allow camera access in your browser.");
      } else if (err.name === "NotFoundError") {
        csShowToast("❌ No camera found. Use Upload Card Photo instead.");
      } else {
        csShowToast("❌ Could not open camera: " + err.message);
      }
      // Fallback to file picker
      csTriggerGallery();
    }
  };

  // ── Start video stream ────────────────────────────────────────
  async function csStartStream(deviceId) {
    // Stop existing stream first
    if (_stream) {
      _stream.getTracks().forEach(t => t.stop());
      _stream = null;
    }

    // Request highest resolution for better OCR — fallback to 1080p if 4K not supported
    const constraints = {
      video: deviceId
        ? { deviceId: { exact: deviceId }, width: { ideal: 3840, min: 1920 }, height: { ideal: 2160, min: 1080 }, focusMode: "continuous" }
        : { facingMode: { ideal: "environment" }, width: { ideal: 3840, min: 1920 }, height: { ideal: 2160, min: 1080 }, focusMode: "continuous" }
    };

    try {
      _stream = await navigator.mediaDevices.getUserMedia(constraints);
    } catch (e) {
      const fallback = {
        video: deviceId
          ? { deviceId: { exact: deviceId }, width: { ideal: 1920 }, height: { ideal: 1080 } }
          : { facingMode: { ideal: "environment" }, width: { ideal: 1920 }, height: { ideal: 1080 } }
      };
      _stream = await navigator.mediaDevices.getUserMedia(fallback);
    }

    const video = document.getElementById("cs-video");
    if (video) {
      video.srcObject = _stream;
      await video.play();
    }
  }

  // ── Switch camera ─────────────────────────────────────────────
  window.csChangeCamera = async function () {
    const sel = document.getElementById("cs-cam-select");
    if (!sel) return;
    _activeCamId = sel.value;
    try {
      await csStartStream(_activeCamId);
    } catch (err) {
      csShowToast("❌ Could not switch camera.");
    }
  };

  // ── Capture frame from video ──────────────────────────────────
  window.csCaptureFrame = function () {
    const video  = document.getElementById("cs-video");
    const canvas = document.getElementById("cs-canvas");
    if (!video || !canvas) return;

    // Use full native resolution — not capped
    const W = video.videoWidth  || 1920;
    const H = video.videoHeight || 1080;
    canvas.width  = W;
    canvas.height = H;

    const ctx = canvas.getContext("2d");
    ctx.drawImage(video, 0, 0, W, H);

    // Grayscale + contrast boost for better OCR
    const imageData = ctx.getImageData(0, 0, W, H);
    const data = imageData.data;
    for (let i = 0; i < data.length; i += 4) {
      const avg = 0.299 * data[i] + 0.587 * data[i+1] + 0.114 * data[i+2];
      const val = Math.min(255, Math.max(0, ((avg - 128) * 1.5) + 128));
      data[i] = data[i+1] = data[i+2] = val;
    }
    ctx.putImageData(imageData, 0, 0);

    csCloseCamera();

    // Higher quality + PNG for lossless OCR input
    canvas.toBlob(blob => {
      if (blob) csProcessImage(blob);
    }, "image/jpeg", 0.98);
  };

  // ── Close camera modal ────────────────────────────────────────
  window.csCloseCamera = function () {
    if (_stream) {
      _stream.getTracks().forEach(t => t.stop());
      _stream = null;
    }
    const modal = document.getElementById("cs-camera-modal");
    if (modal) modal.style.display = "none";

    const video = document.getElementById("cs-video");
    if (video) { video.srcObject = null; }
  };

  // ── Handle file input (mobile / gallery upload) ───────────────
  window.csHandleFile = function (file) {
    if (!file) return;
    csProcessImage(file);
  };

  // ── Core: process image through Tesseract OCR ─────────────────
  async function csProcessImage(imageSource) {
    // Show preview
    const preview = document.getElementById("cs-card-preview");
    const panel   = document.getElementById("cs-preview-panel");
    const url     = URL.createObjectURL(imageSource);
    if (preview) preview.src = url;
    if (panel)   panel.style.display = "block";

    // Reset previous results
    const efEl  = document.getElementById("cs-extracted-fields");
    const actEl = document.getElementById("cs-action-row");
    if (efEl)  efEl.innerHTML = "";
    if (actEl) actEl.style.display = "none";

    // Show scanning state
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
        csShowToast("❌ OCR library not loaded. Check internet connection.");
        return;
      }

      const result = await Tesseract.recognize(imageSource, "eng", {
        logger: m => {
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
      if (actEl) actEl.style.display = "flex";
      csShowToast("✅ Card scanned! Review and tap Fill Form.");

    } catch (err) {
      console.error("OCR error:", err);
      csShowToast("❌ Could not read card. Try better lighting.");
      if (efEl) efEl.innerHTML =
        `<div style="color:#ef4444;font-size:12px">
           Could not read the card. Try with better lighting or a clearer photo.
         </div>`;
    } finally {
      if (btn)      btn.disabled = false;
      if (btnLabel) btnLabel.textContent = "Scan Another Card";
      if (label)    label.style.display  = "none";
      if (barWrap)  barWrap.style.display = "none";
      if (bar)      bar.style.width = "0%";
    }
  }

  // ── Smart parser for Indian business cards ────────────────────
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
    const emailMatch = raw.match(
      /[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}/
    );
    if (emailMatch) fields.email = emailMatch[0].toLowerCase();

    // Website
    const webMatch = raw.match(/(?:www\.|https?:\/\/)[^\s,<>]+/i);
    if (webMatch) fields.website = webMatch[0].replace(/^https?:\/\//i, "www.");

    // Indian mobile — handles +91, spaces, dashes, brackets
    const cleaned   = raw.replace(/[()]/g, "");
    const mobPatterns = [
      /(?:\+91|0091|091|91)?[\s\-]?([6-9]\d{2})[\s\-]?(\d{3})[\s\-]?(\d{4})/,
      /(?:\+91|0091|091|91)?([6-9]\d{9})/,
    ];
    for (const pat of mobPatterns) {
      const m = cleaned.match(pat);
      if (m) {
        const num = (m[1] + (m[2] || "") + (m[3] || "")).replace(/\D/g, "");
        if (num.length === 10) { fields.mobile_number = num; break; }
      }
    }
    const mobMatch = null; // handled above
    // mobile_number already set above

    // Designation
    const desgRe = /\b(CEO|CTO|CFO|COO|CMO|MD|GM|VP|AVP|SVP|EVP|President|Director|Manager|Head|Lead|Senior|Junior|Associate|Founder|Co-?Founder|Partner|Consultant|Advisor|Executive|Officer|Engineer|Architect|Designer|Developer|Analyst|Specialist|Proprietor|Owner)\b/i;
    for (const line of lines) {
      if (desgRe.test(line) && line.length < 60) {
        fields.designation = csClean(line);
        break;
      }
    }

    // Business name — company suffixes
    const bizRe = /\b(Pvt\.?\s*Ltd\.?|Private\s+Limited|Ltd\.?|Limited|LLP|Inc\.?|Corp\.?|Corporation|Enterprises?|Solutions?|Technologies?|Techno|Infotech|Services?|Systems?|Consultants?|Associates?|Group|Holdings?|Industries?|Ventures?|Works|Exports?|Trading)\b/i;
    for (const line of lines) {
      if (bizRe.test(line) && line.length < 80) {
        fields.business_name = csClean(line);
        break;
      }
    }

    // Indian cities
    const cities = [
      "Mumbai","Delhi","Bangalore","Bengaluru","Hyderabad","Ahmedabad",
      "Chennai","Kolkata","Surat","Pune","Jaipur","Lucknow","Kanpur",
      "Nagpur","Indore","Thane","Bhopal","Visakhapatnam","Patna","Vadodara",
      "Ghaziabad","Ludhiana","Agra","Nashik","Meerut","Faridabad","Rajkot",
      "Coimbatore","Madurai","Noida","Gurugram","Gurgaon","Kochi","Ernakulam",
      "Mysuru","Mysore","Trichy","Salem","Chandigarh","Jodhpur","Bhubaneswar",
      "Jabalpur","Raipur","Kota","Gwalior","Vijayawada","Solapur","Hubli",
      "Mangalore","Tiruppur","Warangal","Navi Mumbai","Aurangabad","Amritsar",
      "Srinagar","Ranchi","Guwahati","Allahabad","Prayagraj",
      "Theni","Dindigul","Vellore","Tirunelveli","Thoothukudi","Erode","Sivakasi","Karur"
    ];
    const cityRe   = new RegExp(`\\b(${cities.join("|")})\\b`, "i");
    const cityMatch = raw.match(cityRe);
    if (cityMatch) fields.location = csTitleCase(cityMatch[1]);

    // PIN code fallback
    if (!fields.location) {
      const pinMatch = raw.match(/\b([A-Z][a-z]+(?: [A-Z][a-z]+)?)\s*[-–]\s*\d{6}\b/);
      if (pinMatch) fields.location = pinMatch[1];
    }

    // Name — heuristic: first alpha-only line that isn't a designation or company
    const skipRe = /pvt|ltd|inc|corp|group|enterprise|solution|service|technolog|consultant|associate|http|www|@|mobile|phone|tel|email|address|no\.|#|road|street|nagar|near|opp|plot|floor|building|gst|pan\b/i;
    for (const line of lines) {
      const c = line.replace(/[^a-zA-Z\s.]/g, "").trim();
      if (
        c.length >= 3 &&
        c.length <= 45 &&
        /^[A-Za-z\s.]+$/.test(c) &&
        !skipRe.test(c) &&
        c !== fields.designation &&
        c !== fields.business_name
      ) {
        fields.full_name = csTitleCase(csClean(c));
        break;
      }
    }

    return fields;
  }

  // ── Render extracted fields ───────────────────────────────────
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
                     min-width:82px;flex-shrink:0">${r.key}</span>
        <span style="font-size:13px;font-weight:500;word-break:break-all;
                     color:${r.val ? "#fff" : "rgba(255,255,255,.25)"};
                     ${r.val ? "" : "font-style:italic"}">
          ${r.val || "not detected"}
        </span>
      </div>`
    ).join("") + `
      <details style="margin-top:8px">
        <summary style="font-size:11px;color:rgba(255,255,255,.3);
                        cursor:pointer;user-select:none">Raw OCR text</summary>
        <pre style="font-size:10px;color:rgba(255,255,255,.3);white-space:pre-wrap;
                    word-break:break-all;margin-top:6px;padding:8px;
                    background:rgba(0,0,0,.3);border-radius:6px;
                    max-height:120px;overflow-y:auto">${csEscape(rawText)}</pre>
      </details>`;
  }

  // ── Apply fields into form ─────────────────────────────────────
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

    const nameEl = document.getElementById("full_name");
    if (nameEl) nameEl.scrollIntoView({ behavior: "smooth", block: "center" });

    csShowToast("✅ Form filled! Please review and submit.");
  };

  // ── Toast — reuses stall.html toast if available ──────────────
  function csShowToast(msg) {
    if (typeof toast === "function") {
      toast(msg, msg.startsWith("✅") ? "ok" : "err");
      return;
    }
    let t = document.getElementById("cs-toast-el");
    if (!t) {
      t = document.createElement("div");
      t.id = "cs-toast-el";
      t.style.cssText = `
        position:fixed;bottom:90px;left:50%;
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
    clearTimeout(t._timer);
    t._timer = setTimeout(() => {
      t.style.opacity = "0";
      t.style.transform = "translateX(-50%) translateY(20px)";
    }, 3000);
  }

  // ── Helpers ───────────────────────────────────────────────────
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

  // ── Close camera on Escape key ────────────────────────────────
  document.addEventListener("keydown", e => {
    if (e.key === "Escape") csCloseCamera();
  });

  // ── Close camera modal if clicking backdrop ───────────────────
  document.addEventListener("click", e => {
    const modal = document.getElementById("cs-camera-modal");
    if (modal && e.target === modal) csCloseCamera();
  });

})();