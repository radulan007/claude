/*
 * UTMB Live — Adam & Eva → Finish segment, ALL MEN (every category)
 * =================================================================
 * Same as utmb-live-segment.js but pulls the whole race ranking and keeps every
 * male runner (info.sex === "H") across all age categories, then ranks them by
 * their Adam & Eva → Finish segment and flags the record.
 * Paste in the DevTools Console on a UTMB Live results page for the race, e.g.
 *   https://live.utmb.world/ro/bucovinabyutmb/2026/ur100m
 */
(async function () {
  const ADAM_POINT = 182, FINISH_POINT = 200; // Bucovina UR100M 2026
  const SEX = "H"; // "H" = men, "F" = women
  const API = "https://utmblive-api.utmb.world";
  const m = location.pathname.match(/\/([a-z0-9]+)\/(\d{4})\/([a-z0-9]+)/i);
  const TENANT = m ? `${m[1]}_${m[2]}` : "bucovinabyutmb_2026";
  const RACE = (m && m[3]) || "ur100m";

  document.getElementById("utmb-seg-panel")?.remove();
  const esc = (s) => String(s == null ? "" : s).replace(/[&<>]/g, (c) => ({ "&":"&amp;","<":"&lt;",">":"&gt;" }[c]));
  const panel = document.createElement("div"); panel.id = "utmb-seg-panel";
  panel.style.cssText = "position:fixed;inset:3vh 3vw;z-index:2147483647;background:#0f1420;color:#e8edf6;border:1px solid #2a3446;border-radius:14px;box-shadow:0 20px 60px rgba(0,0,0,.6);display:flex;flex-direction:column;font:14px system-ui,sans-serif;overflow:hidden";
  panel.innerHTML = '<div style="padding:16px 18px;font-weight:700">UTMB · Adam &amp; Eva → Finish · Bărbați (toate categoriile) <span id="utmb-status" style="font-weight:400;color:#94a3b8">— pornesc…</span><button id="utmb-close" style="float:right;background:#243043;color:#e8edf6;border:1px solid #2a3446;border-radius:8px;padding:6px 12px;cursor:pointer">Închide ✕</button></div><div id="utmb-body" style="overflow:auto;padding:0 18px 18px"></div>';
  (document.body || document.documentElement).appendChild(panel);
  const statusEl = panel.querySelector("#utmb-status"), bodyEl = panel.querySelector("#utmb-body");
  panel.querySelector("#utmb-close").onclick = () => panel.remove();
  const setStatus = (msg, c) => { statusEl.textContent = " — " + msg; if (c) statusEl.style.color = c; };
  const secs = (t) => { if (t == null || t === "") return null; const p = String(t).split(":").map(Number); if (p.some(isNaN)) return null; return p.length === 3 ? p[0]*3600+p[1]*60+p[2] : p.length === 2 ? p[0]*60+p[1] : p[0]; };
  const fmt = (s) => { if (s == null || isNaN(s)) return "—"; const neg = s<0; s = Math.abs(Math.round(s)); const h=Math.floor(s/3600), mm=Math.floor(s%3600/60), ss=s%60; return (neg?"-":"")+h+":"+String(mm).padStart(2,"0")+":"+String(ss).padStart(2,"0"); };
  const j = async (u) => { const r = await fetch(u, { headers: { accept:"application/json", "X-Tenant":TENANT } }); if (!r.ok) throw new Error("HTTP "+r.status); return r.json(); };

  try {
    setStatus("aduc lista completă de alergători…");
    const all = []; let page = 1, total = Infinity;
    while (all.length < total && page <= 200) {
      const d = await j(`${API}/races/${RACE}/progressive?type=FINAL_RANKING&page=${page}&limit=10`);
      total = d.totalRunner ?? all.length; (d.runners || []).forEach((r) => all.push(r));
      if (!d.runners || d.runners.length === 0) break; page++;
    }
    const men = all.filter((r) => String(r.info?.sex || "").toUpperCase() === SEX);
    if (!men.length) { setStatus("0 bărbați găsiți (din "+all.length+" alergători, cursă="+RACE+")", "#f59e0b"); return; }
    setStatus(`${men.length} bărbați din ${all.length} · aduc trecerile… 0/${men.length}`);

    const rows = []; const cumAt = (d, pid) => { const p = (d?.detail?.passings || []).find((x) => x.pointId === pid); return p ? secs(p.cumulatedTime) : null; };
    let done = 0;
    async function worker(list) { for (const r of list) { try {
      const rd = await j(`${API}/runners/${r.bib}?locale=ro`);
      const a = cumAt(rd, ADAM_POINT), f = cumAt(rd, FINISH_POINT), seg = (a!=null&&f!=null&&f>a) ? f-a : null;
      rows.push({ bib: rd.resume?.info?.index ?? r.bib, name: rd.resume?.info?.fullname || r.info?.fullname || ("#"+r.bib), cat: rd.resume?.info?.category || r.info?.category || "", rank: rd.resume?.ranking?.sex || r.ranking?.sex || "", adam:a, fin:f, seg });
    } catch (e) { console.warn("eroare", r.bib, e.message); } setStatus(`${men.length} bărbați · aduc trecerile… ${++done}/${men.length}`); } }
    const N = 5, ch = Array.from({length:N}, () => []); men.forEach((r,i) => ch[i%N].push(r)); await Promise.all(ch.map(worker));

    const valid = rows.filter((r) => r.seg != null); const best = valid.length ? Math.min(...valid.map((r)=>r.seg)) : null;
    rows.sort((a,b) => (a.seg==null?1e12:a.seg) - (b.seg==null?1e12:b.seg));
    rows.forEach((r) => { r.delta = (r.seg!=null&&best!=null) ? r.seg-best : null; r.record = r.seg!=null && r.seg===best; });
    statusEl.innerHTML = ` — gata ✓ · ${esc(RACE)} · bărbați · ${valid.length}/${rows.length} valizi · record <b>${fmt(best)}</b>`;
    const cell = (v, x) => `<td style="padding:7px 10px;border-bottom:1px solid #2a3446;${x||""}">${v}</td>`;
    const tbl = rows.map((r,i) => `<tr style="background:${r.record?"rgba(34,197,94,.14)":"transparent"}">${cell(r.seg!=null?i+1:"—")}${cell(r.record?'<span style="background:#22c55e;color:#03140a;font-weight:700;font-size:11px;padding:2px 7px;border-radius:999px">RECORD</span>':"")}${cell(esc(r.rank))}${cell(esc(r.bib))}${cell(esc(r.name))}${cell(esc(r.cat))}${cell(fmt(r.adam),"font-variant-numeric:tabular-nums")}${cell(fmt(r.fin),"font-variant-numeric:tabular-nums")}${cell(fmt(r.seg),"font-variant-numeric:tabular-nums;font-weight:700")}${cell(r.delta==null?"—":r.delta===0?"±0":"+"+fmt(r.delta),"color:"+(r.delta>0?"#94a3b8":"#22c55e")+";font-variant-numeric:tabular-nums")}</tr>`).join("");
    bodyEl.innerHTML = `<div style="margin:6px 0 12px"><button id="utmb-csv" style="background:#38bdf8;color:#04121c;font-weight:600;border:none;border-radius:8px;padding:8px 14px;cursor:pointer">Export CSV</button></div><table style="border-collapse:collapse;width:100%;white-space:nowrap"><thead><tr style="position:sticky;top:0;background:#1d2637;color:#94a3b8;font-size:12px;text-transform:uppercase"><th style="padding:9px 10px;text-align:left">#</th><th></th><th style="padding:9px 10px;text-align:left">Clas. M</th><th style="padding:9px 10px;text-align:left">Dorsal</th><th style="padding:9px 10px;text-align:left">Alergător</th><th style="padding:9px 10px;text-align:left">Cat.</th><th style="padding:9px 10px;text-align:left">Adam &amp; Eva</th><th style="padding:9px 10px;text-align:left">Finish</th><th style="padding:9px 10px;text-align:left">Segment</th><th style="padding:9px 10px;text-align:left">vs record</th></tr></thead><tbody>${tbl}</tbody></table>`;
    bodyEl.querySelector("#utmb-csv").onclick = () => { const head = ["seg_rank","record","clas_masc","dorsal","nume","categorie","adam_eva","finish","segment","segment_sec","vs_record"]; const lines = [head.join(",")].concat(rows.map((r,i) => [r.seg!=null?i+1:"", r.record?"DA":"", r.rank, r.bib, '"'+String(r.name).replace(/"/g,'""')+'"', r.cat, fmt(r.adam), fmt(r.fin), fmt(r.seg), r.seg==null?"":Math.round(r.seg), r.delta==null?"":(r.delta===0?"0":"+"+fmt(r.delta))].join(","))); const a = document.createElement("a"); a.href = URL.createObjectURL(new Blob([lines.join("\n")],{type:"text/csv"})); a.download = `utmb-segment-${RACE}-barbati.csv`; a.click(); };
  } catch (e) { setStatus("EROARE: " + e.message, "#ef4444"); bodyEl.innerHTML = '<pre style="color:#ef4444;white-space:pre-wrap">'+esc(e.stack||e.message)+'</pre>'; console.error(e); }
})();
