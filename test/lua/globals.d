extern (Lua):
@safe:

void print(...);
double tonumber(string s);
string tostring(...);

alias Iterator(T) = T delegate();
