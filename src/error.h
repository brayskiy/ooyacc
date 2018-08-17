#ifndef INCLUDED_ERROR
#define INCLUDED_ERROR


void fatal(const char* msg);
void no_space(void);
void open_error(char* filename);
void unexpected_EOF(void);
void print_pos(char* st_line, char* st_cptr);
void syntax_error(int st_lineno, char* st_line, char* st_cptr);
void unterminated_comment(int c_lineno, char* c_line, char* c_cptr);
void unterminated_string(int s_lineno, char* s_line, char* s_cptr);
void unterminated_text(int t_lineno, char* t_line, char* t_cptr);
void unterminated_union(int u_lineno, char* u_line, char* u_cptr);
void over_unionized(char* u_cptr);
void illegal_tag(int t_lineno, char* t_line, char* t_cptr);
void illegal_character(char* c_cptr);
void used_reserved(char* s);
void tokenized_start(char* s);
void retyped_warning(char* s);
void reprec_warning(char* s);
void revalued_warning(char* s);
void terminal_start(char* s);
void restarted_warning(void);
void no_grammar(void);
void terminal_lhs(int s_lineno);
void prec_redeclared(void);
void unterminated_action(int a_lineno, char* a_line, char* a_cptr);
void dollar_warning(int a_lineno, int i);
void dollar_error(int a_lineno, char* a_line, char* a_cptr);
void untyped_lhs(void);
void untyped_rhs(int i, char* s);
void unknown_rhs(int i);
void default_action_warning(void);
void undefined_goal(char* s);
void undefined_symbol_warning(char* s);


#endif // INCLUDED_ERROR
