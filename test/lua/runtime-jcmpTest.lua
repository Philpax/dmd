require(arg[1])

Events = {
    Handlers = {},
    Subscribe = function(self, name, fn)
        self.Handlers[name] = fn
    end
}

function Vector3(x, y, z)
    local function __add(x, y)
        return {x = x.x + y.x, y = x.y + y.y, z = x.z + y.z, __add = __add} 
    end
    return {
        x = x,
        y = y, 
        z = z,
        __add = __add
    }
end

player = {
    position = Vector3(0, 0, 0),
    angle = {},
    SetPosition = function(self, pos)
        self.position = pos
    end,
    GetPosition = function(self)
        return self.position
    end,
    SetAngle = function(self, angle)
        self.angle = angle
    end,
    GetAngle = function(self)
        return self.angle
    end,
    EnterVehicle = function(self, vehicle, seat)
        print("Entered vehicle")
    end
}

Vehicle = {
    Create = function(id, pos, angle)
        print("Created vehicle")
    end
}

table.remove(arg, 1)
_Dmain(arg)
assert(Events.Handlers.ClientModuleLoad {player = player} == true)
assert(Events.Handlers.PlayerChat {player = player, text = "/up"} == false)
assert(player.position.y == 100)
assert(Events.Handlers.PlayerChat {player = player, text = "/down"} == false)
assert(player.position.y == 0)
assert(Events.Handlers.PlayerChat {player = player, text = "/invalid"} == true)
assert(Events.Handlers.ModuleUnload {} == true)
