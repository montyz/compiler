/** Grammar for the Mantra language.
 *
 *  LABELS (to make applications derived from grammar easier):
 *
 *  Label scope identifies which node holds ref to Scope object
 *  Label name identifies name of scope like class name
 */
grammar Mantra;

@header {
import mantra.symbols.Scope;
import mantra.symbols.Type;
}

compilationUnit : packageDef? (function|clazz|interfaze|enumDef)* EOF ;

packageDef
locals [Scope scope] // leaves nice ptr field in this parse tree node
	:	'package' packageName
	;

clazz
locals [Scope scope]
    :   ('api'|'abstract')* 'class' name=ID typeArgumentNames?
     	('extends' supType=type)?
     	('implements' iTypes+=type (',' iTypes+=type)*)?
        '{'
            clazzMember*
        '}'
    ;

interfaze
locals [Scope scope]
    :   'api'? 'interface' name=ID ('extends' type (',' type)*)?
        '{'
//            field*
            functionHead*
        '}'
    ;

enumDef
locals [Scope scope]
	:   'enum' name=ID '{' elements+=ID (',' elements+=ID)* '}'
    ;

clazzMember
    :   clazz
    |	interfaze
    |	field
    |	memberFunction
    |   enumDef
    ;

field:  ('static'|'api')? vardecl
// 	|	'api'? propdecl
 	|	'api'? valdecl
 	;

commands : stat+ ;

memberFunction
	:	('static'|'api'|'overload')* function
	;

function
    :   functionHead block
    ;

functionHead
locals [Scope scope]
    :   'def' name=ID functionSignature
    ;

functionSignature
    :   '(' argList? ')' (':' type)?
    ;

argList
    :   argDef (',' argDef)*
    ;

argDef
    :   decl ('=' expression)?  // const exprs
    ;

lambdaSignature // no explicit return types in lambdas
    :   '(' ')'				 // for use like () => 42.0
	|	'(' decl (',' decl)* ')'		 // (x:int) => x*2
    |   ID 					 // shorthand for inferred arg
    |   '(' ID (',' ID)* ')' // shorthand for inferred args
    ;

blockArgs // no explicit return types in blocks { x,y | return x*y }
    :   decl (',' decl)* 	 // { x:int | ... }
    |   ID (',' ID)* 		 // shorthand for inferred arg types
    ;

funcSignature
    :   '(' ')' ':' type
    |	'(' ')'
	|	'(' argList ')' ':' type
	|	'(' argList ')'
    ;

/*
propdecl
    :   'property' decl ('=' expression)?
    |   'property' ID ('=' expression)?
    ;
*/

/*
TODO: add
    public Scope scope;   // set by Def.g; ID lives in which scope?
    public Symbol symbol; // set by Ref.g; point at def in symbol table
*/
vardecl
    :   'var' decl ('=' expression)?						# VarDeclWithType
    |   // type inf can use multiple assign on left
        'var' name=ID '=' expression 						# VarDeclNoType
    |   // type inf can use multiple assign on left
        'var' names+=ID (',' names+=ID)+ '=' expression 	# MultiVarDeclNoType
    ;

valdecl
    :   'val' decl '=' expression							# ValDeclWithType
    |   'val' name=ID '=' expression						# ValDeclNoType
    ;

decl:   name=ID ':' type ;

// TODO: add refs for these type names
// (int, float)[100], func<(x:int)>[100]
type:	coreType ('[' ']')+									# ArrayType
	|	coreType											# NonArrayType
	;

coreType
	:	classOrInterfaceType
    |	builtInType
    |	tupleType
	|   functionType
	;

tupleType // ordered list of types; tuples accessed with t[1], t[2], etc...
	:	'(' type (',' type)+ ')'
	;

functionType
    :   'func' '<' '(' argList? ')' ':' type '>'
    |	'func' '<' '(' argList ')' '>'
    |   'func' '<' '(' type ')' ':' type '>' // single argument doesn't need name
    |   'func' '<' '(' type ')' '>'
    |	'func' // ref to func with no args, no return value like {}
    ;

classOrInterfaceType
	:	qualifiedName typeArguments?
	;

typeArguments
    :   '<' type (',' type)* '>'
    ;

typeArgumentNames // only built-in types can use this like llist<string>
    :   '<' ID (',' ID)* '>'
    ;

builtInType
    :   'boolean'
    |   'char'
    |   'byte'
    |   'short'
    |   'int'
    |   'long'
    |   'float'
    |   'double'
	|	'string'

    |	(	'map'
		|	'tree'
		|	'list'
		|	'llist'
		|	'set'
		)
		typeArguments?
	;

block
locals [Scope scope]
	:	'{' stat* '}'
	;

stat:   lvalue (',' lvalue)* assignmentOperator expression
    |   expression // calls, pipelines, ...
    |   vardecl
    |   valdecl
    |   'for' expression block
    |   'while' expression block
    |   'if' expression block ('else' block)?
    |   'return' expression
    |   'do' block 'while' expression ';'
    |   'try' block (catches finallyBlock? | finallyBlock)
    |   'switch' expression '{' switchCase+ ('default' ':' (stat|block)?)? '}'
    |   'return' expression?
    |   'throw' expression
    |   'break'
    |   'continue'
    |   'print' expression
    |   'throw' expression
    |   clazz
    |   interfaze
    |   function
    |   enumDef
    ;

switchCase
    :   'case' expression (',' expression)* ':' (stat|block)?
    ;

catches
    :   catchClause+
    ;

catchClause
    :   'catch' '(' catchType ID ')' block
    ;

catchType
	:	qualifiedName
	;

finallyBlock
	:	'finally' block
	;

argExprList
    :   expression
    |   ID '=' expression (',' ID '=' expression)*
    ;

lvalue
	:	ID													# IdLvalue
	|	expression '[' expression ']'						# ArrayLvalue
	|	expression '.' ID									# FieldLvalue
	;

expression
locals [Type exprType]
	:   primary												# PrimaryExpr
    |   expression '.' ID									# FieldAccessExpr
    |   type '.' 'class'									# ClassPtrExpr
    |   expression '[' expression ']'						# ArrayIndexExpr
    |	'len' '(' expression ')'							# LenExpr
//    |	'count' '(' expression ')'							# CountExpr // counts non nil or non false entries?
    |	'xor' '(' expression ')'							# BitXorExpr
    |   expression '(' argExprList? ')' lambda?				# CallExpr
    |   '-' expression										# NegateExpr
    |   ('~'|'!') expression								# NotExpr
    |   expression ('*'|'/'|'%') expression					# MultExpr
    |   expression ('+'|'-') expression						# AddExpr
    |   expression ('<' '<' | '>' '>' '>' | '>' '>') expression	# ShiftExpr
    |   expression ('<=' | '>=' | '>' | '<') expression		# CmpExpr
	|   expression 'instanceof' type						# InstanceOfExpr
	|   expression ('==' | '!=' | 'is') expression			# EqExpr
	|   expression '&' expression							# BitAndExpr
	|   expression '^' expression							# ExpExpr
	|   expression '|' expression							# BitOrExpr
	|	expression ':' expression 							# RangeExpr
	|   expression 'and' expression							# AndExpr
	|   expression 'or' expression							# OrExpr
	|   expression 'in' expression							# InExpr
	|   expression '?' expression ':' expression			# TernaryIfExpr
	|	expression pipeOperator	expression					# PipeExpr
    ;

pipeOperator
	:	'=>' '[' expression ']'
	|	'=>*'
	|	'*=>' // pipe, merge
	|	'=>'
    ;

primary
locals [Type exprType]
	:	'(' expression ')'
    |	tuple
    |   THIS
    |   SUPER
    |   literal
    |   list
    |   map
    |   set // must appear before ctor to catch set(1,2)
    |   ctor
    |   lambda
    |   ID // string[] could match string here then [] as next statement; keep this as last alt
    ;

tuple
locals [Type exprType]
	:	'(' expression (',' expression)+ ')' ; // can also be a tuple of pipelines, yielding pipeline graph

// ctor (ambig with call)
ctor
locals [Type exprType]
	:	classOrInterfaceType '(' argExprList? ')'  	// Button(title="foo")
	|	builtInType          '(' argExprList? ')'  	// int(10), string()
	|	classOrInterfaceType ('[' expression? ']')+	// User[10][] list of 10 User lists of unspecified initial size
	|	builtInType          ('[' expression? ']')+ // int[] list of ints with unspecified initial size, int[10] 10 initial ints
	;

list
locals [Type exprType]
	:   '[' ']' // type inferred
    |   '[' expression (',' expression)* ']'
    ;

map
locals [Type exprType]
	:   '[' mapElem (',' mapElem)* ']'
    ;

mapElem
locals [Type exprType]
    :   expression '=' expression
    ;

// special case for convenience set(1,2), set<User>(User(), User()) where we don't need arg names
set
locals [Type exprType]
	:   'set' typeArguments? '(' (expression (',' expression)*)? ')'
	;

lambda
 locals [Type exprType]
    :   lambdaSignature '->' expression   // special case single expression
    |   '{' (blockArgs '|')? stat+ '}'
    |   '{' '}' // empty lambda
    ;

/** mantra::lang is a package name */
packageName
	:	ids+=ID ('::' ids+=ID)*
	;

/** mantra::lang::Object is a qualified class name in package mantra::lang */
qualifiedName
    :   packageName '::' ids+=ID ('.' ids+=ID)*
    |	ids+=ID ('.' ids+=ID)*
    ;

literal
locals [Type exprType]
    :   IntegerLiteral
    |   FloatingPointLiteral
    |   CharacterLiteral
    |   StringLiteral
    |   BooleanLiteral
    |   'nil'
    ;

assignmentOperator
    :   '='
    |   '+='
    |   '-='
    |   '*='
    |   '/='
    ;

ABSTRACT : 'abstract';
API : 'api';
ASSERT : 'assert';
BOOLEAN : 'boolean';
BREAK : 'break';
BYTE : 'byte';
CASE : 'case';
CATCH : 'catch';
CHAR : 'char';
CLASS : 'class';
CONST : 'const';
CONTINUE : 'continue';
DEFAULT : 'default';
DO : 'do';
DOUBLE : 'double';
ELSE : 'else';
ENUM : 'enum';
EXTENDS : 'extends';
FINAL : 'final';
FINALLY : 'finally';
FLOAT : 'float';
FOR : 'for';
IF : 'if';
GOTO : 'goto';// reserved, not used
IMPLEMENTS : 'implements';
IMPORT : 'import';
INSTANCEOF : 'instanceof';
INT : 'int';
INTERFACE : 'interface';
LEN : 'len';
LONG : 'long';
NATIVE : 'native';
NIL : 'nil' ;
OVERLOAD : 'overload';
PACKAGE : 'package';
PROPERTY : 'property'; // reserved, not used
RETURN : 'return';
SET : 'set';
SHORT : 'short';
STATIC : 'static';
STRING : 'string';
SUPER : 'super';
SWITCH : 'switch';
THIS : 'this';
THROW : 'throw';
TRANSIENT : 'transient';
TRY : 'try';
WHILE : 'while';
VAR : 'var' ;
VOID : 'void' ;
XOR : 'xor' ;

// §3.10.1 Integer Literals

IntegerLiteral
	:	DecimalIntegerLiteral
	|	HexIntegerLiteral
	|	OctalIntegerLiteral
	|	BinaryIntegerLiteral
	;

fragment
DecimalIntegerLiteral
	:	DecimalNumeral IntegerTypeSuffix?
	;

fragment
HexIntegerLiteral
	:	HexNumeral IntegerTypeSuffix?
	;

fragment
OctalIntegerLiteral
	:	OctalNumeral IntegerTypeSuffix?
	;

fragment
BinaryIntegerLiteral
	:	BinaryNumeral IntegerTypeSuffix?
	;

fragment
IntegerTypeSuffix
	:	[lL]
	;

fragment
DecimalNumeral
	:	'0'
	|	NonZeroDigit (Digits? | Underscores Digits)
	;

fragment
Digits
	:	Digit (DigitsAndUnderscores? Digit)?
	;

fragment
Digit
	:	'0'
	|	NonZeroDigit
	;

fragment
NonZeroDigit
	:	[1-9]
	;

fragment
DigitsAndUnderscores
	:	DigitOrUnderscore+
	;

fragment
DigitOrUnderscore
	:	Digit
	|	'_'
	;

fragment
Underscores
	:	'_'+
	;

fragment
HexNumeral
	:	'0' [xX] HexDigits
	;

fragment
HexDigits
	:	HexDigit (HexDigitsAndUnderscores? HexDigit)?
	;

fragment
HexDigit
	:	[0-9a-fA-F]
	;

fragment
HexDigitsAndUnderscores
	:	HexDigitOrUnderscore+
	;

fragment
HexDigitOrUnderscore
	:	HexDigit
	|	'_'
	;

fragment
OctalNumeral
	:	'0' Underscores? OctalDigits
	;

fragment
OctalDigits
	:	OctalDigit (OctalDigitsAndUnderscores? OctalDigit)?
	;

fragment
OctalDigit
	:	[0-7]
	;

fragment
OctalDigitsAndUnderscores
	:	OctalDigitOrUnderscore+
	;

fragment
OctalDigitOrUnderscore
	:	OctalDigit
	|	'_'
	;

fragment
BinaryNumeral
	:	'0' [bB] BinaryDigits
	;

fragment
BinaryDigits
	:	BinaryDigit (BinaryDigitsAndUnderscores? BinaryDigit)?
	;

fragment
BinaryDigit
	:	[01]
	;

fragment
BinaryDigitsAndUnderscores
	:	BinaryDigitOrUnderscore+
	;

fragment
BinaryDigitOrUnderscore
	:	BinaryDigit
	|	'_'
	;

FloatingPointLiteral
	:	DecimalFloatingPointLiteral
	|	HexadecimalFloatingPointLiteral
	;

fragment
DecimalFloatingPointLiteral
	:	Digits '.' Digits? ExponentPart? FloatTypeSuffix?
	|	'.' Digits ExponentPart? FloatTypeSuffix?
	|	Digits ExponentPart FloatTypeSuffix?
	|	Digits FloatTypeSuffix
	;

fragment
ExponentPart
	:	ExponentIndicator SignedInteger
	;

fragment
ExponentIndicator
	:	[eE]
	;

fragment
SignedInteger
	:	Sign? Digits
	;

fragment
Sign
	:	[+-]
	;

fragment
FloatTypeSuffix
	:	[fFdD]
	;

fragment
HexadecimalFloatingPointLiteral
	:	HexSignificand BinaryExponent FloatTypeSuffix?
	;

fragment
HexSignificand
	:	HexNumeral '.'?
	|	'0' [xX] HexDigits? '.' HexDigits
	;

fragment
BinaryExponent
	:	BinaryExponentIndicator SignedInteger
	;

fragment
BinaryExponentIndicator
	:	[pP]
	;

BooleanLiteral
	:	'true'
	|	'false'
	;

CharacterLiteral
	:	'\'' SingleCharacter '\''
	|	'\'' EscapeSequence '\''
	;

fragment
SingleCharacter
	:	~['\\\r\n]
	;

StringLiteral
	:	'"' StringCharacter* '"'
	;

UnterminatedStringLiteral
	:  '\"' StringCharacter* ([\r\n]|EOF)
	;

fragment
StringCharacter
	:	~["\\\r\n]
	|	EscapeSequence
	;

fragment
EscapeSequence
	:	'\\' [btnfr"'\\]
	|	OctalEscape
	;

fragment
OctalEscape
	:	'\\' OctalDigit
	|	'\\' OctalDigit OctalDigit
	|	'\\' ZeroToThree OctalDigit OctalDigit
	;

fragment
ZeroToThree
	:	[0-3]
	;

LPAREN : '(';
RPAREN : ')';
LBRACE : '{';
RBRACE : '}';
LBRACK : '[';
RBRACK : ']';
SEMI : ';';
COMMA : ',';
DOT : '.';

//ASSIGN : '=';
GT : '>';
LT : '<';
BANG : '!';
TILDE : '~';
QUESTION : '?';
COLON : ':';
EQUAL : '==';
IS : 'is' ;
IN : 'in' ;
LE : '<=';
GE : '>=';
NOTEQUAL : '!=';
AND : 'and';
OR : 'or';
INC : '++';
DEC : '--';
ADD : '+';
SUB : '-';
MUL : '*';
DIV : '/';
BITAND : '&';
BITOR : '|';
CARET : '^';
MOD : '%';
YIELDS : '->' ; // lambda
PIPE : '=>' ;
PIPE_MANY : '=>*' ;
MERGE_MANY : '*=>' ;

ADD_ASSIGN : '+=';
SUB_ASSIGN : '-=';
MUL_ASSIGN : '*=';
DIV_ASSIGN : '/=';

ID  :	JavaLetter JavaLetterOrDigit*  // follow Java conventions
	;

fragment
JavaLetter
	:	[a-zA-Z$_] // these are the "java letters" below 0xFF
	|	// covers all characters above 0xFF which are not a surrogate
		~[\u0000-\u00FF\uD800-\uDBFF]
		{Character.isJavaIdentifierStart(_input.LA(-1))}?
	|	// covers UTF-16 surrogate pairs encodings for U+10000 to U+10FFFF
		[\uD800-\uDBFF] [\uDC00-\uDFFF]
		{Character.isJavaIdentifierStart(Character.toCodePoint((char)_input.LA(-2), (char)_input.LA(-1)))}?
	;

fragment
JavaLetterOrDigit
	:	[a-zA-Z0-9$_] // these are the "java letters or digits" below 0xFF
	|	// covers all characters above 0xFF which are not a surrogate
		~[\u0000-\u00FF\uD800-\uDBFF]
		{Character.isJavaIdentifierPart(_input.LA(-1))}?
	|	// covers UTF-16 surrogate pairs encodings for U+10000 to U+10FFFF
		[\uD800-\uDBFF] [\uDC00-\uDFFF]
		{Character.isJavaIdentifierPart(Character.toCodePoint((char)_input.LA(-2), (char)_input.LA(-1)))}?
	;

WS  :  [ \t\u000C]+ -> channel(HIDDEN)
    ;

NL  :   '\r'? '\n' -> channel(HIDDEN) ;    // command separator (ignore for now)

DOC_COMMENT
	:	'/**' .*? ('*/' | EOF) -> channel(HIDDEN)
	;

BLOCK_COMMENT
	:	'/*' .*? ('*/' | EOF)  -> channel(HIDDEN)
	;

LINE_COMMENT
	:	'//' ~[\r\n]*  -> channel(HIDDEN)
	;