#ifndef INCLUDED_SYMTAB
#define INCLUDED_SYMTAB

class Symtab
{
    // TABLE_SIZE is the number of entries in the symbol table.
    // TABLE_SIZE must be a power of two.
    enum Symtab_Const
    {
        TABLE_SIZE = 1024
    };


public:

    static int     hash(char* name);
    static bucket* make_bucket(char* name);
    static bucket* lookup(char* name);
    static void    create_symbol_table(void);
    static void    free_symbol_table(void);
    static void    free_symbols(void);

public:

    static bucket* first_symbol;
    static bucket* last_symbol;

private:

    static bucket** symbol_table;

};

#endif // INCLUDED_SYMTAB
