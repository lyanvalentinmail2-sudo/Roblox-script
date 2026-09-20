advance(1)
local gui = assert(playerGui:FindFirstChild("FEEmotesGui"))
local panel = find(gui, "Panel")
local icon = find(gui, "Reopen")
local navigation = find(gui, "LibraryNavigation")
check(
	not panel.Visible and icon.Visible and panel.GroupTransparency == 1,
	"UI: inicia solo con acceso lateral"
)
check(icon.Size.X.Offset == 48 and icon.Size.Y.Offset == 48, "UI: acceso cuadrado pequeño")
check(icon:FindFirstChildOfClass("UICorner").CornerRadius.Offset == 12, "UI: acceso con esquinas redondeadas")
check(catalogCalls == 0 and #officialPrompts == 0, "UI: inicio no consulta catálogo ni abre compras")
check(
	panel.BackgroundTransparency > 0 and find(panel, "GlassSheen") ~= nil,
	"UI: superficies glass sin modificar Lighting"
)
click(icon, 0.4)
check(panel.Visible and not icon.Visible and panel.GroupTransparency == 0, "UI: apertura animada al tocar")
check(catalogCalls == 1, "UI: catálogo se consulta al abrir por primera vez")
check(panel.Size.X.Offset <= 400 and panel.Size.Y.Offset <= 560, "UI: ventana compacta")
check(panel.BackgroundTransparency >= 0.55, "UI: vidrio más transparente")
local favoriteTab = find(gui, "Favoritos")
check(favoriteTab.Parent == panel and favoriteTab.Text == "★", "UI: estrella en cabecera")
check(
	favoriteTab.Size.X.Offset == 36 and favoriteTab.Size.Y.Offset == 36,
	"UI: botón favoritos cuadrado compacto"
)
check(favoriteTab.BackgroundColor3.R < 0.5, "UI: favoritos no seleccionado es neutro")
local layout = find(gui, "SquareLayout")
check(layout.CellSize.X.Offset == layout.CellSize.Y.Offset, "UI: tarjetas de emote cuadradas")
check(layout.FillDirectionMaxCells == 3, "UI: tres emotes por fila en teléfono")
check(panel.BackgroundColor3.R < 0.03 and panel.BackgroundColor3.G < 0.03, "UI: fondo negro")
check(tweenCount > 0, "UI: usa tweens reales del adaptador")
local first = find(gui, "Emote_123")
check(
	find(first, "Favorite").Size.X.Offset == 28 and find(first, "Equip").Size.X.Offset == 28,
	"UI: acciones de tarjeta compactas"
)
local requestsBefore = #requests
click(find(first, "SelectEmote"), 0.4)
local detailOverlay = find(gui, "EmoteDetailsOverlay")
check(detailOverlay.Visible and #requests == requestsBefore, "UI: tocar tarjeta abre ficha sin reproducir")
check(#officialPrompts == 0, "UI: abrir ficha no inicia una compra")
local preview = find(gui, "BlackEmoteSquare")
check(
	preview.Size.X.Offset == preview.Size.Y.Offset and preview.BackgroundColor3.R == 0,
	"UI: miniatura sobre cuadrado negro"
)
check(
	find(gui, "DeployEmote").Text == "Desplegar" and find(gui, "BuyEmote").Text == "Comprar",
	"UI: las dos acciones solicitadas"
)
check(find(gui, "EmotePrice").Text == "50 Robux", "UI: precio de MarketplaceService")
click(find(gui, "BuyEmote"), 0.1)
check(
	#officialPrompts == 1 and officialPrompts[1].id == 123,
	"UI: Comprar abre prompt oficial del emote elegido"
)
click(find(gui, "BuyEmote"), 0.1)
check(#officialPrompts == 1, "UI: pulsaciones repetidas no duplican prompts")
market.PromptPurchaseFinished:Fire(localPlayer, 123, false)
advance(0.1)
check(find(gui, "BuyEmote").Active, "UI: cancelar permite reintentar")
click(find(gui, "DeployEmote"), 0.4)
check(
	requests[#requests].action == "Play" and requests[#requests].id == 123,
	"UI: Desplegar reproduce el emote seleccionado"
)
check(not detailOverlay.Visible, "UI: desplegar cierra la ficha")
click(find(first, "SelectEmote"), 0.4)
click(find(gui, "CloseDetails"), 0)
click(find(first, "SelectEmote"), 0.4)
check(
	detailOverlay.Visible and find(gui, "EmoteDetailsCard").GroupTransparency == 0,
	"UI: reapertura de ficha ignora cierre tardío"
)
click(find(gui, "CloseDetails"), 0.3)
viewport = vector(740, 320)
find(gui, "SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
advance(0.3)
check(icon.Position.X.Offset == 684, "UI: acceso sigue en el lateral al girar pantalla")
check(layout.FillDirectionMaxCells == 4, "UI: cuatro emotes por fila en ancho mayor")
check(
	preview.Size.X.Offset == preview.Size.Y.Offset and preview.Size.Y.Offset <= 100,
	"UI: ficha compacta en horizontal"
)
check(layout.CellSize.X.Offset == layout.CellSize.Y.Offset, "UI: cuadrícula sigue cuadrada tras girar")
viewport = vector(390, 740)
find(gui, "SafeArea"):GetPropertyChangedSignal("AbsoluteSize"):Fire()
advance(0.3)
check(icon.Position.X.Offset == 334, "UI: vuelve al lateral en vertical")
check(layout.FillDirectionMaxCells == 3, "UI: vuelve a tres columnas sin recrear el hub")

click(find(first, "Favorite"), 0.4)
check(find(first, "Favorite").Text == "★", "UI: estrella activada")
check(playerGui:GetAttribute("FEEmotesFavoritesV1") ~= nil, "UI: favoritos guardados en sesión")
click(find(gui, "Favoritos"), 0.4)
check(
	favoriteTab.BackgroundColor3.R == 1 and favoriteTab.BackgroundColor3.G == 211 / 255,
	"UI: favoritos seleccionado amarillo"
)
favoriteTab.MouseEnter:Fire()
favoriteTab.MouseLeave:Fire()
advance(0.3)
check(favoriteTab.BackgroundColor3.R == 1, "UI: hover no borra el amarillo de favoritos")
check(find(gui, "Emote_123") ~= nil, "UI: colección favorita independiente")
local search = find(gui, "Search")
search.Text = "no match"
advance(0.3)
local found = false
for _, object in ipairs(gui:GetDescendants()) do
	if object.Name == "Emote_123" then
		found = true
	end
end
check(not found, "UI: filtra favoritos al escribir")
search.Text = "dance"
advance(0.3)
check(find(gui, "Emote_123") ~= nil, "UI: recupera coincidencias")
click(find(find(gui, "Emote_123"), "Favorite"), 0.3)
found = false
for _, object in ipairs(gui:GetDescendants()) do
	if object.Name == "Emote_123" then
		found = true
	end
end
check(not found, "UI: quitar favorito actualiza la sección")
check(favoriteTab.BackgroundColor3.R == 1, "UI: favoritos vacío sigue seleccionado amarillo")
click(find(navigation, "Catálogo"), 0.4)
check(favoriteTab.BackgroundColor3.R < 0.5, "UI: salir de favoritos restaura el color neutro")
check(
	find(find(gui, "Emote_123"), "Favorite").Text == "☆",
	"UI: catálogo conserva el emote al quitar favorito"
)
click(find(gui, "PlayerControls"), 0.4)
check(
	find(gui, "ExpandedPlayer").Visible and find(gui, "ExpandedPlayer").Size.Y.Offset == 106,
	"UI: controles desplegados"
)
click(find(gui, "PlayerControls"), 0)
click(find(gui, "PlayerControls"), 0.4)
check(find(gui, "ExpandedPlayer").Visible, "UI: plegado antiguo no oculta controles reabiertos")
local minimize, close
for _, child in ipairs(panel:GetChildren()) do
	if child:IsA("TextButton") and child.Text == "−" then
		minimize = child
	end
	if child:IsA("TextButton") and child.Text == "×" then
		close = child
	end
end
local stops = 0
for _, request in ipairs(requests) do
	if request.action == "Stop" then
		stops = stops + 1
	end
end
click(minimize, 0.4)
check(icon.Visible and not panel.Visible, "UI: minimizar muestra el icono")
local stopsAfter = 0
for _, request in ipairs(requests) do
	if request.action == "Stop" then
		stopsAfter = stopsAfter + 1
	end
end
check(stopsAfter == stops, "UI: minimizar no detiene emotes")
click(icon, 0.4)
check(panel.Visible and not icon.Visible, "UI: el icono restaura el panel")
click(minimize, 0.05)
click(icon, 0.4)
check(panel.Visible and panel.GroupTransparency == 0, "UI: minimizado tardío no oculta reapertura")
click(close, 0.4)
check(icon.Visible and not panel.Visible, "UI: cierre deja icono recuperable")
check(requests[#requests].action == "Stop", "UI: cerrar detiene el emote")
local touch = { UserInputType = Enum.UserInputType.Touch, Position = vector(320, 30) }
icon.InputBegan:Fire(touch)
advance(0)
touch.Position = vector(280, 130)
input.InputChanged:Fire(touch)
advance(0)
input.InputEnded:Fire(touch)
advance(0)
click(icon, 0)
check(not panel.Visible, "UI: arrastrar el icono no abre el panel")
advance(0.3)
check(icon.Position.X.Offset == 8 or icon.Position.X.Offset == 334, "UI: el acceso se ajusta a un lateral")
click(icon, 0.4)
check(panel.Visible, "UI: el siguiente toque tras arrastrar sí abre")
localPlayer.CharacterAdded:Fire()
advance(0.5)
check(playerGui:FindFirstChild("FEEmotesGui") == gui, "UI: reaparecer no duplica la GUI")
click(find(navigation, "Catálogo"), 0.4)
click(find(find(gui, "Emote_123"), "Favorite"), 0.4)
click(minimize, 0.05)
gui:Destroy()
advance(1)
check(not playerGui:FindFirstChild("FEEmotesGui"), "UI: destruir elimina la GUI")
check(liveTweens == 0, "UI: no quedan tweens activos tras destruir")
print("GUI estructural: " .. assertions .. " comprobaciones correctas (sin renderizado)")
