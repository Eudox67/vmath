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

unit AVXMatrixCumSumDiffOperationsx64;

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


procedure AVXMatrixCumulativeSumRow(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXMatrixCumulativeSumColumnUnaligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixCumulativeSumColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXMatrixDifferentiateRow(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXMatrixDifferentiateColumnUnaligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixDifferentiateColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;


implementation


// ##################################################
// #### Cumulative sum
// ##################################################

procedure AVXMatrixCumulativeSumRow(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var iRSI : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
// rcx: dest, rdx: destlinewidth; r8: src; r9 : srclinewidth
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

   // prolog - maintain stack
   mov iRSI, rsi;

   // if (width <= 0) or (height <= 0) then exit;
   mov r10, width;
   cmp r10, 0;
   jle @@exitproc;
   mov rsi, height;
   cmp rsi, 0;
   jle @@exitproc;

   // iter := -width*sizeof(Double)
   imul r10, -8;

   // prepare counters
   sub rcx, r10;
   sub r8, r10;
   @@foryloop:
      mov rax, r10;

      vxorpd xmm0, xmm0, xmm0; 
      @@forxloop:
         vmovsd xmm1, [r8 + rax]; 
         vaddsd xmm0, xmm0, xmm1; 
         vmovsd [rcx + rax], xmm0; 
      add rax, 8;
      jnz @@forxloop;

      add rcx, rdx;
      add r8, r9;
   dec rsi;
   jnz @@foryloop;
   @@exitProc:

   // epilog - stack cleanup
   mov rsi, iRSI;
   vzeroupper; 
end;

procedure AVXMatrixCumulativeSumColumnUnaligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var iRDI, iRSI : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
// rcx: dest, rdx: destlinewidth; r8: src; r9 : srclinewidth
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

   // prolog - maintain stack
   mov iRDI, rdi;
   mov iRSI, rsi;

   // if (width <= 1) or (height <= 0) then exit;
   mov r11, height;
   cmp r11, 0;

   jle @@exitproc;
   mov r10, width;
   sub r10, 4;
   jl @@lastColumns;

   @@forxloop:
       mov rax, r11;
       vxorpd ymm0, ymm0, ymm0; 
       xor rdi, rdi;
       xor rsi, rsi;

       // 4 values at once
       @@foryloop:
           vmovupd ymm1, [r8 + rdi]; 
           vaddpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rsi], ymm0; 

           add rdi, r9;
           add rsi, rdx;
       dec rax;
       jnz @@foryloop;

       add r8, 32;
       add rcx, 32;
   sub r10, 4;
   jge @@forxloop;

   @@lastColumns:
   add r10, 4;
   jz @@exitProc;

   @@forxloopshort:
       mov rax, r11;
       vxorpd xmm0, xmm0, xmm0; 
       xor rdi, rdi;
       xor rsi, rsi;

       // 4 values at once
       @@foryloopshort:
           vmovsd xmm1, [r8 + rdi]; 
           vaddsd xmm0, xmm0, xmm1; 
           vmovsd [rcx + rsi], xmm0; 

           add rdi, r9;
           add rsi, rdx;
       dec rax;
       jnz @@foryloopshort;

       add r8, 8;
       add rcx, 8;
   sub r10, 1;
   jg @@forxloopshort;

   @@exitProc:

   // epilog - stack cleanup
   mov rdi, iRDI;
   mov rsi, iRSI;
   vzeroupper; 
end;

procedure AVXMatrixCumulativeSumColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var iRDI, iRSI : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
// rcx: dest, rdx: destlinewidth; r8: src; r9 : srclinewidth
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

   // prolog - maintain stack
   mov iRDI, rdi;
   mov iRSI, rsi;

   // if (width <= 1) or (height <= 0) then exit;
   mov r11, height;
   cmp r11, 0;

   jle @@exitproc;
   mov r10, width;
   sub r10, 4;
   jl @@lastColumns;

   @@forxloop:
       mov rax, r11;
       vxorpd ymm0, ymm0, ymm0; 
       xor rdi, rdi;
       xor rsi, rsi;

       // 4 values at once
       @@foryloop:
           vmovapd ymm1, [r8 + rdi]; 
           vaddpd ymm0, ymm0, ymm1; 
           vmovapd [rcx + rsi], ymm0; 

           add rdi, r9;
           add rsi, rdx;
       dec rax;
       jnz @@foryloop;

       add r8, 32;
       add rcx, 32;
   sub r10, 4;
   jge @@forxloop;

   @@lastColumns:
   add r10, 4;
   jz @@exitProc;

   @@forxloopshort:
       mov rax, r11;
       vxorpd xmm0, xmm0, xmm0; 
       xor rdi, rdi;
       xor rsi, rsi;

       // 4 values at once
       @@foryloopshort:
           vmovsd xmm1, [r8 + rdi]; 
           vaddsd xmm0, xmm0, xmm1; 
           vmovsd [rcx + rsi], xmm0; 

           add rdi, r9;
           add rsi, rdx;
       dec rax;
       jnz @@foryloopshort;

       add r8, 8;
       add rcx, 8;
   sub r10, 1;
   jg @@forxloopshort;

   @@exitProc:
   // epilog - stack cleanup
   mov rdi, iRDI;
   mov rsi, iRSI;
   vzeroupper; 
end;

// ###############################################
// #### Differentiate
// ###############################################

procedure AVXMatrixDifferentiateRow(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
{$ifdef UNIX}
var width : NativeInt;
    height : NativeInt;
    {$ENDIF}
// rcx: dest, rdx: destlinewidth; r8: src; r9 : srclinewidth
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

   // prolog - maintain stack

   // if (width <= 1) or (height <= 0) then exit;
   mov r10, width;
   cmp r10, 1;
   jle @@exitproc;
   mov r11, height;
   cmp r11, 0;
   jle @@exitproc;
   // iter := -width*sizeof(Double)
   imul r10, -8;
   // prepare counters
   sub rcx, r10;
   sub r8, r10;
   add r10, 8;
   @@foryloop:
       mov rax, r10;
       vmovsd xmm1, [r8 + rax - 8]; 
       @@forxloop:
           vmovsd xmm0, [r8 + rax]; 
           vsubsd xmm2, xmm0, xmm1; 
           vmovsd [rcx + rax - 8], xmm2; 
           vmovapd xmm1, xmm0; 
       add rax, 8;
       jnz @@forxloop;

       add rcx, rdx;
       add r8, r9;
   dec r11;
   jnz @@foryloop;

   @@exitProc:

   // epilog - stack cleanup
   vzeroupper; 
end;

procedure AVXMatrixDifferentiateColumnUnaligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var iRDI, iRSI : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
// rcx: dest, rdx: destlinewidth; r8: src; r9 : srclinewidth
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
   // prolog - maintain stack
   mov iRDI, rdi;
   mov iRSI, rsi;

   // if (width <= 1) or (height <= 0) then exit;
   mov r11, height;
   cmp r11, 1;
   jle @@exitproc;

   mov r10, width;
   cmp r10, 1;
   jle @@exitproc;

   dec r11;
   sub r10, 4;
   jl @@forxloopend;

   @@forxloop:
       mov rax, r11;
       vxorpd ymm0, ymm0, ymm0; 
       mov rdi, r9;
       xor rsi, rsi;

       vmovupd ymm0, [r8]; 

       // 4 values at once
       @@foryloop:
           vmovupd ymm1, [r8 + rdi]; 
           vsubpd ymm2, ymm1, ymm0; 
           vmovupd [rcx + rsi], ymm2; 

           vmovapd ymm0, ymm1; 

           add rdi, r9;
           add rsi, rdx;
       dec rax;
       jnz @@foryloop;

       add r8, 32;
       add rcx, 32;
   sub r10, 4;
   jge @@forxloop;

   @@forxloopend:
   add r10, 4;
   jz @@exitProc;

   // #####################################
   // #### last < 4 columns
   @@forxloopshort:
      mov rax, r11;
      vxorpd xmm0, xmm0, xmm0; 
      mov rdi, r9;
      xor rsi, rsi;

      vmovsd xmm0, [r8]; 

      // one column value:
      @@foryloopshort:
          vmovsd xmm1, [r8 + rdi]; 
          vsubsd xmm2, xmm1, xmm0; 
          vmovsd [rcx + rsi], xmm2; 

          vmovsd xmm0, xmm0, xmm1; 

          add rdi, r9;
          add rsi, rdx;
      dec rax;
      jnz @@foryloopshort;

      add r8, 8;
      add rcx, 8;

   dec r10;
   jnz @@forxloopshort;

   @@exitProc:

   // epilog - stack cleanup
   mov rdi, iRDI;
   mov rsi, iRSI;
end;

procedure AVXMatrixDifferentiateColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var iRDI, iRSI : NativeInt;
    {$ifdef UNIX}
    width : NativeInt;
    height : NativeInt;
    {$ENDIF}
// rcx: dest, rdx: destlinewidth; r8: src; r9 : srclinewidth
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
   // prolog - maintain stack
   mov iRDI, rdi;
   mov iRSI, rsi;

   // if (width <= 1) or (height <= 0) then exit;
   mov r11, height;
   cmp r11, 1;
   jle @@exitproc;

   mov r10, width;
   cmp r10, 1;
   jle @@exitproc;

   dec r11;
   sub r10, 4;
   jl @@forxloopend;

   @@forxloop:
       mov rax, r11;
       vxorpd ymm0, ymm0, ymm0; 
       mov rdi, r9;
       xor rsi, rsi;

       vmovupd ymm0, [r8]; 

       // 4 values at once
       @@foryloop:
           vmovapd ymm1, [r8 + rdi]; 
           vsubpd ymm2, ymm1, ymm0; 
           vmovapd [rcx + rsi], ymm2; 

           vmovapd ymm0, ymm1; 

           add rdi, r9;
           add rsi, rdx;
       dec rax;
       jnz @@foryloop;

       add r8, 32;
       add rcx, 32;
   sub r10, 4;
   jge @@forxloop;

   @@forxloopend:
   add r10, 4;
   jz @@exitProc;

   // #####################################
   // #### last < 4 columns
   @@forxloopshort:
      mov rax, r11;
      vxorpd xmm0, xmm0, xmm0; 
      mov rdi, r9;
      xor rsi, rsi;

      vmovsd xmm0, [r8]; 

      // one column value:
      @@foryloopshort:
          vmovsd xmm1, [r8 + rdi]; 
          vsubsd xmm2, xmm1, xmm0; 
          vmovsd [rcx + rsi], xmm2; 

          vmovsd xmm0, xmm0, xmm1; 

          add rdi, r9;
          add rsi, rdx;
      dec rax;
      jnz @@foryloopshort;

      add r8, 8;
      add rcx, 8;

   dec r10;
   jnz @@forxloopshort;

   @@exitProc:

   // epilog - stack cleanup
   mov rdi, iRDI;
   mov rsi, iRSI;
end;



end.
