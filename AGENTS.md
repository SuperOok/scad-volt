# AGENTS.md

Notes for agents (Claude Code, GitHub Copilot, …) working in this repository.
Please read before editing 3D models or exports.

## Project overview

`scad-volt` contains parametric 3D models (OpenSCAD) that are exported to
printable multi-material `.3mf` files.

```
.
├── resources/                       # shared assets (SVG logos etc.)
│   ├── Logo_of_Volt.svg
│   └── star-svgrepo-com.svg
└── schnalle/                        # model "EU-Schnalle backplate"
    ├── EU-Schnalle-backplate.scad   # parametric source
    ├── export-EU-Schnalle-backplate.sh
    └── *.3mf                        # exported results (checked in)
```

## Requirements

- `openscad` (tested with 2021.01) — must be on the `PATH`
- `python3` (tested with 3.12) — assembles the `.3mf` from the STL parts

The export script checks both and aborts with a clear message if anything is
missing.

## Exporting the model

Run from the respective model folder:

```bash
cd schnalle
./export-EU-Schnalle-backplate.sh                                  # default: 0.4 mm/layer
./export-EU-Schnalle-backplate.sh 0.2 EU-Schnalle-backplate-0.2mm.3mf  # uniform 0.2
./export-EU-Schnalle-backplate.sh 0.2 EU-Schnalle-backplate-base0.2-stars0.4.3mf 0.4  # thin base, thick star layer
```

The script takes three optional arguments:

| Arg | Meaning | Default |
|-----|---------|---------|
| `$1` | base layer height `height` in mm | `0.4` |
| `$2` | output file | `EU-Schnalle-backplate.3mf` |
| `$3` | height of the topmost star layer `star_layer_height` in mm | = `$1` (uniform) |

The total thickness is `plain_layer_count * height + star_layer_height`, so with
the 5 base layers ~2.4 mm (0.4/0.4), ~1.2 mm (0.2/0.2) or ~1.4 mm (0.2/0.4).
`star_layer_height` only affects the topmost layer with the stripes and stars;
`height` affects the 5 stacked base layers. Diameter and slot width stay the same
across all variants; only the thickness is varied via the layer height. The
script couples the logo engraving depth `logo_engrave_depth` to `height`, so that
the logo cuts through exactly the bottom layer regardless of the layer height.

**Caution, reload-from-disk:** Do not rename the canonical
`EU-Schnalle-backplate.3mf` (0.4 mm) — multi-piece plates derived by hand in
PrusaSlicer reference it via this file name.

Script flow:

1. Renders individual STL parts with OpenSCAD (base layers, star stripes of
   layer 06, and 12 individual stars) via the `-D part="…"` parameters of the
   `.scad`.
2. An embedded Python script reads the ASCII STLs and writes a named
   multi-material `.3mf` (`EU-Schnalle-backplate.3mf`) from them.
3. Temporary STLs are cleaned up automatically.

### Colors (5-color scheme)

The `.3mf` defines five 3MF base materials in extruder order; the
`displaycolor` matches the `extruder_colour` from the manually created
PrusaSlicer plates:

| Material index | Extruder | Color |
|---|---|---|
| 0 | 1 | `#FFFF00` yellow |
| 1 | 2 | `#90EE90` light green |
| 2 | 3 | `#FF0000` red |
| 3 | 4 | `#0000FF` blue |
| 4 | 5 | `#800080` violet |

The part → extruder assignment is stored in the script as `layer_extruders` /
`strip_extruders` / `star_extruders` and reproduces the manual coloring exactly
(5 base layers stacked, layer 06 as 5-color stripes, 12 stars individually).
**If the number of parts is changed in the `.scad`, these lists must be kept in
sync** (otherwise the fallback to material 0 kicks in).

Expected result: `EU-Schnalle-backplate.3mf` (~68 KB).

## Important pitfalls

- **Check the SVG paths.** The `.scad` imports the Volt logo via `logo_file`;
  the path is **relative to the `.scad` file** and points to
  `../resources/Logo_of_Volt.svg`. If the SVG is not there, OpenSCAD **does not
  fail hard** but only prints `ERROR: Can't open file …` and keeps rendering the
  layer without the logo. Symptom: the `.3mf` is conspicuously small (~34 KB
  instead of ~68 KB) and the render time of the base layer is in the
  milliseconds range instead of ~3 s.
- **Don't blindly trust the script output.** Because of `set -euo pipefail`, an
  OpenSCAD import error does not signal a non-zero exit code. After every export,
  watch for `ERROR`/`WARNING` in the output **and** for a plausible file size.
- **The star SVG is not imported.** `resources/star-svgrepo-com.svg` is only
  reference material; the stars are generated geometrically in the `.scad`.

## Conventions

- Exported `.3mf` files are deliberately checked in (directly printable without
  OpenSCAD). After changes to the model, regenerate the export and commit it too.
- Parameters (dimensions, layer count, star count …) live at the top of the
  `.scad` and should be maintained there, not duplicated in the export script.
