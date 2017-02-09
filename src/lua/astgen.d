module ddmd.lua.astgen;

import ddmd.lua.generateluaastvisitor;
import ddmd.lua.flattenblockvisitor;
import ddmd.lua.printvisitor;

import d = ddmd.lua.dast;
import lua = ddmd.lua.ast;

import ddmd.root.outbuffer;

void codegen(OutBuffer* buf, d.Module* mod)
{
    auto generateLuaAST = new GenerateLuaASTVisitor();
    auto moduleNode = generateLuaAST.convert!(lua.Module)(*mod);
    
    auto flattenBlock = new FlattenBlockVisitor();
    moduleNode.accept(flattenBlock); 
    
    auto print = new PrintVisitor(buf);
    moduleNode.accept(print);
}
