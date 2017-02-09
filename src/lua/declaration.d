module ddmd.lua.declaration;

import ddmd.lua.node;
import ddmd.lua.statement;
import ddmd.lua.visitor;
import ddmd.lua.expression;

class Declaration : Node
{
    @NoVisit Declaration parent;

    this(Declaration parent)
    {
        this.parent = parent;
    }

    mixin Acceptor;
}

class UnimplementedDecl : Declaration
{
    string message;

    this(Declaration parent, string message)
    {
        super(parent);
        this.message = message;
    }

    mixin Acceptor;
}

class NamedDeclaration : Declaration
{
    string name;

    this(Declaration parent, string name)
    {
        super(parent);
        this.name = name;
    }

    mixin Acceptor;
}

class Module : NamedDeclaration
{
    Declaration[] members;
    @NoVisit Module[] imports;

    this(Declaration parent, string name, Declaration[] members)
    {
        super(parent, name);
        this.members = members;
    }

    mixin Acceptor;
}

class GroupDecl : Declaration
{
    Declaration[] members;

    this(Declaration parent, Declaration[] members)
    {
        super(parent);
        this.members = members;
    }

    mixin Acceptor;
}

class Namespace : NamedDeclaration
{
    Declaration[] members;

    this(Declaration parent, string name, Declaration[] members)
    {
        super(parent, name);
        this.members = members;
    }

    mixin Acceptor;
}

class Variable : NamedDeclaration
{
    Expression initializer;

    this(Declaration parent, string name, Expression initializer)
    {
        super(parent, name);
        this.initializer = initializer;
    }

    mixin Acceptor;
}

class Function : NamedDeclaration
{
    Variable[] arguments;
    Statement _body;
    bool isStatic;

    this(Declaration parent, string name, Variable[] arguments, Statement _body)
    {
        super(parent, name);
        this.arguments = arguments;
        this._body = _body;

        foreach (argument; this.arguments)
            argument.parent = this;
    }

    mixin Acceptor;
}

class FunctionLiteral : Function
{
    this(Declaration parent, Variable[] arguments, Statement _body)
    {
        super(parent, "function literal", arguments, _body);
    }

    mixin Acceptor;
}

class Aggregrate : NamedDeclaration
{
    Declaration[] members;

    this(Declaration parent, string name, Declaration[] members)
    {
        super(parent, name);
        this.members = members;
    }

    mixin Acceptor;
}

class Struct : Aggregrate
{
    this(Declaration parent, string name, Declaration[] members)
    {
        super(parent, name, members);
    }

    mixin Acceptor;
}

class Class : Aggregrate
{
    this(Declaration parent, string name, Declaration[] members)
    {
        super(parent, name, members);
    }

    mixin Acceptor;
}

class Import : Declaration
{
    @NoVisit Module mod;

    this(Declaration parent, Module mod)
    {
        super(parent);
        this.mod = mod;
    }

    mixin Acceptor;
}
