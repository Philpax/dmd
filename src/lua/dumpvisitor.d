module ddmd.lua.dumpvisitor;

import ddmd.lua.visitor;
import ddmd.lua.node;
import ddmd.lua.statement;
import ddmd.lua.declaration;
import ddmd.lua.expression;

class DumpVisitor : Visitor
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

    void writeIndent()
    {
        import std.stdio;
        foreach (_; 0..this.indent*2)
            write(' ');
    }

public:
    alias visit = Visitor.visit;

    override void visit(Node) {}

    mixin(generateDumpVisitMethods!Statement);
    mixin(generateDumpVisitMethods!Declaration);
    mixin(generateDumpVisitMethods!Expression);
}

string generateDumpVisitMethods(BaseClass)()
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
            static if (is(typeof(Field) : Node))
            {
                statements ~= `this.writeIndent();`;
                statements ~= `writeln("%s (", value.%s, ")");`.format(fieldName, fieldName);
                static if (!hasUDA!(Field, NoVisit))
                {
                    statements ~= `if (value.` ~ fieldName ~ ` !is null)`;
                    statements ~= `    value.` ~ fieldName ~ `.accept(this);`;
                }
            }
            else static if (is(typeof(Field) T : U[], U : Node))
            {
                statements ~= `writeln("%s[] (", value.%s, ")");`.format(fieldName, fieldName);
                static if (!hasUDA!(Field, NoVisit))
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
        import std.stdio : writeln;
        if (this.inHistory(value))
            return;

        auto length = this.pushHistory(value);
        ++this.indent;
%s
        --this.indent;
        this.resetHistory(length);
    }
`.format(Member.stringof, statements.map!(a => "        " ~ a).join("\n"));
        }
    }

    return output;
}
