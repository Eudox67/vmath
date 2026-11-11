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


unit AVXMatrixScaleOperationsx64;

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


procedure AVXMatrixAddscaleAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
procedure AVXMatrixAddscaleUnAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;

procedure AVXMatrixAddscaleAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
procedure AVXMatrixAddscaleUnAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;

procedure AVXMatrixScaleAddAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
procedure AVXMatrixScaleAddUnAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;

procedure AVXMatrixScaleAddAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
procedure AVXMatrixScaleAddUnAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;

procedure AVXMatrixAddAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif} : double); assembler;
procedure AVXMatrixAddUnAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif} : double); assembler;

procedure AVXMatrixAddAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif} : double); assembler;
procedure AVXMatrixAddUnAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif} : double); assembler;


implementation


procedure AVXMatrixAddscaleAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset, Scale : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   movsd xmm3, unixScale;
   movsd scale, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -width*sizeof(double);
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 
   lea rax, scale;
   vbroadcastsd ymm1, [rax]; 


   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // add mul
           vmovapd ymm0, [rcx + rax - 128]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmulpd ymm0, ymm0, ymm1; 
           vmovapd [rcx + rax - 128], ymm0; 

           vmovapd ymm2, [rcx + rax - 96]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmulpd ymm2, ymm2, ymm1; 
           vmovapd [rcx + rax - 96], ymm2; 

           vmovapd ymm0, [rcx + rax - 64]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmulpd ymm0, ymm0, ymm1; 
           vmovapd [rcx + rax - 64], ymm0; 

           vmovapd ymm2, [rcx + rax - 32]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmulpd ymm2, ymm2, ymm1; 
           vmovapd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovapd xmm0, [rcx + rax]; 
           vaddpd xmm0, xmm0, xmm3; 
           vmulpd xmm0, xmm0, xmm1; 

           vmovapd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;

procedure AVXMatrixAddscaleUnAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset, scale : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   movsd xmm3, unixscale;
   movsd scale, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -width*sizeof(double);
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 
   lea rax, scale;
   vbroadcastsd ymm1, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // add mul
           vmovupd ymm0, [rcx + rax - 128]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmulpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 128], ymm0; 

           vmovupd ymm2, [rcx + rax - 96]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmulpd ymm2, ymm2, ymm1; 
           vmovupd [rcx + rax - 96], ymm2; 

           vmovupd ymm0, [rcx + rax - 64]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmulpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 64], ymm0; 

           vmovupd ymm2, [rcx + rax - 32]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmulpd ymm2, ymm2, ymm1; 
           vmovupd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovupd xmm0, [rcx + rax]; 
           vaddpd xmm0, xmm0, xmm3; 
           vmulpd xmm0, xmm0, xmm1; 

           vmovupd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;


procedure AVXMatrixAddscaleAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset, scale : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   movsd xmm3, unixscale;
   movsd scale, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -(width - 1)*sizeof(double);
   dec r8;
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 
   lea rax, scale;
   vbroadcastsd ymm1, [rax]; 


   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // add mul
           vmovapd ymm0, [rcx + rax - 128]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmulpd ymm0, ymm0, ymm1; 
           vmovapd [rcx + rax - 128], ymm0; 

           vmovapd ymm2, [rcx + rax - 96]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmulpd ymm2, ymm2, ymm1; 
           vmovapd [rcx + rax - 96], ymm2; 

           vmovapd ymm0, [rcx + rax - 64]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmulpd ymm0, ymm0, ymm1; 
           vmovapd [rcx + rax - 64], ymm0; 

           vmovapd ymm2, [rcx + rax - 32]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmulpd ymm2, ymm2, ymm1; 
           vmovapd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovapd xmm0, [rcx + rax]; 
           vaddpd xmm0, xmm0, xmm3; 
           vmulpd xmm0, xmm0, xmm1; 

           vmovapd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // special care of the last column:
       vmovsd xmm0, [rcx]; 
       vaddsd xmm0, xmm0, xmm3; 
       vmulsd xmm0, xmm0, xmm1; 
       vmovsd [rcx], xmm0; 

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;

procedure AVXMatrixAddscaleUnAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset, scale : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   movsd xmm3, unixscale;
   movsd scale, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -(width - 1)*sizeof(double);
   dec r8;
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 
   lea rax, scale;
   vbroadcastsd ymm1, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // add mul
           vmovupd ymm0, [rcx + rax - 128]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmulpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 128], ymm0; 

           vmovupd ymm2, [rcx + rax - 96]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmulpd ymm2, ymm2, ymm1; 
           vmovupd [rcx + rax - 96], ymm2; 

           vmovupd ymm0, [rcx + rax - 64]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmulpd ymm0, ymm0, ymm1; 
           vmovupd [rcx + rax - 64], ymm0; 

           vmovupd ymm2, [rcx + rax - 32]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmulpd ymm2, ymm2, ymm1; 
           vmovupd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovupd xmm0, [rcx + rax]; 
           vaddpd xmm0, xmm0, xmm3; 
           vmulpd xmm0, xmm0, xmm1; 

           vmovupd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // special care of the last column:
       vmovsd xmm0, [rcx]; 
       vaddsd xmm0, xmm0, xmm3; 
       vmulsd xmm0, xmm0, xmm1; 
       vmovsd [rcx], xmm0; 

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;


procedure AVXMatrixScaleAddAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset, scale : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   movsd xmm3, unixscale;
   movsd scale, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -width*sizeof(double);
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 
   lea rax, scale;
   vbroadcastsd ymm1, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // addition:
           vmovapd ymm0, [rcx + rax - 128]; 
           vmulpd ymm0, ymm0, ymm1; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovapd [rcx + rax - 128], ymm0; 

           vmovapd ymm2, [rcx + rax - 96]; 
           vmulpd ymm2, ymm2, ymm1; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovapd [rcx + rax - 96], ymm2; 

           vmovapd ymm0, [rcx + rax - 64]; 
           vmulpd ymm0, ymm0, ymm1; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovapd [rcx + rax - 64], ymm0; 

           vmovapd ymm2, [rcx + rax - 32]; 
           vmulpd ymm2, ymm2, ymm1; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovapd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovapd xmm0, [rcx + rax]; 
           vmulpd xmm0, xmm0, xmm1; 
           vaddpd xmm0, xmm0, xmm3; 

           vmovapd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;

procedure AVXMatrixScaleAddUnAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset, scale : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   movsd xmm3, unixscale;
   movsd scale, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -width*sizeof(double);
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 
   lea rax, scale;
   vbroadcastsd ymm1, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // addition:
           vmovupd ymm0, [rcx + rax - 128]; 
           vmulpd ymm0, ymm0, ymm1; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovupd [rcx + rax - 128], ymm0; 

           vmovupd ymm2, [rcx + rax - 96]; 
           vmulpd ymm2, ymm2, ymm1; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovupd [rcx + rax - 96], ymm2; 

           vmovupd ymm0, [rcx + rax - 64]; 
           vmulpd ymm0, ymm0, ymm1; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovupd [rcx + rax - 64], ymm0; 

           vmovupd ymm2, [rcx + rax - 32]; 
           vmulpd ymm2, ymm2, ymm1; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovupd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovupd xmm0, [rcx + rax]; 
           vmulpd xmm0, xmm0, xmm1; 
           vaddpd xmm0, xmm0, xmm3; 

           vmovupd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;

procedure AVXMatrixScaleAddAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset, scale : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   movsd xmm3, unixscale;
   movsd scale, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -width*sizeof(double);
   dec r8;
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 
   lea rax, scale;
   vbroadcastsd ymm1, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // addition:
           vmovapd ymm0, [rcx + rax - 128]; 
           vmulpd ymm0, ymm0, ymm1; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovapd [rcx + rax - 128], ymm0; 

           vmovapd ymm2, [rcx + rax - 96]; 
           vmulpd ymm2, ymm2, ymm1; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovapd [rcx + rax - 96], ymm2; 

           vmovapd ymm0, [rcx + rax - 64]; 
           vmulpd ymm0, ymm0, ymm1; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovapd [rcx + rax - 64], ymm0; 

           vmovapd ymm2, [rcx + rax - 32]; 
           vmulpd ymm2, ymm2, ymm1; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovapd [rcx + rax - 32], ymm2; 


       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovapd xmm0, [rcx + rax]; 
           vmulpd xmm0, xmm0, xmm1; 
           vaddpd xmm0, xmm0, xmm3; 

           vmovapd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // special care of the last column:
       vmovsd xmm0, [rcx]; 
       vmulsd xmm0, xmm0, xmm1; 
       vaddsd xmm0, xmm0, xmm3; 
       vmovsd [rcx], xmm0; 

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;

procedure AVXMatrixScaleAddUnAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif}, {$ifdef UNIX}unixScale{$ELSE}Scale{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset, scale : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   movsd xmm3, unixscale;
   movsd scale, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -width*sizeof(double);
   dec r8;
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 
   lea rax, scale;
   vbroadcastsd ymm1, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // addition:
           vmovupd ymm0, [rcx + rax - 128]; 
           vmulpd ymm0, ymm0, ymm1; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovupd [rcx + rax - 128], ymm0; 

           vmovupd ymm2, [rcx + rax - 96]; 
           vmulpd ymm2, ymm2, ymm1; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovupd [rcx + rax - 96], ymm2; 

           vmovupd ymm0, [rcx + rax - 64]; 
           vmulpd ymm0, ymm0, ymm1; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovupd [rcx + rax - 64], ymm0; 

           vmovupd ymm2, [rcx + rax - 32]; 
           vmulpd ymm2, ymm2, ymm1; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovupd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovupd xmm0, [rcx + rax]; 
           vmulpd xmm0, xmm0, xmm1; 
           vaddpd xmm0, xmm0, xmm3; 

           vmovupd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // special care of the last column:
       vmovsd xmm0, [rcx]; 
       vmulsd xmm0, xmm0, xmm1; 
       vaddsd xmm0, xmm0, xmm3; 
       vmovsd [rcx], xmm0; 

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;


// ###########################################
// #### Offset a matrix
// ###########################################

procedure AVXMatrixAddAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -width*sizeof(double);
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // add mul
           vmovapd ymm0, [rcx + rax - 128]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovapd [rcx + rax - 128], ymm0; 

           vmovapd ymm2, [rcx + rax - 96]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovapd [rcx + rax - 96], ymm2; 

           vmovapd ymm0, [rcx + rax - 64]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovapd [rcx + rax - 64], ymm0; 

           vmovapd ymm2, [rcx + rax - 32]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovapd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovapd xmm0, [rcx + rax]; 
           vaddpd xmm0, xmm0, xmm3; 

           vmovapd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;

procedure AVXMatrixAddUnAlignedEvenW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -width*sizeof(double);
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // add mul
           vmovupd ymm0, [rcx + rax - 128]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovupd [rcx + rax - 128], ymm0; 

           vmovupd ymm2, [rcx + rax - 96]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovupd [rcx + rax - 96], ymm2; 

           vmovupd ymm0, [rcx + rax - 64]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovupd [rcx + rax - 64], ymm0; 

           vmovupd ymm2, [rcx + rax - 32]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovupd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovupd xmm0, [rcx + rax]; 
           vaddpd xmm0, xmm0, xmm3; 

           vmovupd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;


procedure AVXMatrixAddAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -(width - 1)*sizeof(double);
   dec r8;
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // add mul
           vmovapd ymm0, [rcx + rax - 128]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovapd [rcx + rax - 128], ymm0; 

           vmovapd ymm2, [rcx + rax - 96]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovapd [rcx + rax - 96], ymm2; 

           vmovapd ymm0, [rcx + rax - 64]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovapd [rcx + rax - 64], ymm0; 

           vmovapd ymm2, [rcx + rax - 32]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovapd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovapd xmm0, [rcx + rax]; 
           vaddpd xmm0, xmm0, xmm3; 

           vmovapd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // special care of the last column:
       vmovsd xmm0, [rcx]; 
       vaddsd xmm0, xmm0, xmm3; 
       vmovsd [rcx], xmm0; 

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;

procedure AVXMatrixAddUnAlignedOddW(Dest : PDouble; const LineWidth, Width, Height : NativeInt; {$ifdef UNIX}unixdOffset{$ELSE}dOffset{$endif} : double); assembler;
{$IFDEF UNIX}
var dOffset : double;
{$ENDIF}
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // (note that the 5th and 6th parameter are are on the stack)
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX -> mov to RCX, RDX, R8, R9
   movsd xmm3, unixdOffset;
   movsd dOffset, xmm3;
   mov r8, rdx;
   mov r9, rcx;
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}

   // note: RCX = dest, RDX = destLineWidth, R8 = width, R9 = height
   // prolog - simulate stack

   //iters := -(width - 1)*sizeof(double);
   dec r8;
   imul r8, -8;

   lea rax, dOffset;
   vbroadcastsd ymm3, [rax]; 

   // helper registers for the mt1, mt2 and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetchw data...
           // prefetchw [rcx + rax];

           // add mul
           vmovupd ymm0, [rcx + rax - 128]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovupd [rcx + rax - 128], ymm0; 

           vmovupd ymm2, [rcx + rax - 96]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovupd [rcx + rax - 96], ymm2; 

           vmovupd ymm0, [rcx + rax - 64]; 
           vaddpd ymm0, ymm0, ymm3; 
           vmovupd [rcx + rax - 64], ymm0; 

           vmovupd ymm2, [rcx + rax - 32]; 
           vaddpd ymm2, ymm2, ymm3; 
           vmovupd [rcx + rax - 32], ymm2; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           vmovupd xmm0, [rcx + rax]; 
           vaddpd xmm0, xmm0, xmm3; 

           vmovupd [rcx + rax], xmm0; 
       add rax, 16;
       jnz @addforxloop2;

       @nextLine:

       // special care of the last column:
       vmovsd xmm0, [rcx]; 
       vaddsd xmm0, xmm0, xmm3; 
       vmovsd [rcx], xmm0; 

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;


end.
