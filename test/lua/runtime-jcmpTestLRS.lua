require("runtime-jcmpTestBase")
local player2 = Server.players[2]
assert(Events.Handlers.PlayerDeath { player = player2 } == true)
assert(Events.Handlers.PlayerSpawn { player = player2 } == false)
