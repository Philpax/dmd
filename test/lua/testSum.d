import math;
import io;
@safe:

auto sum(T...)(T args)
{
    T[0] ret;
    foreach (arg; args)
        ret += arg;
    return ret;
}

int main(string[] args)
{
    print(sum(1, 2, 3, 4));

    return 0;
}
