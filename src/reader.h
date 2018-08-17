#ifndef INCLUDED_READER
#define INCLUDED_READER

class Reader
{

public:

    Reader() :
        tagmax(0), 
        tag_table(0),
        saw_eof(0),
        prec(0)
    { }

    ~Reader() {}

    void reader(void);

private:

    void    cachec(int c);
    void    get_line(void);
    char*   dup_line(void);
    void    skip_comment(void);
    int     nextc(void);
    int     keyword(void);
    void    copy_ident(void);
    void    copy_text(void);
    void    copy_union(void);
    int     hexval(int c);
    bucket* get_literal(void);
    int     is_reserved(char* name);
    bucket* get_name(void);
    int     get_number(void);
    char*   get_tag(void);
    void    declare_tokens(int assoc);
    void    declare_types(void);
    void    declare_start(void);
    void    read_declarations(void);
    void    initialize_grammar(void);
    void    expand_items(void);
    void    expand_rules(void);
    void    advance_to_start(void);
    void    start_rule(register bucket* bp, int s_lineno);
    void    end_rule(void);
    void    insert_empty_rule(void);
    void    copy_action(void);
    void    add_symbol(void);
    int     mark_symbol(void);
    void    read_grammar(void);
    void    free_tags(void);
    void    pack_names(void);
    void    check_symbols(void);
    void    pack_symbols(void);
    void    pack_grammar(void);
    void    print_grammar(void);

public:

   static const char line_format[];

private:

    char*    cache;
    int      cinc;
    int      cache_size;

    int      tagmax;
    char**   tag_table;
    
    char     saw_eof;
    int      linesize;

    int      prec;
    int      gensym;
    char     last_was_action;
    
    int      maxitems;
    bucket** pitem;

    int      maxrules;
    bucket** plhs;

    int      name_pool_size;
    char*    name_pool;

    static const char banner[];

};

#endif // INCLUDED_READER
