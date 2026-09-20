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
