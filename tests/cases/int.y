/*
 * Integer calculator.
 *
 * Exercises: default YYSTYPE (int), operator precedence across several
 * levels (bitwise, additive, multiplicative), left associativity, unary
 * minus via %prec, parentheses, and error recovery via the `error` token.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cctype>
%}

%left  '|'
%left  '&'
%left  '+' '-'
%left  '*' '/' '%'
%right UMINUS

%token INT

%%

input
    : /* empty */
    | input line
    ;

line
    : '\n'
    | expr '\n'   { printf("%d\n", $1); }
    | error '\n'  { yyerrok; printf("error\n"); }
    ;

expr
    : INT
    | expr '+' expr           { $$ = $1 + $3; }
    | expr '-' expr           { $$ = $1 - $3; }
    | expr '*' expr           { $$ = $1 * $3; }
    | expr '/' expr           { $$ = $1 / $3; }
    | expr '%' expr           { $$ = $1 % $3; }
    | expr '&' expr           { $$ = $1 & $3; }
    | expr '|' expr           { $$ = $1 | $3; }
    | '-' expr %prec UMINUS   { $$ = -$2; }
    | '(' expr ')'            { $$ = $2; }
    ;

%%

int yylex()
{
    int c;
    do { c = getchar(); } while (c == ' ' || c == '\t');
    if (c == EOF) return 0;
    if (isdigit(c))
    {
        int v = 0;
        do { v = v * 10 + (c - '0'); c = getchar(); } while (isdigit(c));
        if (c != EOF) ungetc(c, stdin);
        yylval = v;
        return INT;
    }
    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
