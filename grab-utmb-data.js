/*
 * grab-utmb-data.js  —  UTMB Live results exporter
 * ---------------------------------------------------
 * Run this in your browser's DevTools Console *while you are on the
 * live.utmb.world results page you want to analyse* (the page that shows
 * the checkpoint splits, e.g. the ur100m results with the category filter
 * you care about). It captures everything the page knows and downloads a
 * `utmb-results-*.json` file. Then drag that file into the analyzer app.
 *
 * It runs in the page's own context, so there is no CORS problem and no
 * bot-protection to fight — it just reads what your browser already loaded.
 *
 * If the results are split across several pages (?page=1, ?page=2 ...),
 * run it once per page and drop all the downloaded files into the app;
 * they are merged by bib number automatically.
 */
(function () {
  const out = {
    source: "grab-utmb-data.js",
    url: location.href,
    title: document.title,
    extractedAt: new Date().toISOString(),
    nextData: null,       // Next.js pages-router hydration payload
    jsonScripts: [],      // any <script type="application/json">
    nextFlight: [],       // Next.js app-router streamed RSC payload
    tables: [],           // classic <table> elements
    gridRows: [],         // ARIA role="row" grids (React tables often use these)
  };

  // 1) Next.js pages-router data
  try {
    if (window.__NEXT_DATA__) out.nextData = window.__NEXT_DATA__;
  } catch (e) {}

  // 2) Every embedded JSON script block
  try {
    document.querySelectorAll('script[type="application/json"]').forEach((s) => {
      try { out.jsonScripts.push(JSON.parse(s.textContent)); }
      catch (_) { out.jsonScripts.push({ raw: s.textContent }); }
    });
  } catch (e) {}

  // 3) Next.js app-router streamed flight data (self.__next_f)
  try {
    if (Array.isArray(self.__next_f)) {
      out.nextFlight = self.__next_f.map((chunk) =>
        Array.isArray(chunk) ? chunk[chunk.length - 1] : chunk
      );
    }
  } catch (e) {}

  // 4) Classic HTML tables
  try {
    document.querySelectorAll("table").forEach((tbl) => {
      const headers = [...tbl.querySelectorAll("thead th, thead td")].map((c) =>
        c.innerText.trim()
      );
      const rows = [...tbl.querySelectorAll("tbody tr")].map((tr) =>
        [...tr.querySelectorAll("td, th")].map((c) => c.innerText.trim())
      );
      if (rows.length) out.tables.push({ headers, rows });
    });
  } catch (e) {}

  // 5) ARIA grids (role="table"/"grid" built from divs)
  try {
    document.querySelectorAll('[role="table"], [role="grid"]').forEach((grid) => {
      const rows = [...grid.querySelectorAll('[role="row"]')].map((r) =>
        [...r.querySelectorAll('[role="cell"], [role="columnheader"], [role="gridcell"]')].map(
          (c) => c.innerText.trim()
        )
      );
      if (rows.length) out.gridRows.push(rows);
    });
  } catch (e) {}

  const json = JSON.stringify(out);
  const size = (json.length / 1024).toFixed(0);
  const blob = new Blob([json], { type: "application/json" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = "utmb-results-" + Date.now() + ".json";
  document.body.appendChild(a);
  a.click();
  a.remove();

  console.log(
    "%cUTMB export ready (" + size + " KB). Drop the downloaded file into the analyzer.",
    "color:#0a7; font-weight:bold"
  );
  console.log("Captured:", {
    nextData: !!out.nextData,
    jsonScripts: out.jsonScripts.length,
    nextFlightChunks: out.nextFlight.length,
    tables: out.tables.length,
    grids: out.gridRows.length,
  });
})();
