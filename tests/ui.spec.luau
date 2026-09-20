advance(1)
local gui = assert(playerGui:FindFirstChild("FEEmotesGui"))
local panel = find(gui, "Panel")
local icon = find(gui, "Reopen")
local navigation = find(gui, "LibraryNavigation")
check(panel.Visible and not icon.Visible and panel.GroupTransparency == 0, "UI: entrada visible")
check(panel.BackgroundColor3.R < 0.03 and panel.BackgroundColor3.G < 0.03, "UI: fondo negro")
check(tweenCount > 0, "UI: usa tweens reales del adaptador")
local first = find(gui, "Emote_123")
click(find(first, "Favorite"), 0.4)
check(find(first, "Favorite").Text == "★", "UI: estrella activada")
check(playerGui:GetAttribute("FEEmotesFavoritesV1") ~= nil, "UI: favoritos guardados en sesión")
click(find(navigation, "Favoritos"), 0.4)
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
click(find(navigation, "Catálogo"), 0.4)
check(
	find(find(gui, "Emote_123"), "Favorite").Text == "☆",
	"UI: catálogo conserva el emote al quitar favorito"
)
click(find(gui, "PlayerControls"), 0.4)
check(
	find(gui, "ExpandedPlayer").Visible and find(gui, "ExpandedPlayer").Size.Y.Offset == 128,
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
