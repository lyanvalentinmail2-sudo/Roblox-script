local player, humanoid = makePlayer()
check(send(player, "Sync").speed == 1, "estado inicial")
send(player, "Play", 123)
check(snapshot(player).active.Id == 123 and track().playing, "reproducción")
check(track().Priority == "Action" and track().Looped, "prioridad y bucle")
send(player, "Settings", nil, { speed = 2, locked = true, paused = false, settingsRevision = 1 })
check(track().speed == 2, "velocidad en servidor")
humanoid.Running:Fire(10)
advance(0)
check(track().playing, "mantener al caminar")
send(player, "Settings", nil, { speed = 2, locked = true, paused = true, settingsRevision = 2 })
check(track().speed == 0, "congelar pose")
send(player, "Settings", nil, { speed = 3, locked = false, paused = false, settingsRevision = 1 })
check(snapshot(player).settingsRevision == 2 and track().speed == 0, "ignora ajustes antiguos")
send(player, "Settings", nil, { speed = 0 / 0, locked = false, paused = false, settingsRevision = 3 })
check(track().speed == 0, "rechaza NaN")
send(player, "Settings", nil, { speed = 1, locked = false, paused = false, settingsRevision = 3 })
humanoid.Running:Fire(10)
advance(0)
check(not track().playing and not snapshot(player).active, "movimiento sin mantener detiene")
advance(1)
send(player, "Play", 123)
send(player, "Stop")
advance(0.3)
check(not snapshot(player).active and track().destroyed, "stop limpia la pista")

local equipped = makePlayer()
for i = 1, 8 do
	advance(1)
	send(equipped, "Equip", 1000 + i)
end
check(#snapshot(equipped).equipped == 8, "ocho accesos rápidos")
advance(1)
send(equipped, "Equip", 1009)
check(#snapshot(equipped).equipped == 8 and snapshot(equipped).isError, "límite de equipados")
send(equipped, "Equip", 1001)
check(#snapshot(equipped).equipped == 7, "retirar equipado")
equipped.CharacterRemoving:Fire()
advance(0)
check(#snapshot(equipped).equipped == 7, "equipados conservados al reaparecer")

local invalid = makePlayer()
local reads = fixture.reads
send(invalid, "Play", "123")
send(invalid, "Play", math.huge)
check(fixture.reads == reads, "IDs inválidos no consultan Roblox")
send(invalid, "Play", 999)
check(snapshot(invalid).isError and not snapshot(invalid).active, "rechaza assets no emote")
advance(1)
fixture.denied = true
send(invalid, "Play", 789)
fixture.denied = false
check(snapshot(invalid).isError and not snapshot(invalid).loading, "permisos denegados recuperables")

local r6, r6Humanoid = makePlayer()
r6Humanoid.RigType = "R6"
send(r6, "Play", 123)
check(snapshot(r6).isError and not snapshot(r6).active, "R6 rechazado explícitamente")

local slow = makePlayer()
fixture.delay = 3
send(slow, "Play", 555)
check(snapshot(slow).loading, "carga asíncrona")
send(slow, "Stop")
advance(4)
fixture.delay = 0
check(not snapshot(slow).active and not snapshot(slow).loading, "stop cancela una carga tardía")

local timeout = makePlayer()
fixture.delay = 20
send(timeout, "Play", 556)
advance(16)
check(snapshot(timeout).isError and not snapshot(timeout).loading, "timeout libera la interfaz")
fixture.delay = 0
send(timeout, "Play", 123)
check(snapshot(timeout).active.Id == 123, "se puede reintentar tras timeout")
advance(5)
check(snapshot(timeout).active.Id == 123, "carga obsoleta no reemplaza el reintento")

local emptyAnimation = makePlayer()
fixture.length = 0
send(emptyAnimation, "Play", 123)
advance(9)
fixture.length = 2
check(snapshot(emptyAnimation).isError and track().destroyed, "pista vacía se destruye")

local dead, deadHumanoid = makePlayer()
send(dead, "Play", 123)
deadHumanoid.Died:Fire()
advance(0)
check(not snapshot(dead).active and not track().playing, "muerte detiene")

local leaving = makePlayer()
fixture.delay = 2
send(leaving, "Play", 557)
Players.PlayerRemoving:Fire(leaving)
leaving.Parent = nil
advance(3)
fixture.delay = 0
check(not snapshot(leaving).active, "salir cancela cargas pendientes")
print("Servidor: " .. assertions .. " comprobaciones correctas (dobles de Roblox)")
