/*
 * Trigonometric calculator.
 *
 * Exercises: one-argument trig/inverse/hyperbolic builtins (sin cos tan
 * asin acos atan sinh cosh tanh sqrt), a two-argument builtin (atan2, and
 * pow/hypot), the `pi` and `e` constants, and expressions combining them
 * to check well-known values and identities.
 *
 * Statements are terminated with ';'; whitespace (including newlines) is
 * insignificant.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <cmath>

typedef double (*Fn1)(double);
typedef double (*Fn2)(double, double);

static double t_sin  (double x) { return sin(x);   }
static double t_cos  (double x) { return cos(x);   }
static double t_tan  (double x) { return tan(x);   }
static double t_asin (double x) { return asin(x);  }
static double t_acos (double x) { return acos(x);  }
static double t_atan (double x) { return atan(x);  }
static double t_sinh (double x) { return sinh(x);  }
static double t_cosh (double x) { return cosh(x);  }
static double t_tanh (double x) { return tanh(x);  }
static double t_sqrt (double x) { return sqrt(x);  }

static double t_atan2(double y, double x) { return atan2(y, x); }
static double t_pow  (double a, double b) { return pow(a, b);   }
static double t_hypot(double a, double b) { return hypot(a, b); }

static const double PI = 3.14159265358979323846;
static const double E  = 2.71828182845904523536;
%}

%union {
    double dval;
    Fn1    fn1;
    Fn2    fn2;
}

%token <dval> NUMBER
%token <fn1>  FUNC1
%token <fn2>  FUNC2
%type  <dval> expr

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
    | expr ';'   { printf("%.6f\n", $1); }
    ;

expr
    : NUMBER
    | FUNC1 '(' expr ')'           { $$ = (*$1)($3); }
    | FUNC2 '(' expr ',' expr ')'  { $$ = (*$1)($3, $5); }
    | expr '+' expr                { $$ = $1 + $3; }
    | expr '-' expr                { $$ = $1 - $3; }
    | expr '*' expr                { $$ = $1 * $3; }
    | expr '/' expr                { $$ = $1 / $3; }
    | expr '^' expr                { $$ = pow($1, $3); }
    | '-' expr %prec UMINUS        { $$ = -$2; }
    | '(' expr ')'                 { $$ = $2; }
    ;

%%

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
        yylval.dval = atof(buf);
        return NUMBER;
    }

    if (isalpha(c) || c == '_')
    {
        char buf[32]; int i = 0;
        do { buf[i++] = (char)c; c = getchar(); }
        while ((isalnum(c) || c == '_') && i < 31);
        buf[i] = '\0';
        if (c != EOF) ungetc(c, stdin);

        if (strcmp(buf, "pi") == 0) { yylval.dval = PI; return NUMBER; }
        if (strcmp(buf, "e")  == 0) { yylval.dval = E;  return NUMBER; }

        static const struct { const char* n; Fn1 f; } one[] = {
            {"sin", t_sin}, {"cos", t_cos}, {"tan", t_tan},
            {"asin", t_asin}, {"acos", t_acos}, {"atan", t_atan},
            {"sinh", t_sinh}, {"cosh", t_cosh}, {"tanh", t_tanh},
            {"sqrt", t_sqrt},
        };
        static const struct { const char* n; Fn2 f; } two[] = {
            {"atan2", t_atan2}, {"pow", t_pow}, {"hypot", t_hypot},
        };
        for (const auto& b : one) if (strcmp(buf, b.n) == 0) { yylval.fn1 = b.f; return FUNC1; }
        for (const auto& b : two) if (strcmp(buf, b.n) == 0) { yylval.fn2 = b.f; return FUNC2; }

        return buf[0];   /* unknown identifier -> provoke a parse error */
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
