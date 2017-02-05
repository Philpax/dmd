module ddmd.lua.astgen;

import ddmd.lua.generateluaastvisitor;
import ddmd.lua.printvisitor;

import d = ddmd.lua.dast;
import lua = ddmd.lua.ast;

import ddmd.root.outbuffer;

void codegen(OutBuffer* buf, d.Module* mod)
{
    auto generateLuaASTVisitor = new GenerateLuaASTVisitor();
    auto moduleNode = generateLuaASTVisitor.convert!(lua.Module)(*mod);
    
    auto printVisitor = new PrintVisitor(buf);
    moduleNode.accept(printVisitor);
}
