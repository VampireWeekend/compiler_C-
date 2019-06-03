%{
#define YYSTYPE char *
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define MAX_STACK_SIZE 105
#define MAX_ARGS_SIZE 27
#define MAX_VARS_SIZE 27
#define MAX_FUNCTIONS 100

extern FILE* yyin;
FILE *incFileName;

int ii = 0, itop = -1, istack[MAX_STACK_SIZE];
int ww = 0, wtop = -1, wstack[MAX_STACK_SIZE];
char *nowFuncName;
char *inputFileName, *outputFileName, *incFileNameString;
int nowFuncs=0, nowArgs, nowVars, nowFuncType, nowFuncReturn;
char  *nowFuncArgs[MAX_ARGS_SIZE], *nowFuncVars[MAX_VARS_SIZE], *nowFunc[MAX_FUNCTIONS];
int nowFuncArgsCount[MAX_ARGS_SIZE];
int countCallArgs=0;

#define _BEG_IF     {istack[++itop] = ++ii;}
#define _END_IF     {itop--;}
#define _i          (istack[itop])

#define _BEG_WHILE  {wstack[++wtop] = ++ww;}
#define _END_WHILE  {wtop--;}
#define _w          (wstack[wtop])

FILE * yyin;

extern int yylineno;

void yyerror(char* msg);
void my_writeFunc();
int check(char *str);

%}


%token  INTEGER
%token  IDENTIFIER
%token T_Int T_Void T_Return T_Break T_While T_If T_Else T_Le T_Ge T_Ne
%token T_Eq T_AddEq T_SubEq  T_Continue

%%

start: declaration_list


declaration_list: declaration_list func_declaration
| func_declaration
;

func_declaration: func_type_name '(' params ')' statement
								{
									if (nowFuncType==1) {
										if (nowFuncReturn==0) yyerror("return not found in function");
									}
									nowFuncArgsCount[nowFuncs] = nowArgs;
									printf("ENDFUNC@%s\n\n",nowFuncName);
									my_writeFunc();
								}
;

func_type_name: type_specifier FuncName {
	if (strcmp($1,"int")==0) {
		nowFuncType = 1;
	} else nowFuncType = 0;
}

FuncName:
Identifier     {
	nowFuncs++;
	nowFunc[nowFuncs] = nowFuncName = $1;
	nowVars=nowArgs=0;
	printf("FUNC @%s:\n", $1);
	nowFuncReturn = 0;
}
;

params: param_list
| /* empty */
;

param_list: param_type_list
| param_list ';' param_type_list
;

param_type_list: type_specifier param_id_list   { printf("\n "); }
;

param_id_list: param_id_list ',' param_id {
	if (check($3)) yyerror("duplicate parameters");
	printf(",%s",  $3);
	nowArgs++;
	nowFuncArgs[nowArgs] = $3;
}
| param_id {
	if (check($1)) yyerror("duplicate parameters");
	printf("\t%s.arg %s",  nowFuncName, $1);
	nowArgs++;
	nowFuncArgs[nowArgs] = $1;
}
;

param_id: Identifier
;

local_declarations: local_declarations var_declaration
| /* empty */
;

var_declaration: type_specifier var_decl_list ';' {
	printf("\n");
}
;

var_decl_list: var_decl_id {
	if (check($1)) yyerror("duplicate variable");
	printf("\t%s.var %s",  nowFuncName, $1);
	nowVars++;
	nowFuncVars[nowVars] = $1;
}
| var_decl_list ',' var_decl_id {
	if (check($3)) yyerror("duplicate variable");
	printf(", %s", $3);
	nowVars++;
	nowFuncVars[nowVars] = $3;
}
;

var_decl_id: Identifier
;

type_specifier: T_Int
| T_Void
;

statement_list: statement_list statement
| /* empty */
;

statement:
 expression_stmt
| compound_stmt
| selection_stmt
| iteration_stmt
| return_stmt
| break_stmt
| continue_stmt
;

compound_stmt: '{' local_declarations statement_list '}'
;

expression_stmt: expressions ';' {printf("\n");}
|';' {printf("\n");}
;

selection_stmt:
If '(' expressions ')' Then statement_list EndThen Else statement_list EndIf
| If '(' expressions ')' Then statement_list EndThen EndIf
;

If:
T_If            {  _BEG_IF;  printf("_begIf_%d:\n", _i); }
;

Then:
/* empty */     { printf("\tjz _elIf_%d\n", _i); }
;

EndThen:
/* empty */     { printf("\tjmp _endIf_%d\n_elIf_%d:\n", _i, _i); }
;

Else:
T_Else
;

EndIf:
/* empty */     { printf("_endIf_%d:\n\n", _i); _END_IF; }
;

iteration_stmt: While '(' expressions ')' Do statement_list EndWhile
;

While:
T_While
{
	_BEG_WHILE;
	printf("_begWhile_%d:\n", _w);
}
;

Do:
/* empty */     { printf("\tjz _endWhile_%d\n", _w); }
;

EndWhile:
/* empty */
{
	printf("\tjmp _begWhile_%d\n_endWhile_%d:\n\n", _w, _w);
	_END_WHILE;
}
;

break_stmt:
T_Break ';'     { printf("\tjmp _endWhile_%d\n", _w); }
;

continue_stmt:
T_Continue ';'  { printf("\tjmp _begWhile_%d\n", _w); }
;

return_stmt: T_Return ';' {
	if (nowFuncType==1) yyerror("must return something in function");
	printf("\tret\n\n");
}
| T_Return expressions ';' {
	if (nowFuncType==0) yyerror("return something not allowed in void function");
	printf("\tret ~\n\n");
	nowFuncReturn++;
}
;

expressions:
var '=' expressions
{
	printf("\tpush %s\n", $3);
	printf("\tpop %s\n", $1);
}
| var T_AddEq  expressions
{
	printf("\tpush %s\n", $3);
	printf("\tpush %s\n", $1);
	printf("\tadd\n");
	printf("\tpop %s\n", $1);
}
| var T_SubEq  expressions
{
	printf("\tpush %s\n", $3);
	printf("\tpush %s\n", $1);
	printf("\tsub\n");
	printf("\tpop %s\n", $1);
}
| expression
;

expression:
var '=' simple_expression
{
	printf("\tpop %s\n", $1);
}
| var T_AddEq  simple_expression
{
	printf("\tpush %s\n", $1);
	printf("\tadd\n");
	printf("\tpop %s\n", $1);
}
| var T_SubEq  simple_expression
{
	printf("\tpush %s\n", $1);
	printf("\tsub\n");
	printf("\tpop %s\n", $1);
}
| simple_expression
;

var: Identifier { if (!check($1)) yyerror("undefined variable"); }
;

simple_expression:
simple_expression '|' or_expression  {  printf("\tor\n"); }
| or_expression
;

or_expression:
or_expression '&' unary_rel_expression  {  printf("\tand\n"); }
| unary_rel_expression
;

unary_rel_expression: '!' unary_rel_expression   {  printf("\tnot\n"); }
| rel_expression
;

rel_expression:
add_expression T_Le add_expression { printf("\tcmple\n"); }
| add_expression T_Ge add_expression { printf("\tcmpge\n"); }
| add_expression '<' add_expression { printf("\tcmpls\n"); }
| add_expression '>' add_expression { printf("\tcmpgt\n"); }
| add_expression T_Eq add_expression { printf("\tcmpeq\n"); }
| add_expression T_Ne add_expression { printf("\tcmpne\n"); }
| add_expression
;

add_expression:
add_expression '+' term { printf("\tadd\n"); }
| add_expression '-' term { printf("\tsub\n"); }
| term
;

term:
term '*' unary_expression { printf("\tmul\n"); }
| term '/' unary_expression { printf("\tdiv\n"); }
| term '%' unary_expression { printf("\tmod\n"); }
| unary_expression
;

unary_expression:
'-' unary_expression  {   printf("\tneg\n");  }
| factor
;

factor: '(' expression ')'
| var   {   printf("\tpush %s\n",$1); }
| call
| constant {   printf("\tpush %s\n",$1); }
;

/* 常数 */
constant:
INTEGER
;

call: Identifier '(' args ')' {
	int flag=0;
	for (int i=1;i<=nowFuncs;i++) {
		if (strcmp($1,nowFunc[i])==0) flag=1; else {
			if (countCallArgs != nowFuncArgsCount[i])
				yyerror("total number of function call arguments is not right");
					//函数调用参数数量不对
		}
	}
	if (!flag) yyerror("function not defined before"); //调用的函数之前没有定义
	printf("\t$%s\n", $1);
}
;

args: arg_list
| /*empty*/  { countCallArgs = 0;}
;

/* 变量列表 */
arg_list: arg_list ',' expression { countCallArgs++;}
| expression { countCallArgs = 1;}
;

Identifier: IDENTIFIER
;

%%

int check(char *str) {
	for (int i=1;i<=nowArgs;i++) {
		if (strcmp(str,nowFuncArgs[i])==0) return 1;
	}
	for (int i=1;i<=nowVars;i++) {
		if (strcmp(str,nowFuncVars[i])==0) return 1;
	}
	return 0;
}

void yyerror(char* msg)
{
	printf("\n\n%s: line %d\n", msg, yylineno);
	exit(0);
}

void my_writeFunc() {
	fprintf(incFileName, "; ---------Now Function Is: %s ---------------\n", nowFuncName);
	fprintf(incFileName,"%%define %s.argc %d\n",  nowFuncName, nowArgs );
	fprintf(incFileName,"%%define %s.varc %d\n",  nowFuncName, nowVars );

	fprintf(incFileName,
    			"\n%%MACRO $%s 0\n\tCALL @%s\n\tADD ESP, 4*%s.argc\n\tPUSH EAX\n%%ENDMACRO\n\n",
                nowFuncName, nowFuncName, nowFuncName);

	if (nowArgs!=0) {
		fprintf(incFileName, "%%MACRO %s.arg %s.argc\n", nowFuncName, nowFuncName);
		for (int i=1;i<=nowArgs;i++) {
			fprintf(incFileName,"\t%%define %s [EBP + 8 + 4*%s.argc - 4*%d]\n", nowFuncArgs[i], nowFuncName, i);
		}
		fprintf(incFileName, "%%ENDMACRO\n\n" );
	}

	if (nowVars!=0) {
		fprintf(incFileName, "%%MACRO %s.var %s.varc\n", nowFuncName, nowFuncName);
		for (int i=1;i<=nowVars;i++) {
			fprintf(incFileName,"\t%%define %s [EBP - 4*%d]\n", nowFuncVars[i], i);
		}
		fprintf(incFileName, "\tSUB ESP, 4*%s.varc\n", nowFuncName);
		fprintf(incFileName, "%%ENDMACRO\n\n" );
	}

	fprintf(incFileName, "%%MACRO ENDFUNC@%s 0\n\tLEAVE\n\tRET\n" ,nowFuncName);
	for (int i=1;i<=nowArgs;i++) {
		fprintf(incFileName, "\t%%undef %s\n", nowFuncArgs[i]);
	}
	for (int i=1;i<=nowVars;i++) {
		fprintf(incFileName, "\t%%undef %s\n", nowFuncVars[i]);
	}
	fprintf(incFileName, "%%ENDMACRO\n\n\n");
}

int main(int argc, char *argv[])
{
	if(argc!=2) {
		printf("usage: %s filename\n", argv[0]);
		exit(0);
	}

	if( (yyin=fopen(argv[1], "r")) ==NULL )
	{
		printf("open file %s failed\n", argv[1]);
		exit(0);
	}

	incFileNameString = "./backend/my.inc";
	incFileName = fopen(incFileNameString, "w");

	yyparse();

	int flag=0;
	for (int i=1;i<=nowFuncs;i++) {
		if (strcmp(nowFunc[i],"main")) flag=1;
	}
	if (!flag) yyerror("main function not defined");

	fclose(yyin);
	fclose(incFileName);
	return 0;
}
