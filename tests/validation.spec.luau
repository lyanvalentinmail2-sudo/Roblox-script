-- El runner inyecta Validation y Config desde los módulos reales.
local count = 0
local function check(condition, message)
	assert(condition, message)
	count = count + 1
end
for _, id in ipairs({ 1, 3576686446, 9007199254740991 }) do
	check(Validation.assetId(id), "ID válido rechazado")
end
for _, id in ipairs({ 0, -1, 1.5, math.huge, -math.huge, 0 / 0, "123", {}, false, 9007199254740992 }) do
	check(not Validation.assetId(id), "ID peligroso aceptado")
end
check(not Validation.assetId(nil), "nil aceptado")
check(Validation.parseId(" 3576686446 ") == 3576686446, "ID con espacios")
check(Validation.parseId("https://www.roblox.com/catalog/3576686446/Hello") == 3576686446, "URL")
check(
	Validation.parseId("https://www.roblox.com/es/catalog/3576686446/Hello") == 3576686446,
	"URL localizada"
)
for _, value in ipairs({
	"Hello",
	"-123",
	"1.2",
	"https://evil.test/catalog/123",
	"0",
	"https://www.roblox.com.evil.test/catalog/123",
}) do
	check(Validation.parseId(value) == nil, "URL o ID inválido aceptado")
end
check(Validation.speed(0.25, Config.MinSpeed, Config.MaxSpeed), "velocidad mínima")
check(Validation.speed(3, Config.MinSpeed, Config.MaxSpeed), "velocidad máxima")
for _, value in ipairs({ 0, -1, 4, math.huge, 0 / 0, "1" }) do
	check(not Validation.speed(value, Config.MinSpeed, Config.MaxSpeed), "velocidad inválida")
end
check(Validation.isRoblox(1, "User"), "creador Roblox")
check(Validation.isRoblox(1, 1), "CreatorType numérico")
check(not Validation.isRoblox(1, "Group"), "grupo 1 no es Roblox")
check(not Validation.isRoblox(99, "User"), "UGC no es Roblox")
local bucket = { tokens = 2, time = 0 }
check(Validation.consume(bucket, 0, 2, 1), "primer token")
check(Validation.consume(bucket, 0, 2, 1), "segundo token")
check(not Validation.consume(bucket, 0, 2, 1), "freno a spam")
check(Validation.consume(bucket, 1, 2, 1), "recarga")
check(Validation.consume(bucket, 999, 2, 1), "recarga tras inactividad")
check(bucket.tokens == 1, "capacidad máxima")
for _, item in ipairs(Config.Featured) do
	check(Validation.assetId(item.Id) and type(item.Name) == "string", "destacado válido")
end
print("Validation: " .. count .. " comprobaciones correctas")
