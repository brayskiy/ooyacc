/*
 * Boolean logic and comparison operators.
 *
 *   comparisons:  <  >  <=  >=  ==  !=      (operate on numbers -> boolean)
 *   logic:        &&  ||  !   and   or   not
 *   literals:     true  false
 *   arithmetic:   + - * / and parens, as comparison operands
 *
 * A value is a boolean or a number (SVal, carried by value in the %union).
 * Comparisons and logic yield booleans (printed true/false); arithmetic
 * yields numbers (printed with %g), so the two kinds are visible in the
 * output. Precedence, from lowest to highest: || , && , == != ,
 * < > <= >= , + - , * / , unary ! and -. Statements end with ';';
 * whitespace (including newlines) is insignificant.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>

struct SVal { bool isBool; double num; };

static SVal mkNum(double v)  { SVal s; s.isBool = false; s.num = v;             return s; }
static SVal mkBool(bool b)   { SVal s; s.isBool = true;  s.num = b ? 1.0 : 0.0; return s; }
static bool truthy(SVal s)   { return s.num != 0.0; }
%}

%union {
    double num;
    SVal   val;
}

%token <num> NUMBER
%token       TRUE FALSE AND OR NOT LE GE EQ NE
%type  <val> expr

%left  OR
%left  AND
%left  EQ NE
%left  '<' '>' LE GE
%left  '+' '-'
%left  '*' '/'
%right NOT UMINUS

%%

program
    : /* empty */
    | program stmt
    ;

stmt
    : ';'
    | expr ';'
        {
            if ($1.isBool) printf("%s\n", $1.num != 0.0 ? "true" : "false");
            else           printf("%g\n", $1.num);
        }
    ;

expr
    : NUMBER              { $$ = mkNum($1); }
    | TRUE               { $$ = mkBool(true); }
    | FALSE              { $$ = mkBool(false); }
    | expr OR  expr      { $$ = mkBool(truthy($1) || truthy($3)); }
    | expr AND expr      { $$ = mkBool(truthy($1) && truthy($3)); }
    | expr EQ  expr      { $$ = mkBool($1.num == $3.num); }
    | expr NE  expr      { $$ = mkBool($1.num != $3.num); }
    | expr '<' expr      { $$ = mkBool($1.num <  $3.num); }
    | expr '>' expr      { $$ = mkBool($1.num >  $3.num); }
    | expr LE  expr      { $$ = mkBool($1.num <= $3.num); }
    | expr GE  expr      { $$ = mkBool($1.num >= $3.num); }
    | expr '+' expr      { $$ = mkNum($1.num + $3.num); }
    | expr '-' expr      { $$ = mkNum($1.num - $3.num); }
    | expr '*' expr      { $$ = mkNum($1.num * $3.num); }
    | expr '/' expr      { $$ = mkNum($1.num / $3.num); }
    | NOT expr           { $$ = mkBool(!truthy($2)); }
    | '-' expr %prec UMINUS { $$ = mkNum(-$2.num); }
    | '(' expr ')'       { $$ = $2; }
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
        while (i < 63 && (isdigit(c) || c == '.'))
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
        char buf[16]; int i = 0;
        do { buf[i++] = (char)c; c = getchar(); }
        while ((isalnum(c) || c == '_') && i < 15);
        buf[i] = '\0';
        if (c != EOF) ungetc(c, stdin);

        if (strcmp(buf, "true")  == 0) return TRUE;
        if (strcmp(buf, "false") == 0) return FALSE;
        if (strcmp(buf, "and")   == 0) return AND;
        if (strcmp(buf, "or")    == 0) return OR;
        if (strcmp(buf, "not")   == 0) return NOT;
        return '?';   /* unknown word -> parse error */
    }

    switch (c)
    {
    case '<': { int n = getchar(); if (n == '=') return LE; if (n != EOF) ungetc(n, stdin); return '<'; }
    case '>': { int n = getchar(); if (n == '=') return GE; if (n != EOF) ungetc(n, stdin); return '>'; }
    case '=': { int n = getchar(); if (n == '=') return EQ; if (n != EOF) ungetc(n, stdin); return '='; }
    case '!': { int n = getchar(); if (n == '=') return NE; if (n != EOF) ungetc(n, stdin); return NOT; }
    case '&': { int n = getchar(); if (n == '&') return AND; if (n != EOF) ungetc(n, stdin); return '&'; }
    case '|': { int n = getchar(); if (n == '|') return OR;  if (n != EOF) ungetc(n, stdin); return '|'; }
    }
    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
