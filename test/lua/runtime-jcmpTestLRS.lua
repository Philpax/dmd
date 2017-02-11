require("runtime-jcmpTestBase")
local players = Server.players
assert(Events.Handlers.PlayerDeath { player = players[2] } == true)
assert(Events.Handlers.PlayerSpawn { player = players[2] } == false)
assert(Events.Handlers.PlayerDeath { player = players[3] } == true)
assert(Events.Handlers.PlayerSpawn { player = players[3] } == false)
