# Comprobación manual en Roblox Studio

Estas pruebas requieren Roblox Studio y están **pendientes de ejecución real**. Las pruebas de `npm test` utilizan dobles de servicios: no acceden al catálogo ni renderizan la interfaz.

## Instalación y replicación

- [ ] Importar `FEEmotes.rbxmx` en una experiencia vacía, mover los componentes y activar el servidor siguiendo el README.
- [ ] Configurar R15 y abrir un servidor de prueba con dos jugadores. No debe haber errores en Output.
- [ ] Tocar una tarjeta abre la ficha; pulsar Desplegar reproduce un emote oficial permitido. Ambos clientes ven al primer jugador animarse; el segundo jugador no cambia de emote.
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
- [ ] Verificar que abrir el hub, seleccionar, equipar o marcar favoritos no abre avisos ni compra artículos. Solo Comprar debe abrir el prompt oficial; no confirmar gastos no deseados.

## Teléfono y GUI

En Device Emulator, probar 360×640, 390×844, tablet y teléfono en horizontal; terminar en un dispositivo físico si está disponible.

- [ ] Sin recortes por notch o barra superior; todos los controles accesibles desplazando el contenido.
- [ ] Miniaturas, etiquetas, estado de reproducción y mensajes de error legibles.
- [ ] Slider con un dedo; joystick con otro. Soltar fuera del slider recupera el desplazamiento.
- [ ] Arrastrar la cabecera a cada borde; la ventana queda dentro de la zona segura.
- [ ] Girar la pantalla con el panel abierto y el icono minimizado: queda dentro de pantalla.
- [ ] Minimizar conserva el emote y muestra el cuadrado lateral FE. Tocarlo restaura el panel; arrastrarlo no lo abre.
- [ ] Abrir controles con ≡ y plegarlos repetidamente: no desaparecen por un callback anterior.
- [ ] Minimizar/abrir/cerrar rápidamente: ningún tween tardío oculta la ventana reabierta.
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

## Glass: favoritos y animaciones (verificación real pendiente)

- [ ] Marcar ☆ en una tarjeta; Favoritos muestra la misma miniatura y nombre. ★ lo retira sin quitarlo del catálogo ni de Equipados.
- [ ] Guardar favoritos UGC/oficiales, navegar otras páginas y cambiar búsquedas: la colección permanece.
- [ ] Buscar por nombre, creador e ID en Favoritos. Vaciar el buscador devuelve toda la colección.
- [ ] Completar 120 favoritos: mensaje de límite, sin bloquear ni perder los ya guardados.
- [ ] Reaparecer y volver a ejecutar el archivo de Delta: los favoritos permanecen durante la sesión; los equipados se reinician al ejecutar de nuevo.
- [ ] Recibir resultados de catálogo mientras Favoritos está abierto: la pestaña no cambia sola.
- [ ] Favoritos vacíos y búsqueda sin resultados: mensaje correspondiente, sin tarjetas huérfanas.
- [ ] Todos los fondos principales son negros/grafito; pestañas y botones seleccionados tienen contraste adecuado.
- [ ] Transiciones de entrada/salida, indicador de navegación, estrellas, tarjetas y controles fluidas en teléfono físico.
- [ ] Abrir/cerrar 30 veces, cambiar pestañas y recrear GUI: sin conexiones, tweens o pistas acumulándose.
- [ ] Arrastrar el icono a las cuatro esquinas y girar el teléfono: siempre se puede volver a tocar.
- [ ] Al cerrar o minimizar con el teclado abierto, se cierra el teclado y se puede recuperar el hub.

## Inicio cerrado, ficha y compra oficial (pruebas reales pendientes)

- [ ] Ejecutar: solo aparece un cuadrado FE lateral de 48 × 48 con UICorner; no se abre el panel ni se consulta SearchCatalog automáticamente.
- [ ] Primer toque: apertura con escala/fundido y consulta del catálogo. Cerrar y abrir no repite búsquedas innecesarias.
- [ ] Las superficies glass son translúcidas; Lighting y efectos globales del juego permanecen intactos.
- [ ] Tarjetas 1:1 en 360×640, 390×844 y horizontal, con miniaturas/nombres legibles.
- [ ] Tocar una tarjeta abre una ficha sin iniciar reproducción ni compra; se ve el emote sobre un cuadrado negro.
- [ ] Desplegar reproduce exactamente el ID seleccionado. Cerrar la ficha no detiene una pista que ya estaba sonando.
- [ ] Comprar solo abre el aviso oficial del ID seleccionado; cancelar no concede el artículo ni inicia reproducción.
- [ ] Artículo gratuito, ya adquirido, fuera de venta y consulta fallida: precio/estado correcto y habilitación adecuada de Comprar.
- [ ] Pulsar Comprar repetidamente no abre varios avisos.
- [ ] No se da por procesada una compra solo por el evento de cierre; se vuelve a comprobar propiedad.
- [ ] Cambiar de selección o cerrar durante la consulta descarta respuestas obsoletas y prompts aún no abiertos.
- [ ] Un aviso oficial ya visible se cancela desde Roblox, incluso si minimizas o cierras el hub.
- [ ] Fallo de PromptPurchase o restricciones de venta: error claro, sin reintentos de compra automáticos.
- [ ] Girar la pantalla: acceso sigue en un lateral, preview cuadrado y ambos botones de la ficha accesibles.
- [ ] Ejecutar dos veces vuelve a mostrar solo FE y mantiene los favoritos de la sesión.

## Glass Compact (verificación en teléfono pendiente)

- [ ] Ventana no supera 400 × 560; mantiene márgenes en 320×568, 360×640 y 390×844.
- [ ] Catálogo, Equipados y Favoritos usan 3 columnas en teléfono y 4 con suficiente ancho; no aparecen filas cortadas al girar la pantalla.
- [ ] Probar una colección de 120 emotes y una cantidad no múltiplo de 3/4: última fila y scroll correctos.
- [ ] ★ está arriba en un botón cuadrado; pulsarlo abre Favoritos y lo pinta amarillo. Salir a Catálogo/Equipados restaura el tono neutro.
- [ ] Hover, pulsaciones repetidas y colección vacía no borran por error el amarillo de la sección seleccionada.
- [ ] Estrellas de tarjetas guardadas son doradas; marcar una no cambia la sección seleccionada ni abre la ficha.
- [ ] Tarjetas pequeñas: + y ☆ se pueden tocar por separado sin reproducir, abrir fichas ni comprar accidentalmente.
- [ ] Verificar legibilidad del vidrio sobre mapas claros, oscuros y fondos en movimiento en un dispositivo real.
- [ ] La ficha compacta sigue mostrando nombre, creador y estado de compra con sus dos botones accesibles.
