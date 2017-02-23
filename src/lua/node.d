module ddmd.lua.node;

import ddmd.lua.visitor;

class Node
{
    void accept(Visitor visitor)
    {
        visitor.visit(this);
    }
}
