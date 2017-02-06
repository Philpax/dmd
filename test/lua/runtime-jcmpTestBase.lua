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

function Color(r, g, b)
    local function __add(r, g)
        return {r = r.r + g.r, g = r.g + g.g, b = r.b + g.b, __add = __add} 
    end
    return {
        r = r,
        g = g, 
        b = b,
        __add = __add
    }
end

function Weapon(id)
    return {id = id}
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
    end,
    ClearInventory = function(self) end,
    GiveWeapon = function(self, slot, weapon) end,
    SetHealth = function(self, health) end
}

Server = {
    players = {player},
    GetPlayers = function(self)
        local index = 1
        return function()
            local ret = self.players[index]
            index = index + 1
            return ret
        end
    end,
    GetPlayerCount = function(self) return #self.players end
}

Chat = {
    Broadcast = function(self, text, color)
        print("[CHAT] " .. text)
    end
}

Vehicle = {
    Create = function(id, pos, angle)
        print("Created vehicle")
    end
}

require(arg[1])

table.remove(arg, 1)
_Dmain(arg)
