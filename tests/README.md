# ooyacc test suite

End-to-end tests that exercise the generator by feeding it real grammars,
compiling the C++ parser class it emits, running it, and comparing output
against a golden file.

## Running

```sh
make test          # from the repo root
# or
bash tests/run_tests.sh
```

`CXX` and `CXXFLAGS` can be overridden, e.g. `CXX=clang++ make test`.

Each case passes only if the grammar generates, the generated parser
compiles cleanly with the shared driver, and its stdout matches the
expected file exactly.

## Layout

```
tests/
  driver.cpp        generic main(): constructs the generated class `y`
                    and calls yyparse(); shared by every case
  run_tests.sh      the harness (generate -> compile -> run -> diff)
  cases/
    <name>.y        a grammar
    <name>.in       stdin fed to the compiled parser
    <name>.expected exact expected stdout
```

Every grammar's lexer (`yylex`) reads from stdin and its actions print to
stdout, which is why one driver serves them all.

## Cases and what they cover

| Case      | Feature area                                                              |
|-----------|--------------------------------------------------------------------------|
| `int`     | default `YYSTYPE` (int), multi-level precedence, left assoc, unary `%prec`, `error` recovery |
| `float`   | `%union` (one member), tagged `<dval>` tokens/types, right-assoc `^`, sci-notation lexing |
| `complex` | `%union` with a struct member, multiple tags (`<dval>`/`<cval>`), struct-valued `$$`/`$n` |
| `string`  | `%union` mixing `char*` and `int`, heap allocation in actions, keyword lexing |
| `func`    | three-tag `%union` (double / function pointer / char*), `std::map` parser state, assignment, function calls |
| `mixed`   | everything at once: decimal/float/scientific/hex/binary/octal literals, one- and two-arg functions, variables, nested parentheses, full precedence |
| `bases`   | `long`-typed `%union`, integer literals in several bases, C bitwise/shift operators and precedence, unary `~`/`-`, two-char operator lexing |
| `errors`  | negative literals/results, `error`-token recovery (a bad line reports `error` and parsing resumes), graceful semantic errors (division by zero), parser-state flag |
| `intgauss3`| user-defined functions (`def f(x) = ...`) and 3-point Gauss-Legendre integration; AST-valued `%union` with recursive interpretation, `std::map` of user functions as parser state, user functions calling user functions |
| `trig`    | trigonometric / inverse / hyperbolic builtins (sin cos tan asin acos atan sinh cosh tanh), two-arg `atan2`, `pi`/`e` constants, and well-known values and identities |
| `array`   | array creation/indexing/mutation, reductions (len/sum/avg/max/min/prod), `print`; `%union` carrying a `std::vector<double>*` built by a left-recursive list rule, arrays kept in a `std::map`, `a[i]` as both lvalue and rvalue |
| `control` | a small imperative language: `while`, `for`, `if`/`elseif`/`else`, `case`/`when`, `func` definitions with recursion and local scope; statement+expression AST interpreted after parse, multi-type pointer `%union`, list-building rules, elseif desugaring, comments (`#`) |

## Adding a case

Drop `<name>.y`, `<name>.in`, and `<name>.expected` into `cases/`. The
grammar must define `yylex` (reading stdin) and `yyerror`; the harness
picks it up automatically. Use `-d`-friendly constructs — the harness
always generates with `-d`, which is required for `%union`.
