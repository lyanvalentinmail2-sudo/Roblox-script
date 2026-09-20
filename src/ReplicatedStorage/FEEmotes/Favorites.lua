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
