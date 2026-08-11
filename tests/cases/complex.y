/*
 * Complex-number calculator.
 *
 * Exercises: %union carrying a struct (Complex) alongside a scalar,
 * multiple semantic tags in one grammar (<dval> and <cval>), struct-valued
 * $$/$n, and mixing typed rules. A complex literal is written [re,im];
 * a bare number promotes to (n, 0).
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cctype>

struct Complex { double re, im; };
%}

%union {
    double  dval;
    Complex cval;
}

%token <dval> NUM
%type  <cval> expr

%left '+' '-'
%left '*'

%%

input
    : /* empty */
    | input line
    ;

line
    : '\n'
    | expr '\n'   { printf("%.2f%+.2fi\n", $1.re, $1.im); }
    ;

expr
    : NUM                     { $$.re = $1; $$.im = 0; }
    | '[' NUM ',' NUM ']'     { $$.re = $2; $$.im = $4; }
    | expr '+' expr           { $$.re = $1.re + $3.re; $$.im = $1.im + $3.im; }
    | expr '-' expr           { $$.re = $1.re - $3.re; $$.im = $1.im - $3.im; }
    | expr '*' expr           { $$.re = $1.re*$3.re - $1.im*$3.im;
                                $$.im = $1.re*$3.im + $1.im*$3.re; }
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
    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
