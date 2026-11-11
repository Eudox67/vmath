// ###################################################################
// #### This file is part of the vmath project - a 64-bit, double-
// #### precision (mode objfpc) fork of mrMath:
// ####   https://github.com/mikerabat/mrmath
// ####
// #### Derived from mrMath. Copyright (c) 2011-2024, Michael R.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ####
// #### vmath is an independent fork and is not affiliated with,
// #### endorsed by, or supported by the mrMath project or its author.
// ###################################################################

unit ASMVecConvolvex64;

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


// simple convolution: the input and output parameter are assumed to be vectors!
// it's also assumed that memory before A is accessible for at least bLen elements
// -> these elements are used for the convulution calculation
// -> needs an aligned B and blen mod 2 needs to be zero
procedure ASMVecConvolveRevB(dest : PDouble; A, B : PDouble; aLen, {$ifdef UNIX}unixbLen{$ELSE}bLen{$endif} : NativeInt); assembler;


implementation


procedure ASMVecConvolveRevB(dest : PDouble; A, B : PDouble; aLen, {$ifdef UNIX}unixbLen{$ELSE}bLen{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var bLen : NativeInt;
{$endif}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov bLen, r8;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   mov r10, bLen;
   imul r10, -8;

   // rdx=A, r8 = B;
   add rdx, 8;
   sub r8, r10;

   @@forxloop:
      mov rax, r10;

      xorpd xmm0, xmm0;

      // unrolled part
      @@innerLoopUnrolled:
         add rax, 64;
         jg @@innerLoopStart;

         movupd xmm1, [rdx + rax - 64];
         movapd xmm2, [r8 + rax - 64];

         mulpd xmm1, xmm2;
         addpd xmm0, xmm1;

         movupd xmm3, [rdx + rax - 48];
         movapd xmm4, [r8 + rax - 48];

         mulpd xmm3, xmm4;
         addpd xmm0, xmm3;

         movupd xmm1, [rdx + rax - 32];
         movapd xmm2, [r8 + rax - 32];

         mulpd xmm1, xmm2;
         addpd xmm0, xmm1;

         movupd xmm3, [rdx + rax - 16];
         movapd xmm4, [r8 + rax - 16];

         mulpd xmm3, xmm4;
         addpd xmm0, xmm3;

      jmp @@innerLoopUnrolled;

      @@innerLoopStart:
      sub rax, 64;
      jz @@innerLoopEnd;

      @@innerLoop:
         movupd xmm1, [rdx + rax];
         movapd xmm2, [r8 + rax];

         mulpd xmm1, xmm2;
         addpd xmm0, xmm1;
         add rax, 16;
      jnz @@innerLoop;

      @@innerLoopEnd:

      haddpd xmm0, xmm0;
      movsd [rcx], xmm0;

      // next element
      add rcx, 8;
      add rdx, 8;
   dec r9;
   jnz @@forxloop;

   // ########################################
   // #### epilog
end;


end.
