extern (Lua):
@safe:

void print(...);
double tonumber(string s);
string tostring(...);

alias Iterator(T) = T delegate() @safe;

extern(D):
struct IteratorRange(T)
{
    private Iterator!T iterator;
    private T head;

    this(Iterator!T iterator)
    {
        this.iterator = iterator;
        this.popFront();
    }

    @property T front()
    {
        return this.head;
    }

    void popFront()
    {
        this.head = iterator();
    }

    @property bool empty()
    {
        return this.head is null;
    }
}
