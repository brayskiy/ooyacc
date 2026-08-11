/*
 * A small imperative language: control flow and user functions.
 *
 *   x = <expr>;                       assignment
 *   print <expr>;                     print a value
 *   if (c) { .. } elseif (c) { .. } else { .. }
 *   while (c) { .. }
 *   for (i = a; c; i = e) { .. }
 *   case (e) { when v: ..  when v: ..  else: .. }
 *   func name(a, b) { ..  return e; }   definition (recursion allowed)
 *   name(args)                        call (expression or statement)
 *   # line comment
 *
 * Because loops and conditionals execute their bodies conditionally or
 * repeatedly, statements and expressions are parsed into an AST and then
 * interpreted -- exercising the generator on a %union of several AST/list
 * pointer types, list-building rules, elseif desugaring, and a large rule
 * set. Functions get their own local scope; `return` unwinds via a thrown
 * value. Whitespace (including newlines) is insignificant.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <cmath>
#include <vector>
#include <map>
#include <string>

struct Expr;
struct Stmt;
struct CaseArm { Expr* val; std::vector<Stmt*> body; };
struct Func    { std::vector<std::string> params; std::vector<Stmt*> body; };
struct ReturnEx { double value; };

enum { E_NUM, E_VAR, E_UN, E_BIN, E_CALL };
enum { OP_LE = 1001, OP_GE, OP_EQ, OP_NE, OP_AND, OP_OR, OP_NOT, OP_NEG };

struct Expr {
    int                kind = 0;
    double             num  = 0;
    std::string        name;
    int                op   = 0;
    Expr*              a    = nullptr;
    Expr*              b    = nullptr;
    std::vector<Expr*> args;
};

enum { S_ASSIGN, S_PRINT, S_RETURN, S_EXPR, S_IF, S_WHILE, S_FOR, S_CASE };

struct Stmt {
    int                   kind = 0;
    std::string           name;                 /* assignment target      */
    Expr*                 e    = nullptr;        /* value / cond / switch  */
    Expr*                 cond = nullptr;        /* if/while/for condition */
    std::vector<Stmt*>    body;
    std::vector<Stmt*>    elseBody;
    Stmt*                 init = nullptr;        /* for-init               */
    Stmt*                 post = nullptr;        /* for-post               */
    std::vector<CaseArm>  arms;                  /* case arms              */
};

static Expr* mkNum(double v)                       { Expr* e = new Expr; e->kind = E_NUM; e->num = v; return e; }
static Expr* mkVar(const char* s)                  { Expr* e = new Expr; e->kind = E_VAR; e->name = s; return e; }
static Expr* mkUn(int op, Expr* a)                 { Expr* e = new Expr; e->kind = E_UN; e->op = op; e->a = a; return e; }
static Expr* mkBin(int op, Expr* a, Expr* b)       { Expr* e = new Expr; e->kind = E_BIN; e->op = op; e->a = a; e->b = b; return e; }
static Expr* mkCall(const char* s, std::vector<Expr*>* args) { Expr* e = new Expr; e->kind = E_CALL; e->name = s; e->args = *args; return e; }

static Stmt* mkAssign(const char* n, Expr* e)      { Stmt* s = new Stmt; s->kind = S_ASSIGN; s->name = n; s->e = e; return s; }
static Stmt* mkPrint(Expr* e)                      { Stmt* s = new Stmt; s->kind = S_PRINT; s->e = e; return s; }
static Stmt* mkReturn(Expr* e)                     { Stmt* s = new Stmt; s->kind = S_RETURN; s->e = e; return s; }
static Stmt* mkExprStmt(Expr* e)                   { Stmt* s = new Stmt; s->kind = S_EXPR; s->e = e; return s; }
static Stmt* mkIf(Expr* c, std::vector<Stmt*>* t, std::vector<Stmt*>* el) { Stmt* s = new Stmt; s->kind = S_IF; s->cond = c; s->body = *t; s->elseBody = *el; return s; }
static Stmt* mkWhile(Expr* c, std::vector<Stmt*>* b) { Stmt* s = new Stmt; s->kind = S_WHILE; s->cond = c; s->body = *b; return s; }
static Stmt* mkFor(const char* n1, Expr* e1, Expr* c, const char* n2, Expr* e3, std::vector<Stmt*>* b)
{
    Stmt* s = new Stmt; s->kind = S_FOR;
    s->init = mkAssign(n1, e1); s->cond = c; s->post = mkAssign(n2, e3); s->body = *b;
    return s;
}
static Stmt* mkCase(Expr* sw, std::vector<CaseArm>* arms, std::vector<Stmt*>* el)
{
    Stmt* s = new Stmt; s->kind = S_CASE; s->e = sw; s->arms = *arms; s->elseBody = *el;
    return s;
}

static char* dupstr(const char* s) { char* r = (char*)malloc(strlen(s) + 1); strcpy(r, s); return r; }
%}

%union {
    double                     num;
    char*                      name;
    Expr*                      expr;
    Stmt*                      stmt;
    std::vector<Stmt*>*        slist;
    std::vector<std::string>*  strlist;
    std::vector<Expr*>*        elist;
    std::vector<CaseArm>*      arms;
}

%token <num>  NUMBER
%token <name> NAME
%token        PRINT IF ELSEIF ELSE WHILE FOR CASE WHEN FUNC RETURN
%token        LE GE EQ NE AND OR NOT

%type <expr>    expr
%type <stmt>    stmt ifstmt
%type <slist>   block stmtlist elsepart elsearm
%type <strlist> params paramlist
%type <elist>   args arglist
%type <arms>    arms

%left  OR
%left  AND
%left  EQ NE
%left  '<' '>' LE GE
%left  '+' '-'
%left  '*' '/' '%'
%right NOT UMINUS

%%

program
    : /* empty */
    | program item
    ;

item
    : funcdef
    | stmt      { execTop($1); }
    ;

funcdef
    : FUNC NAME '(' params ')' block
        {
            Func fn; fn.params = *$4; fn.body = *$6;
            funcs_[$2] = fn;
            delete $4; delete $6; free($2);
        }
    ;

params
    : /* empty */   { $$ = new std::vector<std::string>(); }
    | paramlist     { $$ = $1; }
    ;

paramlist
    : NAME                { $$ = new std::vector<std::string>(); $$->push_back($1); free($1); }
    | paramlist ',' NAME  { $1->push_back($3); free($3); $$ = $1; }
    ;

block
    : '{' stmtlist '}'    { $$ = $2; }
    ;

stmtlist
    : /* empty */         { $$ = new std::vector<Stmt*>(); }
    | stmtlist stmt       { $1->push_back($2); $$ = $1; }
    ;

stmt
    : NAME '=' expr ';'                 { $$ = mkAssign($1, $3); free($1); }
    | PRINT expr ';'                    { $$ = mkPrint($2); }
    | RETURN expr ';'                   { $$ = mkReturn($2); }
    | expr ';'                          { $$ = mkExprStmt($1); }
    | ifstmt                            { $$ = $1; }
    | WHILE '(' expr ')' block          { $$ = mkWhile($3, $5); delete $5; }
    | FOR '(' NAME '=' expr ';' expr ';' NAME '=' expr ')' block
        { $$ = mkFor($3, $5, $7, $9, $11, $13); free($3); free($9); delete $13; }
    | CASE '(' expr ')' '{' arms elsearm '}'
        { $$ = mkCase($3, $6, $7); delete $6; delete $7; }
    ;

ifstmt
    : IF '(' expr ')' block elsepart    { $$ = mkIf($3, $5, $6); delete $5; delete $6; }
    ;

elsepart
    : /* empty */                       { $$ = new std::vector<Stmt*>(); }
    | ELSE block                        { $$ = $2; }
    | ELSEIF '(' expr ')' block elsepart
        {
            std::vector<Stmt*>* wrap = new std::vector<Stmt*>();
            wrap->push_back(mkIf($3, $5, $6));
            delete $5; delete $6;
            $$ = wrap;
        }
    ;

arms
    : /* empty */                       { $$ = new std::vector<CaseArm>(); }
    | arms WHEN expr ':' stmtlist
        { CaseArm a; a.val = $3; a.body = *$5; delete $5; $1->push_back(a); $$ = $1; }
    ;

elsearm
    : /* empty */                       { $$ = new std::vector<Stmt*>(); }
    | ELSE ':' stmtlist                 { $$ = $3; }
    ;

expr
    : NUMBER                            { $$ = mkNum($1); }
    | NAME                              { $$ = mkVar($1); free($1); }
    | NAME '(' args ')'                 { $$ = mkCall($1, $3); delete $3; free($1); }
    | expr '+' expr                     { $$ = mkBin('+', $1, $3); }
    | expr '-' expr                     { $$ = mkBin('-', $1, $3); }
    | expr '*' expr                     { $$ = mkBin('*', $1, $3); }
    | expr '/' expr                     { $$ = mkBin('/', $1, $3); }
    | expr '%' expr                     { $$ = mkBin('%', $1, $3); }
    | expr '<' expr                     { $$ = mkBin('<', $1, $3); }
    | expr '>' expr                     { $$ = mkBin('>', $1, $3); }
    | expr LE expr                      { $$ = mkBin(OP_LE, $1, $3); }
    | expr GE expr                      { $$ = mkBin(OP_GE, $1, $3); }
    | expr EQ expr                      { $$ = mkBin(OP_EQ, $1, $3); }
    | expr NE expr                      { $$ = mkBin(OP_NE, $1, $3); }
    | expr AND expr                     { $$ = mkBin(OP_AND, $1, $3); }
    | expr OR expr                      { $$ = mkBin(OP_OR, $1, $3); }
    | NOT expr                          { $$ = mkUn(OP_NOT, $2); }
    | '-' expr %prec UMINUS             { $$ = mkUn(OP_NEG, $2); }
    | '(' expr ')'                      { $$ = $2; }
    ;

args
    : /* empty */   { $$ = new std::vector<Expr*>(); }
    | arglist       { $$ = $1; }
    ;

arglist
    : expr                { $$ = new std::vector<Expr*>(); $$->push_back($1); }
    | arglist ',' expr    { $1->push_back($3); $$ = $1; }
    ;

%%

std::map<std::string, Func>   funcs_;
std::map<std::string, double> global_;

double eval(Expr* e, std::map<std::string, double>& env)
{
    switch (e->kind)
    {
    case E_NUM: return e->num;
    case E_VAR:
    {
        auto it = env.find(e->name);
        return it == env.end() ? 0.0 : it->second;
    }
    case E_UN:
    {
        double a = eval(e->a, env);
        return e->op == OP_NOT ? (a == 0.0 ? 1.0 : 0.0) : -a;
    }
    case E_BIN:
    {
        double a = eval(e->a, env), b = eval(e->b, env);
        switch (e->op)
        {
        case '+':    return a + b;
        case '-':    return a - b;
        case '*':    return a * b;
        case '/':    return a / b;
        case '%':    return fmod(a, b);
        case '<':    return a <  b ? 1.0 : 0.0;
        case '>':    return a >  b ? 1.0 : 0.0;
        case OP_LE:  return a <= b ? 1.0 : 0.0;
        case OP_GE:  return a >= b ? 1.0 : 0.0;
        case OP_EQ:  return a == b ? 1.0 : 0.0;
        case OP_NE:  return a != b ? 1.0 : 0.0;
        case OP_AND: return (a != 0.0 && b != 0.0) ? 1.0 : 0.0;
        case OP_OR:  return (a != 0.0 || b != 0.0) ? 1.0 : 0.0;
        }
        return 0.0;
    }
    case E_CALL:
    {
        auto it = funcs_.find(e->name);
        if (it == funcs_.end()) return 0.0;
        Func& f = it->second;
        std::map<std::string, double> local;
        for (size_t i = 0; i < f.params.size() && i < e->args.size(); ++i)
            local[f.params[i]] = eval(e->args[i], env);
        try { for (Stmt* st : f.body) exec(st, local); }
        catch (ReturnEx& r) { return r.value; }
        return 0.0;
    }
    }
    return 0.0;
}

void exec(Stmt* s, std::map<std::string, double>& env)
{
    switch (s->kind)
    {
    case S_ASSIGN: env[s->name] = eval(s->e, env); break;
    case S_PRINT:  printf("%g\n", eval(s->e, env)); break;
    case S_EXPR:   eval(s->e, env); break;
    case S_RETURN: throw ReturnEx{ eval(s->e, env) };
    case S_IF:
        if (eval(s->cond, env) != 0.0) { for (Stmt* b : s->body)     exec(b, env); }
        else                           { for (Stmt* b : s->elseBody) exec(b, env); }
        break;
    case S_WHILE:
        while (eval(s->cond, env) != 0.0)
            for (Stmt* b : s->body) exec(b, env);
        break;
    case S_FOR:
        for (exec(s->init, env); eval(s->cond, env) != 0.0; exec(s->post, env))
            for (Stmt* b : s->body) exec(b, env);
        break;
    case S_CASE:
    {
        double v = eval(s->e, env);
        for (CaseArm& a : s->arms)
            if (eval(a.val, env) == v) { for (Stmt* b : a.body) exec(b, env); return; }
        for (Stmt* b : s->elseBody) exec(b, env);
        break;
    }
    }
}

void execTop(Stmt* s) { exec(s, global_); }

int yylex()
{
    int c;
    for (;;)
    {
        c = getchar();
        if (c == ' ' || c == '\t' || c == '\n' || c == '\r') continue;
        if (c == '#') { while ((c = getchar()) != EOF && c != '\n') {} continue; }
        break;
    }
    if (c == EOF) return 0;

    if (isdigit(c) || c == '.')
    {
        char buf[64]; int i = 0;
        while (i < 63 &&
               (isdigit(c) || c == '.' || c == 'e' || c == 'E' ||
                ((c == '+' || c == '-') && i > 0 &&
                 (buf[i-1] == 'e' || buf[i-1] == 'E'))))
        {
            buf[i++] = (char)c;
            c = getchar();
        }
        buf[i] = '\0';
        if (c != EOF) ungetc(c, stdin);
        yylval.num = atof(buf);
        return NUMBER;
    }

    if (isalpha(c) || c == '_')
    {
        char buf[64]; int i = 0;
        do { buf[i++] = (char)c; c = getchar(); }
        while ((isalnum(c) || c == '_') && i < 63);
        buf[i] = '\0';
        if (c != EOF) ungetc(c, stdin);

        if (strcmp(buf, "print")  == 0) return PRINT;
        if (strcmp(buf, "if")     == 0) return IF;
        if (strcmp(buf, "elseif") == 0) return ELSEIF;
        if (strcmp(buf, "else")   == 0) return ELSE;
        if (strcmp(buf, "while")  == 0) return WHILE;
        if (strcmp(buf, "for")    == 0) return FOR;
        if (strcmp(buf, "case")   == 0) return CASE;
        if (strcmp(buf, "when")   == 0) return WHEN;
        if (strcmp(buf, "func")   == 0) return FUNC;
        if (strcmp(buf, "return") == 0) return RETURN;

        yylval.name = dupstr(buf);
        return NAME;
    }

    switch (c)
    {
    case '<': { int n = getchar(); if (n == '=') return LE; if (n != EOF) ungetc(n, stdin); return '<'; }
    case '>': { int n = getchar(); if (n == '=') return GE; if (n != EOF) ungetc(n, stdin); return '>'; }
    case '=': { int n = getchar(); if (n == '=') return EQ; if (n != EOF) ungetc(n, stdin); return '='; }
    case '!': { int n = getchar(); if (n == '=') return NE; if (n != EOF) ungetc(n, stdin); return NOT; }
    case '&': { int n = getchar(); if (n == '&') return AND; if (n != EOF) ungetc(n, stdin); return '&'; }
    case '|': { int n = getchar(); if (n == '|') return OR;  if (n != EOF) ungetc(n, stdin); return '|'; }
    }
    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
