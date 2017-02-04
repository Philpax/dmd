module ddmd.lua.visitor;

import ddmd.lua.node;
import ddmd.lua.statement;
import ddmd.lua.declaration;
import ddmd.lua.expression;

class Visitor
{
public:
    void visit(Node value)
    {
        assert(0);
    }

    mixin(generateVisitMethods!Statement);
    mixin(generateVisitMethods!Declaration);
    mixin(generateVisitMethods!Expression);
}

// Mixed in by Node classes
mixin template Acceptor()
{
    override void accept(Visitor visitor)
    {
        visitor.visit(this);
    }
}

private:
string generateVisitMethods(BaseClass)()
{
    import std.typecons : Identity;
    import std.traits : BaseClassesTuple;
    import std.string : format;

    alias Module = Identity!(__traits(parent, BaseClass));

    string output;
    foreach (memberName; __traits(allMembers, Module))
    {
        alias Member = Identity!(__traits(getMember, Module, memberName));

        static if (is(Member : BaseClass))
        {
            alias baseClassesTuple = BaseClassesTuple!Member;

            output ~=
`
    void visit(%s value)
    {
        import std.traits : getSymbolsByUDA;

        this.visit(cast(%s)value);
    }
`.format(Member.stringof, baseClassesTuple[0].stringof);
        }
    }

    return output;
}