# Emote Glass — GUI de emotes para Delta (móvil)

Un solo archivo Lua: **`EmoteGlass.lua`**. GUI con efecto vidrio (blur + translucidez),
compacta y pensada para usar con el pulgar en el teléfono.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/lyanvalentinmail2-sudo/Roblox-script/arena/01a0bfd6-roblox-script/EmoteGlass.lua"))()
```

### Cómo ejecutarlo en Delta (Android)

1. Abre **Roblox** y **entra a cualquier juego** (`game:HttpGet` necesita estar dentro de un
   juego; desde el menú de Roblox no funciona).
2. Abre **Delta** y dale a **Attach / Inyectar** (el icono de Roblox). Espera a que diga conectado.
3. En Delta: pestaña **Console/Ejecutor** → **Paste** (pegar) → pega el `loadstring` de arriba →
   **Execute / Ejecutar**.
4. Aparece la ventana de vidrio. Si la pierdes de vista, busca la **bola flotante "E"**
   y tócala.

**Sin internet / sin URL:** copia el contenido de `EmoteGlass.lua`, pégalo en el editor de
Delta, guárdalo como script y ejecútalo. Hace exactamente lo mismo.

> El archivo vive en la rama `arena/01a0bfd6-roblox-script`. Si lo mueves a `main`,
> la URL pasa a ser `.../Roblox-script/main/EmoteGlass.lua`.

---

## Qué trae

| | |
|---|---|
| **Catálogo** | 127 emotes: 113 UGC + 7 de Roblox (gratis) + 7 clásicos `/e` |
| **Pestañas** | Todos · UGC · Roblox · Favs · Gratis |
| **Buscador** | Por nombre o por ID. Si escribes solo un ID, lo reproduce |
| **Precio** | Debajo de cada emote (`Gratis`, `55 R$`, `750 R$`…) |
| **★ Favoritos** | Estrellita **dentro** de cada emote; se guardan en archivo |
| **Al seleccionar** | Barra con **[Despegar]** y **[Comprar <precio> R$]** |
| **Ajustes del emote puesto** | ⚙ → velocidad (0.25×–3×) y "no se sale si te mueves" |
| **Ventana** | Se arrastra, se minimiza en una bola flotante, y recuerda su posición |

## Controles (táctil)

- **Tocar un emote** → se lo pone tu avatar y aparece la barra con los 2 botones.
- **★ dentro del emote** → lo agrega/quita de Favoritos.
- **■ (rojo, arriba)** → despegar el emote que tengas puesto.
- **⚙** → ajustes: deslizador de velocidad, botón `1x`, y el interruptor
  *"No se sale si te mueves"*.
- **—** → minimizar en la bola flotante (arrastrable); toca la bola para volver.
- En PC: `F` abre/cierra, `Retroceso` despegar, clic derecho en un emote abre su barra.

## Dónde se guarda

Con un executor que tenga `writefile` (Delta sí), guarda en:

```
workspace/EmoteGlass/config.json   →  favoritos, velocidad, bloqueo al moverse, posición de la ventana
```

Si tu executor no tiene `writefile`, el script avisa con un aviso rojo y sigue funcionando
(los favoritos solo duran la sesión).

## Límites reales (para que no te sorprenda)

- **Es 100 % cliente.** Los emotes se reproducen con `Humanoid:LoadAnimation` en tu
  personaje: los ven los demás solo si el juego replica animaciones del cliente
  (en la mayoría sí; en juegos con anti-cheat propio, no).
- **Emotes UGC de pago:** el cliente solo puede reproducir los que tu cuenta **ya tiene**.
  Si no lo tienes, al tocarlo te lo dice y usas **[Comprar]** (abre la tienda oficial de
  Roblox con `PromptPurchase`; no hay forma legal de saltarse el pago).
- **R6:** los emotes UGC no cargan en personajes R6; el script te avisa en vez de fallar en silencio.
- Algunos juegos quitan el `Humanoid`/`Animator` o bloquean animaciones: ahí no hay script que funcione.

## Añadir emotes nuevos

Los datos viven en un bloque marcado dentro de `EmoteGlass.lua`
(`--[[<EMOTE_DATA>]] … --[[</EMOTE_DATA>]]`) y se generan desde
[`tools/build_data.py`](tools/build_data.py). El formato por línea es
`"Nombre|Id|PrecioRobux|Categoria"` (`U` = UGC, `R` = Roblox, `C` = clásico; `F` = gratis).

```bash
python3 tools/build_data.py    # regenera el bloque y valida que no haya IDs repetidos
```

Los IDs son del catálogo oficial de Roblox (categoría Emotes, `assetType` 61 ·
EmoteAnimation); los clásicos salen del script `Animate` de Roblox.

## Pruebas

El script se prueba **de verdad**: se ejecuta sobre un VM Lua 5.1 (el dialecto de Roblox)
contra un API de Roblox simulado — no es una copia de la lógica.

```bash
python3 tools/run_tests.py           # sintaxis + 88 verificaciones de comportamiento
python3 tools/run_tests.py --check   # solo sintaxis
```

Cubre: catálogo y precios, codec JSON (incluido rechazar JSON roto), filtros y búsqueda,
poner/despegar emotes, prioridad de animación, velocidad aplicada al reproducir,
"no se sale si te mueves", liberar el emote cuando termina, compra, favoritos persistidos
en archivo, rejilla virtual (que el scroll no dispare el número de baldosas), la estrellita,
los botones de la barra, minimizar, y que re-ejecutar el script no deje GUIs ni conexiones sueltas.

```
$ python3 tools/run_tests.py
sintaxis Lua 5.1: OK (58 KB)
...
88 verificaciones, 0 fallos
TODO OK
```

## Estructura

```
EmoteGlass.lua        ← el script (único archivo que necesitas)
tools/build_data.py   ← genera/valida el catálogo incrustado
tools/run_tests.py    ← corre las pruebas
tests/harness.lua     ← API de Roblox simulada + 88 verificaciones
```
