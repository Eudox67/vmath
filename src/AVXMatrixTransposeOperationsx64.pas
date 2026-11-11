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


unit AVXMatrixTransposeOperationsx64;

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


procedure AVXMatrixTransposeAligned(dest : PDouble; const destLineWidth : NativeInt; mt : PDouble; const LineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixTransposeUnaligned(dest : PDouble; const destLineWidth : NativeInt; mt : PDouble; const LineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

// Inplace Trasnposition of an N x N matrix
procedure AVXMatrixTransposeInplace(mt : PDouble; const LineWidth : NativeInt; N : NativeInt); assembler;


implementation


procedure AVXMatrixTransposeAligned(dest : PDouble; const destLineWidth : NativeInt;
  mt : PDouble; const LineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var iR12, iR13, iR14, iR15, iRSI, iRDI : NativeInt;
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

   // rcx = dest, rdx = destLineWidth, r8 = mt, r9 = LineWidth
   mov iR12, r12;
   mov iR13, r13;
   mov iR14, r14;
   mov iR15, r15;
   mov iRSI, rsi;
   mov iRDI, rdi;

   // stack handling
   sub rsp, $40;
   vmovupd [rsp + $00], xmm4; 
   vmovupd [rsp + $10], xmm5; 
   vmovupd [rsp + $20], xmm6; 
   vmovupd [rsp + $30], xmm7; 

   // iters := -width*sizeof(double);
   mov r10, width;
   shl r10, 3;
   imul r10, -1;

   sub r8, r10;

   // mtLineWidth2 := 4**LineWidth
   mov r11, r9;
   shl r11, 2;

   mov rdi, height;
   sub rdi, 4;
   jl @@foryloop4End;

   // we have at least a height of 4 -> try to transpose 4x4 blocks
   @foryloop4:
      // prepare pointers to mt
      mov r12, r8;
      mov r13, r12;
      add r13, r9;   // + linewidth
      mov r14, r13;
      add r14, r9;
      mov r15, r14;
      add r15, r9;

      mov rsi, rcx;

      // 4x4 blockwise transposition
      mov rax, r10;
      @forxloop4:
         add rax, 32;
         jg @loopend4;

         vmovapd ymm0, [r12 + rax - 32]; 
         vmovapd ymm1, [r13 + rax - 32]; 
         vmovapd ymm2, [r14 + rax - 32]; 
         vmovapd ymm3, [r15 + rax - 32]; 

         vunpckhpd ymm4, ymm0, ymm1; 
         vunpckhpd ymm5, ymm2, ymm3; 
         vunpcklpd ymm7, ymm2, ymm3; 

         vperm2f128 ymm3, ymm4, ymm5, $31; 

         vunpcklpd ymm6, ymm0, ymm1; 
         vinsertf128 ymm1, ymm4, xmm5, 1; 
         vperm2f128 ymm2, ymm6, ymm7, $31; 
         vinsertf128 ymm0, ymm6, xmm7, 1; 

         vmovapd [rsi], ymm0; 
         add rsi, rdx;
         vmovapd [rsi], ymm1; 
         add rsi, rdx;
         vmovapd [rsi], ymm2; 
         add rsi, rdx;
         vmovapd [rsi], ymm3; 
         add rsi, rdx;
      jmp @forxloop4;

      @loopend4:
      sub rax, 32;
      jz @nextline4;

       // handle the missing columns
      @forxloop:
         vmovsd xmm0, [r12 + rax]; 
         vmovsd [rsi], xmm0; 

         vmovsd xmm0, [r13 + rax]; 
         vmovsd [rsi + 8], xmm0; 

         vmovsd xmm0, [r14 + rax]; 
         vmovsd [rsi + 16], xmm0; 

         vmovsd xmm0, [r15 + rax]; 
         vmovsd [rsi + 24], xmm0; 
         add rsi, rdx;

      add rax, 8;
      jnz @forxloop;

      @nextline4:

      // dest := dest + 4*sizeof(double)
      add rcx, 32;
      add r8, r11; // src := src + 4*LineWidth
   sub rdi, 4;
   jge @foryloop4;

   @@foryloop4End:

   add rdi, 4;
   jz @endproc;

   // #############################
   // #### handle the last max 4 rows
   @@foryloop:
      mov rsi, rcx;
      mov rax, r10;

      @@forxloop:
         vmovsd xmm0, [r8 + rax]; 
         vmovsd [rsi], xmm0; 
         add rsi, rdx;
      add rax, 8;
      jnz @@forxloop;

      add rcx, 8;
      add r8, r9;
   dec rdi;
   jnz @@foryloop;

   @endproc:

   // epilog
   mov r12, iR12;
   mov r13, iR13;
   mov r14, iR14;
   mov r15, iR15;
   mov rsi, iRSI;
   mov rdi, iRDI;

   vmovupd xmm4, [rsp + $00]; 
   vmovupd xmm5, [rsp + $10]; 
   vmovupd xmm6, [rsp + $20]; 
   vmovupd xmm7, [rsp + $30]; 
   add rsp, $40;
   vzeroupper; 
end;

procedure AVXMatrixTransposeUnaligned(dest : PDouble; const destLineWidth : NativeInt; mt : PDouble; const LineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var iR12, iR13, iR14, iR15, iRSI, iRDI : NativeInt;
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

   // rcx = dest, rdx = destLineWidth, r8 = mt, r9 = LineWidth
   mov iR12, r12;
   mov iR13, r13;
   mov iR14, r14;
   mov iR15, r15;
   mov iRSI, rsi;
   mov iRDI, rdi;

   sub rsp, $40;
   vmovupd [rsp + $00], xmm4; 
   vmovupd [rsp + $10], xmm5; 
   vmovupd [rsp + $20], xmm6; 
   vmovupd [rsp + $30], xmm7; 

   // iters := -width*sizeof(double);
   mov r10, width;
   imul r10, -8;

   sub r8, r10;

   // mtLineWidth2 := 4**LineWidth
   mov r11, r9;
   shl r11, 2;

   mov rdi, height;
   sub rdi, 4;
   jl @@foryloop4End;

   // we have at least a height of 4 -> try to transpose 4x4 blocks
   @foryloop4:
      // prepare pointers to mt
      mov r12, r8;
      mov r13, r12;
      add r13, r9;   // + linewidth
      mov r14, r13;
      add r14, r9;
      mov r15, r14;
      add r15, r9;

      mov rsi, rcx;

      // 4x4 blockwise transposition
      mov rax, r10;
      @forxloop4:
         add rax, 32;
         jg @loopend4;

         vmovupd ymm0, [r12 + rax - 32]; 
         vmovupd ymm1, [r13 + rax - 32]; 
         vmovupd ymm2, [r14 + rax - 32]; 
         vmovupd ymm3, [r15 + rax - 32]; 

         vunpckhpd ymm4, ymm0, ymm1; 
         vunpckhpd ymm5, ymm2, ymm3; 
         vunpcklpd ymm7, ymm2, ymm3; 

         vperm2f128 ymm3, ymm4, ymm5, $31; 

         vunpcklpd ymm6, ymm0, ymm1; 
         vinsertf128 ymm1, ymm4, xmm5, 1; 
         vperm2f128 ymm2, ymm6, ymm7, $31; 
         vinsertf128 ymm0, ymm6, xmm7, 1; 

         vmovupd [rsi], ymm0; 
         add rsi, rdx;
         vmovupd [rsi], ymm1; 
         add rsi, rdx;
         vmovupd [rsi], ymm2; 
         add rsi, rdx;
         vmovupd [rsi], ymm3; 
         add rsi, rdx;
      jmp @forxloop4;

      @loopend4:
      sub rax, 32;
      jz @nextline4;

       // handle the missing columns
      @forxloop:
         vmovsd xmm0, [r12 + rax]; 
         vmovsd [rsi], xmm0; 

         vmovsd xmm0, [r13 + rax]; 
         vmovsd [rsi + 8], xmm0; 

         vmovsd xmm0, [r14 + rax]; 
         vmovsd [rsi + 16], xmm0; 

         vmovsd xmm0, [r15 + rax]; 
         vmovsd [rsi + 24], xmm0; 
         add rsi, rdx;

      add rax, 8;
      jnz @forxloop;

      @nextline4:

      // dest := dest + 4*sizeof(double)
      add rcx, 32;
      add r8, r11; // src := src + 4*LineWidth
   sub rdi, 4;
   jge @foryloop4;

   @@foryloop4End:

   add rdi, 4;
   jz @endproc;

   // #############################
   // #### handle the last max 4 rows
   @@foryloop:
      mov rsi, rcx;
      mov rax, r10;

      @@forxloop:
         vmovsd xmm0, [r8 + rax]; 
         vmovsd [rsi], xmm0; 
         add rsi, rdx;
      add rax, 8;
      jnz @@forxloop;

      add rcx, 8;
      add r8, r9;
   dec rdi;
   jnz @@foryloop;

   @endproc:

   // epilog
   mov r12, iR12;
   mov r13, iR13;
   mov r14, iR14;
   mov r15, iR15;
   mov rsi, iRSI;
   mov rdi, iRDI;

   vmovupd xmm4, [rsp + $00]; 
   vmovupd xmm5, [rsp + $10]; 
   vmovupd xmm6, [rsp + $20]; 
   vmovupd xmm7, [rsp + $30]; 
   add rsp, $40;
   vzeroupper; 
end;

// simple Inplace Trasnposition of an N x N matrix
procedure AVXMatrixTransposeInplace(mt : PDouble; const LineWidth : NativeInt; N : NativeInt); assembler;
// rcx: mt, rdx, LineWidth, r8: N
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
   // check if N < 2 -> do nothing an a 1x1 matrix
   cmp r8, 2;
   jl @@exitProc;

   // iter: -N*sizeof(Double)
   mov rax, r8;
   imul rax, -8;

   mov r9, rcx;  // pDest1: genptr(mt, 0, 1, linewidth)
   add r9, rdx;

   sub rcx, rax;  // mt + iter

   // for y := 0 to n - 2
   dec r8;
   @@foryloop:

      mov r10, rax; // iter aka x
      add r10, 8;
      mov r11, r9;
      // for x := y + 1 to n-1 do
      @@forxloop:
         vmovsd xmm0, [rcx + r10]; 
         vmovsd xmm1, [r11]; 

         vmovsd [rcx + r10], xmm1; 
         vmovsd [r11], xmm0; 

         add r11, rdx;
      add r10, 8;
      jnz @@forxloop;

      add rax, 8;  // iter + sizeof(double);
      //pDest := PConstDoubleArr( GenPtr(dest, 0, y, destLineWidth) );
      add rcx, rdx;
      // GenPtr(dest, y, y + 1, destLineWidth);
      add r9, rdx;
      add r9, 8;
   dec r8;
   jnz @@foryloop;

   @@exitProc:

   vzeroupper; 
end;


end.
