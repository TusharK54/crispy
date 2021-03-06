%{
  open Ast
  open Printf
  open Lexing

  let remove_quotes s =
    String.sub s 1 (String.length s - 2)

  let t_fun_factory ts =

    let rec factory acc ts =
      match acc with
      | t::[] ->
        T_fun(acc, t)
      | t::z ->
        factory (t::acc) z
    in factory [] ts

%}

%token UNIT
%token <int> INT
%token <bool> BOOL
%token <string> STR ID
%token T_INT T_BOOL T_STR T_FN
%token LPAREN RPAREN LSQUARE RSQUARE LCURLY RCURLY
%token ADD SUB MUL DIV EXP MOD
%token EQ NE GT GE LT LE NOT AND OR
%token COMMA DOT QUOTE DQUOTE COLON

%token ASSIGN
%token SEQ
%token IF ELSE WHILE
%token ASSERT ASSERTFAIL
%token EOF

/* precedence rules */
%right ASSIGN
%right OR
%right AND
%left EQ NE GT GE LT LE
%right COMMA
%left ADD SUB
%left MUL DIV MOD
%left EXP
%right NOT

%type <Ast.exp> program
%start program

%%
program: seq EOF ;                      { $1 }


/* sequence expressions */
seq:
  | exp                                 { $1 }
  | exp SEQ                             { $1 }
  | exp SEQ seq                         { Seq($1, $3) }
  | block_exp                           { $1 }
  | block_exp seq                       { Seq($1, $2) }
  ;

block_seq:  /* blocks that are not followed by a SEQ */
  | block                               { $1 }
  ;

block:      /* blocks that must be followed by a SEQ */
  | LCURLY seq RCURLY                   { $2 }

/* expressions */
block_exp:
  | IF exp block_seq ELSE block_seq     { If($2, $3, $5) }
  | WHILE exp block_seq                 { Unit }

exp:
  | v                                   { $1 }
  | bop                                 { $1 }
  | uop                                 { $1 }
  | assign                              { $1 }
  | slice                               { $1 } 
  | exp LSQUARE exp RSQUARE             { Proj($1, $3) }
  ;

slice:
  | exp LSQUARE exp COLON exp RSQUARE   { Slice($1, $3, $5) }
  | exp LSQUARE exp COLON RSQUARE       { Slice($1, $3, Nop) }
  | exp LSQUARE COLON exp RSQUARE       { Slice($1, Nop, $4) }
  | exp LSQUARE COLON RSQUARE           { Slice($1, Nop, Nop) }
  ;

assign:
  | var ASSIGN exp                      { Assign($1, $3) }
  | varlist ASSIGN explist              { AssignTuple($1, $3) } 
  ;

uop:
  | NOT exp                             { Uop(Not, $2) }
  | ASSERT exp                          { Uop(Assert, $2) }
  | ASSERTFAIL exp                      { Uop(AssertFail, $2) }
  ;

bop:
  | exp ADD exp                         { Bop(Add, $1, $3) }
  | exp SUB exp                         { Bop(Sub, $1, $3) }
  | exp MUL exp                         { Bop(Mul, $1, $3) }
  | exp DIV exp                         { Bop(Div, $1, $3) }
  | exp EXP exp                         { Bop(Exp, $1, $3) }
  | exp MOD exp                         { Bop(Mod, $1, $3) }
  | exp EQ exp                          { Bop(Eq, $1, $3) }
  | exp NE exp                          { Bop(Ne, $1, $3) }
  | exp GT exp                          { Bop(Gt, $1, $3) }
  | exp GE exp                          { Bop(Ge, $1, $3) }
  | exp LT exp                          { Bop(Lt, $1, $3) }
  | exp LE exp                          { Bop(Le, $1, $3) }
  | exp AND exp                         { Bop(And, $1, $3) }
  | exp OR exp                          { Bop(Or, $1, $3) }
  ;

/* comma-separated expressions */

explist:
  | exp                                 { [$1] }
  | exp COMMA explist                   { $1::$3 }

varlist: 
  | var                                 { [$1] }
  | var COMMA varlist                   { $1::$3 }

arglist: /*
  | var                                 { [($1, T_any)] }
  | var COMMA arglist                   { ($1, T_any)::$3 } */
  | var COLON typ                       { [($1, $3)] }
  | var COLON typ COMMA arglist         { ($1, $3)::$5 }
  ;

/* values */
v:
  | var                                 { Var($1) }
  | lit                                 { $1 }
  | LPAREN explist RPAREN               { Tuple($2) }
  | LPAREN arglist RPAREN T_FN block    { Fn($2, $5) }
  | exp LPAREN explist RPAREN           { App($1, $3) }
  | LPAREN seq RPAREN                   { $2 }
  ;

var:
  | ID                                  { $1 }
  ;

lit:
  | UNIT                                { Unit }
  | INT                                 { Int($1) }
  | SUB INT                             { Int(-1 * $2) }
  | BOOL                                { Bool($1) }
  | STR                                 { Str(remove_quotes($1)) }
  ;


/* types */
typ:
  | t_base                              { $1 }
  | t_function                          { $1 }
  | LPAREN typlist RPAREN               { T_product($2) }
  | LPAREN typ RPAREN                   { $2 }
  ;

t_base:
  | T_INT                               { T_int }
  | T_BOOL                              { T_bool }
  | T_STR                               { T_str }

t_function:
  | typ T_FN typ                        { T_fun([$1], $3) } 
  ;

typlist:
  | typ                                 { [$1] }
  | typ COMMA typlist                   { $1::$3 }