--[[=====================================================================
	 PRUEBAS DEL DETECTOR DE TOOLS
======================================================================]]

local mock = _G.__mock
local S = mock.servicios

local NOMBRES_ESPERADOS = {
	"ArcoDePlasma",
	"EspadaInicial",
	"EspadaLegendaria",
	"LlaveDorada",
	"M4A1",
	"PicoDeMinero",
	"PlantillaArma",
}
local TOTAL = 7

local function buscarEntrada(lista, nombre)
	for _, e in ipairs(lista) do
		if e.nombre == nombre then
			return e
		end
	end
	return nil
end

local function impresionContiene(texto)
	for _, linea in ipairs(mock.prints) do
		if string.find(linea, texto, 1, true) then
			return true
		end
	end
	return false
end

local function notificacionContiene(texto)
	for _, n in ipairs(mock.notificaciones) do
		local t = tostring(n.Text or "")
		if string.find(t, texto, 1, true) then
			return true
		end
	end
	return false
end

--=====================================================================
-- FASE 1
--=====================================================================
function fase1()
	print("")
	print("=========== FASE 1: detección básica ===========")

	local API = _G.DetectorTools
	assertVerdad(type(API) == "table", "la API _G.DetectorTools existe")

	local lista = API.escanear()
	assertEq(#lista, TOTAL, "el escaneo encuentra las " .. TOTAL .. " tools del mundo de prueba")
	assertEq(nombresDe(lista), NOMBRES_ESPERADOS, "los nombres detectados son exactamente los esperados")

	local arco = buscarEntrada(lista, "ArcoDePlasma")
	assertVerdad(arco ~= nil, "se encuentra la tool equipada (ArcoDePlasma)")
	assertEq(arco and arco.equipada, true, "ArcoDePlasma figura como EQUIPADA")
	assertEq(arco and arco.dueno, "TuJugador", "ArcoDePlasma pertenece a TuJugador")
	assertEq(arco and arco.contenedor, "Personaje (equipada)", "contenedor correcto para la tool equipada")
	assertEq(arco and arco.clase, "Tool", "la clase detectada es Tool")

	local espada = buscarEntrada(lista, "EspadaLegendaria")
	assertEq(espada and espada.contenedor, "Backpack (guardada)", "EspadaLegendaria figura guardada en la mochila")
	assertEq(espada and espada.tooltip, "Espada épica de prueba", "se lee el ToolTip de la tool")

	local llave = buscarEntrada(lista, "LlaveDorada")
	assertEq(llave and llave.dueno, nil, "LlaveDorada no tiene dueño (está en el mapa)")
	assertEq(llave and llave.ruta, "Workspace.Cofre.LlaveDorada", "se calcula bien la ruta de la tool del mapa")
	assertEq(llave and llave.contenedor, "Workspace", "contenedor correcto para la tool del mapa")

	local m4 = buscarEntrada(lista, "M4A1")
	assertEq(m4 and m4.dueno, "Amigo123", "se detectan tools de otros jugadores")

	-- Sin duplicados (el personaje también está en Workspace)
	local repetidos = {}
	for _, e in ipairs(lista) do
		repetidos[e.ruta] = (repetidos[e.ruta] or 0) + 1
	end
	local duplicadas = 0
	for _, n in pairs(repetidos) do
		if n > 1 then
			duplicadas = duplicadas + 1
		end
	end
	assertEq(duplicadas, 0, "no hay tools contadas dos veces (jugador + Workspace)")

	-- La HopperBin no cuenta por defecto
	assertEq(buscarEntrada(lista, "BinLinterna"), nil, "la HopperBin se ignora con la config por defecto")

	-- Nombres y rutas
	assertEq(#API.nombres(), TOTAL, "API.nombres() devuelve todos los nombres")
	assertEq(#API.rutas(), TOTAL, "API.rutas() devuelve todas las rutas")
	local json = API.json()
	assertVerdad(type(json) == "string" and string.find(json, "LlaveDorada", 1, true) ~= nil,
		"API.json() exporta la lista como texto")

	-- Salida por consola
	assertVerdad(impresionContiene("DETECTOR DE TOOLS"), "se imprime el encabezado en consola")
	assertVerdad(impresionContiene("7 herramienta(s)"), "la consola dice cuántas tools se encontraron")
	assertVerdad(impresionContiene("LlaveDorada"), "las tools salen listadas en la consola con su nombre")
	assertVerdad(impresionContiene("Workspace.Cofre.LlaveDorada"), "la consola muestra la ruta de cada tool")

	-- Notificaciones
	assertVerdad(notificacionContiene("7 tool"), "se avisa por notificación cuántas tools hay")

	-- Panel
	assertEq(buscarPanel(), 1, "se crea un solo panel en CoreGui")
	assertEq(contarFilas(), TOTAL, "el panel muestra una fila por tool")
	assertVerdad(hayLayout(), "el UIListLayout sigue vivo tras pintar la lista")

	print("")
	print("=========== FASE 1b: filtro y cambios en vivo ===========")

	local gui = S.CoreGui:FindFirstChild("DetectorDeTools")
	local busqueda = gui.Marco.Contenido.Busqueda
	busqueda.Text = "llave"
	mock.disparar(busqueda.Changed, "Text")
	assertEq(contarFilas(), 1, "el buscador filtra por nombre")
	busqueda.Text = "amigo123"
	mock.disparar(busqueda.Changed, "Text")
	assertEq(contarFilas(), 1, "el buscador filtra por dueño (todo en minúsculas)")
	busqueda.Text = ""
	mock.disparar(busqueda.Changed, "Text")
	assertEq(contarFilas(), TOTAL, "al borrar el filtro vuelven a salir todas")

	-- Aparece una tool nueva en la mochila
	local nueva = mock.nuevo("Tool", "NuevaPistola")
	nueva.Parent = _G.mundoTest.mochila
	mock.correrTareas()
	assertEq(#_G.DetectorTools.escanear(), TOTAL + 1, "al recogerse una tool nueva el escaneo la detecta")
	assertEq(contarFilas(), TOTAL + 1, "el panel se actualiza solo")
	assertVerdad(notificacionContiene("Apareció: NuevaPistola"), "se notifica la tool nueva")
	assertVerdad(contiene(_G.DetectorTools.nombres(), "NuevaPistola"), "el nombre nuevo entra en la API")

	-- Desaparece la tool
	_G.mundoTest.mochila:FindFirstChild("NuevaPistola").Parent = nil
	mock.correrTareas()
	assertEq(#_G.DetectorTools.escanear(), TOTAL, "al perder la tool desaparece de la lista")

	-- Refresco automático (corrutina de fondo)
	assertVerdad(#mock.hilos >= 1, "el refresco automático arrancó un hilo de fondo")
	local vivo = true
	for _, co in ipairs(mock.hilos) do
		if coroutine.status(co) == "suspended" then
			local ok, err = coroutine.resume(co)
			if not ok then
				vivo = false
				print("  error en el hilo de auto-refresco: " .. tostring(err))
			end
		end
	end
	assertVerdad(vivo, "el hilo de auto-refresco se ejecuta sin errores")

	print("")
	print("=========== FASE 1c: cerrar / reabrir / re-ejecutar ===========")

	_G.DetectorTools.cerrar()
	assertEq(buscarPanel(), 0, "cerrar() elimina el panel")

	assertVerdad(_G.DetectorTools.mostrar() == true, "mostrar() vuelve a abrir el panel")
	assertEq(buscarPanel(), 1, "solo hay un panel tras reabrirlo")
	assertEq(contarFilas(), TOTAL, "la lista se vuelve a pintar al reabrir")

	-- Se ejecuta el script otra vez (lo hace el runner): no debe duplicar nada
end

function fase1_reejecutado()
	print("")
	print("=========== FASE 1d: re-ejecución del script ===========")
	assertEq(buscarPanel(), 1, "re-ejecutar el script no duplica el panel")
	assertEq(contarFilas(), TOTAL, "la lista sigue correcta tras re-ejecutar")
	assertEq(#_G.DetectorTools.escanear(), TOTAL, "el escaneo sigue correcto tras re-ejecutar")
	assertEq(#mock.notificaciones > 0, true, "la versión nueva sigue notificando")
end

--=====================================================================
-- FASE 2: con CONFIG.incluirBackpackItems = true
--=====================================================================
function fase2()
	print("")
	print("=========== FASE 2: CONFIG.incluirBackpackItems = true ===========")
	local lista = _G.DetectorTools.escanear()
	assertEq(#lista, TOTAL + 1, "con incluirBackpackItems = true también cuenta la HopperBin")
	assertVerdad(buscarEntrada(lista, "BinLinterna") ~= nil, "la HopperBin sale en la lista")
	assertEq(contarFilas(), TOTAL + 1, "el panel la muestra también")
end


--=====================================================================
-- FASE 3: el juego bloquea CoreGui -> debe caer a PlayerGui
--=====================================================================
function fase3()
	print("")
	print("=========== FASE 3: CoreGui bloqueado por el juego ===========")
	local yo = S.Players.LocalPlayer
	local playerGui = yo:FindFirstChild("PlayerGui")

	assertEq(buscarPanel("CoreGui"), 0, "no se pudo crear nada en CoreGui")
	assertEq(buscarPanel("Players"), 0, "el panel no acaba colgado dentro de Players")
	assertVerdad(playerGui:FindFirstChild("DetectorDeTools") ~= nil, "el panel se crea en PlayerGui como respaldo")
	assertEq(contarFilas(), TOTAL, "la lista funciona igual en PlayerGui")
	assertVerdad(hayLayout(), "el layout también funciona en PlayerGui")

	local gui = playerGui:FindFirstChild("DetectorDeTools")
	local boton = gui.Marco.Contenido:FindFirstChild("Escanear")
	assertVerdad(boton ~= nil, "el botón Escanear existe")
	mock.disparar(boton.MouseButton1Click)
	assertEq(contarFilas(), TOTAL, "el botón Escanear repinta la lista sin errores")
end
