# Simple-Bitwise-Processor--Compiler-Optimization
Simple language for bitwise processing using a lexer (Flex) and parser (Bison). Specifically generating LLVM IR code for basic code.

E.g. (test_7.p1)
======================================== Source Code input ========================================
''in a
b = a*a - a
final b12,b11,b10,b9,b8,b7,b6,b5''

======================================== LLVM IR Representation ========================================
; ModuleID = 'test_7'
source_filename = "test_7"

define i32 @test_7(i32 %0) {
entry:
  %1 = alloca i32, align 4
  store i32 %0, i32* %1, align 4
  %a = load i32, i32* %1, align 4
  %a1 = load i32, i32* %1, align 4
  %expr.mul = mul i32 %a, %a1
  %a2 = load i32, i32* %1, align 4
  %expr.sub = sub i32 %expr.mul, %a2
  %b = alloca i32, align 4
  store i32 %expr.sub, i32* %b, align 4
  %2 = load i32, i32* %b, align 4
  %3 = and i32 4096, %2
  %4 = icmp ne i32 %3, 0
  %bit.specifier = zext i1 %4 to i32
  %5 = load i32, i32* %b, align 4
  %6 = and i32 2048, %5
  %7 = icmp ne i32 %6, 0
  %bit.specifier3 = zext i1 %7 to i32
  %comma.shift_opt = shl i32 %bit.specifier, 1
  %comma.concat_opt = or i32 %comma.shift_opt, %bit.specifier3
  %8 = load i32, i32* %b, align 4
  %9 = and i32 1024, %8
  %10 = icmp ne i32 %9, 0
  %bit.specifier4 = zext i1 %10 to i32
  %comma.shift_opt5 = shl i32 %comma.concat_opt, 1
  %comma.concat_opt6 = or i32 %comma.shift_opt5, %bit.specifier4
  %11 = load i32, i32* %b, align 4
  %12 = and i32 512, %11
  %13 = icmp ne i32 %12, 0
  %bit.specifier7 = zext i1 %13 to i32
  %comma.shift_opt8 = shl i32 %comma.concat_opt6, 1
  %comma.concat_opt9 = or i32 %comma.shift_opt8, %bit.specifier7
  %14 = load i32, i32* %b, align 4
  %15 = and i32 256, %14
  %16 = icmp ne i32 %15, 0
  %bit.specifier10 = zext i1 %16 to i32
  %comma.shift_opt11 = shl i32 %comma.concat_opt9, 1
  %comma.concat_opt12 = or i32 %comma.shift_opt11, %bit.specifier10
  %17 = load i32, i32* %b, align 4
  %18 = and i32 128, %17
  %19 = icmp ne i32 %18, 0
  %bit.specifier13 = zext i1 %19 to i32
  %comma.shift_opt14 = shl i32 %comma.concat_opt12, 1
  %comma.concat_opt15 = or i32 %comma.shift_opt14, %bit.specifier13
  %20 = load i32, i32* %b, align 4
  %21 = and i32 64, %20
  %22 = icmp ne i32 %21, 0
  %bit.specifier16 = zext i1 %22 to i32
  %comma.shift_opt17 = shl i32 %comma.concat_opt15, 1
  %comma.concat_opt18 = or i32 %comma.shift_opt17, %bit.specifier16
  %23 = load i32, i32* %b, align 4
  %24 = and i32 32, %23
  %25 = icmp ne i32 %24, 0
  %bit.specifier19 = zext i1 %25 to i32
  %comma.shift_opt20 = shl i32 %comma.concat_opt18, 1
  %comma.concat_opt21 = or i32 %comma.shift_opt20, %bit.specifier19
  ret i32 %comma.concat_opt21
}

