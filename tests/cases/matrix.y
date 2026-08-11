/*
 * Matrix manipulation via embedded (built-in) functions.
 *
 *   A = [[1, 2], [3, 4]];          matrices are 2D arrays
 *   det(m)                          determinant
 *   inverse(m)                      matrix inverse
 *   rotate(m)                       rotate 90 degrees clockwise
 *   submatrix(m, i, j)              minor: m with row i and column j removed
 *   solve(A, b)                     solution x of the linear system A x = b
 *   m[i][j]  m[i][j] = e            element access / mutation
 *   print e;  /  e;                 nested pretty-print
 *
 * The built-ins are implemented natively (in the manner of intgauss3):
 * matrix values (a recursive Value carried in the %union) are converted to
 * plain double matrices, the linear algebra runs by Gaussian elimination /
 * Gauss-Jordan, and the result is converted back. Builtins are dispatched
 * by name in one call rule, so they compose (e.g. det(submatrix(...))).
 * Whitespace (including newlines) is insignificant.
 */
%{
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <cctype>
#include <cmath>
#include <vector>
#include <map>
#include <string>
#include <algorithm>

struct Value {
    bool               isScalar = true;
    double             num      = 0;
    std::vector<Value> arr;
};

typedef std::vector<std::vector<double> > Mat;
typedef std::vector<double>               Vec;

static Value* scalar(double v) { Value* x = new Value; x->isScalar = true; x->num = v; return x; }

static Value* arrayVal(std::vector<Value*>* items)
{
    Value* x = new Value; x->isScalar = false;
    for (Value* it : *items) x->arr.push_back(*it);
    return x;
}

static double numOf(Value* v)       { return v->isScalar ? v->num : 0.0; }

static Mat toMat(const Value& v)
{
    Mat m;
    for (const Value& row : v.arr)
    {
        Vec r;
        for (const Value& e : row.arr) r.push_back(e.num);
        m.push_back(r);
    }
    return m;
}
static Vec toVec(const Value& v)
{
    Vec r;
    for (const Value& e : v.arr) r.push_back(e.num);
    return r;
}
static Value* fromMat(const Mat& m)
{
    Value* x = new Value; x->isScalar = false;
    for (const Vec& row : m)
    {
        Value r; r.isScalar = false;
        for (double e : row) { Value s; s.isScalar = true; s.num = e; r.arr.push_back(s); }
        x->arr.push_back(r);
    }
    return x;
}
static Value* fromVec(const Vec& v)
{
    Value* x = new Value; x->isScalar = false;
    for (double e : v) { Value s; s.isScalar = true; s.num = e; x->arr.push_back(s); }
    return x;
}

static double matDet(Mat a)
{
    int n = (int)a.size();
    double det = 1.0;
    for (int i = 0; i < n; ++i)
    {
        int p = i;
        for (int r = i + 1; r < n; ++r) if (fabs(a[r][i]) > fabs(a[p][i])) p = r;
        if (fabs(a[p][i]) < 1e-12) return 0.0;
        if (p != i) { std::swap(a[p], a[i]); det = -det; }
        det *= a[i][i];
        for (int r = i + 1; r < n; ++r)
        {
            double f = a[r][i] / a[i][i];
            for (int c = i; c < n; ++c) a[r][c] -= f * a[i][c];
        }
    }
    return det;
}

static Mat matInverse(Mat a)
{
    int n = (int)a.size();
    Mat inv(n, Vec(n, 0.0));
    for (int i = 0; i < n; ++i) inv[i][i] = 1.0;
    for (int i = 0; i < n; ++i)
    {
        int p = i;
        for (int r = i + 1; r < n; ++r) if (fabs(a[r][i]) > fabs(a[p][i])) p = r;
        std::swap(a[p], a[i]); std::swap(inv[p], inv[i]);
        double d = a[i][i];
        for (int c = 0; c < n; ++c) { a[i][c] /= d; inv[i][c] /= d; }
        for (int r = 0; r < n; ++r)
        {
            if (r == i) continue;
            double f = a[r][i];
            for (int c = 0; c < n; ++c) { a[r][c] -= f * a[i][c]; inv[r][c] -= f * inv[i][c]; }
        }
    }
    return inv;
}

static Mat matRotate(const Mat& m)   /* 90 degrees clockwise */
{
    int rows = (int)m.size(), cols = (int)m[0].size();
    Mat r(cols, Vec(rows, 0.0));
    for (int i = 0; i < cols; ++i)
        for (int j = 0; j < rows; ++j)
            r[i][j] = m[rows - 1 - j][i];
    return r;
}

static Mat matSubmatrix(const Mat& m, int ri, int cj)
{
    Mat r;
    for (int i = 0; i < (int)m.size(); ++i)
    {
        if (i == ri) continue;
        Vec row;
        for (int j = 0; j < (int)m[i].size(); ++j)
            if (j != cj) row.push_back(m[i][j]);
        r.push_back(row);
    }
    return r;
}

static Vec matSolve(Mat a, Vec b)
{
    int n = (int)a.size();
    for (int i = 0; i < n; ++i)
    {
        int p = i;
        for (int r = i + 1; r < n; ++r) if (fabs(a[r][i]) > fabs(a[p][i])) p = r;
        std::swap(a[p], a[i]); std::swap(b[p], b[i]);
        for (int r = i + 1; r < n; ++r)
        {
            double f = a[r][i] / a[i][i];
            for (int c = i; c < n; ++c) a[r][c] -= f * a[i][c];
            b[r] -= f * b[i];
        }
    }
    Vec x(n, 0.0);
    for (int i = n - 1; i >= 0; --i)
    {
        double s = b[i];
        for (int c = i + 1; c < n; ++c) s -= a[i][c] * x[c];
        x[i] = s / a[i][i];
    }
    return x;
}

static Value* callBuiltin(const char* name, std::vector<Value*>& a)
{
    std::string n = name;
    if (n == "det"       && a.size() == 1) return scalar(matDet(toMat(*a[0])));
    if (n == "inverse"   && a.size() == 1) return fromMat(matInverse(toMat(*a[0])));
    if (n == "rotate"    && a.size() == 1) return fromMat(matRotate(toMat(*a[0])));
    if (n == "submatrix" && a.size() == 3) return fromMat(matSubmatrix(toMat(*a[0]), (int)numOf(a[1]), (int)numOf(a[2])));
    if (n == "solve"     && a.size() == 2) return fromVec(matSolve(toMat(*a[0]), toVec(*a[1])));
    return scalar(0);
}

static void printValue(const Value& v)
{
    if (v.isScalar) { printf("%g", v.num + 0.0); return; }   /* + 0.0 normalizes -0 */
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
%token        PRINT
%type  <val>   expr
%type  <vlist> items itemlist args arglist
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
    | NAME '=' expr ';'          { arrays_[$1] = *$3; delete $3; free($1); }
    | NAME indices '=' expr ';'  { setElem($1, *$2, *$4); delete $2; delete $4; free($1); }
    | PRINT expr ';'            { printValue(*$2); putchar('\n'); delete $2; }
    | expr ';'                 { printValue(*$1); putchar('\n'); delete $1; }
    ;

expr
    : NUMBER                   { $$ = scalar($1); }
    | '[' items ']'            { $$ = arrayVal($2); delete $2; }
    | NAME                     { $$ = getVar($1); free($1); }
    | NAME indices             { $$ = getElem($1, *$2); delete $2; free($1); }
    | NAME '(' args ')'        { $$ = callBuiltin($1, *$3); delete $3; free($1); }
    | expr '+' expr            { $$ = scalar(numOf($1) + numOf($3)); delete $1; delete $3; }
    | expr '-' expr            { $$ = scalar(numOf($1) - numOf($3)); delete $1; delete $3; }
    | expr '*' expr            { $$ = scalar(numOf($1) * numOf($3)); delete $1; delete $3; }
    | expr '/' expr            { $$ = scalar(numOf($1) / numOf($3)); delete $1; delete $3; }
    | '-' expr %prec UMINUS    { $$ = scalar(-numOf($2)); delete $2; }
    | '(' expr ')'             { $$ = $2; }
    ;

items
    : /* empty */   { $$ = new std::vector<Value*>(); }
    | itemlist      { $$ = $1; }
    ;

itemlist
    : expr                 { $$ = new std::vector<Value*>(); $$->push_back($1); }
    | itemlist ',' expr    { $1->push_back($3); $$ = $1; }
    ;

args
    : /* empty */   { $$ = new std::vector<Value*>(); }
    | arglist       { $$ = $1; }
    ;

arglist
    : expr                 { $$ = new std::vector<Value*>(); $$->push_back($1); }
    | arglist ',' expr     { $1->push_back($3); $$ = $1; }
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

        yylval.name = dupstr(buf);
        return NAME;
    }

    return c;
}

void yyerror(const char* s)
{
    fprintf(stderr, "yyerror: %s\n", s);
}
