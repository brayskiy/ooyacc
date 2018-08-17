#ifndef INCLUDED_LR0
#define INCLUDED_LR0

#include "defs.h"
#include "closure.h"

class LR0
{

public:

    LR0() :
        kernel_base(0),
        kernel_end(0),
        kernel_items(0),
        last_shift(0),
        last_reduction(0)
    {}


    void  lr0(LRData& ld);

private:

    void  allocate_itemsets(void);
    void  allocate_storage(void);
    void  append_states(void);
    void  free_storage(void);
    void  generate_states(void);
    int   get_state(int symbol);
    void  initialize_states(void);
    void  new_itemsets(void);
    core* new_state(int symbol);
    void  show_cores(void);
    void  show_ritems(void);
    void  show_rrhs(void);
    void  show_shifts(void);
    void  save_shifts(void);
    void  save_reductions(void);
    void  set_derives(void);
    void  free_derives(void);
    void  set_nullable(void);
    void  free_nullable(void );

private:

    int         nshifts;
    short*      shift_symbol;

    short*      redset;
    short*      shiftset;

    short**     kernel_base;
    short**     kernel_end;
    short*      kernel_items;

    core**      state_set;
    core*       this_state;
    core*       last_state;

    int         nstates;
    core*       first_state;
    shifts*     first_shift;
    reductions* first_reduction;

    shifts*     last_shift;
    reductions* last_reduction;

    Closure     cl;

};

#endif // INCLUDED_LR0
