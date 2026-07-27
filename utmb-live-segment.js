/*
 * UTMB Live — Adam & Eva → Finish segment analyzer (all-in-one)
 * =============================================================
 * Paste this into the browser DevTools Console while on a UTMB Live results
 * page, e.g.:
 *   https://live.utmb.world/ro/bucovinabyutmb/2026/ur100m?category=20-34M
 *
 * It reads the race + category from the URL, pulls every runner in that
 * category from the official API (https://utmblive-api.utmb.world), computes
 * each runner's time on the Adam & Eva → Finish segment, ranks them fastest
 * first, flags the record, and shows a table right on the page (+ CSV export).
 *
 * Nothing is uploaded — it runs entirely in your browser against the same
 * API the site itself uses.
 */
(async function () {
  // ---- Checkpoint pointIds (Bucovina UR100M 2026, verified against the course profile) ----
  // Adam & Eva = 182 (km 105), Finish = 200 (km 115). Change these for another race.
  const ADAM_POINT = 182;
  const FINISH_POINT = 200;

  const API = "https://utmblive-api.utmb.world";
  const m = location.pathname.match(/\/([a-z0-9]+)\/(\d{4})\/([a-z0-9]+)/i);
  const RACE = (m && m[3]) || "ur100m";
  const CAT = new URLSearchParams(location.search).get("category") || "20-34M";

  const secs = (t) => {
    if (t == null || t === "") return null;
    const p = String(t).split(":").map(Number);
    if (p.some(isNaN)) return null;
    return p.length === 3 ? p[0]*3600 + p[1]*60 + p[2] : p.length === 2 ? p[0]*60 + p[1] : p[0];
  };
  const fmt = (s) => {
    if (s == null || isNaN(s)) return "—";
    const neg = s < 0; s = Math.abs(Math.round(s));
    const h = Math.floor(s/3600), mm = Math.floor(s%3600/60), ss = s%60;
    return (neg?"-":"") + h + ":" + String(mm).padStart(2,"0") + ":" + String(ss).padStart(2,"0");
  };
  const j = (u) => fetch(u, { headers: { accept: "application/json" } }).then((r) => r.json());

  console.log("%cUTMB segment analyzer — cursa " + RACE + ", categoria " + CAT, "color:#38bdf8;font-weight:bold;font-size:14px");

  // 1) all runners in the category
  const runners = [];
  let page = 1, total = Infinity;
  while (runners.length < total && page <= 100) {
    const d = await j(`${API}/races/${RACE}/progressive?type=FINAL_RANKING&category=${encodeURIComponent(CAT)}&page=${page}&limit=10`);
    total = d.totalRunner ?? runners.length;
    (d.runners || []).forEach((r) => runners.push(r));
    if (!d.runners || d.runners.length === 0) break;
    page++;
  }
  console.log(`Am găsit ${runners.length} alergători. Aduc trecerile fiecăruia…`);

  // 2) each runner's passings (concurrency-limited)
  const rows = [];
  const cumAt = (detail, pid) => {
    const p = (detail?.detail?.passings || []).find((x) => x.pointId === pid);
    return p ? secs(p.cumulatedTime) : null;
  };
  let done = 0;
  async function worker(list) {
    for (const r of list) {
      try {
        const rd = await j(`${API}/runners/${r.bib}?locale=ro`);
        const a = cumAt(rd, ADAM_POINT), f = cumAt(rd, FINISH_POINT);
        const seg = (a != null && f != null && f > a) ? f - a : null;
        rows.push({
          bib: rd.resume?.info?.index ?? r.bib,
          id: r.bib,
          name: rd.resume?.info?.fullname || r.info?.fullname || ("#" + r.bib),
          cat: rd.resume?.info?.category || CAT,
          rank: rd.resume?.ranking?.category || r.ranking?.category || "",
          finishTime: rd.resume?.raceTime || r.raceTime || "",
          adam: a, fin: f, seg,
        });
      } catch (e) { console.warn("eroare la", r.bib, e.message); }
      if (++done % 5 === 0 || done === runners.length) console.log(`  ${done}/${runners.length}`);
    }
  }
  const N = 5, chunks = Array.from({ length: N }, () => []);
  runners.forEach((r, i) => chunks[i % N].push(r));
  await Promise.all(chunks.map(worker));

  // 3) rank + flag
  const valid = rows.filter((r) => r.seg != null);
  const best = valid.length ? Math.min(...valid.map((r) => r.seg)) : null;
  rows.sort((a, b) => (a.seg == null ? 1e12 : a.seg) - (b.seg == null ? 1e12 : b.seg));
  rows.forEach((r) => { r.delta = (r.seg != null && best != null) ? r.seg - best : null; r.record = r.seg != null && r.seg === best; });

  // 4) render overlay
  document.getElementById("utmb-seg-panel")?.remove();
  const esc = (s) => String(s == null ? "" : s).replace(/[&<>]/g, (c) => ({ "&":"&amp;","<":"&lt;",">":"&gt;" }[c]));
  const panel = document.createElement("div");
  panel.id = "utmb-seg-panel";
  panel.style.cssText = "position:fixed;inset:3vh 3vw;z-index:999999;background:#0f1420;color:#e8edf6;border:1px solid #2a3446;border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.6);display:flex;flex-direction:column;font:14px system-ui,Segoe UI,Roboto,sans-serif;overflow:hidden";
  const tbl = rows.map((r, i) => {
    const flag = r.record ? '<span style="background:#22c55e;color:#03140a;font-weight:700;font-size:11px;padding:2px 7px;border-radius:999px">RECORD</span>' : "";
    return `<tr style="background:${r.record ? "rgba(34,197,94,.14)" : "transparent"}">
      <td style="padding:7px 10px;border-bottom:1px solid #2a3446">${r.seg!=null?i+1:"—"}</td>
      <td style="padding:7px 10px;border-bottom:1px solid #2a3446">${flag}</td>
      <td style="padding:7px 10px;border-bottom:1px solid #2a3446">${esc(r.rank)}</td>
      <td style="padding:7px 10px;border-bottom:1px solid #2a3446">${esc(r.bib)}</td>
      <td style="padding:7px 10px;border-bottom:1px solid #2a3446">${esc(r.name)}</td>
      <td style="padding:7px 10px;border-bottom:1px solid #2a3446;font-variant-numeric:tabular-nums">${fmt(r.adam)}</td>
      <td style="padding:7px 10px;border-bottom:1px solid #2a3446;font-variant-numeric:tabular-nums">${fmt(r.fin)}</td>
      <td style="padding:7px 10px;border-bottom:1px solid #2a3446;font-variant-numeric:tabular-nums;font-weight:700">${fmt(r.seg)}</td>
      <td style="padding:7px 10px;border-bottom:1px solid #2a3446;color:${r.delta>0?"#94a3b8":"#22c55e"};font-variant-numeric:tabular-nums">${r.delta==null?"—":r.delta===0?"±0":"+"+fmt(r.delta)}</td>
    </tr>`;
  }).join("");
  panel.innerHTML = `
    <div style="padding:14px 18px;border-bottom:1px solid #2a3446;display:flex;align-items:center;gap:12px">
      <div style="font-weight:700;font-size:16px">Segment <span style="color:#38bdf8">Adam &amp; Eva → Finish</span> · ${esc(RACE)} · ${esc(CAT)}</div>
      <div style="color:#94a3b8;font-size:13px">${valid.length}/${rows.length} cu segment valid · record <b style="color:#22c55e">${fmt(best)}</b></div>
      <div style="margin-left:auto;display:flex;gap:8px">
        <button id="utmb-csv" style="background:#243043;color:#e8edf6;border:1px solid #2a3446;border-radius:8px;padding:7px 12px;cursor:pointer">Export CSV</button>
        <button id="utmb-close" style="background:#243043;color:#e8edf6;border:1px solid #2a3446;border-radius:8px;padding:7px 12px;cursor:pointer">Închide ✕</button>
      </div>
    </div>
    <div style="overflow:auto">
      <table style="border-collapse:collapse;width:100%;white-space:nowrap">
        <thead><tr style="position:sticky;top:0;background:#1d2637;color:#94a3b8;font-size:12px;text-transform:uppercase;letter-spacing:.04em">
          <th style="padding:9px 10px;text-align:left">#</th><th style="padding:9px 10px;text-align:left"></th>
          <th style="padding:9px 10px;text-align:left">Clas. cat.</th><th style="padding:9px 10px;text-align:left">Dorsal</th>
          <th style="padding:9px 10px;text-align:left">Alergător</th><th style="padding:9px 10px;text-align:left">Adam &amp; Eva</th>
          <th style="padding:9px 10px;text-align:left">Finish</th><th style="padding:9px 10px;text-align:left">Segment</th>
          <th style="padding:9px 10px;text-align:left">vs record</th>
        </tr></thead>
        <tbody>${tbl}</tbody>
      </table>
    </div>`;
  document.body.appendChild(panel);
  document.getElementById("utmb-close").onclick = () => panel.remove();
  document.getElementById("utmb-csv").onclick = () => {
    const head = ["seg_rank","record","cat_rank","dorsal","nume","adam_eva_cumulat","finish_cumulat","segment","segment_secunde","vs_record"];
    const lines = [head.join(",")].concat(rows.map((r, i) => [
      r.seg!=null?i+1:"", r.record?"DA":"", r.rank, r.bib, '"'+String(r.name).replace(/"/g,'""')+'"',
      fmt(r.adam), fmt(r.fin), fmt(r.seg), r.seg==null?"":Math.round(r.seg), r.delta==null?"":(r.delta===0?"0":"+"+fmt(r.delta)),
    ].join(",")));
    const a = document.createElement("a");
    a.href = URL.createObjectURL(new Blob([lines.join("\n")], { type: "text/csv" }));
    a.download = `utmb-segment-${RACE}-${CAT}.csv`; a.click();
  };
  console.log("%cGata ✓ Tabelul e afișat pe pagină. Cel mai rapid pe segment e marcat RECORD.", "color:#22c55e;font-weight:bold;font-size:14px");
})();
