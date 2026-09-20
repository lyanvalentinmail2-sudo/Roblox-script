#!/usr/bin/env python3
"""Ejecuta DetectorDeTools.lua contra el simulador de la API de Roblox.

Uso:  python3 tests/run_tests.py
Requiere: pip install lupa   (Lua embebido en Python)
"""
import pathlib
import sys

RAIZ = pathlib.Path(__file__).resolve().parent.parent
DETECTOR = RAIZ / "DetectorDeTools.lua"

try:
    from lupa import LuaRuntime
except ImportError:
    print("Falta lupa. Instálalo con:  pip install lupa")
    sys.exit(2)


def main() -> int:
    fuente = DETECTOR.read_text(encoding="utf-8")

    L = LuaRuntime(unpack_returned_tuples=True)

    def ejecutar(codigo: str, nombre: str) -> None:
        try:
            L.execute(codigo)
        except Exception as e:  # noqa: BLE001
            print(f"\n### ERROR ejecutando {nombre}:\n{e}")
            raise

    ejecutar((RAIZ / "tests" / "mock_roblox.lua").read_text(encoding="utf-8"), "mock_roblox.lua")
    ejecutar((RAIZ / "tests" / "mundo.lua").read_text(encoding="utf-8"), "mundo.lua")
    ejecutar("_G.mundoTest = construirMundo()", "construirMundo()")
    ejecutar((RAIZ / "tests" / "pruebas.lua").read_text(encoding="utf-8"), "pruebas.lua")

    print("\n=== Cargando DetectorDeTools.lua (1ª ejecución) ===")
    ejecutar(fuente, "DetectorDeTools.lua")
    ejecutar("fase1()", "fase1()")

    print("\n=== Cargando DetectorDeTools.lua (2ª ejecución, debe limpiar la anterior) ===")
    ejecutar(fuente, "DetectorDeTools.lua (2ª vez)")
    ejecutar("fase1_reejecutado()", "fase1_reejecutado()")

    print("\n=== Cargando DetectorDeTools.lua con CONFIG.incluirBackpackItems = true ===")
    variante = fuente.replace("incluirBackpackItems = false", "incluirBackpackItems = true", 1)
    assert "incluirBackpackItems = true" in variante, "no se pudo crear la variante de config"
    ejecutar(variante, "DetectorDeTools.lua (variante)")
    ejecutar("fase2()", "fase2()")

    print("\n=== Cargando DetectorDeTools.lua con CoreGui bloqueado ===")
    L.execute("_G.__mock.bloquearCoreGui = true")
    ejecutar(fuente, "DetectorDeTools.lua (CoreGui bloqueado)")
    ejecutar("fase3()", "fase3()")

    fallos = L.execute("return resumen()")
    print("")
    if fallos and int(fallos) > 0:
        print(f"### {fallos} PRUEBA(S) FALLIDA(S)")
        return 1
    print("### TODAS LAS PRUEBAS PASARON")
    return 0


if __name__ == "__main__":
    sys.exit(main())
