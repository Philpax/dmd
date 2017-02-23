module ddmd.lua.flattenblockvisitor;

import lua = ddmd.lua.ast;

class FlattenBlockVisitor : lua.RecursiveVisitor
{
public:
    alias visit = lua.RecursiveVisitor.visit;
    override void visit(lua.Node) {}

    void rewrite(T)(T stmt)
        if (is(typeof(stmt.members) == lua.Statement[]))
    {
        bool rebuild = false;
        foreach (member; stmt.members)
        {
            member.accept(this);
            if (cast(lua.Compound)member || cast(lua.GroupStmt)member)
                rebuild = true;
        }

        if (rebuild)
        {
            lua.Statement[] statements;
            foreach (member; stmt.members)
            {
                if (auto compound = cast(lua.Compound)member)
                    statements ~= compound.members;
                else if (auto group = cast(lua.GroupStmt)member)
                    statements ~= group.members;
                else
                    statements ~= member;
            }
            stmt.members = statements;
        }
    }


    override void visit(lua.Compound c)
    {
        this.rewrite(c);
    }

    override void visit(lua.GroupStmt g)
    {
        this.rewrite(g);
    }

    void rewrite(T)(T decl)
        if (is(typeof(decl.members) == lua.Declaration[]))
    {
        bool rebuild = false;
        foreach (member; decl.members)
        {
            member.accept(this);
            if (cast(lua.GroupDecl)member)
                rebuild = true;
        }

        if (rebuild)
        {
            lua.Declaration[] declarations;
            foreach (member; decl.members)
            {
                if (auto group = cast(lua.GroupDecl)member)
                    declarations ~= group.members;
                else
                    declarations ~= member;
            }
            decl.members = declarations;
        }
    }

    override void visit(lua.Module m)
    {
        this.rewrite(m);
    }

    override void visit(lua.GroupDecl g)
    {
        this.rewrite(g);
    }


}
