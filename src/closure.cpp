#include "closure.h"


short*    itemset;
short*    itemsetend;
unsigned* ruleset;


void Closure::set_EFF(void)
{
    register unsigned *row;
    register int symbol;
    register short *sp;
    register int rowsize;
    register int i;
    register int rule;

    rowsize = WORDSIZE(nvars);
    EFF     = NEW2(nvars * rowsize, unsigned);

    row = EFF;
    for (i = start_symbol; i < nsyms; i++)
    {
	sp = derives[i];
	for (rule = *sp; rule > 0; rule = *++sp)
	{
	    symbol = ritem[rrhs[rule]];
	    if (ISVAR(symbol))
	    {
		symbol -= start_symbol;
		SETBIT(row, symbol);
	    }
	}
	row += rowsize;
    }

    reflexive_transitive_closure(EFF, nvars);

#ifdef	DEBUG
    print_EFF();
#endif
}


void Closure::set_first_derives(void)
{
    register unsigned *rrow;
    register unsigned *vrow;
    register int j;
    register unsigned k;
    register unsigned cword = 0;
    register short *rp;

    int rule;
    int rulesetsize;
    int varsetsize;

    rulesetsize = WORDSIZE(nrules);
    varsetsize = WORDSIZE(nvars);
    first_derives = NEW2(nvars * rulesetsize, unsigned) - ntokens * rulesetsize;

    set_EFF();

    rrow = first_derives + ntokens * rulesetsize;
    for (int i = start_symbol; i < nsyms; i++)
    {
	vrow = EFF + ((i - ntokens) * varsetsize);
	k = BITS_PER_WORD;
	for (j = start_symbol; j < nsyms; k++, j++)
	{
	    if (k >= BITS_PER_WORD)
	    {
		cword = *vrow++;
		k = 0;
	    }

	    if (cword & (1 << k))
	    {
		rp = derives[j];
		while ((rule = *rp++) >= 0)
		{
		    SETBIT(rrow, rule);
		}
	    }
	}

	vrow += varsetsize;
	rrow += rulesetsize;
    }

#ifdef	DEBUG
    print_first_derives();
#endif

    FREE(EFF);
}


void Closure::closure(short* nucleus, int n)
{
    register int ruleno;
    register unsigned word;
    register unsigned i;
    register short *csp;
    register unsigned *dsp;
    register unsigned *rsp;
    register int rulesetsize;

    short *csend;
    unsigned *rsend;
    int symbol;
    int itemno;

    rulesetsize = WORDSIZE(nrules);
    rsp = ruleset;
    rsend = ruleset + rulesetsize;
    for (rsp = ruleset; rsp < rsend; rsp++)
	*rsp = 0;

    csend = nucleus + n;
    for (csp = nucleus; csp < csend; ++csp)
    {
	symbol = ritem[*csp];
	if (ISVAR(symbol))
	{
	    dsp = first_derives + symbol * rulesetsize;
	    rsp = ruleset;
	    while (rsp < rsend)
		*rsp++ |= *dsp++;
	}
    }

    ruleno = 0;
    itemsetend = itemset;
    csp = nucleus;
    for (rsp = ruleset; rsp < rsend; ++rsp)
    {
	word = *rsp;
	if (word)
	{
	    for (i = 0; i < BITS_PER_WORD; ++i)
	    {
		if (word & (1 << i))
		{
		    itemno = rrhs[ruleno+i];
		    while (csp < csend && *csp < itemno)
			*itemsetend++ = *csp++;
		    *itemsetend++ = itemno;
		    while (csp < csend && *csp == itemno)
			++csp;
		}
	    }
	}
	ruleno += BITS_PER_WORD;
    }

    while (csp < csend)
	*itemsetend++ = *csp++;

#ifdef	DEBUG
  print_closure(n);
#endif
}



void Closure::finalize_closure(void)
{
  FREE(itemset);
  FREE(ruleset);
  FREE(first_derives + ntokens * WORDSIZE(nrules));
}


void Closure::transitive_closure(unsigned* R, int n)
{
    register int rowsize;
    register unsigned i;
    register unsigned *rowj;
    register unsigned *rp;
    register unsigned *rend;
    register unsigned *ccol;
    register unsigned *relend;
    register unsigned *cword;
    register unsigned *rowi;

    rowsize = WORDSIZE(n);
    relend = R + n*rowsize;

    cword = R;
    i = 0;
    rowi = R;
    while (rowi < relend)
    {
	ccol = cword;
	rowj = R;

	while (rowj < relend)
	{
	    if (*ccol & (1 << i))
	    {
		rp = rowi;
		rend = rowj + rowsize;
		while (rowj < rend)
		    *rowj++ |= *rp++;
	    }
	    else
	    {
		rowj += rowsize;
	    }

	    ccol += rowsize;
	}

	if (++i >= BITS_PER_WORD)
	{
	    i = 0;
	    cword++;
	}

	rowi += rowsize;
    }
}


void Closure::reflexive_transitive_closure(unsigned* R, int n)
{
    register int rowsize;
    register unsigned i;
    register unsigned *rp;
    register unsigned *relend;

    transitive_closure(R, n);

    rowsize = WORDSIZE(n);
    relend = R + n*rowsize;

    i = 0;
    rp = R;
    while (rp < relend)
    {
	*rp |= (1 << i);
	if (++i >= BITS_PER_WORD)
	{
	    i = 0;
	    rp++;
	}

	rp += rowsize;
    }
}


#ifdef	DEBUG


void Closure::print_closure(int n)
{
  register short *isp;

  printf("\n\nn = %d\n\n", n);
  for (isp = itemset; isp < itemsetend; isp++)
    printf("   %d\n", *isp);
}


void Closure::print_EFF(void)
{
    register int i, j;
    register unsigned *rowp;
    register unsigned word;
    register unsigned k;

    printf("\n\nEpsilon Free Firsts\n");

    for (i = start_symbol; i < nsyms; i++)
    {
	printf("\n%s", symbol_name[i]);
	rowp = EFF + ((i - start_symbol) * WORDSIZE(nvars));
	word = *rowp++;

	k = BITS_PER_WORD;
	for (j = 0; j < nvars; k++, j++)
	{
	    if (k >= BITS_PER_WORD)
	    {
		word = *rowp++;
		k = 0;
	    }

	    if (word & (1 << k))
		printf("  %s", symbol_name[start_symbol + j]);
	}
    }
}


void Closure::print_first_derives(void)
{
    register int i;
    register int j;
    register unsigned *rp;
    register unsigned cword;
    register unsigned k;

    printf("\n\n\nFirst Derives\n");

    for (i = start_symbol; i < nsyms; i++)
    {
	printf("\n%s derives\n", symbol_name[i]);
	rp = first_derives + i * WORDSIZE(nrules);
	k = BITS_PER_WORD;
	for (j = 0; j <= nrules; k++, j++)
        {
	  if (k >= BITS_PER_WORD)
	  {
	      cword = *rp++;
	      k = 0;
	  }

	  if (cword & (1 << k))
	    printf("   %d\n", j);
	}
    }

  fflush(stdout);
}


#endif
