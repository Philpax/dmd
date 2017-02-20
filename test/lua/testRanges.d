void main() @safe
{
    import std.range : iota;
    import std.algorithm : map, filter;
    foreach (i; 10.iota.map!(a => a * a).filter!(a => a > 50))
        print(i);
}
