--[[=====================================================================
	 SIMULADOR MÍNIMO DE LA API DE ROBLOX (para pruebas sin Roblox)
	 Implementa solo lo que usa DetectorDeTools.lua: Instance, game,
	 servicios, eventos, Enums, UDim2, Color3, task...
======================================================================]]

local mock = {
	prints = {},
	notificaciones = {},
	tareas = {},
	hilos = {},
	instanciasCreadas = 0,
}
_G.__mock = mock

--=====================================================================
-- Señales (eventos)
--=====================================================================
local function nuevaSenal(nombre)
	local s = { _nombre = nombre, _fns = {} }
	function s:Connect(fn)
		table.insert(self._fns, fn)
		return {
			_activa = true,
			Disconnect = function(self2)
				self2._activa = false
				for i, f in ipairs(s._fns) do
					if f == fn then
						s._fns[i] = nil
					end
				end
			end,
		}
	end
	function s:Once(fn)
		return self:Connect(fn)
	end
	return s
end

local function disparar(senal, ...)
	if senal == nil then
		return
	end
	-- copia para no romper el bucle si alguien se desconecta
	local fns = {}
	for _, f in ipairs(senal._fns) do
		table.insert(fns, f)
	end
	for _, f in ipairs(fns) do
		f(...)
	end
end
mock.disparar = disparar

--=====================================================================
-- Tipos de datos (UDim, UDim2, Color3, Vector3)
--=====================================================================
local function tipoConMetodos(nombre, campos, operaciones)
	local mt
	mt = {
		__index = function(t, k)
			if k == "__tipo" then
				return nombre
			end
			if operaciones and operaciones[k] then
				return function(...)
					return operaciones[k](...)
				end
			end
			return rawget(t, k)
		end,
		__tostring = function(t)
			local partes = {}
			for _, c in ipairs(campos) do
				table.insert(partes, tostring(t[c]))
			end
			return nombre .. "(" .. table.concat(partes, ", ") .. ")"
		end,
	}
	return mt
end

local UDim_mt = tipoConMetodos("UDim", { "Scale", "Offset" })
UDim = {}
function UDim.new(scale, offset)
	return setmetatable({ Scale = scale or 0, Offset = offset or 0 }, UDim_mt)
end

local UDim2_mt = tipoConMetodos("UDim2", { "X", "Y" })
UDim2 = {}
function UDim2.new(xs, xo, ys, yo)
	return setmetatable({
		X = UDim.new(xs, xo),
		Y = UDim.new(ys, yo),
	}, UDim2_mt)
end
function UDim2.fromOffset(x, y)
	return UDim2.new(0, x, 0, y)
end

local Color3_mt = tipoConMetodos("Color3", { "R", "G", "B" })
Color3 = {}
function Color3.fromRGB(r, g, b)
	return setmetatable({ R = (r or 0) / 255, G = (g or 0) / 255, B = (b or 0) / 255 }, Color3_mt)
end
function Color3.new(r, g, b)
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3_mt)
end

local Vector3_mt = tipoConMetodos("Vector3", { "X", "Y", "Z" }, {
	__sub = function(a, b)
		return setmetatable({ X = a.X - b.X, Y = a.Y - b.Y, Z = a.Z - b.Z }, Vector3_mt)
	end,
	__add = function(a, b)
		return setmetatable({ X = a.X + b.X, Y = a.Y + b.Y, Z = a.Z + b.Z }, Vector3_mt)
	end,
})
Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3_mt)
end

--=====================================================================
-- Enums (proxy: cualquier Enum.Categoria.Item devuelve un token estable)
--=====================================================================
local enumMT
enumMT = {
	__index = function(t, k)
		local item = setmetatable({ Nombre = tostring(k) }, enumMT)
		rawset(t, k, item)
		return item
	end,
	__tostring = function(t)
		return "EnumItem(" .. t.Nombre .. ")"
	end,
}
Enum = setmetatable({}, enumMT)

--=====================================================================
-- Instancias
--=====================================================================
local PADRES = {
	Instance = nil,
	BackpackItem = "Instance",
	Backpack = "Instance",
	Tool = "BackpackItem",
	HopperBin = "BackpackItem",
	Model = "Instance",
	BasePart = "Instance",
	Part = "BasePart",
	Folder = "Instance",
	Player = "Instance",
	GuiObject = "Instance",
	GuiBase2d = "Instance",
	LayerCollector = "Instance",
	ScreenGui = "LayerCollector",
	Frame = "GuiObject",
	TextLabel = "GuiObject",
	TextButton = "GuiObject",
	TextBox = "GuiObject",
	ScrollingFrame = "GuiObject",
	UICorner = "Instance",
	UIStroke = "Instance",
	UIPadding = "Instance",
	UIListLayout = "Instance",
	Camera = "Instance",
}

local EVENTOS = {
	ChildAdded = true, ChildRemoved = true, DescendantAdded = true, DescendantRemoving = true,
	Changed = true, AncestryChanged = true, Destroying = true,
	MouseButton1Click = true, MouseButton1Down = true, MouseButton1Up = true,
	InputBegan = true, InputChanged = true, InputEnded = true, FocusLost = true,
	Activated = true, Equipped = true, Unequipped = true,
	PlayerAdded = true, PlayerRemoving = true, CharacterAdded = true, CharacterRemoving = true,
	Heartbeat = true, Stepped = true,
}

local DEFAULTS = {
	Enabled = true,
	Visible = true,
	Active = false,
	AutoButtonColor = true,
	BackgroundTransparency = 0,
	TextTransparency = 0,
	Text = "",
	TextSize = 14,
	BorderSizePixel = 1,
	ClearTextOnFocus = true,
	ResetOnSpawn = true,
	IgnoreGuiInset = false,
	DisplayOrder = 0,
	ScrollBarThickness = 12,
	Thickness = 1,
	CanBeDropped = true,
	RequiresHandle = true,
	ToolTip = "",
	TextureId = "",
	Grip = nil,
}

local mtInstancia

local function esA(inst, clase)
	local actual = rawget(inst, "ClassName")
	local vueltas = 0
	while actual ~= nil and vueltas < 30 do
		if actual == clase then
			return true
		end
		actual = PADRES[actual]
		vueltas = vueltas + 1
	end
	return false
end

local function nuevoHijo(padre, hijo)
	-- Simula los juegos que prohíben escribir en CoreGui desde un script normal.
	if mock.bloquearCoreGui and padre == mock.servicios.CoreGui then
		error("The current identity (2) cannot modify CoreGui")
	end

	local lista = rawget(padre, "_hijos")
	if lista == nil then
		lista = {}
		rawset(padre, "_hijos", lista)
	end
	table.insert(lista, hijo)
	rawset(hijo, "_padre", padre)

	-- recorrer ancestros para los eventos Descendant*
	local actual = padre
	while actual ~= nil do
		local s = rawget(actual, "_signals")
		if s and s.DescendantAdded then
			disparar(s.DescendantAdded, hijo)
		end
		actual = rawget(actual, "_padre")
	end

	local s = rawget(padre, "_signals")
	if s and s.ChildAdded then
		disparar(s.ChildAdded, hijo)
	end
end

local function desvincular(hijo)
	local padre = rawget(hijo, "_padre")
	if padre == nil then
		return
	end
	local s = rawget(padre, "_signals")
	if s and s.DescendantRemoving then
		disparar(s.DescendantRemoving, hijo)
	end
	local lista = rawget(padre, "_hijos") or {}
	for i, h in ipairs(lista) do
		if h == hijo then
			table.remove(lista, i)
			break
		end
	end
	rawset(hijo, "_padre", nil)
	if s and s.ChildRemoved then
		disparar(s.ChildRemoved, hijo)
	end
end

local function nuevo(className, nombre)
	mock.instanciasCreadas = mock.instanciasCreadas + 1
	local inst = setmetatable({}, mtInstancia)
	rawset(inst, "ClassName", className or "Instance")
	rawset(inst, "Name", nombre or (className or "Instance"))
	rawset(inst, "_padre", nil)
	rawset(inst, "_hijos", {})
	rawset(inst, "_signals", {})
return inst
end
mock.nuevo = nuevo

mtInstancia = {
	__index = function(t, k)
		if k == "Parent" then
			return rawget(t, "_padre")
		end

		local raw = rawget(t, k)
		if raw ~= nil then
			return raw
		end

		if DEFAULTS[k] ~= nil then
			return DEFAULTS[k]
		end

		-- buscar un hijo con ese nombre (como hace Roblox)
		local hijos = rawget(t, "_hijos")
		if hijos then
			for _, h in ipairs(hijos) do
				if rawget(h, "Name") == k then
					return h
				end
			end
		end

		-- eventos: se crean bajo demanda
		if EVENTOS[k] then
			local s = rawget(t, "_signals")
			if s[k] == nil then
				s[k] = nuevaSenal(k)
			end
			return s[k]
		end

		-- métodos de instancia
		if k == "GetChildren" then
			return function(self)
				local copia = {}
				for _, h in ipairs(rawget(self, "_hijos") or {}) do
					table.insert(copia, h)
				end
				return copia
			end
		elseif k == "GetDescendants" then
			return function(self)
				local salida = {}
				local function bajar(nodo)
					for _, h in ipairs(rawget(nodo, "_hijos") or {}) do
						table.insert(salida, h)
						bajar(h)
					end
				end
				bajar(self)
				return salida
			end
		elseif k == "FindFirstChild" then
			return function(self, nombre)
				for _, h in ipairs(rawget(self, "_hijos") or {}) do
					if rawget(h, "Name") == nombre then
						return h
					end
				end
				return nil
			end
		elseif k == "WaitForChild" then
			return function(self, nombre)
				for _, h in ipairs(rawget(self, "_hijos") or {}) do
					if rawget(h, "Name") == nombre then
						return h
					end
				end
				return nil
			end
		elseif k == "IsA" then
			return function(self, clase)
				return esA(self, clase)
			end
		elseif k == "Destroy" then
			return function(self)
				desvincular(self)
			end
		elseif k == "ClearAllChildren" then
			return function(self)
				for _, h in ipairs(rawget(self, "_hijos") or {}) do
					desvincular(h)
				end
			end
		elseif k == "GetFullName" then
			return function(self)
				local partes, actual, vueltas = {}, self, 0
				while actual ~= nil and vueltas < 50 do
					-- El DataModel no forma parte de la ruta (igual que en Roblox).
					if rawget(actual, "ClassName") ~= "DataModel" then
						table.insert(partes, 1, rawget(actual, "Name"))
					end
					actual = rawget(actual, "_padre")
					vueltas = vueltas + 1
				end
				return table.concat(partes, ".")
			end
		elseif k == "Clone" then
			return function(self)
				local copia = nuevo(rawget(self, "ClassName"), rawget(self, "Name"))
				return copia
			end
		end

		return nil
	end,
	__newindex = function(t, k, v)
		if k == "Parent" then
			local viejo = rawget(t, "_padre")
			if viejo ~= nil then
				desvincular(t)
			end
			if v ~= nil then
				nuevoHijo(v, t)
			end
			return
		end
		rawset(t, k, v)
	end,
}

Instance = {}
function Instance.new(className)
	if className ~= nil and PADRES[className] == nil then
		error("Instance.new: clase desconocida en el mock: " .. tostring(className))
	end
	return nuevo(className)
end

--=====================================================================
-- game + servicios
--=====================================================================
local game = nuevo("DataModel", "Game")
_G.game = game
mock.game = game

local SERVICIOS_MOCK = {"Workspace", "Players", "ReplicatedStorage", "ReplicatedFirst", "StarterPack",
	"StarterGui", "StarterPlayer", "Lighting", "Teams", "SoundService", "CoreGui",
	"UserInputService", "HttpService", "RunService", "TweenService", "CollectionService",
	"ContextActionService", "TestService"}

local servicios = {}
for _, nombre in ipairs(SERVICIOS_MOCK) do
	local s = nuevo("Instance", nombre)
	s.Parent = game
	servicios[nombre] = s
	rawset(game, nombre, s)
end
mock.servicios = servicios

rawset(game, "GetService", function(self, nombre)
	local s = servicios[nombre]
	if s == nil then
		error(nombre .. " is not a valid member of DataModel")
	end
	return s
end)

-- Alias globales típicos de Roblox
Workspace = servicios.Workspace
workspace = Workspace
game.Workspace = Workspace

--=====================================================================
-- Comportamientos concretos de los servicios usados
--=====================================================================
-- HttpService
rawset(servicios.HttpService, "JSONEncode", function(self, datos)
	local partes = {}
	for _, d in ipairs(datos) do
		table.insert(partes, string.format('{"nombre":"%s","ruta":"%s"}', d.nombre, d.ruta))
	end
	return "[" .. table.concat(partes, ",") .. "]"
end)

-- StarterGui: SetCore (notificaciones)
rawset(servicios.StarterGui, "SetCore", function(self, accion, datos)
	if accion == "SendNotification" then
		table.insert(mock.notificaciones, datos)
		return
	end
	error("SetCore: acción no soportada en el mock: " .. tostring(accion))
end)

-- UserInputService (las señales se crean solas con __index)

--=====================================================================
-- task
--=====================================================================
task = {}
function task.wait(t)
	mock.esperas = (mock.esperas or 0) + 1
	if coroutine.isyieldable() then
		coroutine.yield()
	end
end
function task.spawn(fn)
	local co = coroutine.create(fn)
	table.insert(mock.hilos, co)
	return co
end
function task.defer(fn)
	table.insert(mock.tareas, fn)
	return fn
end
function task.delay(t, fn)
	table.insert(mock.tareas, fn)
	return fn
end
function mock.correrTareas()
	local pendientes = mock.tareas
	mock.tareas = {}
	for _, fn in ipairs(pendientes) do
		local ok, err = pcall(fn)
		if not ok then
			table.insert(mock.prints, "ERROR EN TAREA: " .. tostring(err))
			print("ERROR EN TAREA: " .. tostring(err))
		end
	end
end

wait = task.wait
spawn = task.spawn
delay = task.delay

--=====================================================================
-- print / warn capturados
--=====================================================================
local printReal = print
print = function(...)
	local partes = {}
	for i = 1, select("#", ...) do
		table.insert(partes, tostring(select(i, ...)))
	end
	table.insert(mock.prints, table.concat(partes, " "))
	printReal(table.concat(partes, " "))
end

warn = function(...)
	local partes = {}
	for i = 1, select("#", ...) do
		table.insert(partes, tostring(select(i, ...)))
	end
	table.insert(mock.prints, "WARN: " .. table.concat(partes, " "))
end

--=====================================================================
-- setclipboard
--=====================================================================
_G.__clipboard = nil
function setclipboard(texto)
	_G.__clipboard = tostring(texto)
end

_G.mock_roblox_listo = true
