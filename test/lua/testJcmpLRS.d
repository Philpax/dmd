//!RUNTIME: runtime-jcmpTestLRS.lua
import jcmp;
import math;
import table;

@safe:

const spawns = [
	Vector3(14197.319336, 458.649567, 14382.654297),
	Vector3(14053.989258, 451.647766, 14313.827148),
	Vector3(14192.114258, 438.649567, 14359.311523),
	Vector3(14109.357422, 423.588654, 14350.410156),
	Vector3(14162.669922, 434.653503, 14290.238281)
];

const deathSpawn = Vector3(14130.737305, 528.022278, 14341.015625);
const textColor = Color(115, 170, 220);
jcmp.Player[] players;

void StartGame()
{
    const message = "Starting game with " ~ tostring(Server.GetPlayerCount()) ~ " players";
    Chat.Broadcast("[Last Rico Standing] " ~ message, textColor);

    foreach (player; Server.Players)
    {
        table.insert(players, player);

        const randomIndex = math.random(0, spawns.length-1);
        const position = spawns[randomIndex];
        player.SetPosition(position);
        player.ClearInventory();

        const weapon = Weapon(28);
        player.GiveWeapon(2, weapon);
        player.SetHealth(1);
    }
}

bool PlayerSpawn(jcmp.PlayerSpawn e)
{
    if (players.length < 2 && Server.GetPlayerCount() >= 2)
    {
        StartGame();
    }
    else
    {
        e.player.ClearInventory();
        e.player.SetPosition(deathSpawn);

        const message = "[Last Rico Standing] A game in progress, please wait";
        e.player.SendChatMessage(message, textColor);
    }

    return false;
}

bool PlayerDeathOrQuit(jcmp.PlayerEvent e)
{
    // TODO: Think of a better way to handle this
    auto index = 1u;
    foreach (player; players)
    {
        if (player == e.player)
            break;
        ++index;
    }
    table.remove(players, index);

    if (players.length == 1)
    {
        const message = "[Last Rico Standing] " ~ players[0].GetName() ~ " has won the game!";
        Chat.Broadcast(message, textColor);
    }

    return true;
}

void main(string[] args)
{
    Events.AutoSubscribe(&PlayerSpawn);
    Events.Subscribe("PlayerDeath", (e) => PlayerDeathOrQuit(cast(PlayerEvent)e));
    Events.Subscribe("PlayerQuit", (e) => PlayerDeathOrQuit(cast(PlayerEvent)e));
    StartGame();
}
