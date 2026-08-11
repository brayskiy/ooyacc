/*
 * Scientific calculator: mixed multi-operator expressions.
 *
 * Exercises everything together:
 *   - number types: decimal, float, scientific (1.5e3), hex (0xFF),
 *     binary (0b1010), octal (0o17)
 *   - single-arg functions: sqrt sin cos log exp abs floor ceil
 *   - two-arg functions: pow max min hypot
 *   - variables and assignment (std::map state)
 *   - full precedence with +, -, *, /, %, ^ (right assoc), unary minus,
 *     and deeply nested parentheses
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
typedef double (*Fn2)(double, double);

static double f_sqrt (double x) { return sqrt(x);  }
static double f_sin  (double x) { return sin(x);   }
static double f_cos  (double x) { return cos(x);   }
static double f_log  (double x) { return log(x);   }
static double f_exp  (double x) { return exp(x);   }
static double f_abs  (double x) { return fabs(x);  }
static double f_floor(double x) { return floor(x); }
static double f_ceil (double x) { return ceil(x);  }

static double g_pow  (double a, double b) { return pow(a, b);   }
static double g_max  (double a, double b) { return a > b ? a : b; }
static double g_min  (double a, double b) { return a < b ? a : b; }
static double g_hypot(double a, double b) { return hypot(a, b); }

static char* dupstr(const char* s)
{
    char* r = (char*)malloc(strlen(s) + 1);
    strcpy(r, s);
    return r;
}
%}

%union {
    double dval;
    Fn1    fn1;
    Fn2    fn2;
    char*  name;
}

%token <dval> NUM
%token <fn1>  FUNC1
%token <fn2>  FUNC2
%token <name> VAR
%type  <dval> expr

%right '='
%left  '+' '-'
%left  '*' '/' '%'
%right '^'
%right UMINUS

%%

input
    : /* empty */
    | input line
    ;

line
    : '\n'
    | expr '\n'   { printf("%.4f\n", $1); }
    ;

expr
    : NUM
    | VAR                          { $$ = vars_[$1]; free($1); }
    | VAR '=' expr                 { vars_[$1] = $3; $$ = $3; free($1); }
    | FUNC1 '(' expr ')'           { $$ = (*$1)($3); }
    | FUNC2 '(' expr ',' expr ')'  { $$ = (*$1)($3, $5); }
    | expr '+' expr                { $$ = $1 + $3; }
    | expr '-' expr                { $$ = $1 - $3; }
    | expr '*' expr                { $$ = $1 * $3; }
    | expr '/' expr                { $$ = $1 / $3; }
    | expr '%' expr                { $$ = fmod($1, $3); }
    | expr '^' expr                { $$ = pow($1, $3); }
    | '-' expr %prec UMINUS        { $$ = -$2; }
    | '(' expr ')'                 { $$ = $2; }
    ;

%%

std::map<std::string, double> vars_;

int yylex()
{
    int c;
    do { c = getchar(); } while (c == ' ' || c == '\t');
    if (c == EOF) return 0;

    if (isdigit(c) || c == '.')
    {
        /* Base-prefixed integers: 0x.. 0b.. 0o.. */
        if (c == '0')
        {
            int n = getchar();
            if (n == 'x' || n == 'X')
            {
                unsigned long v = 0; int d = getchar();
                while (isxdigit(d))
                {
                    v = v * 16 + (isdigit(d) ? d - '0' : tolower(d) - 'a' + 10);
                    d = getchar();
                }
                if (d != EOF) ungetc(d, stdin);
                yylval.dval = (double)v; return NUM;
            }
            if (n == 'b' || n == 'B')
            {
                unsigned long v = 0; int d = getchar();
                while (d == '0' || d == '1') { v = v * 2 + (d - '0'); d = getchar(); }
                if (d != EOF) ungetc(d, stdin);
                yylval.dval = (double)v; return NUM;
            }
            if (n == 'o' || n == 'O')
            {
                unsigned long v = 0; int d = getchar();
                while (d >= '0' && d <= '7') { v = v * 8 + (d - '0'); d = getchar(); }
                if (d != EOF) ungetc(d, stdin);
                yylval.dval = (double)v; return NUM;
            }
            if (n != EOF) ungetc(n, stdin);   /* plain 0 / 0.5 / 0e1 */
        }

        /* Decimal / floating / scientific. */
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
        return NUM;
    }

    if (isalpha(c) || c == '_')
    {
        char buf[32]; int i = 0;
        do { buf[i++] = (char)c; c = getchar(); }
        while ((isalnum(c) || c == '_') && i < 31);
        buf[i] = '\0';
        if (c != EOF) ungetc(c, stdin);

        static const struct { const char* n; Fn1 f; } one[] = {
            {"sqrt", f_sqrt}, {"sin", f_sin}, {"cos", f_cos}, {"log", f_log},
            {"exp", f_exp}, {"abs", f_abs}, {"floor", f_floor}, {"ceil", f_ceil},
        };
        static const struct { const char* n; Fn2 f; } two[] = {
            {"pow", g_pow}, {"max", g_max}, {"min", g_min}, {"hypot", g_hypot},
        };
        for (const auto& b : one) if (strcmp(buf, b.n) == 0) { yylval.fn1 = b.f; return FUNC1; }
        for (const auto& b : two) if (strcmp(buf, b.n) == 0) { yylval.fn2 = b.f; return FUNC2; }

        yylval.name = dupstr(buf);
        return VAR;
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
