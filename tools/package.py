"""Genera el modelo de instalación de Studio, sin servicios ni dependencias externas."""
from pathlib import Path
import argparse
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "FEEmotes.rbxmx"


def build():
    root = ET.Element("roblox", {"version": "4"})
    for value in ("null", "nil"):
        ET.SubElement(root, "External").text = value
    counter = 0

    def item(parent, kind, name, source=None, disabled=False):
        nonlocal counter
        counter += 1
        obj = ET.SubElement(parent, "Item", {"class": kind, "referent": f"RBX{counter}"})
        props = ET.SubElement(obj, "Properties")
        ET.SubElement(props, "string", {"name": "Name"}).text = name
        if source:
            ET.SubElement(props, "ProtectedString", {"name": "Source"}).text = (
                ROOT / source
            ).read_text(encoding="utf-8")
        if disabled:
            ET.SubElement(props, "bool", {"name": "Disabled"}).text = "true"
        return obj

    package = item(root, "Folder", "FEEmotes_Package")
    storage = item(package, "Folder", "ReplicatedStorage")
    shared = item(storage, "Folder", "FEEmotes")
    for name in ("Config", "Validation", "Favorites", "HubState", "EmoteDetails"):
        item(shared, "ModuleScript", name, f"src/ReplicatedStorage/FEEmotes/{name}.lua")
    server = item(package, "Folder", "ServerScriptService")
    item(server, "Script", "FEEmotes", "src/ServerScriptService/FEEmotes.server.lua", disabled=True)
    starter = item(package, "Folder", "StarterPlayer")
    scripts = item(starter, "Folder", "StarterPlayerScripts")
    item(scripts, "LocalScript", "FEEmotes", "src/StarterPlayer/StarterPlayerScripts/FEEmotes.client.lua")
    ET.indent(root, space="  ")
    return ET.tostring(root, encoding="utf-8", xml_declaration=True) + b"\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Verifica que el modelo coincide con src/")
    args = parser.parse_args()
    content = build()
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_bytes() != content:
            raise SystemExit("Modelo desactualizado: ejecuta npm run package")
        print("Modelo XML OK: las 7 fuentes coinciden; servidor desactivado para importación segura.")
    else:
        OUTPUT.write_bytes(content)
        print(f"Generado {OUTPUT.name} ({len(content):,} bytes)")


if __name__ == "__main__":
    main()
