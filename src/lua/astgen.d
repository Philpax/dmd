module ddmd.lua.astgen;

import ddmd.lua.generateluaastvisitor;
import ddmd.lua.flattenblockvisitor;
import ddmd.lua.printvisitor;

import d = ddmd.lua.dast;
import lua = ddmd.lua.ast;

import ddmd.root.outbuffer;

extern (C++) class ValidityCheckVisitor : d.Visitor
{
public:
    alias visit = d.Visitor.visit;

    override void visit(d.Dsymbol) {}
    override void visit(d.FuncDeclaration f)
    {
        if (f.isMain() && !f.isSafe())
            f.error("must be @safe in Lua mode");
    }

    override void visit(d.Module m)
    {
        if (m.members)
        {
            foreach (member; (*m.members)[])
                member.accept(this);
        }
    }
}

void codegen(OutBuffer* buf, d.Module* mod)
{
    import core.stdc.stdio : printf;
    import ddmd.globals;

    if (global.params.verbose)
        printf("lua-cg\tvalidity check\n");
    auto validityCheck = new ValidityCheckVisitor();
    mod.accept(validityCheck);

    if (global.params.verbose)
        printf("lua-cg\tgenerate Lua AST\n");
    auto generateLuaAST = new GenerateLuaASTVisitor();
    auto moduleNode = generateLuaAST.convert!(lua.Module)(*mod);

    if (global.params.verbose)
        printf("lua-cg\tflatten Lua AST\n");
    auto flattenBlock = new FlattenBlockVisitor();
    moduleNode.accept(flattenBlock);

    if (global.params.verbose)
        printf("lua-cg\tprint Lua AST\n");
    auto print = new PrintVisitor(buf);
    moduleNode.accept(print);
}
