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

class RecursiveVisitor : Visitor
{
private:
    int indent = 0;
    Node[] history;

    uint pushHistory(Node node)
    {
        auto length = this.history.length;
        this.history ~= node;
        return length;
    }

    void resetHistory(uint length)
    {
        this.history = this.history[0..length];
    }

    bool inHistory(Node node)
    {
        import std.algorithm : canFind;
        return this.history.canFind(node);
    }

public:
    alias visit = Visitor.visit;

    mixin(generateRecursiveVisitMethods!Statement);
    mixin(generateRecursiveVisitMethods!Declaration);
    mixin(generateRecursiveVisitMethods!Expression);
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
            auto baseClass = BaseClassesTuple!Member[0].stringof;
            output ~=
`
    void visit(%s value)
    {
        this.visit(cast(%s)value);
    }
`.format(Member.stringof, baseClass);
        }
    }

    return output;
}

public enum NoVisit;
string generateRecursiveVisitMethods(BaseClass)()
{
    import std.typecons : Identity;
    import std.traits : BaseClassesTuple, hasUDA;
    import std.string : format;
    import std.algorithm : map;
    import std.array : join;

    alias Module = Identity!(__traits(parent, BaseClass));

    string[] GenerateFieldAcceptors(Member)()
    {
        string[] statements;
        foreach (fieldName; __traits(allMembers, Member))
        {
            alias Field = Identity!(__traits(getMember, Member, fieldName));
            static if (!hasUDA!(Field, NoVisit))
            {
                static if (is(typeof(Field) : Node))
                {
                    statements ~= `if (value.` ~ fieldName ~ ` !is null)`;
                    statements ~= `    value.` ~ fieldName ~ `.accept(this);`;
                }
                else static if (is(typeof(Field) T : U[], U : Node))
                {
                    statements ~= `foreach (child; value.` ~ fieldName ~ `)`;
                    statements ~= `    if (child !is null)`;
                    statements ~= `        child.accept(this);`;
                }
            }
        }
        return statements;
    }

    string output;
    foreach (memberName; __traits(allMembers, Module))
    {
        alias Member = Identity!(__traits(getMember, Module, memberName));

        static if (is(Member : BaseClass))
        {
            auto statements = GenerateFieldAcceptors!Member();
            auto baseClass = BaseClassesTuple!Member[0].stringof;
            statements ~= `this.visit(cast(%s)value);`.format(baseClass);

            output ~=
`
    override void visit(%s value)
    {
        if (this.inHistory(value))
            return;

        auto length = this.pushHistory(value);
%s
        this.resetHistory(length);
    }
`.format(Member.stringof, statements.map!(a => "        " ~ a).join("\n"));
        }
    }

    return output;
}
