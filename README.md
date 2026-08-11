# ooyacc

A YACC-compatible LALR(1) parser generator (Berkeley yacc / byacc lineage)
that emits a **self-contained C++ parser class** instead of the classic C
functions and global tables.

Feed it a familiar `.y` grammar and it generates a class whose parse state,
stacks, and `yyparse()` are all members — so multiple parsers can coexist and
be embedded cleanly in C++ code.

## How it differs from classic yacc

- The output is a class named after the file prefix (default `y`), not a set
  of global functions.
- `yylex()` and `yyerror()` are **member functions** you supply in the
  grammar's functions section; they can read the parser's own state.
- `YYSTYPE` defaults to `int`; a `%union` (with `-d`) defines it as usual.
- `main()` lives in your own driver, which constructs the class and calls
  `yyparse()`.

## Build

```sh
make directories program   # builds ./bin/ooyacc
make                       # also installs to $HOME/bin
make test                  # build + run the test suite (see tests/)
```

Requires a C++17 compiler (`g++` by default) and `make`.

## Usage

```
ooyacc [-dlrtv] [-b file_prefix] [-p symbol_prefix] grammar.y
```

| Option | Effect |
|--------|--------|
| `-d`   | write the header (`<prefix>.tab.h`); **required for `%union`** |
| `-v`   | write a human-readable automaton dump (`<prefix>.output`) |
| `-l`   | omit `#line` directives from the generated code |
| `-r`   | split tables/code into a separate `<prefix>.code.c` |
| `-t`   | include debugging tables (`YYDEBUG`) |
| `-b`   | set the output file prefix / class name (default `y`) |
| `-p`   | set the symbol prefix (default `yy`) |

Output files (with default prefix `y`): `y.tab.cpp` (parser), `y.tab.h`
(class header, with `-d`), `y.output` (with `-v`).

## Example

A minimal grammar (`calc.y`):

```yacc
%{
#include <cstdio>
#include <cctype>
%}

%token NUM
%left '+' '-'
%left '*' '/'

%%
line : expr '\n'        { printf("%d\n", $1); }
     ;
expr : expr '+' expr    { $$ = $1 + $3; }
     | expr '-' expr    { $$ = $1 - $3; }
     | expr '*' expr    { $$ = $1 * $3; }
     | expr '/' expr    { $$ = $1 / $3; }
     | '(' expr ')'     { $$ = $2; }
     | NUM
     ;
%%

/* yylex and yyerror become members of the generated class */
int yylex()
{
    int c;
    do { c = getchar(); } while (c == ' ' || c == '\t');
    if (c == EOF) return 0;
    if (isdigit(c)) {
        int v = 0;
        do { v = v * 10 + (c - '0'); c = getchar(); } while (isdigit(c));
        if (c != EOF) ungetc(c, stdin);
        yylval = v;
        return NUM;
    }
    return c;
}

void yyerror(const char* s) { fprintf(stderr, "error: %s\n", s); }
```

A driver providing `main` (`driver.cpp`):

```cpp
#include "y.tab.h"

int main()
{
    y parser;
    return parser.yyparse();
}
```

Generate, compile, run:

```sh
ooyacc -d calc.y
g++ -std=c++17 y.tab.cpp driver.cpp -o calc
echo "1 + 2 * 3" | ./calc      # -> 7
```

See [`tests/cases`](tests/cases) for fuller examples: integer, floating-point,
and complex arithmetic; string manipulation; and variables with built-in
functions (using `%union` with scalar, struct, pointer, and function-pointer
tags).

## Testing

`make test` (or `bash tests/run_tests.sh`) generates a parser from each
grammar in `tests/cases`, compiles it with a shared driver, runs it, and
diffs stdout against a golden file. See [`tests/README.md`](tests/README.md).

## Continuous integration

CI runs the test suite on every pull request (validating the work branch) and
on every push to the default branch (validating post-merge). The default
branch accepts changes through pull requests only, and a PR merges only when
CI is green. See [`.github/README.md`](.github/README.md).

## License

See [LICENSE](LICENSE).
