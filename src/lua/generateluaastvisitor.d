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
    lua.Function rtDeepCopy;
    lua.Function setmetatable;

    lua.Variable init;
    lua.Variable mt;
    lua.Variable construct;

    void storeNode(Input)(Input dNode, lua.Node luaNode)
        if (__traits(compiles, dNode.accept(this)))
    {
        Value* value = dmd_aaGet(&this.converted, cast(void*)dNode);
        *value = cast(void*)luaNode;
    }

    Result getNode(Result, Input)(Input dNode)
    {
        Value* value = dmd_aaGet(&this.converted, cast(void*)dNode);
        if (*value)
            return cast(Result)(*value);
        else
            return null;
    }

public:
    alias visit = d.Visitor.visit;

    this()
    {
        this.rtDeepCopy = new lua.Function(null, "__rtDeepCopy", [], null);
        this.setmetatable = new lua.Function(null, "setmetatable", [], null);

        this.init = new lua.Variable(null, "init", null);
        this.mt = new lua.Variable(null, "__mt", null);
        this.construct = new lua.Variable(null, "construct", null);
    }

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
            auto prevNode = this.getNode!Result(dNode);
            if (prevNode)
                return prevNode;

            dNode.accept(this);
            this.storeNode(dNode, this.node);
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
        if (mod.members)
        {
            foreach (member; (*mod.members)[])
            {
                auto luaNode = this.convert!(lua.Declaration)(member);
                if (luaNode)
                    luaModule.members ~= luaNode;
            }
        }
        this.mod = oldModule;
        this.node = luaModule;
    }

    override void visit(d.AttribDeclaration attrib)
    {
        // Not sure why this works; lifted from toobj.d
        auto members = attrib.include(null, null);

        if (members)
        {
            auto node = new lua.GroupDecl(
                this.convert!(lua.Declaration)(attrib.parent), []);
            this.storeNode(attrib, node);

            lua.Declaration[] decls;
            foreach (decl; (*members)[])
            {
                // Only accept certain kinds of declarations for now
                bool skippableDecl =
                    !(decl.isVarDeclaration() || decl.isFuncDeclaration());

                if (skippableDecl)
                    continue;

                auto luaDecl = this.convert!(lua.Declaration)(decl);
                if (luaDecl)
                    decls ~= luaDecl;
            }
            node.members = decls;
            this.node = node;
        }
        else
        {
            this.node = null;
        }
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
        auto parent = this.convert!(lua.Declaration)(ti.parent);
        // HACK: Delete parent if it's a struct (as the contents of this
        // instantiation will not be in struct scope)
        if (cast(lua.Struct)parent)
            parent = null;
        auto luaGroup = new lua.GroupDecl(parent, []);
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
        // Generate the struct declaration in the Lua AST
        // (which is not actually represented in the final code)
        auto luaStruct = new lua.Struct(null, _struct.ident.toDString(), []);
        this.storeNode(_struct, luaStruct);

        auto parent = this.convert!(lua.Declaration)(_struct.parent);
        luaStruct.parent = this.mod;

        lua.Declaration[] members = [];
        if (_struct.members)
        {
            foreach (member; (*_struct.members)[])
            {
                auto luaNode = this.convert!(lua.Declaration)(member);
                if (luaNode)
                {
                    // Flatten immediately, so that we can get access
                    // to members when we generate our table representation
                    // TODO: Handle multiple levels of nesting
                    if (auto group = cast(lua.GroupDecl)luaNode)
                        members ~= group.members;
                    else
                        members ~= luaNode;
                }
            }
        }

        this.node = luaStruct;
        luaStruct.members = members;

        // If this is a Lua-linkage struct, don't emit the table
        // (as those have their own semantics)
        if (_struct.lua)
            return;

        auto structRef = new lua.NamedDeclarationRef(luaStruct);

        // Generate the table representation of the struct
        alias KV = lua.KeyValue;
        alias kV = lua.keyValue;
        auto s = (string value) => new lua.String(value);
        auto tL = (KV[] pairs) => new lua.TableLiteral(pairs);
        // Values within .init (i.e. struct default state)
        KV[] initValues;

        class ReparentVisitor : lua.RecursiveVisitor
        {
        public:
            lua.Declaration from;
            lua.Declaration to;

            this(lua.Declaration from, lua.Declaration to)
            {
                this.from = from;
                this.to = to;
            }

            alias visit = lua.RecursiveVisitor.visit;
            override void visit(lua.Node) {}
            override void visit(lua.Declaration d)
            {
                if (d.parent == from)
                    d.parent = to;
            }
        }

        // Build up the init/metatables
        // Values contained within __index (i.e. functions)
        KV[] indexValues; 
        lua.Variable[] constructorArgs;
        foreach (member; luaStruct.members)
        {
            if (auto variable = cast(lua.Variable)member)
            {
                auto varInit = variable.initializer;
                if (varInit is null)
                    varInit = new lua.Nil();
                initValues ~= kV(s(variable.name), varInit);
                constructorArgs ~= variable;
            }
            else if (auto func = cast(lua.Function)member)
            {
                auto funcLiteral = new lua.FunctionLiteral(
                    func.parent, func.arguments, func._body);

                scope reparentVisitor = new ReparentVisitor(func, funcLiteral);
                foreach (argument; funcLiteral.arguments)
                    argument.accept(reparentVisitor);

                if (funcLiteral._body)
                    funcLiteral._body.accept(reparentVisitor);

                indexValues ~= kV(
                    s(func.name), new lua.DeclarationExpr(funcLiteral));
            }
        }

        // Create the constructor function (__call)
        auto constructorBody = new lua.Compound([]);
        auto constructor = new lua.FunctionLiteral(
            luaStruct, constructorArgs, constructorBody);

        auto constructorSelf = new lua.Variable(constructor, "self",
            new lua.Call(this.rtDeepCopy, null, 
                [new lua.DotVariable(structRef, this.init)]
            )
        );
        auto constructorSelfRef = new lua.NamedDeclarationRef(constructorSelf);
        constructorBody.members ~= new lua.ExpressionStmt(
            new lua.DeclarationExpr(constructorSelf)
        );
        foreach (variable; constructorArgs)
        {
            constructorBody.members ~= new lua.ExpressionStmt(
                new lua.Assign(
                    new lua.DotVariable(constructorSelfRef, variable),
                    new lua.NamedDeclarationRef(variable)
                )
            );
        }
        constructorBody.members ~= new lua.Return(constructorSelfRef);

        // Metatable values
        KV[] mtValues = [kV(s("__index"), tL(indexValues))];

        // Build up the final table
        auto structTable = tL([
            kV(s("init"), tL(initValues)),
            kV(s("construct"), new lua.DeclarationExpr(constructor)),
            kV(s("__mt"), tL(mtValues))
        ]);

        // Build entries for the top scope
        lua.Declaration[] topScope;
        // Table variable
        topScope ~= new lua.Variable(
            this.mod, luaStruct.name, structTable);

        // Generate setmetatable calls for init/table
        // Set metatable for .init
        auto initMtStmt = new lua.ExpressionStmt(
            new lua.Call(this.setmetatable, null, [
                new lua.DotVariable(structRef, this.init),
                new lua.DotVariable(structRef, this.mt)
            ])
        );
        // Set metatable for the table
        auto tableMt = tL([
            kV(s("__call"), new lua.DotVariable(structRef, this.construct))
        ]);
        auto tableMtStmt = new lua.ExpressionStmt(
            new lua.Call(this.setmetatable, null, [structRef, tableMt])
        );

        // Add the metatable statements as a group to the top scope
        topScope ~= new lua.StatementDecl(this.mod,
            new lua.GroupStmt([initMtStmt, tableMtStmt])
        );

        this.mod.members ~= new lua.GroupDecl(this.mod, topScope);
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

    override void visit(d.SymbolDeclaration symbol)
    {
        this.node = this.convert!(lua.Struct)(symbol.dsym);
    }

    override void visit(d.ProtDeclaration prot)
    {
        if (prot.decl is null)
        {
            this.node = null;
            return;
        }

        // HACK:
        // Special-case prot declarations with a single var declaration
        // element, so that they don't interfere with AST generation.
        // This proved to be an issue with member variables in a templated
        // extern (D) struct.
        if (prot.decl.dim == 1)
        {
            auto decl = (*prot.decl)[0];
            if (auto var = decl.isVarDeclaration())
            {
                this.storeNode(prot, null);
                this.node = this.convert!(lua.Declaration)((*prot.decl)[0]);
                return;
            }
        }

        this.visit(cast(d.AttribDeclaration)prot);
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
        auto expr = this.convert!(lua.Expression)(stmt.exp);
        if (expr is null)
        {
            this.node = null;
            return;
        }
        // Rewrite a = (b = (c = d)) into separate statements
        if (auto assignExpr = cast(lua.Assign)expr)
        {
            lua.Assign[] assignExprs;
            while (assignExpr !is null)
            {
                assignExprs ~= assignExpr;
                auto newAssignExpr = cast(lua.Assign)assignExpr.operand2;
                if (newAssignExpr !is null)
                {
                    assignExpr.operand2 = newAssignExpr.operand1;
                }
                assignExpr = newAssignExpr;
            }

            import std.algorithm : map;
            import std.array : array;
            import std.range : retro;

            this.node = new lua.GroupStmt(
                assignExprs.map!(
                    a => cast(lua.Statement)(new lua.ExpressionStmt(a))
                ).retro.array()
            );
        }
        else
        {
            this.node = new lua.ExpressionStmt(expr);
        }
    }
    
    override void visit(d.ForStatement stmt)
    {
        // Keep an array of statements to go into the result group, and
        // inject the initialiser if one is available
        lua.Statement[] resultStmts = [];
        if (stmt._init)
            resultStmts ~= this.convert!(lua.Statement)(stmt._init);

        // Create a while body with the existing body; if there's an increment,
        // add it to the generated compound statement
        auto bodyRawStmt = this.convertConditionalBody(stmt._body);
        lua.Compound bodyStmt;
        if (auto compoundStmt = cast(lua.Compound)bodyRawStmt)
            bodyStmt = compoundStmt;
        else
            bodyStmt = new lua.Compound([bodyRawStmt]);

        if (stmt.increment)
        {
            bodyStmt.members ~= new lua.ExpressionStmt(
                this.convert!(lua.Expression)(stmt.increment)
            );
        }

        // Add our while to the final result
        resultStmts ~= new lua.While(
            this.convert!(lua.Expression)(stmt.condition), bodyStmt
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
        else if (stmt.isIfStatement() || stmt.isCompoundStatement())
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

    override void visit(d.BreakStatement _break)
    {
        this.node = new lua.Break();
    }

    override void visit(d.DoStatement _do)
    {
        this.node = new lua.RepeatUntil(
            this.convertConditionalBody(_do._body),
            new lua.Not(this.convert!(lua.Expression)(_do.condition))
        );
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

        auto luaFunction = new lua.Function(
            this.convert!(lua.Declaration)(func.parent), name, [], null);
        this.storeNode(func, luaFunction);

        // HACK: Only emit the self variable if we're dealing with a struct
        if (func.vthis && func.vthis.type.ty == d.Tstruct)
            luaFunction.arguments ~= new lua.Variable(luaFunction, "self", null);

        if (func.parameters)
        {
            foreach (parameter; (*func.parameters)[])
                luaFunction.arguments ~= this.convert!(lua.Variable)(parameter);
        }

        // HACK: Grab the definition of math.floor for later use
        if (func.parent && func.parent.ident && func.parent.ident.toDString() == "math" && name == "floor")
            this.mathFloor = luaFunction;

        luaFunction._body = this.convert!(lua.Statement)(func.fbody);
        luaFunction.isStatic = func.isStatic();
        this.node = luaFunction;
    }

    override void visit(d.FuncLiteralDeclaration func)
    {
        // HACK: Purposely do nothing, so that we don't emit a func literal
        // at top scope. Thought process is that we'll manually emit one
        // whereever we need to, anyway...
        this.node = null;
    }

    lua.FunctionLiteral generateFuncLiteral(d.FuncLiteralDeclaration func)
    {
        if (auto luaFunction = this.getNode!(lua.FunctionLiteral)(func))
            return luaFunction;

        auto luaFunction = new lua.FunctionLiteral(null, [], null);

        if (func.parameters)
        {
            foreach (parameter; (*func.parameters)[])
                luaFunction.arguments ~= this.convert!(lua.Variable)(parameter);
        }

        this.storeNode(func, luaFunction);

        luaFunction.parent = this.convert!(lua.Declaration)(func.parent);
        luaFunction._body = this.convert!(lua.Statement)(func.fbody);
        luaFunction.isStatic = func.isStatic();
        return luaFunction;
    }

    override void visit(d.VarDeclaration decl)
    {
        import ddmd.lua.constants : Keywords;
        import std.algorithm : canFind;

        // Don't emit manifest constants
        if (decl.storage_class & d.STCmanifest)
        {
            this.node = null;
            return;
        }

        // Adjust the name if it's a reserved keyword
        auto name = decl.ident.toDString();
        if (Keywords.canFind(name))
            name = "_" ~ name;

        auto node = new lua.Variable(null, name, null);
        this.storeNode(decl, node);
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
                    if (assignExpr.op == d.TOKblit &&
                        assignExpr.e2.type.ty == d.Tstruct)
                    {
                        init = new lua.DotVariable(init, this.init);
                        init = new lua.Call(this.rtDeepCopy, null, [init]);
                    }
                } 
                else
                {
                    init = this.convert!(lua.Expression)(exprInit.exp);
                }
            }
        }
        else
        {
            if (decl.type.ty == d.Tarray || decl.type.ty == d.Tsarray)
                init = new lua.ArrayLiteral([]);
        } 
        node.parent = this.convert!(lua.Declaration)(decl.parent);
        node.initializer = init;
        this.node = node;
    }

    override void visit(d.TemplateDeclaration decl)
    {
        // Do nothing: We don't emit template decls
        this.node = null;
    }

    override void visit(d.AliasDeclaration decl)
    {
        // Do nothing: We don't emit alias decls
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
        auto decl = this.convert!(lua.Declaration)(expr.declaration);
        if (decl !is null)
            this.node = new lua.DeclarationExpr(decl);
        else
            this.node = null;
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
    mixin BinOp!(d.AndAndExp, lua.And);

    override void visit(d.VarExp expr)
    {
        if (auto funcLiteral = expr.var.isFuncLiteralDeclaration())
        {
            this.node = new lua.DeclarationExpr(
                this.generateFuncLiteral(funcLiteral)
            );
            return;
        }

        this.node = new lua.NamedDeclarationRef(
            this.convert!(lua.NamedDeclaration)(expr.var));
    }

    override void visit(d.CallExp expr)
    {
        lua.Expression[] arguments;
        bool convertAccessExpr = true;

        // HACK: We attept to rewrite a.f(x) to f(a, x) if f is the result
        // of a template instance, and a is a struct. Not super great...
        if (expr.f && expr.f.parent)
        {
            if (auto ti = expr.f.parent.isTemplateInstance())
            {
                if (auto _struct = ti.parent.isStructDeclaration())
                {
                    if (auto dotVar = cast(d.DotVarExp)expr.e1)
                    {
                        arguments ~= this.convert!(lua.Expression)(dotVar.e1);
                        convertAccessExpr = false;
                    }
                }
            }
        }

        if (expr.arguments)
        {
            foreach (argument; (*expr.arguments)[])
                arguments ~= this.convert!(lua.Expression)(argument);
        }

        this.node = new lua.Call(
            this.convert!(lua.Function)(expr.f),
            convertAccessExpr ? this.convert!(lua.Expression)(expr.e1) : null,
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
        this.node = new lua.DeclarationExpr(this.generateFuncLiteral(expr.fd));
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
        {
            this.node = new lua.NamedDeclarationRef(
                this.convert!(lua.Function)(func));
        }
        else
        {
            this.visit(cast(d.Expression)expr);
        }
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

    override void visit(d.SliceExp expr)
    {
        auto e = expr.e1;
        // If this is an array, and it's an identity slice, pass it through
        // Otherwise, treat it as an unsupported node
        if (e.type && (e.type.ty == d.Tsarray || e.type.ty == d.Tarray) && 
            expr.upr is null && expr.lwr is null)
        {
            this.node = this.convert!(lua.Expression)(e);
        }
        else
        {
            this.visit(cast(d.Expression)expr);
        }
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

    override void visit(d.ThisExp expr)
    {
        this.node = new lua.Self();
    }

    override void visit(d.UnaExp expr)
    {
        import std.string : fromStringz;
        this.node = new lua.Unary(
            this.convert!(lua.Expression)(expr.e1),
            d.Token.toChars(expr.op).fromStringz().idup
        );
    }

    mixin template UnaOp(DClass, LuaClass)
    {
        override void visit(DClass expr)
        {
            this.node = new LuaClass(this.convert!(lua.Expression)(expr.e1));
        }
    }
    mixin UnaOp!(d.NotExp, lua.Not);

    override void visit(d.AssertExp expr)
    {
        this.node = new lua.Assert(
            this.convert!(lua.Expression)(expr.e1),
            this.convert!(lua.Expression)(expr.msg)
        );
    }

    override void visit(d.AddrExp expr)
    {
        this.node = this.convert!(lua.Expression)(expr.e1);
    }
}
