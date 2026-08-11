/*
 * Floating-point calculator.
 *
 * Exercises: %union with a single double member, tagged tokens/types
 * (<dval>), automatic $$/$n tagging, exponentiation (right assoc),
 * unary minus, and scientific-notation lexing.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cctype>
#include <cmath>
%}

%union {
    double dval;
}

%token <dval> NUM
%type  <dval> expr

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
    | expr '+' expr           { $$ = $1 + $3; }
    | expr '-' expr           { $$ = $1 - $3; }
    | expr '*' expr           { $$ = $1 * $3; }
    | expr '/' expr           { $$ = $1 / $3; }
    | expr '^' expr           { $$ = pow($1, $3); }
    | '-' expr %prec UMINUS   { $$ = -$2; }
    | '(' expr ')'            { $$ = $2; }
    ;

%%

int yylex()
{
    int c;
    do { c = getchar(); } while (c == ' ' || c == '\t');
    if (c == EOF) return 0;
    if (isdigit(c) || c == '.')
    {
        char buf[64];
        int  i = 0;
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
    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
