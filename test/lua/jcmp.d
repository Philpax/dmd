extern(Lua):

struct Vector3
{
    float x, y, z;
    Vector3 __add(Vector3 rhs);
}

struct Rotation
{
    float x, y, z, w;
    float yaw, pitch, roll;
}

final class ServerGlobal
{
public:
final:
    int GetPlayerCount();
}

extern ServerGlobal Server;

final class Player
{
public:
    double GetHealth();
    void SetHealth(double health);

    Vector3 GetPosition();
    void SetPosition(Vector3 position);

    Rotation GetAngle();
    void SetAngle(Rotation angle);

    void EnterVehicle(Vehicle vehicle, uint seat);
}

final class Vehicle
{
public:
    void Remove();

    static Vehicle Create(int id, Vector3 position, Rotation angle);
}

class EventData
{
}

class ClientModuleLoad : EventData
{
    Player player;
}

class PlayerChat : EventData
{
    Player player;
    string text;
}

class BaseEventManager
{
public:
final:
    alias CallbackD = extern(D) bool delegate(EventData);
    alias CallbackF = extern(D) bool function(EventData);
    void Subscribe(string name, CallbackD callback);
    void Subscribe(string name, CallbackF callback);
}

final class EventManager : BaseEventManager
{
public:
}

extern EventManager Events;
