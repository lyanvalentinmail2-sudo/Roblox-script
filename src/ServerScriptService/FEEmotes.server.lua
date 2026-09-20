-- FE Emotes • servidor autoritativo. No requiere HTTP, loadstring ni ejecutores.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MarketplaceService = game:GetService("MarketplaceService")
local InsertService = game:GetService("InsertService")

local shared = ReplicatedStorage:WaitForChild("FEEmotes")
local Config = require(shared:WaitForChild("Config"))
local Validation = require(shared:WaitForChild("Validation"))

-- Opcional: mapea un ID de emote a una animación que TU experiencia pueda usar.
-- Solo el desarrollador modifica esta tabla; nunca se aceptan AnimationIds del cliente.
local AnimationOverrides = {
	-- [ID_DEL_EMOTE] = ID_DE_ANIMACION_AUTORIZADA,
}

local remote = Instance.new("RemoteEvent")
remote.Name = "Request"
remote.Parent = shared
local sessions = {}
local cache, cacheOrder = {}, {}
local activeLoads = 0

local function send(player, state, message, isError)
	if player.Parent ~= Players then
		return
	end
	remote:FireClient(player, {
		active = state.active,
		equipped = state.equipped,
		speed = state.speed,
		locked = state.locked,
		paused = state.paused,
		loading = state.busy,
		settingsRevision = state.settingsRevision,
		message = message,
		isError = isError == true,
	})
end

local function clearTrack(state)
	if state.ended then
		state.ended:Disconnect()
		state.ended = nil
	end
	if state.track then
		local track = state.track
		state.track = nil
		track:Stop(0.15)
		task.delay(0.2, function()
			track:Destroy()
		end)
	end
	state.active = nil
end

local function stop(player, state, message)
	state.revision = state.revision + 1
	state.busy = false
	clearTrack(state)
	send(player, state, message)
end

local function cacheEntry(id, entry)
	if not cache[id] then
		table.insert(cacheOrder, id)
	end
	cache[id] = entry
	while #cacheOrder > Config.MaxCacheEntries do
		cache[table.remove(cacheOrder, 1)] = nil
	end
end

local function resolve(id, needsAnimation)
	local entry = cache[id]
	if not entry then
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfoAsync(id, Enum.InfoType.Asset)
		end)
		if not ok then
			return nil, "No se pudo consultar ese ID. Inténtalo de nuevo."
		end
		if info.AssetTypeId ~= Enum.AssetType.EmoteAnimation.Value then
			return nil, "Ese ID no es un emote del catálogo de Roblox."
		end
		local creator = info.Creator or {}
		entry = {
			item = {
				Id = id,
				Name = info.Name,
				Creator = creator.Name or "Creador",
				IsRoblox = Validation.isRoblox(creator.CreatorTargetId or creator.Id, creator.CreatorType),
			},
		}
		cacheEntry(id, entry)
	end
	if needsAnimation and not entry.animation then
		local override = AnimationOverrides[id]
		if override and Validation.assetId(override) then
			entry.animation = "rbxassetid://" .. tostring(override)
		else
			local ok, container = pcall(function()
				return InsertService:LoadAsset(id)
			end)
			if not ok then
				return nil, "Roblox no permite cargar este emote aquí. Revisa los permisos del asset."
			end
			-- Nunca se inserta el contenedor en el DataModel ni se ejecuta su código.
			local animation = container:FindFirstChildWhichIsA("Animation", true)
			local animationId = animation and animation.AnimationId
			container:Destroy()
			if not animationId or animationId == "" then
				return nil, "Este emote no contiene una animación compatible."
			end
			entry.animation = animationId
		end
	end
	return entry
end

local function alive(player, character)
	if player.Character ~= character or not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return nil
	end
	return humanoid
end

local function moving(humanoid)
	local root = humanoid.RootPart
	return root and Vector3.new(root.AssemblyLinearVelocity.X, 0, root.AssemblyLinearVelocity.Z).Magnitude > 1
end

local function perform(player, state, action, id)
	if state.busy then
		send(player, state, "Espera a que termine la carga.", true)
		return
	end
	if activeLoads >= 12 or os.clock() - state.lastLoad < 0.8 then
		send(player, state, "Un momento… vuelve a intentarlo.", true)
		return
	end
	state.lastLoad = os.clock()
	state.revision = state.revision + 1
	local revision = state.revision
	local character = player.Character
	state.busy = true
	activeLoads = activeLoads + 1
	send(player, state, action == "Play" and "Cargando emote…" or "Equipando…")

	local function current()
		return sessions[player] == state and state.revision == revision and player.Character == character
	end
	-- Una petición antigua no puede arrancar tras detener, cerrar o reaparecer.
	task.delay(Config.LoadTimeout, function()
		if current() and state.busy then
			state.revision = state.revision + 1
			state.busy = false
			send(player, state, "La carga tardó demasiado. Puedes volver a intentarlo.", true)
		end
	end)

	local ok, failure = pcall(function()
		local entry, problem = resolve(id, action == "Play")
		if not current() then
			return
		end
		if not entry then
			state.busy = false
			send(player, state, problem, true)
			return
		end
		if action == "Equip" then
			table.insert(state.equipped, entry.item)
			state.busy = false
			send(player, state, "Emote equipado en tu acceso rápido.")
			return
		end
		local humanoid = alive(player, character)
		if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
			state.busy = false
			send(player, state, "Necesitas un personaje R15 vivo para usar estos emotes.", true)
			return
		end
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if not animator then
			animator = Instance.new("Animator")
			animator.Parent = humanoid -- Creado en servidor para replicación FE.
		end
		local animation = Instance.new("Animation")
		animation.AnimationId = entry.animation
		local loaded, track = pcall(function()
			return animator:LoadAnimation(animation)
		end)
		animation:Destroy()
		if not loaded then
			error("Animator no pudo cargar el emote")
		end
		-- LoadAnimation puede devolver una pista que todavía no cargó o no tiene permisos.
		local deadline = os.clock() + 8
		while track.Length == 0 and current() and os.clock() < deadline do
			task.wait(0.1)
		end
		if not current() then
			track:Destroy()
			return
		end
		if track.Length == 0 or not alive(player, character) then
			track:Destroy()
			error("Animación vacía, restringida o personaje no disponible")
		end
		if not state.locked and moving(humanoid) then
			track:Destroy()
			state.busy = false
			send(player, state, "Detente o activa «Mantener al moverte».", true)
			return
		end
		clearTrack(state)
		track.Priority = Enum.AnimationPriority.Action
		track.Looped = true
		state.track = track
		state.active = entry.item
		state.busy = false
		track:Play(0.15, 1, state.paused and 0 or state.speed)
		state.ended = track.Stopped:Connect(function()
			if state.track == track then
				clearTrack(state)
				send(player, state, "Emote finalizado.")
			end
		end)
		send(player, state, "Emote listo. ¡A tu ritmo!")
	end)
	activeLoads = activeLoads - 1
	if not ok and current() then
		state.busy = false
		warn("[FE Emotes] Error de carga:", failure)
		send(player, state, "No se pudo reproducir. Comprueba el rig y los permisos de la animación.", true)
	end
end

local function addPlayer(player)
	if sessions[player] then
		return
	end
	local state = {
		equipped = {},
		speed = 1,
		locked = false,
		paused = false,
		busy = false,
		revision = 0,
		settingsRevision = 0,
		lastLoad = -math.huge,
		bucket = { tokens = 12, time = os.clock() },
		connections = {},
	}
	sessions[player] = state
	local function characterAdded(character)
		for _, connection in ipairs(state.connections) do
			connection:Disconnect()
		end
		state.connections = {}
		stop(player, state)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if not humanoid or player.Character ~= character or sessions[player] ~= state then
			return
		end
		table.insert(
			state.connections,
			humanoid.Running:Connect(function(speed)
				if speed > 0.75 and state.track and not state.locked then
					stop(player, state, "Emote detenido al moverte.")
				end
			end)
		)
		table.insert(
			state.connections,
			humanoid.StateChanged:Connect(function(_, newState)
				if
					state.track
					and not state.locked
					and (
						newState == Enum.HumanoidStateType.Jumping
						or newState == Enum.HumanoidStateType.Freefall
						or newState == Enum.HumanoidStateType.Swimming
					)
				then
					stop(player, state, "Emote detenido al moverte.")
				end
			end)
		)
		table.insert(
			state.connections,
			humanoid.Died:Connect(function()
				stop(player, state)
			end)
		)
	end
	state.added = player.CharacterAdded:Connect(characterAdded)
	state.removing = player.CharacterRemoving:Connect(function()
		stop(player, state)
	end)
	if player.Character then
		task.spawn(characterAdded, player.Character)
	end
end

remote.OnServerEvent:Connect(function(player, request)
	local state = sessions[player]
	if not state or type(request) ~= "table" or type(request.action) ~= "string" then
		return
	end
	-- Rate limiting antes de cualquier llamada de catálogo o carga.
	if not Validation.consume(state.bucket, os.clock(), 12, 6) then
		return
	end
	local action = request.action
	if action == "Sync" then
		send(player, state)
	elseif action == "Stop" then
		stop(player, state, "Emote detenido.")
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
		state.settingsRevision = request.settingsRevision
		state.speed, state.locked, state.paused = request.speed, request.locked, request.paused
		if state.track then
			state.track:AdjustSpeed(state.paused and 0 or state.speed)
			local humanoid = alive(player, player.Character)
			if not state.locked and humanoid and moving(humanoid) then
				stop(player, state, "Emote detenido al moverte.")
				return
			end
		end
		send(player, state)
	elseif (action == "Play" or action == "Equip") and Validation.assetId(request.id) then
		if action == "Equip" then
			if state.busy then
				send(player, state, "Espera a que termine la carga.", true)
				return
			end
			for i, item in ipairs(state.equipped) do
				if item.Id == request.id then
					table.remove(state.equipped, i)
					send(player, state, "Emote retirado del acceso rápido.")
					return
				end
			end
			if #state.equipped >= Config.MaxEquipped then
				send(player, state, "Tienes 8 emotes equipados. Retira uno desde «Equipados».", true)
				return
			end
		end
		perform(player, state, action, request.id)
	end
end)

Players.PlayerAdded:Connect(addPlayer)
Players.PlayerRemoving:Connect(function(player)
	local state = sessions[player]
	if not state then
		return
	end
	sessions[player] = nil
	state.revision = state.revision + 1
	clearTrack(state)
	state.added:Disconnect()
	state.removing:Disconnect()
	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end
end)
for _, player in ipairs(Players:GetPlayers()) do
	addPlayer(player)
end
