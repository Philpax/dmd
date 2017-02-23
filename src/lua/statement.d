module ddmd.lua.statement;

import ddmd.lua.node;
import ddmd.lua.visitor;
import ddmd.lua.expression;

class Statement : Node
{
    mixin Acceptor;
}

class UnimplementedStmt : Statement
{
    string message;

    this(string message)
    {
        this.message = message;
    }

    mixin Acceptor;
}

class Compound : Statement
{
    Statement[] members;

    this(Statement[] members)
    {
        this.members = members;
    }

    mixin Acceptor;
}

class Return : Statement
{
    Expression expr;

    this(Expression expr)
    {
        this.expr = expr;
    }

    mixin Acceptor;
}

class Scope : Statement
{
    Statement stmt;

    this(Statement stmt)
    {
        this.stmt = stmt;
    }

    mixin Acceptor;
}

class ExpressionStmt : Statement
{
    Expression expr;

    this(Expression expr)
    {
        this.expr = expr;
    }

    mixin Acceptor;
}

// Group statements allow for the grouping of multiple statements without
// creating a new indentation level or scope
class GroupStmt : Statement
{
    Statement[] members;

    this(Statement[] members)
    {
        this.members = members;
    }

    mixin Acceptor;
}

class While : Statement
{
    Expression condition;
    Statement _body;

    this(Expression condition, Statement _body)
    {
        this.condition = condition;
        this._body = _body;
    }

    mixin Acceptor;
}

class If : Statement
{
    Expression condition;
    Statement _body;
    Statement _else;

    this(Expression condition, Statement _body, Statement _else)
    {
        this.condition = condition;
        this._body = _body;
        this._else = _else;
    }

    mixin Acceptor;
}

class Break : Statement
{
    mixin Acceptor;
}

class RepeatUntil : Statement
{
    Statement _body;
    Expression condition;

    this(Statement _body, Expression condition)
    {
        this._body = _body;
        this.condition = condition;
    }

    mixin Acceptor;
}
