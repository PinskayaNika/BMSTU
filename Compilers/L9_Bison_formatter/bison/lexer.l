%option reentrant noyywrap bison-bridge bison-locations
%option extra-type="struct Extra *"

%{

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "lexer.h"
#include "parser.tab.h"

#define FLOAT_TYPENAME "float"
#define INT_TYPENAME "int"

#define YY_USER_ACTION                                      \
    {                                                       \
        int i;                                              \
        struct Extra *extra = yyextra;                      \
        if (! extra->continued) {                           \
            yylloc->first_line = extra->cur_line;           \
            yylloc->first_column = extra->cur_column;       \
        }                                                   \
        extra->continued = 0;                               \
        for (i = 0; i < yyleng; i++)                        \
        {                                                   \
            if (yytext[i] == '\n')                          \
            {                                               \
                extra->cur_line++;                          \
                extra->cur_column = 1;                      \
            }                                               \
            else                                            \
                extra->cur_column++;                        \
            }                                               \
                                                            \
        yylloc->last_line = extra->cur_line;                \
        yylloc->last_column = extra->cur_column;            \
    }

void yyerror(YYLTYPE *loc, yyscan_t scanner, char *msg)
{
    printf("Error (%d,%d): %s\n", loc->first_line, loc->first_column, msg);
}

%}

HEX_DIGIT       [0-9a-f]
UNICODE         \\u{HEX_DIGIT}{HEX_DIGIT}{HEX_DIGIT}{HEX_DIGIT}
UNESCAPED       [ -!#-\[\]-~]
ESCAPED         [\n]|[\t]

CHAR            {UNICODE}|{UNESCAPED}|{ESCAPED}
STRING          ["]["]|["]{CHAR}+["]

DIGIT           [0-9]
DIGIT1TO9       [1-9]
DIGITS          {DIGIT}+
INT             {DIGIT}|{DIGIT1TO9}{DIGITS}|-{DIGIT}|-{DIGIT1TO9}{DIGITS}
FRAC            [.]{DIGITS}
EXP             [eE][+-]?{DIGITS}
NUMBER          {INT}|{INT}{FRAC}|{INT}{EXP}|{INT}{FRAC}{EXP}

%%

[ ]+

true        { return ValTrue; }
false       { return ValFalse; }
null        { return ValNull; }

{STRING}    {   
                yylval->string = strdup(yytext); 
                return String; 
            }

{NUMBER}    { 
                if (strchr(yytext, '.')) {
                    yylval->number.typeName = FLOAT_TYPENAME;
                    yylval->number.numData.numFloat = atof(yytext);
                } else {
                    yylval->number.typeName = INT_TYPENAME;
                    yylval->number.numData.numInt = atoi(yytext);
                }
                return Number; 
            }

\{          { return ObjBeg; }
\}          { return ObjEnd; }

\[          { return ArrBeg; }
\]          { return ArrEnd; }

:           { return SymColon; }
,           { return SymComma; }

\n          { return SymLBreak; }
\t          { return SymTab; }

%%

void init_scanner(char *program, yyscan_t *scanner, struct Extra *extra)
{
    extra->continued = 0;
    extra->cur_line = 1;
    extra->cur_column = 1;
    yylex_init(scanner);
    yylex_init_extra(extra, scanner);
    yy_scan_string(program, *scanner);
}

void destroy_scanner(yyscan_t scanner)
{
    yylex_destroy(scanner);
}