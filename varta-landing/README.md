# Varta — landing page campanie promoțională

Landing page single-file pentru campania „Cumperi Varta, poți câștiga o mașină Chery".
Un singur obiectiv: să determine oamenii să **încarce bonul**.

- **Fișier livrabil:** [`varta-campanie-landing.html`](./varta-campanie-landing.html) — self-contained, fără build, fără framework. Singura dependență externă: Google Fonts.
- **Portabilitate Avada:** tot codul e domeniat sub wrapper-ul `.varta-lp` (nu intră în conflict cu stilurile globale ale temei), iar CSS-ul e grupat pe secțiuni cu bannere `/* === */` ca să poată fi tăiat în Avada Code Block-uri.
- **Fără** localStorage/sessionStorage.

## Secțiuni
Header · Hero (mașină + CTA „Încarcă bonul") · **Baterie-contor** (elementul-semnătură, se încarcă spre 5.000) · Cum participi (3 pași) · Zona de upload (mockup Gravity Forms) · Premii · FAQ · Footer legal · CTA sticky pe mobil.

## Cum se testează local
Deschide direct `varta-campanie-landing.html` în browser (dublu-click) — nu are nevoie de server.

---

## 1) Design tokens folosiți

### Culori (definite pe `.varta-lp`)
| Token | Valoare | Rol |
|---|---|---|
| `--carbon` | `#14161A` | Fundal închis principal (carbon) |
| `--carbon-2` | `#1C1F25` | Suprafață închisă, un pas mai deschis |
| `--carbon-3` | `#262A32` | Borduri / carduri pe fundal închis |
| `--varta-red` | `#E4032E` | **PLACEHOLDER** — roșul oficial Varta (CTA, accente) |
| `--varta-red-dark` | `#A80022` | Roșu închis (hover / accente) |
| `--charge` | `#FFD21E` | Galben electric — accent „încărcare" |
| `--silver` | `#C7CDD4` | Text secundar pe fundal închis |
| `--surface` | `#F4F5F7` | Suprafață deschisă (secțiunea de upload) |
| `--ink` | `#14161A` | Text pe suprafață deschisă |
| `--white` | `#FFFFFF` | Titluri / text principal pe închis |

### Tipografie
| Token | Font | Rol |
|---|---|---|
| `--font-display` | **Saira** (500–800) | Titluri, CTA — senzație tehnic/sportiv |
| `--font-mono` | **Space Mono** (400/700) | Cifre, date, contor — senzație de instrument de bord |
| `--font-body` | **Inter** (400–700) | Body text |

### Spațieri (scală marketing, spațios)
`--space-1: 8px` · `--space-2: 16px` · `--space-3: 24px` · `--space-4: 32px` · `--space-5: 48px` · `--space-6: 64px` · `--space-7: 96px`

### Raze & layout
`--r-sm: 10px` · `--r-md: 16px` · `--r-lg: 24px` · `--r-pill: 999px` · `--maxw: 1140px` · `--shadow: 0 20px 50px rgba(0,0,0,.45)`

---

## 2) Placeholders rămase de completat
- **Logo Varta** — acum e text stilizat (`.vlp-logo`), marcat vizibil „logo placeholder".
- **Roșul oficial** — `--varta-red: #E4032E` e placeholder; de înlocuit cu roșul oficial Varta.
- **Imaginea mașinii Chery** — două zone placeholder (hero + secțiunea Premii).
- **Premii secundare** — card placeholder în secțiunea Premii (dacă se includ în regulament).
- **Copy legal** — perioadă campanie, scenariul „dacă nu se ating 5.000", impozit/condiții, date operator (footer + FAQ).
- **GDPR / regulament** — linkuri placeholder în footer; bifele de acord intră în formularul real.
- **Zona de formular** — mockup vizual unde se integrează **Gravity Forms** (WordPress).
- **Datele contorului** — bateria folosește o valoare demo (`DEMO_COUNT` în JS); de legat la numărul real de bonuri validate din platformă.
- **Perioada campaniei** — apare ca „(placeholder: perioadă)" în lista de condiții și în FAQ.

---

## 3) Accesibilitate & performanță (aplicate)
- Contrast text pe fundal închis: alb / silver `#C7CDD4` pe carbon `#14161A` (≥ 4.5:1); accente pe text mare bold.
- Focus vizibil la tastatură (`:focus-visible` cu contur galben), skip-link „Sari la conținut".
- Ținte tap ≥ 44px pe toate butoanele/CTA; formular cu label-uri vizibile.
- Mobile-first, fără scroll orizontal; imagini cu `max-width:100%`.
- FAQ pe `<details>/<summary>` — accesibil la tastatură fără JS.
- `prefers-reduced-motion`: oprește animațiile; bateria afișează direct nivelul final.
- Iconițe SVG inline (fără emoji), conform regulilor skill-ului.

## 4) Notă despre skill-ul `ui-ux-pro-max`
În mediul curent skill-ul avea **doar `SKILL.md`** — lipseau `scripts/search.py` și baza de date (`.csv`, `references/`), deci **căutarea în baza de design nu a putut rula**. S-au folosit recomandările implicite (tabelul de priorități din `SKILL.md` + direcția vizuală deja stabilită), **nu** baza de date. Pentru a folosi baza de date, reclonează skill-ul complet.
