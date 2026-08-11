/*
 * Generic test driver shared by every grammar in tests/cases.
 *
 * Each grammar defines its lexer (yylex) to read from stdin and its
 * semantic actions to print results to stdout, so a single driver works
 * for all of them: construct the generated parser class `y` and run it.
 */
#include "y.tab.h"

int main()
{
    y parser;
    return parser.yyparse();
}
