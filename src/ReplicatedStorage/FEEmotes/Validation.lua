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
