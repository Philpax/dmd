module ddmd.lua.expression;

import ddmd.lua.node;
import ddmd.lua.visitor;
import ddmd.lua.declaration;

class Expression : Node
{
    mixin Acceptor;
}

class UnimplementedExpr : Expression
{
    string message;

    this(string message)
    {
        this.message = message;
    }

    mixin Acceptor;
}

class Integer : Expression
{
    enum Type
    {
        Integer,
        Boolean
    }
    ulong value;
    Type type;

    this(ulong value, Type type)
    {
        this.value = value;
        this.type = type;
    }

    mixin Acceptor;
}

class Real : Expression
{
    real value;

    this(real value)
    {
        this.value = value;
    }

    mixin Acceptor;
}

class DeclarationExpr : Expression
{
    // Use Node as the declaration can be of any type
    // (according to the D AST)
    Node declaration;

    this(Node declaration)
    {
        this.declaration = declaration;
    }

    mixin Acceptor;
}

class Binary : Expression
{
    Expression operand1;
    Expression operand2;
    string operation;

    this(Expression operand1, Expression operand2, string operation)
    {
        this.operand1 = operand1;
        this.operand2 = operand2;
        this.operation = operation;
    }

    mixin Acceptor;
}

mixin template BinaryNode(string Name, string Operator)
{
    mixin(`class ` ~ Name ~ ` : Binary
    {
        this(Expression operand1, Expression operand2)
        {
            super(operand1, operand2, Operator);
        }

        mixin Acceptor;
    }`);
}

mixin BinaryNode!("Equal", "==");
mixin BinaryNode!("NotEqual", "~=");
mixin BinaryNode!("Concat", "..");
mixin BinaryNode!("Assign", "=");
mixin BinaryNode!("Add", "+");
mixin BinaryNode!("And", "and");

class VariableExpr : Expression
{
    Variable variable;

    this(Variable variable)
    {
        this.variable = variable;
    }

    mixin Acceptor;
}

class Call : Expression
{
    Function func;
    Expression call;
    Expression[] arguments;

    this(Function func, Expression call, Expression[] arguments)
    {
        this.func = func;
        this.call = call;
        this.arguments = arguments;
    }

    mixin Acceptor;
}

class String : Expression
{
    string text;

    this(string text)
    {
        this.text = text;
    }

    mixin Acceptor;
}

class DotVariable : Expression
{
    Expression operand;
    Variable variable;

    this(Expression operand, Variable variable)
    {
        this.operand = operand;
        this.variable = variable;
    }

    mixin Acceptor;
}

class ColonFunction : Expression
{
    Expression operand;
    Function func;

    this(Expression operand, Function func)
    {
        this.operand = operand;
        this.func = func;
    }

    mixin Acceptor;
}

class FunctionReference : Expression
{
    Function func;

    this(Function func)
    {
        this.func = func;
    }

    mixin Acceptor;
}

class StructLiteral : Expression
{
    Struct _struct;
    Expression[] fields;

    this(Struct _struct, Expression[] fields)
    {
        this._struct = _struct;
        this.fields = fields;
    }

    mixin Acceptor;
}

class Nil : Expression
{
    mixin Acceptor;
}

class ArrayLength : Expression
{
    Expression expr;

    this(Expression expr)
    {
        this.expr = expr;
    }

    mixin Acceptor;
}

class Index : Expression
{
    Expression expr;
    Expression index;

    this(Expression expr, Expression index)
    {
        this.expr = expr;
        this.index = index;
    }

    mixin Acceptor;
}

class ArrayLiteral : Expression
{
    Expression[] elements;

    this(Expression[] elements)
    {
        this.elements = elements;
    }

    mixin Acceptor;
}
