/*
 * Negative and error-handling calculator.
 *
 * Exercises: negative literals and negative results (unary minus),
 * syntax-error recovery via the `error` token (a malformed line reports
 * "error" and parsing resumes on the next line), and graceful semantic
 * error handling (division by zero reports "division by zero" instead of
 * crashing). A parser-state flag (err_) suppresses the numeric print on a
 * line that raised a semantic error.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cctype>
%}

%left  '+' '-'
%left  '*' '/'
%right UMINUS

%token INT

%%

input
    : /* empty */
    | input line
    ;

line
    : '\n'
    | expr '\n'    { if (!err_) printf("%d\n", $1); err_ = 0; }
    | error '\n'   { yyerrok; printf("error\n"); err_ = 0; }
    ;

expr
    : INT
    | expr '+' expr           { $$ = $1 + $3; }
    | expr '-' expr           { $$ = $1 - $3; }
    | expr '*' expr           { $$ = $1 * $3; }
    | expr '/' expr
        {
            if ($3 == 0) { printf("division by zero\n"); err_ = 1; $$ = 0; }
            else         { $$ = $1 / $3; }
        }
    | '-' expr %prec UMINUS   { $$ = -$2; }
    | '(' expr ')'            { $$ = $2; }
    ;

%%

bool err_ = false;

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
