@safe:

struct Test
{
    int a = 5;
    string b = "hello";

    this(int a, string b)
    {
        this.a = a;
        this.b = b;
    }

    void printValues()
    {
        print(this.a, this.b);
    }

    Test opBinary(string op)(Test rhs)
        if (op == "+")
    {
        return Test(this.a + rhs.a, this.b);
    }
}

int main()
{
    Test test;
    print(test.a);
    test.printValues();

    Test test2;
    auto test3 = test2;
    (test + test2 + test3).printValues();

    return 0;
}
