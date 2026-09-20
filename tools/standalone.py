"""Empaqueta el controlador local y la GUI existente en un solo archivo para copiar."""
from pathlib import Path
import argparse

ROOT = Path(__file__).resolve().parent.parent
OUTPUT = ROOT / "FEEmotes-Delta.lua"


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


def inline(name, path):
    return f"local {name} = (function()\n{read(path)}\nend)()\n"


def replace_once(source, old, new):
    if source.count(old) != 1:
        raise ValueError(f"La GUI cambió; revisa el empaquetador: {old[:65]!r}")
    return source.replace(old, new, 1)


def build():
    client = read("src/StarterPlayer/StarterPlayerScripts/FEEmotes.client.lua")
    # Compartir la GUI sin copiar su mantenimiento ni depender de ReplicatedStorage.
    head, body = client.split("local C = {", 1)
    head = head[:head.index('local shared =')]
    head = replace_once(head, 'local ReplicatedStorage = game:GetService("ReplicatedStorage")\n', '')
    head = replace_once(head, 'if playerGui:FindFirstChild("FEEmotesGui") then\n\treturn\nend',
                        'local previousGui = playerGui:FindFirstChild("FEEmotesStandaloneGui")\n'
                        'if previousGui then previousGui:Destroy() end')
    head += inline("Config", "src/ReplicatedStorage/FEEmotes/Config.lua")
    head += inline("Validation", "src/ReplicatedStorage/FEEmotes/Validation.lua")
    head += inline("Favorites", "src/ReplicatedStorage/FEEmotes/Favorites.lua")
    head += inline("HubState", "src/ReplicatedStorage/FEEmotes/HubState.lua")
    head += inline("HubLayout", "src/ReplicatedStorage/FEEmotes/HubLayout.lua")
    head += inline("EmoteDetails", "src/ReplicatedStorage/FEEmotes/EmoteDetails.lua")
    head += inline("createController", "src/Standalone/Controller.lua")
    head += "local remote = createController(player, Config, Validation)\n\n"
    body = "local C = {" + body
    body = replace_once(body, 'Name = "FEEmotesGui"', 'Name = "FEEmotesStandaloneGui"')
    body = body.replace('remote:FireServer(', 'remote:Dispatch(').replace('remote.OnClientEvent', 'remote.Changed')
    body = replace_once(body, '"GLASS COMPACT  /  TU AVATAR"', '"GLASS COMPACT  /  LOCAL · R15"')
    body = replace_once(body, '"Listo · R15 recomendado"', '"Modo local · visibilidad a otros no garantizada"')
    body = replace_once(body, 'connect(gui.Destroying, function()\n', 'connect(gui.Destroying, function()\n\tremote:Destroy()\n')
    preamble = """-- FE EMOTES · ARCHIVO ÚNICO / EJECUCIÓN LOCAL
-- Generado por tools/standalone.py. No editar este archivo: modifica src/ y regenera.
-- Pega TODO el archivo en tu entorno de ejecución Lua cliente.
-- No requiere Studio, remotos del servidor, claves, descargas de código ni archivos auxiliares.
-- Compatibilidad con Delta NO verificada en un dispositivo real.
-- No garantiza replicación FE ni evita permisos, restricciones o moderación de Roblox.
-- Necesita avatar R15 y acceso a GetObjects para extraer las animaciones de catálogo.

"""
    return preamble + head + body


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    content = build()
    if args.check:
        if not OUTPUT.exists() or OUTPUT.read_text(encoding="utf-8") != content:
            raise SystemExit("Standalone desactualizado: ejecuta npm run package")
        print("Standalone OK: controlador, módulos y GUI coinciden con src/.")
    else:
        OUTPUT.write_text(content, encoding="utf-8")
        print(f"Generado {OUTPUT.name}")


if __name__ == "__main__":
    main()
