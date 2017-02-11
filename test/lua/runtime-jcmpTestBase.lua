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
    mt.__sub = function(x, y)
        local t = {x = x.x - y.x, y = x.y - y.y, z = x.z - y.z}
        setmetatable(t, mt)
        return t
    end
    mt.__eq = function(a, b)
        return (a.x == b.x) and (a.y == b.y) and (a.z == b.z)
    end
    mt.__tostring = function(v)
        return ("%f, %f, %f"):format(v.x, v.y, v.z)
    end
    mt.__index = {
        Distance = function(a, b)
            local d = a - b
            return math.sqrt(d.x*d.x + d.y*d.y + d.z*d.z)
        end
    }

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

function Player(id, name)
    local t = {
        id = id,
        name = name,
        position = Vector3(0, 0, 0),
        angle = {}
    }

    local mt = {}
    mt.__eq = function(a, b)
        return a.id == b.id
    end
    mt.__index = {
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

        GetName = function(self)
            return self.name
        end,

        EnterVehicle = function(self, vehicle, seat)
            print(self:GetName() .. " entered vehicle " .. vehicle:GetId())
        end,

        ClearInventory = function(self)
            print(self:GetName() .. " cleared inventory")
        end,
        GiveWeapon = function(self, slot, weapon)
            print(self:GetName() .. " received weapon")
        end,

        SetHealth = function(self, health)
        end,

        SendChatMessage = function(self, msg, colour)
            print("[CHAT for " .. self:GetName() .. "]: " .. msg)
        end,
    }
    setmetatable(t, mt)
    return t
end

Server = {
    players = {Player(1, "Player1"), Player(2, "Player2"), Player(3, "Player3")},
    GetPlayers = function(self)
        local index = 1
        return function()
            local ret = self.players[index]
            index = index + 1
            return ret
        end
    end,
    GetPlayerCount = function(self)
        return #self.players
    end
}

Chat = {
    Broadcast = function(self, text, color)
        print("[CHAT] " .. text)
    end
}

Vehicle = {
    Create = function(id, pos, angle)
        local t = {id = id, pos = pos, angle = angle}
        local mt = {}
        mt.__index = {
            GetId = function(self)
                return self.id
            end,
            Remove = function(self)
                print("Vehicle " .. tostring(self:GetId()) .. " removed")
            end
        }
        setmetatable(t, mt)
        return t
    end
}

require(arg[1])

table.remove(arg, 1)
_Dmain(arg)
