# UTMB Segment Analyzer — Adam & Eva → Finish

A single-file, offline web app that reads a **UTMB Live** results table, computes each runner's
time on the **Adam & Eva → Finish** segment, and **flags the fastest (record) time** on that
segment. It's built for analysing results like
`https://live.utmb.world/bucovinabyutmb/2026/ur100m?category=20-34M`.

Everything runs locally in your browser — no server, no build step, no data leaves your machine.

## How to use

1. Open **`index.html`** in any modern browser (double-click it).
2. Load the results with whichever method works for you (see below).
3. In **Choose the segment**, confirm the two checkpoints (it auto-picks *Adam & Eva* as the start
   and *Finish* as the end) — results appear instantly.
4. Read the table: it's sorted by segment time, the **RECORD** row is highlighted, and the
   **vs ref** column shows how far each runner was behind the reference. Export to CSV if you want.

## Getting the data in (3 ways)

The results page loads its data with JavaScript and sits behind bot-protection, so a plain download
of the URL usually won't contain the table. In order of reliability:

### A) Browser snippet — always works ✅
1. Open the results page in your own browser (apply the category filter you want).
2. Open DevTools (`F12`) → **Console**.
3. Paste the snippet from the app's **Browser snippet** tab (or from
   [`grab-utmb-data.js`](./grab-utmb-data.js)) and press **Enter**.
4. It downloads a `utmb-results-*.json` file. **Drop that file** into the app's *Paste / drop* tab.
5. If the results span several pages (`?page=1`, `?page=2`, …), run it once per page and drop **all**
   the files at once — they're merged by bib number.

> The snippet runs inside the page itself, so there's no CORS problem and no bot-blocking — it just
> reads what your browser already loaded.

### B) Paste / drop
Drop a **saved page** (`Ctrl+S` → `.html`), a **CSV**, or paste a **copied results table** straight
into the box. The parser auto-detects the rank / bib / name / category columns and treats the rest as
checkpoints; if a guess is off, just re-pick the start/end checkpoint from the dropdowns.

### C) Fetch a URL
The app will *try* a direct fetch of the URL, but this typically fails on CORS or bot-protection.
If it does, it tells you to use method A.

## The flag rule

The default is **"fastest segment time"**: the app computes `Finish − Adam&Eva` for every runner,
finds the single fastest, and flags it as the **RECORD**. Two other reference modes are available in
the *Flag rule* dropdown at any time:

| Mode | Reference | What gets flagged |
|------|-----------|-------------------|
| **Fastest segment time** *(default)* | the fastest segment in the field | the record holder(s) |
| **Category winner's segment** | the segment time of race rank #1 | anyone who ran the segment *faster* than the winner |
| **A runner I pick** | any runner you choose | anyone faster than that runner |

*Tie tolerance* lets you treat times within N seconds as tied (useful for rounding).

## Notes on time parsing

- Splits are assumed to be **elapsed time from the start** (e.g. `13:45:22`), which is how UTMB Live
  shows them, so `segment = Finish − Adam&Eva`. If your data uses **clock time of day**, switch the
  *"Split values are…"* dropdown to *Time of day* (it handles a midnight crossing).
- Formats understood: `H:MM:SS`, `MM:SS`, `1d 12:34:56` / `J1 12:34:56`, and ISO datetimes.
- Runners missing either split (DNF at Adam & Eva, still on course, etc.) show `—` and are excluded
  from the fastest/flagging calculation.

## Why isn't the data fetched automatically?

This tool was built in an environment whose network policy blocks `live.utmb.world`, so it can't pull
the live data itself. Your own browser can reach the site fine — that's exactly what the **Browser
snippet** is for. It makes the tool work regardless of network policy, CORS, or the site's internal
API changing.

## Recommended for UTMB Live: the all-in-one snippet

`utmb-live-segment.js` is the easiest path for real UTMB Live data. Open the results page for
your category (e.g. `https://live.utmb.world/ro/bucovinabyutmb/2026/ur100m?category=20-34M`),
open the Console (`F12`), paste the whole file, and press Enter. It:

1. reads the race + category from the URL,
2. pulls every runner in that category from the official API (`https://utmblive-api.utmb.world`),
3. computes each runner's **Adam & Eva → Finish** segment = `cumulatedTime(Finish) − cumulatedTime(Adam & Eva)`,
4. ranks them fastest-first, flags the **record**, and renders a table on the page (with CSV export).

No CORS problem, because it runs in the page's own origin against the same API the site uses.

### How the checkpoints were identified

The API exposes numeric `pointId`s, not names. For **Bucovina UR100M 2026** they were verified
against the course profile (via cumulative distance = segment `speed` × segment `time`):

| pointId | km | checkpoint |
|--------:|---:|------------|
| 166 | 95  | Transrarau |
| **182** | **105** | **Adam & Eva** |
| 194 | 111 | P. Mesteacan |
| 196 | 112 | Runc |
| **200** | **115** | **Finish** |

So the snippet uses `ADAM_POINT = 182` and `FINISH_POINT = 200` (constants at the top — change
them for a different race).

### Useful API endpoints (utmblive-api.utmb.world)

> **Every request needs an `X-Tenant` header** with the event slug (e.g. `X-Tenant: bucovinabyutmb`),
> otherwise the API replies `404 {"message":"X-Tenant not provided"}`. The tenant is the path segment
> before the year in the URL (`/ro/**bucovinabyutmb**/2026/…`).

- `GET /races/{raceId}/progressive?type=FINAL_RANKING&category={cat}&page={n}&limit=10` — ranking list (has `totalRunner`, `runners[].bib`).
- `GET /runners/{bib}?locale=ro` — one runner, incl. `detail.passings[]` with `pointId`, `time`, `cumulatedTime`, `speed`.
- `GET /races/{raceId}` — race config incl. `distribution.distribution[]` (ordered `pointId`s).
- `GET /event-context` — event + race list.

## Files

- `utmb-live-segment.js` — **all-in-one** UTMB Live snippet (fetch + compute + table). Recommended.
- `index.html` — the general offline analyzer (open this) for pasted / dropped data of any race.
- `grab-utmb-data.js` — a generic browser-console page-data exporter (used by the app's *Browser snippet* tab).
