/*
 * Variables and built-in functions (an mfcalc-style calculator).
 *
 * Exercises: %union with three tags (double, function pointer, char*),
 * a std::map member kept as parser state, assignment (VAR = expr),
 * function-call syntax dispatched through a function pointer stored in
 * the semantic value, and precedence including right-associative '^'.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <cmath>
#include <map>
#include <string>

typedef double (*FnPtr)(double);

/* Wrappers avoid taking the address of overloaded <cmath> names. */
static double f_sqrt(double x) { return sqrt(x); }
static double f_sin (double x) { return sin(x);  }
static double f_cos (double x) { return cos(x);  }
static double f_log (double x) { return log(x);  }
static double f_exp (double x) { return exp(x);  }
static double f_abs (double x) { return fabs(x); }

static char* dupstr(const char* s)
{
    char* r = (char*)malloc(strlen(s) + 1);
    strcpy(r, s);
    return r;
}
%}

%union {
    double dval;
    FnPtr  fn;
    char*  name;
}

%token <dval> NUM
%token <fn>   FUNC
%token <name> VAR
%type  <dval> expr

%right '='
%left  '+' '-'
%left  '*' '/'
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
    | VAR                     { $$ = vars_[$1]; free($1); }
    | VAR '=' expr            { vars_[$1] = $3; $$ = $3; free($1); }
    | FUNC '(' expr ')'       { $$ = (*$1)($3); }
    | expr '+' expr           { $$ = $1 + $3; }
    | expr '-' expr           { $$ = $1 - $3; }
    | expr '*' expr           { $$ = $1 * $3; }
    | expr '/' expr           { $$ = $1 / $3; }
    | expr '^' expr           { $$ = pow($1, $3); }
    | '-' expr %prec UMINUS   { $$ = -$2; }
    | '(' expr ')'            { $$ = $2; }
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
        char buf[64];
        int  i = 0;
        while (i < 63 && (isdigit(c) || c == '.'))
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
        char buf[32];
        int  i = 0;
        do { buf[i++] = (char)c; c = getchar(); }
        while ((isalnum(c) || c == '_') && i < 31);
        buf[i] = '\0';
        if (c != EOF) ungetc(c, stdin);

        static const struct { const char* n; FnPtr f; } builtins[] = {
            {"sqrt", f_sqrt}, {"sin", f_sin}, {"cos", f_cos},
            {"log",  f_log},  {"exp", f_exp}, {"abs", f_abs},
        };
        for (const auto& b : builtins)
            if (strcmp(buf, b.n) == 0) { yylval.fn = b.f; return FUNC; }

        yylval.name = dupstr(buf);
        return VAR;
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
