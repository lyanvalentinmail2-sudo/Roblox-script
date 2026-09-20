# FE Emotes

**Tu avatar. Tu ritmo.** Un sistema de emotes para tu propia experiencia de Roblox, con interfaz oscura, acentos violeta y controles pensados para teléfono.

> Se instala en **Roblox Studio**, no en un ejecutor. “FE” significa que la reproducción se realiza mediante un `Animator` del servidor para que se replique a los demás jugadores. No es un script universal para juegos ajenos, no desactiva FilteringEnabled y no elude compras o permisos de Roblox.

## Funciones

- **Catálogo real**: búsqueda por nombre, ID o enlace de catálogo; miniaturas y paginación.
- **UGC + no UGC**: filtros Todos, UGC, Roblox y Equipados. UGC identifica creadores distintos del usuario oficial Roblox; los filtros se aplican a las páginas cargadas.
- **8 accesos rápidos**: equipar, reproducir y quitar emotes sin escribir comandos.
- **Velocidad de 0,25× a 3×**: deslizador táctil y botones de ajuste de 0,25×.
- **Mantener al moverte**: caminar o saltar no cancela el emote cuando está activado.
- **Pausar pose**: congela el fotograma con velocidad cero. Es independiente de “Mantener”; activa ambos para moverte con la pose congelada.
- **Minimizar**: el emote sigue funcionando en un minirreproductor con pausa y detener.
- **Cerrar**: detiene el emote, cancela su carga pendiente y oculta el panel. El botón pequeño **FE** permite volver a abrirlo.
- Ventana arrastrable, zonas seguras de pantalla, ajuste al girar el teléfono y botones principales de al menos 44 px. Atajo **M** en PC.
- Validación de IDs, tipo de asset, velocidad, personaje R15 y frecuencia de solicitudes en el servidor; limpieza al morir o salir.

## Instalación rápida en Studio

1. Descarga [`FEEmotes.rbxmx`](FEEmotes.rbxmx) usando **Download raw file** en GitHub. Abre tu experiencia en Studio y detén cualquier sesión de prueba.
2. En Explorer, haz clic derecho sobre `Workspace` → **Insert from File…** e importa el archivo. Aparecerá `FEEmotes_Package`.
3. Mueve **el contenido**, no las carpetas de servicios del paquete, a estas ubicaciones reales:

   | Dentro del paquete | Destino real |
   | --- | --- |
   | `ReplicatedStorage/FEEmotes` (Folder con dos módulos) | `game.ReplicatedStorage` |
   | `ServerScriptService/FEEmotes` (Script) | `game.ServerScriptService` |
   | `StarterPlayer/StarterPlayerScripts/FEEmotes` (LocalScript) | `game.StarterPlayer.StarterPlayerScripts` |

4. El Script de servidor viene desactivado para que no se ejecute al importar. **Actívalo después de mover los tres componentes**: `Enabled = true` / `Disabled = false` en Properties.
5. Elimina la carpeta vacía `FEEmotes_Package`. No instales dos copias del sistema.
6. Configura el tipo de avatar de tu experiencia como **R15**. Los emotes de este catálogo no se convierten a R6.
7. Pulsa **Play**, no solamente Run. Para comprobar replicación, inicia un servidor de prueba con **2 jugadores**.

No necesitas activar HTTP Requests, `loadstring`, acceso a DataStore ni instalar bibliotecas externas en el juego. Studio requiere ordenador para la instalación; la interfaz del juego está diseñada para usarse en teléfono.

### Alternativa: copiar las fuentes

Crea esta estructura en Explorer y pega el contenido del archivo correspondiente. Respeta los tipos **ModuleScript**, **Script** y **LocalScript**:

```text
ReplicatedStorage
└── FEEmotes                         Folder
    ├── Config                       ModuleScript ← src/ReplicatedStorage/FEEmotes/Config.lua
    └── Validation                   ModuleScript ← src/ReplicatedStorage/FEEmotes/Validation.lua
ServerScriptService
└── FEEmotes                         Script ← src/ServerScriptService/FEEmotes.server.lua
StarterPlayer
└── StarterPlayerScripts
    └── FEEmotes                     LocalScript ← src/StarterPlayer/StarterPlayerScripts/FEEmotes.client.lua
```

El servidor crea `ReplicatedStorage.FEEmotes.Request` automáticamente; no lo crees a mano.

### Alternativa: Rojo

Con [Rojo](https://rojo.space/) y su plugin de Studio instalados:

```sh
rojo serve default.project.json
```

Conecta el plugin al proyecto. La configuración sincroniza únicamente los componentes del sistema; no reemplaza el mapa ni tus controles de personaje.

## Cómo usarlo

1. Toca una **imagen** del catálogo para reproducir el emote en bucle.
2. Toca **+ Equipar** para añadirlo a la fila de accesos rápidos. En **Equipados**, usa **✓ Quitar** para liberar un espacio.
3. Para un ID concreto, introduce el ID **del emote del catálogo**, o `https://www.roblox.com/catalog/ID/Nombre`, y pulsa **Ir →**. El servidor lo comprueba y, si se puede reproducir, aparecerá en la lista para equiparlo.
4. Ajusta la velocidad. Activa **Mantener** si quieres seguir moviéndote sin que se cancele.
5. Usa **Pausar pose** para parar la animación en el fotograma actual; **Reanudar pose** recupera la velocidad elegida.
6. Usa **−** en la cabecera para minimizar, **■** para detener o **×** para cerrar. Arrastra la cabecera para mover el panel. En el minirreproductor, toca el nombre para volver al panel y arrastra el borde libre para moverlo.

**Equipar es un acceso rápido dentro de esta experiencia.** No compra el emote, no lo añade al inventario global ni modifica permanentemente la rueda de emotes de tu cuenta. Los accesos y ajustes sobreviven a la reaparición del personaje, pero se reinician al salir del servidor; no hay persistencia entre sesiones.

## Disponibilidad y permisos: importante

Buscar un emote no garantiza que Roblox permita reproducirlo en tu experiencia. El servidor:

1. Consulta `MarketplaceService:GetProductInfoAsync` y exige `AssetType.EmoteAnimation`.
2. Usa `InsertService:LoadAsset` para extraer únicamente la referencia `Animation` del emote. **El contenedor nunca se inserta en el mundo ni se ejecutan scripts de assets.**
3. Carga esa animación en el `Animator` del personaje y comprueba que tenga duración válida antes de reproducirla.

Esto sirve tanto para emotes de Roblox como para UGC **que Roblox permita cargar y reproducir en la experiencia**. Assets privados, retirados, restringidos o con permisos insuficientes muestran un error; no se promete compatibilidad con todo el catálogo. Comprar un emote en una cuenta no garantiza por sí solo permisos de animación para una experiencia de grupo.

Si tienes una animación propia o autorizada para un emote que no se carga directamente, configura `AnimationOverrides` en el **Script del servidor**:

```lua
local AnimationOverrides = {
    -- [ID_DEL_EMOTE_DEL_CATALOGO] = ID_DE_ANIMACION_AUTORIZADA,
}
```

El ID del catálogo sigue validándose. Este mapeo no otorga permisos: la animación también debe poder usarse en tu experiencia. Nunca envíes IDs internos de animación desde el cliente como sustituto de esta validación.

“Mantener” no ancla al personaje ni cambia su velocidad de desplazamiento. Da prioridad `Action` a la pista y evita cancelarla al caminar/saltar. Otros sistemas del juego, como combate o animaciones de prioridad superior, pueden interferir. Morir, detener o cerrar sí cancela la pista, aunque “Mantener” esté activado.

## Configuración

Edita `Config.lua` para cambiar los destacados, rango de velocidad, número de accesos y tiempo máximo de carga. La interfaz de esta versión está diseñada para **8** espacios; si cambias ese máximo, actualiza también los textos y el diseño. Los destacados son un respaldo cuando el catálogo tarda o falla; su disponibilidad puede cambiar en Roblox.

Se cargan 30 resultados por página y hasta 120 por búsqueda para limitar instancias en móviles. Los filtros UGC/Roblox son locales a esas páginas: **Cargar más** puede revelar más coincidencias. Una búsqueda nueva reinicia la lista. No se leen inventarios ni se muestran avisos de compra.

## Desarrollo y comprobaciones

Las herramientas de Node y Python solo son para desarrollar este repositorio. **No forman parte de la instalación en Roblox.**

```sh
npm ci --ignore-scripts
npm run format:check
npm test
```

- Compilación de sintaxis de los cuatro archivos con Luau (WASM).
- Pruebas de validación, límites y clasificación de creadores.
- Pruebas del servidor con dobles de servicios: reproducción, velocidad, congelación, movimiento, cancelación, timeout, equipados, permisos, R6, muerte y desconexión.
- Verificación de que el modelo importable coincide exactamente con las fuentes.
- GitHub Actions ejecuta estas comprobaciones en cada push y pull request.

Después de editar fuentes:

```sh
npm run format
npm run package
npm test
```

**Las pruebas automatizadas no sustituyen Roblox Studio.** No comprueban el renderizado real, la replicación del motor ni los permisos actuales del catálogo. Sigue la [lista de pruebas en Studio](docs/PRUEBAS.md) antes de publicar tu experiencia.

## Solución de problemas

| Problema | Revisión |
| --- | --- |
| No aparece la GUI | Usa Play, revisa las tres ubicaciones y activa el Script del servidor. Mira Output. |
| El ID no es válido | Usa un emote del catálogo, no un bundle, accesorio o ID interno de animación. |
| Error de rig | Configura R15 y reaparece. |
| Error de permisos o pista vacía | Revisa disponibilidad y permisos del asset/animación. Prueba otro emote oficial. |
| Filtro UGC vacío | Carga más páginas o busca por nombre. Los destacados iniciales son oficiales. |
| El emote termina al caminar | Activa Mantener. Pausar pose por sí solo no evita la cancelación por movimiento. |
| No lo ven otros jugadores | Comprueba que está instalado el servidor y prueba con dos clientes; revisa Output. |
| Cambios de velocidad no visibles | Una pose pausada tiene velocidad efectiva cero; reanúdala. Revisa scripts de animación ajenos. |

### Referencias de Roblox

- [AvatarEditorService / catálogo](https://create.roblox.com/docs/reference/engine/classes/AvatarEditorService)
- [InsertService y permisos de carga](https://create.roblox.com/docs/reference/engine/classes/InsertService)
- [Animator y replicación](https://create.roblox.com/docs/reference/engine/classes/Animator)
- [AnimationTrack / AdjustSpeed](https://create.roblox.com/docs/reference/engine/classes/AnimationTrack)
