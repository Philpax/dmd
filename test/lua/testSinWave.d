import math;
import io;
@safe:

int main(string[] args)
{
    foreach (x; 0..50)
    {
        const width = 25;
        auto f = math.sin(math.pi * x * 0.04);
        auto y = cast(int)math.floor(f * width);

        auto pad = math.min(25 + y, 25);

        foreach (_; 0..pad)
            io.write(" ");
        
        foreach (_; 0..math.abs(y))
            io.write("#");

        print();
    }

    return 0;
}
