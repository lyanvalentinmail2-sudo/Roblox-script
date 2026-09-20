# FE Emotes GLASS COMPACT — archivo único para ejecutores

## Qué archivo usar

Usa **[`FEEmotes-Delta.lua`](../FEEmotes-Delta.lua)**, no el modelo `.rbxmx` ni los scripts separados de Studio.

Es una versión de ejecución **local** para un entorno Lua cliente como Delta. Incluye módulos, controlador y GUI en un solo archivo. No espera componentes del servidor, no usa remotos del juego ni descarga librerías de interfaz.

**Compatibilidad pendiente de comprobar en Delta real.** Las pruebas del repositorio verifican sintaxis y lógica con dobles de servicios; no ejecutan Delta ni el motor de Roblox, y no realizan compras reales.

## Cómo abrirlo

1. Abre `FEEmotes-Delta.lua` en GitHub y pulsa **Raw**.
2. Copia **todo** el código y pégalo en el editor del ejecutor después de que cargue tu personaje R15.
3. Ejecuta. **El panel NO se abre solo:** verás un cuadrado **FE** de 48 × 48 px en el lateral derecho, con esquinas redondeadas (`UICorner`).
4. Toca ese cuadrado para abrir el hub con una animación de escala y fundido. Se consulta el catálogo en la primera apertura.
5. Arrástralo si prefieres el otro lateral; al soltarlo se ajusta al borde más cercano. Arrastrar no cuenta como un toque para abrir.

No requiere claves propias ni archivos auxiliares. La reproducción necesita que el entorno permita `game:GetObjects`; si no, muestra un error. Usa esta versión donde tengas permiso. Los ejecutores pueden contravenir las normas de Roblox y poner en riesgo tu cuenta; este proyecto no ofrece protección contra sanciones.

## Tarjetas y ficha del emote

El catálogo está formado por **tarjetas cuadradas**, con **3 emotes por fila en teléfonos habituales y 4 cuando hay más ancho**. En espacios excepcionalmente estrechos baja a 2 o 1 para evitar recortes. El patrón de catálogo y ficha está inspirado en editores como «Mi Avatar», con diseño propio; no es una copia exacta del juego.

Toca la imagen de una tarjeta para abrir su ficha. **Tocar la tarjeta no reproduce ni compra nada.** La ficha muestra:

- La miniatura del emote sobre un **cuadrado negro**.
- Nombre, creador y precio orientativo o estado de disponibilidad.
- **Desplegar:** reproduce el emote en tu personaje, sujeto a los permisos del juego y Roblox.
- **Comprar:** abre la ventana oficial de confirmación de Roblox.

El nombre completo y el creador se muestran en la ficha; las tarjetas densas reservan su pie al nombre y sus esquinas a **+** y **☆**.

La ficha se puede cerrar con **×** o tocando su fondo. En horizontal, la miniatura se reduce y el contenido se desplaza; ambos botones principales quedan fuera del área desplazable para seguir accesibles.

En las tarjetas, **+** añade un emote a los ocho accesos rápidos; **✓** lo retira. **☆ / ★** guarda o quita un favorito. Estos controles son independientes de Comprar.

## Compra: sin cargos automáticos

El hub usa `GetProductInfoAsync` para consultar los datos del asset y `PlayerOwnsAssetAsync` para verificar si ya lo tienes. **Comprar** solo llama a `MarketplaceService:PromptPurchase` tras una pulsación explícita, con el ID del emote seleccionado.

- El precio del hub es **orientativo**. Revisa el precio final y confirma o cancela dentro de la ventana oficial de Roblox.
- Comprar queda desactivado durante la consulta, si ya tienes el artículo, si está fuera de venta directa, si falla la comprobación de propiedad o si ya hay una compra pendiente.
- Los artículos gratuitos también requieren el aviso oficial. No se ofrecen compras de reventa de assets marcados fuera de venta directa.
- No se usan productos de desarrollador, game passes ni IDs de terceros como sustitutos del emote.
- El evento de cierre del aviso **no se considera recibo**. Si Roblox informa una respuesta positiva, se vuelve a verificar la propiedad antes de mostrar que lo tienes.
- Cerrar la ficha cancela una apertura de compra aún pendiente. **Un aviso oficial ya abierto se cancela en Roblox**, no al minimizar el hub.
- La compra cliente puede estar restringida por el juego, el entorno o la ubicación de venta del asset; se informa del error sin intentar eludirlo.
- Comprar no reproduce ni equipa automáticamente en este hub.

## Resto de controles

- **Búsqueda:** nombre, ID del emote o enlace de catálogo. Un ID/enlace abre la ficha, no una reproducción automática.
- **Catálogo / Equipados:** pestañas compactas. Dentro de Catálogo, Todos / UGC / Roblox filtra las páginas cargadas.
- **★ de la cabecera:** botón cuadrado de Favoritos. Se ilumina en **amarillo** cuando esa sección está seleccionada y vuelve a gris al cambiar a Catálogo o Equipados. Sigue amarillo aunque la colección esté vacía; no es un indicador de cuántos favoritos tienes.
- **Favoritos:** hasta 120, búsqueda local por nombre, creador o ID; no consume espacios de Equipados.
- **≡ Controles:** despliega velocidad, Mantener y Pausar pose desde el reproductor.
- **Velocidad:** deslizador y botones de 0,25× a 3×.
- **Mantener:** caminar o saltar no cancela la pista; no modifica WalkSpeed ni ancla al personaje.
- **Pausar pose:** congela el fotograma. Activa también Mantener para moverte con la pose pausada.
- **Minimizar `−`:** conserva el emote y devuelve el cuadrado lateral FE.
- **Detener `■`:** detiene la pista y cancela su carga pendiente.
- **Cerrar `×`:** detiene el emote y oculta el panel, dejando FE para reabrir.
- **Volver a ejecutar:** limpia la GUI anterior y empieza cerrado. Reinicia accesos/ajustes, pero conserva favoritos si continúa el mismo PlayerGui de la sesión.

Los accesos rápidos sobreviven al respawn, pero no al salir ni a ejecutar de nuevo el archivo. Los favoritos se guardan en un atributo local de PlayerGui; no se escriben archivos en el teléfono ni hay persistencia entre sesiones. Equipar o marcar favoritos no compra artículos.

## Glass UI y animaciones

- Ventana de hasta **400 × 560 px**, más pequeña que las versiones anteriores, adaptada con márgenes de 12 px.
- Cabecera con botones de 36 px, acciones de tarjeta de 28 px y acciones Desplegar/Comprar de 40 px; ficha y reproductor también compactados.
- Negro translúcido al 58% de transparencia, superficies internas más transparentes, reflejos suaves, bordes finos y texto blanco con una sombra sutil para mantener legibilidad. Es un efecto de cristal **simulado mediante GUI**: no modifica Lighting ni desenfoca globalmente el juego.
- Apertura/cierre con escala y fundido; navegación deslizante, feedback al pulsar, tarjetas y controles animados.
- El cuadrado lateral y las tarjetas conservan su forma al girar el teléfono.
- Los tweens se cancelan al reemplazarlos o destruir la GUI. No hay animaciones infinitas por tarjeta.
- Las transiciones antiguas no deben ocultar un panel o ficha que ya hayas reabierto.

**Actualiza el cargador:** los enlaces anteriores fijados a un hash siguen cargando la versión vieja. Copia el nuevo archivo o usa el enlace de esta actualización.

## Límites y errores

No se garantiza que otros jugadores vean el emote ni que todos los assets del catálogo se puedan reproducir. La replicación depende del Animator, los permisos y el juego. No se desactivan anticheats ni se modifican otros jugadores. `GetObjects` solo extrae la referencia de animación: los objetos se destruyen sin insertarlos en el mundo ni ejecutar sus scripts.

| Síntoma | Qué revisar |
| --- | --- |
| No aparece el panel | El arranque es cerrado: busca el cuadrado FE del lateral. |
| Tampoco aparece FE | Comprueba que copiaste todo el archivo y mira los errores del ejecutor. |
| Necesitas R15 / falta Animator | Espera a cargar o reaparecer con un personaje compatible. |
| GetObjects/permisos | El entorno bloquea la API o el asset está restringido; no se fuerza su carga. |
| Comprar está gris | Lee el estado en la ficha: consulta, propiedad, disponibilidad o prompt pendiente. |
| El precio difiere | El precio válido es el de la confirmación oficial de Roblox, no el orientativo del hub. |
| No lo ven otros | Esta versión no garantiza FE universal. |
| Se quita al moverte | Activa Mantener; otros scripts del juego pueden interferir. |

## Desarrollo

`FEEmotes-Delta.lua` se genera desde `src/Standalone/Controller.lua`, la GUI y los módulos `Config`, `Validation`, `Favorites`, `HubState`, `HubLayout` y `EmoteDetails`.

```sh
npm run format
npm run package
npm test
```

Antes de afirmar compatibilidad, realizar las pruebas reales en teléfono, Studio y un entorno autorizado con Delta de [PRUEBAS.md](PRUEBAS.md). Para probar compras, usa cancelación o un artículo gratuito; no confirmes gastos que no desees realizar.
