%{
//  Evan Mason
//  ECE 466 - Compiler Optimization
//  Project 1

#include <cstdio>
#include <list>
#include <vector>
#include <map>
#include <iostream>
#include <string>
#include <memory>
#include <stdexcept>

#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/Value.h"
#include "llvm/IR/Function.h"
#include "llvm/IR/Type.h"
#include "llvm/IR/Verifier.h"

#include "llvm/Bitcode/BitcodeReader.h"
#include "llvm/Bitcode/BitcodeWriter.h"
#include "llvm/Support/SystemUtils.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/IR/IRBuilder.h"
#include "llvm/Support/FileSystem.h"

using namespace llvm;
using namespace std;

// Need for parser and scanner
extern FILE *yyin;
int yylex();
void yyerror(const char*);
int yyparse();
 
// Needed for LLVM
string funName;
Module *M;
LLVMContext TheContext;
IRBuilder<> Builder(TheContext);

//add local variables to 'stack'
std::map<std::string,Value*> idMap;

%}

%union {
  vector<string> *params_list;
  Value *val;
  char * id;
  int imm;
}

/*%define parse.trace*/

%type <params_list> params_list
%type <val> expr
%type <val> ensemble

%token IN FINAL
%token ERROR
%token <imm> NUMBER
%token <id> ID
%token BINV INV PLUS MINUS XOR AND OR MUL DIV MOD
%token COMMA ENDLINE ASSIGN LBRACKET RBRACKET LPAREN RPAREN NONE COLON
%token REDUCE EXPAND

%precedence BINV
%precedence INV
%left PLUS MINUS OR
%left MUL DIV AND XOR MOD

%start program

%%

program: inputs statements_opt final
{
  YYACCEPT;
}
;

inputs:   IN params_list ENDLINE
{
  std::vector<Type*> param_types;
  for(auto s: *$2)
    {
      param_types.push_back(Builder.getInt32Ty());
    }
  ArrayRef<Type*> Params (param_types);
  
  // Create int function type with no arguments
  FunctionType *FunType = FunctionType::get(Builder.getInt32Ty(),Params,false);

  // Create a main function
  Function *Function = Function::Create(FunType,GlobalValue::ExternalLinkage,funName,M);

  //Add a basic block to main to hold instructions, and set Builder to insert there
  Builder.SetInsertPoint(BasicBlock::Create(TheContext, "entry", Function));

  int arg_no=0;
    for(auto &a: Function->args()) {
      // iterate over arguments of function
      // match name to position
      //Function keeps track of argument values by position/index
      //match name given in grammar with position to argument
      //link values
      Value* var = NULL;
      var = Builder.CreateAlloca(Builder.getInt32Ty(), nullptr);
      idMap[$2->at(arg_no)] = var;
      Builder.CreateStore(&a,var);
      arg_no++;
    }
}
| IN NONE ENDLINE
{ 
  // Create int function type with no arguments
  FunctionType *FunType = 
    FunctionType::get(Builder.getInt32Ty(),false);

  // Create a main function
  Function *Function = Function::Create(FunType,  
         GlobalValue::ExternalLinkage,funName,M);

  //Add a basic block to main to hold instructions, and set Builder
  //to insert there
  Builder.SetInsertPoint(BasicBlock::Create(TheContext, "entry", Function));
}
;

params_list: ID
{
  $$ = new vector<string>;
  // add ID to vector
  $$->push_back($1);
}
| params_list COMMA ID
{
  // add ID to $1
  $$->push_back($3);
}
;

final: FINAL ensemble endline_opt
{
  Builder.CreateRet($2);
}
;

endline_opt: %empty | ENDLINE;
            

statements_opt: %empty
            | statements;

statements:   statement 
            | statements statement 
;

statement: ID ASSIGN ensemble ENDLINE
{
    // Look to see if we already allocated it
    Value* var = NULL;
    if (idMap.find($1)==idMap.end()) {
        // We haven’t, so make a spot on the stack
        var = Builder.CreateAlloca(Builder.getInt32Ty(), nullptr, $1);
        // remember this location and associate it with $1
        idMap[$1] = var;
    }
    else {
        var = idMap[$1];
      }
    // store $3 into $1’s location in memory
    Builder.CreateStore($3,var);

}
// | ID NUMBER ASSIGN ensemble ENDLINE                      // 566 only
// | ID LBRACKET ensemble RBRACKET ASSIGN ensemble ENDLINE  // 566 only
;

ensemble:   expr
{
    $$ = $1;
}
// | expr COLON NUMBER                  // 566 only
|           ensemble COMMA expr
{
    Value * temp = nullptr;
    temp = Builder.CreateShl($1, 1, "comma.shift_opt");
    $$ = Builder.CreateOr(temp, $3, "comma.concat_opt");
}
// | ensemble COMMA expr COLON NUMBER   // 566 only
;

expr:   ID                                                  // Identifier
{
    Value * var = nullptr;
    if(idMap.find($1) == idMap.end()){
        printf("Variable accessed before being defined\n");
        YYABORT;
    }
    var = idMap[$1];
    $$ = Builder.CreateLoad(var, $1);
}
|       ID NUMBER                                           // Get bit at index[NUMBER], move it to LSB position
{
    // Look to see if we already allocated it
    if (idMap.find($1)==idMap.end()) {
        printf("Variable accessed before being defined\n");
        YYABORT;
    }
    //trying to access index out of bounds
    if($2 > 31 || $2 < 0){
        printf("Bit index out of bounds\n");
        YYABORT;
    }
    //create bit mask
    Value *bit_mask = Builder.getInt32(1);
    bit_mask = Builder.CreateShl(bit_mask, $2);
    //load stored val
    Value *temp = Builder.CreateLoad(idMap[$1]);
    //perform bitmask
    Value *result = Builder.CreateAnd(bit_mask, temp);
    //determine if indexed bit is 0 or 1
    Value *icmp = Builder.CreateICmpNE(result, Builder.getInt32(0));
    //extend icmp size
    $$ = Builder.CreateZExt(icmp, Builder.getInt32Ty(), "bit.specifier");

}
|       NUMBER                                              // Int Number
{
    $$ = Builder.getInt32($1);
}
|       expr PLUS expr                                      // Add two expr
{
    $$ = Builder.CreateAdd($1, $3, "expr.add");
}
|       expr MINUS expr                                     // Subtract two expr
{
    $$ = Builder.CreateSub($1, $3, "expr.sub");
}
|       expr XOR expr                                       // XOR operation on two expr
{
    $$ = Builder.CreateXor($1, $3, "expr.xor");
}
|       expr AND expr                                       // AND operation on two expr
{
    $$ = Builder.CreateAnd($1, $3, "expr.and");
}
|       expr OR expr                                        // OR operation on two expr
{
    $$ = Builder.CreateOr($1, $3, "expr.or");
}
|       INV expr                                            // Flips all 32 bits in expr (e.g. y=0; ~y becomes -1)
{
    Value * result = $2;
    for(int i = 0; i<32; i++){
        result = Builder.CreateXor(result, (Builder.CreateShl(Builder.getInt32(1), i)));
    }
    $$ = result;
}
|       BINV expr                                           // Invert LSB of expr
{
    Value *bit_mask = Builder.getInt32(1);
    //perform bitmask
    Value *result = Builder.CreateAnd(bit_mask, $2);
    //determine if LSB bit is 0 or 1
    Value *icmp = Builder.CreateICmpEQ(result, Builder.getInt32(1));
    $$ = Builder.CreateSelect(icmp,Builder.CreateSub($2, Builder.getInt32(1)),
                Builder.CreateAdd($2, Builder.getInt32(1)),"expr.binv");

}
|       expr MUL expr                                       // Multiply two expr
{
    $$ = Builder.CreateMul($1, $3, "expr.mul");
}
|       expr DIV expr                                       // Divide two expr
{
    $$ = Builder.CreateSDiv($1, $3, "expr.div");
}
|       expr MOD expr                                       // Modulo operation on two expr
{
    //(num - divisor * (num / divisor))
    Value *temp1 = Builder.CreateSDiv($1, $3);
    Value *temp2 = Builder.CreateMul(temp1, $3);
    $$ = Builder.CreateSub($1, temp2, "expr.mod");
}
|       ID LBRACKET ensemble RBRACKET                       // Access specific bit of ID
{
    // Look to see if we already allocated it
    if (idMap.find($1)==idMap.end()) {
        printf("Variable accessed before being defined\n");
        YYABORT;
    }
    //trying to access index out of bounds
    Value *gt_check = Builder.CreateICmpSGT($3, Builder.getInt32(31));
    Value *lt_check = Builder.CreateICmpSLT($3, Builder.getInt32(0));
    Value *check1 = Builder.CreateZExt(gt_check, Builder.getInt32Ty());
    Value *check2 = Builder.CreateZExt(lt_check, Builder.getInt32Ty());
    if(check1 == Builder.getInt32(1) || check2 == Builder.getInt32(1)){
        printf("Bit index out of bounds\n");
        YYABORT;
    }
    //create bit mask
    Value *bit_mask = Builder.getInt32(1);
    bit_mask = Builder.CreateShl(bit_mask, $3);
    //load stored val
    Value *temp = Builder.CreateLoad(idMap[$1]);
    //perform bitmask
    Value *result = Builder.CreateAnd(bit_mask, temp);
    //determine if indexed bit is 0 or 1
    Value *icmp = Builder.CreateICmpNE(result, Builder.getInt32(0));
    //extend icmp size
    $$ = Builder.CreateZExt(icmp, Builder.getInt32Ty(), "bit.specifier.bracket");
}
|       LPAREN ensemble RPAREN
{
    $$ = $2;
}
/* 566 only */
// | LPAREN ensemble RPAREN LBRACKET ensemble RBRACKET
// | REDUCE AND LPAREN ensemble RPAREN
// | REDUCE OR LPAREN ensemble RPAREN
// | REDUCE XOR LPAREN ensemble RPAREN
// | REDUCE PLUS LPAREN ensemble RPAREN
// | EXPAND  LPAREN ensemble RPAREN
;

%%

unique_ptr<Module> parseP1File(const string &InputFilename)
{
  funName = InputFilename;
  if (funName.find_last_of('/') != string::npos)
    funName = funName.substr(funName.find_last_of('/')+1);
  if (funName.find_last_of('.') != string::npos)
    funName.resize(funName.find_last_of('.'));
    
  //errs() << "Function will be called " << funName << ".\n";
  
  // unique_ptr will clean up after us, call destructor, etc.
  unique_ptr<Module> Mptr(new Module(funName.c_str(), TheContext));

  // set global module
  M = Mptr.get();
  
  /* this is the name of the file to generate, you can also use
     this string to figure out the name of the generated function */
  yyin = fopen(InputFilename.c_str(),"r");

  //yydebug = 1;
  if (yyparse() != 0)
    // errors, so discard module
    Mptr.reset();
  else
    // Dump LLVM IR to the screen for debugging
    M->print(errs(),nullptr,false,true);
  
  return Mptr;
}

void yyerror(const char* msg)
{
  printf("%s\n",msg);
}
