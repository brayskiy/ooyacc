/*
 * A tiny language with user-defined functions, plus numerical integration
 * by the 3-point Gauss-Legendre method.
 *
 *   def f(x) = <expr>;        define a user function of one variable
 *   integrate(f, a, b);       integral of f over [a, b] (3-point Gauss)
 *   <expr>;                   evaluate and print
 *
 * Expressions may call builtins (sqrt sin cos exp log abs) and user
 * functions -- including user functions that call other user functions.
 *
 * Exercises the generator on an AST-valued %union: because Gauss
 * quadrature evaluates the integrand at three abscissae, function bodies
 * are parsed into an AST and interpreted (recursively) rather than
 * evaluated once on reduction. User functions live in a std::map kept as
 * parser state.
 *
 * 3-point Gauss-Legendre on [-1,1]: nodes +/-sqrt(3/5), 0 with weights
 * 5/9, 8/9, 5/9; mapped to [a,b] via x = (b-a)/2 * xi + (a+b)/2. This is
 * exact for polynomials up to degree 5.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <cmath>
#include <map>
#include <string>

typedef double (*Fn1)(double);

static double b_sqrt(double x) { return sqrt(x); }
static double b_sin (double x) { return sin(x);  }
static double b_cos (double x) { return cos(x);  }
static double b_exp (double x) { return exp(x);  }
static double b_log (double x) { return log(x);  }
static double b_abs (double x) { return fabs(x); }

enum { N_NUM, N_VAR, N_NEG, N_BIN, N_BUILTIN, N_UCALL };

struct Node {
    int         kind = 0;
    double      num  = 0;
    int         op   = 0;         /* for N_BIN: '+','-','*','/','^' */
    Node*       l    = nullptr;
    Node*       r    = nullptr;
    std::string name;             /* N_VAR / N_UCALL identifier      */
    Fn1         fn   = nullptr;   /* N_BUILTIN                       */
};

struct UFunc { std::string param; Node* body = nullptr; };

static Node* mkNum(double v)                 { Node* n = new Node; n->kind = N_NUM;     n->num = v;               return n; }
static Node* mkVar(const char* s)            { Node* n = new Node; n->kind = N_VAR;     n->name = s;              return n; }
static Node* mkNeg(Node* a)                  { Node* n = new Node; n->kind = N_NEG;     n->l = a;                 return n; }
static Node* mkBin(int op, Node* a, Node* b) { Node* n = new Node; n->kind = N_BIN;     n->op = op; n->l = a; n->r = b; return n; }
static Node* mkCall(Fn1 f, Node* a)          { Node* n = new Node; n->kind = N_BUILTIN; n->fn = f; n->l = a;      return n; }
static Node* mkUCall(const char* s, Node* a) { Node* n = new Node; n->kind = N_UCALL;   n->name = s; n->l = a;    return n; }

static char* dupstr(const char* s)
{
    char* r = (char*)malloc(strlen(s) + 1);
    strcpy(r, s);
    return r;
}
%}

%union {
    double num;
    char*  name;
    Node*  node;
    Fn1    fn;
}

%token <num>  NUMBER
%token <name> NAME
%token <fn>   FUNC
%token        DEF INTEGRATE
%type  <node> expr

%left  '+' '-'
%left  '*' '/'
%right '^'
%right UMINUS

%%

program
    : /* empty */
    | program stmt
    ;

stmt
    : ';'
    | DEF NAME '(' NAME ')' '=' expr ';'
        {
            UFunc f; f.param = $4; f.body = $7;
            ufuncs_[$2] = f;
            free($2); free($4);
        }
    | expr ';'
        { printf("%.6f\n", eval($1, "", 0.0)); }
    ;

expr
    : NUMBER                              { $$ = mkNum($1); }
    | NAME                                { $$ = mkVar($1);  free($1); }
    | NAME '(' expr ')'                   { $$ = mkUCall($1, $3); free($1); }
    | FUNC '(' expr ')'                   { $$ = mkCall($1, $3); }
    | INTEGRATE '(' NAME ',' expr ',' expr ')'
        {
            double a = eval($5, "", 0.0);
            double b = eval($7, "", 0.0);
            $$ = mkNum(gaussIntegrate($3, a, b));
            free($3);
        }
    | expr '+' expr                       { $$ = mkBin('+', $1, $3); }
    | expr '-' expr                       { $$ = mkBin('-', $1, $3); }
    | expr '*' expr                       { $$ = mkBin('*', $1, $3); }
    | expr '/' expr                       { $$ = mkBin('/', $1, $3); }
    | expr '^' expr                       { $$ = mkBin('^', $1, $3); }
    | '-' expr %prec UMINUS               { $$ = mkNeg($2); }
    | '(' expr ')'                        { $$ = $2; }
    ;

%%

std::map<std::string, UFunc> ufuncs_;

double eval(Node* n, const std::string& p, double pv)
{
    switch (n->kind)
    {
    case N_NUM:     return n->num;
    case N_VAR:     return n->name == p ? pv : 0.0;
    case N_NEG:     return -eval(n->l, p, pv);
    case N_BUILTIN: return n->fn(eval(n->l, p, pv));
    case N_UCALL:
    {
        auto it = ufuncs_.find(n->name);
        if (it == ufuncs_.end()) return 0.0;
        double arg = eval(n->l, p, pv);
        return eval(it->second.body, it->second.param, arg);
    }
    case N_BIN:
    {
        double a = eval(n->l, p, pv), b = eval(n->r, p, pv);
        switch (n->op)
        {
        case '+': return a + b;
        case '-': return a - b;
        case '*': return a * b;
        case '/': return a / b;
        case '^': return pow(a, b);
        }
    }
    }
    return 0.0;
}

double gaussIntegrate(const std::string& name, double a, double b)
{
    auto it = ufuncs_.find(name);
    if (it == ufuncs_.end()) return 0.0;

    Node*              body = it->second.body;
    const std::string& p    = it->second.param;

    const double h = (b - a) / 2.0;
    const double c = (a + b) / 2.0;
    const double s = sqrt(3.0 / 5.0);          /* sqrt(0.6) */

    return h * ( (5.0 / 9.0) * eval(body, p, c - h * s)
               + (8.0 / 9.0) * eval(body, p, c)
               + (5.0 / 9.0) * eval(body, p, c + h * s) );
}

int yylex()
{
    int c;
    do { c = getchar(); } while (c == ' ' || c == '\t' || c == '\n' || c == '\r');
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
        char buf[32]; int i = 0;
        do { buf[i++] = (char)c; c = getchar(); }
        while ((isalnum(c) || c == '_') && i < 31);
        buf[i] = '\0';
        if (c != EOF) ungetc(c, stdin);

        if (strcmp(buf, "def") == 0)       return DEF;
        if (strcmp(buf, "integrate") == 0) return INTEGRATE;

        static const struct { const char* n; Fn1 f; } builtins[] = {
            {"sqrt", b_sqrt}, {"sin", b_sin}, {"cos", b_cos},
            {"exp", b_exp},   {"log", b_log}, {"abs", b_abs},
        };
        for (const auto& b : builtins)
            if (strcmp(buf, b.n) == 0) { yylval.fn = b.f; return FUNC; }

        yylval.name = dupstr(buf);
        return NAME;
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
