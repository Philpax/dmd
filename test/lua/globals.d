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

template filter(alias predicate)
{
    auto filter(Range)(Range range)
    {
        return FilterResult!(predicate, Range)(range);
    }
}

private struct FilterResult(alias pred, Range)
{
    alias R = Range;
    R _input;

    this(R r)
    {
        _input = r;
        while (!_input.empty && !pred(_input.front))
        {
            _input.popFront();
        }
    }

    auto opSlice() { return this; }

    @property bool empty() { return _input.empty; }

    void popFront()
    {
        do
        {
            _input.popFront();
        } while (!_input.empty && !pred(_input.front));
    }

    @property auto ref front()
    {
        assert(!empty, "Attempting to fetch the front of an empty filter.");
        return _input.front;
    }
}
