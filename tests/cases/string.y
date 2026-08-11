/*
 * String manipulation.
 *
 * Exercises: %union mixing a pointer (char*) and a scalar (int), heap
 * management inside actions (malloc/free), string-typed and int-typed
 * rules in one grammar, and keyword lexing (upper/lower).
 *
 *   "a" . "b"      concatenation
 *   upper(s)       uppercase
 *   lower(s)       lowercase
 *   #s             length (int-valued)
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>

static char* dupstr(const char* s)
{
    char* r = (char*)malloc(strlen(s) + 1);
    strcpy(r, s);
    return r;
}
%}

%union {
    char* str;
    int   num;
}

%token <str> STRING
%token UPPER LOWER
%type  <str> expr
%type  <num> numexpr

%left '.'

%%

input
    : /* empty */
    | input line
    ;

line
    : '\n'
    | expr '\n'      { printf("%s\n", $1); free($1); }
    | numexpr '\n'   { printf("%d\n", $1); }
    ;

numexpr
    : '#' expr       { $$ = (int)strlen($2); free($2); }
    ;

expr
    : STRING
    | expr '.' expr
        {
            char* r = (char*)malloc(strlen($1) + strlen($3) + 1);
            strcpy(r, $1);
            strcat(r, $3);
            free($1);
            free($3);
            $$ = r;
        }
    | UPPER '(' expr ')'
        { for (char* p = $3; *p; ++p) *p = (char)toupper((unsigned char)*p); $$ = $3; }
    | LOWER '(' expr ')'
        { for (char* p = $3; *p; ++p) *p = (char)tolower((unsigned char)*p); $$ = $3; }
    | '(' expr ')'   { $$ = $2; }
    ;

%%

int yylex()
{
    int c;
    do { c = getchar(); } while (c == ' ' || c == '\t');
    if (c == EOF) return 0;

    if (c == '"')
    {
        char buf[256];
        int  i = 0;
        while ((c = getchar()) != EOF && c != '"' && i < 255)
            buf[i++] = (char)c;
        buf[i] = '\0';
        yylval.str = dupstr(buf);
        return STRING;
    }

    if (isalpha(c))
    {
        char buf[32];
        int  i = 0;
        do { buf[i++] = (char)c; c = getchar(); } while (isalpha(c) && i < 31);
        buf[i] = '\0';
        if (c != EOF) ungetc(c, stdin);
        if (strcmp(buf, "upper") == 0) return UPPER;
        if (strcmp(buf, "lower") == 0) return LOWER;
        return buf[0]; /* unknown word -> provoke a parse error */
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
