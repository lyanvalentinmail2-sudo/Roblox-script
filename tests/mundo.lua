--[[=====================================================================
	 MUNDO DE PRUEBA + ASERCIONES
======================================================================]]

local mock = _G.__mock
local S = mock.servicios

--=====================================================================
-- Utilidades de prueba
--=====================================================================
local resultados = { ok = 0, fallos = {} }

function assertEq(actual, esperado, descripcion)
	local iguales
	if type(actual) == "table" and type(esperado) == "table" then
		iguales = #actual == #esperado
		if iguales then
			for i = 1, #actual do
				if actual[i] ~= esperado[i] then
					iguales = false
					break
				end
			end
		end
	else
		iguales = (actual == esperado)
	end

	if iguales then
		resultados.ok = resultados.ok + 1
		print(string.format("  [OK] %s", descripcion))
	else
		table.insert(resultados.fallos, string.format(
			"%s  (esperado: %s / obtenido: %s)",
			descripcion, tostring(esperado), tostring(actual)
		))
		print(string.format("  [FALLO] %s (esperado: %s / obtenido: %s)",
			descripcion, tostring(esperado), tostring(actual)))
	end
end

function assertVerdad(condicion, descripcion)
	assertEq(condicion == true, true, descripcion)
end

function resumen()
	print("")
	print(string.format("RESULTADO: %d comprobaciones OK, %d fallos", resultados.ok, #resultados.fallos))
	for _, f in ipairs(resultados.fallos) do
		print("  FALLO -> " .. f)
	end
	return #resultados.fallos
end

-- Devuelve el contenedor donde haya quedado el panel (CoreGui o PlayerGui).
function contenedorDelPanel()
	local yo = S.Players.LocalPlayer
	local posibles = { S.CoreGui, yo and yo:FindFirstChild("PlayerGui") or nil }
	for _, padre in ipairs(posibles) do
		if padre ~= nil and padre:FindFirstChild("DetectorDeTools") ~= nil then
			return padre
		end
	end
	return nil
end

-- Cuenta las filas del panel (solo las que se llaman "Fila")
function contarFilas()
	local gui = contenedorDelPanel()
	if gui == nil then
		return -1
	end
	gui = gui:FindFirstChild("DetectorDeTools")
	if gui == nil then
		return -1
	end
	local marco = gui:FindFirstChild("Marco")
	if marco == nil then
		return -2
	end
	local contenido = marco:FindFirstChild("Contenido")
	if contenido == nil then
		return -3
	end
	local lista = contenido:FindFirstChild("Lista")
	if lista == nil then
		return -4
	end
	local n = 0
	for _, hijo in ipairs(lista:GetChildren()) do
		if hijo.Name == "Fila" then
			n = n + 1
		end
	end
	return n
end

function hayLayout()
	local padre = contenedorDelPanel()
	if padre == nil then
		return false
	end
	local gui = padre:FindFirstChild("DetectorDeTools")
	if gui == nil then
		return false
	end
	local lista = gui.Marco.Contenido.Lista
	for _, hijo in ipairs(lista:GetChildren()) do
		if hijo.ClassName == "UIListLayout" then
			return true
		end
	end
	return false
end

function buscarPanel(nombreServicio)
	local padre = nombreServicio and S[nombreServicio] or S.CoreGui
	local paneles = 0
	for _, hijo in ipairs(padre:GetChildren()) do
		if hijo.Name == "DetectorDeTools" then
			paneles = paneles + 1
		end
	end
	return paneles
end

function nombresDe(entradas)
	local t = {}
	for _, e in ipairs(entradas) do
		table.insert(t, e.nombre)
	end
	table.sort(t)
	return t
end

function contiene(lista, valor)
	for _, v in ipairs(lista) do
		if v == valor then
			return true
		end
	end
	return false
end

--=====================================================================
-- MUNDO DE PRUEBA
--=====================================================================
function construirMundo()
	local Players = S.Players
	local Workspace = S.Workspace
	local ReplicatedStorage = S.ReplicatedStorage

	-- Jugadores
	local yo = mock.nuevo("Player", "TuJugador")
	local amigo = mock.nuevo("Player", "Amigo123")
	yo.Parent = Players
	amigo.Parent = Players

	local jugadores = { yo, amigo }
	rawset(Players, "GetPlayers", function(self)
		return jugadores
	end)
	rawset(Players, "GetPlayerFromCharacter", function(self, personaje)
		for _, j in ipairs(jugadores) do
			if j.Character == personaje then
				return j
			end
		end
		return nil
	end)
	rawset(Players, "LocalPlayer", yo)

	local playerGui = mock.nuevo("PlayerGui", "PlayerGui")
	playerGui.Parent = yo

	-- Personaje del jugador local
	local personaje = mock.nuevo("Model", "TuJugador")
	personaje.Parent = Workspace
	yo.Character = personaje
	mock.nuevo("Part", "LeftHand").Parent = personaje
	mock.nuevo("Part", "HumanoidRootPart").Parent = personaje

	local arco = mock.nuevo("Tool", "ArcoDePlasma")
	arco.Parent = personaje
	mock.nuevo("Part", "Handle").Parent = arco

	-- Mochila del jugador local
	local mochila = mock.nuevo("Backpack", "Backpack")
	mochila.Parent = yo
	local espada = mock.nuevo("Tool", "EspadaLegendaria")
	espada.ToolTip = "Espada épica de prueba"
	espada.Parent = mochila
	local pico = mock.nuevo("Tool", "PicoDeMinero")
	pico.Parent = mochila
	-- BackpackItem que NO es Tool: no debe contarse por defecto
	mock.nuevo("HopperBin", "BinLinterna").Parent = mochila

	-- Mochila de otro jugador
	local mochilaAmigo = mock.nuevo("Backpack", "Backpack")
	mochilaAmigo.Parent = amigo
	mock.nuevo("Tool", "M4A1").Parent = mochilaAmigo

	-- Mundo
	mock.nuevo("Part", "Suelo").Parent = Workspace
	local cofre = mock.nuevo("Model", "Cofre")
	cofre.Parent = Workspace
	mock.nuevo("Tool", "LlaveDorada").Parent = cofre

	-- Plantilla replicada
	mock.nuevo("Tool", "PlantillaArma").Parent = ReplicatedStorage

	-- Plantillas que nadie usa
	local StarterPack = S.StarterPack
	mock.nuevo("Tool", "EspadaInicial").Parent = StarterPack

	-- Objetos que NO deben contarse
	mock.nuevo("Folder", "CarpetaSuelta").Parent = Workspace

	return {
		yo = yo,
		amigo = amigo,
		mochila = mochila,
		personaje = personaje,
		arco = arco,
	}
end
