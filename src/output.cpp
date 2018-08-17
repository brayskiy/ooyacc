#include "output.h"
#include "reader.h"


void Output::output(const OutputData& odp, 
                    const LRData& ldp, 
                    const LalrData& lap)
{
    memmove(&od, &odp, sizeof(OutputData));
    memmove(&ld, &ldp, sizeof(LRData));
    memmove(&la, &lap, sizeof(LalrData));

    char buf[64 * 1024];

    free_itemsets();
    free_shifts();
    free_reductions();
    output_prefix();
    //output_stored_text();
    output_defines();
    output_rule_data();
    output_yydefred();
    output_actions();
    output_debug();
    output_stype();

    if (rflag)
    {
        fprintf(code_file, "%s", tables);
    }
    fprintf(code_file, "%s", header);
    //output_trailing_text();
    sprintf(buf, body, file_prefix, file_prefix, file_prefix);
    fprintf(code_file, "%s", buf);
    output_semantic_actions();
    sprintf(buf, trailer, file_prefix);
    fprintf(code_file, "%s", buf);
}


void Output::output_prefix(void)
{
    if (symbol_prefix == NULL)
    {
	symbol_prefix = (char *)"yy";
    }
    else
    {
	++outline;
	fprintf(code_file, "#define yylhs %slhs\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yylen %slen\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yydefred %sdefred\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yydgoto %sdgoto\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yysindex %ssindex\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yyrindex %srindex\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yygindex %sgindex\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yytable %stable\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yycheck %scheck\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yyname %sname\n", symbol_prefix);
	++outline;
	fprintf(code_file, "#define yyrule %srule\n", symbol_prefix);

    }
    ++outline;
    fprintf(code_file, "#define YYPREFIX \"yy\"\n\n" );
}


void Output::output_rule_data(void)
{
    register int i;
    register int j;

  
    fprintf(output_file, "\nstatic const short %slhs[] = \n{%58d,",
            "yy", symbol_value[start_symbol]);

    j = 10;
    for (i = 3; i < nrules; i++)
    {
	if (j >= 10)
	{
	    if (!rflag) ++outline;
	    putc('\n', output_file);
	    j = 1;
	}
        else
	    ++j;

        fprintf(output_file, "%5d,", symbol_value[rlhs[i]]);
    }
    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\n");


    fprintf(output_file, "\nstatic const short %slen[] = \n{%58d,",
            "yy", 2);

    j = 10;
    for (i = 3; i < nrules; i++)
    {
	if (j >= 10)
	{
	    if (!rflag) ++outline;
	    putc('\n', output_file);
	    j = 1;
	}
	else
	  j++;

        fprintf(output_file, "%5d,", rrhs[i + 1] - rrhs[i] - 1);
    }
    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\n");
}


void Output::output_yydefred(void)
{
    register int i, j;

    fprintf(output_file, "\nstatic const short %sdefred[] = \n{%58d,",
            "yy", (od.defred[0] ? od.defred[0] - 2 : 0));

    j = 10;
    for (i = 1; i < ld.nstates; i++)
    {
	if (j < 10)
	    ++j;
	else
	{
	    if (!rflag) ++outline;
	    putc('\n', output_file);
	    j = 1;
	}

	fprintf(output_file, "%5d,", (od.defred[i] ? od.defred[i] - 2 : 0));
    }

    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\n");
}


void Output::output_actions(void)
{
    nvectors = 2 * ld.nstates + nvars;

    froms = NEW2(nvectors, short*);
    tos   = NEW2(nvectors, short*);
    tally = NEW2(nvectors, short);
    width = NEW2(nvectors, short);

    token_actions();
    FREE(la.lookaheads);
    FREE(la.LA);
    FREE(la.LAruleno);
    FREE(la.accessing_symbol);

    goto_actions();
    FREE(la.goto_map + ntokens);
    FREE(la.from_state);
    FREE(la.to_state);

    sort_actions();
    pack_table();
    output_base();
    output_table();
    output_check();
}


void Output::token_actions(void)
{
    register int i, j;
    register int shiftcount, reducecount;
    register int max, min;
    register short *actionrow, *r, *s;
    register action *p;

    actionrow = NEW2(2*ntokens, short);
    for (i = 0; i < ld.nstates; ++i)
    {
	if (od.parser[i])
	{
	    for (j = 0; j < 2 * ntokens; ++j)
	    {
		actionrow[j] = 0;
	    }

	    shiftcount = 0;
	    reducecount = 0;
	    for (p = od.parser[i]; p; p = p->next)
	    {
		if (p->suppressed == 0)
		{
		    if (p->action_code == SHIFT)
		    {
			++shiftcount;
			actionrow[p->symbol] = p->number;
		    }
		    else if (p->action_code == REDUCE && p->number != od.defred[i])
		    {
			++reducecount;
			actionrow[p->symbol + ntokens] = p->number;
		    }
		}
	    }

	    tally[i] = shiftcount;
	    tally[ld.nstates + i] = reducecount;
	    width[i] = 0;
	    width[ld.nstates + i] = 0;
	    if (shiftcount > 0)
	    {
		froms[i] = r = NEW2(shiftcount, short);
		tos[i] = s = NEW2(shiftcount, short);
		min = MAXSHORT;
		max = 0;
		for (j = 0; j < ntokens; ++j)
		{
		    if (actionrow[j])
		    {
			if (min > symbol_value[j])
			    min = symbol_value[j];
			if (max < symbol_value[j])
			    max = symbol_value[j];
			*r++ = symbol_value[j];
			*s++ = actionrow[j];
		    }
		}
		width[i] = max - min + 1;
	    }
	    if (reducecount > 0)
	    {
		froms[ld.nstates + i] = r = NEW2(reducecount, short);
		tos[ld.nstates + i] = s = NEW2(reducecount, short);
		min = MAXSHORT;
		max = 0;
		for (j = 0; j < ntokens; ++j)
		{
		    if (actionrow[ntokens + j])
		    {
			if (min > symbol_value[j])
			    min = symbol_value[j];
			if (max < symbol_value[j])
			    max = symbol_value[j];
			*r++ = symbol_value[j];
			*s++ = actionrow[ntokens+j] - 2;
		    }
		}
		width[ld.nstates + i] = max - min + 1;
	    }
	}
    }
    FREE(actionrow);
}


void Output::goto_actions(void)
{
    register int i, j, k;

    state_count = NEW2(ld.nstates, short);

    k = default_goto(start_symbol + 1);
    fprintf(output_file, "\nstatic const short %sdgoto[] = \n{%22d,",
            "yy", k);
    save_column(start_symbol + 1, k);

    j = 10;
    for (i = start_symbol + 2; i < nsyms; i++)
    {
	if (j >= 10)
	{
	    if (!rflag) ++outline;
	    putc('\n', output_file);
	    j = 1;
	}
	else
	    ++j;

	k = default_goto(i);
	fprintf(output_file, "%5d,", k);
	save_column(i, k);
    }

    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\n");
    FREE(state_count);
}


int Output::default_goto(int symbol)
{
    register int i;
    register int m;
    register int n;
    register int default_state;
    register int max;

    m = la.goto_map[symbol];
    n = la.goto_map[symbol + 1];

    if (m == n) return (0);

    for (i = 0; i < ld.nstates; i++)
	state_count[i] = 0;

    for (i = m; i < n; i++)
	state_count[la.to_state[i]]++;

    max = 0;
    default_state = 0;
    for (i = 0; i < ld.nstates; i++)
    {
	if (state_count[i] > max)
	{
	    max = state_count[i];
	    default_state = i;
	}
    }

    return (default_state);
}



void Output::save_column(int symbol, int default_state)
{
    register int i;
    register int m;
    register int n;
    register short *sp;
    register short *sp1;
    register short *sp2;
    register int count;
    register int symno;

    m = la.goto_map[symbol];
    n = la.goto_map[symbol + 1];

    count = 0;
    for (i = m; i < n; i++)
    {
	if (la.to_state[i] != default_state)
	    ++count;
    }
    if (count == 0) return;

    symno = symbol_value[symbol] + 2 * ld.nstates;

    froms[symno] = sp1 = sp = NEW2(count, short);
    tos[symno] = sp2 = NEW2(count, short);

    for (i = m; i < n; i++)
    {
	if (la.to_state[i] != default_state)
	{
	    *sp1++ = la.from_state[i];
	    *sp2++ = la.to_state[i];
	}
    }

    tally[symno] = count;
    width[symno] = sp1[-1] - sp[0] + 1;
}


void Output::sort_actions(void)
{
  register int i;
  register int j;
  register int k;
  register int t;
  register int w;

  order = NEW2(nvectors, short);
  nentries = 0;

  for (i = 0; i < nvectors; i++)
    {
      if (tally[i] > 0)
	{
	  t = tally[i];
	  w = width[i];
	  j = nentries - 1;

	  while (j >= 0 && (width[order[j]] < w))
	    j--;

	  while (j >= 0 && (width[order[j]] == w) && (tally[order[j]] < t))
	    j--;

	  for (k = nentries - 1; k > j; k--)
	    order[k + 1] = order[k];

	  order[j + 1] = i;
	  nentries++;
	}
    }
}


void Output::pack_table(void)
{
    register int i;
    register int place;
    register int state;

    base = NEW2(nvectors, short);
    pos = NEW2(nentries, short);

    maxtable = 1000;
    table = NEW2(maxtable, short);
    check = NEW2(maxtable, short);

    lowzero = 0;
    high = 0;

    for (i = 0; i < maxtable; i++)
	check[i] = -1;

    for (i = 0; i < nentries; i++)
    {
	state = matching_vector(i);

	if (state < 0)
	    place = pack_vector(i);
	else
	    place = base[state];

	pos[i] = place;
	base[order[i]] = place;
    }

    for (i = 0; i < nvectors; i++)
    {
	if (froms[i])
	    FREE(froms[i]);
	if (tos[i])
	    FREE(tos[i]);
    }

    FREE(froms);
    FREE(tos);
    FREE(pos);
}


/*  The function matching_vector determines if the vector specified by	*/
/*  the input parameter matches a previously considered	vector.  The	*/
/*  test at the start of the function checks if the vector represents	*/
/*  a row of shifts over terminal symbols or a row of reductions, or a	*/
/*  column of shifts over a nonterminal symbol.  Berkeley Yacc does not	*/
/*  check if a column of shifts over a nonterminal symbols matches a	*/
/*  previously considered vector.  Because of the nature of LR parsing	*/
/*  tables, no two columns can match.  Therefore, the only possible	*/
/*  match would be between a row and a column.  Such matches are	*/
/*  unlikely.  Therefore, to save time, no attempt is made to see if a	*/
/*  column matches a previously considered vector.			*/
/*									*/
/*  Matching_vector is poorly designed.  The test could easily be made	*/
/*  faster.  Also, it depends on the vectors being in a specific	*/
/*  order.								*/

int Output::matching_vector(int vector)
{
    register int i;
    register int j;
    register int k;
    register int t;
    register int w;
    register int match;
    register int prev;

    i = order[vector];
    if (i >= 2 * ld.nstates)
	return (-1);

    t = tally[i];
    w = width[i];

    for (prev = vector - 1; prev >= 0; prev--)
    {
	j = order[prev];
	if (width[j] != w || tally[j] != t)
	    return (-1);

	match = 1;
	for (k = 0; match && k < t; k++)
	{
	    if (tos[j][k] != tos[i][k] || froms[j][k] != froms[i][k])
		match = 0;
	}

	if (match)
	    return (j);
    }

    return (-1);
}


int Output::pack_vector(int vector)
{
    register int i, j, k, l;
    register int t;
    register int loc;
    register int ok;
    register short *from;
    register short *to;
    int newmax;

    i = order[vector];
    t = tally[i];
    assert(t);

    from = froms[i];
    to = tos[i];

    j = lowzero - from[0];
    for (k = 1; k < t; ++k)
	if (lowzero - from[k] > j)
	    j = lowzero - from[k];
    for (;; ++j)
    {
	if (j == 0)
	    continue;
	ok = 1;
	for (k = 0; ok && k < t; k++)
	{
	    loc = j + from[k];
	    if (loc >= maxtable)
	    {
		if (loc >= MAXTABLE)
		    fatal("maximum table size exceeded");

		newmax = maxtable;

		do 
                {
                    newmax += 200;
                } while (newmax <= loc);

		table = (short *)REALLOC(table, newmax * sizeof(short));
		if (table == 0) no_space();
		check = (short *)REALLOC(check, newmax * sizeof(short));
		if (check == 0) no_space();
		for (l = maxtable; l < newmax; ++l)
		{
		    table[l] = 0;
		    check[l] = -1;
		}
		maxtable = newmax;
	    }

	    if (check[loc] != -1)
		ok = 0;
	}
	for (k = 0; ok && k < vector; k++)
	{
	    if (pos[k] == j)
		ok = 0;
	}
	if (ok)
	{
	    for (k = 0; k < t; k++)
	    {
		loc = j + from[k];
		table[loc] = to[k];
		check[loc] = from[k];
		if (loc > high) high = loc;
	    }

	    while (check[lowzero] != -1)
		++lowzero;

	    return (j);
	}
    }
}



void Output::output_base(void)
{
    register int i, j;

    fprintf(output_file, "static const short %ssindex[] = \n{%58d,",
            "yy", base[0]);

    j = 10;
    for (i = 1; i < ld.nstates; i++)
    {
	if (j >= 10)
	{
	    if (!rflag) ++outline;
	    putc('\n', output_file);
	    j = 1;
	}
	else
	    ++j;

	fprintf(output_file, "%5d,", base[i]);
    }

    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\nstatic const short %srindex[] = \n{%58d,",
            "yy", base[ld.nstates]);

    j = 10;
    for (i = ld.nstates + 1; i < 2 * ld.nstates; i++)
    {
	if (j >= 10)
	{
	    if (!rflag) ++outline;
	    putc('\n', output_file);
	    j = 1;
	}
	else
	    ++j;

	fprintf(output_file, "%5d,", base[i]);
    }

    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\nstatic const short %sgindex[] = \n{%22d,",
            "yy", base[2 * ld.nstates]);

    j = 10;
    for (i = 2 * ld.nstates + 1; i < nvectors - 1; i++)
    {
	if (j >= 10)
	{
	    if (!rflag) ++outline;
	    putc('\n', output_file);
	    j = 1;
	}
	else
	    ++j;

	fprintf(output_file, "%5d,", base[i]);
    }

    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\n");
    FREE(base);
}



void Output::output_table(void)
{
    register int i;
    register int j;

    ++outline;
    fprintf(code_file, "\n\n#define YYTABLESIZE %d\n", high);
    fprintf(output_file, "\nstatic const short %stable[] = \n{%d,",
            "yy",table[0]);

    j = 10;
    for (i = 1; i <= high; i++)
    {
	if (j >= 10)
	{
	    if (!rflag) ++outline;
	    putc('\n', output_file);
	    j = 1;
	}
	else
	    ++j;

	fprintf(output_file, "%5d,", table[i]);
    }

    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\n");
    FREE(table);
}


void Output::output_check(void)
{
    register int i;
    register int j;

    fprintf(output_file, "\nstatic const short %scheck[] = \n{%58d,",
            "yy", check[0]);

    j = 10;
    for (i = 1; i <= high; i++)
    {
	if (j >= 10)
	{
	    if (!rflag) ++outline;
	    putc('\n', output_file);
	    j = 1;
	}
	else
	    ++j;

	fprintf(output_file, "%5d,", check[i]);
    }

    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\n");
    FREE(check);
}


int Output::is_C_identifier(char* name)
{
    register char *s;
    register int c;

    s = name;
    c = *s;
    if (c == '"')
    {
	c = *++s;
	if (!isalpha(c) && c != '_' && c != '$')
	    return (0);
	while ((c = *++s) != '"')
	{
	    if (!isalnum(c) && c != '_' && c != '$')
		return (0);
	}
	return (1);
    }

    if (!isalpha(c) && c != '_' && c != '$')
	return (0);
    while ((c = *++s))
    {
	if (!isalnum(c) && c != '_' && c != '$')
	    return (0);
    }
    return (1);
}



void Output::write_tokens(void)
{
    // Tokens.
    register char* s;
    register int   c;
    int count = 0;
    fprintf(defines_file, "\n\nenum %s_Tokens\n{\n", file_prefix);
    int i = 2;
    for (; i < ntokens; ++i)
    {
        s = symbol_name[i];
	if (is_C_identifier(s))
	{
            if (dflag)
            {
                if (count)
                { 
                    fprintf(defines_file, ",\n");
                }
                fprintf(defines_file, "\t");
                ++count;
            }
	    c = *s;
	    if (c == '"')
	    {
		while ((c = *++s) != '"')
		{
		    if (dflag) putc(c, defines_file);
		}
	    }
	    else
	    {
		do
		{
		    if (dflag) putc(c, defines_file);
		}
		while ((c = *++s));
	    }
	    if (dflag)
            {
                fprintf(defines_file, "\t\t = %d", symbol_value[i]);
            }
	}
    }
    fprintf(defines_file, "\n};\n\n");
    // End Tokens.
}



void Output::output_defines(void)
{
    register int c;
    fprintf(code_file,"\n#include \"%s.tab.h\"\n\n",file_prefix);

    fprintf(defines_file,"                       \n"                          );
    fprintf(defines_file,"#ifndef %s_OOYACC_H    \n", file_prefix             );
    fprintf(defines_file,"#define %s_OOYACC_H    \n", file_prefix             );
    fprintf(defines_file,"                       \n"                          );

    fprintf(defines_file,"#ifdef YYSTACKSIZE                      \n"         );
    fprintf(defines_file,"    #undef YYMAXDEPTH                   \n"         );
    fprintf(defines_file,"    #define YYMAXDEPTH YYSTACKSIZE      \n"         );
    fprintf(defines_file,"#else                                   \n"         );
    fprintf(defines_file,"    #ifdef YYMAXDEPTH                   \n"         );
    fprintf(defines_file,"        #define YYSTACKSIZE YYMAXDEPTH  \n"         );
    fprintf(defines_file,"    #else                               \n"         );
    fprintf(defines_file,"        #define YYSTACKSIZE 500         \n"         );
    fprintf(defines_file,"        #define YYMAXDEPTH 500          \n"         );
    fprintf(defines_file,"    #endif                              \n"         );
    fprintf(defines_file,"#endif                                  \n"         );
    fprintf(defines_file,"                                        \n"         );

    //write_tokens();

    ++outline;
    fprintf(code_file, "#define YYERRCODE %d\n", symbol_value[1]);
    if(strcmp(symbol_prefix,"yy")!=0)
      fprintf(defines_file,"#define YYSTYPE %sTYPE\n",symbol_prefix);

    // Declarations section of ".y" file
    output_stored_text();

    if (dflag && unionized)
    {
	fclose(union_file);
	union_file = fopen(union_file_name, "r");
	if (union_file == NULL) open_error(union_file_name);
	while ((c = getc(union_file)) != EOF)
	    putc(c, defines_file);
	fprintf(defines_file, " YYSTYPE;\n\n"); 
    }

    fprintf(defines_file,"                                \n"                 );
    fprintf(defines_file,"class %s                        \n", file_prefix    );
    fprintf(defines_file,"{                               \n"                 );

    write_tokens();

    fprintf(defines_file,"                                \n"                 );
    fprintf(defines_file,"public:                         \n"                 );
    fprintf(defines_file,"                                \n"                 );
    fprintf(defines_file,"    %s(void* pExtraData = 0);   \n", file_prefix    );
    fprintf(defines_file,"    int      yyparse();         \n"                 );
    fprintf(defines_file,"    YYSTYPE* getLVal();         \n"                 );
    fprintf(defines_file,"                                \n"                 );
    fprintf(defines_file,"private:                        \n"                 );
    fprintf(defines_file,"                                \n"                 );
  
    // All content of functions section will be stored in the calss.
    output_trailing_text();

    fprintf(defines_file,"                                \n"                 );
    fprintf(defines_file,"private:                        \n"                 );
    fprintf(defines_file,"                                \n"                 );
    fprintf(defines_file,"    int      yydebug;           \n"                 );
    fprintf(defines_file,"    int      yynerrs;           \n"                 );
    fprintf(defines_file,"    int      yyerrflag;         \n"                 );
    fprintf(defines_file,"    int      yychar;            \n"                 );
    fprintf(defines_file,"    short*   yyssp;             \n"                 );
    fprintf(defines_file,"    YYSTYPE* yyvsp;             \n"                 );
    fprintf(defines_file,"    YYSTYPE  yyval;             \n"                 );
    fprintf(defines_file,"    YYSTYPE  yylval;            \n"                 );
    fprintf(defines_file,"    short    yyss[YYSTACKSIZE]; \n"                 );
    fprintf(defines_file,"    YYSTYPE  yyvs[YYSTACKSIZE]; \n"                 );
    fprintf(defines_file,"    int      yym,yyn,yystate;   \n"                 );
    fprintf(defines_file,"    char*    yys;               \n"                 );
    fprintf(defines_file,"                                \n"                 );
    fprintf(defines_file,"};\n\n\n");
    fprintf(defines_file,"#endif // %s_OOYACC_H\n", file_prefix);
}


void Output::output_stored_text(void)
{
    register int c;
    register FILE *in, *out;

    fclose(text_file);
    text_file = fopen(text_file_name, "r");
    if (text_file == NULL)
	open_error(text_file_name);
    in = text_file;
    if ((c = getc(in)) == EOF)
	return;
    out = defines_file;
    if (c ==  '\n')
	++outline;
    putc(c, out);
    while ((c = getc(in)) != EOF)
    {
	if (c == '\n')
        {
	    ++outline;
        }
	putc(c, out);
    }
    if (!lflag)
    {
	fprintf(out, Reader::line_format, ++outline + 1, code_file_name);
    }
}


void Output::output_debug(void)
{
    register int i, j, k, max;
    char **symnam, *s;

    ++outline;
    fprintf(code_file, "#define YYFINAL %d\n\n", od.final_state);
    outline += 3;
    
    fprintf(code_file, "#ifndef YYDEBUG    \n"        );
    fprintf(code_file, "#define YYDEBUG %d \n", tflag );
    fprintf(code_file, "#endif             \n"        );
    fprintf(code_file, "                   \n"        );
    
    if (rflag)
    {
	fprintf(output_file, "#ifndef YYDEBUG\n#define YYDEBUG %d\n#endif\n",
		tflag);
    }

    max = 0;
    for (i = 2; i < ntokens; ++i)
    {
	if (symbol_value[i] > max)
        {
	    max = symbol_value[i];
        }
    }
    ++outline;
    fprintf(code_file, "#define YYMAXTOKEN %d\n\n", max);

    symnam = (char **)MALLOC((max+1)*sizeof(char *));
    if (symnam == 0)
    {
        no_space();
    }

    /* Note that it is  not necessary to initialize the element		*/
    /* symnam[max].							*/
    for (i = 0; i < max; ++i)
    {
	symnam[i] = 0;
    }
    for (i = ntokens - 1; i >= 2; --i)
    {
	symnam[symbol_value[i]] = symbol_name[i];
    }
    symnam[0] = (char *)"end-of-file";

    if (!rflag)
    { 
        ++outline;
    }
    fprintf(output_file, "#if YYDEBUG\n");
    fprintf(output_file, "\nstatic char *%sname[] = \n{", "yy");
    j = 80;
    for (i = 0; i <= max; ++i)
    {
	if ((s = symnam[i]))
	{
	    if (s[0] == '"')
	    {
		k = 7;
		while (*++s != '"')
		{
		    ++k;
		    if (*s == '\\')
		    {
			k += 2;
			if (*++s == '\\')
			    ++k;
		    }
		}
		j += k;
		if (j > 80)
		{
		    if (!rflag) ++outline;
		    putc('\n', output_file);
		    j = k;
		}
		fprintf(output_file, "\"\\\"");
		s = symnam[i];
		while (*++s != '"')
		{
		    if (*s == '\\')
		    {
			fprintf(output_file, "\\\\");
			if (*++s == '\\')
			    fprintf(output_file, "\\\\");
			else
			    putc(*s, output_file);
		    }
		    else
			putc(*s, output_file);
		}
		fprintf(output_file, "\\\"\",");
	    }
	    else if (s[0] == '\'')
	    {
		if (s[1] == '"')
		{
		    j += 7;
		    if (j > 80)
		    {
			if (!rflag) ++outline;
			putc('\n', output_file);
			j = 7;
		    }
		    fprintf(output_file, "\"'\\\"'\",");
		}
		else
		{
		    k = 5;
		    while (*++s != '\'')
		    {
			++k;
			if (*s == '\\')
			{
			    k += 2;
			    if (*++s == '\\')
				++k;
			}
		    }
		    j += k;
		    if (j > 80)
		    {
			if (!rflag) ++outline;
			putc('\n', output_file);
			j = k;
		    }
		    fprintf(output_file, "\"'");
		    s = symnam[i];
		    while (*++s != '\'')
		    {
			if (*s == '\\')
			{
			    fprintf(output_file, "\\\\");
			    if (*++s == '\\')
				fprintf(output_file, "\\\\");
			    else
				putc(*s, output_file);
			}
			else
			    putc(*s, output_file);
		    }
		    fprintf(output_file, "'\",");
		}
	    }
	    else
	    {
		k = strlen(s) + 3;
		j += k;
		if (j > 80)
		{
		    if (!rflag) ++outline;
		    putc('\n', output_file);
		    j = k;
		}
		putc('"', output_file);
		do { putc(*s, output_file); } while (*++s);
		fprintf(output_file, "\",");
	    }
	}
	else
	{
	    j += 2;
	    if (j > 80)
	    {
		if (!rflag) ++outline;
		putc('\n', output_file);
		j = 2;
	    }
	    fprintf(output_file, "0,");
	}
    }
    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\n");
    FREE(symnam);

    if (!rflag) ++outline;
    fprintf(output_file, "\nstatic char *%srule[] = \n{\n", "yy");
    for (i = 2; i < nrules; ++i)
    {
	fprintf(output_file, "\"%s :", symbol_name[rlhs[i]]);
	for (j = rrhs[i]; ritem[j] > 0; ++j)
	{
	    s = symbol_name[ritem[j]];
	    if (s[0] == '"')
	    {
		fprintf(output_file, " \\\"");
		while (*++s != '"')
		{
		    if (*s == '\\')
		    {
			if (s[1] == '\\')
			    fprintf(output_file, "\\\\\\\\");
			else
			    fprintf(output_file, "\\\\%c", s[1]);
			++s;
		    }
		    else
			putc(*s, output_file);
		}
		fprintf(output_file, "\\\"");
	    }
	    else if (s[0] == '\'')
	    {
		if (s[1] == '"')
		    fprintf(output_file, " '\\\"'");
		else if (s[1] == '\\')
		{
		    if (s[2] == '\\')
			fprintf(output_file, " '\\\\\\\\");
		    else
			fprintf(output_file, " '\\\\%c", s[2]);
		    s += 2;
		    while (*++s != '\'')
			putc(*s, output_file);
		    putc('\'', output_file);
		}
		else
		    fprintf(output_file, " '%c'", s[1]);
	    }
	    else
		fprintf(output_file, " %s", s);
	}
	if (!rflag) ++outline;
	fprintf(output_file, "\",\n");
    }

    if (!rflag) outline += 2;
    fprintf(output_file, "\n};\n\n#endif // YYDEBUG\n\n");
}


void Output::output_stype(void)
{
    if (!unionized && ntags == 0)
    {
	outline += 3;
	fprintf(code_file, "#ifndef YYSTYPE\ntypedef int YYSTYPE;\n#endif\n");
    }
}


void Output::output_trailing_text(void)
{
    register int c, last;
    register FILE *in, *out;

    if (line == 0)
    {
	return;
    }

    in  = input_file;
    out = defines_file;

    c = *cptr;
    if (c == '\n')
    {
	++lineno;
	if ((c = getc(in)) == EOF)
	    return;
	if (!lflag)
	{
	    ++outline;
	    fprintf(out, Reader::line_format, lineno, input_file_name);
	}
	if (c == '\n')
	    ++outline;
	putc(c, out);
	last = c;
    }
    else
    {
	if (!lflag)
	{
	    ++outline;
	    fprintf(out, Reader::line_format, lineno, input_file_name);
	}
	do { putc(c, out); } while ((c = *++cptr) != '\n');
	++outline;
	putc('\n', out);
	last = '\n';
    }

    while ((c = getc(in)) != EOF)
    {
	if (c == '\n')
	    ++outline;
	putc(c, out);
	last = c;
    }

    if (last != '\n')
    {
	++outline;
	putc('\n', out);
    }
    if (!lflag)
	fprintf(out, Reader::line_format, ++outline + 1, code_file_name);
}


void Output::output_semantic_actions(void)
{
    register int   c, last;
    register FILE* out;

    fclose(action_file);
    action_file = fopen(action_file_name, "r");
    if (action_file == NULL)
	open_error(action_file_name);

    if ((c = getc(action_file)) == EOF)
    {
	return;
    }

    out = code_file;
    last = c;
    if (c == '\n')
    {
	++outline;
    }
    putc(c, out);
    while ((c = getc(action_file)) != EOF)
    {
	if (c == '\n')
        {
	    ++outline;
        }
	putc(c, out);
	last = c;
    }

    if (last != '\n')
    {
	++outline;
	putc('\n', out);
    }

    if (!lflag)
    {
	fprintf(out, Reader::line_format, ++outline + 1, code_file_name);
    }
}


void Output::free_itemsets(void)
{
    register core *cp, *next;

    FREE(la.state_table);
    for (cp = ld.first_state; cp; cp = next)
    {
	next = cp->next;
	FREE(cp);
    }
}


void Output::free_shifts(void)
{
    register shifts *sp, *next;

    FREE(la.shift_table);
    for (sp = ld.first_shift; sp; sp = next)
    {
	next = sp->next;
	FREE(sp);
    }
}


void Output::free_reductions(void)
{
    register reductions *rp, *next;

    FREE(la.reduction_table);
    for (rp = ld.first_reduction; rp; rp = next)
    {
	next = rp->next;
	FREE(rp);
    }
}
