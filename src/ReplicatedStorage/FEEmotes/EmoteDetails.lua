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
