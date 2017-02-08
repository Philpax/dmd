Events = {
    Handlers = {},
    Subscribe = function(self, name, fn)
        self.Handlers[name] = fn
    end
}

function Vector3(x, y, z)
    local mt = {}
    mt.__add = function(x, y)
        local t = {x = x.x + y.x, y = x.y + y.y, z = x.z + y.z}
        setmetatable(t, mt)
        return t
    end

    local t = {x = x, y = y, z = z}
    setmetatable(t, mt)
    return t
end

function Color(r, g, b)
    local mt = {}
    mt.__add = function(x, y)
        local t = {r = x.r + y.r, g = x.g + y.g, b = x.b + y.b} 
        setmetatable(t, mt)
        return t
    end

    local t = {r = r, g = g, b = b}
    setmetatable(t, mt)
    return t
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
