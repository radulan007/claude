# Context proiect — landing page campanie Varta

Proiect: landing page campanie promoțională Varta (RO).

Mecanica: cumperi Varta >= 100 lei -> încarci bonul -> la 5.000 bonuri validate se trage la sorți -> premiu mașină Chery.

Direcție vizuală: „Varta oficial, energic". Semnătură: baterie-contor care se încarcă spre 5.000.

Constrângere de livrare: cod portabil în WordPress/Avada (CSS inline-abil, un singur fișier, fără build, fără framework, doar Google Fonts ca dependență externă).

## Delimitarea scopului
Claude Code se folosește **doar pentru partea vizuală / front-end** (HTML/CSS/JS de prezentare).
Rămân pe WordPress: formularul real (Gravity Forms), object storage poze, deduplicarea bonurilor,
regulament notarial, GDPR, impozit. Aici sunt doar mockup-uri vizuale pentru acele zone.

## Convenții de cod (pentru portabilitate Avada)
- Tot codul e domeniat sub wrapper-ul `.varta-lp` — nu atinge selectori globali.
- Design tokens ca variabile CSS pe `.varta-lp` (culori, fonturi, spațieri).
- Stiluri grupate pe secțiuni cu bannere `/* === */` ca să se taie ușor în Avada Code Block-uri.
- Fără localStorage/sessionStorage.
- Accesibilitate obligatorie: contrast >= 4.5:1, focus vizibil, ținte tap >= 44px,
  `prefers-reduced-motion`, mobile-first, fără scroll orizontal.

## Fișiere
- `varta-campanie-landing.html` — landing page-ul (single-file, self-contained).
- `README.md` — design tokens + lista de placeholders rămase.

## Notă despre skill-ul ui-ux-pro-max
Skill-ul a fost instalat complet (v2.11.0, din `nextlevelbuilder/ui-ux-pro-max-skill`), cu
`scripts/search.py` + baza de date `.csv` + `references/`. Căutarea `--design-system` a rulat
și a **confirmat** direcția „Varta oficial, energic" (dark high-contrast + accent roșu; pattern
Hero+Features+CTA cu CTA sticky). Stilul „Liquid Glass" sugerat de BM25 NU a fost adoptat ca stil
principal (perf. slabă + risc de contrast, potrivit pentru lux/SaaS, nu pentru promo de masă pe mobil).
