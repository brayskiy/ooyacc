#ifndef INCLUDED_MKPARSER
#define INCLUDED_MKPARSER

#include "defs.h"

class MakeParser
{

public:

    MakeParser() :
        defred(0),
        rules_used(0),
        SRconflicts(0),
        RRconflicts(0)
    {}

    ~MakeParser(void)
    {
        for (int i = 0; i < nstates; i++)
        {
            free_action_row(parser[i]);
        }
        FREE(parser);

        if (defred)      free(defred);
        if (rules_used)  free(rules_used);
        if (SRconflicts) free(SRconflicts);
        if (RRconflicts) free(RRconflicts);
    }

    void    make_parser(VerboseData& vd, OutputData& od, 
                        const LRData& ldp, const LalrData& lap);

private:

    action* parse_actions(register int stateno);
    action* get_shifts(int stateno);
    action* add_reductions(int stateno, register action* actions);
    action* add_reduce(register action* actions, int ruleno, int symbol);
    void    find_final_state(void);
    void    unused_rules(void);
    void    remove_conflicts(void);
    void    total_conflicts(void);
    int     sole_reduction(int stateno);
    void    defreds(void);
    void    free_action_row(register action* p);
    void    free_parser(void);

private:

    action** parser;
    short*   defred;
    short*   rules_used;
    int      SRtotal;
    int      RRtotal;
    short*   SRconflicts;
    short*   RRconflicts;
    short    nunused;
    short    final_state;

    int      SRcount;
    int      RRcount;

    int      nstates;

    LalrData la;

};

#endif // INCLUDED_MKPARSER
