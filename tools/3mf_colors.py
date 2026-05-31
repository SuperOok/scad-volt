#!/usr/bin/env python3
"""Lies/aendere die Farbzuordnung in einer PrusaSlicer-.3mf.

Die konkreten Farben stehen im eingebetteten Konfig-Member
`Metadata/Slic3r_PE.config` als Zeilen der Form `; key = v1;v2;...`.
Relevant sind:
  - extruder_colour : die im UI pro Werkzeug/Extruder vergebenen Farben
  - filament_colour : die Farben aus dem gewaehlten Filament-Preset

Beispiele:
  3mf_colors.py show platte.3mf
  3mf_colors.py set  platte.3mf "#FFFF00,#90EE90,#FF0000,#0000FF,#800080"
  3mf_colors.py set  platte.3mf "#FFCC00;#502379" --key filament_colour -o neu.3mf
"""
import argparse
import os
import re
import shutil
import sys
import tempfile
from zipfile import ZIP_DEFLATED, ZipFile

CONFIG_MEMBER = "Metadata/Slic3r_PE.config"
HEX_RE = re.compile(r"^#(?:[0-9A-Fa-f]{6}|[0-9A-Fa-f]{8})$")


def read_config(path):
    with ZipFile(path) as zf:
        if CONFIG_MEMBER not in zf.namelist():
            sys.exit(f"FEHLER: {path} enthaelt kein {CONFIG_MEMBER} "
                     "(keine PrusaSlicer-Projekt-.3mf?).")
        return zf.read(CONFIG_MEMBER).decode("utf-8", "replace")


def get_value(config_text, key):
    """Liefert den Roh-Wert einer `; key = value`-Zeile oder None."""
    m = re.search(rf'^\s*;?\s*{re.escape(key)}\s*=\s*(.*)$', config_text, re.MULTILINE)
    return m.group(1).strip() if m else None


def split_colors(value):
    return [c for c in value.split(";")] if value else []


def cmd_show(args):
    config = read_config(args.file)
    for key in ("extruder_colour", "filament_colour"):
        value = get_value(config, key)
        if value is None:
            print(f"{key}: (nicht gesetzt)")
            continue
        colors = split_colors(value)
        print(f"{key}: {len(colors)} Eintraege")
        for i, color in enumerate(colors, start=1):
            print(f"  Extruder {i}: {color}")


def cmd_set(args):
    colors = [c.strip() for c in re.split(r"[;,]", args.colors) if c.strip()]
    bad = [c for c in colors if not HEX_RE.match(c)]
    if bad:
        sys.exit(f"FEHLER: ungueltige Farbwerte (erwartet #RRGGBB oder #RRGGBBAA): {bad}")

    config = read_config(args.file)
    existing = get_value(config, args.key)
    if existing is None:
        sys.exit(f"FEHLER: Schluessel '{args.key}' in {CONFIG_MEMBER} nicht gefunden.")

    old_count = len(split_colors(existing))
    if old_count and old_count != len(colors):
        print(f"WARNUNG: {args.key} hatte {old_count} Eintraege, "
              f"neu sind es {len(colors)}.", file=sys.stderr)

    new_value = ";".join(colors)
    new_config, n = re.subn(
        rf'(^\s*;?\s*{re.escape(args.key)}\s*=\s*).*$',
        lambda m: m.group(1) + new_value,
        config, count=1, flags=re.MULTILINE,
    )
    if n != 1:
        sys.exit(f"FEHLER: konnte '{args.key}' nicht ersetzen.")

    out_path = args.output or args.file
    _rewrite_3mf(args.file, out_path, {CONFIG_MEMBER: new_config})
    print(f"{args.key} gesetzt auf: {new_value}")
    print(f"geschrieben: {out_path}")


def _rewrite_3mf(src, dst, replacements):
    """Kopiert src nach dst und ersetzt die angegebenen Member (Text)."""
    # In temporaere Datei schreiben, dann atomar verschieben (auch bei dst == src sicher).
    fd, tmp = tempfile.mkstemp(suffix=".3mf", dir=os.path.dirname(os.path.abspath(dst)) or ".")
    os.close(fd)
    try:
        with ZipFile(src) as zin, ZipFile(tmp, "w", ZIP_DEFLATED) as zout:
            for info in zin.infolist():
                data = zin.read(info.filename)
                if info.filename in replacements:
                    data = replacements[info.filename].encode("utf-8")
                # Kompressionsart des Originals beibehalten
                zout.writestr(info, data, compress_type=info.compress_type)
        shutil.move(tmp, dst)
    except BaseException:
        if os.path.exists(tmp):
            os.remove(tmp)
        raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    p_show = sub.add_parser("show", help="Farbzuordnung anzeigen")
    p_show.add_argument("file", help="Pfad zur .3mf")
    p_show.set_defaults(func=cmd_show)

    p_set = sub.add_parser("set", help="Farben setzen")
    p_set.add_argument("file", help="Pfad zur .3mf")
    p_set.add_argument("colors", help="Farben, durch ',' oder ';' getrennt (z.B. '#FFFF00,#FF0000')")
    p_set.add_argument("--key", default="extruder_colour",
                       choices=["extruder_colour", "filament_colour"],
                       help="zu setzender Schluessel (Default: extruder_colour)")
    p_set.add_argument("-o", "--output",
                       help="Ausgabedatei (Default: Quelle in-place ueberschreiben)")
    p_set.set_defaults(func=cmd_set)

    args = parser.parse_args(argv)
    args.func(args)


if __name__ == "__main__":
    main()
