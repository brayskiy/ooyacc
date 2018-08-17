#ifndef INCLUDED_OUTPUT
#define INCLUDED_OUTPUT


#include "defs.h"


class Output
{

public:

    Output()  {}
    ~Output() {}

    void output(const OutputData& odp, const LRData& ldp, const LalrData& lap);

private:

    void output_prefix(void);
    void output_rule_data(void);
    void output_yydefred(void);
    void output_actions(void);
    void token_actions(void);
    void goto_actions(void);
    int  default_goto(int symbol);
    void save_column(int symbol, int default_state);
    void sort_actions(void);
    void pack_table(void);
    int  matching_vector(int vector);
    int  pack_vector(int vector);
    void output_base(void);
    void output_table(void);
    void output_check(void);
    int  is_C_identifier(char* name);
    void write_tokens(void);
    void output_defines(void);
    void output_stored_text(void);
    void output_debug(void);
    void output_stype(void);
    void output_trailing_text(void);
    void output_semantic_actions(void);
    void free_itemsets(void);
    void free_shifts(void);
    void free_reductions(void);

 private:

    int      nvectors;
    int      nentries;
    short**  froms;
    short**  tos;
    short*   tally;
    short*   width;
    short*   state_count;
    short*   order;
    short*   base;
    short*   pos;
    int      maxtable;
    short*   table;
    short*   check;
    int      lowzero;
    int      high;

    static const char tables[];
    static const char header[];
    static const char body[];
    static const char trailer[];

    OutputData od;
    LRData     ld;
    LalrData   la;

};


#endif //  INCLUDED_OUTPUT
