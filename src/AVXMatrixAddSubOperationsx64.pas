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


unit AVXMatrixAddSubOperationsx64;

// ############################################################
// ##### Matrix addition/subtraction assembler optimized:
// ############################################################

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


procedure AVXMatrixAddAligned(dest : PDouble; const destLineWidth : NativeInt; mt1, mt2 : PDouble; {$ifdef UNIX}unixWidth{$ELSE}width{$endif} : NativeInt; {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; const LineWidth1, LineWidth2 : NativeInt); assembler;
procedure AVXMatrixAddUnAligned(dest : PDouble; const destLineWidth : NativeInt; mt1, mt2 : PDouble; {$ifdef UNIX}unixWidth{$ELSE}width{$endif} : NativeInt; {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; const LineWidth1, LineWidth2 : NativeInt); assembler;

procedure AVXMatrixSubAligned(dest : PDouble; const destLineWidth : NativeInt; mt1, mt2 : PDouble; {$ifdef UNIX}unixWidth{$ELSE}width{$endif} : NativeInt; {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; const LineWidth1, LineWidth2 : NativeInt); assembler;
procedure AVXMatrixSubUnAligned(dest : PDouble; const destLineWidth : NativeInt; mt1, mt2 : PDouble; {$ifdef UNIX}unixWidth{$ELSE}width{$endif} : NativeInt; {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; const LineWidth1, LineWidth2 : NativeInt); assembler;

procedure AVXMatrixSubT(A : PDouble; LineWidthA : NativeInt; B : PDouble; LineWidthB : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXMatrixSubVecAlignedVecRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixSubVecAlignedRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixSubVecAlignedCol(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXMatrixSubVecUnalignedVecRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixSubVecUnalignedRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixSubVecUnalignedCol(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXMatrixAddVecAlignedVecRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixAddVecAlignedRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixAddVecAlignedCol(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXMatrixAddVecUnalignedVecRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixAddVecUnalignedRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixAddVecUnalignedCol(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;


implementation


procedure AVXMatrixAddAligned(dest : PDouble; const destLineWidth : NativeInt; mt1, mt2 : PDouble; {$ifdef UNIX}unixWidth{$ELSE}width{$endif} : NativeInt; {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; const LineWidth1, LineWidth2 : NativeInt); assembler;
var iRBX, iR12 : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = mt1, R9 = mt2
   // prolog - simulate stack
   mov iRBX, rbx;
   mov iR12, r12;

   //iters := -width*sizeof(double);
   mov r10, width;
   imul r10, -8;

   mov r11, LineWidth1;
   mov r12, LineWidth2;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;
   sub r9, r10;
   sub rcx, r10;

   // for y := 0 to height - 1:
   mov rbx, Height;
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetch data...
           // prefetch [r8 + rax];
           // prefetch [r9 + rax];

           // addition:
           vmovapd ymm0, [r8 + rax - 128]; 
           vaddpd ymm0, ymm0, [r9 + rax - 128]; 

           vmovapd ymm1, [r8 + rax - 96]; 
           vaddpd ymm1, ymm1, [r9 + rax - 96]; 

           vmovapd ymm2, [r8 + rax - 64]; 
           vaddpd ymm2, ymm2, [r9 + rax - 64]; 

           vmovapd ymm3, [r8 + rax - 32]; 
           vaddpd ymm3, ymm3, [r9 + rax - 32]; 

           vmovapd [rcx + rax - 128], ymm0; 
           vmovapd [rcx + rax - 96], ymm1; 
           vmovapd [rcx + rax - 64], ymm2; 
           vmovapd [rcx + rax - 32], ymm3; 
       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @@loopEnd2;

           vmovapd xmm0, [r8 + rax - 16]; 
           vaddpd xmm0, xmm0, [r9 + rax - 16]; 

           vmovapd [rcx + rax - 16], xmm0; 
       jmp @addforxloop2;

       @@loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm0, [r8 - 8]; 
       vmovsd xmm1, [r9 - 8]; 
       vaddsd xmm0, xmm0, xmm1; 
       vmovsd [rcx - 8], xmm0; 

       @nextLine:

       // next line:
       add r8, r11;
       add r9, r12;
       add rcx, rdx;

   // loop y end
   dec rbx;
   jnz @@addforyloop;

   // epilog
   mov rbx, iRBX;
   mov r12, iR12;
   vzeroupper; 
end;

procedure AVXMatrixAddUnAligned(dest : PDouble; const destLineWidth : NativeInt; mt1, mt2 : PDouble; {$ifdef UNIX}unixWidth{$ELSE}width{$endif} : NativeInt; {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; const LineWidth1, LineWidth2 : NativeInt); assembler;
var iRBX, iR12 : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = mt1, R9 = mt2
   // prolog - simulate stack
   mov iRBX, rbx;
   mov iR12, r12;

   //iters := -width*sizeof(double);
   mov r10, width;
   shl r10, 3;
   imul r10, -1;

   mov r11, LineWidth1;
   mov r12, LineWidth2;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;
   sub r9, r10;
   sub rcx, r10;

   // for y := 0 to height - 1:
   mov rbx, Height;
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetch data...
           // prefetch [r8 + rax];
           // prefetch [r9 + rax];

           // addition:
           vmovupd ymm0, [r8 + rax - 128]; 
           vmovupd ymm1, [r9 + rax - 128]; 
           vaddpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 128], ymm0; 

           vmovupd ymm0, [r8 + rax - 96]; 
           vmovupd ymm1, [r9 + rax - 96]; 
           vaddpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 96], ymm0; 

           vmovupd ymm0, [r8 + rax - 64]; 
           vmovupd ymm1, [r9 + rax - 64]; 
           vaddpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 64], ymm0; 

           vmovupd ymm0, [r8 + rax - 32]; 
           vmovupd ymm1, [r9 + rax - 32]; 
           vaddpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 32], ymm0; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @@loopEnd2;

           vmovupd xmm0, [r8 + rax - 16]; 
           vmovupd xmm1, [r9 + rax - 16]; 
           vaddpd xmm0, xmm0, xmm1; 

           vmovupd [rcx + rax - 16], xmm0; 
       jmp @addforxloop2;

       @@loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm0, [r8 - 8]; 
       vmovsd xmm1, [r9 - 8]; 
       vaddsd xmm0, xmm0, xmm1; 
       vmovsd [rcx - 8], xmm0; 

       @nextLine:

       // next line:
       add r8, r11;
       add r9, r12;
       add rcx, rdx;

   // loop y end
   dec rbx;
   jnz @@addforyloop;

   // epilog
   mov rbx, iRBX;
   mov r12, iR12;
   vzeroupper; 
end;

procedure AVXMatrixSubAligned(dest : PDouble; const destLineWidth : NativeInt; mt1, mt2 : PDouble; {$ifdef UNIX}unixWidth{$ELSE}width{$endif} : NativeInt; {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; const LineWidth1, LineWidth2 : NativeInt); assembler;
var iRBX, iR12 : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = mt1, R9 = mt2
   // prolog - simulate stack
   mov iRBX, rbx;
   mov iR12, r12;

   //iters := -width*sizeof(double);
   mov r10, width;
   imul r10, -8;

   mov r11, LineWidth1;
   mov r12, LineWidth2;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;
   sub r9, r10;
   sub rcx, r10;

   // for y := 0 to height - 1:
   mov rbx, Height;
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetch data...
           // prefetch [r8 + rax];
           // prefetch [r9 + rax];

           // addition:
           vmovapd ymm0, [r8 + rax - 128]; 
           vsubpd ymm0, ymm0, [r9 + rax - 128]; 

           vmovapd ymm1, [r8 + rax - 96]; 
           vsubpd ymm1, ymm1, [r9 + rax - 96]; 

           vmovapd ymm2, [r8 + rax - 64]; 
           vsubpd ymm2, ymm2, [r9 + rax - 64]; 

           vmovapd ymm3, [r8 + rax - 32]; 
           vsubpd ymm3, ymm3, [r9 + rax - 32]; 

           vmovapd [rcx + rax - 128], ymm0; 
           vmovapd [rcx + rax - 96], ymm1; 
           vmovapd [rcx + rax - 64], ymm2; 
           vmovapd [rcx + rax - 32], ymm3; 
       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @@loopEnd2;

           vmovapd xmm0, [r8 + rax - 16]; 
           vsubpd xmm0, xmm0, [r9 + rax - 16]; 

           vmovapd [rcx + rax - 16], xmm0; 
       jmp @addforxloop2;

       @@loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm0, [r8 - 8]; 
       vmovsd xmm1, [r9 - 8]; 
       vsubsd xmm0, xmm0, xmm1; 
       vmovsd [rcx - 8], xmm0; 

       @nextLine:

       // next line:
       add r8, r11;
       add r9, r12;
       add rcx, rdx;

   // loop y end
   dec rbx;
   jnz @@addforyloop;

   // epilog
   mov rbx, iRBX;
   mov r12, iR12;
   vzeroupper; 
end;

procedure AVXMatrixSubUnAligned(dest : PDouble; const destLineWidth : NativeInt; mt1, mt2 : PDouble; {$ifdef UNIX}unixWidth{$ELSE}width{$endif} : NativeInt; {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; const LineWidth1, LineWidth2 : NativeInt); assembler;
var iRBX, iR12 : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = mt1, R9 = mt2
   // prolog - simulate stack
   mov iRBX, rbx;
   mov iR12, r12;

   //iters := -width*sizeof(double);
   mov r10, width;
   imul r10, -8;

   mov r11, LineWidth1;
   mov r12, LineWidth2;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;
   sub r9, r10;
   sub rcx, r10;

   // for y := 0 to height - 1:
   mov rbx, Height;
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetch data...
           // prefetch [r8 + rax];
           // prefetch [r9 + rax];

           // addition:
           vmovupd ymm0, [r8 + rax - 128]; 
           vmovupd ymm1, [r9 + rax - 128]; 
           vsubpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 128], ymm0; 

           vmovupd ymm0, [r8 + rax - 96]; 
           vmovupd ymm1, [r9 + rax - 96]; 
           vsubpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 96], ymm0; 

           vmovupd ymm0, [r8 + rax - 64]; 
           vmovupd ymm1, [r9 + rax - 64]; 
           vsubpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 64], ymm0; 

           vmovupd ymm0, [r8 + rax - 32]; 
           vmovupd ymm1, [r9 + rax - 32]; 
           vsubpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 32], ymm0; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @@loopEnd2;

           vmovupd xmm0, [r8 + rax - 16]; 
           vmovupd xmm1, [r9 + rax - 16]; 
           vsubpd xmm0, xmm0, xmm1; 

           vmovupd [rcx + rax - 16], xmm0; 
       jmp @addforxloop2;

       @@loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm0, [r8 - 8]; 
       vmovsd xmm1, [r9 - 8]; 
       vsubsd xmm0, xmm0, xmm1; 
       vmovsd [rcx - 8], xmm0; 

       @nextLine:

       // next line:
       add r8, r11;
       add r9, r12;
       add rcx, rdx;

   // loop y end
   dec rbx;
   jnz @@addforyloop;

   // epilog
   mov rbx, iRBX;
   mov r12, iR12;
   vzeroupper; 
end;

procedure AVXMatrixSubT(A : PDouble; LineWidthA : NativeInt; B : PDouble; LineWidthB : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var iRBX : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
// rcx : A, rdx : LineWidthA, r8 : B, r9 : LineWidthB;
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}
   // maintain stack
   mov iRBX, rbx;

   // rax: iter := -width*sizeof(double)
   mov rcx, A;
   mov rax, width;
   imul rax, -8;
   sub rcx, rax;

   // for y := 0 to height - 1
   @@foryloop:
      mov r10, r8;
      mov rbx, rax;
              // for x := 0 to width - 1
      @@forxloop:
         vmovsd xmm0, [rcx + rbx]; 
         vmovsd xmm1, [r10]; 
         vsubsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rbx], xmm0; 

         add r10, r9;
      add rbx, 8;
      jnz @@forxloop;

      add rcx, rdx;
      add r8, 8;
   dec height;
   jnz @@foryloop;

   // epilog
   mov rbx, iRBX;
   vzeroupper; 
end;

// ########################################################
// #### Matrix add, sub to vector operations
// ########################################################

procedure AVXMatrixSubVecAlignedVecRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var width : NativeInt;
    height : NativeInt;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}
   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r10, width;
   imul r10, -8;

   sub rcx, r10;
   sub r8, r10;

   @@foryloop:
      mov rax, r10;

      @@forxloopUnrolled:
         add rax, 64;
         jg @@EndLoop1;

         vmovapd ymm0, [rcx + rax - 64]; 
         vsubpd ymm0, ymm0, [r8 + rax - 64]; 
         vmovapd [rcx + rax - 64], ymm0; 

         vmovapd ymm2, [rcx + rax - 32]; 
         vsubpd ymm2, ymm2, [r8 + rax - 32]; 
         vmovapd [rcx + rax - 32], ymm2; 

      jmp @@forxloopUnrolled;

      @@EndLoop1:

      sub rax, 64;

      jz @NextLine;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 
         vmovsd xmm1, [r8 + rax]; 

         vsubsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add rax, 8;
      jnz @@forxloop;

      @NextLine:

      add rcx, rdx;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixSubVecAlignedRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var vecIter : NativeInt;
{$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
{$ENDIF}

asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}
   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r11, width;

   imul r11, r9;
   imul r11, -1;
   mov vecIter, r11;

   mov r10, width;
   imul r10, -8;

   sub rcx, r10;
   sub r8, r11;

   @@foryloop:
      mov rax, r10;
      mov r11, vecIter;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 
         vmovsd xmm1, [r8 + r11]; 

         vsubsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add r11, r9;
         add rax, 8;
      jnz @@forxloop;

      add rcx, rdx;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixSubVecAlignedCol(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var width : NativeInt;
    height : NativeInt;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}
   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r10, width;
   imul r10, -8;

   sub rcx, r10;

   @@foryloop:
      mov rax, r10;

      vbroadcastsd ymm1, [r8]; 

      @@forxloopUnrolled:
         add rax, 64;
         jg @@EndLoop1;

         vmovapd ymm0, [rcx + rax - 64]; 
         vsubpd ymm0, ymm0, ymm1; 
         vmovapd [rcx + rax - 64], ymm0; 

         vmovapd ymm2, [rcx + rax - 32]; 
         vsubpd ymm2, ymm2, ymm1; 
         vmovapd [rcx + rax - 32], ymm2; 

      jmp @@forxloopUnrolled;

      @@EndLoop1:

      sub rax, 64;

      jz @NextLine;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 

         vsubsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add rax, 8;
      jnz @@forxloop;

      @NextLine:

      add rcx, rdx;
      add r8, r9;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixSubVecUnalignedVecRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var width : NativeInt;
    height : NativeInt;
{$ENDIF}

asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}

   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r10, width;
   imul r10, -8;

   sub rcx, r10;
   sub r8, r10;

   @@foryloop:
      mov rax, r10;

      @@forxloopUnrolled:
         add rax, 64;
         jg @@EndLoop1;

         vmovupd ymm0, [rcx + rax - 64]; 
         vmovupd ymm1, [r8 + rax - 64]; 
         vsubpd ymm0, ymm0, ymm1; 
         vmovupd [rcx + rax - 64], ymm0; 

         vmovupd ymm2, [rcx + rax - 32]; 
         vmovupd ymm3, [r8 + rax - 32]; 
         vsubpd ymm2, ymm2, ymm3; 
         vmovupd [rcx + rax - 32], ymm2; 

      jmp @@forxloopUnrolled;

      @@EndLoop1:

      sub rax, 64;

      jz @NextLine;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 
         vmovsd xmm1, [r8 + rax]; 

         vsubsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add rax, 8;
      jnz @@forxloop;

      @NextLine:

      add rcx, rdx;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixSubVecUnalignedRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var vecIter : NativeInt;
{$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
{$ENDIF}

asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}
   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r11, width;

   imul r11, r9;
   imul r11, -1;
   mov vecIter, r11;

   mov r10, width;
   imul r10, -8;

   sub rcx, r10;
   sub r8, r11;

   @@foryloop:
      mov rax, r10;
      mov r11, vecIter;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 
         vmovsd xmm1, [r8 + r11]; 

         vsubsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add r11, r9;
         add rax, 8;
      jnz @@forxloop;

      add rcx, rdx;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixSubVecUnalignedCol(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var width : NativeInt;
    height : NativeInt;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}

   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r10, width;
   imul r10, -8;

   sub rcx, r10;

   @@foryloop:
      mov rax, r10;

      vbroadcastsd ymm1, [r8]; 

      @@forxloopUnrolled:
         add rax, 64;
         jg @@EndLoop1;

         vmovupd ymm0, [rcx + rax - 64]; 
         vsubpd ymm0, ymm0, ymm1; 
         vmovupd [rcx + rax - 64], ymm0; 

         vmovupd ymm2, [rcx + rax - 32]; 
         vsubpd ymm2, ymm2, ymm1; 
         vmovupd [rcx + rax - 32], ymm2; 

      jmp @@forxloopUnrolled;

      @@EndLoop1:

      sub rax, 64;

      jz @NextLine;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 

         vsubsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add rax, 8;
      jnz @@forxloop;

      @NextLine:

      add rcx, rdx;
      add r8, r9;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;


procedure AVXMatrixAddVecAlignedVecRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var width : NativeInt;
    height : NativeInt;
{$ENDIF}

asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}

   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r10, width;
   imul r10, -8;

   sub rcx, r10;
   sub r8, r10;

   @@foryloop:
      mov rax, r10;

      @@forxloopUnrolled:
         add rax, 64;
         jg @@EndLoop1;

         vmovapd ymm0, [rcx + rax - 64]; 
         vaddpd ymm0, ymm0, [r8 + rax - 64]; 
         vmovapd [rcx + rax - 64], ymm0; 

         vmovapd ymm2, [rcx + rax - 32]; 
         vaddpd ymm2, ymm2, [r8 + rax - 32]; 
         vmovapd [rcx + rax - 32], ymm2; 
      jmp @@forxloopUnrolled;

      @@EndLoop1:

      sub rax, 64;

      jz @NextLine;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 
         vmovsd xmm1, [r8 + rax]; 

         vaddsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add rax, 8;
      jnz @@forxloop;

      @NextLine:

      add rcx, rdx;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixAddVecAlignedRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var vecIter : NativeInt;
{$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
{$ENDIF}

asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}

   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r11, width;

   imul r11, r9;
   imul r11, -1;
   mov vecIter, r11;

   mov r10, width;
   imul r10, -8;

   sub rcx, r10;
   sub r8, r11;

   @@foryloop:
      mov rax, r10;
      mov r11, vecIter;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 
         vmovsd xmm1, [r8 + r11]; 

         vaddsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add r11, r9;
         add rax, 8;
      jnz @@forxloop;

      add rcx, rdx;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixAddVecAlignedCol(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var width : NativeInt;
    height : NativeInt;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}

   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r10, width;
   imul r10, -8;

   sub rcx, r10;

   @@foryloop:
      mov rax, r10;

      vbroadcastsd ymm1, [r8]; 

      @@forxloopUnrolled:
         add rax, 64;
         jg @@EndLoop1;

         vmovapd ymm0, [rcx + rax - 64]; 
         vaddpd ymm0, ymm0, ymm1; 
         vmovapd [rcx + rax - 64], ymm0; 

         vmovapd ymm2, [rcx + rax - 32]; 
         vaddpd ymm2, ymm2, ymm1; 
         vmovapd [rcx + rax - 32], ymm2; 

      jmp @@forxloopUnrolled;

      @@EndLoop1:

      sub rax, 64;

      jz @NextLine;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 

         vaddsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add rax, 8;
      jnz @@forxloop;

      @NextLine:

      add rcx, rdx;
      add r8, r9;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixAddVecUnalignedVecRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var width : NativeInt;
    height : NativeInt;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}

   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r10, width;
   imul r10, -8;

   sub rcx, r10;
   sub r8, r10;

   @@foryloop:
      mov rax, r10;

      @@forxloopUnrolled:
         add rax, 64;
         jg @@EndLoop1;

         vmovupd ymm0, [rcx + rax - 64]; 
         vmovupd ymm1, [r8 + rax - 64]; 
         vaddpd ymm0, ymm0, ymm1; 
         vmovupd [rcx + rax - 64], ymm0; 

         vmovupd ymm2, [rcx + rax - 32]; 
         vmovupd ymm3, [r8 + rax - 32]; 
         vaddpd ymm2, ymm2, ymm3; 
         vmovupd [rcx + rax - 32], ymm2; 

      jmp @@forxloopUnrolled;

      @@EndLoop1:

      sub rax, 64;

      jz @NextLine;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 
         vmovsd xmm1, [r8 + rax]; 

         vaddsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add rax, 8;
      jnz @@forxloop;

      @NextLine:

      add rcx, rdx;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixAddVecUnalignedRow(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var vecIter : NativeInt;
{$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}

   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r11, width;

   imul r11, r9;
   imul r11, -1;
   mov vecIter, r11;

   mov r10, width;
   imul r10, -8;

   sub rcx, r10;
   sub r8, r11;

   @@foryloop:
      mov rax, r10;
      mov r11, vecIter;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 
         vmovsd xmm1, [r8 + r11]; 

         vaddsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add r11, r9;
         add rax, 8;
      jnz @@forxloop;

      add rcx, rdx;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;

procedure AVXMatrixAddVecUnalignedCol(A : PDouble; LineWidthA : NativeInt; B : PDouble; incX : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var width : NativeInt;
    height : NativeInt;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   mov width, r8;
   mov height, r9;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
  {$ENDIF}

   // rcx = a, rdx = LineWidthA, r8 = B, r9 = incX
   mov r10, width;
   imul r10, -8;

   sub rcx, r10;

   @@foryloop:
      mov rax, r10;

      vbroadcastsd ymm1, [r8]; 

      @@forxloopUnrolled:
         add rax, 64;
         jg @@EndLoop1;

         vmovupd ymm0, [rcx + rax - 64]; 
         vaddpd ymm0, ymm0, ymm1; 
         vmovupd [rcx + rax - 64], ymm0; 

         vmovupd ymm2, [rcx + rax - 32]; 
         vaddpd ymm2, ymm2, ymm1; 
         vmovupd [rcx + rax - 32], ymm2; 

      jmp @@forxloopUnrolled;

      @@EndLoop1:

      sub rax, 64;

      jz @NextLine;

      @@forxloop:
         vmovsd xmm0, [rcx + rax]; 

         vaddsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 

         add rax, 8;
      jnz @@forxloop;

      @NextLine:

      add rcx, rdx;
      add r8, r9;
   dec Height;
   jnz @@foryloop;

   vzeroupper; 
end;



end.
