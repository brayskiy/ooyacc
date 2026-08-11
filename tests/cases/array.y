/*
 * Arrays: creation and manipulation.
 *
 *   a = [1, 2, 3];        create / assign an array (elements are exprs)
 *   a[i] = <expr>;        mutate an element
 *   a[i]                  element access (scalar)
 *   len(a) sum(a) avg(a) max(a) min(a) prod(a)   reductions
 *   print a;              print the whole array
 *   <expr>;              evaluate and print a scalar
 *
 * Exercises the generator on a %union carrying a std::vector<double>*
 * (a list built by a left-recursive rule), named arrays kept in a
 * std::map as parser state, and LALR resolution of `a[i]` used both as an
 * lvalue (element assignment) and an rvalue (element access) -- the '='
 * lookahead is not in FOLLOW(expr), so no conflict arises.
 *
 * Statements end with ';'; whitespace (including newlines) is insignificant.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <vector>
#include <map>
#include <string>

static char* dupstr(const char* s)
{
    char* r = (char*)malloc(strlen(s) + 1);
    strcpy(r, s);
    return r;
}
%}

%union {
    double                dval;
    char*                 name;
    std::vector<double>*  vec;
}

%token <dval> NUMBER
%token <name> NAME
%token        LEN SUM AVG MAX MIN PROD PRINT
%type  <dval> expr
%type  <vec>  elems elemlist

%left  '+' '-'
%left  '*' '/'
%right UMINUS

%%

program
    : /* empty */
    | program stmt
    ;

stmt
    : ';'
    | NAME '=' '[' elems ']' ';'
        { arrays_[$1] = *$4; delete $4; free($1); }
    | NAME '[' expr ']' '=' expr ';'
        {
            std::vector<double>& v = arrays_[$1];
            int i = (int)$3;
            if (i >= 0 && i < (int)v.size()) v[i] = $6;
            free($1);
        }
    | PRINT NAME ';'
        {
            std::vector<double>& v = arrays_[$2];
            for (size_t i = 0; i < v.size(); ++i) { if (i) putchar(' '); printf("%g", v[i]); }
            putchar('\n');
            free($2);
        }
    | expr ';'
        { printf("%g\n", $1); }
    ;

elems
    : /* empty */   { $$ = new std::vector<double>(); }
    | elemlist      { $$ = $1; }
    ;

elemlist
    : expr                { $$ = new std::vector<double>(); $$->push_back($1); }
    | elemlist ',' expr   { $1->push_back($3); $$ = $1; }
    ;

expr
    : NUMBER
    | NAME '[' expr ']'
        {
            std::vector<double>& v = arrays_[$1];
            int i = (int)$3;
            $$ = (i >= 0 && i < (int)v.size()) ? v[i] : 0.0;
            free($1);
        }
    | LEN  '(' NAME ')'   { $$ = (double)arrays_[$3].size(); free($3); }
    | SUM  '(' NAME ')'   { double s = 0; for (double x : arrays_[$3]) s += x; $$ = s; free($3); }
    | AVG  '(' NAME ')'
        {
            std::vector<double>& v = arrays_[$3];
            double s = 0; for (double x : v) s += x;
            $$ = v.empty() ? 0.0 : s / v.size();
            free($3);
        }
    | MAX  '(' NAME ')'
        {
            std::vector<double>& v = arrays_[$3];
            double m = v.empty() ? 0.0 : v[0];
            for (double x : v) if (x > m) m = x;
            $$ = m; free($3);
        }
    | MIN  '(' NAME ')'
        {
            std::vector<double>& v = arrays_[$3];
            double m = v.empty() ? 0.0 : v[0];
            for (double x : v) if (x < m) m = x;
            $$ = m; free($3);
        }
    | PROD '(' NAME ')'   { double p = 1; for (double x : arrays_[$3]) p *= x; $$ = p; free($3); }
    | expr '+' expr       { $$ = $1 + $3; }
    | expr '-' expr       { $$ = $1 - $3; }
    | expr '*' expr       { $$ = $1 * $3; }
    | expr '/' expr       { $$ = $1 / $3; }
    | '-' expr %prec UMINUS { $$ = -$2; }
    | '(' expr ')'        { $$ = $2; }
    ;

%%

std::map<std::string, std::vector<double> > arrays_;

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

        if (strcmp(buf, "len")  == 0) return LEN;
        if (strcmp(buf, "sum")  == 0) return SUM;
        if (strcmp(buf, "avg")  == 0) return AVG;
        if (strcmp(buf, "max")  == 0) return MAX;
        if (strcmp(buf, "min")  == 0) return MIN;
        if (strcmp(buf, "prod") == 0) return PROD;
        if (strcmp(buf, "print")== 0) return PRINT;

        yylval.name = dupstr(buf);
        return NAME;
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
