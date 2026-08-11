/*
 * Multi-dimensional (2D and 3D) arrays.
 *
 *   m = [[1, 2, 3], [4, 5, 6]];        create a nested array
 *   c = [[[1,2],[3,4]], [[5,6],[7,8]]];
 *   m[i][j]        m[i][j][k]          element access (any depth)
 *   m[i][j] = e;                       element mutation
 *   len(e)                             size of the outermost dimension
 *   sum(e)                             recursive sum of all scalars
 *   print e;                           nested-array pretty print
 *
 * Exercises a recursive value type carried through a %union of Value and
 * list pointers: array literals may nest arbitrarily, an index chain
 * (`[i][j]..`)
 * is its own list rule usable as both an rvalue (access) and an lvalue
 * (assignment), and element assignment walks into a std::vector-of-Value
 * stored as parser state. Whitespace (including newlines) is insignificant.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <vector>
#include <map>
#include <string>

struct Value {
    bool               isScalar = true;
    double             num      = 0;
    std::vector<Value> arr;
};

static Value* scalar(double v) { Value* x = new Value; x->isScalar = true; x->num = v; return x; }

static Value* arrayVal(std::vector<Value*>* items)
{
    Value* x = new Value; x->isScalar = false;
    for (Value* it : *items) x->arr.push_back(*it);
    return x;
}

static double numOf(Value* v)          { return v->isScalar ? v->num : 0.0; }
static double lenOf(const Value& v)    { return v.isScalar ? 1.0 : (double)v.arr.size(); }
static double sumVal(const Value& v)
{
    if (v.isScalar) return v.num;
    double s = 0; for (const Value& e : v.arr) s += sumVal(e);
    return s;
}

static void printValue(const Value& v)
{
    if (v.isScalar) { printf("%g", v.num); return; }
    putchar('[');
    for (size_t i = 0; i < v.arr.size(); ++i) { if (i) printf(", "); printValue(v.arr[i]); }
    putchar(']');
}

static char* dupstr(const char* s) { char* r = (char*)malloc(strlen(s) + 1); strcpy(r, s); return r; }
%}

%union {
    double                num;
    char*                 name;
    Value*                val;
    std::vector<Value*>*  vlist;
    std::vector<int>*     ilist;
}

%token <num>  NUMBER
%token <name> NAME
%token        LEN SUM PRINT
%type  <val>   expr
%type  <vlist> items itemlist
%type  <ilist> indices

%left '+' '-'
%left '*' '/'
%right UMINUS

%%

program
    : /* empty */
    | program stmt
    ;

stmt
    : ';'
    | NAME '=' expr ';'             { arrays_[$1] = *$3; delete $3; free($1); }
    | NAME indices '=' expr ';'     { setElem($1, *$2, *$4); delete $2; delete $4; free($1); }
    | PRINT expr ';'               { printValue(*$2); putchar('\n'); delete $2; }
    | expr ';'                     { printValue(*$1); putchar('\n'); delete $1; }
    ;

expr
    : NUMBER                       { $$ = scalar($1); }
    | '[' items ']'                { $$ = arrayVal($2); delete $2; }
    | NAME                         { $$ = getVar($1); free($1); }
    | NAME indices                 { $$ = getElem($1, *$2); delete $2; free($1); }
    | LEN '(' expr ')'             { $$ = scalar(lenOf(*$3)); delete $3; }
    | SUM '(' expr ')'             { $$ = scalar(sumVal(*$3)); delete $3; }
    | expr '+' expr                { $$ = scalar(numOf($1) + numOf($3)); delete $1; delete $3; }
    | expr '-' expr                { $$ = scalar(numOf($1) - numOf($3)); delete $1; delete $3; }
    | expr '*' expr                { $$ = scalar(numOf($1) * numOf($3)); delete $1; delete $3; }
    | expr '/' expr                { $$ = scalar(numOf($1) / numOf($3)); delete $1; delete $3; }
    | '-' expr %prec UMINUS        { $$ = scalar(-numOf($2)); delete $2; }
    | '(' expr ')'                 { $$ = $2; }
    ;

items
    : /* empty */   { $$ = new std::vector<Value*>(); }
    | itemlist      { $$ = $1; }
    ;

itemlist
    : expr                 { $$ = new std::vector<Value*>(); $$->push_back($1); }
    | itemlist ',' expr    { $1->push_back($3); $$ = $1; }
    ;

indices
    : '[' expr ']'           { $$ = new std::vector<int>(); $$->push_back((int)numOf($2)); delete $2; }
    | indices '[' expr ']'   { $1->push_back((int)numOf($3)); delete $3; $$ = $1; }
    ;

%%

std::map<std::string, Value> arrays_;

Value* getVar(const char* name)
{
    auto it = arrays_.find(name);
    return it == arrays_.end() ? scalar(0) : new Value(it->second);
}

Value* getElem(const char* name, std::vector<int>& idx)
{
    auto it = arrays_.find(name);
    if (it == arrays_.end()) return scalar(0);
    Value* cur = &it->second;
    for (int i : idx)
    {
        if (cur->isScalar || i < 0 || i >= (int)cur->arr.size()) return scalar(0);
        cur = &cur->arr[i];
    }
    return new Value(*cur);
}

void setElem(const char* name, std::vector<int>& idx, const Value& val)
{
    Value* cur = &arrays_[name];
    for (int i : idx)
    {
        if (cur->isScalar || i < 0 || i >= (int)cur->arr.size()) return;
        cur = &cur->arr[i];
    }
    *cur = val;
}

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

        if (strcmp(buf, "len")   == 0) return LEN;
        if (strcmp(buf, "sum")   == 0) return SUM;
        if (strcmp(buf, "print") == 0) return PRINT;

        yylval.name = dupstr(buf);
        return NAME;
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
