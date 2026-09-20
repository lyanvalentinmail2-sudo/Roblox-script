local client = localClient()
check(client.send("Sync").speed == 1, "standalone: estado inicial")
client.send("Play", 123)
check(client.snapshot().active.Id == 123 and track().playing, "standalone: reproducción sin servidor")
check(fixture.remote == nil, "standalone: no crea RemoteEvents")
check(fixture.objectsDestroyed == 1, "standalone: destruye todos los objetos cargados")
client.send("Settings", nil, { speed = 2, locked = true, paused = false, settingsRevision = 1 })
check(track().speed == 2, "standalone: velocidad")
client.humanoid.Running:Fire(10)
advance(0)
check(track().playing, "standalone: mantiene al moverse")
client.send("Settings", nil, { speed = 2, locked = true, paused = true, settingsRevision = 2 })
check(track().speed == 0, "standalone: pose congelada")
client.send("Settings", nil, { speed = 1, locked = true, paused = false, settingsRevision = 1 })
check(track().speed == 0, "standalone: ajustes obsoletos ignorados")
client.send("Settings", nil, { speed = 1, locked = false, paused = false, settingsRevision = 3 })
client.humanoid.Running:Fire(10)
advance(0)
check(not track().playing and not client.snapshot().active, "standalone: movimiento cancela")
client.send("Play", 123)
client.send("Stop")
advance(0.3)
check(track().destroyed and not client.snapshot().active, "standalone: detener limpia")

local equipped = localClient()
local calls = fixture.getObjectsCalls
for i = 1, 8 do
	equipped.send("Equip", 1000 + i)
end
check(#equipped.snapshot().equipped == 8, "standalone: ocho equipados")
check(fixture.getObjectsCalls == calls, "standalone: equipar no carga objetos")
equipped.send("Equip", 1009)
check(#equipped.snapshot().equipped == 8 and equipped.snapshot().isError, "standalone: límite")
equipped.send("Equip", 1001)
check(#equipped.snapshot().equipped == 7, "standalone: retirar")
equipped.player.CharacterRemoving:Fire()
advance(0)
check(#equipped.snapshot().equipped == 7, "standalone: conservar accesos tras respawn")

local invalid = localClient()
calls = fixture.getObjectsCalls
invalid.send("Play", 999)
check(invalid.snapshot().isError and fixture.getObjectsCalls == calls, "standalone: valida tipo de asset")
local reads = fixture.reads
invalid.send("Play", -5)
invalid.send("Play", "123")
invalid.send("Play", 0 / 0)
check(fixture.reads == reads, "standalone: valida IDs")
fixture.denied = true
invalid.send("Play", 555)
fixture.denied = false
check(invalid.snapshot().isError and not invalid.snapshot().loading, "standalone: GetObjects bloqueado")
fixture.noAnimation = true
invalid.send("Play", 556)
fixture.noAnimation = false
check(invalid.snapshot().isError and not invalid.snapshot().loading, "standalone: asset sin Animation")

local r6 = localClient()
r6.humanoid.RigType = "R6"
r6.send("Play", 123)
check(r6.snapshot().isError and not r6.snapshot().active, "standalone: R6 informa error")
local missing = localClient()
missing.humanoid.FindFirstChildOfClass = function()
	return nil
end
missing.send("Play", 123)
check(missing.snapshot().isError, "standalone: no crea Animator local ni simula FE")

local slow = localClient()
fixture.delay = 3
slow.send("Play", 777)
check(slow.snapshot().loading, "standalone: estado de carga")
slow.send("Stop")
advance(4)
fixture.delay = 0
check(not slow.snapshot().active and not slow.snapshot().loading, "standalone: cerrar cancela carga")

local timeout = localClient()
fixture.delay = 20
timeout.send("Play", 778)
advance(16)
check(timeout.snapshot().isError and not timeout.snapshot().loading, "standalone: timeout")
fixture.delay = 0
timeout.send("Play", 123)
check(timeout.snapshot().active.Id == 123, "standalone: reintento")
advance(5)
check(timeout.snapshot().active.Id == 123, "standalone: carga vieja no reemplaza pista nueva")

local zero = localClient()
fixture.length = 0
zero.send("Play", 123)
advance(9)
fixture.length = 2
check(zero.snapshot().isError and track().destroyed, "standalone: pista vacía se destruye")

local reinject = localClient()
reinject.send("Play", 123)
local oldTrack = track()
reinject.controller:Destroy()
advance(0.3)
check(oldTrack.destroyed and not oldTrack.playing, "standalone: reinyección limpia pista")
local count = #fixture.tracks
reinject.send("Play", 123)
check(#fixture.tracks == count, "standalone: controlador destruido no reproduce")
local pending = localClient()
fixture.delay = 3
pending.send("Play", 779)
pending.controller:Destroy()
advance(4)
fixture.delay = 0
check(#fixture.tracks == count, "standalone: destruir cancela cargas pendientes")
print("Standalone: " .. assertions .. " comprobaciones correctas (dobles, no Delta real)")
