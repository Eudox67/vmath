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


unit AVXMatrixMinMaxOperationsx64;

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


uses MatrixConst;

function AVXMatrixMaxAligned(mt : PDouble; width, height : NativeInt; const LineWidth : NativeInt) : double; assembler;
function AVXMatrixMaxUnAligned(mt : PDouble; width, height : NativeInt; const LineWidth : NativeInt) : double; assembler;

function AVXMatrixMinAligned(mt : PDouble; width, height : NativeInt; const LineWidth : NativeInt) : double; assembler;
function AVXMatrixMinUnAligned(mt : PDouble; width, height : NativeInt; const LineWidth : NativeInt) : double; assembler;

// in matrix max/min
procedure AVXMatrixMinValUnAligned( dest : PDouble; const LineWidth : NativeInt; width, height : NativeInt; {$IFDEF UNIX}unixMinVal : double {$ELSE} minVal : double {$ENDIF} ); assembler;
procedure AVXMatrixMaxValUnAligned( dest : PDouble; const LineWidth : NativeInt; width, height : NativeInt; {$IFDEF UNIX}unixMaxVal : double {$ELSE} maxVal : double {$ENDIF} ); assembler;

procedure AVXMatrixMinValAligned( dest : PDouble; const LineWidth : NativeInt; width, height : NativeInt; {$IFDEF UNIX}unixMinVal : double {$ELSE} minVal : double {$ENDIF} ); assembler;
procedure AVXMatrixMaxValAligned( dest : PDouble; const LineWidth : NativeInt; width, height : NativeInt; {$IFDEF UNIX}unixMaxVal : double {$ELSE} maxVal : double {$ENDIF} ); assembler;


implementation


function AVXMatrixMaxAligned(mt : PDouble; width, height : NativeInt; const LineWidth : NativeInt) : double; assembler;
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
   // note: RCX = mt, RDX = width, R8 = height, R9 = LineWidth
   // prolog - simulate stack
   sub rsp, $10;
   vmovupd [rsp + $00], xmm4; 

   imul rdx, -8;

   sub rcx, rdx;

   // init result
   lea rax, [rip + cNegMaxDouble];
   vbroadcastsd ymm0, [rax]; 
   vmovapd ymm3, ymm0; 
   vmovapd ymm4, ymm0; 

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, rdx;
       add rax, 128;
       jg @loopEnd;

       @addforxloop:
           // prefetch data...
           // prefetch [rcx + rax];

           // max:
           vmaxpd ymm3, ymm3, [rcx + rax - 128]; 
           vmaxpd ymm4, ymm4, [rcx + rax - 96]; 
           vmaxpd ymm3, ymm3, [rcx + rax - 64]; 
           vmaxpd ymm4, ymm4, [rcx + rax - 32]; 

       add rax, 128;
       jle @addforxloop;

       vextractf128 xmm2, ymm3, 1; 
       vmaxpd xmm2, xmm2, xmm3; 
       vmaxpd xmm0, xmm0, xmm2; 
       vextractf128 xmm2, ymm4, 1; 
       vmaxpd xmm2, xmm2, xmm4; 
       vmaxpd xmm0, xmm0, xmm2; 

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @addforxloop2end;

           vmaxpd xmm0, xmm0, [rcx + rax - 16]; 
       jmp @addforxloop2;

       @addforxloop2end:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm2, [rcx + rax]; 
       vmaxsd xmm0, xmm0, xmm2; 

       @nextLine:

       // next line:
       add rcx, r9;

   // loop y end
   dec r8;
   jnz @@addforyloop;

   // final max ->
   vmovhlps xmm1, xmm1, xmm0; 
   vmaxsd xmm0, xmm0, xmm1; 

   // epilog - cleanup stack
   vmovupd xmm4, [rsp + $00]; 
   add rsp, $10;
   vzeroupper; 
end;

function AVXMatrixMaxUnAligned(mt : PDouble; width, height : NativeInt; const LineWidth : NativeInt) : double; assembler;
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

   // note: RCX = mt, RDX = width, R8 = height, R9 = LineWidth
   // prolog - simulate stack
   sub rsp, $10;
   vmovupd [rsp + $00], xmm4; 

   imul rdx, -8;

   sub rcx, rdx;

   // init result
   lea rax, [rip + cNegMaxDouble];
   vbroadcastsd ymm0, [rax]; 
   vmovapd ymm3, ymm0; 
   vmovapd ymm4, ymm0; 

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, rdx;

       add rax, 128;
       jg @loopEnd;

       @addforxloop:
           // prefetch data...
           // prefetch [rcx + rax];

           // max:
           vmovupd ymm2, [rcx + rax - 128]; 
           vmaxpd ymm3, ymm3, ymm2; 
           vmovupd ymm2, [rcx + rax - 96]; 
           vmaxpd ymm4, ymm4, ymm2; 
           vmovupd ymm2, [rcx + rax - 64]; 
           vmaxpd ymm3, ymm3, ymm2; 
           vmovupd ymm2, [rcx + rax - 32]; 
           vmaxpd ymm4, ymm4, ymm2; 
       add rax, 128;
       jle @addforxloop;

       vextractf128 xmm2, ymm3, 1; 
       vmaxpd xmm2, xmm2, xmm3; 
       vmaxpd xmm0, xmm0, xmm2; 
       vextractf128 xmm2, ymm4, 1; 
       vmaxpd xmm2, xmm2, xmm4; 
       vmaxpd xmm0, xmm0, xmm2; 

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @addforxloop2end;

           vmovupd xmm2, [rcx + rax - 16]; 
           vmaxpd xmm0, xmm0, xmm2; 
       jmp @addforxloop2;

       @addforxloop2end:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm2, [rcx + rax]; 
       vmaxsd xmm0, xmm0, xmm2; 

       @nextLine:

       // next line:
       add rcx, r9;

   // loop y end
   dec r8;
   jnz @@addforyloop;

   // final max ->
   vmovhlps xmm1, xmm1, xmm0; 
   vmaxsd xmm0, xmm0, xmm1; 

   // epilog - cleanup stack
   vmovupd xmm4, [rsp + $00]; 
   add rsp, $10;
   vzeroupper; 
end;

function AVXMatrixMinAligned(mt : PDouble; width, height : NativeInt; const LineWidth : NativeInt) : double; assembler;
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

   // note: RCX = mt, RDX = width, R8 = height, R9 = LineWidth
   // prolog - simulate stack
   sub rsp, $10;
   vmovupd [rsp + $00], xmm4; 

   imul rdx, -8;

   sub rcx, rdx;

   // init result
   lea rax, [rip + cMaxDouble];
   vbroadcastsd ymm0, [rax]; 
   vmovapd ymm3, ymm0; 
   vmovapd ymm4, ymm0; 

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, rdx;
       add rax, 128;
       jg @loopEnd;

       @addforxloop:
           // prefetch data...
           // prefetch [rcx + rax];

           // max:
           vminpd ymm3, ymm3, [rcx + rax - 128]; 
           vminpd ymm4, ymm4, [rcx + rax - 96]; 
           vminpd ymm3, ymm3, [rcx + rax - 64]; 
           vminpd ymm4, ymm4, [rcx + rax - 32]; 
       add rax, 128;
       jle @addforxloop

       vextractf128 xmm2, ymm3, 1; 
       vminpd xmm2, xmm2, xmm3; 
       vminpd xmm0, xmm0, xmm2; 
       vextractf128 xmm2, ymm4, 1; 
       vminpd xmm2, xmm2, xmm4; 
       vminpd xmm0, xmm0, xmm2; 

       @loopEnd:
       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @addforxloop2end;

           vminpd xmm0, xmm0, [rcx + rax - 16]; 
       jmp @addforxloop2;

       @addforxloop2end:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm2, [rcx + rax]; 
       vminsd xmm0, xmm0, xmm2; 

       @nextLine:

       // next line:
       add rcx, r9;

   // loop y end
   dec r8;
   jnz @@addforyloop;

   // final min ->
   vmovhlps xmm1, xmm1, xmm0; 
   vminsd xmm0, xmm0, xmm1; 

   // epilog - cleanup stack
   vmovupd xmm4, [rsp + $00]; 
   add rsp, $10;
   vzeroupper; 
end;

function AVXMatrixMinUnAligned(mt : PDouble; width, height : NativeInt; const LineWidth : NativeInt) : double; assembler;
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

   // note: RCX = mt, RDX = width, R8 = height, R9 = LineWidth
   // prolog - simulate stack
   sub rsp, $10;
   vmovupd [rsp + $00], xmm4; 

   imul rdx, -8;

   sub rcx, rdx;

   // init result
   lea rax, [rip + cMaxDouble];
   vbroadcastsd ymm0, [rax]; 
   vmovapd ymm3, ymm0; 
   vmovapd ymm4, ymm0; 

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, rdx;
       add rax, 128;
       jg @loopEnd;

       @addforxloop:
           // prefetch data...
           // prefetch [rcx + rax];

           // max:
           vmovupd ymm2, [rcx + rax - 128]; 
           vminpd ymm3, ymm3, ymm2; 
           vmovupd ymm2, [rcx + rax - 96]; 
           vminpd ymm4, ymm4, ymm2; 
           vmovupd ymm2, [rcx + rax - 64]; 
           vminpd ymm3, ymm3, ymm2; 
           vmovupd ymm2, [rcx + rax - 32]; 
           vminpd ymm4, ymm4, ymm2; 
       add rax, 128;
       jle @addforxloop

       vextractf128 xmm2, ymm3, 1; 
       vminpd xmm2, xmm2, xmm3; 
       vminpd xmm0, xmm0, xmm2; 
       vextractf128 xmm2, ymm4, 1; 
       vminpd xmm2, xmm2, xmm4; 
       vminpd xmm0, xmm0, xmm2; 

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @addforxloop2end;

           vmovupd xmm2, [rcx + rax - 16]; 
           vminpd xmm0, xmm0, xmm2; 
       jmp @addforxloop2;

       @addforxloop2end:
       sub rax, 16;
       jz @nextLine;

       vmovsd xmm2, [rcx + rax]; 
       vminsd xmm0, xmm0, xmm2; 

       @nextLine:

       // next line:
       add rcx, r9;

   // loop y end
   dec r8;
   jnz @@addforyloop;

   // final max ->
   vmovhlps xmm1, xmm1, xmm0; 
   vminsd xmm0, xmm0, xmm1; 

   // epilog - cleanup stack
   vmovupd xmm4, [rsp + $00]; 
   add rsp, $10;
   vzeroupper; 
end;

procedure AVXMatrixMinValUnAligned( dest : PDouble; const LineWidth : NativeInt; width, height : NativeInt;{$IFDEF UNIX}unixMinVal : double {$ELSE} minVal : double {$ENDIF}); assembler;
// rcx = dest; rdx = LineWidth, r8 = Width, r9 = height; xmm0 = unixMinVal
{$IFDEF UNIX}
var minVal : double;
{$ENDIF}
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
   movsd minVal, xmm0;
   {$ENDIF}

   imul r8, -8;

   // helper registers for the dest pointer
   sub rcx, r8;

   lea rax, minVal;
   vbroadcastsd ymm0, [rax]; 

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
           vminpd ymm1, ymm1, ymm0; 
           vmovupd [rcx + rax - 128], ymm1; 

           vmovupd ymm2, [rcx + rax - 96]; 
           vminpd ymm2, ymm2, ymm0; 
           vmovupd [rcx + rax - 96], ymm2; 

           vmovupd ymm3, [rcx + rax - 64]; 
           vminpd ymm3, ymm3, ymm0; 
           vmovupd [rcx + rax - 64], ymm3; 

           vmovupd ymm4, [rcx + rax - 32]; 
           vminpd ymm4, ymm4, ymm0; 
           vmovupd [rcx + rax - 32], ymm4; 
       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @loopEnd2;

           vmovupd xmm1, [rcx + rax - 16]; 
           vminpd xmm1, xmm1, xmm0; 
           vmovupd [rcx + rax - 16], xmm1; 
       jmp @addforxloop2;

       @loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm1, [rcx + rax]; 
       vminsd xmm1, xmm1, xmm0; 
       vmovsd [rcx + rax], xmm1; 

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   vzeroupper; 
end;


procedure AVXMatrixMaxValUnAligned( dest : PDouble; const LineWidth : NativeInt; width, height : NativeInt; {$IFDEF UNIX}unixMaxVal : double {$ELSE} maxVal : double {$ENDIF} ); assembler;
// rcx = dest; rdx = LineWidth, r8 = Width, r9 = height, unix: xmm0 = unixmaxval
{$IFDEF UNIX}
var maxVal : double;
{$ENDIF}
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
   movsd maxVal, xmm0;
   {$ENDIF}

   imul r8, -8;

   // helper registers for the dest pointer
   sub rcx, r8;

   lea rax, maxVal;
   vbroadcastsd ymm0, [rax]; 

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
           vmaxpd ymm1, ymm1, ymm0; 
           vmovupd [rcx + rax - 128], ymm1; 

           vmovupd ymm2, [rcx + rax - 96]; 
           vmaxpd ymm2, ymm2, ymm0; 
           vmovupd [rcx + rax - 96], ymm2; 

           vmovupd ymm3, [rcx + rax - 64]; 
           vmaxpd ymm3, ymm3, ymm0; 
           vmovupd [rcx + rax - 64], ymm3; 

           vmovupd ymm4, [rcx + rax - 32]; 
           vmaxpd ymm4, ymm4, ymm0; 
           vmovupd [rcx + rax - 32], ymm4; 
       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @loopEnd2;

           vmovupd xmm1, [rcx + rax - 16]; 
           vmaxpd xmm1, xmm1, xmm0; 
           vmovupd [rcx + rax - 16], xmm1; 
       jmp @addforxloop2;

       @loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm1, [rcx + rax]; 
       vmaxsd xmm1, xmm1, xmm0; 
       vmovsd [rcx + rax], xmm1; 

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   vzeroupper; 
end;


procedure AVXMatrixMinValAligned( dest : PDouble; const LineWidth : NativeInt; width, height : NativeInt; {$IFDEF UNIX}unixMinVal : double {$ELSE} minVal : double {$ENDIF} ); assembler;
// rcx = dest; rdx = LineWidth, r8 = Width, r9 = height
{$IFDEF UNIX}
var minVal : double;
{$ENDIF}
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
   movsd minVal, xmm0;
   {$ENDIF}

   imul r8, -8;

   // helper registers for the dest pointer
   sub rcx, r8;

   lea rax, minVal;
   vbroadcastsd ymm0, [rax]; 

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
           vminpd ymm1, ymm0, [rcx + rax - 128]; 
           vmovapd [rcx + rax - 128], ymm1; 

           vminpd ymm2, ymm0, [rcx + rax - 96]; 
           vmovapd [rcx + rax - 96], ymm2; 

           vminpd ymm3, ymm0, [rcx + rax - 64]; 
           vmovapd [rcx + rax - 64], ymm3; 

           vminpd ymm4, ymm0, [rcx + rax - 32]; 
           vmovapd [rcx + rax - 32], ymm4; 
       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @loopEnd2;

           vminpd xmm1, xmm0, [rcx + rax - 16]; 
           vmovapd [rcx + rax - 16], xmm1; 
       jmp @addforxloop2;

       @loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm1, [rcx + rax]; 
       vminsd xmm1, xmm1, xmm0; 
       vmovsd [rcx + rax], xmm1; 

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   vzeroupper; 
end;

procedure AVXMatrixMaxValAligned( dest : PDouble; const LineWidth : NativeInt; width, height : NativeInt; {$IFDEF UNIX}unixMaxVal : double {$ELSE} maxVal : double {$ENDIF} ); assembler;
// rcx = dest; rdx = LineWidth, r8 = Width, r9 = height
{$IFDEF UNIX}
var maxVal : double;
{$ENDIF}
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
   movsd maxVal, xmm0;
   {$ENDIF}

   imul r8, -8;

   // helper registers for the dest pointer
   sub rcx, r8;

   lea rax, maxVal;
   vbroadcastsd ymm0, [rax]; 

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
           vmaxpd ymm1, ymm0, [rcx + rax - 128]; 
           vmovapd [rcx + rax - 128], ymm1; 

           vmaxpd ymm2, ymm0, [rcx + rax - 96]; 
           vmovapd [rcx + rax - 96], ymm2; 

           vmaxpd ymm3, ymm0, [rcx + rax - 64]; 
           vmovapd [rcx + rax - 64], ymm3; 

           vmaxpd ymm4, ymm0, [rcx + rax - 32]; 
           vmovapd [rcx + rax - 32], ymm4; 
       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
           add rax, 16;
           jg @loopEnd2;

           vmaxpd xmm1, xmm0, [rcx + rax - 16]; 
           vmovapd [rcx + rax - 16], xmm1; 
       jmp @addforxloop2;

       @loopEnd2:

       sub rax, 16;
       jz @nextLine;

       vmovsd xmm1, [rcx + rax]; 
       vmaxsd xmm1, xmm1, xmm0; 
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
