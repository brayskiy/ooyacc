#ifndef INCLUDED_LALR
#define INCLUDED_LALR

#include "defs.h"

class Lalr
{
    struct shorts
    {
        struct shorts* next;
        short          value;
    };

public:

    void    lalr(LalrData& la, const LRData& ldp);

 private:

    void    set_state_table(void);
    void    set_accessing_symbol(void);
    void    set_shift_table(void);
    void    set_reduction_table(void);
    void    set_maxrhs(void);
    void    initialize_LA(void);
    void    set_goto_map(void);
    int     map_goto(int state, int symbol);
    void    initialize_F(void);
    void    build_relations(void);
    void    add_lookback_edge(int stateno, int ruleno, int gotono);
    short** transpose(short** R, int n);
    void    compute_FOLLOWS(void);
    void    compute_lookaheads(void);
    void    digraph(short** relation);
    void    traverse(register int i);

private:

    int          tokensetsize;
    int          infinity;
    int          maxrhs;
    int          ngotos;
    unsigned*    F;
    short**      includes;
    shorts**     lookback;
    short**      R;
    short*       INDEX;
    short*       VERTICES;
    int          top;

    short*       accessing_symbol;
    core**       state_table;
    shifts**     shift_table;
    reductions** reduction_table;
    unsigned*    LA;
    short*       LAruleno;
    short*       lookaheads;
    short*       goto_map;
    short*       from_state;
    short*       to_state;

    LRData    ld;

};

#endif //  INCLUDED_LALR
