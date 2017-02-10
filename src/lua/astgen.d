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
    auto validityCheck = new ValidityCheckVisitor();
    mod.accept(validityCheck);

    auto generateLuaAST = new GenerateLuaASTVisitor();
    auto moduleNode = generateLuaAST.convert!(lua.Module)(*mod);
    
    auto flattenBlock = new FlattenBlockVisitor();
    moduleNode.accept(flattenBlock); 
    
    auto print = new PrintVisitor(buf);
    moduleNode.accept(print);
}
