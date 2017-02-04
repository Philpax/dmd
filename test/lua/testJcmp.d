//!RUNTIME: runtime-jcmpTest.lua
import jcmp;

@property Vector3 Position(Player player)
{
    return player.GetPosition();
}

@property void Position(Player player, Vector3 position)
{
    player.SetPosition(position);
}

@property Rotation Angle(Player player)
{
    return player.GetAngle();
}

@property void Angle(Player player, Rotation angle)
{
    player.SetAngle(angle);
}

bool ChatCommands(EventData e)
{
    auto event = cast(jcmp.PlayerChat)e;
    if (event.text == "/up")
    {
        event.player.Position = event.player.Position + Vector3(0, 100, 0);
        return false;
    }
    else if (event.text == "/down")
    {
        event.player.Position = event.player.Position + Vector3(0, -100, 0);
        return false;
    }
    else
    {
        return true;
    }
}

Vehicle vehicle = null;
bool ClientModuleLoad(EventData e)
{
    auto event = cast(jcmp.ClientModuleLoad)e;
    auto player = event.player;
    vehicle = Vehicle.Create(2, player.Position, player.Angle);
    player.EnterVehicle(vehicle, 0);

    return true;
}

int main(string[] args)
{
    Events.Subscribe("PlayerChat", &ChatCommands);
    Events.Subscribe("ClientModuleLoad", &ClientModuleLoad);
    Events.Subscribe("ModuleUnload", (_) {
        if (vehicle)
            vehicle.Remove();

        return true;
    });

    return 0;
}
