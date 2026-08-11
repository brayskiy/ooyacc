/*
 * String manipulation functions.
 *
 *   s = "text";                       assign a string variable
 *   len(s)            length          upper(s) / lower(s)   case
 *   substr(s, i, n)   substring        find(s, sub)         index or -1
 *   replace(s, a, b)  replace all      reverse(s)           reverse
 *   repeat(s, n)      repeat           charat(s, i)         one-char string
 *   a + b             concatenation (numbers stringify); + adds two numbers
 *   print e;  /  e;                   print a string or number
 *
 * Values are string-or-number, carried through the %union as an SVal*.
 * Builtins have varying arity and are dispatched by name in one call rule
 * (NAME '(' args ')'), which coexists with plain NAME variables because '('
 * is not in FOLLOW(expr). Whitespace (including newlines) is insignificant.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <vector>
#include <map>
#include <string>
#include <algorithm>

struct SVal {
    bool        isNum = true;
    double      num   = 0;
    std::string str;
};

static SVal* numVal(double v)             { SVal* x = new SVal; x->isNum = true;  x->num = v; return x; }
static SVal* strVal(const std::string& s) { SVal* x = new SVal; x->isNum = false; x->str = s; return x; }

static std::string asStr(SVal* v)
{
    if (!v->isNum) return v->str;
    char buf[64]; snprintf(buf, sizeof buf, "%g", v->num);
    return buf;
}
static double asNum(SVal* v) { return v->isNum ? v->num : atof(v->str.c_str()); }

static char* dupstr(const char* s) { char* r = (char*)malloc(strlen(s) + 1); strcpy(r, s); return r; }
%}

%union {
    double               num;
    char*                str;
    SVal*                val;
    std::vector<SVal*>*  args;
}

%token <num> NUMBER
%token <str> STRING NAME
%token       PRINT
%type  <val>  expr
%type  <args> arglist arglistne

%left '+' '-'
%left '*' '/'

%%

program
    : /* empty */
    | program stmt
    ;

stmt
    : ';'
    | NAME '=' expr ';'    { vars_[$1] = *$3; delete $3; free($1); }
    | PRINT expr ';'      { printVal($2); delete $2; }
    | expr ';'            { printVal($1); delete $1; }
    ;

expr
    : STRING              { $$ = strVal($1); free($1); }
    | NUMBER              { $$ = numVal($1); }
    | NAME                { $$ = getVar($1); free($1); }
    | NAME '(' arglist ')' { $$ = callBuiltin($1, *$3); delete $3; free($1); }
    | expr '+' expr
        {
            if ($1->isNum && $3->isNum) $$ = numVal($1->num + $3->num);
            else                        $$ = strVal(asStr($1) + asStr($3));
            delete $1; delete $3;
        }
    | expr '-' expr       { $$ = numVal(asNum($1) - asNum($3)); delete $1; delete $3; }
    | expr '*' expr       { $$ = numVal(asNum($1) * asNum($3)); delete $1; delete $3; }
    | expr '/' expr       { $$ = numVal(asNum($1) / asNum($3)); delete $1; delete $3; }
    | '(' expr ')'        { $$ = $2; }
    ;

arglist
    : /* empty */   { $$ = new std::vector<SVal*>(); }
    | arglistne     { $$ = $1; }
    ;

arglistne
    : expr                  { $$ = new std::vector<SVal*>(); $$->push_back($1); }
    | arglistne ',' expr    { $1->push_back($3); $$ = $1; }
    ;

%%

std::map<std::string, SVal> vars_;

SVal* getVar(const char* name)
{
    auto it = vars_.find(name);
    return it == vars_.end() ? strVal("") : new SVal(it->second);
}

void printVal(SVal* v)
{
    if (v->isNum) printf("%g\n", v->num);
    else          printf("%s\n", v->str.c_str());
}

SVal* callBuiltin(const char* name, std::vector<SVal*>& a)
{
    std::string n = name;
    SVal* r = 0;

    if (n == "len" && a.size() == 1)
        r = numVal((double)asStr(a[0]).size());
    else if (n == "upper" && a.size() == 1)
    {
        std::string s = asStr(a[0]);
        for (char& c : s) c = (char)toupper((unsigned char)c);
        r = strVal(s);
    }
    else if (n == "lower" && a.size() == 1)
    {
        std::string s = asStr(a[0]);
        for (char& c : s) c = (char)tolower((unsigned char)c);
        r = strVal(s);
    }
    else if (n == "reverse" && a.size() == 1)
    {
        std::string s = asStr(a[0]);
        std::reverse(s.begin(), s.end());
        r = strVal(s);
    }
    else if (n == "substr" && a.size() == 3)
    {
        std::string s = asStr(a[0]);
        int start = (int)asNum(a[1]);
        int count = (int)asNum(a[2]);
        if (start < 0) start = 0;
        if (start > (int)s.size()) start = s.size();
        r = strVal(s.substr(start, count));
    }
    else if (n == "find" && a.size() == 2)
    {
        std::string s = asStr(a[0]), sub = asStr(a[1]);
        size_t pos = s.find(sub);
        r = numVal(pos == std::string::npos ? -1.0 : (double)pos);
    }
    else if (n == "replace" && a.size() == 3)
    {
        std::string s = asStr(a[0]), from = asStr(a[1]), to = asStr(a[2]);
        if (!from.empty())
            for (size_t p = s.find(from); p != std::string::npos; p = s.find(from, p + to.size()))
                s.replace(p, from.size(), to);
        r = strVal(s);
    }
    else if (n == "repeat" && a.size() == 2)
    {
        std::string s = asStr(a[0]), out;
        int k = (int)asNum(a[1]);
        for (int i = 0; i < k; ++i) out += s;
        r = strVal(out);
    }
    else if (n == "charat" && a.size() == 2)
    {
        std::string s = asStr(a[0]);
        int i = (int)asNum(a[1]);
        r = strVal((i >= 0 && i < (int)s.size()) ? std::string(1, s[i]) : std::string());
    }
    else
        r = strVal("");   /* unknown builtin / arity */

    for (SVal* p : a) delete p;
    return r;
}

int yylex()
{
    int c;
    do { c = getchar(); } while (c == ' ' || c == '\t' || c == '\n' || c == '\r');
    if (c == EOF) return 0;

    if (c == '"')
    {
        std::string s;
        while ((c = getchar()) != EOF && c != '"') s += (char)c;
        yylval.str = dupstr(s.c_str());
        return STRING;
    }

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
        char buf[32]; int i = 0;
        do { buf[i++] = (char)c; c = getchar(); }
        while ((isalnum(c) || c == '_') && i < 31);
        buf[i] = '\0';
        if (c != EOF) ungetc(c, stdin);

        if (strcmp(buf, "print") == 0) return PRINT;

        yylval.str = dupstr(buf);
        return NAME;
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
