# AGENTS.md

Hinweise für Agenten (Claude Code, GitHub Copilot, …), die in diesem Repository
arbeiten. Bitte vor dem Bearbeiten von 3D-Modellen oder Exporten lesen.

## Projektüberblick

`scad-volt` enthält parametrische 3D-Modelle (OpenSCAD), die zu druckbaren
Multi-Material-`.3mf`-Dateien exportiert werden.

```
.
├── resources/                       # geteilte Assets (SVG-Logos etc.)
│   ├── Logo_of_Volt.svg
│   └── star-svgrepo-com.svg
└── schnalle/                        # Modell "EU-Schnalle backplate"
    ├── EU-Schnalle-backplate.scad   # parametrische Quelle
    ├── export-EU-Schnalle-backplate.sh
    └── *.3mf                        # exportierte Ergebnisse (eingecheckt)
```

## Voraussetzungen

- `openscad` (getestet mit 2021.01) — muss im `PATH` liegen
- `python3` (getestet mit 3.12) — baut das `.3mf` aus den STL-Teilen zusammen

Das Export-Skript prüft beides und bricht mit klarer Meldung ab, wenn etwas fehlt.

## Modell exportieren

Aus dem jeweiligen Modellordner heraus ausführen:

```bash
cd schnalle
./export-EU-Schnalle-backplate.sh
```

Ablauf des Skripts:

1. Rendert mit OpenSCAD einzelne STL-Teile (Basislagen, Stern-Streifen der
   Lage 06, sowie 12 Einzelsterne) über die `-D part="…"`-Parameter des `.scad`.
2. Ein eingebettetes Python-Skript liest die ASCII-STLs und schreibt daraus ein
   benanntes Multi-Material-`.3mf` (`EU-Schnalle-backplate.3mf`) mit zwei
   Materialien: *Volt Purple* (`#502379`) und *EU Star Yellow* (`#FFCC00`).
3. Temporäre STLs werden automatisch aufgeräumt.

Erwartetes Ergebnis: `EU-Schnalle-backplate.3mf` (~68 KB).

## Wichtige Stolpersteine

- **SVG-Pfade prüfen.** Das `.scad` importiert das Volt-Logo über
  `logo_file`, der Pfad ist **relativ zur `.scad`-Datei** und zeigt auf
  `../resources/Logo_of_Volt.svg`. Liegt das SVG nicht dort, **bricht OpenSCAD
  nicht hart ab**, sondern gibt nur `ERROR: Can't open file …` aus und rendert
  die Lage ohne Logo weiter. Symptom: das `.3mf` ist auffällig klein (~34 KB
  statt ~68 KB) und die Renderzeit der Basislage liegt im Millisekundenbereich
  statt bei ~3 s.
- **Skriptausgabe nicht blind vertrauen.** Wegen `set -euo pipefail` signalisiert
  ein OpenSCAD-Importfehler keinen Exit-Code ≠ 0. Nach jedem Export auf
  `ERROR`/`WARNING` in der Ausgabe **und** auf eine plausible Dateigröße achten.
- **Stern-SVG wird nicht importiert.** `resources/star-svgrepo-com.svg` ist nur
  Referenzmaterial; die Sterne werden im `.scad` geometrisch erzeugt.

## Konventionen

- Exportierte `.3mf`-Dateien werden bewusst eingecheckt (direkt druckbar ohne
  OpenSCAD). Nach Änderungen am Modell den Export neu erzeugen und mitcommiten.
- Parameter (Maße, Lagenzahl, Sternzahl …) stehen oben im `.scad` und sollten
  dort gepflegt werden, nicht im Export-Skript dupliziert werden.
