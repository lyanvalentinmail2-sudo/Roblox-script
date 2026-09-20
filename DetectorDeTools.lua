--[[=====================================================================
	 DETECTOR DE TOOLS  ·  Roblox
	 Detecta TODAS las herramientas (Tools / BackpackItems) que el cliente
	 puede ver y te dice sus nombres, dónde están y de quién son.
=======================================================================

	CÓMO USARLO
	-----------
	1) Executor (Solara, Delta, Wave, Xeno, Synapse, AWP...):
	   pega TODO el script y ejecútalo. Se abre un panel con la lista
	   y además la lista completa sale en la consola (F9).

	2) LocalScript normal (StarterPlayerScripts):
	   pégalo tal cual. Si no puede crear la GUI en CoreGui la crea en
	   PlayerGui, y si aun así falla solo imprime en la consola.

	QUÉ ESCANEA
	-----------
	* Tools de TODOS los jugadores: Backpack (guardadas) y Character
	  (equipadas).
	* Tools del mundo: Workspace (mapas, cofres, NPCs, modelos...).
	* Plantillas: ReplicatedStorage, ReplicatedFirst, StarterPack,
	  StarterGui, StarterPlayer, Lighting, Teams, SoundService.
	* Solo si el script corre en el servidor: ServerStorage y
	  ServerScriptService (en el cliente esos servicios ni existen,
	  se ignoran solos).

	NOTA: un script de cliente jamás puede ver cosas que el servidor no
	replica (por ejemplo contenido de ServerStorage). Este detector te
	muestra TODO lo que es visible en tu lado del juego.

	API  (_G.DetectorTools)
	-----------------------
	  _G.DetectorTools.escanear()   -> lista completa (tabla de datos)
	  _G.DetectorTools.nombres()    -> { "Espada", "Pico", "Arco" }
	  _G.DetectorTools.imprimir()   -> imprime la lista en consola
	  _G.DetectorTools.mostrar()    -> abre/restaura el panel
	  _G.DetectorTools.cerrar()     -> cierra el panel y desconecta todo
	  _G.DetectorTools.json()       -> lista exportada como texto JSON
======================================================================]]

--=====================================================================
-- 1) CONFIGURACIÓN (cambia lo que quieras aquí)
--=====================================================================
local CONFIG = {
	mostrarGUI = true, -- abre el panel con la lista
	imprimirConsola = true, -- imprime la lista en la consola (F9)
	autoRefrescar = true, -- vuelve a escanear sola cuando algo cambia
	intervaloAuto = 5, -- segundos entre re-escaneos automáticos (los eventos van al instante)
	incluirBackpackItems = false, -- true = cuenta también HopperBin y demás BackpackItems
	escanearTodoElJuego = false, -- true = recorre el DataModel entero (más lento)
	maxProfundidad = 14, -- profundidad máxima del recorrido
	orden = "dueno", -- "dueno" | "nombre" | "ruta"
	copiarAlClic = true, -- clic en una fila = copia su ruta
	notificar = true, -- usa notificaciones del juego para avisar
	avisarCambios = true, -- avisa cuando aparece/desaparece una tool
}

--=====================================================================
-- 2) UTILIDADES
--=====================================================================
local Game = game
local Instancia = Instance

-- Tabla pública que se expone al final en _G.DetectorTools.
local API = {}

local servicioCache = {}
local function servicio(nombre)
	if servicioCache[nombre] ~= nil then
		return servicioCache[nombre] or nil
	end
	local ok, s = pcall(function()
		return Game:GetService(nombre)
	end)
	servicioCache[nombre] = ok and s or false
	return (ok and s) or nil
end

local function intentar(fn, ...)
	local ok, resultado = pcall(fn, ...)
	if ok then
		return resultado
	end
	return nil
end

-- Propiedad segura: no revienta si la instancia no tiene esa propiedad.
local function propiedad(inst, nombre, porDefecto)
	local ok, valor = pcall(function()
		return inst[nombre]
	end)
	if ok and valor ~= nil then
		return valor
	end
	return porDefecto
end

local function rutaDe(inst)
	local ruta = intentar(function()
		return inst:GetFullName()
	end)
	if type(ruta) == "string" and #ruta > 0 then
		return ruta
	end
	-- Respaldo: construir la ruta a mano subiendo por los padres.
	local partes, actual, vueltas = {}, inst, 0
	while actual ~= nil and vueltas < 100 do
		local nombre = propiedad(actual, "Name", "?")
		table.insert(partes, 1, tostring(nombre))
		actual = propiedad(actual, "Parent", nil)
		vueltas = vueltas + 1
	end
	return table.concat(partes, ".")
end

local function esTool(inst)
	local ok, resultado = pcall(function()
		if CONFIG.incluirBackpackItems then
			return inst:IsA("BackpackItem")
		end
		return inst:IsA("Tool")
	end)
	return ok and resultado == true
end

-- ¿A qué jugador pertenece esta instancia?
-- OJO: el personaje NO cuelga del Player, cuelga de Workspace, así que para
-- las tools equipadas hay que preguntar a Players:GetPlayerFromCharacter().
local function duenoDe(inst)
	local actual, vueltas = inst, 0
	local candidatos = {}

	while actual ~= nil and vueltas < 100 do
		local ok, esJugador = pcall(function()
			return actual:IsA("Player")
		end)
		if ok and esJugador then
			return actual -- caso mochila: Backpack > Player
		end

		table.insert(candidatos, actual)
		actual = propiedad(actual, "Parent", nil)
		vueltas = vueltas + 1
	end

	-- Caso tool equipada: buscamos si alguna de las instancias de arriba es el
	-- personaje de un jugador.
	local Players = servicio("Players")
	if Players then
		for _, candidato in ipairs(candidatos) do
			local ok, jugador = pcall(function()
				return Players:GetPlayerFromCharacter(candidato)
			end)
			if ok and jugador ~= nil then
				return jugador
			end
		end
	end

	return nil
end

-- Servicio/raíz más alto al que pertenece la instancia (Workspace, Players...).
local function raizDe(inst)
	local actual, ultimo = inst, nil
	while actual ~= nil do
		local padre = propiedad(actual, "Parent", nil)
		if padre == nil or padre == Game then
			return ultimo or actual
		end
		ultimo = padre
		actual = padre
	end
	return ultimo
end

-- Notificación del propio juego (StarterGui:SetCore).
local function notificar(titulo, texto, duracion)
	if not CONFIG.notificar then
		return
	end
	local StarterGui = servicio("StarterGui")
	if not StarterGui then
		return
	end
	pcall(function()
		StarterGui:SetCore("SendNotification", {
			Title = titulo,
			Text = texto,
			Duration = duracion or 5,
		})
	end)
end

local function copiarTexto(texto)
	if type(setclipboard) == "function" then
		local ok = pcall(setclipboard, texto)
		if ok then
			return true
		end
	end
	return false
end

--=====================================================================
-- 3) ESCANEO
--=====================================================================
local function crearEntrada(tool)
	local dueno = duenoDe(tool)
	local raiz = raizDe(tool)
	local padre = propiedad(tool, "Parent", nil)
	local equipada = false

	if dueno then
		local personaje = propiedad(dueno, "Character", nil)
		equipada = (personaje ~= nil and padre == personaje)
	end

	-- Contenedor legible: Mochila / Personaje / nombre del servicio.
	local contenedor
	if dueno then
		if equipada then
			contenedor = "Personaje (equipada)"
		else
			local abuelo = padre and propiedad(padre, "Name", nil) or nil
			contenedor = abuelo == "Backpack" and "Backpack (guardada)" or ("Jugador > " .. tostring(abuelo))
		end
	else
		contenedor = raiz and propiedad(raiz, "Name", "?") or "?"
	end

	return {
		inst = tool,
		nombre = tostring(propiedad(tool, "Name", "?")),
		clase = tostring(propiedad(tool, "ClassName", "Tool")),
		ruta = rutaDe(tool),
		dueno = dueno and tostring(propiedad(dueno, "Name", "?")) or nil,
		contenedor = contenedor,
		equipada = equipada,
		tooltip = propiedad(tool, "ToolTip", nil),
		requiereMango = propiedad(tool, "RequiresHandle", nil),
		sePuedeSoltar = propiedad(tool, "CanBeDropped", nil),
		-- TextureId está obsoleto pero muchos juegos todavía lo usan.
		textura = propiedad(tool, "TextureId", nil),
	}
end

local function recorrer(raiz, entradas, visitados)
	local pendientes = { { raiz, 0 } }
	local revisados = 0

	while #pendientes > 0 do
		local nodo = table.remove(pendientes)
		local inst, nivel = nodo[1], nodo[2]

		if inst ~= nil and visitados[inst] ~= true then
			visitados[inst] = true
			revisados = revisados + 1

			-- Cada 400 objetos cedemos un frame para no congelar el juego.
			if revisados % 400 == 0 and type(task) == "table" and type(task.wait) == "function" then
				pcall(task.wait)
			end

			if esTool(inst) then
				table.insert(entradas, crearEntrada(inst))
			end

			if nivel < CONFIG.maxProfundidad then
				local hijos = intentar(function()
					return inst:GetChildren()
				end)
				if type(hijos) == "table" then
					for i = #hijos, 1, -1 do
						table.insert(pendientes, { hijos[i], nivel + 1 })
					end
				end
			end
		end
	end
end

local function raices()
	local lista = {}

	local function agregar(inst)
		if inst ~= nil then
			table.insert(lista, inst)
		end
	end

	-- Todos los jugadores: mochila, personaje, con quién está equipada.
	local Players = servicio("Players")
	if Players then
		local jugadores = intentar(function()
			return Players:GetPlayers()
		end)
		if type(jugadores) == "table" then
			for _, jugador in ipairs(jugadores) do
				for _, hijo in ipairs({ "Backpack", "Character", "PlayerGui", "StarterGear" }) do
					agregar(intentar(function()
						return jugador:FindFirstChild(hijo)
					end))
				end
			end
		end
	end

	-- Mundo y plantillas replicadas.
	local nombres = {
		"Workspace",
		"ReplicatedStorage",
		"ReplicatedFirst",
		"StarterPack",
		"StarterGui",
		"StarterPlayer",
		"Lighting",
		"Teams",
		"SoundService",
		"ServerStorage", -- solo servidor
		"ServerScriptService", -- solo servidor
	}
	for _, nombre in ipairs(nombres) do
		agregar(servicio(nombre))
	end

	if CONFIG.escanearTodoElJuego then
		agregar(Game)
	end

	return lista
end

local function comparar(a, b)
	local claveA, claveB = "", ""

	if CONFIG.orden == "nombre" then
		claveA, claveB = a.nombre:lower(), b.nombre:lower()
	elseif CONFIG.orden == "ruta" then
		claveA, claveB = a.ruta:lower(), b.ruta:lower()
	else -- "dueno": primero las de jugadores, luego el mundo
		claveA = ((a.dueno or "~") .. "|" .. a.nombre):lower()
		claveB = ((b.dueno or "~") .. "|" .. b.nombre):lower()
	end

	if claveA == claveB then
		return a.ruta < b.ruta
	end
	return claveA < claveB
end

local function escanear()
	local entradas, visitados = {}, {}

	for _, raiz in ipairs(raices()) do
		recorrer(raiz, entradas, visitados)
	end

	table.sort(entradas, comparar)
	return entradas
end

--=====================================================================
-- 4) SALIDA POR CONSOLA
--=====================================================================
local function linea(texto)
	print(texto)
end

local function imprimir(entradas)
	entradas = entradas or escanear()

	linea("")
	linea("=================================================================")
	linea(string.format("  DETECTOR DE TOOLS  ·  %d herramienta(s) encontrada(s)", #entradas))
	linea("=================================================================")

	if #entradas == 0 then
		linea("  No se encontró ninguna Tool visible en tu lado del juego.")
		linea("  (Prueba poniendo CONFIG.incluirBackpackItems = true o")
		linea("   CONFIG.escanearTodoElJuego = true y vuelve a ejecutar).")
		linea("=================================================================")
		linea("")
		return entradas
	end

	for i, e in ipairs(entradas) do
		linea(string.format("[%d] %s", i, e.nombre))
		linea("     Clase      : " .. e.clase)
		linea("     Ruta       : " .. e.ruta)
		linea("     Dueño      : " .. (e.dueno or "(nadie / mundo)"))
		linea("     Contenedor : " .. e.contenedor)
		if e.equipada then
			linea("     Estado     : EQUIPADA ✔")
		end
		if e.tooltip and tostring(e.tooltip) ~= "" then
			linea("     Tooltip    : " .. tostring(e.tooltip))
		end
		if e.requiereMango == false then
			linea("     RequiereHandle: false")
		end
		linea("")
	end

	linea("-----------------------------------------------------------------")
	linea("  Nombres: " .. table.concat(API.nombres(entradas), ", "))
	linea("=================================================================")
	linea("")
	return entradas
end

--=====================================================================
-- 5) PANEL (GUI)
--=====================================================================
-- Declaración adelantada: el panel usa refrescar() y se define más abajo.
local refrescar
local estado = {
	lista = {},
	conexiones = {},
	filtro = "",
	cerrado = false,
	autoActivo = false,
}

local refs = {
	gui = nil,
	marco = nil,
	titulo = nil,
	contador = nil,
	busqueda = nil,
	contenido = nil,
	scroller = nil,
	layout = nil,
}

-- Fuente segura (si una fuente ya no existe, usamos otra).
local function fuente(nombre, respaldo)
	local f = intentar(function()
		return Enum.Font[nombre]
	end)
	if f == nil then
		f = intentar(function()
			return Enum.Font[respaldo or "SourceSansBold"]
		end)
	end
	return f
end

local function crear(clase, props, padre)
	local ok, obj = pcall(function()
		return Instancia.new(clase)
	end)
	if not ok or obj == nil then
		return nil
	end
	if props then
		for clave, valor in pairs(props) do
			pcall(function()
				obj[clave] = valor
			end)
		end
	end
	if padre ~= nil then
		pcall(function()
			obj.Parent = padre
		end)
	end
	return obj
end

local function conectar(inst, evento, fn)
	if inst == nil or evento == nil or fn == nil then
		return nil
	end
	local conexion = intentar(function()
		return inst[evento]:Connect(fn)
	end)
	if conexion ~= nil then
		table.insert(estado.conexiones, conexion)
	end
	return conexion
end

local function textoDeLista(entradas, soloRutas)
	local lineas = {}
	for _, e in ipairs(entradas) do
		if soloRutas then
			table.insert(lineas, e.ruta)
		else
			table.insert(lineas, string.format(
				"%s  |  %s  |  dueño: %s  |  %s",
				e.nombre,
				e.clase,
				e.dueno or "(mundo)",
				e.ruta
			))
		end
	end
	return table.concat(lineas, "\n")
end

local function pintarFilas()
	if refs.scroller == nil then
		return
	end
	-- Importante: solo borramos las filas, el UIListLayout y el UIPadding se quedan.
	local hijos = intentar(function()
		return refs.scroller:GetChildren()
	end) or {}
	for _, hijo in ipairs(hijos) do
		if propiedad(hijo, "Name", "") == "Fila" then
			pcall(function()
				hijo:Destroy()
			end)
		end
	end

	local filtro = string.lower(estado.filtro or "")
	local visibles = 0

	for _, e in ipairs(estado.lista) do
		local coincide = true
		if #filtro > 0 then
			local texto = string.lower(e.nombre .. " " .. e.ruta .. " " .. (e.dueno or ""))
			coincide = string.find(texto, filtro, 1, true) ~= nil
		end

		if coincide then
			visibles = visibles + 1
			local fila = crear("TextButton", {
				Name = "Fila",
				Size = UDim2.new(1, -12, 0, 46),
				Position = UDim2.new(0, 6, 0, 0),
				BackgroundColor3 = e.equipada and Color3.fromRGB(28, 48, 34) or Color3.fromRGB(32, 34, 40),
				BackgroundTransparency = 0,
				BorderSizePixel = 0,
				AutoButtonColor = true,
				Text = "",
				TextXAlignment = Enum.TextXAlignment.Left,
				LayoutOrder = visibles,
			}, refs.scroller)

			if fila then
				crear("UICorner", { CornerRadius = UDim.new(0, 6) }, fila)

				local indice = crear("TextLabel", {
					Size = UDim2.new(0, 34, 0, 46),
					Position = UDim2.new(0, 6, 0, 0),
					BackgroundTransparency = 1,
					Text = "#" .. visibles,
					TextColor3 = Color3.fromRGB(120, 124, 138),
					TextSize = 13,
					Font = fuente("Gotham", "SourceSans"),
					TextXAlignment = Enum.TextXAlignment.Center,
				}, fila)

				local nombre = crear("TextLabel", {
					Size = UDim2.new(1, -170, 0, 20),
					Position = UDim2.new(0, 44, 0, 5),
					BackgroundTransparency = 1,
					Text = e.nombre,
					TextColor3 = Color3.fromRGB(240, 241, 245),
					TextSize = 15,
					Font = fuente("GothamBold", "SourceSansBold"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, fila)

				local ruta = crear("TextLabel", {
					Size = UDim2.new(1, -56, 0, 16),
					Position = UDim2.new(0, 44, 0, 26),
					BackgroundTransparency = 1,
					Text = e.ruta,
					TextColor3 = Color3.fromRGB(140, 146, 162),
					TextSize = 11,
					Font = fuente("Gotham", "SourceSans"),
					TextXAlignment = Enum.TextXAlignment.Left,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, fila)

				local etiqueta = crear("TextLabel", {
					Size = UDim2.new(0, 118, 0, 16),
					Position = UDim2.new(1, -124, 0, 5),
					BackgroundTransparency = 1,
					Text = (e.dueno and ("@" .. e.dueno) or "mundo") .. (e.equipada and "  ✔" or ""),
					TextColor3 = e.dueno and Color3.fromRGB(96, 200, 130) or Color3.fromRGB(150, 150, 165),
					TextSize = 12,
					Font = fuente("Gotham", "SourceSans"),
					TextXAlignment = Enum.TextXAlignment.Right,
					TextTruncate = Enum.TextTruncate.AtEnd,
				}, fila)

				if CONFIG.copiarAlClic then
					conectar(fila, "MouseButton1Click", function()
						if copiarTexto(e.ruta) then
							notificar("Copiado", e.ruta, 3)
						end
					end)
				end
			end
		end
	end

	if refs.contador then
		local total = #estado.lista
		local texto
		if #filtro > 0 then
			texto = string.format("Mostrando %d de %d herramienta(s)", visibles, total)
		else
			texto = string.format("%d herramienta(s) encontrada(s)", total)
		end
		pcall(function()
			refs.contador.Text = texto
		end)
	end

	-- Tamaño del lienzo (respaldo por si AutomaticCanvasSize no existe).
	if propiedad(refs.scroller, "AutomaticCanvasSize", nil) == nil then
		pcall(function()
			refs.scroller.CanvasSize = UDim2.new(0, 0, 0, visibles * 52 + 10)
		end)
	end
end

local function actualizarLista(nueva)
	estado.lista = nueva or {}
	pintarFilas()
end

local function hacerArrastrable(marco, asa)
	local UIS = servicio("UserInputService")
	if UIS == nil then
		return
	end

	local arrastrando, inicio, posInicial = false, nil, nil

	conectar(asa, "InputBegan", function(_, input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			arrastrando = true
			inicio = input.Position
			posInicial = marco.Position
		end
	end)

	conectar(UIS, "InputChanged", function(_, input)
		if not arrastrando then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch then
			local delta = input.Position - inicio
			marco.Position = UDim2.new(
				posInicial.X.Scale,
				posInicial.X.Offset + delta.X,
				posInicial.Y.Scale,
				posInicial.Y.Offset + delta.Y
			)
		end
	end)

	conectar(UIS, "InputEnded", function(_, input)
		if input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch then
			arrastrando = false
		end
	end)
end

local function mostrarPanel()
	if refs.gui then
		pcall(function()
			refs.gui.Enabled = true
			refs.marco.Visible = true
		end)
		pintarFilas()
		return
	end
	return false
end

local function crearPanel()
	if refs.gui ~= nil then
		return true
	end
	estado.cerrado = false

	-- Posibles contenedores, en orden de preferencia:
	--   1) gethui()  -> contenedor oculto de los executors (el más seguro)
	--   2) CoreGui   -> funciona en executors, algunos juegos lo bloquean
	--   3) PlayerGui -> siempre funciona (pero el juego puede ver la GUI)
	local candidatos = {}

	local gethui = rawget(_G, "gethui")
	if type(gethui) == "function" then
		local ok, hui = pcall(gethui)
		if ok and hui ~= nil then
			table.insert(candidatos, hui)
		end
	end

	local core = servicio("CoreGui")
	if core then
		table.insert(candidatos, core)
	end

	local Players = servicio("Players")
	local jugador = Players and propiedad(Players, "LocalPlayer", nil) or nil
	local playerGui = jugador and intentar(function()
		return jugador:WaitForChild("PlayerGui", 5)
	end) or nil
	if playerGui then
		table.insert(candidatos, playerGui)
	end

	if #candidatos == 0 then
		return false
	end

	-- Probamos cada contenedor: si el juego bloquea CoreGui, el GUI se queda
	-- sin padre y pasamos al siguiente.
	local gui = nil
	for _, padre in ipairs(candidatos) do
		local intento = crear("ScreenGui", {
			Name = "DetectorDeTools",
			ResetOnSpawn = false,
			IgnoreGuiInset = true,
			DisplayOrder = 999999,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		}, padre)

		if intento ~= nil and propiedad(intento, "Parent", nil) ~= nil then
			gui = intento
			break
		end

		if intento ~= nil then
			pcall(function()
				intento:Destroy()
			end)
		end
	end

	if gui == nil then
		return false
	end
	refs.gui = gui

	local marco = crear("Frame", {
		Name = "Marco",
		Size = UDim2.new(0, 470, 0, 390),
		Position = UDim2.new(0, 24, 0, 70),
		BackgroundColor3 = Color3.fromRGB(22, 23, 28),
		BorderSizePixel = 0,
		Active = true,
	}, gui)
	if marco == nil then
		pcall(function()
			gui:Destroy()
		end)
		refs.gui = nil
		return false
	end
	refs.marco = marco
	crear("UICorner", { CornerRadius = UDim.new(0, 10) }, marco)
	crear("UIStroke", { Color = Color3.fromRGB(58, 60, 72), Thickness = 1 }, marco)

	-- Barra de título (arrastrable)
	local barra = crear("Frame", {
		Name = "Barra",
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundColor3 = Color3.fromRGB(30, 31, 38),
		BorderSizePixel = 0,
		Active = true,
	}, marco)
	if barra then
		crear("UICorner", { CornerRadius = UDim.new(0, 10) }, barra)
	end

	local titulo = crear("TextButton", {
		Name = "Titulo",
		Size = UDim2.new(1, -80, 1, 0),
		BackgroundTransparency = 1,
		Text = "  Detector de Tools",
		TextColor3 = Color3.fromRGB(235, 236, 240),
		TextSize = 15,
		Font = fuente("GothamBold", "SourceSansBold"),
		TextXAlignment = Enum.TextXAlignment.Left,
		AutoButtonColor = false,
	}, barra or marco)
	refs.titulo = titulo

	local botonCerrar = crear("TextButton", {
		Name = "Cerrar",
		Size = UDim2.new(0, 28, 0, 24),
		Position = UDim2.new(1, -32, 0, 5),
		BackgroundColor3 = Color3.fromRGB(56, 34, 38),
		Text = "X",
		TextColor3 = Color3.fromRGB(240, 190, 190),
		TextSize = 14,
		Font = fuente("GothamBold", "SourceSansBold"),
		BorderSizePixel = 0,
	}, barra or marco)
	if botonCerrar then
		crear("UICorner", { CornerRadius = UDim.new(0, 6) }, botonCerrar)
		conectar(botonCerrar, "MouseButton1Click", function()
			pcall(function()
				refs.gui.Enabled = false
			end)
		end)
	end

	local botonMin = crear("TextButton", {
		Name = "Minimizar",
		Size = UDim2.new(0, 28, 0, 24),
		Position = UDim2.new(1, -64, 0, 5),
		BackgroundColor3 = Color3.fromRGB(40, 42, 50),
		Text = "–",
		TextColor3 = Color3.fromRGB(210, 212, 220),
		TextSize = 14,
		Font = fuente("GothamBold", "SourceSansBold"),
		BorderSizePixel = 0,
	}, barra or marco)

	-- Contenido (todo lo que se oculta al minimizar)
	local contenido = crear("Frame", {
		Name = "Contenido",
		Size = UDim2.new(1, 0, 1, -34),
		Position = UDim2.new(0, 0, 0, 34),
		BackgroundTransparency = 1,
	}, marco)
	refs.contenido = contenido

	local contador = crear("TextLabel", {
		Name = "Contador",
		Size = UDim2.new(1, -20, 0, 20),
		Position = UDim2.new(0, 10, 0, 4),
		BackgroundTransparency = 1,
		Text = "Escaneando...",
		TextColor3 = Color3.fromRGB(170, 174, 188),
		TextSize = 13,
		Font = fuente("Gotham", "SourceSans"),
		TextXAlignment = Enum.TextXAlignment.Left,
	}, contenido)
	refs.contador = contador

	local busqueda = crear("TextBox", {
		Name = "Busqueda",
		Size = UDim2.new(1, -20, 0, 28),
		Position = UDim2.new(0, 10, 0, 26),
		BackgroundColor3 = Color3.fromRGB(16, 17, 21),
		BorderSizePixel = 0,
		Text = "",
		PlaceholderText = "Buscar por nombre, ruta o dueño...",
		PlaceholderColor3 = Color3.fromRGB(110, 114, 126),
		TextColor3 = Color3.fromRGB(230, 232, 238),
		TextSize = 13,
		Font = fuente("Gotham", "SourceSans"),
		ClearTextOnFocus = false,
	}, contenido)
	if busqueda then
		crear("UICorner", { CornerRadius = UDim.new(0, 6) }, busqueda)
		crear("UIStroke", { Color = Color3.fromRGB(52, 54, 64), Thickness = 1 }, busqueda)
		refs.busqueda = busqueda
		conectar(busqueda, "Changed", function(prop)
			if prop == "Text" then
				estado.filtro = busqueda.Text or ""
				pintarFilas()
			end
		end)
		conectar(busqueda, "FocusLost", function()
			estado.filtro = busqueda.Text or ""
			pintarFilas()
		end)
	end

	local function boton(nombre, texto, x, color, accion)
		local b = crear("TextButton", {
			Name = nombre,
			Size = UDim2.new(0, 108, 0, 26),
			Position = UDim2.new(0, x, 0, 60),
			BackgroundColor3 = color,
			Text = texto,
			TextColor3 = Color3.fromRGB(240, 241, 245),
			TextSize = 13,
			Font = fuente("Gotham", "SourceSans"),
			BorderSizePixel = 0,
			AutoButtonColor = true,
		}, contenido)
		if b then
			crear("UICorner", { CornerRadius = UDim.new(0, 6) }, b)
			conectar(b, "MouseButton1Click", accion)
		end
		return b
	end

	boton("Escanear", "Escanear", 10, Color3.fromRGB(46, 84, 140), function()
		refrescar(true)
		notificar("Detector de Tools", string.format("Se encontraron %d herramienta(s)", #estado.lista), 3)
	end)

	boton("Copiar", "Copiar lista", 124, Color3.fromRGB(44, 46, 56), function()
		if copiarTexto(textoDeLista(estado.lista, false)) then
			notificar("Detector de Tools", "Lista copiada al portapapeles", 3)
		else
			notificar("Detector de Tools", "Portapapeles no disponible", 3)
		end
	end)

	boton("CopiarRutas", "Copiar rutas", 238, Color3.fromRGB(44, 46, 56), function()
		if copiarTexto(textoDeLista(estado.lista, true)) then
			notificar("Detector de Tools", "Rutas copiadas al portapapeles", 3)
		else
			notificar("Detector de Tools", "Portapapeles no disponible", 3)
		end
	end)

	local scroller = crear("ScrollingFrame", {
		Name = "Lista",
		Size = UDim2.new(1, -20, 1, -100),
		Position = UDim2.new(0, 10, 0, 92),
		BackgroundColor3 = Color3.fromRGB(18, 19, 23),
		BorderSizePixel = 0,
		CanvasSize = UDim2.new(0, 0, 0, 0),
		ScrollBarThickness = 6,
		ScrollBarImageColor3 = Color3.fromRGB(90, 94, 110),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
	}, contenido)
	if scroller then
		crear("UICorner", { CornerRadius = UDim.new(0, 8) }, scroller)
		refs.scroller = scroller
		refs.layout = crear("UIListLayout", {
			Padding = UDim.new(0, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}, scroller)
		crear("UIPadding", {
			PaddingTop = UDim.new(0, 6),
			PaddingBottom = UDim.new(0, 6),
		}, scroller)
	end

	-- Minimizar
	if botonMin then
		local minimizado = false
		conectar(botonMin, "MouseButton1Click", function()
			minimizado = not minimizado
			pcall(function()
				contenido.Visible = not minimizado
				marco.Size = minimizado and UDim2.new(0, 470, 0, 34) or UDim2.new(0, 470, 0, 390)
			end)
		end)
	end

	if titulo then
		hacerArrastrable(marco, titulo)
	end
	-- También se puede arrastrar desde la barra vacía.
	if barra then
		hacerArrastrable(marco, barra)
	end

	return true
end

local function cerrar()
	estado.cerrado = true
	estado.autoActivo = false

	for _, conexion in ipairs(estado.conexiones) do
		pcall(function()
			conexion:Disconnect()
		end)
	end
	estado.conexiones = {}

	if refs.gui then
		pcall(function()
			refs.gui:Destroy()
		end)
	end
	refs.gui, refs.marco, refs.contenido, refs.scroller, refs.contador = nil, nil, nil, nil, nil
end

--=====================================================================
-- 6) REFRESCO AUTOMÁTICO
--=====================================================================
local firmas = {}

local function firmaDe(entradas)
	local set = {}
	for _, e in ipairs(entradas) do
		set[e.ruta] = true
	end
	return set
end

local function compararYNotificar(nuevas, viejas)
	local agregadas, quitadas = {}, {}
	for ruta in pairs(nuevas) do
		if not viejas[ruta] then
			table.insert(agregadas, ruta)
		end
	end
	for ruta in pairs(viejas) do
		if not nuevas[ruta] then
			table.insert(quitadas, ruta)
		end
	end

	if #agregadas == 0 and #quitadas == 0 then
		return false
	end

	if CONFIG.avisarCambios then
		local partes = {}
		if #agregadas > 0 then
			table.insert(partes, "+ " .. table.concat(agregadas, ", "))
		end
		if #quitadas > 0 then
			table.insert(partes, "- " .. table.concat(quitadas, ", "))
		end
		notificar("Tools cambiaron", table.concat(partes, "   "), 4)
	end
	return true
end

local refrescoPendiente = false

function refrescar(mostrarTodo)
	local nuevas = escanear()
	local nuevasFirmas = firmaDe(nuevas)
	local cambio = compararYNotificar(nuevasFirmas, firmas)
	firmas = nuevasFirmas

	actualizarLista(nuevas)

	if CONFIG.imprimirConsola and (mostrarTodo or cambio) then
		imprimir(nuevas)
	end
	return nuevas
end

local function programarRefresco()
	if refrescoPendiente or estado.cerrado then
		return
	end
	refrescoPendiente = true
	local esperar = (type(task) == "table" and type(task.delay) == "function") and task.delay or nil
	if esperar then
		esperar(0.35, function()
			refrescoPendiente = false
			refrescar(false)
		end)
	else
		refrescoPendiente = false
		refrescar(false)
	end
end

local jugadoresEnganchados = {}
local contenedoresEnganchados = {}

-- Escucha una mochila o un personaje (una sola vez por contenedor).
local function engancharContenedor(contenedor, etiqueta)
	if contenedor == nil or contenedoresEnganchados[contenedor] then
		return
	end
	contenedoresEnganchados[contenedor] = true

	conectar(contenedor, "ChildAdded", function(hijo)
		if esTool(hijo) then
			notificar("Detector de Tools", etiqueta .. ": " .. propiedad(hijo, "Name", "?"), 3)
			programarRefresco()
		end
	end)

	conectar(contenedor, "ChildRemoved", function(hijo)
		if esTool(hijo) then
			programarRefresco()
		end
	end)

	programarRefresco()
end

-- Engancha a un jugador (mochila + personaje actuales y futuros).
local function engancharJugador(jugador)
	if jugador == nil or jugadoresEnganchados[jugador] then
		return
	end
	jugadoresEnganchados[jugador] = true

	conectar(jugador, "CharacterAdded", function(personaje)
		engancharContenedor(personaje, "Nueva tool equipada")
		programarRefresco()
	end)

	conectar(jugador, "CharacterRemoving", function()
		programarRefresco()
	end)

	-- Lo que ya existe ahora mismo.
	engancharContenedor(propiedad(jugador, "Character", nil), "Nueva tool equipada")
	engancharContenedor(intentar(function()
		return jugador:FindFirstChild("Backpack")
	end), "Apareció")

	-- Y lo que aparezca un poco más tarde (el personaje tarda en cargar).
	if type(task) == "table" and type(task.spawn) == "function" then
		task.spawn(function()
			for _, nombre in ipairs({ "Backpack", "Character" }) do
				local contenedor = intentar(function()
					return jugador:WaitForChild(nombre, 30)
				end)
				engancharContenedor(contenedor, "Apareció")
			end
		end)
	end
end

local function conectarEventos()
	local Players = servicio("Players")

	if Players then
		conectar(Players, "PlayerAdded", function(jugador)
			engancharJugador(jugador)
		end)

		conectar(Players, "PlayerRemoving", function()
			programarRefresco()
		end)

		-- ¡Importante! Los jugadores que YA están en la partida no disparan
		-- PlayerAdded: hay que engancharlos a mano recorriendo la lista.
		local jugadores = intentar(function()
			return Players:GetPlayers()
		end)
		if type(jugadores) == "table" then
			for _, jugador in ipairs(jugadores) do
				engancharJugador(jugador)
			end
		end
	end

	-- El mundo y las plantillas: solo reaccionamos a Tools nuevas.
	for _, nombre in ipairs({ "Workspace", "ReplicatedStorage", "StarterPack" }) do
		local contenedor = servicio(nombre)
		if contenedor then
			conectar(contenedor, "DescendantAdded", function(hijo)
				if esTool(hijo) then
					programarRefresco()
				end
			end)
			conectar(contenedor, "DescendantRemoving", function(hijo)
				if esTool(hijo) then
					programarRefresco()
				end
			end)
		end
	end
end

local function iniciarAuto()
	if not CONFIG.autoRefrescar or estado.autoActivo then
		return
	end
	if type(task) ~= "table" or type(task.spawn) ~= "function" then
		return
	end
	estado.autoActivo = true

	task.spawn(function()
		while estado.autoActivo and not estado.cerrado do
			task.wait(CONFIG.intervaloAuto)
			if not estado.autoActivo or estado.cerrado then
				break
			end
			pcall(refrescar, false)
		end
	end)
end

--=====================================================================
-- 7) API PÚBLICA  (_G.DetectorTools)
--=====================================================================
function API.escanear()
	return escanear()
end

function API.nombres(entradas)
	entradas = entradas or estado.lista
	if entradas == nil or #entradas == 0 then
		entradas = escanear()
	end
	local nombres = {}
	for _, e in ipairs(entradas) do
		table.insert(nombres, e.nombre)
	end
	return nombres
end

function API.rutas()
	local rutas = {}
	for _, e in ipairs(escanear()) do
		table.insert(rutas, e.ruta)
	end
	return rutas
end

function API.imprimir()
	return imprimir(escanear())
end

function API.mostrar()
	if refs.gui == nil then
		if crearPanel() == false then
			return false
		end
	end
	mostrarPanel()
	refrescar(false)
	return true
end

function API.json()
	local datos = escanear()
	local limpio = {}
	for _, e in ipairs(datos) do
		table.insert(limpio, {
			nombre = e.nombre,
			clase = e.clase,
			ruta = e.ruta,
			dueno = e.dueno,
			contenedor = e.contenedor,
			equipada = e.equipada,
		})
	end
	local HttpService = servicio("HttpService")
	if HttpService == nil then
		return nil
	end
	local ok, json = pcall(function()
		return HttpService:JSONEncode(limpio)
	end)
	return ok and json or nil
end

API.detener = cerrar
API.cerrar = cerrar

-- Si ya se ejecutó antes, limpiamos la versión anterior.
if type(_G.DetectorTools) == "table" and type(_G.DetectorTools.cerrar) == "function" then
	pcall(_G.DetectorTools.cerrar)
end
_G.DetectorTools = API

--=====================================================================
-- 8) ARRANQUE
--=====================================================================
do
	local inicial = escanear()
	estado.lista = inicial
	firmas = firmaDe(inicial)

	if CONFIG.imprimirConsola then
		imprimir(inicial)
	end

	if #inicial == 0 then
		notificar("Detector de Tools", "No se encontró ninguna Tool visible.", 4)
	else
		local algunos = {}
		for i = 1, math.min(#inicial, 6) do
			table.insert(algunos, inicial[i].nombre)
		end
		local sufijo = #inicial > 6 and "..." or ""
		notificar(
			"Detector de Tools",
			string.format("%d tool(s): %s%s", #inicial, table.concat(algunos, ", "), sufijo),
			6
		)
	end

	if CONFIG.mostrarGUI then
		local ok = pcall(crearPanel)
		if ok and refs.gui then
			pintarFilas()
		else
			print("[Detector de Tools] No se pudo crear el panel (CoreGui/PlayerGui bloqueados).")
			print("[Detector de Tools] Modo consola activo: mira la lista de arriba o llama a _G.DetectorTools.imprimir().")
		end
	end

	pcall(conectarEventos)
	pcall(iniciarAuto)
end
