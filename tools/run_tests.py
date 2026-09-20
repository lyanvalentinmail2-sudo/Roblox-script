#!/usr/bin/env python3
"""Ejecuta las pruebas de EmoteGlass.lua sobre un VM Lua 5.1 (mismo dialecto que Roblox).

    python3 tools/run_tests.py            # sintaxis + pruebas de comportamiento
    python3 tools/run_tests.py --check    # solo sintaxis

Las pruebas corren el script DE VERDAD contra un API de Roblox simulado
(tests/harness.lua): no se re-implementa ni se copia su logica.
"""
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

LUA_RUNNER = r"""
import sys
from lupa import lua51

L = lua51.LuaRuntime(unpack_returned_tuples=False)
g = L.globals()


def _exit(code=0):
    raise SystemExit(int(code or 0))


g.os.exit = _exit

src = open('tests/harness.lua', encoding='utf-8').read()
L.execute(src, 'EmoteGlass.lua')   # corre el harness de verdad (arg[1] = script a probar)
"""

SYNTAX_RUNNER = r"""
import sys
from lupa import lua51

L = lua51.LuaRuntime(unpack_returned_tuples=False)
lua = '''
local src = ...
local f, e = loadstring(src, "EmoteGlass.lua")
if f then
    print("sintaxis Lua 5.1: OK (" .. #src .. " bytes)")
    return 0
end
print("sintaxis Lua 5.1: FALLO -> " .. tostring(e))
return 1
'''
fn = L.eval('(function(...) ' + lua.replace('\n', ' ') + ' end)')
sys.exit(int(fn(open(sys.argv[1], encoding='utf-8').read()) or 0))
"""


def find_python_with_lupa() -> str:
    """Interprete con lupa instalado; crea un venv temporal si hace falta."""
    probe = "import lupa.lua51"
    if subprocess.run([sys.executable, "-c", probe], capture_output=True).returncode == 0:
        return sys.executable
    venv = Path("/tmp/emoteglass-luaenv")
    py = venv / "bin" / "python"
    if not py.exists():
        print("instalando lupa (VM Lua 5.1) en un venv temporal ...")
        subprocess.run([sys.executable, "-m", "venv", str(venv)], check=True, capture_output=True)
        subprocess.run([str(py), "-m", "pip", "install", "-q", "lupa"], check=True, capture_output=True)
    return str(py)


def main() -> int:
    check_only = "--check" in sys.argv
    py = find_python_with_lupa()
    target = str(ROOT / "EmoteGlass.lua")

    print("== sintaxis ==")
    r = subprocess.run([py, "-c", SYNTAX_RUNNER, target], cwd=ROOT)
    if check_only or r.returncode != 0:
        return r.returncode

    print("\n== comportamiento (script real sobre Roblox simulado) ==")
    r = subprocess.run([py, "-c", LUA_RUNNER, target], cwd=ROOT)
    return r.returncode


if __name__ == "__main__":
    raise SystemExit(main())
