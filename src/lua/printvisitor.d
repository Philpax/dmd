module ddmd.lua.printvisitor;

import lua = ddmd.lua.ast;

import ddmd.root.outbuffer;

class PrintVisitor : lua.Visitor
{
private:
    OutBuffer* buf;
    uint indentLevel = 0;
    lua.Declaration[] scopes;
    lua.Module mod;

    void writeIndent()
    {
        enum IndentSize = 4;
        foreach (i; 0..indentLevel * IndentSize)
            this.buf.writeByte(' ');
    }

    void write(Args...)(string fmt, Args args)
    {
        import std.string : format;

        buf.writestring(fmt.format(args));
        this.written = true;
    }

    void writeLine(Args...)(string fmt, Args args)
    {
        this.writeIndent();
        this.write(fmt, args);
        buf.writeByte('\n');
    }

    void writeLine()
    {
        buf.writeByte('\n');
    }

    string getFullyScopedName(lua.NamedDeclaration decl)
    {
        auto prefix = "";
        auto parent = decl.parent;
        while (parent)
        {
            if (this.inScope(parent))
                break;

            // HACK: Ignore other modules due to difficulties with `public import`
            // Needs to be fixed at some point!
            if (cast(lua.Module)parent)
                break;

            if (auto nd = cast(lua.NamedDeclaration)parent)
                prefix = nd.name ~ "." ~ prefix;

            parent = parent.parent;
        }
        return prefix ~ decl.name;
    }

    uint pushScope(lua.Declaration newScope)
    {
        auto length = this.scopes.length;
        this.scopes ~= newScope;
        if (auto mod = cast(lua.Module)newScope)
        {
            foreach (_import; mod.imports)
            {
                if (_import != newScope)
                    this.pushScope(_import);
            }
        }
        return length;
    }

    void resetScope(uint len)
    {
        this.scopes = this.scopes[0..len];
    }

    bool inScope(lua.Declaration decl)
    {
        import std.algorithm : canFind;
        return this.scopes.canFind(decl);
    }

    final void acceptWithParens(lua.Expression e)
    {
        auto needsParens = !!cast(lua.Binary)e;
        if (needsParens)
            this.write("(");
        e.accept(this);
        if (needsParens)
            this.write(")");
    }

public:
    alias visit = lua.Visitor.visit;
    bool written = false;

    this(OutBuffer* buf)
    {
        this.buf = buf;
    }

    import std.traits : isCallable;
    final void indent(F)(F f)
        if (isCallable!F)
    {
        ++indentLevel;
        scope (exit) --indentLevel;

        f();
    }

    // Statements
    override void visit(lua.UnimplementedStmt u)
    {
        this.writeLine("--[[" ~ u.message ~ "]]");
    }

    override void visit(lua.Compound c)
    {
        indent({
            foreach (member; c.members)
                member.accept(this);
        });
    }

    override void visit(lua.Return r)
    {
        this.writeIndent();
        this.write("return");
        if (r.expr)
        {
            this.write(" ");
            r.expr.accept(this);
        }
        this.write("\n");
    }

    override void visit(lua.Scope s)
    {
        this.writeLine("do");
        s.stmt.accept(this); 
        this.writeLine("end");
    }

    override void visit(lua.ExpressionStmt e)
    {
        this.writeIndent();
        e.expr.accept(this);
        this.write("\n");
    }

    override void visit(lua.GroupStmt g)
    {
        foreach (member; g.members)
            member.accept(this);
    }

    override void visit(lua.While w)
    {
        this.writeIndent();
        this.write("while ");
        w.condition.accept(this);
        this.write(" do\n");
        w._body.accept(this);
        this.writeLine("end");    
    }

    void writeIfStatement(lua.If i)
    {
        this.write("if ");
        i.condition.accept(this);
        this.write(" then\n");
        i._body.accept(this);
        if (i._else)
        {
            this.writeIndent();
            this.write("else");

            if (auto elseIf = cast(lua.If)i._else)
            {
                this.writeIfStatement(elseIf);
                return;
            }
            else
            {
                this.write("\n");
                i._else.accept(this);
            }
        }
        this.writeLine("end");
    }

    override void visit(lua.If i)
    {
        this.writeIndent();
        this.writeIfStatement(i);
    }

    override void visit(lua.Break b)
    {
        this.writeLine("break");
    }

    // Declarations
    override void visit(lua.UnimplementedDecl u)
    {
        this.write("--[[" ~ u.message ~ "]]");
    }

    override void visit(lua.Function f)
    {
        import std.algorithm : map;
        import std.string : join;

        // If there's no body (i.e. this was a declaration),
        // don't emit this function
        if (f._body is null)
            return;

        auto len = this.pushScope(f);
        auto args = f.arguments.map!(a => a.name).join(", ");
        this.writeLine("function %s(%s)", f.name, args);
        f._body.accept(this);
        this.writeLine("end");
        this.resetScope(len);
    }

    override void visit(lua.FunctionLiteral f)
    {
        import std.algorithm : map;
        import std.string : join;

        auto args = f.arguments.map!(a => a.name).join(", ");

        auto len = this.pushScope(f);
        this.write("function(%s)\n", args);
        if (f._body)
            f._body.accept(this);
        this.writeIndent();
        this.write("end");
        this.resetScope(len);
    }

    override void visit(lua.Module m)
    {
        this.writeLine("-- %s", m.name);

        this.mod = m;
        auto len = this.pushScope(m);
        foreach (member; m.members)
        {
            this.written = false;
            member.accept(this);
            if (this.written)
                this.writeLine();
        }
        this.resetScope(len);
    }
    
    override void visit(lua.Variable v)
    {
        if (v.parent != this.mod)
            this.write("local ");
        this.write("%s", v.name);
        if (v.initializer)
        {
            this.write(" = ");
            v.initializer.accept(this);
        }
    }

    override void visit(lua.GroupDecl g)
    {
        foreach (member; g.members)
            member.accept(this);
    }

    override void visit(lua.Import i)
    {
        this.pushScope(i.mod);
    }

    override void visit(lua.StatementDecl s)
    {
        s.stmt.accept(this);
    }

    override void visit(lua.Struct s) {}

    // Expressions
    override void visit(lua.UnimplementedExpr u)
    {
        this.write("--[[" ~ u.message ~ "]]");
    }

    override void visit(lua.Integer i)
    {
        if (i.type == lua.Integer.Type.Integer)
            this.write("%s", i.value);
        else if (i.type == lua.Integer.Type.Boolean)
            this.write("%s", i.value ? "true" : "false");
    }

    override void visit(lua.Real r)
    {
        this.write("%s", r.value);
    }

    override void visit(lua.DeclarationExpr d)
    {
        d.declaration.accept(this);
    }

    override void visit(lua.Binary b)
    {
        this.acceptWithParens(b.operand1);
        this.write(" %s ", b.operation);
        this.acceptWithParens(b.operand2);
    }

    override void visit(lua.NamedDeclarationRef d)
    {
        this.write("%s", this.getFullyScopedName(d.declaration));
    }

    override void visit(lua.Call c)
    {
        if (c.call)
        {
            c.call.accept(this);
        }
        else
        {
            this.write("%s", this.getFullyScopedName(c.func));
        }
        this.write("(");
        bool first = true;
        foreach (argument; c.arguments)
        {
            if (!first)
                this.write(", ");

            argument.accept(this);
            first = false;
        }
        this.write(")");
    }

    override void visit(lua.String s)
    {
        this.write(`"`);
        this.write("%s", s.text);
        this.write(`"`);
    }

    override void visit(lua.DotVariable d)
    {
        d.operand.accept(this);
        this.write(".");
        this.write("%s", d.variable.name);
    }

    override void visit(lua.ColonFunction c)
    {
        c.operand.accept(this);
        this.write(":");
        this.write("%s", c.func.name);
    }

    override void visit(lua.StructLiteral s)
    {
        this.write("%s", this.getFullyScopedName(s._struct));
        this.write("(");
        bool first = true;
        foreach (field; s.fields)
        {
            if (!first)
                this.write(", ");

            field.accept(this);
            first = false;
        }
        this.write(")");
    }

    override void visit(lua.Nil n)
    {
        this.write("nil");
    }

    override void visit(lua.ArrayLength a)
    {
        this.write("#");
        a.expr.accept(this);
    }

    override void visit(lua.Index i)
    {
        i.expr.accept(this);
        this.write("[");
        i.index.accept(this);
        this.write("]");
    }

    override void visit(lua.ArrayLiteral a)
    {
        bool first = true;
        this.write("{");
        foreach (element; a.elements)
        {
            if (!first)
                this.write(", ");

            element.accept(this);
            first = false;
        }
        this.write("}");
    }

    override void visit(lua.Self s)
    {
        this.write("self");
    }

    override void visit(lua.TableLiteral t)
    {
        bool isValidIdentifier(string ident)
        {
            import std.uni : isNumber, isAlphaNum;
            import std.algorithm : startsWith, all, canFind;
            auto prohibited = [
                "and", "break", "do", "else", "elseif",
                "end", "false", "for", "function", "if",
                "in", "local", "nil", "not", "or",
                "repeat", "return", "then", "true", "until",
                "while"
            ];

            auto validStart = !ident.startsWith!isNumber();
            auto validChars = ident.all!(a => a.isAlphaNum() || a == '_');
            auto validIdent = !prohibited.canFind(ident);
            return validStart && validChars && validIdent;
        }

        if (t.pairs.length > 0)
        {
            this.write("{\n");
            indent({
                foreach (pair; t.pairs)
                {
                    this.writeIndent();
                    auto strLiteral = cast(lua.String)pair[0];
                    if (strLiteral && isValidIdentifier(strLiteral.text))
                    {
                        this.write(strLiteral.text);
                    }
                    else
                    {
                        this.write("[");
                        pair[0].accept(this);
                        this.write("]");
                    }
                    this.write(" = ");
                    pair[1].accept(this);
                    this.write(",\n");
                }
            });
            this.writeIndent();
            this.write("}");
        }
        else
        {
            this.write("{}");
        }
    }

    override void visit(lua.Unary u)
    {
        this.write(u.operator);
        this.acceptWithParens(u.operand);
    }

    override void visit(lua.Assert a)
    {
        this.write("assert(");
        a.operand.accept(this);
        if (a.message)
        {
            this.write(", ");
            a.message.accept(this);
        }
        this.write(")");
    }
}
