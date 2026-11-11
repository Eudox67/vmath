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

unit FMAVecConvolvex64;

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


// simple convolution: the input and output parameter are assumed to be vectors!
// it's also assumed that memory before A is accessible for at least bLen elements
// -> these elements are used for the convulution calculation
// -> needs an aligned B and blen mod 2 needs to be zero
procedure FMAVecConvolveRevB(dest : PDouble; A, B : PDouble; aLen, {$ifdef UNIX}unixbLen{$ELSE}bLen{$endif} : NativeInt); assembler;


implementation


procedure FMAVecConvolveRevB(dest : PDouble; A, B : PDouble; aLen, {$ifdef UNIX}unixbLen{$ELSE}bLen{$endif} : NativeInt); assembler;
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

      vxorpd ymm0, ymm0, ymm0; 

      // unrolled part
      @@innerLoopUnrolled:
         add rax, 128;
         jg @@innerLoopStart;

         vmovupd ymm1, [rdx + rax - 128]; 
         vmovapd ymm2, [r8 + rax - 128]; 

         vfmadd231pd ymm0, ymm1, ymm2; 

         vmovupd ymm3, [rdx + rax - 96]; 
         vmovapd ymm4, [r8 + rax - 96]; 

         vfmadd231pd ymm0,  ymm3, ymm4; 

         vmovupd ymm1, [rdx + rax - 64]; 
         vmovapd ymm2, [r8 + rax - 64]; 

         vfmadd231pd ymm0, ymm1, ymm2; 

         vmovupd ymm3, [rdx + rax - 32]; 
         vmovapd ymm4, [r8 + rax - 32]; 

         vfmadd231pd ymm0, ymm3, ymm4; 

      jmp @@innerLoopUnrolled;

      @@innerLoopStart:
      sub rax, 128;
      jz @@innerLoopEnd;

      @@innerLoop:
         add rax, 32;
         jg @@innerLoop2Start;

         vmovupd ymm1, [rdx + rax - 32]; 
         vmovapd ymm2, [r8 + rax - 32]; 

         vfmadd231pd ymm0, ymm1, ymm2; 
      jmp @@innerLoop;

      // last two elements
      @@innerLoop2Start:
      sub rax, 32;
      jz @@innerLoopEnd;

      vmovupd xmm3, [rdx]; 
      vmovapd xmm4, [r8]; 
      vmulpd xmm3, xmm3, xmm4; 
      vaddpd xmm0, xmm0, xmm3; 


      @@innerLoopEnd:

      vextractf128 xmm1, ymm0, 1; 
      vaddpd xmm0, xmm0, xmm1; 
      vhaddpd xmm0, xmm0, xmm0; 
      vmovsd [rcx], xmm0; 

      // next element
      add rcx, 8;
      add rdx, 8;
   dec r9;
   jnz @@forxloop;

   // ########################################
   // #### epilog
   vzeroupper; 
end;


end.
