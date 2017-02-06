module ddmd.lua.generateluaastvisitor;

import core.stdc.stdio;

import d = ddmd.lua.dast;
import lua = ddmd.lua.ast;

import ddmd.root.outbuffer;
import ddmd.root.aav;

private string toDString(T)(T value)
    if (__traits(hasMember, T, "toChars"))
{
    import std.string : fromStringz;
    return value.toChars.fromStringz.idup;
}

extern(C++) class GenerateLuaASTVisitor : d.Visitor
{
private:
    lua.Module mod;
    lua.Node node;
    AA* converted;

    // Temporary fix
    lua.Function mathFloor;

    void storeNode(Input)(Input dNode, lua.Node luaNode)
        if (__traits(compiles, dNode.accept(this)))
    {
        Value* value = dmd_aaGet(&this.converted, cast(void*)dNode);
        if (*value is null)
            *value = cast(void*)luaNode;
    }

public:
    alias visit = d.Visitor.visit;

    Result convert(Result, Input)(Input dNode)
        if (__traits(compiles, dNode.accept(this)))
    {
        if (dNode is null)
        {
            this.node = null;
            return null;
        }
        else
        {
            Value* value = dmd_aaGet(&this.converted, cast(void*)dNode);
            if (*value)
                return cast(Result)(*value);

            dNode.accept(this);
            *value = cast(void*)this.node;
            return cast(Result)this.node;
        }
    }

    // Symbols
    override void visit(d.Dsymbol symbol)
    {
        import std.string : format, fromStringz;
        this.node = new lua.UnimplementedDecl(
            this.convert!(lua.Declaration)(symbol.parent),
            "sym %s (%s)".format(
                symbol.toDString(), symbol.kind().fromStringz()
            )
        );
    }

    override void visit(d.Import _import)
    {
        auto mod = this.convert!(lua.Module)(_import.mod);
        this.node = new lua.Import(this.convert!(lua.Declaration)(_import.parent), mod);
        this.mod.imports ~= mod;
    }

    override void visit(d.Module mod)
    {
        auto oldModule = this.mod;
        auto luaModule = new lua.Module(
            this.convert!(lua.Declaration)(mod.parent),
            mod.srcfile.toDString(), []);

        this.storeNode(mod, luaModule);

        this.mod = luaModule;
        lua.Declaration[] members = [];
        if (mod.members)
        {
            foreach (member; (*mod.members)[])
            {
                auto luaNode = this.convert!(lua.Declaration)(member);
                if (luaNode)
                    members ~= luaNode;
            }
        }
        this.mod = oldModule;

        this.node = luaModule;
        luaModule.members = members;
    }

    override void visit(d.Nspace nspace)
    {
        auto luaNamespace = new lua.Namespace(
            this.convert!(lua.Declaration)(nspace.parent),
            nspace.ident.toDString(), []);

        this.storeNode(nspace, luaNamespace);

        lua.Declaration[] members = [];
        if (nspace.members)
        {
            foreach (member; (*nspace.members)[])
            {
                auto luaNode = this.convert!(lua.Declaration)(member);
                if (luaNode)
                    members ~= luaNode;
            }
        }

        this.node = luaNamespace;
        luaNamespace.members = members;
    }

    override void visit(d.TemplateInstance ti)
    {
        auto luaGroup = new lua.GroupDecl(this.convert!(lua.Declaration)(ti.parent), []);
        this.storeNode(ti, luaGroup);

        lua.Declaration[] members = [];
        if (ti.members)
        {
            foreach (member; (*ti.members)[])
            {
                auto luaNode = this.convert!(lua.Declaration)(member);
                if (luaNode)
                    members ~= luaNode;
            }
        }

        this.node = luaGroup;
        luaGroup.members = members;
    }

    override void visit(d.StructDeclaration _struct)
    {
        auto luaStruct = new lua.Struct(
            this.convert!(lua.Declaration)(_struct.parent),
            _struct.ident.toDString(), []);

        this.storeNode(_struct, luaStruct);

        lua.Declaration[] members = [];
        if (_struct.members)
        {
            foreach (member; (*_struct.members)[])
            {
                auto luaNode = this.convert!(lua.Declaration)(member);
                if (luaNode)
                    members ~= luaNode;
            }
        }

        this.node = luaStruct;
        luaStruct.members = members;
    }

    override void visit(d.ClassDeclaration _class)
    {
        auto luaClass = new lua.Class(
            this.convert!(lua.Declaration)(_class.parent),
            _class.ident.toDString(), []);

        this.storeNode(_class, luaClass);

        lua.Declaration[] members = [];
        if (_class.members)
        {
            foreach (member; (*_class.members)[])
            {
                auto luaNode = this.convert!(lua.Declaration)(member);
                if (luaNode)
                    members ~= luaNode;
            }
        }

        this.node = luaClass;
        luaClass.members = members;
    }

    // Statements
    override void visit(d.Statement stmt)
    {
        this.node = new lua.UnimplementedStmt("stmt " ~ stmt.toDString());
    }

    override void visit(d.ReturnStatement stmt)
    {
        this.node = new lua.Return(this.convert!(lua.Expression)(stmt.exp));
    }

    override void visit(d.CompoundStatement stmt)
    {
        lua.Statement[] members = [];
        if (stmt.statements)
        {
            foreach (member; (*stmt.statements)[])
            {
                if (member.isCompoundStatement() && stmt.statements.dim == 1)
                {
                    member.accept(this);
                    return;
                }

                auto luaNode = this.convert!(lua.Statement)(member);
                if (luaNode)
                    members ~= luaNode;
            }
        }
        this.node = new lua.Compound(members);
    }

    override void visit(d.ScopeStatement stmt)
    { 
        this.node = new lua.Scope(this.convert!(lua.Statement)(stmt.statement)); 
    }

    override void visit(d.ExpStatement stmt)
    {
        this.node = new lua.ExpressionStmt(this.convert!(lua.Expression)(stmt.exp));
    }
    
    override void visit(d.ForStatement stmt)
    {
        // Keep an array of statements to go into the result group, and
        // inject the initialiser if one is available
        lua.Statement[] resultStmts = [];
        if (stmt._init)
            resultStmts ~= this.convert!(lua.Statement)(stmt._init);

        // Create a while body with the existing body; if there's an increment,
        // tack it on as a compound statement (so that the indentation will match)
        auto bodyStmts = [this.convert!(lua.Statement)(stmt._body)];
        if (stmt.increment)
        {
            bodyStmts ~= new lua.Compound([
                new lua.ExpressionStmt(this.convert!(lua.Expression)(stmt.increment))
            ]);
        }

        // Add our while to the final result
        resultStmts ~= new lua.While(
            this.convert!(lua.Expression)(stmt.condition),
            new lua.GroupStmt(bodyStmts)
        ); 

        this.node = new lua.GroupStmt(resultStmts);
    }

    override void visit(d.UnrolledLoopStatement stmt)
    {
        lua.Statement[] members = [];
        if (stmt.statements)
        {
            foreach (member; (*stmt.statements)[])
            {
                auto luaNode = this.convert!(lua.Statement)(member);
                if (luaNode)
                    members ~= luaNode;
            }
        }
        this.node = new lua.GroupStmt(members);
    }

    lua.Statement convertConditionalBody(d.Statement stmt)
    {
        if (!stmt)
            return null;

        if (auto scopeStmt = stmt.isScopeStatement())
        {
            if (scopeStmt.statement.isCompoundStatement())
                return this.convert!(lua.Statement)(scopeStmt.statement);
            else
                return new lua.Compound([this.convert!(lua.Statement)(scopeStmt.statement)]);
        }
        else if (auto ifStmt = stmt.isIfStatement())
        {
            return this.convert!(lua.Statement)(stmt);
        }
        else
        {
            return new lua.Compound([this.convert!(lua.Statement)(stmt)]);
        }
    }

    override void visit(d.IfStatement stmt)
    {
        this.node = new lua.If(
            this.convert!(lua.Expression)(stmt.condition),
            this.convertConditionalBody(stmt.ifbody),
            this.convertConditionalBody(stmt.elsebody)
        );
    }

    override void visit(d.SwitchStatement stmt)
    {
        if (stmt.cases is null || (*stmt.cases)[].length == 0)
        {
            this.node = null;
            return;
        }

        // Iterate over each case statement and generate if statements
        lua.If[] statements;
        foreach (caseStmt; (*stmt.cases))
        {
            statements ~= new lua.If(
                new lua.Equal(
                    this.convert!(lua.Expression)(stmt.condition),
                    this.convert!(lua.Expression)(caseStmt.exp)
                ),
                this.convertConditionalBody(caseStmt.statement),
                null
            ); 
        }

        // Link each if statement's else to the next if statement
        foreach (index; 0..(statements.length-1))
            statements[index]._else = statements[index+1];

        // Add default onto the last else
        if (stmt.sdefault)
        {
            statements[$-1]._else =
                this.convertConditionalBody(stmt.sdefault.statement);
        }

        this.node = statements[0];
    }

    // Declarations
    override void visit(d.Declaration decl)
    {
        import std.string : format, fromStringz;
        this.node = new lua.UnimplementedDecl(
            this.convert!(lua.Declaration)(decl.parent),
            "decl %s (%s)".format(
                decl.toDString(), decl.kind().fromStringz()
            )
        );
    }

    override void visit(d.FuncDeclaration func)
    {
        import ddmd.dmangle : mangleExact;
        import ddmd.globals : LINKlua;
        import std.string : fromStringz;

        // HACK: Work around opEquals in non-compiled module
        if (!func.type || !func.type.deco)
        {
            this.node = null;
            return;
        }

        string name;
        if (func.linkage == LINKlua)
            name = func.ident.toDString();
        else
            name = func.mangleExact.fromStringz.idup;

        lua.Variable[] args = [];
        if (func.parameters)
        {
            foreach (parameter; (*func.parameters)[])
                args ~= new lua.Variable(null, parameter.ident.toDString(), null);
        }

        auto luaFunction = new lua.Function(null, name, args, null);
        this.storeNode(func, luaFunction);

        // HACK: Grab the definition of math.floor for later use
        if (func.parent && func.parent.ident.toDString() == "math" && name == "floor")
            this.mathFloor = luaFunction;

        luaFunction.parent = this.convert!(lua.Declaration)(func.parent);
        luaFunction._body = this.convert!(lua.Statement)(func.fbody);
        luaFunction.isStatic = func.isStatic();
        this.node = luaFunction;
    }

    override void visit(d.FuncLiteralDeclaration func)
    {
        this.node = null;
    }

    override void visit(d.VarDeclaration decl)
    {
        lua.Expression init = null;
        if (decl._init)
        {
            if (auto exprInit = decl._init.isExpInitializer())
            {
                if (exprInit.exp.op == d.TOKconstruct || 
                    exprInit.exp.op == d.TOKassign ||
                    exprInit.exp.op == d.TOKblit)
                {
                    auto assignExpr = cast(d.AssignExp)exprInit.exp;
                    init = this.convert!(lua.Expression)(assignExpr.e2);
                } 
            }
        } 
        this.node = new lua.Variable(
            this.convert!(lua.Declaration)(decl.parent),
            decl.ident.toDString(), init);
    }

    override void visit(d.TemplateDeclaration decl)
    {
        // Do nothing: We don't emit template decls
        this.node = null;
    }

    // Expressions
    override void visit(d.Expression expr)
    {
        import std.string : format, fromStringz;
        if (!expr || !expr.type)
        {
            this.node = null;
            return;
        }

        this.node = new lua.UnimplementedExpr("expr %s (%s) of %s".format(
            expr.toDString(), d.Token.toChars(expr.op).fromStringz(), expr.type.toDString()
        ));
    }

    override void visit(d.IntegerExp expr)
    {
        if (!expr.type)
        {
            this.node = null;
            return;
        }

        auto type = expr.type.ty == d.Tbool ?
            lua.Integer.Type.Boolean : lua.Integer.Type.Integer;

        this.node = new lua.Integer(expr.getInteger(), type);
    }

    override void visit(d.RealExp expr)
    {
        this.node = new lua.Real(expr.value);
    } 

    override void visit(d.DeclarationExp expr)
    {
        this.node = new lua.DeclarationExpr(this.convert!(lua.Declaration)(expr.declaration));
    }

    override void visit(d.BinExp expr)
    {
        import std.string : fromStringz;
        this.node = new lua.Binary(
            this.convert!(lua.Expression)(expr.e1),
            this.convert!(lua.Expression)(expr.e2),
            d.Token.toChars(expr.op).fromStringz().idup
        );
    }

    override void visit(d.BinAssignExp expr)
    {
        import std.string : fromStringz;
        auto e1 = this.convert!(lua.Expression)(expr.e1);
        auto e2 = this.convert!(lua.Expression)(expr.e2);
        this.node = new lua.Assign(e1,
            new lua.Binary(e1, e2,
                d.Token.toChars(expr.op).fromStringz()[0..$-1].idup
            )
        );
    }

    mixin template BinOp(DClass, LuaClass)
    {
        override void visit(DClass expr)
        {
            this.node = new LuaClass(
                this.convert!(lua.Expression)(expr.e1),
                this.convert!(lua.Expression)(expr.e2)
            );
        }
    }

    mixin template BinOpOverload2(DClass, d.TOK Tok1, LuaClass1, d.TOK Tok2, LuaClass2)
    {
        override void visit(DClass expr)
        {
            if (expr.op == Tok1)
            {
                this.node = new LuaClass1(
                    this.convert!(lua.Expression)(expr.e1),
                    this.convert!(lua.Expression)(expr.e2)
                );
            }
            else if (expr.op == Tok2)
            {
                this.node = new LuaClass2(
                    this.convert!(lua.Expression)(expr.e1),
                    this.convert!(lua.Expression)(expr.e2)
                );
            }
            else
            {
                assert(0);
            }
        }
    }

    mixin BinOp!(d.AssignExp, lua.Assign);
    mixin BinOpOverload2!(d.EqualExp,
            d.TOKequal, lua.Equal, d.TOKnotequal, lua.NotEqual);
    mixin BinOpOverload2!(d.IdentityExp,
            d.TOKidentity, lua.Equal, d.TOKnotidentity, lua.NotEqual);
    mixin BinOp!(d.CatExp, lua.Concat);

    override void visit(d.VarExp expr)
    {
        this.node = new lua.VariableExpr(this.convert!(lua.Variable)(expr.var));
    }

    override void visit(d.CallExp expr)
    {
        lua.Expression[] arguments;
        if (expr.arguments)
        {
            foreach (argument; (*expr.arguments)[])
                arguments ~= this.convert!(lua.Expression)(argument);
        }

        this.node = new lua.Call(
            this.convert!(lua.Function)(expr.f),
            this.convert!(lua.Expression)(expr.e1),
            arguments
        );
    }

    override void visit(d.StringExp expr)
    {
        this.node = new lua.String(expr.toStringz.idup);
    }

    override void visit(d.CastExp expr)
    {
        if (!expr.e1 || !expr.e1.type)
        {
            this.node = null;
            return;
        }

        this.node = this.convert!(lua.Expression)(expr.e1);
        if (expr.to.isintegral() && expr.e1.type.isfloating() && this.mathFloor)
            this.node = new lua.Call(this.mathFloor, null, [cast(lua.Expression)this.node]);
    }

    override void visit(d.FuncExp expr)
    {
        auto func = expr.fd;
        lua.Variable[] args = [];
        if (func.parameters)
        {
            foreach (parameter; (*func.parameters)[])
                args ~= new lua.Variable(null, parameter.ident.toDString(), null);
        }

        auto luaFunction = new lua.FunctionLiteral(
            null, args, this.convert!(lua.Statement)(func.fbody));

        this.node = new lua.DeclarationExpr(luaFunction);
    }

    override void visit(d.DotVarExp expr)
    {
        auto operand = this.convert!(lua.Expression)(expr.e1);
        if (auto var = expr.var.isVarDeclaration())
        {
            this.node = new lua.DotVariable(
                operand, this.convert!(lua.Variable)(var));
        }
        else if (auto func = expr.var.isFuncDeclaration())
        {
            this.node = new lua.ColonFunction(
                operand, this.convert!(lua.Function)(func));
        }
        else
        {
            this.visit(cast(d.Expression)expr);
        }
    }

    override void visit(d.SymbolExp expr)
    {
        if (auto func = expr.var.isFuncDeclaration())
            this.node = new lua.FunctionReference(this.convert!(lua.Function)(func));
        else
            this.visit(cast(d.Expression)expr);
    }

    override void visit(d.StructLiteralExp expr)
    {
        lua.Expression[] fields;
        if (expr.elements)
        {
            foreach (field; (*expr.elements)[])
                fields ~= this.convert!(lua.Expression)(field);
        }

        this.node = new lua.StructLiteral(this.convert!(lua.Struct)(expr.sd), fields);
    }

    override void visit(d.PtrExp expr)
    {
        auto e = expr.e1;
        if (cast(d.TypeDelegate)e.type || cast(d.TypeFunction)e.type)
            this.convert!(lua.Expression)(e);
        else
            this.visit(cast(d.Expression)expr);
    }

    override void visit(d.NullExp expr)
    {
        this.node = new lua.Nil();
    }

    override void visit(d.ArrayLengthExp expr)
    {
        this.node = new lua.ArrayLength(
            this.convert!(lua.Expression)(expr.e1)
        );
    }

    override void visit(d.IndexExp expr)
    {
        // Add 1 to the index because Lua has 1-based indexing
        this.node = new lua.Index(
            this.convert!(lua.Expression)(expr.e1),
            new lua.Add(
                this.convert!(lua.Expression)(expr.e2),
                new lua.Integer(1, lua.Integer.Type.Integer)
            )
        );
    }

    override void visit(d.ArrayLiteralExp expr)
    {
        lua.Expression[] elements;
        if (expr.elements)
        {
            foreach (elem; (*expr.elements)[])
                elements ~= this.convert!(lua.Expression)(elem);
        }
        this.node = new lua.ArrayLiteral(elements);
    }
}
