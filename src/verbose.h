#ifndef INCLUDED_VERBOSE
#define INCLUDED_VERBOSE


#include "defs.h"


class Verbose
{

public:

    void verbose(const VerboseData& vdp, 
                 const LRData& ldp, 
                 const LalrData& lap);

private:

    void log_unused(void);
    void log_conflicts(void);
    void print_state(int state);
    void print_conflicts(int state);
    void print_core(int state);
    void print_nulls(int state);
    void print_actions(int stateno);
    void print_shifts(register action* p);
    void print_reductions(register action* p, int defred);
    void print_gotos(int stateno);

private:

    short*      null_rules;
    VerboseData vd;
    int         nstates;
    LalrData    la;


};

#endif // INCLUDED_VERBOSE
