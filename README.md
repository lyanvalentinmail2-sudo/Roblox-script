# Roblox-script — Detector de Tools

`DetectorDeTools.lua` es un script para Roblox que **detecta todas las herramientas (Tools) del juego y te dice sus nombres**, quién las tiene, dónde están y cómo se llaman exactamente (ruta completa).

- Panel (GUI) con la lista + buscador, y **también** la lista completa por consola (F9).
- Detecta tools de **todos los jugadores** (mochila y equipadas), del **mundo** y de las **plantillas replicadas**.
- Se actualiza **sola** cuando alguien recoge, suelta o equipa una tool.
- Funciona tanto pegado en un **executor** como en un **LocalScript** normal (si el juego bloquea el panel, usa la consola).

---

## Cómo se usa

### Opción 1: executor (Solara, Delta, Wave, Xeno, Synapse, AWP…)

1. Copia todo el contenido de `DetectorDeTools.lua`.
2. Pégalo en el ejecutor y dale a ejecutar.
3. Aparece el panel con la lista de tools y, además, todo sale en la consola (tecla **F9**).

### Opción 2: LocalScript (StarterPlayerScripts)

1. En Studio, crea un `LocalScript` dentro de `StarterPlayer > StarterPlayerScripts`.
2. Pega el mismo código.

---

## Qué te muestra

Por cada tool encontrada:

| Campo | Ejemplo |
|---|---|
| **Nombre** | `EspadaLegendaria` |
| **Clase** | `Tool` |
| **Ruta** | `Workspace.Cofre.LlaveDorada` |
| **Dueño** | `TuJugador` (o `(nadie / mundo)`) |
| **Contenedor** | `Backpack (guardada)` / `Personaje (equipada)` / `Workspace` |
| **Estado** | `EQUIPADA ✔` |
| **Tooltip** | el texto que puso el desarrollador |

Ejemplo de salida por consola:

```
=================================================================
  DETECTOR DE TOOLS  ·  6 herramienta(s) encontrada(s)
=================================================================
[1] EspadaLegendaria
     Clase      : Tool
     Ruta       : Players.TuJugador.Backpack.EspadaLegendaria
     Dueño      : TuJugador
     Contenedor : Backpack (guardada)
     Tooltip    : Espada épica

[2] LlaveDorada
     Clase      : Tool
     Ruta       : Workspace.Cofre.LlaveDorada
     Dueño      : (nadie / mundo)
     Contenedor : Workspace
...
-----------------------------------------------------------------
  Nombres: ArcoDePlasma, EspadaLegendaria, LlaveDorada, M4A1, PicoDeMinero
=================================================================
```

### Dónde mira

- **Jugadores**: `Backpack`, `Character`, `PlayerGui`, `StarterGear` de cada jugador (incluido tú).
- **Mundo**: `Workspace` (cofres, NPCs, mapas, modelos…).
- **Plantillas**: `ReplicatedStorage`, `ReplicatedFirst`, `StarterPack`, `StarterGui`, `StarterPlayer`, `Lighting`, `Teams`, `SoundService`.
- **Solo si se ejecuta en el servidor**: `ServerStorage` y `ServerScriptService`.

> Un script de cliente no puede ver lo que el servidor no replica (por ejemplo el contenido de `ServerStorage`). El detector muestra **todo lo que existe en tu lado del juego**, y los servicios que no te corresponden se ignoran solos.

---

## Panel

- **Escanear**: vuelve a escanear y repinta la lista.
- **Copiar lista** / **Copiar rutas**: copia al portapapeles (en executors con `setclipboard`).
- **Buscador**: filtra por nombre, ruta o dueño.
- **Clic en una fila**: copia la ruta de esa tool.
- Arrastrable por la barra de título; `X` cierra, `–` minimiza.

---

## Configuración

Arriba del archivo, en la tabla `CONFIG`:

| Opción | Por defecto | Qué hace |
|---|---|---|
| `mostrarGUI` | `true` | Abre el panel (si es `false`, solo consola) |
| `imprimirConsola` | `true` | Imprime la lista en la consola |
| `autoRefrescar` | `true` | Re-escanea sola cada X segundos |
| `intervaloAuto` | `5` | Segundos entre re-escaneos |
| `incluirBackpackItems` | `false` | `true` = cuenta también `HopperBin` y demás `BackpackItem` |
| `escanearTodoElJuego` | `false` | `true` = recorre el DataModel entero (más lento) |
| `maxProfundidad` | `14` | Profundidad máxima del recorrido |
| `orden` | `"dueno"` | `"dueno"`, `"nombre"` o `"ruta"` |
| `copiarAlClic` | `true` | Copiar la ruta al hacer clic en una fila |
| `notificar` | `true` | Avisos con notificaciones del juego |
| `avisarCambios` | `true` | Avisa cuando aparece/desaparece una tool |

---

## API `_G.DetectorTools`

Para usarlo desde otro script después de ejecutar el detector:

```lua
local Detector = _G.DetectorTools

for _, nombre in ipairs(Detector.nombres()) do
    print(nombre)                  -- "EspadaLegendaria", "LlaveDorada", ...
end

local lista = Detector.escanear()  -- tabla completa con nombre/clase/ruta/dueño...
Detector.imprimir()                -- lo imprime todo en consola
print(Detector.json())             -- exporta la lista como texto JSON

local tool = Detector.escanear()[1].inst  -- la instancia real de Roblox
print(tool:GetFullName())
```

| Función | Devuelve |
|---|---|
| `escanear()` | Lista completa (tabla de datos con `nombre`, `clase`, `ruta`, `dueno`, `contenedor`, `equipada`, `inst`…) |
| `nombres()` | Tabla con solo los nombres |
| `rutas()` | Tabla con solo las rutas |
| `imprimir()` | Imprime la lista en consola |
| `json()` | La lista exportada como texto JSON |
| `mostrar()` | Abre/restaura el panel |
| `cerrar()` | Cierra el panel y desconecta todo |

---

## Pruebas

El script está probado **de verdad**: `tests/` incluye un simulador de la API de Roblox (`Instance`, `game`, servicios, eventos, `Enum`, `task`…) sobre el que se ejecuta el detector con un mundo de prueba (7 tools repartidas entre jugadores, mochilas, el mapa y las plantillas) y 55 comprobaciones.

```bash
pip install lupa          # Lua embebido en Python
python3 tests/run_tests.py
```

Salida esperada:

```
RESULTADO: 55 comprobaciones OK, 0 fallos
### TODAS LAS PRUEBAS PASARON
```

Qué se comprueba, entre otras cosas: que encuentra las 7 tools correctas, que identifica la equipada y su dueño, que no cuenta nada dos veces, que el buscador filtra, que se entera **en vivo** cuando aparece o desaparece una tool, que el panel no se duplica al re-ejecutar el script y que cae a `PlayerGui` si el juego bloquea `CoreGui`.

---

## Aviso

Úsalo solo en tus propias partidas, en servidores privados o en Studio. Detectar qué herramientas existen es información que el cliente ya tiene; aun así, respeta las reglas del juego y los términos de uso de Roblox.
