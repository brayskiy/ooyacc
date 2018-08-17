#ifndef INCLUDED_CLOSURE
#define INCLUDED_CLOSURE

#include "defs.h"

class Closure
{

public:

   void set_first_derives(void);
   void closure(short* nucleus, int n);
   void finalize_closure(void);

private:

    void set_EFF(void);
   void transitive_closure(unsigned* R, int n);
    void reflexive_transitive_closure(unsigned* R, int n);

#ifdef DEBUG

    void print_closure(int n);
    void print_EFF(void);
    void print_first_derives(void);

#endif

private:

    unsigned* first_derives;
    unsigned* EFF;


};


#endif // INCLUDED_CLOSURE
