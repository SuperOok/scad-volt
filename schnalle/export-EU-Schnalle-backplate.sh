#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$script_dir"

scad_file="EU-Schnalle-backplate.scad"
# Optionale Argumente: $1 = Lagenhoehe in mm, $2 = Ausgabedatei.
# Defaults entsprechen dem bisherigen Verhalten.
layer_height="${1:-0.4}"
output_3mf="${2:-EU-Schnalle-backplate.3mf}"
# Logo-Gravurtiefe an die Lagenhoehe koppeln, damit das Logo genau die
# unterste Lage durchschneidet (unabhaengig von der Lagenhoehe).
logo_engrave_depth="$layer_height"
layer_count=5
star_layer_strip_count=10
star_count=12

require_command() {
    if ! command -v "$1" >/dev/null 2>&1; then
        echo "Missing required command: $1" >&2
        exit 1
    fi
}

require_command openscad
require_command python3

if [[ ! -f "$scad_file" ]]; then
    echo "Missing OpenSCAD source: $scad_file" >&2
    exit 1
fi

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

rm -f -- \
    "EU-Schnalle-backplate.stl" \
    "EU-Schnalle-backplate-body.stl" \
    "EU-Schnalle-backplate-star.stl" \
    "EU-Schnalle-backplate-stars.stl"

echo "Exporting temporary STL parts with OpenSCAD..."
layer_part_stls=()
for ((i = 0; i < layer_count; i++)); do
    layer_number="$(printf "%02d" "$((i + 1))")"
    layer_part_stl="$tmpdir/layer-$layer_number.stl"
    openscad -D 'part="layer"' -D "layer_index=$i" -D "height=$layer_height" -D "logo_engrave_depth=$logo_engrave_depth" -o "$layer_part_stl" "$scad_file"
    layer_part_stls+=("$layer_part_stl")
done

star_part_stls=()
star_layer_strip_stls=()
for ((i = 0; i < star_layer_strip_count; i++)); do
    strip_number="$(printf "%02d" "$((i + 1))")"
    strip_part_stl="$tmpdir/star-layer-strip-$strip_number.stl"
    openscad -D 'part="star_layer_strip"' -D "star_layer_strip_index=$i" -D "height=$layer_height" -o "$strip_part_stl" "$scad_file"
    star_layer_strip_stls+=("$strip_part_stl")
done

for ((i = 0; i < star_count; i++)); do
    star_number="$(printf "%02d" "$((i + 1))")"
    star_part_stl="$tmpdir/star-$star_number.stl"
    openscad -D 'part="star_single"' -D "star_index=$i" -D "height=$layer_height" -o "$star_part_stl" "$scad_file"
    star_part_stls+=("$star_part_stl")
done

echo "Writing named 3MF..."
python3 - "$output_3mf" "$layer_count" "$star_layer_strip_count" "${layer_part_stls[@]}" "${star_layer_strip_stls[@]}" "${star_part_stls[@]}" <<'PY'
from pathlib import Path
from zipfile import ZIP_DEFLATED, ZipFile
from xml.sax.saxutils import escape
import datetime
import sys

output_3mf = Path(sys.argv[1])
layer_count = int(sys.argv[2])
star_layer_strip_count = int(sys.argv[3])
layer_start = 4
strip_start = layer_start + layer_count
star_start = strip_start + star_layer_strip_count
layer_stls = [Path(path) for path in sys.argv[layer_start:strip_start]]
star_layer_strip_stls = [Path(path) for path in sys.argv[strip_start:star_start]]
star_stls = [Path(path) for path in sys.argv[star_start:]]

clock_labels = ["12 Uhr"] + [f"{hour:02d} Uhr" for hour in range(1, 12)]

# Manuelle 5-Farben-Zuordnung aus den PrusaSlicer-Platten (1-basierte Extruder):
#   Extruder -> Farbe siehe `materials` weiter unten (E1..E5).
# ACHTUNG: Diese Listen sind auf 5 Basislagen / 10 Streifen / 12 Sterne
# zugeschnitten. Werden im .scad die Anzahlen geaendert, hier mitpflegen.
layer_extruders = [5, 2, 1, 3, 4]                       # Basislage 01..05
strip_extruders = [3, 3, 1, 1, 2, 2, 4, 4, 5, 5]        # Lage-06 Streifen 01..10
star_extruders = [5, 1, 2, 3, 2, 1, 5, 3, 4, 5, 4, 3]   # Stern 01..12 (Uhrposition)


def material_for(extruders, index, group):
    """1-basierte Extrudernummer -> 0-basierter Material-Index, mit Fallback."""
    if index < len(extruders):
        return extruders[index] - 1
    print(f"WARNUNG: keine Farbzuordnung fuer {group} #{index + 1}, "
          f"nutze Material 0.", file=sys.stderr)
    return 0


parts = []

for index, layer_stl in enumerate(layer_stls):
    layer_number = index + 1
    parts.append(
        {
            "id": 2 + index,
            "name": f"EU-Schnalle Lage {layer_number:02d} Basislage",
            "partnumber": f"EU-Schnalle-backplate-layer-{layer_number:02d}",
            "stl": layer_stl,
            "material_index": material_for(layer_extruders, index, "Basislage"),
        }
    )

for index, strip_stl in enumerate(star_layer_strip_stls):
    strip_number = index + 1
    parts.append(
        {
            "id": 2 + layer_count + index,
            "name": f"EU-Schnalle Lage 06 Streifen {strip_number:02d}",
            "partnumber": f"EU-Schnalle-backplate-layer-06-strip-{strip_number:02d}",
            "stl": strip_stl,
            "material_index": material_for(strip_extruders, index, "Streifen"),
        }
    )

for index, star_stl in enumerate(star_stls):
    label = clock_labels[index]
    partnumber_label = "12" if index == 0 else f"{index:02d}"
    parts.append(
        {
            "id": 2 + layer_count + star_layer_strip_count + index,
            "name": f"EU-Stern {label}",
            "partnumber": f"EU-Schnalle-backplate-star-{partnumber_label}-uhr",
            "stl": star_stl,
            "material_index": material_for(star_extruders, index, "Stern"),
        }
    )

# 5-Farben-Palette (Reihenfolge = Extruder 1..5, entspricht extruder_colour
# aus den manuell erstellten PrusaSlicer-Platten).
materials = [
    ("Extruder 1", "#FFFF00FF"),  # Gelb
    ("Extruder 2", "#90EE90FF"),  # Hellgruen
    ("Extruder 3", "#FF0000FF"),  # Rot
    ("Extruder 4", "#0000FFFF"),  # Blau
    ("Extruder 5", "#800080FF"),  # Violett
]


def attr(value):
    return escape(str(value), {'"': "&quot;"})


def parse_ascii_stl(path):
    vertices = []
    vertex_index = {}
    triangles = []
    current_triangle = []

    for raw_line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw_line.strip()
        if not line.startswith("vertex "):
            continue

        _, xs, ys, zs = line.split()
        vertex = (round(float(xs), 9), round(float(ys), 9), round(float(zs), 9))
        if vertex not in vertex_index:
            vertex_index[vertex] = len(vertices)
            vertices.append(vertex)

        current_triangle.append(vertex_index[vertex])
        if len(current_triangle) == 3:
            triangles.append(tuple(current_triangle))
            current_triangle = []

    if current_triangle:
        raise ValueError(f"{path}: incomplete triangle at end of STL")
    if not vertices or not triangles:
        raise ValueError(f"{path}: no mesh data found")

    return vertices, triangles


def fmt_number(value):
    if abs(value) < 0.0000000005:
        value = 0.0
    text = f"{value:.9f}".rstrip("0").rstrip(".")
    return text or "0"


model_lines = [
    '<?xml version="1.0" encoding="UTF-8"?>',
    '<model unit="millimeter" xml:lang="de-DE" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">',
    '  <metadata name="Title">EU-Schnalle-backplate</metadata>',
    '  <metadata name="Application">GitHub Copilot CLI</metadata>',
    f'  <metadata name="CreationDate">{datetime.date.today().isoformat()}</metadata>',
    "  <resources>",
    '    <basematerials id="1">',
]

for name, color in materials:
    model_lines.append(f'      <base name="{attr(name)}" displaycolor="{attr(color)}"/>')

model_lines.append("    </basematerials>")

for part in parts:
    vertices, triangles = parse_ascii_stl(part["stl"])
    material_index = part["material_index"]

    model_lines.extend(
        [
            f'    <object id="{part["id"]}" type="model" name="{attr(part["name"])}" partnumber="{attr(part["partnumber"])}">',
            "      <mesh>",
            "        <vertices>",
        ]
    )

    for x, y, z in vertices:
        model_lines.append(
            f'          <vertex x="{fmt_number(x)}" y="{fmt_number(y)}" z="{fmt_number(z)}"/>'
        )

    model_lines.extend(["        </vertices>", "        <triangles>"])

    for v1, v2, v3 in triangles:
        model_lines.append(
            f'          <triangle v1="{v1}" v2="{v2}" v3="{v3}" pid="1" p1="{material_index}" p2="{material_index}" p3="{material_index}"/>'
        )

    model_lines.extend(["        </triangles>", "      </mesh>", "    </object>"])

model_lines.extend(["  </resources>", "  <build>"])

for part in parts:
    model_lines.append(
        f'    <item objectid="{part["id"]}" printable="1" partnumber="{attr(part["partnumber"])}"/>'
    )

model_lines.extend(["  </build>", "</model>"])
model_xml = "\n".join(model_lines) + "\n"

content_types_xml = """<?xml version="1.0" encoding="UTF-8"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
  <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
  <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml"/>
</Types>
"""

rels_xml = """<?xml version="1.0" encoding="UTF-8"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
  <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel"/>
</Relationships>
"""

with ZipFile(output_3mf, "w", ZIP_DEFLATED) as zf:
    zf.writestr("[Content_Types].xml", content_types_xml)
    zf.writestr("_rels/.rels", rels_xml)
    zf.writestr("3D/3dmodel.model", model_xml)
PY

echo "Generated:"
ls -lh -- "$output_3mf"
