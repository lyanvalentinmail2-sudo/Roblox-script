# Comprobación manual en Roblox Studio

Estas pruebas requieren Roblox Studio y están **pendientes de ejecución real**. Las pruebas de `npm test` utilizan dobles de servicios: no acceden al catálogo ni renderizan la interfaz.

## Instalación y replicación

- [ ] Importar `FEEmotes.rbxmx` en una experiencia vacía, mover los componentes y activar el servidor siguiendo el README.
- [ ] Configurar R15 y abrir un servidor de prueba con dos jugadores. No debe haber errores en Output.
- [ ] Reproducir un emote oficial permitido. Ambos clientes ven al primer jugador animarse; el segundo jugador no cambia de emote.
- [ ] Buscar y reproducir un emote UGC autorizado. Documentar ID, propietario de la experiencia y resultado; los permisos dependen del asset.
- [ ] Probar R6: mensaje claro, sin pistas fantasma.
- [ ] Instalar mediante Rojo en lugar del modelo y repetir la prueba básica.

## Reproducción

- [ ] Probar 0,25×, 1× y 3×; verificar los cambios también desde el segundo cliente.
- [ ] Sin Mantener: caminar, saltar y nadar detienen el emote.
- [ ] Con Mantener: caminar y saltar conservan el emote, sin anclar el avatar ni cambiar WalkSpeed.
- [ ] Activar Mantener mientras se carga y reproducir mientras se camina.
- [ ] Pausar pose y reanudar, con y sin Mantener; al reanudar se recupera la velocidad elegida.
- [ ] Cambiar de emote varias veces: una sola pista FE Emotes activa, sin detener otras animaciones del juego.
- [ ] Detener, morir o salir durante la carga: ninguna animación empieza tarde.
- [ ] Cerrar durante la carga y abrir de nuevo: no se reinicia el emote cancelado.
- [ ] Respawn: GUI única, emote detenido, ajustes y ocho accesos conservados.

## Catálogo y equipados

- [ ] Buscar por nombre, ID, URL normal y URL localizada `/es/catalog/…`.
- [ ] Confirmar filtros UGC/Roblox por creador; cargar más páginas cuando no haya coincidencias.
- [ ] Equipar ocho emotes; el noveno no se añade. Quitar uno y añadir otro.
- [ ] Reproducir cada acceso rápido; “Equipados” muestra y permite quitar los mismos IDs.
- [ ] Introducir ID de accesorio, ID inexistente y asset restringido: mensajes claros, sin bloquear la UI.
- [ ] Simular catálogo lento/no disponible: timeout recuperable, destacados accesibles, reintento.
- [ ] Cargar hasta 120 resultados; nueva búsqueda reinicia la lista y no duplica tarjetas.
- [ ] Verificar que no se compran artículos ni se modifica la cuenta de Roblox.

## Teléfono y GUI

En Device Emulator, probar 360×640, 390×844, tablet y teléfono en horizontal; terminar en un dispositivo físico si está disponible.

- [ ] Sin recortes por notch o barra superior; todos los controles accesibles desplazando el contenido.
- [ ] Miniaturas, etiquetas, estado de reproducción y mensajes de error legibles.
- [ ] Slider con un dedo; joystick con otro. Soltar fuera del slider recupera el desplazamiento.
- [ ] Arrastrar la cabecera a cada borde; la ventana queda dentro de la zona segura.
- [ ] Girar la pantalla con el panel abierto y minimizado: queda dentro de pantalla.
- [ ] Minimizar conserva el emote; minirreproductor permite pausar, detener y restaurar.
- [ ] Cerrar detiene el emote y deja el botón FE para reabrir; no interfiere con el teclado.
- [ ] Pulsar M en PC; escribir M en el buscador no minimiza el panel.
- [ ] Mantener pulsados/repetir controles y cambiar velocidad no duplica la GUI ni acumula pistas.

## Seguridad e integración

- [ ] En un entorno privado de prueba, enviar IDs negativos, fraccionarios, infinitos, NaN o strings mediante el RemoteEvent: no se cargan assets.
- [ ] Solicitudes de ajustes fuera de rango, tablas malformadas y acciones desconocidas no generan errores del servidor.
- [ ] Ráfaga de solicitudes: límites activos, sin generar cientos de cargas.
- [ ] Confirmar que los contenedores de InsertService nunca se parentan al mundo.
- [ ] Probar con el sistema de combate/animaciones real del juego; animaciones de prioridad superior pueden sustituir visualmente los emotes.
- [ ] Salir y volver a entrar: los accesos se reinician (sin DataStore, comportamiento documentado).
