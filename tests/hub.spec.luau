-- Módulos puros inyectados por el runner.
local assertions = 0
local function check(condition, message)
	assert(condition, message)
	assertions = assertions + 1
end
local library = Favorites.new(Validation, 3)
local item = { Id = 123, Name = "Dance", Creator = "Creator", IsRoblox = false }
check(library:count() == 0, "favoritos empiezan vacíos")
local ok, action = library:toggle(item)
check(ok and action == "added" and library:contains(123), "añadir con estrella")
item.Name = "Changed"
check(library:list()[1].Name == "Dance", "no retiene referencias de catálogo")
local copy = library:list()
copy[1].Name = "Corrupted"
check(library:list()[1].Name == "Dance", "listas defensivas")
check(#library:list(" dance ") == 1, "buscar sin distinguir mayúsculas y espacios")
check(#library:list("Creator") == 1, "buscar por creador")
check(#library:list("123") == 1, "buscar por ID")
check(#library:list("[.*") == 0, "no evalúa patrones de búsqueda")
check(not library:toggle({ Id = 0, Name = "Bad" }), "ID inválido")
check(not library:toggle({ Id = math.huge, Name = "Bad" }), "infinito inválido")
check(not library:toggle({ Id = 200, Name = "" }), "nombre vacío inválido")
check(not library:toggle({ Id = 200, Name = string.rep("x", 201) }), "nombre excesivo inválido")
check(library:toggle({ Id = 124, Name = "Two", IsRoblox = true }), "segundo favorito")
check(library:toggle({ Id = 125, Name = "Three" }), "tercer favorito")
check(library:list()[1].Id == 125, "los más recientes primero")
ok, action = library:toggle({ Id = 126, Name = "Four" })
check(not ok and action == "full" and library:count() == 3, "límite de colección")
ok, action = library:toggle({ Id = 124, Name = "Two" })
check(ok and action == "removed" and not library:contains(124), "quitar libera un espacio")
check(library:toggle({ Id = 126, Name = "Four" }), "añadir tras quitar")
local payload = library:export()
local restored = Favorites.new(Validation, 3)
check(restored:restore(payload) and restored:count() == 3, "restauración de sesión")
check(restored:list()[1].Id == 126, "restaura el orden")
payload.Items[1].Name = "External"
check(restored:list()[1].Name == "Four", "restauración defensiva")
check(not restored:restore({ Version = 2, Items = {} }), "rechaza versiones desconocidas")
check(restored:count() == 3, "payload inválido no borra favoritos")
check(not restored:restore("malformed"), "rechaza datos malformados")
restored:restore({
	Version = 1,
	Items = {
		{ Id = 100, Name = "A" },
		{ Id = 100, Name = "Duplicate" },
		{ Id = -1, Name = "Bad" },
	},
})
check(restored:count() == 1, "deduplica e ignora IDs inválidos")
restored:restore({ Version = 1, Items = {} })
check(restored:count() == 0, "guardar colección vacía")

local hub = HubState.new()
check(hub.mode == "minimized", "ventana inicial cerrada con acceso lateral")
local minimize = hub:set("minimized")
check(hub.mode == "minimized" and hub:current(minimize), "minimizar")
local reopen = hub:set("open")
check(not hub:current(minimize) and hub:current(reopen), "un cierre tardío no oculta el panel reabierto")
local close = hub:set("closed")
check(hub.mode == "closed" and not hub:current(reopen) and hub:current(close), "cerrar")
check(hub:set("unknown") == nil and hub.mode == "closed", "rechaza estados desconocidos")
hub:set("open")
hub:destroy()
check(not hub:current(close) and hub.mode == "destroyed", "destruir invalida callbacks")
check(hub:set("open") == nil, "una GUI destruida no se puede reabrir")
print("Favoritos y transiciones: " .. assertions .. " comprobaciones correctas")
