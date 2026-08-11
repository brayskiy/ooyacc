/*
 * Integer / bitwise calculator over multiple number bases.
 *
 * Exercises: a long-typed %union, integer literals in decimal, hex (0x),
 * binary (0b) and octal (0o), the full C bitwise/shift operator set with
 * C precedence, unary minus and bitwise NOT, and two-character operator
 * lexing (<<, >>).
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cctype>
%}

%union {
    long ival;
}

%token <ival> INT
%type  <ival> expr

%left  '|'
%left  '^'
%left  '&'
%left  LSHIFT RSHIFT
%left  '+' '-'
%left  '*' '/' '%'
%right UMINUS

%%

input
    : /* empty */
    | input line
    ;

line
    : '\n'
    | expr '\n'   { printf("%ld\n", $1); }
    ;

expr
    : INT
    | expr '+' expr           { $$ = $1 + $3; }
    | expr '-' expr           { $$ = $1 - $3; }
    | expr '*' expr           { $$ = $1 * $3; }
    | expr '/' expr           { $$ = $1 / $3; }
    | expr '%' expr           { $$ = $1 % $3; }
    | expr '|' expr           { $$ = $1 | $3; }
    | expr '^' expr           { $$ = $1 ^ $3; }
    | expr '&' expr           { $$ = $1 & $3; }
    | expr LSHIFT expr        { $$ = $1 << $3; }
    | expr RSHIFT expr        { $$ = $1 >> $3; }
    | '~' expr %prec UMINUS   { $$ = ~$2; }
    | '-' expr %prec UMINUS   { $$ = -$2; }
    | '(' expr ')'            { $$ = $2; }
    ;

%%

int yylex()
{
    int c;
    do { c = getchar(); } while (c == ' ' || c == '\t');
    if (c == EOF) return 0;

    if (c == '<') { int n = getchar(); if (n == '<') return LSHIFT; if (n != EOF) ungetc(n, stdin); return c; }
    if (c == '>') { int n = getchar(); if (n == '>') return RSHIFT; if (n != EOF) ungetc(n, stdin); return c; }

    if (isdigit(c))
    {
        long v = 0;
        if (c == '0')
        {
            int n = getchar();
            if (n == 'x' || n == 'X')
            {
                int d = getchar();
                while (isxdigit(d)) { v = v * 16 + (isdigit(d) ? d - '0' : tolower(d) - 'a' + 10); d = getchar(); }
                if (d != EOF) ungetc(d, stdin);
                yylval.ival = v; return INT;
            }
            if (n == 'b' || n == 'B')
            {
                int d = getchar();
                while (d == '0' || d == '1') { v = v * 2 + (d - '0'); d = getchar(); }
                if (d != EOF) ungetc(d, stdin);
                yylval.ival = v; return INT;
            }
            if (n == 'o' || n == 'O')
            {
                int d = getchar();
                while (d >= '0' && d <= '7') { v = v * 8 + (d - '0'); d = getchar(); }
                if (d != EOF) ungetc(d, stdin);
                yylval.ival = v; return INT;
            }
            if (n != EOF) ungetc(n, stdin);
        }
        v = c - '0';
        c = getchar();
        while (isdigit(c)) { v = v * 10 + (c - '0'); c = getchar(); }
        if (c != EOF) ungetc(c, stdin);
        yylval.ival = v;
        return INT;
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
