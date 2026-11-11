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

unit AVXMatrixAbsOperationsx64;

// #####################################################
// #### Abs opertaion applied to every element in a matrix
// #####################################################

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


uses MatrixConst;

procedure AVXMatrixAbsAligned(Dest : PDouble; const LineWidth, Width, Height : NativeInt); assembler;
procedure AVXMatrixAbsUnAligned(Dest : PDouble; const LineWidth, Width, Height : NativeInt); assembler;


implementation


procedure AVXMatrixAbsAligned(Dest : PDouble; const LineWidth, Width, Height : NativeInt); assembler;
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   //iters := -width*sizeof(double);
   shl r8, 3;
   imul r8, -1;

   // helper registers for the dest pointer
   sub rcx, r8;

   lea rax, [rip + cSignBits4];
   vmovupd ymm0, [rax]; 

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetch data...
           //prefetchw [rcx + rax];

           // Abs:
           vmovapd ymm1, [rcx + rax - 128]; 
           vAndpd ymm1, ymm1, ymm0; 
           vmovapd [rcx + rax - 128], ymm1; 

           vmovapd ymm2, [rcx + rax - 96]; 
           vandpd ymm2, ymm2, ymm0; 
           vmovapd [rcx + rax - 96], ymm2; 

           vmovapd ymm3, [rcx + rax - 64]; 
           vandpd ymm3, ymm3, ymm0; 
           vmovapd [rcx + rax - 64], ymm3; 

           vmovapd ymm2, [rcx + rax - 32]; 
           vandpd ymm2, ymm2, ymm0; 
           vmovapd [rcx + rax - 32], ymm2; 
       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @loopEnd2;

           vmovapd xmm1, [rcx + rax - 16]; 
           vandpd xmm1, xmm1, xmm0; 
           vmovapd [rcx + rax - 16], xmm1; 
       jmp @addforxloop2;

       @loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm1, [rcx + rax]; 
       vandpd xmm1, xmm1, xmm0; 
       vmovsd [rcx + rax], xmm1; 

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   vzeroupper; 
end;

procedure AVXMatrixAbsUnAligned(Dest : PDouble; const LineWidth, Width, Height : NativeInt); assembler;
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   //iters := -width*sizeof(double);
   shl r8, 3;
   imul r8, -1;

   // helper registers for the dest pointer
   sub rcx, r8;

   lea rax, [rip + cSignBits4];
   vmovupd ymm0, [rax]; 

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetch data...
           //prefetchw [rcx + rax];

           // Abs:
           vmovupd ymm1, [rcx + rax - 128]; 
           vAndpd ymm1, ymm1, ymm0; 
           vmovupd [rcx + rax - 128], ymm1; 

           vmovupd ymm2, [rcx + rax - 96]; 
           vandpd ymm2, ymm2, ymm0; 
           vmovupd [rcx + rax - 96], ymm2; 

           vmovupd ymm3, [rcx + rax - 64]; 
           vandpd ymm3, ymm3, ymm0; 
           vmovupd [rcx + rax - 64], ymm3; 

           vmovupd ymm2, [rcx + rax - 32]; 
           vandpd ymm2, ymm2, ymm0; 
           vmovupd [rcx + rax - 32], ymm2; 
       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @loopEnd2;

           vmovupd xmm1, [rcx + rax - 16]; 
           vandpd xmm1, xmm1, xmm0; 
           vmovupd [rcx + rax - 16], xmm1; 
       jmp @addforxloop2;

       @loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm1, [rcx + rax]; 
       vandpd xmm1, xmm1, xmm0; 
       vmovsd [rcx + rax], xmm1; 

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   vzeroupper; 
end;


end.
