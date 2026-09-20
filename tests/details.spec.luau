local client = detailClient()
client.select(123)
check(client.snapshot().canBuy and client.snapshot().price == 50, "detalles: precio real y disponible")
check(client.snapshot().item.Name == "Emote 123", "detalles: nombre validado")
check(#client.prompts == 0, "detalles: seleccionar no abre compra")
check(client.controller:purchase(), "detalles: compra requiere acción explícita")
advance(0)
check(#client.prompts == 1 and client.prompts[1] == 123, "detalles: ID exacto al prompt oficial")
check(not client.controller:purchase() and #client.prompts == 1, "detalles: bloqueo de doble compra")
client.marketplace.PromptPurchaseFinished:Fire({}, 123, false)
client.marketplace.PromptPurchaseFinished:Fire(client.player, 124, false)
advance(0)
check(client.snapshot().purchasing, "detalles: ignora eventos ajenos")
client.marketplace.PromptPurchaseFinished:Fire(client.player, 123, false)
advance(0)
check(
	not client.snapshot().purchasing and client.snapshot().canBuy,
	"detalles: cancelación permite reintentar"
)
client.controller:purchase()
advance(0)
client.marketplace.PromptPurchaseFinished:Fire(client.player, 123, true)
advance(0)
check(not client.snapshot().owned, "detalles: flag de prompt no demuestra compra procesada")
client.controller:purchase()
advance(0)
client.options.owned = true
client.marketplace.PromptPurchaseFinished:Fire(client.player, 123, true)
advance(0)
check(
	client.snapshot().owned and not client.snapshot().canBuy,
	"detalles: propiedad verificada tras el prompt"
)
check(not client.controller:purchase(), "detalles: bloquea comprar si ya lo tienes")

local unavailable = detailClient()
unavailable.options.forSale = false
unavailable.select(123)
check(not unavailable.snapshot().canBuy and not unavailable.controller:purchase(), "detalles: fuera de venta")
unavailable.options.forSale = true
unavailable.options.price = 0
unavailable.select(124)
check(unavailable.snapshot().price == 0 and unavailable.snapshot().canBuy, "detalles: emote gratuito")
unavailable.options.price = nil
unavailable.select(125)
check(unavailable.snapshot().price == nil and unavailable.snapshot().canBuy, "detalles: precio no se inventa")
unavailable.select(999)
check(
	unavailable.snapshot().isError and not unavailable.controller:purchase(),
	"detalles: no permite otro tipo de asset"
)
local defensive = detailClient()
local original = { Id = 123, Name = "Original" }
defensive.controller:select(original)
original.Id = 124
advance(0)
check(
	defensive.snapshot().item.Id == 123 and defensive.snapshot().item.Name == "Emote 123",
	"detalles: ID inmutable durante consulta"
)
local queries = unavailable.queries()
unavailable.select(-1)
unavailable.select("123")
check(unavailable.queries() == queries, "detalles: IDs inválidos no llaman a Roblox")

local errors = detailClient()
errors.options.infoError = true
errors.select(123)
check(errors.snapshot().isError and not errors.snapshot().loading, "detalles: fallo de consulta")
errors.options.infoError = false
errors.options.ownershipError = true
errors.select(123)
check(errors.snapshot().isError and not errors.snapshot().canBuy, "detalles: fallo de inventario")
errors.options.ownershipError = false
errors.options.promptError = true
errors.select(123)
errors.controller:purchase()
advance(0)
check(errors.snapshot().isError and not errors.snapshot().purchasing, "detalles: prompt no disponible")

local stale = detailClient()
stale.options.delay = 5
stale.select(123)
stale.options.delay = 0
stale.select(124)
advance(6)
check(
	stale.snapshot().item.Id == 124 and stale.snapshot().item.Name == "Emote 124",
	"detalles: descarta resultados obsoletos"
)
stale.controller:purchase()
stale.controller:clear() -- Antes de que se ejecute la tarea del prompt.
advance(0)
check(#stale.prompts == 0, "detalles: cerrar cancela un prompt aún no abierto")

local timeout = detailClient()
timeout.options.delay = 20
timeout.select(123)
advance(13)
check(not timeout.snapshot().loading and timeout.snapshot().isError, "detalles: timeout recuperable")
timeout.options.delay = 0
timeout.select(124)
advance(8)
check(
	timeout.snapshot().item.Id == 124 and timeout.snapshot().canBuy,
	"detalles: reintento después del timeout"
)

local destroyed = detailClient()
destroyed.options.delay = 2
destroyed.select(123)
local updates = destroyed.updates()
destroyed.controller:Destroy()
advance(3)
check(destroyed.updates() == updates, "detalles: destruir cancela callbacks tardíos")
check(not destroyed.controller:purchase(), "detalles: controlador destruido no abre compras")
local queued = detailClient()
queued.select(123)
queued.controller:purchase()
queued.controller:Destroy()
advance(0)
check(#queued.prompts == 0, "detalles: destruir cancela prompt pendiente")
print("Detalles y compra oficial: " .. assertions .. " comprobaciones correctas (sin compras reales)")
