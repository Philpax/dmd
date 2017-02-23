void main() @safe
{
    import std.range : iota;
    import std.algorithm : map, filter, each;
    10.iota.map!(a => a * a).filter!(a => a > 50).each!print;
}
