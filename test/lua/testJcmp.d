//!RUNTIME: runtime-jcmpTest.lua
import jcmp;
@safe:

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

bool ChatCommands(jcmp.PlayerChat event)
{
    switch (event.text)
    {
    case "/up":
        event.player.Position = event.player.Position + Vector3(0, 100, 0);
        return false;
    case "/down":
        event.player.Position = event.player.Position + Vector3(0, -100, 0);
        return false;
    default:
        return true;
    }
}

Vehicle vehicle = null;
bool ClientModuleLoad(jcmp.ClientModuleLoad event)
{
    auto player = event.player;
    vehicle = Vehicle.Create(2, player.Position, player.Angle);
    player.EnterVehicle(vehicle, VehicleSeat.Driver);

    return true;
}

int main(string[] args)
{
    Events.AutoSubscribe(&ChatCommands);
    Events.AutoSubscribe(&ClientModuleLoad);
    Events.Subscribe("ModuleUnload", (_) {
        if (vehicle)
            vehicle.Remove();

        return true;
    });

    return 0;
}
