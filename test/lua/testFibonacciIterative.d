void main() @safe
{
    int n0 = 1;
    int n1 = 1;

    print(n0);
    print(n1);

    foreach (_; 0..5)
    {
        auto temp = n0;
        n0 = n1;
        n1 += temp;
        print(n1);
    }
}
