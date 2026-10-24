# Unelte pentru televizoarele din casă

| TV | Sistem | Ce putem face |
|---|---|---|
| Sony, Philips, TCL | Android TV / Google TV | ADB în rețea: animații mai scurte, aplicații promoționale dezactivate, launcher mai ușor |
| 2 × Samsung | Tizen | Fără ADB; doar setări din meniu (mai jos) |

## 1. Pregătire (o singură dată, pe calculator)

1. Instalează **Python 3**: https://www.python.org/downloads/ (pe Windows bifează „Add to PATH”).
2. Instalează **Android SDK Platform-Tools** (conține `adb`):
   https://developer.android.com/tools/releases/platform-tools
   Dezarhivează și adaugă folderul în PATH (sau rulează scripturile din acel folder).

## 2. Găsește televizoarele

Pornește toate televizoarele, apoi:

```
python discover.py
```

Afișează IP-ul, marca și modelul fiecăruia. Notează IP-urile pentru Sony, Philips și TCL.

## 3. Activează „Network debugging” pe Sony, Philips, TCL

1. Settings → Device Preferences (sau System) → About → apasă de **7 ori** pe **Build** până apare „You are now a developer”.
2. Settings → Device Preferences → **Developer options** → activează **USB debugging** și, dacă apare, **Network debugging / ADB over network**.
   - Pe unele TCL opțiunea e în Settings → System → Developer options.
3. La prima conectare, televizorul afișează „Allow USB debugging?” → bifează „Always allow” → **OK**.

## 4. Optimizează (pe fiecare TV Android)

```
python android_tv_optimize.py 192.168.1.50            # mod test: arată ce ar face
python android_tv_optimize.py 192.168.1.50 --apply    # aplică
python android_tv_optimize.py 192.168.1.50 --restore  # anulează tot
```

- Animațiile scad la 0.5× (cu `--no-animations` se opresc complet).
- Scriptul îți arată aplicațiile preinstalate care par promoții sau extra, iar tu alegi ce dezactivezi.
  **Nu dezactiva ce nu recunoști.** Nimic nu se șterge, iar `--restore` reactivează tot.
- Repornește televizorul după aplicare.

**Opțional:** instalează din Google Play un launcher ușor, de exemplu **Projectivy Launcher** sau
**FLauncher**, și setează-l ca ecran principal. Ecranul de start nu va mai încărca rânduri de recomandări și reclame.

La final dezactivează din nou **Network debugging** pe fiecare TV, din motive de securitate.

## 5. Samsung (Tizen), din meniu

- Settings → General → **Smart Features** → oprește „Autorun Smart Hub” și „Autorun Last App”.
- Settings → Support → Terms & Privacy → dezactivează **Interest-Based Advertisements** și **Viewing Information Services**.
- Settings → General → **Power and Energy Saving** → activează **Quick Start / Instant On** (pornire rapidă).
- Settings → Support → Device Care → **Start Device Care** (curăță memoria). Șterge aplicațiile nefolosite din Apps → ⚙.
- Actualizează software-ul: Settings → Support → Software Update.
