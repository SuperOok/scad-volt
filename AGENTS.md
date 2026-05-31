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
./export-EU-Schnalle-backplate.sh                                  # Standard: 0,4 mm/Lage
./export-EU-Schnalle-backplate.sh 0.2 EU-Schnalle-backplate-0.2mm.3mf  # uniform 0,2
./export-EU-Schnalle-backplate.sh 0.2 EU-Schnalle-backplate-base0.2-stars0.4.3mf 0.4  # dünne Basis, dicke Sternlage
```

Das Skript nimmt drei optionale Argumente:

| Arg | Bedeutung | Default |
|-----|-----------|---------|
| `$1` | Basis-Lagenhöhe `height` in mm | `0.4` |
| `$2` | Ausgabedatei | `EU-Schnalle-backplate.3mf` |
| `$3` | Höhe der obersten Sternlage `star_layer_height` in mm | = `$1` (uniform) |

Die Gesamtdicke ist `plain_layer_count * height + star_layer_height`, bei den 5
Basislagen also ~2,4 mm (0,4/0,4), ~1,2 mm (0,2/0,2) oder ~1,4 mm (0,2/0,4).
`star_layer_height` betrifft nur die oberste Lage mit den Streifen und Sternen;
`height` die 5 gestapelten Basislagen. Durchmesser und Schlitzbreite bleiben über
alle Varianten gleich; nur die Dicke wird über die Lagenhöhe variiert. Die
Logo-Gravurtiefe `logo_engrave_depth` koppelt das Skript an `height`, damit das
Logo unabhängig von der Lagenhöhe genau die unterste Lage durchschneidet.

**Achtung Reload-from-disk:** Die kanonische `EU-Schnalle-backplate.3mf` (0,4 mm)
nicht umbenennen — von Hand in PrusaSlicer abgeleitete Mehrfach-Platten
referenzieren sie über diesen Dateinamen.

Ablauf des Skripts:

1. Rendert mit OpenSCAD einzelne STL-Teile (Basislagen, Stern-Streifen der
   Lage 06, sowie 12 Einzelsterne) über die `-D part="…"`-Parameter des `.scad`.
2. Ein eingebettetes Python-Skript liest die ASCII-STLs und schreibt daraus ein
   benanntes Multi-Material-`.3mf` (`EU-Schnalle-backplate.3mf`).
3. Temporäre STLs werden automatisch aufgeräumt.

### Farben (5-Farben-Schema)

Das `.3mf` definiert fünf 3MF-Basismaterialien in Extruder-Reihenfolge; die
`displaycolor` entspricht der `extruder_colour` aus den manuell erstellten
PrusaSlicer-Platten:

| Material-Index | Extruder | Farbe |
|---|---|---|
| 0 | 1 | `#FFFF00` Gelb |
| 1 | 2 | `#90EE90` Hellgrün |
| 2 | 3 | `#FF0000` Rot |
| 3 | 4 | `#0000FF` Blau |
| 4 | 5 | `#800080` Violett |

Die Zuordnung Teil → Extruder ist im Skript als `layer_extruders` /
`strip_extruders` / `star_extruders` hinterlegt und reproduziert exakt die
manuelle Einfärbung (5 Basislagen gestapelt, Lage 06 als 5-Farben-Streifen,
12 Sterne einzeln). **Wird die Teilezahl im `.scad` geändert, müssen diese
Listen mitgepflegt werden** (sonst greift der Fallback auf Material 0).

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
