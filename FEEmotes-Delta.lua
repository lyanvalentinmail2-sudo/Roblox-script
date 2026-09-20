-- FE EMOTES · ARCHIVO ÚNICO / EJECUCIÓN LOCAL
-- Generado por tools/standalone.py. No editar este archivo: modifica src/ y regenera.
-- Pega TODO el archivo en tu entorno de ejecución Lua cliente.
-- No requiere Studio, remotos del servidor, claves, descargas de código ni archivos auxiliares.
-- Compatibilidad con Delta NO verificada en un dispositivo real.
-- No garantiza replicación FE ni evita permisos, restricciones o moderación de Roblox.
-- Necesita avatar R15 y acceso a GetObjects para extraer las animaciones de catálogo.

-- FE Emotes / GLASS COMPACT • biblioteca densa, cristal translúcido y favoritos dorados.
local Players = game:GetService("Players")
local AvatarEditorService = game:GetService("AvatarEditorService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local previousGui = playerGui:FindFirstChild("FEEmotesStandaloneGui")
if previousGui then previousGui:Destroy() end
local Config = (function()
-- Configuración compartida. Los permisos se validan siempre en el servidor.
return {
	Title = "FE Emotes",
	MinSpeed = 0.25,
	MaxSpeed = 3,
	SpeedStep = 0.25,
	MaxEquipped = 8,
	MaxCacheEntries = 128,
	LoadTimeout = 15,
	-- Catálogo inicial: IDs de emote del catálogo, NO IDs internos de animación.
	Featured = {
		{ Id = 3576686446, Name = "Hello", Creator = "Roblox", IsRoblox = true },
		{ Id = 3576823880, Name = "Point2", Creator = "Roblox", IsRoblox = true },
		{ Id = 3576968026, Name = "Shrug", Creator = "Roblox", IsRoblox = true },
		{ Id = 3576747102, Name = "Applaud", Creator = "Roblox", IsRoblox = true },
		{ Id = 3716636630, Name = "Tilt", Creator = "Roblox", IsRoblox = true },
		{ Id = 3360689775, Name = "Salute", Creator = "Roblox", IsRoblox = true },
	},
}

end)()
local Validation = (function()
-- Funciones puras: también se ejecutan en las pruebas fuera de Studio.
local Validation = {}

function Validation.assetId(value)
	return type(value) == "number"
		and value == value
		and value > 0
		and value <= 9007199254740991
		and value % 1 == 0
end

function Validation.speed(value, minimum, maximum)
	return type(value) == "number" and value == value and value >= minimum and value <= maximum
end

function Validation.parseId(text)
	if type(text) ~= "string" then
		return nil
	end
	local digits = text:match("^%s*(%d+)%s*$")
		or text:match("^https://www%.roblox%.com/catalog/(%d+)")
		or text:match("^https://www%.roblox%.com/[%a%-]+/catalog/(%d+)")
	local id = tonumber(digits)
	return Validation.assetId(id) and id or nil
end

function Validation.isRoblox(creatorId, creatorType)
	-- Los grupos tienen IDs independientes: el grupo 1 no es el usuario Roblox.
	return tonumber(creatorId) == 1 and (creatorType == "User" or creatorType == 1)
end

function Validation.consume(bucket, now, capacity, refill)
	bucket.tokens = math.min(capacity, bucket.tokens + math.max(0, now - bucket.time) * refill)
	bucket.time = now
	if bucket.tokens < 1 then
		return false
	end
	bucket.tokens = bucket.tokens - 1
	return true
end

return Validation

end)()
local Favorites = (function()
-- Biblioteca local, independiente del catálogo paginado y de los ocho equipados.
local Favorites = {}

function Favorites.new(validation, limit)
	local entries = {}
	local maximum = limit or 120
	local library = {}
	local function sanitize(item)
		if
			type(item) ~= "table"
			or not validation.assetId(item.Id)
			or type(item.Name) ~= "string"
			or #item.Name == 0
			or #item.Name > 200
		then
			return nil
		end
		return {
			Id = item.Id,
			Name = item.Name,
			Creator = type(item.Creator) == "string" and #item.Creator <= 200 and item.Creator or "Creador",
			IsRoblox = item.IsRoblox == true,
		}
	end
	function library:contains(id)
		for _, entry in ipairs(entries) do
			if entry.Id == id then
				return true
			end
		end
		return false
	end
	function library:count()
		return #entries
	end
	function library:toggle(item)
		local safe = sanitize(item)
		if not safe then
			return false, "invalid"
		end
		for i, entry in ipairs(entries) do
			if entry.Id == safe.Id then
				table.remove(entries, i)
				return true, "removed"
			end
		end
		if #entries >= maximum then
			return false, "full"
		end
		table.insert(entries, 1, safe)
		return true, "added"
	end
	function library:list(query)
		local result = {}
		local needle = type(query) == "string" and query:lower():match("^%s*(.-)%s*$") or ""
		for _, entry in ipairs(entries) do
			if
				needle == ""
				or entry.Name:lower():find(needle, 1, true)
				or entry.Creator:lower():find(needle, 1, true)
				or tostring(entry.Id) == needle
			then
				table.insert(result, table.clone(entry))
			end
		end
		return result
	end
	function library:export()
		return { Version = 1, Items = self:list() }
	end
	function library:restore(payload)
		if type(payload) ~= "table" or payload.Version ~= 1 or type(payload.Items) ~= "table" then
			return false
		end
		local imported, seen = {}, {}
		-- Solo se examinan 120 elementos; payloads enormes no bloquean la interfaz.
		for i = 1, math.min(#payload.Items, maximum) do
			local safe = sanitize(payload.Items[i])
			if safe and not seen[safe.Id] then
				table.insert(imported, safe)
				seen[safe.Id] = true
			end
		end
		entries = imported
		return true
	end
	return library
end

return Favorites

end)()
local HubState = (function()
-- Tickets de transición: un tween antiguo nunca debe ocultar una ventana reabierta.
local HubState = {}
function HubState.new()
	local state = { mode = "minimized", revision = 0 }
	function state:set(mode)
		if self.mode == "destroyed" or (mode ~= "open" and mode ~= "minimized" and mode ~= "closed") then
			return nil
		end
		self.mode = mode
		self.revision = self.revision + 1
		return self.revision
	end
	function state:current(ticket)
		return self.mode ~= "destroyed" and self.revision == ticket
	end
	function state:destroy()
		self.mode = "destroyed"
		self.revision = self.revision + 1
	end
	return state
end
return HubState

end)()
local HubLayout = (function()
-- Geometría compartida y comprobable sin el motor: ventanas pequeñas, tarjetas 1:1.
local HubLayout = {
	MaxWidth = 400,
	MaxHeight = 560,
	Margin = 12,
	Gap = 6,
}

function HubLayout.window(width, height)
	return math.max(1, math.min(HubLayout.MaxWidth, width - HubLayout.Margin * 2)),
		math.max(1, math.min(HubLayout.MaxHeight, height - HubLayout.Margin * 2))
end

function HubLayout.grid(width, count)
	local columns = width >= 360 and 4 or (width >= 258 and 3 or (width >= 170 and 2 or 1))
	local side = math.max(1, math.floor((width - HubLayout.Gap * (columns - 1)) / columns))
	local rows = math.ceil(math.max(0, count) / columns)
	return columns, side, math.max(0, rows * (side + HubLayout.Gap) - HubLayout.Gap)
end

return HubLayout

end)()
local EmoteDetails = (function()
-- Detalles y compra de assets del catálogo. Nunca compra automáticamente.
-- El evento de cierre del prompt NO demuestra que la compra se haya procesado.
local EmoteDetails = {}

function EmoteDetails.new(marketplace, player, validation, onChanged)
	local state = { loading = false, canBuy = false, purchasing = false }
	local revision = 0
	local destroyed = false
	local pendingPrompt = nil
	local controller = {}
	local function emit(message, isError)
		if destroyed then
			return
		end
		state.message = message
		state.isError = isError == true
		state.purchasing = pendingPrompt ~= nil
		local snapshot = table.clone(state)
		if state.item then
			snapshot.item = table.clone(state.item)
		end
		onChanged(snapshot)
	end
	function controller:clear()
		revision = revision + 1
		state = { loading = false, canBuy = false, purchasing = pendingPrompt ~= nil }
	end
	function controller:select(item)
		if destroyed or type(item) ~= "table" or not validation.assetId(item.Id) then
			return false
		end
		item = table.clone(item) -- El llamador no puede cambiar el ID de una consulta pendiente.
		revision = revision + 1
		local token = revision
		state =
			{ item = table.clone(item), loading = true, canBuy = false, purchasing = pendingPrompt ~= nil }
		emit("Consultando precio y disponibilidad…")
		local function current()
			return not destroyed and revision == token
		end
		task.delay(12, function()
			if current() and state.loading then
				revision = revision + 1
				state.loading = false
				emit("La consulta tardó demasiado. Cierra y vuelve a seleccionar el emote.", true)
			end
		end)
		task.spawn(function()
			local ok, info = pcall(function()
				return marketplace:GetProductInfoAsync(item.Id, Enum.InfoType.Asset)
			end)
			if not current() then
				return
			end
			if not ok or type(info) ~= "table" then
				state.loading = false
				emit("No se pudo consultar el artículo. Vuelve a seleccionarlo para reintentar.", true)
				return
			end
			if info.AssetTypeId ~= Enum.AssetType.EmoteAnimation.Value then
				state.loading = false
				emit("Este ID no corresponde a un emote del catálogo.", true)
				return
			end
			if type(info.Name) == "string" then
				state.item.Name = info.Name
			end
			local creator = info.Creator or {}
			state.item.Creator = creator.Name or state.item.Creator
			state.item.IsRoblox =
				validation.isRoblox(creator.CreatorTargetId or creator.Id, creator.CreatorType)
			state.forSale = info.IsForSale == true
			if
				type(info.PriceInRobux) == "number"
				and info.PriceInRobux >= 0
				and info.PriceInRobux < math.huge
			then
				state.price = info.PriceInRobux
			end
			local checked, owned = pcall(function()
				return marketplace:PlayerOwnsAssetAsync(player, item.Id)
			end)
			if not current() then
				return
			end
			state.loading = false
			if not checked or type(owned) ~= "boolean" then
				emit("No se pudo comprobar tu inventario. Vuelve a seleccionar el emote.", true)
				return
			end
			state.owned = owned
			state.canBuy = state.forSale and not owned
			if owned then
				emit("Ya tienes este emote. Puedes desplegarlo.")
			elseif not state.forSale then
				emit("Este emote no está a la venta directa.")
			else
				emit("Precio orientativo. Confirma el precio final en la ventana de Roblox.")
			end
		end)
		return true
	end
	function controller:purchase()
		if destroyed or not state.item or not state.canBuy or state.loading then
			return false
		end
		if pendingPrompt then
			emit("Ya hay una ventana de compra abierta. Ciérrala en Roblox primero.")
			return false
		end
		local id, token = state.item.Id, revision
		pendingPrompt = id
		emit("Abriendo la confirmación oficial de Roblox…")
		-- Solo se llega aquí por una pulsación explícita en Comprar.
		task.spawn(function()
			if destroyed or revision ~= token then
				pendingPrompt = nil
				if not destroyed then
					emit()
				end
				return
			end
			local ok = pcall(function()
				marketplace:PromptPurchase(player, id)
			end)
			if not ok then
				pendingPrompt = nil
				if not destroyed then
					emit("Roblox o este entorno no permiten abrir la compra aquí.", true)
				end
			end
		end)
		return true
	end
	local finished = marketplace.PromptPurchaseFinished:Connect(function(buyer, id, purchased)
		if destroyed or buyer ~= player or id ~= pendingPrompt then
			return
		end
		pendingPrompt = nil
		if purchased and state.item and state.item.Id == id then
			-- Verificar propiedad: el booleano del evento no es un recibo.
			controller:select(state.item)
		else
			emit("Ventana de compra cerrada. No se ha confirmado ninguna compra.")
		end
	end)
	function controller:Destroy()
		if destroyed then
			return
		end
		destroyed = true
		revision = revision + 1
		finished:Disconnect()
	end
	return controller
end

return EmoteDetails

end)()
local createController = (function()
-- Controlador local. No usa remotos del juego ni altera otros jugadores.
-- GetObjects depende del contexto de ejecución; nunca se parentan los assets cargados.
return function(player, Config, Validation)
	local MarketplaceService = game:GetService("MarketplaceService")
	local changed = Instance.new("BindableEvent")
	local controller = { Changed = changed.Event }
	local state = {
		equipped = {},
		speed = 1,
		locked = false,
		paused = false,
		loading = false,
		settingsRevision = 0,
	}
	local destroyed = false
	local revision = 0
	local pendingLoads = 0
	local track, stoppedConnection
	local characterConnections = {}
	local lifetimeConnections = {}
	local cache, cacheOrder = {}, {}

	local function emit(message, isError)
		if destroyed then
			return
		end
		changed:Fire({
			active = state.active,
			equipped = table.clone(state.equipped),
			speed = state.speed,
			locked = state.locked,
			paused = state.paused,
			loading = state.loading,
			settingsRevision = state.settingsRevision,
			message = message,
			isError = isError == true,
		})
	end
	local function clearTrack()
		if stoppedConnection then
			stoppedConnection:Disconnect()
			stoppedConnection = nil
		end
		if track then
			local previous = track
			track = nil
			previous:Stop(0.15)
			task.delay(0.2, function()
				previous:Destroy()
			end)
		end
		state.active = nil
	end
	local function stop(message)
		revision = revision + 1
		state.loading = false
		clearTrack()
		emit(message)
	end
	local function humanoidFor(character)
		if not character or character ~= player.Character then
			return nil
		end
		local humanoid = character:FindFirstChildOfClass("Humanoid")
		return humanoid and humanoid.Health > 0 and humanoid or nil
	end
	local function moving(humanoid)
		local root = humanoid.RootPart
		return root
			and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 1
	end
	local function resolve(id, animationRequired)
		local entry = cache[id]
		if not entry then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset)
			end)
			if not ok then
				return nil, "No se pudo consultar el ID. Revisa tu conexión e inténtalo de nuevo."
			end
			if info.AssetTypeId ~= Enum.AssetType.EmoteAnimation.Value then
				return nil, "Usa el ID de un emote del catálogo, no el de un accesorio o animación."
			end
			local creator = info.Creator or {}
			entry = {
				item = {
					Id = id,
					Name = info.Name,
					Creator = creator.Name or "Creador",
					IsRoblox = Validation.isRoblox(
						creator.CreatorTargetId or creator.Id,
						creator.CreatorType
					),
				},
			}
			cache[id] = entry
			table.insert(cacheOrder, id)
			while #cacheOrder > Config.MaxCacheEntries do
				cache[table.remove(cacheOrder, 1)] = nil
			end
		end
		if animationRequired and not entry.animation then
			local ok, objects = pcall(function()
				return game:GetObjects("rbxassetid://" .. tostring(id))
			end)
			if not ok or type(objects) ~= "table" then
				return nil, "Este entorno no permite cargar el emote (GetObjects/permisos). Prueba otro."
			end
			local animationId
			-- Solo leer AnimationId; no insertar modelos, ejecutar scripts ni require(assetId).
			for _, object in ipairs(objects) do
				local animation = object:IsA("Animation") and object
					or object:FindFirstChildWhichIsA("Animation", true)
				if animation and animation.AnimationId ~= "" then
					animationId = animation.AnimationId
				end
			end
			for _, object in ipairs(objects) do
				object:Destroy()
			end
			if not animationId then
				return nil, "El asset no contiene una animación de emote compatible."
			end
			entry.animation = animationId
		end
		return entry
	end
	local function perform(action, id)
		if state.loading or pendingLoads >= 2 then
			emit("Espera a que termine la carga o pulsa detener.", true)
			return
		end
		revision = revision + 1
		local token = revision
		local character = player.Character
		local function current()
			return not destroyed and revision == token and character == player.Character
		end
		state.loading = true
		pendingLoads = pendingLoads + 1
		emit(action == "Play" and "Cargando emote…" or "Equipando…")
		task.delay(Config.LoadTimeout, function()
			if current() and state.loading then
				revision = revision + 1
				state.loading = false
				emit("La carga tardó demasiado. Puedes reintentar.", true)
			end
		end)
		task.spawn(function()
			local candidate
			local ok, failure = pcall(function()
				local entry, problem = resolve(id, action == "Play")
				if not current() then
					return
				end
				if not entry then
					state.loading = false
					emit(problem, true)
					return
				end
				if action == "Equip" then
					table.insert(state.equipped, entry.item)
					state.loading = false
					emit("Equipado en tu acceso rápido local.")
					return
				end
				local humanoid = humanoidFor(character)
				if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
					state.loading = false
					emit("Necesitas un personaje R15 vivo.", true)
					return
				end
				local animator = humanoid:FindFirstChildOfClass("Animator")
				if not animator then
					state.loading = false
					emit("Tu personaje no tiene Animator. Espera a reaparecer y reintenta.", true)
					return
				end
				local animation = Instance.new("Animation")
				animation.AnimationId = entry.animation
				local loaded, result = pcall(function()
					return animator:LoadAnimation(animation)
				end)
				animation:Destroy()
				if not loaded then
					error("No se pudo cargar AnimationTrack")
				end
				candidate = result
				local deadline = os.clock() + 8
				while candidate.Length == 0 and current() and os.clock() < deadline do
					task.wait(0.1)
				end
				if not current() then
					return
				end
				if candidate.Length == 0 or not humanoidFor(character) then
					error("La animación no está disponible o el personaje cambió")
				end
				if not state.locked and moving(humanoid) then
					state.loading = false
					emit("Detente o activa Mantener al moverte.", true)
					return
				end
				clearTrack()
				candidate.Priority = Enum.AnimationPriority.Action
				candidate.Looped = true
				candidate:Play(0.15, 1, state.paused and 0 or state.speed)
				track, candidate = candidate, nil
				state.active = entry.item
				state.loading = false
				local playing = track
				stoppedConnection = track.Stopped:Connect(function()
					if track == playing then
						clearTrack()
						emit("Emote finalizado.")
					end
				end)
				emit("Reproducción local · visibilidad a otros no garantizada.")
			end)
			pendingLoads = pendingLoads - 1
			if candidate then
				candidate:Destroy()
			end
			if not ok and current() then
				state.loading = false
				warn("[FE Emotes / local]", failure)
				emit("No se pudo reproducir. El juego o Roblox pueden restringir esta animación.", true)
			end
		end)
	end
	function controller:Dispatch(request)
		if destroyed or type(request) ~= "table" then
			return
		end
		local action = request.action
		if action == "Sync" then
			emit()
		elseif action == "Stop" then
			stop("Emote detenido.")
		elseif action == "Settings" then
			if
				not Validation.speed(request.speed, Config.MinSpeed, Config.MaxSpeed)
				or type(request.locked) ~= "boolean"
				or type(request.paused) ~= "boolean"
				or not Validation.assetId(request.settingsRevision)
				or request.settingsRevision <= state.settingsRevision
			then
				return
			end
			state.speed, state.locked, state.paused = request.speed, request.locked, request.paused
			state.settingsRevision = request.settingsRevision
			if track then
				track:AdjustSpeed(state.paused and 0 or state.speed)
				local humanoid = humanoidFor(player.Character)
				if not state.locked and humanoid and moving(humanoid) then
					stop("Emote detenido al moverte.")
					return
				end
			end
			emit()
		elseif (action == "Play" or action == "Equip") and Validation.assetId(request.id) then
			if action == "Equip" then
				if state.loading then
					emit("Espera a que termine la carga.", true)
					return
				end
				for i, item in ipairs(state.equipped) do
					if item.Id == request.id then
						table.remove(state.equipped, i)
						emit("Emote retirado del acceso rápido.")
						return
					end
				end
				if #state.equipped >= Config.MaxEquipped then
					emit("Retira un emote: los 8 espacios están ocupados.", true)
					return
				end
			end
			perform(action, request.id)
		end
	end
	local function disconnectCharacter()
		for _, connection in ipairs(characterConnections) do
			connection:Disconnect()
		end
		characterConnections = {}
	end
	local function onCharacter(character)
		disconnectCharacter()
		stop()
		local humanoid = character:WaitForChild("Humanoid", 10)
		if destroyed or player.Character ~= character or not humanoid then
			return
		end
		table.insert(
			characterConnections,
			humanoid.Running:Connect(function(speed)
				if speed > 0.75 and track and not state.locked then
					stop("Emote detenido al moverte.")
				end
			end)
		)
		table.insert(
			characterConnections,
			humanoid.StateChanged:Connect(function(_, newState)
				if
					track
					and not state.locked
					and (
						newState == Enum.HumanoidStateType.Jumping
						or newState == Enum.HumanoidStateType.Freefall
						or newState == Enum.HumanoidStateType.Swimming
					)
				then
					stop("Emote detenido al moverte.")
				end
			end)
		)
		table.insert(
			characterConnections,
			humanoid.Died:Connect(function()
				stop()
			end)
		)
	end
	table.insert(lifetimeConnections, player.CharacterAdded:Connect(onCharacter))
	table.insert(
		lifetimeConnections,
		player.CharacterRemoving:Connect(function()
			disconnectCharacter()
			stop()
		end)
	)
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	function controller:Destroy()
		if destroyed then
			return
		end
		destroyed = true
		revision = revision + 1
		clearTrack()
		disconnectCharacter()
		for _, connection in ipairs(lifetimeConnections) do
			connection:Disconnect()
		end
		changed:Destroy()
	end
	return controller
end

end)()
local remote = createController(player, Config, Validation)

local C = {
	background = Color3.fromRGB(5, 5, 6),
	surface = Color3.fromRGB(15, 15, 17),
	elevated = Color3.fromRGB(26, 26, 29),
	stroke = Color3.fromRGB(60, 60, 65),
	text = Color3.fromRGB(245, 245, 247),
	muted = Color3.fromRGB(184, 188, 198),
	favorite = Color3.fromRGB(255, 211, 84),
	accent = Color3.fromRGB(237, 237, 241),
	selected = Color3.fromRGB(226, 226, 231),
	error = Color3.fromRGB(255, 164, 174),
}
-- Solo tweens activos; se cancelan al reemplazarlos y al destruir la GUI.
local activeTweens = {}
local function tween(object, props, duration, style)
	local previous = activeTweens[object]
	if previous then
		previous:Cancel()
	end
	local animation = TweenService:Create(
		object,
		TweenInfo.new(duration or 0.18, style or Enum.EasingStyle.Quart, Enum.EasingDirection.Out),
		props
	)
	activeTweens[object] = animation
	animation.Completed:Once(function()
		if activeTweens[object] == animation then
			activeTweens[object] = nil
		end
	end)
	animation:Play()
	return animation
end
local connections = {}
local function connect(signal, callback)
	local connection = signal:Connect(callback)
	table.insert(connections, connection)
	return connection
end
local function make(class, props, parent)
	local object = Instance.new(class)
	for key, value in pairs(props) do
		object[key] = value
	end
	object.Parent = parent
	return object
end
local function rounded(object, radius)
	make("UICorner", { CornerRadius = UDim.new(0, radius or 12) }, object)
end
local function stroke(object, color)
	return make("UIStroke", { Color = color or C.stroke, Thickness = 1, Transparency = 0.3 }, object)
end
local function text(parent, value, size, color, props)
	local options = {
		BackgroundTransparency = 1,
		Text = value,
		TextSize = size or 14,
		TextColor3 = color or C.text,
		TextStrokeColor3 = C.background,
		TextStrokeTransparency = 0.82,
		Font = Enum.Font.GothamMedium,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Size = UDim2.fromScale(1, 1),
		RichText = false,
	}
	for key, valueOverride in pairs(props or {}) do
		options[key] = valueOverride
	end
	return make("TextLabel", options, parent)
end
local function button(parent, value, props)
	local options = {
		BackgroundColor3 = C.elevated,
		BackgroundTransparency = 0.42,
		BorderSizePixel = 0,
		Text = value,
		TextColor3 = C.text,
		TextSize = 14,
		Font = Enum.Font.GothamMedium,
		AutoButtonColor = false,
		Size = UDim2.fromOffset(36, 36),
	}
	for key, override in pairs(props or {}) do
		options[key] = override
	end
	local object = make("TextButton", options, parent)
	rounded(object, 10)
	if options.Name ~= "SpeedSlider" and options.Name ~= "EmoteDetailsOverlay" then
		local scale = make("UIScale", { Scale = 1 }, object)
		-- Conexiones propiedad del botón: Destroy las libera junto con la tarjeta.
		object.MouseEnter:Connect(function()
			tween(scale, { Scale = 1.025 }, 0.16)
		end)
		object.MouseLeave:Connect(function()
			tween(scale, { Scale = 1 }, 0.16)
		end)
		object.Activated:Connect(function()
			scale.Scale = 0.94
			tween(scale, { Scale = 1 }, 0.28, Enum.EasingStyle.Back)
		end)
		object.Destroying:Connect(function()
			if activeTweens[scale] then
				activeTweens[scale]:Cancel()
				activeTweens[scale] = nil
			end
			if activeTweens[object] then
				activeTweens[object]:Cancel()
				activeTweens[object] = nil
			end
		end)
	end
	return object
end

local gui = make("ScreenGui", {
	Name = "FEEmotesStandaloneGui",
	ResetOnSpawn = false,
	DisplayOrder = 30,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
	ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets,
}, playerGui)
local safe = make("Frame", {
	Name = "SafeArea",
	BackgroundTransparency = 1,
	Size = UDim2.fromScale(1, 1),
}, gui)
local panel = make("CanvasGroup", {
	Name = "Panel",
	Visible = false,
	GroupTransparency = 1,
	BackgroundTransparency = 0.58,
	BackgroundColor3 = C.background,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(HubLayout.MaxWidth, HubLayout.MaxHeight),
	ClipsDescendants = true,
}, safe)
local panelScale = make("UIScale", { Scale = 1 }, panel)
rounded(panel, 18)
local glassBorder = stroke(panel, C.accent)
glassBorder.Transparency = 0.52
-- Cristal simulado con transparencias, reflejos y bordes; no se altera Lighting.
local sheen = make("Frame", {
	Name = "GlassSheen",
	BackgroundColor3 = C.text,
	BackgroundTransparency = 0.91,
	Size = UDim2.fromScale(1, 1),
	BorderSizePixel = 0,
	Active = false,
}, panel)
rounded(sheen, 18)
make("UIGradient", {
	Rotation = 115,
	Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(0.5, 1),
		NumberSequenceKeypoint.new(1, 0.65),
	}),
}, sheen)
local accent = make("Frame", {
	BackgroundColor3 = C.accent,
	BorderSizePixel = 0,
	Size = UDim2.new(1, 0, 0, 1),
	BackgroundTransparency = 0.35,
}, panel)
make("UIGradient", { Color = ColorSequence.new(C.stroke, C.accent) }, accent)
local header = make("Frame", {
	Name = "DragHandle",
	Active = true,
	BackgroundTransparency = 1,
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -142, 0, 40),
}, panel)
text(header, "FE", 18, C.accent, { Size = UDim2.fromOffset(25, 22), Font = Enum.Font.GothamBold })
text(
	header,
	"EMOTES",
	16,
	C.text,
	{ Position = UDim2.fromOffset(28, 0), Size = UDim2.new(1, -28, 0, 22), Font = Enum.Font.GothamBold }
)
text(
	header,
	"GLASS COMPACT  /  LOCAL · R15",
	8,
	C.muted,
	{ Position = UDim2.fromOffset(0, 24), Size = UDim2.new(1, 0, 0, 12) }
)
local favoritesNav = button(panel, "★", {
	Name = "Favoritos",
	Position = UDim2.new(1, -124, 0, 10),
	TextSize = 23,
})
local favoritesBorder = stroke(favoritesNav, C.stroke)
local minimize = button(panel, "−", { TextSize = 21, Position = UDim2.new(1, -84, 0, 10) })
local close = button(panel, "×", { TextSize = 21, Position = UDim2.new(1, -44, 0, 10) })

local navigation = make("Frame", {
	Name = "LibraryNavigation",
	BackgroundTransparency = 0.6,
	Position = UDim2.fromOffset(10, 56),
	Size = UDim2.new(1, -20, 0, 34),
	BackgroundColor3 = C.surface,
	BorderSizePixel = 0,
}, panel)
rounded(navigation, 10)
local navIndicator = make("Frame", {
	Position = UDim2.fromOffset(4, 4),
	Size = UDim2.new(0.5, -8, 1, -8),
	BackgroundColor3 = C.selected,
	BorderSizePixel = 0,
}, navigation)
rounded(navIndicator, 7)
local viewButtons = { Favoritos = favoritesNav }
for i, name in ipairs({ "Catálogo", "Equipados" }) do
	viewButtons[name] = button(navigation, name, {
		Name = name,
		Position = UDim2.new((i - 1) / 2, 0, 0, 0),
		Size = UDim2.new(0.5, 0, 1, 0),
		BackgroundTransparency = 1,
		TextSize = 12,
		TextColor3 = i == 1 and C.background or C.muted,
	})
end
local pageSurface = make("CanvasGroup", {
	Name = "LibraryPage",
	Position = UDim2.fromOffset(10, 98),
	Size = UDim2.new(1, -20, 1, -132),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
}, panel)
local body = make("ScrollingFrame", {
	Name = "Content",
	Position = UDim2.fromOffset(0, 0),
	Size = UDim2.fromScale(1, 1),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.accent,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ElasticBehavior = Enum.ElasticBehavior.WhenScrollable,
}, pageSurface)
make("UIPadding", { PaddingRight = UDim.new(0, 5), PaddingBottom = UDim.new(0, 8) }, body)
make("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Padding = UDim.new(0, 6) }, body)
local order = 0
local function section(height, surface)
	order = order + 1
	local frame = make("Frame", {
		Size = UDim2.new(1, 0, 0, height),
		LayoutOrder = order,
		BorderSizePixel = 0,
		BackgroundColor3 = C.surface,
		BackgroundTransparency = surface and 0.56 or 1,
	}, body)
	if surface then
		rounded(frame)
	end
	return frame
end

local now = section(54, true)
stroke(now)
local activeImage = make("ImageLabel", {
	BackgroundColor3 = C.elevated,
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(36, 36),
	Position = UDim2.fromOffset(8, 9),
	Image = "",
	ScaleType = Enum.ScaleType.Fit,
}, now)
rounded(activeImage, 10)
local activeName = text(now, "Elige un emote", 12, C.text, {
	Position = UDim2.fromOffset(52, 7),
	Size = UDim2.new(1, -146, 0, 20),
})
local activeState = text(now, "UGC + Roblox", 10, C.muted, {
	Position = UDim2.fromOffset(52, 30),
	Size = UDim2.new(1, -146, 0, 16),
})
local stopButton =
	button(now, "■", { Position = UDim2.new(1, -44, 0, 9), TextColor3 = C.error, TextSize = 18 })

local controlsToggle =
	button(now, "≡", { Name = "PlayerControls", Position = UDim2.new(1, -84, 0, 9), TextSize = 21 })
local controlsGroup = section(0, false)
controlsGroup.Name = "ExpandedPlayer"
controlsGroup.ClipsDescendants = true
controlsGroup.Visible = false
local controlsOpen = false
local controlsRevision = 0
local speedSection = section(54, false)
speedSection.Parent = controlsGroup
text(speedSection, "VELOCIDAD", 10, C.muted, { Size = UDim2.new(0.5, 0, 0, 18) })
local speedValue = text(speedSection, "1.00×", 13, C.accent, {
	Position = UDim2.new(0.5, 0, 0, 0),
	Size = UDim2.new(0.5, 0, 0, 18),
	TextXAlignment = Enum.TextXAlignment.Right,
})
local minus = button(speedSection, "−", { Position = UDim2.fromOffset(0, 18), TextSize = 20 })
local plus = button(speedSection, "+", { Position = UDim2.new(1, -36, 0, 18), TextSize = 20 })
local slider = button(speedSection, "", {
	Name = "SpeedSlider",
	Position = UDim2.fromOffset(46, 18),
	Size = UDim2.new(1, -92, 0, 36),
	BackgroundTransparency = 1,
})
local rail = make("Frame", {
	BackgroundColor3 = C.elevated,
	BorderSizePixel = 0,
	Position = UDim2.new(0, 10, 0.5, -3),
	Size = UDim2.new(1, -20, 0, 6),
}, slider)
rounded(rail, 3)
local fill =
	make("Frame", { BackgroundColor3 = C.accent, BorderSizePixel = 0, Size = UDim2.fromScale(0.27, 1) }, rail)
rounded(fill, 3)
local knob = make("Frame", {
	BackgroundColor3 = C.text,
	BorderSizePixel = 0,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.27, 0.5),
	Size = UDim2.fromOffset(20, 20),
}, rail)
rounded(knob, 10)
local switches = section(46, false)
switches.Parent = controlsGroup
switches.Position = UDim2.fromOffset(0, 60)
local lockButton = button(switches, "", { Size = UDim2.new(0.5, -4, 1, 0) })
local pauseButton =
	button(switches, "", { Position = UDim2.new(0.5, 4, 0, 0), Size = UDim2.new(0.5, -4, 1, 0) })
local lockTitle = text(
	lockButton,
	"○ Mantener",
	13,
	C.text,
	{ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 18) }
)
text(
	lockButton,
	"No se quita al moverte",
	10,
	C.muted,
	{ Position = UDim2.fromOffset(8, 25), Size = UDim2.new(1, -16, 0, 14) }
)
local pauseTitle = text(
	pauseButton,
	"Ⅱ Pausar pose",
	13,
	C.text,
	{ Position = UDim2.fromOffset(8, 4), Size = UDim2.new(1, -16, 0, 18) }
)
text(
	pauseButton,
	"Congela el fotograma",
	10,
	C.muted,
	{ Position = UDim2.fromOffset(8, 25), Size = UDim2.new(1, -16, 0, 14) }
)

local quick = section(60, false)
local quickTitle = text(quick, "ACCESO RÁPIDO · 0/8", 10, C.muted, { Size = UDim2.new(1, 0, 0, 18) })
local quickScroll = make("ScrollingFrame", {
	Position = UDim2.fromOffset(0, 20),
	Size = UDim2.new(1, 0, 0, 40),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.X,
	ScrollBarThickness = 2,
	ScrollBarImageColor3 = C.accent,
	ScrollingDirection = Enum.ScrollingDirection.X,
}, quick)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, quickScroll)

local browseTitle = section(46, false)
local collectionEyebrow = text(browseTitle, "LA BIBLIOTECA", 8, C.muted, { Size = UDim2.new(1, -44, 0, 12) })
local collectionTitle = text(browseTitle, "Encuentra tu ritmo.", 16, C.text, {
	Position = UDim2.fromOffset(0, 12),
	Size = UDim2.new(1, -44, 0, 21),
	Font = Enum.Font.GothamBold,
})
local collectionHint = text(browseTitle, "Toca un emote para desplegarlo o comprarlo.", 9, C.muted, {
	Position = UDim2.fromOffset(0, 34),
	Size = UDim2.new(1, 0, 0, 12),
})
local collectionCount = text(browseTitle, "06", 18, C.accent, {
	Position = UDim2.new(1, -40, 0, 12),
	Size = UDim2.fromOffset(40, 22),
	TextXAlignment = Enum.TextXAlignment.Right,
})
local searchSection = section(36, false)
local searchBox = make("TextBox", {
	Name = "Search",
	Size = UDim2.new(1, -48, 1, 0),
	BackgroundTransparency = 0.48,
	BackgroundColor3 = C.surface,
	BorderSizePixel = 0,
	Text = "",
	PlaceholderText = "Buscar nombre, ID o enlace…",
	PlaceholderColor3 = C.muted,
	TextColor3 = C.text,
	Font = Enum.Font.Gotham,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false,
}, searchSection)
rounded(searchBox)
stroke(searchBox)
make("UIPadding", { PaddingLeft = UDim.new(0, 12), PaddingRight = UDim.new(0, 10) }, searchBox)
local searchButton = button(searchSection, "Ir →", {
	Position = UDim2.new(1, -42, 0, 0),
	Size = UDim2.fromOffset(42, 36),
	TextSize = 12,
	BackgroundColor3 = C.selected,
	TextColor3 = C.background,
})
local tabsSection = section(30, false)
make("UIListLayout", {
	FillDirection = Enum.FillDirection.Horizontal,
	Padding = UDim.new(0, 6),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, tabsSection)
local tabs = {}
for i, name in ipairs({ "Todos", "UGC", "Roblox" }) do
	tabs[name] =
		button(tabsSection, name, { Size = UDim2.new(1 / 3, -4, 1, 0), TextSize = 11, LayoutOrder = i })
end
local grid = section(0, false)
grid.Name = "EmoteGrid"
local gridLayout = make("UIGridLayout", {
	Name = "SquareLayout",
	FillDirectionMaxCells = 3,
	CellSize = UDim2.fromOffset(96, 96),
	CellPadding = UDim2.fromOffset(HubLayout.Gap, HubLayout.Gap),
	SortOrder = Enum.SortOrder.LayoutOrder,
}, grid)
local empty = section(92, true)
stroke(empty)
local emptyText = text(
	empty,
	"Tu siguiente emote está por llegar.\nPrueba otra búsqueda.",
	13,
	C.muted,
	{ TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center }
)
empty.Visible = false
local moreSection = section(36, false)
local more = button(moreSection, "Buscar en el catálogo de Roblox", { Size = UDim2.fromScale(1, 1) })
local note = section(26, false)
text(
	note,
	"Equipar no compra el artículo. Disponibilidad según Roblox.",
	10,
	C.muted,
	{ TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center }
)

local status = text(panel, "Modo local · visibilidad a otros no garantizada", 10, C.muted, {
	Position = UDim2.new(0, 12, 1, -30),
	Size = UDim2.new(1, -24, 0, 26),
	TextWrapped = true,
})
local detailUI = { revision = 0 }
detailUI.overlay = button(panel, "", {
	Name = "EmoteDetailsOverlay",
	Size = UDim2.fromScale(1, 1),
	Visible = false,
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BackgroundTransparency = 0.3,
	ZIndex = 20,
})
detailUI.card = make("CanvasGroup", {
	Name = "EmoteDetailsCard",
	Active = true,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(344, 368),
	BackgroundColor3 = C.surface,
	BackgroundTransparency = 0.28,
	BorderSizePixel = 0,
	GroupTransparency = 1,
	ClipsDescendants = true,
}, detailUI.overlay)
rounded(detailUI.card, 18)
stroke(detailUI.card, C.accent).Transparency = 0.7
detailUI.scale = make("UIScale", { Scale = 1 }, detailUI.card)
text(detailUI.card, "EMOTE SELECCIONADO", 10, C.muted, {
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -62, 0, 28),
})
detailUI.close =
	button(detailUI.card, "×", { Name = "CloseDetails", Position = UDim2.new(1, -44, 0, 4), TextSize = 21 })
detailUI.body = make("ScrollingFrame", {
	Name = "DetailsContent",
	Position = UDim2.fromOffset(12, 48),
	Size = UDim2.new(1, -24, 1, -112),
	BackgroundTransparency = 1,
	BorderSizePixel = 0,
	CanvasSize = UDim2.new(),
	AutomaticCanvasSize = Enum.AutomaticSize.Y,
	ScrollingDirection = Enum.ScrollingDirection.Y,
	ScrollBarThickness = 3,
	ScrollBarImageColor3 = C.muted,
}, detailUI.card)
detailUI.content =
	make("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, -6, 0, 334) }, detailUI.body)
detailUI.preview = make("Frame", {
	Name = "BlackEmoteSquare",
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
	BorderSizePixel = 0,
	Size = UDim2.fromOffset(144, 144),
	Position = UDim2.new(0.5, 0, 0, 0),
	AnchorPoint = Vector2.new(0.5, 0),
}, detailUI.content)
rounded(detailUI.preview, 12)
stroke(detailUI.preview)
detailUI.image = make("ImageLabel", {
	Name = "SelectedEmoteImage",
	BackgroundTransparency = 1,
	Size = UDim2.new(1, -16, 1, -16),
	Position = UDim2.fromOffset(8, 8),
	Image = "",
	ScaleType = Enum.ScaleType.Fit,
}, detailUI.preview)
detailUI.name = text(
	detailUI.content,
	"Emote",
	17,
	C.text,
	{ Name = "SelectedEmoteName", TextXAlignment = Enum.TextXAlignment.Center }
)
detailUI.creator = text(detailUI.content, "", 11, C.muted, { TextXAlignment = Enum.TextXAlignment.Center })
detailUI.price = text(
	detailUI.content,
	"Consultar disponibilidad",
	14,
	C.text,
	{ Name = "EmotePrice", TextXAlignment = Enum.TextXAlignment.Center }
)
detailUI.message = text(
	detailUI.content,
	"",
	11,
	C.muted,
	{ Name = "PurchaseMessage", TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Center }
)
detailUI.deploy = button(detailUI.card, "Desplegar", {
	Name = "DeployEmote",
	Position = UDim2.new(0, 12, 1, -52),
	Size = UDim2.new(0.5, -17, 0, 40),
	TextSize = 12,
	BackgroundColor3 = C.selected,
	TextColor3 = C.background,
})
detailUI.buy = button(detailUI.card, "Comprar", {
	Name = "BuyEmote",
	Position = UDim2.new(0.5, 5, 1, -52),
	Size = UDim2.new(0.5, -17, 0, 40),
	TextSize = 12,
	BackgroundColor3 = Color3.fromRGB(0, 0, 0),
})
stroke(detailUI.buy)
local launcher = button(safe, "FE", {
	Name = "Reopen",
	Size = UDim2.fromOffset(48, 48),
	Position = UDim2.new(1, -56, 0.34, 0),
	Visible = true,
	BackgroundColor3 = C.background,
	TextSize = 17,
	Font = Enum.Font.GothamBold,
})
launcher:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 12)
local launcherRing = stroke(launcher, C.accent)
launcherRing.Transparency = 0.15
local launcherDot = make("Frame", {
	Name = "PlaybackIndicator",
	Size = UDim2.fromOffset(10, 10),
	Position = UDim2.new(1, -12, 0, 2),
	BackgroundColor3 = C.muted,
	BorderSizePixel = 0,
}, launcher)
rounded(launcherDot, 5)

local windowState = HubState.new()
local favorites = Favorites.new(Validation, 120)
local favoritesKey = "FEEmotesFavoritesV1"
do
	local saved = playerGui:GetAttribute(favoritesKey)
	if type(saved) == "string" and #saved < 100000 then
		local ok, payload = pcall(function()
			return HttpService:JSONDecode(saved)
		end)
		if ok then
			favorites:restore(payload)
		end
	end
end
local selectedView = "Catálogo"
local viewQueries = { ["Catálogo"] = "", Favoritos = "", Equipados = "" }
local localSearchRevision = 0
local lastIconDrag = -math.huge
local launcherOnLeft = false

local state = { equipped = {}, speed = 1, locked = false, paused = false, loading = false }
local items = table.clone(Config.Featured)
local selectedTab = "Todos"
local catalogPages = nil
local searching = false
local searchRevision = 0
local lastSearch = -math.huge
local closed = true
local catalogStarted = false
local destroyed = false
local sliderInput = nil
local settingsVersion = 0
local sentSettingsVersion = 0
local slotsSignature = ""
local cards = {}

local function thumbnail(id)
	return "rbxthumb://type=Asset&id=" .. tostring(id) .. "&w=150&h=150"
end
local function request(action, id)
	remote:Dispatch({ action = action, id = id })
end
local function notify(message, isError)
	status.Text = message
	status.TextColor3 = isError and C.error or C.muted
	status.TextTransparency = 0.45
	tween(status, { TextTransparency = 0 }, 0.25)
end
local function isEquipped(id)
	for _, item in ipairs(state.equipped) do
		if item.Id == id then
			return true
		end
	end
	return false
end
local function flushSettings()
	if settingsVersion <= sentSettingsVersion then
		return
	end
	sentSettingsVersion = settingsVersion
	remote:Dispatch({
		action = "Settings",
		speed = state.speed,
		locked = state.locked,
		paused = state.paused,
		settingsRevision = settingsVersion,
	})
end
local function play(id)
	if state.loading then
		notify("Una carga en curso. Espera o pulsa detener.", true)
		return
	end
	flushSettings()
	request("Play", id)
end
local details = EmoteDetails.new(MarketplaceService, player, Validation, function(snapshot)
	if destroyed or not snapshot.item then
		return
	end
	detailUI.item = snapshot.item
	detailUI.name.Text = snapshot.item.Name or "Emote"
	detailUI.creator.Text = snapshot.item.Creator or "Creador"
	if snapshot.loading then
		detailUI.price.Text = "Consultando…"
	elseif snapshot.owned then
		detailUI.price.Text = "En tu inventario"
	elseif snapshot.forSale == false then
		detailUI.price.Text = "Fuera de venta"
	elseif snapshot.price ~= nil then
		detailUI.price.Text = snapshot.price == 0 and "Gratis" or tostring(snapshot.price) .. " Robux"
	else
		detailUI.price.Text = "Precio no disponible"
	end
	detailUI.message.Text = snapshot.message or "Confirma cualquier compra en la ventana oficial de Roblox."
	detailUI.message.TextColor3 = snapshot.isError and C.error or C.muted
	local enabled = snapshot.canBuy and not snapshot.purchasing
	detailUI.buy.Active = enabled
	detailUI.buy.Selectable = enabled
	detailUI.buy.TextTransparency = enabled and 0 or 0.5
	detailUI.buy.BackgroundTransparency = enabled and 0 or 0.45
end)
local function closeDetails()
	detailUI.revision = detailUI.revision + 1
	local token = detailUI.revision
	detailUI.item = nil
	details:clear()
	tween(detailUI.card, { GroupTransparency = 1 }, 0.15)
	task.delay(0.16, function()
		if not destroyed and detailUI.revision == token then
			detailUI.overlay.Visible = false
		end
	end)
end
local function openDetails(item)
	if destroyed or windowState.mode ~= "open" then
		return
	end
	detailUI.revision = detailUI.revision + 1
	detailUI.item = item
	detailUI.overlay.Visible = true
	detailUI.image.Image = thumbnail(item.Id)
	detailUI.body.CanvasPosition = Vector2.new(0, 0)
	detailUI.scale.Scale = 0.94
	tween(detailUI.scale, { Scale = 1 }, 0.28, Enum.EasingStyle.Back)
	tween(detailUI.card, { GroupTransparency = 0 }, 0.2)
	details:select(item)
end
connect(detailUI.close.Activated, closeDetails)
connect(detailUI.overlay.Activated, closeDetails)
connect(detailUI.deploy.Activated, function()
	if not detailUI.item or destroyed then
		return
	end
	local id = detailUI.item.Id
	closeDetails()
	play(id)
end)
connect(detailUI.buy.Activated, function()
	details:purchase()
end)
local function paintControls()
	speedValue.Text = string.format("%.2f×", state.speed)
	local ratio = (state.speed - Config.MinSpeed) / (Config.MaxSpeed - Config.MinSpeed)
	if sliderInput then
		fill.Size = UDim2.fromScale(ratio, 1)
		knob.Position = UDim2.fromScale(ratio, 0.5)
	else
		tween(fill, { Size = UDim2.fromScale(ratio, 1) }, 0.12)
		tween(knob, { Position = UDim2.fromScale(ratio, 0.5) }, 0.12)
	end
	lockTitle.Text = state.locked and "● Mantener: sí" or "○ Mantener: no"
	pauseTitle.Text = state.paused and "▶ Reanudar pose" or "Ⅱ Pausar pose"
	tween(lockButton, { BackgroundColor3 = state.locked and C.selected or C.elevated })
	tween(pauseButton, { BackgroundColor3 = state.paused and C.selected or C.elevated })
	lockTitle.TextColor3 = state.locked and C.background or C.text
	pauseTitle.TextColor3 = state.paused and C.background or C.text
	for _, label in ipairs(lockButton:GetChildren()) do
		if label:IsA("TextLabel") and label ~= lockTitle then
			label.TextColor3 = state.locked and C.elevated or C.muted
		end
	end
	for _, label in ipairs(pauseButton:GetChildren()) do
		if label:IsA("TextLabel") and label ~= pauseTitle then
			label.TextColor3 = state.paused and C.elevated or C.muted
		end
	end
	activeName.Text = state.active and state.active.Name or "Elige tu próximo emote"
	activeImage.Image = state.active and thumbnail(state.active.Id) or ""
	activeState.Text = state.loading and "Cargando…"
		or (
			state.active and (state.paused and "POSE PAUSADA" or "REPRODUCIENDO")
			or "UGC + clásicos de Roblox"
		)
	activeState.TextColor3 = state.active and C.text or C.muted
	launcherDot.BackgroundColor3 = state.active and C.text or C.muted
	launcherDot.Visible = state.active ~= nil
	if not controlsOpen and state.active then
		activeState.Text = (state.paused and "PAUSA" or string.format("%.2f×", state.speed))
			.. (state.locked and " · FIJO" or " · EN BUCLE")
	end
end
local function scheduleSettings()
	settingsVersion = settingsVersion + 1
	local version = settingsVersion
	paintControls()
	-- Debounce real: una solicitud por gesto/ráfaga; no por cada píxel del slider.
	task.delay(0.15, function()
		if destroyed or version ~= settingsVersion then
			return
		end
		flushSettings()
	end)
end
local function setSpeed(value)
	state.speed = math.clamp(
		math.floor(value / Config.SpeedStep + 0.5) * Config.SpeedStep,
		Config.MinSpeed,
		Config.MaxSpeed
	)
	scheduleSettings()
end

local function saveFavorites()
	local ok = pcall(function()
		playerGui:SetAttribute(favoritesKey, HttpService:JSONEncode(favorites:export()))
	end)
	if not ok then
		notify("Favoritos disponibles en este panel; no se pudo guardar la copia de sesión.", true)
	end
end
local renderCards
local function updateGridSize()
	local columns, side, height = HubLayout.grid(grid.AbsoluteSize.X, #cards)
	gridLayout.FillDirectionMaxCells = columns
	gridLayout.CellSize = UDim2.fromOffset(side, side)
	grid.Size = UDim2.new(1, 0, 0, height)
end
connect(grid:GetPropertyChangedSignal("AbsoluteSize"), updateGridSize)
local function toggleFavorite(item, favoriteButton)
	local ok, result = favorites:toggle(item)
	if not ok then
		notify("Tu colección admite hasta 120 favoritos.", true)
		return
	end
	saveFavorites()
	notify(
		result == "added" and "★ Guardado en Favoritos. Tu colección, a un toque."
			or "Emote retirado de Favoritos."
	)
	if selectedView == "Favoritos" then
		renderCards(false)
	else
		favoriteButton.Text = favorites:contains(item.Id) and "★" or "☆"
		tween(favoriteButton, { TextColor3 = favorites:contains(item.Id) and C.favorite or C.muted })
	end
end
renderCards = function(animate)
	for _, card in ipairs(cards) do
		card:Destroy()
	end
	cards = {}
	local source = items
	if selectedView == "Favoritos" then
		source = favorites:list(searchBox.Text)
	elseif selectedView == "Equipados" then
		source = state.equipped
	end
	local count = 0
	local query = searchBox.Text:lower():match("^%s*(.-)%s*$")
	for _, item in ipairs(source) do
		local matches = selectedView ~= "Catálogo"
			or selectedTab == "Todos"
			or (selectedTab == "Roblox" and item.IsRoblox)
			or (selectedTab == "UGC" and not item.IsRoblox)
		if selectedView == "Equipados" and query ~= "" then
			matches = item.Name:lower():find(query, 1, true) ~= nil or tostring(item.Id) == query
		end
		if matches then
			count = count + 1
			local card = make("Frame", {
				Name = "Emote_" .. tostring(item.Id),
				BackgroundColor3 = C.surface,
				BackgroundTransparency = 0.54,
				BorderSizePixel = 0,
				LayoutOrder = count,
				ClipsDescendants = true,
			}, grid)
			rounded(card, 10)
			local border = stroke(card, state.active and state.active.Id == item.Id and C.accent or C.stroke)
			table.insert(cards, card)
			card.Destroying:Connect(function()
				for _, descendant in ipairs(card:GetDescendants()) do
					if activeTweens[descendant] then
						activeTweens[descendant]:Cancel()
						activeTweens[descendant] = nil
					end
				end
			end)
			local image = make("ImageButton", {
				Name = "SelectEmote",
				Size = UDim2.fromScale(1, 1),
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				Image = thumbnail(item.Id),
				ScaleType = Enum.ScaleType.Fit,
				AutoButtonColor = false,
			}, card)
			rounded(image, 10)
			local caption = make("Frame", {
				BackgroundColor3 = Color3.fromRGB(0, 0, 0),
				BackgroundTransparency = 0.4,
				BorderSizePixel = 0,
				Position = UDim2.new(0, 0, 1, -24),
				Size = UDim2.new(1, 0, 0, 24),
			}, image)
			text(
				caption,
				item.Name,
				10,
				C.text,
				{ Position = UDim2.fromOffset(6, 3), Size = UDim2.new(1, -12, 0, 18) }
			)
			local equipped = isEquipped(item.Id)
			local equip = button(card, equipped and "✓" or "+", {
				Name = "Equip",
				Position = UDim2.fromOffset(4, 4),
				Size = UDim2.fromOffset(28, 28),
				TextSize = 17,
				BackgroundColor3 = equipped and C.selected or C.elevated,
				TextColor3 = equipped and C.background or C.text,
			})
			local favoriteButton = button(card, favorites:contains(item.Id) and "★" or "☆", {
				Name = "Favorite",
				Position = UDim2.new(1, -32, 0, 4),
				Size = UDim2.fromOffset(28, 28),
				TextSize = 17,
				BackgroundColor3 = C.background,
				BackgroundTransparency = 0.4,
				TextColor3 = favorites:contains(item.Id) and C.favorite or C.muted,
			})
			equip:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 8)
			favoriteButton:FindFirstChildOfClass("UICorner").CornerRadius = UDim.new(0, 8)
			image.MouseEnter:Connect(function()
				tween(border, { Transparency = 0 }, 0.18)
			end)
			image.MouseLeave:Connect(function()
				tween(border, { Transparency = 0.3 }, 0.18)
			end)
			image.Activated:Connect(function()
				openDetails(item)
			end)
			equip.Activated:Connect(function()
				request("Equip", item.Id)
			end)
			favoriteButton.Activated:Connect(function()
				toggleFavorite(item, favoriteButton)
			end)
			-- Entrada breve de las primeras tarjetas; sin bucles permanentes por emote.
			if animate and count <= 8 then
				local scale = make("UIScale", { Scale = 0.94 }, image)
				image.ImageTransparency = 0.6
				task.delay((count - 1) * 0.025, function()
					if destroyed or not image.Parent then
						return
					end
					tween(scale, { Scale = 1 }, 0.3, Enum.EasingStyle.Back)
					tween(image, { ImageTransparency = 0 }, 0.3)
				end)
			end
		end
	end
	empty.Visible = count == 0
	if selectedView == "Favoritos" then
		emptyText.Text = favorites:count() == 0
				and "☆  Tu colección empieza aquí.\nMarca la estrella de cualquier emote para guardarlo."
			or "No hay favoritos con ese nombre.\nPrueba otro nombre, creador o ID."
	elseif selectedView == "Equipados" then
		emptyText.Text = "Tus emotes, siempre a mano.\nToca + en el catálogo para añadirlos."
	else
		emptyText.Text = "No hay coincidencias en estas páginas.\nPrueba otra búsqueda o carga más emotes."
	end
	grid.Visible = count > 0
	updateGridSize()
	collectionCount.Text = string.format("%02d", count)
	collectionEyebrow.Text = selectedView == "Favoritos" and "TU COLECCIÓN PERSONAL"
		or (selectedView == "Equipados" and "LISTOS PARA REPRODUCIR" or "LA BIBLIOTECA")
	collectionTitle.Text = selectedView == "Favoritos" and "Solo tus favoritos."
		or (selectedView == "Equipados" and "Tu selección rápida." or "Encuentra tu ritmo.")
	collectionHint.Text = selectedView == "Favoritos"
			and (tostring(favorites:count()) .. " / 120 guardados · ★ para quitar")
		or (
			selectedView == "Equipados" and "Hasta 8 accesos rápidos. Sin perder tu ritmo."
			or "Toca un emote para desplegarlo o comprarlo."
		)
	quick.Visible = #state.equipped > 0
	for name, tab in pairs(tabs) do
		tween(tab, {
			BackgroundColor3 = name == selectedTab and C.selected or C.surface,
			TextColor3 = name == selectedTab and C.background or C.muted,
		})
	end
	tabsSection.Visible = selectedView == "Catálogo"
	moreSection.Visible = selectedView == "Catálogo"
end

local function renderSlots()
	local ids = {}
	for _, item in ipairs(state.equipped) do
		table.insert(ids, tostring(item.Id))
	end
	local signature = table.concat(ids, ",")
	if signature == slotsSignature then
		return
	end
	slotsSignature = signature
	for _, child in ipairs(quickScroll:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	quickTitle.Text = "ACCESO RÁPIDO · " .. tostring(#state.equipped) .. "/8"
	for i = 1, Config.MaxEquipped do
		local item = state.equipped[i]
		local slot = button(quickScroll, item and "" or tostring(i), {
			Size = UDim2.fromOffset(38, 38),
			LayoutOrder = i,
			TextColor3 = C.muted,
			BackgroundColor3 = item and C.elevated or C.surface,
		})
		if item then
			make(
				"ImageLabel",
				{ Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Image = thumbnail(item.Id) },
				slot
			)
		end
		slot.Activated:Connect(function()
			if item then
				play(item.Id)
			else
				notify("Toca + en una tarjeta para ocupar este espacio.")
			end
		end)
	end
end

local function normalize(result)
	local id = tonumber(result.Id)
	if not Validation.assetId(id) then
		return nil
	end
	return {
		Id = id,
		Name = tostring(result.Name or "Emote"),
		Creator = tostring(result.CreatorName or "Creador"),
		IsRoblox = Validation.isRoblox(result.CreatorTargetId or result.CreatorId, result.CreatorType),
	}
end
local function searchCatalog(nextPage)
	if selectedView ~= "Catálogo" then
		renderCards(true)
		return
	end
	if searching or os.clock() - lastSearch < 1 then
		return
	end
	local query = searchBox.Text:sub(1, 100):match("^%s*(.-)%s*$")
	local directId = Validation.parseId(query)
	if directId and not nextPage then
		openDetails({ Id = directId, Name = "Emote #" .. tostring(directId), Creator = "Catálogo" })
		return
	end
	if nextPage and catalogPages and catalogPages.IsFinished then
		notify("Llegaste al final de los resultados.")
		return
	end
	lastSearch = os.clock()
	searching = true
	searchRevision = searchRevision + 1
	local revision = searchRevision
	local oldPages = catalogPages
	more.Text = "Cargando…"
	notify("Consultando el catálogo de Roblox…")
	task.delay(15, function()
		if not destroyed and searching and revision == searchRevision then
			searchRevision = searchRevision + 1
			searching = false
			catalogPages = nil -- Una paginación tardía ya no se reutiliza.
			more.Text = "Reintentar búsqueda"
			notify("El catálogo tarda en responder. Vuelve a intentarlo.", true)
		end
	end)
	task.spawn(function()
		local ok, pages = pcall(function()
			if nextPage and oldPages then
				oldPages:AdvanceToNextPageAsync()
				return oldPages
			end
			local params = CatalogSearchParams.new()
			params.AssetTypes = { Enum.AvatarAssetType.EmoteAnimation }
			params.SearchKeyword = query
			params.IncludeOffSale = true
			params.Limit = 30
			return AvatarEditorService:SearchCatalogAsync(params)
		end)
		if destroyed or revision ~= searchRevision then
			return
		end
		searching = false
		if not ok then
			if not nextPage then
				catalogPages = nil
			end
			more.Text = "Reintentar búsqueda"
			notify("Catálogo no disponible. Puedes usar los destacados o introducir un ID.", true)
			return
		end
		catalogPages = pages
		if not nextPage or not oldPages then
			items = {}
		end
		local seen = {}
		for _, item in ipairs(items) do
			seen[item.Id] = true
		end
		for _, result in ipairs(pages:GetCurrentPage()) do
			if #items >= 120 then
				break
			end
			local item = normalize(result)
			if item and not seen[item.Id] then
				table.insert(items, item)
				seen[item.Id] = true
			end
		end
		-- Evita miles de instancias en teléfonos. Una búsqueda nueva reinicia el límite.
		local capped = #items >= 120
		more.Text = capped and "Límite de 120 · afina la búsqueda"
			or (pages.IsFinished and "Fin de resultados · volver a buscar" or "Cargar más emotes ↓")
		if capped then
			catalogPages = nil
		end
		renderCards(selectedView == "Catálogo")
		notify(tostring(#items) .. " emotes · toca una tarjeta para ver sus opciones")
	end)
end

local function clampPosition(object, x, y)
	local size = safe.AbsoluteSize
	object.Position = UDim2.fromOffset(
		math.clamp(x, 8, math.max(8, size.X - object.Size.X.Offset - 8)),
		math.clamp(y, 8, math.max(8, size.Y - object.Size.Y.Offset - 8))
	)
end
local positioned = false
local function resize()
	local size = safe.AbsoluteSize
	if size.X < 1 or size.Y < 1 then
		return
	end
	if activeTweens[launcher] then
		activeTweens[launcher]:Cancel()
	end
	panel.Size = UDim2.fromOffset(HubLayout.window(size.X, size.Y))
	detailUI.card.Size = UDim2.fromOffset(panel.Size.X.Offset - 20, math.min(368, panel.Size.Y.Offset - 20))
	local side = math.min(
		144,
		math.max(80, detailUI.card.Size.X.Offset - 48),
		math.max(80, detailUI.card.Size.Y.Offset - 210)
	)
	detailUI.preview.Size = UDim2.fromOffset(side, side)
	detailUI.content.Size = UDim2.new(1, -6, 0, side + 126)
	for index, field in ipairs({ "name", "creator", "price", "message" }) do
		local y = side + ({ 8, 30, 52, 78 })[index]
		detailUI[field].Position = UDim2.fromOffset(0, y)
		detailUI[field].Size = UDim2.new(1, 0, 0, field == "message" and 44 or 22)
	end
	updateGridSize()
	if not positioned then
		clampPosition(panel, size.X - panel.Size.X.Offset - 16, (size.Y - panel.Size.Y.Offset) / 2)
		clampPosition(launcher, size.X - 56, math.floor(size.Y * 0.34))
		positioned = true
	else
		clampPosition(panel, panel.Position.X.Offset, panel.Position.Y.Offset)
		clampPosition(launcher, launcherOnLeft and 8 or size.X - 56, launcher.Position.Y.Offset)
	end
end
-- Un solo gesto activo: arrastrar la ventana no secuestra el joystick ni otros dedos.
local drag = nil
local function draggable(handle, target)
	connect(handle.InputBegan, function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			if target == launcher and activeTweens[target] then
				activeTweens[target]:Cancel()
			end
			drag = { input = input, origin = input.Position, position = target.Position, target = target }
		end
	end)
end
local function sliderAt(x)
	local ratio = math.clamp((x - rail.AbsolutePosition.X) / math.max(1, rail.AbsoluteSize.X), 0, 1)
	setSpeed(Config.MinSpeed + ratio * (Config.MaxSpeed - Config.MinSpeed))
end
connect(slider.InputBegan, function(input)
	if
		input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch
	then
		sliderInput = input
		body.ScrollingEnabled = false
		sliderAt(input.Position.X)
	end
end)
connect(UserInputService.InputChanged, function(input)
	if
		sliderInput
		and (
			input == sliderInput
			or (
				sliderInput.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement
			)
		)
	then
		sliderAt(input.Position.X)
	end
	if
		drag
		and (
			input == drag.input
			or (
				drag.input.UserInputType == Enum.UserInputType.MouseButton1
				and input.UserInputType == Enum.UserInputType.MouseMovement
			)
		)
	then
		local delta = input.Position - drag.origin
		if delta.Magnitude > 6 then
			drag.moved = true
		end
		clampPosition(drag.target, drag.position.X.Offset + delta.X, drag.position.Y.Offset + delta.Y)
	end
end)
connect(UserInputService.InputEnded, function(input)
	if input == sliderInput then
		sliderInput = nil
		body.ScrollingEnabled = true
	end
	if drag and input == drag.input then
		if drag.target == launcher and drag.moved then
			lastIconDrag = os.clock()
			launcherOnLeft = launcher.Position.X.Offset + 24 < safe.AbsoluteSize.X / 2
			local edge = launcherOnLeft and 8 or math.max(8, safe.AbsoluteSize.X - 56)
			tween(launcher, { Position = UDim2.fromOffset(edge, launcher.Position.Y.Offset) }, 0.18)
		end
		drag = nil
	end
end)
draggable(header, panel)
draggable(launcher, launcher)
connect(safe:GetPropertyChangedSignal("AbsoluteSize"), resize)

local function showPanel()
	local ticket = windowState:set("open")
	if not ticket then
		return
	end
	closed = false
	launcher.Visible = false
	panel.Visible = true
	panelScale.Scale = 1
	resize()
	panelScale.Scale = 0.9
	tween(panelScale, { Scale = 1 }, 0.32, Enum.EasingStyle.Back)
	tween(panel, { GroupTransparency = 0 }, 0.22)
	if not catalogStarted then
		catalogStarted = true
		searchCatalog(false)
	end
end
local function hidePanel(mode)
	local ticket = windowState:set(mode)
	if not ticket then
		return
	end
	closed = mode == "closed"
	closeDetails()
	if searchBox:IsFocused() then
		searchBox:ReleaseFocus(false)
	end
	if closed then
		request("Stop")
	end
	sliderInput = nil
	body.ScrollingEnabled = true
	drag = nil
	launcher.Visible = true
	local iconScale = launcher:FindFirstChildOfClass("UIScale")
	iconScale.Scale = 0.75
	tween(iconScale, { Scale = 1 }, 0.32, Enum.EasingStyle.Back)
	tween(panelScale, { Scale = 0.96 }, 0.2)
	tween(panel, { GroupTransparency = 1 }, 0.2)
	task.delay(0.21, function()
		if not destroyed and windowState:current(ticket) then
			panel.Visible = false
		end
	end)
	if not closed then
		notify("Minimizado · toca el icono FE para volver. Tu emote continúa.")
	end
end
connect(minimize.Activated, function()
	hidePanel("minimized")
end)
connect(close.Activated, function()
	hidePanel("closed")
end)
connect(launcher.Activated, function()
	if (drag and drag.target == launcher and drag.moved) or os.clock() - lastIconDrag < 0.2 then
		return
	end
	showPanel()
end)
connect(stopButton.Activated, function()
	request("Stop")
end)
connect(controlsToggle.Activated, function()
	controlsOpen = not controlsOpen
	controlsRevision = controlsRevision + 1
	local ticket = controlsRevision
	controlsGroup.Visible = true
	controlsToggle.Text = controlsOpen and "⌃" or "≡"
	tween(controlsGroup, { Size = UDim2.new(1, 0, 0, controlsOpen and 106 or 0) }, 0.24)
	task.delay(0.25, function()
		if not destroyed and ticket == controlsRevision and not controlsOpen then
			controlsGroup.Visible = false
		end
	end)
	paintControls()
end)

connect(minus.Activated, function()
	setSpeed(state.speed - Config.SpeedStep)
end)
connect(plus.Activated, function()
	setSpeed(state.speed + Config.SpeedStep)
end)
connect(lockButton.Activated, function()
	state.locked = not state.locked
	scheduleSettings()
end)
local function togglePause()
	state.paused = not state.paused
	scheduleSettings()
end
connect(pauseButton.Activated, togglePause)
connect(searchButton.Activated, function()
	searchCatalog(false)
end)
connect(searchBox.FocusLost, function(enterPressed)
	if enterPressed then
		searchCatalog(false)
	end
end)
connect(more.Activated, function()
	searchCatalog(catalogPages ~= nil and not catalogPages.IsFinished)
end)
for name, tab in pairs(tabs) do
	connect(tab.Activated, function()
		selectedTab = name
		renderCards(true)
	end)
end
local function selectView(name)
	closeDetails()
	viewQueries[selectedView] = searchBox.Text
	selectedView = name
	searchBox.Text = viewQueries[name]
	searchBox.PlaceholderText = name == "Catálogo" and "Buscar nombre, ID o enlace…"
		or "Filtrar tu colección…"
	navIndicator.Visible = name ~= "Favoritos"
	for i, key in ipairs({ "Catálogo", "Equipados" }) do
		if key == name then
			tween(navIndicator, { Position = UDim2.new((i - 1) / 2, 4, 0, 4) }, 0.25)
		end
		tween(viewButtons[key], { TextColor3 = key == name and C.background or C.muted })
	end
	local favoriteView = name == "Favoritos"
	tween(favoritesNav, {
		BackgroundColor3 = favoriteView and C.favorite or C.elevated,
		BackgroundTransparency = favoriteView and 0.06 or 0.42,
		TextColor3 = favoriteView and C.background or C.text,
	}, 0.2)
	tween(favoritesBorder, { Color = favoriteView and C.favorite or C.stroke }, 0.2)
	body.CanvasPosition = Vector2.new(0, 0)
	pageSurface.GroupTransparency = 0.45
	tween(pageSurface, { GroupTransparency = 0 }, 0.25)
	renderCards(true)
end
for name, viewButton in pairs(viewButtons) do
	connect(viewButton.Activated, function()
		selectView(name)
	end)
end
connect(searchBox:GetPropertyChangedSignal("Text"), function()
	localSearchRevision = localSearchRevision + 1
	local ticket = localSearchRevision
	if selectedView == "Catálogo" then
		return
	end
	task.delay(0.12, function()
		if not destroyed and ticket == localSearchRevision and selectedView ~= "Catálogo" then
			renderCards(false)
		end
	end)
end)
connect(remote.Changed, function(snapshot)
	if destroyed then
		return
	end
	local previousActive = state.active and state.active.Id
	local previousSlots = slotsSignature
	state.active, state.equipped, state.loading = snapshot.active, snapshot.equipped, snapshot.loading
	-- No hacer saltar el slider a un valor antiguo mientras el usuario lo arrastra.
	if not sliderInput and snapshot.settingsRevision >= settingsVersion then
		state.speed, state.locked, state.paused = snapshot.speed, snapshot.locked, snapshot.paused
		settingsVersion = snapshot.settingsRevision
		sentSettingsVersion = math.max(sentSettingsVersion, settingsVersion)
	end
	if snapshot.active then
		local found = false
		for _, item in ipairs(items) do
			if item.Id == snapshot.active.Id then
				found = true
				break
			end
		end
		if not found then
			table.insert(items, 1, snapshot.active)
			if #items > 120 then
				table.remove(items)
			end
		end
	end
	paintControls()
	renderSlots()
	if previousActive ~= (state.active and state.active.Id) or previousSlots ~= slotsSignature then
		renderCards()
	end
	if snapshot.message then
		notify(snapshot.message, snapshot.isError)
	end
end)
connect(UserInputService.InputBegan, function(input, processed)
	if not processed and not UserInputService:GetFocusedTextBox() and input.KeyCode == Enum.KeyCode.M then
		if windowState.mode == "open" then
			hidePanel("minimized")
		else
			showPanel()
		end
	end
end)
connect(player.CharacterAdded, function()
	state.active = nil
	paintControls()
	if not closed then
		notify("Nuevo personaje · tus accesos rápidos se mantienen.")
	end
	request("Sync")
end)
connect(gui.Destroying, function()
	remote:Destroy()
	destroyed = true
	details:Destroy()
	windowState:destroy()
	for object, animation in pairs(activeTweens) do
		animation:Cancel()
		activeTweens[object] = nil
	end
	searchRevision = searchRevision + 1
	request("Stop")
	for _, connection in ipairs(connections) do
		connection:Disconnect()
	end
end)

slotsSignature = "initial"
renderSlots()
renderCards(true)
paintControls()
task.defer(function()
	if not destroyed then
		resize()
	end
end)
request("Sync")
