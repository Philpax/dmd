module ddmd.lua.printgen;

import core.stdc.stdio;
import core.stdc.string;

import d = ddmd.lua.dast;

import ddmd.root.outbuffer;
import ddmd.root.array;

class CodeGenerator
{
    OutBuffer* buf;
    d.Module* mod;

    this(OutBuffer* buf, d.Module* mod)
    {
        this.buf = buf;
        this.mod = mod;
    }

    alias CString = const(char)*;

    extern(C++) final class ToLuaVisitor : d.Visitor
    {
        alias visit = d.Visitor.visit;
        Array!(d.Module) staticImports;
    public:
        int indentLevel = 0;

        extern (D) this()
        {
        }

        void writeIndent()
        {
            int tabSize = 4;

            foreach (indent; 0 .. indentLevel*tabSize)
                buf.writeByte(' ');
        }

        enum Scope = q{
            ++indentLevel;
            scope (exit) --indentLevel;
        };

        void writeModule(d.Module mod)
        {
            import std.algorithm: canFind;
            if (this.staticImports[].canFind(mod))
            {
                buf.printf("%s.", mod.ident.toChars());
            }
        }

        // ---------------- Symbols
        override void visit(d.Dsymbol sym)
        {
            buf.printf("--[[UNIMPL-SYM %s: %s]]\n", sym.kind(), sym.ident.toChars());
        }

        override void visit(d.ScopeDsymbol sym)
        {
            if (!sym.members)
                return;

            foreach (i; 0..sym.members.dim)
            {
                (*sym.members)[i].accept(this);
            }
        }

        override void visit(d.Import sym)
        {
            buf.printf("require \"%s\"\n", sym.id.toChars());
            if (sym.isstatic)
            {
                staticImports.push(sym.mod);
            }
        }

        // ---------------- Statements
        override void visit(d.Statement stmt)
        {
            writeIndent();
            buf.printf("--[[UNIMPL-STMT %s]]\n", stmt.toChars());
        }

        override void visit(d.CompoundStatement stmt)
        {
            if (!stmt.statements)
                return;

            if (stmt.statements.dim == 1 && (*stmt.statements)[0].isCompoundStatement())
            {
                (*stmt.statements)[0].accept(this);
                return;
            }

            mixin(Scope);
            foreach (i; 0..stmt.statements.dim)
            {
                auto childStmt = (*stmt.statements)[i];
                childStmt.accept(this);
            }
        }

        override void visit(d.ExpStatement stmt)
        {
            writeIndent();
            scope (exit) buf.printf("\n");

            stmt.exp.accept(this);
        }

        override void visit(d.ReturnStatement stmt)
        {
            writeIndent();
            scope (exit) buf.printf("\n");

            buf.printf("return");
            if (stmt.exp)
            {
                buf.printf(" ");
                stmt.exp.accept(this);
            }
        }

        override void visit(d.UnrolledLoopStatement stmt)
        {
            if (!stmt.statements)
                return;

            foreach (i; 0..stmt.statements.dim)
            {
                auto childStmt = (*stmt.statements)[i];
                childStmt.accept(this);
            }
        }

        override void visit(d.ScopeStatement stmt)
        {
            if (!stmt.statement)
                return;

            writeIndent();
            buf.printf("do\n");
            {
                stmt.statement.accept(this);
            }
            writeIndent();
            buf.printf("end\n");
        }

        override void visit(d.ForStatement stmt)
        {
            writeIndent();
            buf.printf("do\n");
            {
                mixin(Scope);
                if (stmt._init)
                    stmt._init.accept(this);

                writeIndent();
                buf.printf("while ");
                stmt.condition.accept(this);
                buf.printf(" do\n");

                stmt._body.accept(this);
                {
                    mixin(Scope);
                    writeIndent();
                    stmt.increment.accept(this);
                    buf.printf("\n");
                }

                writeIndent();
                buf.printf("end\n");
            }
            writeIndent();
            buf.printf("end\n");
        }

        void writeBodyStatement(d.Statement stmt)
        {
            if (auto scopeStmt = stmt.isScopeStatement())
            {
                if (auto compoundStmt = scopeStmt.statement.isCompoundStatement())
                {
                    scopeStmt.statement.accept(this);
                }
                else
                {
                    mixin(Scope);
                    scopeStmt.statement.accept(this);
                }
            }
            else
            {
                mixin(Scope);
                stmt.accept(this);
            }
        }

        void writeIfStatement(d.IfStatement stmt)
        {
            buf.printf("if ");
            stmt.condition.accept(this);
            buf.printf(" then\n");

            writeBodyStatement(stmt.ifbody);

            if (stmt.elsebody)
            {
                writeIndent();
                buf.printf("else");

                if (auto elseIfStmt = stmt.elsebody.isIfStatement())
                {
                    writeIfStatement(elseIfStmt);
                }
                else
                {
                    buf.printf("\n");

                    writeBodyStatement(stmt.elsebody);

                    writeIndent();
                    buf.printf("end\n");
                }
            }
            else
            {
                writeIndent();
                buf.printf("end\n");
            }
        }

        override void visit(d.IfStatement stmt)
        {
            writeIndent();
            writeIfStatement(stmt);
        }

        // ---------------- Expressions
        override void visit(d.Expression expr)
        {
            buf.printf("--[[UNIMPL-EXPR %s: %s (%s)]]",
                d.Token.toChars(expr.op), expr.toChars(), expr.type ? expr.type.toChars() : "");
        }

        override void visit(d.IdentifierExp expr)
        {
            buf.writestring(expr.ident.toChars());
        }

        override void visit(d.VarExp expr)
        {
            writeModule(expr.var.getModule());
            buf.writestring(expr.var.ident.toChars());
        }

        override void visit(d.DeclarationExp expr)
        {
            expr.declaration.accept(this);
        }

        override void visit(d.BinExp expr)
        {
            expr.e1.accept(this);
            buf.writeByte(' ');
            buf.printf(d.Token.toChars(expr.op));
            buf.writeByte(' ');
            expr.e2.accept(this);
        }

        override void visit(d.AddAssignExp expr)
        {
            expr.e1.accept(this);
            buf.printf(" = ");
            expr.e1.accept(this);
            buf.printf(" + ");
            expr.e2.accept(this);
        }

        override void visit(d.AssignExp expr)
        {
            expr.e1.accept(this);
            buf.printf(" = ");
            expr.e2.accept(this);
        }

        override void visit(d.CallExp expr)
        {
            import ddmd.dmangle : mangleExact;

            writeModule(expr.f._scope._module);
            bool injectSelf = false;
            if (expr.f.isMember())
            {
                if (expr.f.isStatic())
                {
                    buf.printf("%s.", expr.f.parent.ident.toChars());
                }
                expr.e1.accept(this);
                buf.printf("(");
            }
            else
            {
                buf.printf("%s(", expr.f.mangleExact());
                injectSelf = true;
            }
            if (expr.arguments)
            {
                bool first = true;
                if (expr.e1.op == d.TOK.TOKdotvar && injectSelf)
                {
                    auto dotExpr = cast(d.DotVarExp)expr.e1;
                    dotExpr.e1.accept(this);
                    first = false;
                }
                foreach (arg; (*expr.arguments)[])
                {
                    if (!first)
                        buf.printf(", ");

                    arg.accept(this);
                    first = false;
                }
            }
            buf.printf(")");
        }

        override void visit(d.IntegerExp expr)
        {
            buf.printf("%lld", expr.getInteger());
        }

        override void visit(d.ArrayLengthExp expr)
        {
            buf.printf("#");
            expr.e1.accept(this);
        }

        override void visit(d.SliceExp expr)
        {
            expr.e1.accept(this);
        }

        override void visit(d.IndexExp expr)
        {
            expr.e1.accept(this);
            buf.printf("[(");
            expr.e2.accept(this);
            buf.printf(")+1]");
        }

        override void visit(d.CastExp expr)
        {
            expr.e1.accept(this);
        }

        override void visit(d.RealExp expr)
        {
            import std.math : floor;

            if (expr.value == expr.value.floor())
                buf.printf("%lld", expr.toInteger());
            else
                buf.writestring(expr.toChars());
        }

        override void visit(d.StringExp expr)
        {
            buf.writestring(expr.toChars());
        }

        override void visit(d.DotVarExp expr)
        {
            expr.e1.accept(this);
            if (expr.var.isFuncDeclaration())
                buf.printf(":");
            else
                buf.printf(".");
            buf.writestring(expr.var.ident.toChars());
        }

        void writeFuncLiteral(d.FuncLiteralDeclaration decl)
        {
            buf.printf("function(");
            if (decl.parameters)
            {
                for (size_t i = 0; i < decl.parameters.dim; i++)
                {
                    d.VarDeclaration v = (*decl.parameters)[i];

                    if (i > 0)
                        buf.printf(", ");

                    buf.writestring(v.ident.toChars());
                }
            }
            buf.printf(")\n");

            if (decl.fbody)
                decl.fbody.accept(this);

            writeIndent();
            buf.printf("end");
        }

        override void visit(d.FuncExp expr)
        {
            writeFuncLiteral(expr.fd);
        }

        override void visit(d.StructLiteralExp expr)
        {
            buf.printf("%s(", expr.sd.ident.toChars());

            if (expr.elements)
            {
                for (size_t i = 0; i < expr.elements.dim; i++)
                {
                    if (i > 0)
                        buf.printf(", ");

                    auto exp = (*expr.elements)[i];
                    exp.accept(this);
                }
            }

            buf.printf(")");
        }

        override void visit(d.CommaExp expr)
        {
            if (expr.e1.op == d.TOK.TOKdeclaration && expr.e2.op == d.TOK.TOKcomma)
            {
                buf.printf("(function()\n");

                {
                    mixin(Scope);
                    writeIndent();
                    expr.e1.accept(this);
                    buf.printf("\n");

                    writeIndent();
                    expr.e2.accept(this);
                    buf.printf("\n");
                }

                writeIndent();
                buf.printf("end)()");
            }
            else
            {
                expr.e1.accept(this);
                buf.printf("\n");

                writeIndent();
                if (expr.e2.op == d.TOK.TOKvar)
                    buf.printf("return ");
                expr.e2.accept(this);
            }
        }

        override void visit(d.SymOffExp expr)
        {
            import ddmd.dmangle : mangleExact;

            auto fnDecl = expr.var.isFuncDeclaration();

            if (!fnDecl)
                return expr.error("can't compile %s: only functions supported", expr.toChars());

            buf.writestring(fnDecl.mangleExact());
        }

        override void visit(d.NullExp expr)
        {
            buf.writestring("nil");
        }

        override void visit(d.ThisExp expr)
        {
            buf.writestring("self");
        }

        override void visit(d.AssertExp expr)
        {
            buf.writestring("assert(");
            expr.e1.accept(this);
            buf.writestring(", ");
            expr.msg.accept(this);
            buf.writestring(")");
        }

        override void visit(d.AddrExp expr)
        {
            expr.e1.accept(this);
        }

        // ---------------- Declarations
        override void visit(d.Declaration decl)
        {
            buf.printf("--[[UNIMPL-DECL %s: %s]]\n", decl.kind(), decl.ident.toChars());
        }

        override void visit(d.FuncDeclaration decl)
        {
            import ddmd.dmangle : mangleExact;

            if (decl.isFuncLiteralDeclaration())
                return;

            writeIndent();
            buf.printf("function %s(", decl.mangleExact());
            if (decl.parameters)
            {
                bool first = true;
                if (decl.vthis)
                {
                    buf.writestring("self");
                    first = false;
                }
                foreach (varDecl; (*decl.parameters)[])
                {
                    if (!first)
                        buf.printf(", ");

                    buf.writestring(varDecl.ident.toChars());
                    first = false;
                }
            }
            buf.printf(")\n");

            if (decl.fbody)
                decl.fbody.accept(this);

            buf.printf("end\n");
        }

        override void visit(d.VarDeclaration decl)
        {
            buf.printf("local ");
            if (decl._init)
            {
                if (auto expInit = decl._init.isExpInitializer())
                {
                    if (expInit.exp.op == d.TOK.TOKblit)
                    {
                        auto blitExp = cast(d.BlitExp)expInit.exp;
                        auto varExp = cast(d.VarExp)blitExp.e1;

                        buf.printf("%s = Copy(%s.init)", decl.ident.toChars(), varExp.var.type.toChars());
                        return;
                    }
                    else if (expInit.exp.op == d.TOK.TOKassign || expInit.exp.op == d.TOK.TOKconstruct)
                    {
                        auto assignExpr = cast(d.AssignExp)expInit.exp;

                        if (assignExpr.e2.type.ty == d.ENUMTY.Tstruct)
                        {
                            assignExpr.e1.accept(this);
                            buf.printf(" = Copy(");
                            assignExpr.e2.accept(this);
                            buf.printf(")");
                        }
                        else
                        {
                            assignExpr.accept(this);
                        }
                        return;
                    }
                    else
                    {
                        buf.printf("%s = ", decl.ident.toChars());
                    }
                }
                decl._init.accept(this);
            }
            else
            {
                buf.writestring(decl.ident.toChars());
            }
        }

        override void visit(d.TemplateDeclaration decl)
        {
            // Do nothing: We don't emit template decls in Lua
        }

        override void visit(d.StructDeclaration decl)
        {
            auto name = decl.ident.toChars();
            buf.printf("%s = {\n", name);
            {
                mixin(Scope);

                // Write init
                writeIndent();
                buf.writestring("init = {\n");
                {
                    mixin(Scope);

                    foreach (field; decl.fields[])
                    {
                        writeIndent();
                        buf.printf("%s = ", field.ident.toChars());
                        field._init.accept(this);
                        buf.writestring(",\n");
                    }
                }
                writeIndent();
                buf.writestring("},\n");

                // Write metatable
                writeIndent();
                buf.writestring("__mt = {\n");
                {
                    mixin(Scope);

                    writeIndent();
                    buf.writestring("__index = {\n");

                    {
                        mixin(Scope);
                        writeIndent();

                        buf.writestring("__ctor = function(self");
                        foreach (field; decl.fields[])
                        {
                            buf.writestring(", ");
                            buf.writestring(field.ident.toChars());
                        }
                        buf.writestring(")\n");

                        {
                            mixin(Scope);
                            foreach (field; decl.fields[])
                            {
                                auto fieldName = field.ident.toChars();
                                writeIndent();
                                buf.printf("self.%s = %s\n", fieldName, fieldName);
                            }
                            writeIndent();
                            buf.printf("return self\n");
                        }

                        writeIndent();
                        buf.writestring("end\n");
                    }

                    writeIndent();
                    buf.writestring("}\n");
                }
                writeIndent();
                buf.writestring("},\n");
            }
            writeIndent();
            buf.writestring("}\n");

            writeIndent();
            buf.printf("setmetatable(%s.init, %s.__mt)\n", name, name);

            writeIndent();
            buf.printf("setmetatable(%s, {\n", name);
            {
                mixin(Scope);
                writeIndent();

                bool first = true;
                buf.writestring("__call = function(");
                foreach (field; decl.fields[])
                {
                    if (!first)
                        buf.writestring(", ");

                    buf.writestring(field.ident.toChars());
                    first = false;
                }
                buf.writestring(")\n");

                {
                    mixin(Scope);
                    writeIndent();
                    buf.printf("local ret = Copy(%s.init)\n", name);
                    foreach (field; decl.fields[])
                    {
                        auto fieldName = field.ident.toChars();
                        writeIndent();
                        buf.printf("ret.%s = %s\n", fieldName, fieldName);
                    }
                    writeIndent();
                    buf.printf("return ret\n");
                }

                writeIndent();
                buf.writestring("end\n");
            }
            writeIndent();
            buf.writestring("})");
        }

        // ---------------- Initializers
        override void visit(d.Initializer init)
        {
            buf.printf("--[[UNIMPL-INIT %s]]\n", init.toChars());
        }

        override void visit(d.ExpInitializer init)
        {
            init.exp.accept(this);
        }
    }

    void generate()
    {
        import ddmd.globals;

        this.buf.printf("-- %s\n", mod.srcfile.toChars());

        scope visitor = new ToLuaVisitor();

        foreach (member; (*mod.members)[])
        {
            if (global.params.verbose)
                printf("generate %s %s\n", member.kind(), member.toChars());

            member.accept(visitor);

            if (!member.isTemplateDeclaration())
                buf.printf("\n");
        }
    }
}

void codegen(OutBuffer* buf, d.Module* mod)
{
    scope codeGenerator = new CodeGenerator(buf, mod);
    codeGenerator.generate();
}
