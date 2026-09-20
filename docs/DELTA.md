# FE Emotes NOIR — archivo único para ejecutores

## Qué archivo usar

Usa **[`FEEmotes-Delta.lua`](../FEEmotes-Delta.lua)**, no el modelo `.rbxmx` ni los scripts separados de Studio.

Es una versión de ejecución **local** para un entorno Lua cliente como Delta. Incluye los módulos, el controlador y toda la GUI en un solo archivo: no espera scripts del servidor, no usa remotos del juego y no descarga librerías para dibujar la interfaz.

**Compatibilidad pendiente de comprobar en Delta real.** Las pruebas de este repositorio verifican sintaxis y lógica mediante dobles de servicios; no ejecutan Delta ni el motor de Roblox.

## Cómo probarlo

1. Abre el archivo `FEEmotes-Delta.lua` en GitHub y pulsa **Raw** para ver el código completo.
2. Copia **todo** el código. No copies el HTML de la página de GitHub ni solo un fragmento.
3. Entra con un avatar **R15**, espera a que el personaje termine de cargar y pega el código en el editor de tu ejecutor.
4. Ejecuta el archivo. Debería aparecer **FE Emotes / NOIR EDITION / LOCAL · R15**.
5. Toca la imagen de un emote para reproducirlo; **+ Equipar** lo añade a los ocho accesos rápidos.

No requiere claves propias, archivos auxiliares, Studio ni componentes de servidor. La carga de emotes necesita que el entorno permita `game:GetObjects`; si no, muestra un error. Usa esta versión donde tengas permiso. Los ejecutores pueden contravenir las normas de Roblox y poner en riesgo tu cuenta; este proyecto no ofrece protección contra sanciones.

## Controles

- **Búsqueda:** nombre, ID del emote del catálogo o enlace de Roblox. No sirve un ID de accesorio o bundle.
- **Catálogo / Favoritos / Equipados:** tres zonas distintas con transición animada. Dentro de Catálogo, Todos / UGC / Roblox filtra las páginas cargadas.
- **☆ / ★ Favoritos:** guarda o quita emotes de tu biblioteca (hasta 120). Busca localmente por nombre, creador o ID. No usa los espacios de Equipados.
- **≡ Controles:** despliega velocidad, Mantener y Pausar pose desde la tarjeta del reproductor.
- **Velocidad:** deslizador o `−` / `+`, de 0,25× a 3×.
- **Mantener:** evita cancelar el emote al caminar o saltar. No ancla al avatar ni modifica WalkSpeed.
- **Pausar pose:** detiene el fotograma. Activa también Mantener para moverte con la pose pausada.
- **Minimizar `−`:** mantiene el emote y deja un **icono circular negro FE** para volver a abrir el panel. Muestra un punto blanco cuando hay un emote activo.
- **Detener `■`:** detiene la pista y cancela su carga pendiente.
- **Cerrar `×`:** detiene y oculta el panel, dejando el botón FE para volver a abrirlo.
- **Arrastrar:** usa la cabecera del panel o arrastra el icono FE. Arrastrar el icono no cuenta como un toque de apertura.
- **Volver a ejecutar:** destruye la GUI anterior y su controlador antes de crear una nueva. Reinicia los accesos y ajustes, pero conserva los favoritos mientras permanezca el mismo PlayerGui de la sesión.

Los accesos rápidos sobreviven a la reaparición, pero no se guardan al salir del juego ni al volver a ejecutar el archivo. Los **favoritos** sobreviven además a volver a ejecutar el archivo: se guardan en un atributo local de PlayerGui, no en archivos del teléfono. Al salir de la sesión no se garantiza su conservación. Equipar o marcar como favorito no compra artículos ni cambia el inventario o la rueda global de tu cuenta.

## Diseño NOIR y animaciones

- Fondo negro y superficies grafito; botones seleccionados blancos, texto de alto contraste y tarjetas redondeadas.
- Apertura/cierre con escala y fundido; navegación con indicador deslizante; feedback al tocar botones y estrellas.
- Entrada escalonada de las primeras tarjetas, controles desplegables y movimientos del slider.
- Los tweens se cancelan al reemplazarlos o destruir la GUI. No hay bucles de animación permanentes por tarjeta.
- Puedes minimizar y volver a abrir rápidamente: una transición anterior no debería ocultar el panel nuevo.

**Actualiza tu cargador:** si usaste el código anterior con un hash de commit, ese enlace sigue apuntando a la versión antigua. Copia el nuevo archivo o usa el nuevo enlace de esta actualización.

## Límites importantes

- **No garantiza que otros jugadores vean el emote.** La replicación de una animación iniciada desde el cliente depende del Animator existente, del juego y de los permisos de Roblox. No se crea un Animator local para fingir que existe replicación FE.
- Los emotes UGC y oficiales se buscan en el catálogo; solo se reproducen los que Roblox y el entorno permitan cargar.
- No elude permisos de animación ni restricciones de assets. No modifica anticheats ni otros jugadores.
- `GetObjects` solo se usa para leer la referencia `AnimationId`. Los objetos devueltos se destruyen, nunca se insertan en el mundo ni se ejecutan sus scripts.
- Las animaciones de combate u otros scripts del juego pueden interrumpir o superponer la pista. “Mantener” no puede garantizar lo contrario.
- El catálogo puede fallar por conexión o limitaciones del entorno. Se mantienen los destacados como respaldo.

## Si no funciona

| Mensaje / síntoma | Qué revisar |
| --- | --- |
| No aparece nada | Comprueba que copiaste todo `FEEmotes-Delta.lua`, espera a que cargue el personaje y consulta los errores del ejecutor. |
| Necesitas R15 | El personaje actual es R6 o todavía no ha cargado. |
| GetObjects/permisos | El entorno bloquea esa API o el asset está restringido. No se fuerza su carga. |
| No tiene Animator | Espera a reaparecer; el script no fabrica un Animator para prometer replicación. |
| Animación no disponible | Prueba un emote oficial distinto; comprueba los permisos y el juego. |
| No lo ven otros | No hay garantía de FE en esta versión. Para controlar la replicación usa la versión de Studio en tu propia experiencia. |
| Emote se quita al moverte | Activa Mantener. Si otro sistema del juego lo detiene, este script no lo desactiva. |

## Desarrollo y pruebas pendientes

No edites a mano `FEEmotes-Delta.lua`: se genera desde `src/Standalone/Controller.lua`, los módulos compartidos (`Config`, `Validation`, `Favorites`, `HubState`) y la GUI de Studio.

```sh
npm run format
npm run package
npm test
```

Antes de afirmar compatibilidad, verificar en un entorno autorizado con Delta: arranque sin componentes de Studio, emote oficial y UGC permitido, velocidad, pausa, movimiento, cerrar durante una carga, reaparición, dos ejecuciones consecutivas, orientación del teléfono y visibilidad desde un segundo cliente.
