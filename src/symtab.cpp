#include "defs.h"
#include "symtab.h"


bucket** Symtab::symbol_table = 0;
bucket*  Symtab::first_symbol = 0;
bucket*  Symtab::last_symbol  = 0;


int Symtab::hash(char* name)
{
    assert(name && *name);
    char* s = name;
    int   k = *s;
    int   c;
    while ((c = *++s))
    {
	k = (31 * k + c) & (TABLE_SIZE - 1);
    }
    return (k);
}


bucket* Symtab::make_bucket(char* name)
{
    register bucket *bp;

    assert(name);
    bp = (bucket *)MALLOC(sizeof(bucket));
    if (bp == 0)
    {
        no_space();
    }
    bp->link = 0;
    bp->next = 0;
    bp->name = (char *)MALLOC(strlen(name) + 1);
    if (bp->name == 0)
    {
        no_space();
    }
    bp->tag = 0;
    bp->value = UNDEFINED;
    bp->index = 0;
    bp->prec = 0;
    bp->classic = UNKNOWN;
    bp->assoc = TOKEN;

    if (bp->name == 0)
    {
        no_space();
    }
    strcpy(bp->name, name);

    return (bp);
}


bucket* Symtab::lookup(char* name)
{
    bucket** bpp = symbol_table + hash(name);
    bucket*  bp  = *bpp;

    while (bp)
    {
	if (strcmp(name, bp->name) == 0)
        {
            return (bp);
        }
	bpp = &bp->link;
	bp  = *bpp;
    }

    *bpp = bp = make_bucket(name);
    last_symbol->next = bp;
    last_symbol = bp;

    return (bp);
}


void Symtab::create_symbol_table(void)
{
    symbol_table = (bucket **)MALLOC(TABLE_SIZE * sizeof(bucket *));
    if (symbol_table == 0) no_space();
    for (int i = 0; i < TABLE_SIZE; i++)
    {
	symbol_table[i] = 0;
    }
    bucket* bp   = make_bucket((char *)"error");
    bp->index    = 1;
    bp->classic  = TERM;

    first_symbol = bp;
    last_symbol  = bp;
    symbol_table[hash((char *)"error")] = bp;
}


void Symtab::free_symbol_table(void)
{
    FREE(symbol_table);
    symbol_table = 0;
}


void Symtab::free_symbols(void)
{
    bucket* q = 0;
    for (bucket* p = first_symbol; p; p = q)
    {
	q = p->next;
	FREE(p);
    }
}
