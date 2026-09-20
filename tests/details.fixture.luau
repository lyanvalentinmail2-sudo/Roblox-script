local function detailClient()
	local options = { owned = false, forSale = true, price = 50, delay = 0 }
	local buyer = {}
	local prompts, snapshots = {}, {}
	local queries = 0
	local marketplace = { PromptPurchaseFinished = signal() }
	function marketplace:GetProductInfoAsync(id)
		queries = queries + 1
		if options.delay > 0 then
			task.wait(options.delay)
		end
		if options.infoError then
			error("Metadata unavailable")
		end
		return {
			AssetTypeId = id == 999 and 10 or 61,
			Name = "Emote " .. id,
			IsForSale = options.forSale,
			PriceInRobux = options.price,
			Creator = { Name = "Roblox", CreatorTargetId = 1, CreatorType = "User" },
		}
	end
	function marketplace:PlayerOwnsAssetAsync(player, id)
		assert(player == buyer and Validation.assetId(id))
		if options.ownershipError then
			error("Inventory unavailable")
		end
		return options.owned
	end
	function marketplace:PromptPurchase(player, id)
		assert(player == buyer)
		if options.promptError then
			error("Unsupported")
		end
		table.insert(prompts, id)
	end
	local controller = EmoteDetails.new(marketplace, buyer, Validation, function(snapshot)
		table.insert(snapshots, snapshot)
	end)
	return {
		controller = controller,
		options = options,
		player = buyer,
		marketplace = marketplace,
		prompts = prompts,
		snapshot = function()
			return snapshots[#snapshots]
		end,
		queries = function()
			return queries
		end,
		select = function(id)
			controller:select({ Id = id, Name = "Original", Creator = "Creator" })
			advance(0)
		end,
		updates = function()
			return #snapshots
		end,
	}
end
