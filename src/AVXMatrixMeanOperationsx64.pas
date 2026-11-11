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


unit AVXMatrixMeanOperationsx64;

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


uses MatrixConst;

procedure AVXMatrixMeanRowAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixMeanRowUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXMatrixMeanColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixMeanColumnUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXMatrixVarRowAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
procedure AVXMatrixVarRowUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;

procedure AVXMatrixVarColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
procedure AVXMatrixVarColumnUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;


// combined methods
procedure AVXMatrixMeanVarRowAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
procedure AVXMatrixMeanVarRowUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;

procedure AVXMatrixMeanVarColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
procedure AVXMatrixMeanVarColumnUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;


implementation


procedure AVXMatrixMeanRowAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
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

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth

   // prolog

   // iters := -width*sizeof(double)
   mov r10, width;
   imul r10, -8;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;
   
   vcvtsi2sd xmm3, xmm3, width;

   // for y := 0 to height - 1:
   mov r11, Height;
   @@addforyloop:
       vxorpd ymm0, ymm0, ymm0; 
       vxorpd ymm1, ymm1, ymm1; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;
           // prefetch data...
           // prefetch [r8 + rax];

           // addition:
           vaddpd ymm0, ymm0, [r8 + rax - 128]; 
           vaddpd ymm1, ymm1, [r8 + rax - 96]; 
           vaddpd ymm0, ymm0, [r8 + rax - 64]; 
           vaddpd ymm1, ymm1, [r8 + rax - 32]; 
       jmp @addforxloop

       @loopEnd:

       vaddpd ymm0, ymm0, ymm1; 
       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       sub rax, 128;

       jz @buildRes;

       @addforxloop2:
           add rax, 16;
           jg @@addforxloop2end;

           vaddpd xmm0, xmm0, [r8 + rax - 16]; 
       jmp @addforxloop2;

       @@addforxloop2end:

       sub rax, 16;
       jz @buildRes;

       vaddsd xmm0, xmm0, [r8 + rax]; 

       @buildRes:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 

       vdivsd xmm0, xmm0, xmm3; 

       // write result
       vmovsd [rcx], xmm0; 

       // next line:
       add r8, r9;
       add rcx, rdx;

   // loop y end
   dec r11;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;

procedure AVXMatrixMeanRowUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
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

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth

   // prolog

   // iters := -width*sizeof(double)
   mov r10, width;
   imul r10, -8;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm3, xmm3, width;

   // for y := 0 to height - 1:
   mov r11, Height;
   @@addforyloop:
       vxorpd ymm0, ymm0, ymm0; 
       vxorpd ymm1, ymm1, ymm1; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;
           // prefetch data...
           // prefetch [r8 + rax];

           // addition:
           vmovupd ymm2, [r8 + rax - 128]; 
           vaddpd ymm0, ymm0, ymm2; 
           vmovupd ymm2, [r8 + rax - 96]; 
           vaddpd ymm1, ymm1, ymm2; 
           vmovupd ymm2, [r8 + rax - 64]; 
           vaddpd ymm0, ymm0, ymm2; 
           vmovupd ymm2, [r8 + rax - 32]; 
           vaddpd ymm1, ymm1, ymm2; 
       jmp @addforxloop

       @loopEnd:

       vaddpd ymm0, ymm0, ymm1; 
       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       sub rax, 128;

       jz @buildRes;

       @addforxloop2:
           add rax, 16;
           jg @@addforxloop2end;

           vmovupd xmm2, [r8 + rax - 16]; 
           vaddpd xmm0, xmm0, xmm2; 
       jmp @addforxloop2;

       @@addforxloop2end:

       sub rax, 16;
       jz @buildRes;

       vaddsd xmm0, xmm0, [r8 + rax]; 

       @buildRes:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 

       vdivsd xmm0, xmm0, xmm3; 

       // write result
       vmovsd [rcx], xmm0; 

       // next line:
       add r8, r9;
       add rcx, rdx;

   // loop y end
   dec r11;
   jnz @@addforyloop;

   // epilog
   vzeroupper; 
end;

procedure AVXMatrixMeanColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var tmp : double;
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

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth
   xor r10, r10;
   sub r10, height;
   imul r10, r9;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm0, xmm0, height;
   
   lea rax, tmp;
   vmovsd [rax], xmm0; 
   vbroadcastsd ymm2, [rax]; // vbroadcastsd ymm2, xmm0; // avx2

   // for x := 0 to width - 1:
   mov r11, Width;
   sub r11, 4;
   jl @@addforxloop4end;

   // 4 columns at once
   @@addforxloop4:
       vxorpd ymm1, ymm1, ymm1; 

       // for y := 0 to height - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforyloop4:
           vaddpd ymm1, ymm1, [r8 + rax]; 
       add rax, r9;
       jnz @addforyloop4;

       // build result
       vdivpd ymm1, ymm1, ymm2; 
       vmovapd [rcx], ymm1; 

       // next columns:
       add rcx, 32;
       add r8, 32;

   // loop x end
   sub r11, 4;
   jge @@addforxloop4;

   @@addforxloop4end:

   add r11, 4;
   jz @@endProc;

   sub r11, 2;
   jl @@lastcolumn;

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop2:
       vaddpd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop2;

   // build result
   vdivpd xmm1, xmm1, xmm2; 
   vmovapd [rcx], xmm1; 

   // next columns:
   add rcx, 16;
   add r8, 16;

   dec r11;
   jnz @@endProc;

   @@lastcolumn:

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop:
       vaddsd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop;

   // build result
   vdivsd xmm1, xmm1, xmm2; 
   vmovsd [rcx], xmm1; 

   @@endProc:
   vzeroupper; 
end;

procedure AVXMatrixMeanColumnUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
var tmp : double; // for broadcastsd
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

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth
   xor r10, r10;
   sub r10, height;
   imul r10, r9;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;
   
   vcvtsi2sd xmm0, xmm0, height;
   
   lea rax, tmp;
   vmovsd [rax], xmm0; 
   vbroadcastsd ymm2, [rax]; 

   // for x := 0 to width - 1:
   mov r11, Width;
   sub r11, 4;
   jl @@addforxloop4end;

   // 4 columns at once
   @@addforxloop4:
       vxorpd ymm1, ymm1, ymm1; 

       // for y := 0 to height - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforyloop4:
           vmovupd ymm0, [r8 + rax]; 
           vaddpd ymm1, ymm1, ymm0; 
       add rax, r9;
       jnz @addforyloop4;

       // build result
       vdivpd ymm1, ymm1, ymm2; 
       vmovupd [rcx], ymm1;

       // next columns:
       add rcx, 32;
       add r8, 32;

   // loop x end
   sub r11, 4;
   jge @@addforxloop4;

   @@addforxloop4end:

   add r11, 4;
   jz @@endProc;

   sub r11, 2;
   jl @@lastcolumn;

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop2:
       vmovupd xmm0, [r8 + rax]; 
       vaddpd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop2;

   // build result
   vdivpd xmm1, xmm1, xmm2; 
   vmovupd [rcx], xmm1; 

   // next columns:
   add rcx, 16;
   add r8, 16;

   dec r11;
   jnz @@endProc;

   @@lastcolumn:

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop:
       vaddsd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop;

   // build result
   vdivsd xmm1, xmm1, xmm2; 
   vmovsd [rcx], xmm1; 


   @@endProc:
   vzeroupper; 
end;

// ###########################################
// #### Variance calculation
// ###########################################


procedure AVXMatrixVarRowAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
var tmp : double;
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

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth

   // prolog
   sub rsp, $10;
   vmovupd [rsp + $00], xmm4; 

   // iters := -width*sizeof(double)
   mov r10, width;
   shl r10, 3;
   imul r10, -1;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm3, xmm3, width;

   // for y := 0 to height - 1:
   mov r11, Height;
   @@addforyloop:
       vxorpd ymm0, ymm0, ymm0; 
       vxorpd ymm1, ymm1, ymm1; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;
           // prefetch data...
           // prefetch [r8 + rax];

           // addition:
           vaddpd ymm0, ymm0, [r8 + rax - 128]; 
           vaddpd ymm1, ymm1, [r8 + rax - 96]; 
           vaddpd ymm0, ymm0, [r8 + rax - 64]; 
           vaddpd ymm1, ymm1, [r8 + rax - 32]; 
       jmp @addforxloop

       @loopEnd:

       vaddpd ymm0, ymm0, ymm1; 
       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       sub rax, 128;

       jz @buildRes;

       @addforxloop2:
           add rax, 16;
           jg @@addforxloop2end;

           vaddpd xmm0, xmm0, [r8 + rax - 16]; 
       jmp @addforxloop2;

       @@addforxloop2end:

       sub rax, 16;
       jz @buildRes;

       vaddsd xmm0, xmm0, [r8 + rax]; 

       @buildRes:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 
       vdivsd xmm0, xmm0, xmm3; 

       // we have calculated the mean ->
       // repeat the loop to calculate the variance
       lea rax, tmp;
       vmovsd [rax], xmm0; 
       vbroadcastsd ymm4, [rax]; 
       vxorpd xmm0, xmm0, xmm0; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       // variance = sum (x - mean)^2
       mov rax, r10;
       @addforxloop3:
           add rax, 128;
           jg @loopEnd2;
           // prefetch data...
           // prefetch [ecx + rax];

           // addition:
           vmovapd ymm1, [r8 + rax - 128]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovapd ymm1, [r8 + rax - 96]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovapd ymm1, [r8 + rax - 64]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovapd ymm1, [r8 + rax - 32]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

       jmp @addforxloop3

       @loopEnd2:

       sub rax, 128;

       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       jz @buildRes2;

       @addforxloop4:
           add rax, 16;
           jg @addforxloop4end;

           vmovapd xmm1, [r8 + rax - 16]; 
           vsubpd xmm1, xmm1, xmm4; 
           vmulpd xmm1, xmm1, xmm1; 
           vaddpd xmm0, xmm0, xmm1; 
       jmp @addforxloop4;

       @addforxloop4end:

       sub rax, 16;
       jz @buildRes2;

       // last column
       vmovsd xmm1, [r8 + rax]; 
       vsubsd xmm1, xmm1, xmm4; 
       vmulsd xmm1, xmm1, xmm1; 
       vaddsd xmm0, xmm0, xmm1; 


       @buildRes2:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 

       // check if we need to use the unbiased version
       cmp unbiased, 0;
       jz @@dobiased;

       lea rax, [rip + cOne];
       vmovsd xmm2, [rax]; 
       vsubsd xmm4, xmm3, xmm2; 
       vmaxsd xmm4, xmm4, xmm2; 

       vdivsd xmm0, xmm0, xmm4; 

       jmp @@writeRes;

       @@dobiased:
       vdivsd xmm0, xmm0, xmm3; 

       // write result
       @@writeRes:
       vmovsd [rcx], xmm0; 

       // next line:
       add r8, r9;
       add rcx, rdx;

   // loop y end
   dec r11;
   jnz @@addforyloop;

   // epilog
   vmovupd xmm4, [rsp + $00]; 
   add rsp, $10;
   vzeroupper; 
end;

procedure AVXMatrixVarRowUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
var tmp : double;
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

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth

   // prolog
   sub rsp, $10;
   vmovupd [rsp + $00], xmm4; 

   // iters := -width*sizeof(double)
   mov r10, width;
   shl r10, 3;
   imul r10, -1;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm3, xmm3, width;

   // for y := 0 to height - 1:
   mov r11, Height;
   @@addforyloop:
       vxorpd ymm0, ymm0, ymm0; 
       vxorpd ymm1, ymm1, ymm1; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;
           // prefetch data...
           // prefetch [r8 + rax];

           // addition:
           vmovupd ymm2, [r8 + rax - 128]; 
           vaddpd ymm0, ymm0, ymm2; 
           vmovupd ymm2, [r8 + rax - 96]; 
           vaddpd ymm1, ymm1, ymm2; 
           vmovupd ymm2, [r8 + rax - 64]; 
           vaddpd ymm0, ymm0, ymm2; 
           vmovupd ymm2, [r8 + rax - 32]; 
           vaddpd ymm1, ymm1, ymm2; 
       jmp @addforxloop

       @loopEnd:

       vaddpd ymm0, ymm0, ymm1; 
       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       sub rax, 128;

       jz @buildRes;

       @addforxloop2:
           add rax, 16;
           jg @@addforxloop2end;

           vmovupd xmm2, [r8 + rax - 16]; 
           vaddpd xmm0, xmm0, xmm2; 
       jmp @addforxloop2;

       @@addforxloop2end:

       sub rax, 16;
       jz @buildRes;

       vaddsd xmm0, xmm0, [r8 + rax]; 

       @buildRes:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 
       vdivsd xmm0, xmm0, xmm3; 

       // we have calculated the mean ->
       // repeat the loop to calculate the variance
       lea rax, tmp;
       vmovsd [rax], xmm0; 
       vbroadcastsd ymm4, [rax]; 
       vxorpd xmm0, xmm0, xmm0; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       // variance = sum (x - mean)^2
       mov rax, r10;
       @addforxloop3:
           add rax, 128;
           jg @loopEnd2;
           // prefetch data...
           // prefetch [ecx + rax];

           // addition:
           vmovupd ymm1, [r8 + rax - 128]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovupd ymm1, [r8 + rax - 96]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovupd ymm1, [r8 + rax - 64]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovupd ymm1, [r8 + rax - 32]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

       jmp @addforxloop3

       @loopEnd2:

       sub rax, 128;

       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       jz @buildRes2;

       @addforxloop4:
           add rax, 16;
           jg @addforxloop4end;

           vmovupd xmm1, [r8 + rax - 16]; 
           vsubpd xmm1, xmm1, xmm4; 
           vmulpd xmm1, xmm1, xmm1; 
           vaddpd xmm0, xmm0, xmm1; 
       jmp @addforxloop4;

       @addforxloop4end:

       sub rax, 16;
       jz @buildRes2;

       // last column
       vmovsd xmm1, [r8 + rax]; 
       vsubsd xmm1, xmm1, xmm4; 
       vmulsd xmm1, xmm1, xmm1; 
       vaddsd xmm0, xmm0, xmm1; 


       @buildRes2:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 

       // check if we need to use the unbiased version
       cmp unbiased, 0;
       jz @@dobiased;

       lea rax, [rip + cOne];
       vmovsd xmm2, [rax]; 
       vsubsd xmm4, xmm3, xmm2; 
       vmaxsd xmm4, xmm4, xmm2; 

       vdivsd xmm0, xmm0, xmm4; 

       jmp @@writeRes;

       @@dobiased:
       vdivsd xmm0, xmm0, xmm3; 

       // write result
       @@writeRes:
       vmovsd [rcx], xmm0; 

       // next line:
       add r8, r9;
       add rcx, rdx;

   // loop y end
   dec r11;
   jnz @@addforyloop;

   // epilog
   vmovupd xmm4, [rsp + $00]; 
   add rsp, $10;
   vzeroupper; 
end;

procedure AVXMatrixVarColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
var tmp : double;
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

   // prolog
   sub rsp, $20;
   vmovupd [rsp + $00], xmm4; 
   vmovupd [rsp + $10], xmm5; 

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth
   xor r10, r10;
   sub r10, height;
   imul r10, r9;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm0, xmm0, height;
   
   lea rax, tmp;
   vmovsd [rax], xmm0; 
   vbroadcastsd ymm2, [rax]; // vbroadcastsd ymm2, xmm0;  // is avx2

   lea rax, [rip + cOne];
   vbroadcastsd ymm5, [rax]; 


   // for x := 0 to width - 1:
   mov r11, Width;
   sub r11, 4;
   jl @@addforxloop4end;

   // 4 columns at once
   @@addforxloop4:
       vxorpd ymm1, ymm1, ymm1; 

       // for y := 0 to height - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforyloop4:
           vaddpd ymm1, ymm1, [r8 + rax]; 
       add rax, r9;
       jnz @addforyloop4;

       // build result
       vdivpd ymm0, ymm1, ymm2; 

       // calculate final standard deviation
       // for y := 0 to height - 1;
       // prepare for reverse loop
       vxorpd ymm4, ymm4, ymm4; 
       mov rax, r10;
       @addforyloop4_2:
           vmovapd ymm1, [r8 + rax]; 
           vsubpd ymm1, ymm1, ymm0; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm4, ymm4, ymm1; 
       add rax, r9;
       jnz @addforyloop4_2;

       // check if we need to use the unbiased version
       cmp unbiased, 0;
       jz @@dobiased_4;

       lea rax, [rip + cOne];

       vbroadcastsd ymm1, [rax]; 
       vsubpd ymm3, ymm2, ymm1; 
       vmaxpd ymm3, ymm3, ymm1; 

       vdivpd ymm4, ymm4, ymm3; 

       jmp @@writeRes_4;

       @@dobiased_4:
       vdivpd ymm4, ymm4, ymm2; 

       // write result
       @@writeRes_4:
       vmovapd [rcx], ymm4; 

       // next columns:
       add rcx, 32;
       add r8, 32;

   // loop x end
   sub r11, 4;
   jge @@addforxloop4;

   @@addforxloop4end:

   add r11, 4;
   jz @@endProc;

   sub r11, 2;
   jl @@lastcolumn;

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop2:
       vaddpd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop2;

   // build result
   vdivpd xmm0, xmm1, xmm2; 

   // calculate final standard deviation
   // for y := 0 to height - 1;
   // prepare for reverse loop
   vxorpd xmm4, xmm4, xmm4; 
   mov rax, r10;
   @addforyloop2_2:
      vmovapd xmm1, [r8 + rax]; 
      vsubpd xmm1, xmm1, xmm0; 
      vmulpd xmm1, xmm1, xmm1; 
      vaddpd xmm4, xmm4, xmm1; 
   add rax, r9;
   jnz @addforyloop2_2;

   // check if we need to use the unbiased version
   cmp unbiased, 0;
   jz @@dobiased_2;

   vsubpd xmm3, xmm2, xmm5; 
   vmaxpd xmm3, xmm3, xmm5; 

   vdivpd xmm4, xmm4, xmm3; 

   jmp @@writeRes2;

   @@dobiased_2:
   vdivpd xmm4, xmm4, xmm2; 

   // write result
   @@writeRes2:
   vmovapd [rcx], xmm4; 

   // next columns:
   add rcx, 16;
   add r8, 16;

   dec r11;
   jnz @@endProc;

   @@lastcolumn:

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop_1:
       vaddsd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop_1;

   // build result
   vdivsd xmm0, xmm1, xmm2; 

   // calculate final standard deviation
   // for y := 0 to height - 1;
   // prepare for reverse loop
   vxorpd xmm4, xmm4, xmm4; 
   mov rax, r10;
   @addforyloop1_2:
      vmovsd xmm1, [r8 + rax]; 
      vsubsd xmm1, xmm1, xmm0; 
      vmulsd xmm1, xmm1, xmm1; 
      vaddsd xmm4, xmm4, xmm1; 
   add rax, r9;
   jnz @addforyloop1_2;

   // check if we need to use the unbiased version
   cmp unbiased, 0;
   jz @@dobiased_2;

   vmovsd xmm3, xmm3, xmm2; 
   vsubsd xmm3, xmm3, xmm5; 
   vmaxsd xmm3, xmm3, xmm5; 

   vdivsd xmm4, xmm4, xmm3; 

   jmp @@writeRes_1;

   @@dobiased_1:
   vdivsd xmm4, xmm4, xmm2; 

   // write result
   @@writeRes_1:
   vmovsd [rcx], xmm4; 


   @@endProc:

   // epilog
   vmovupd xmm4, [rsp + $00]; 
   vmovupd xmm5, [rsp + $10]; 
   add rsp, $20;
   vzeroupper; 
end;

procedure AVXMatrixVarColumnUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
var tmp : double;
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

   // prolog
   sub rsp, $20;
   vmovupd [rsp + $00], xmm4; 
   vmovupd [rsp + $10], xmm5; 

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth
   xor r10, r10;
   sub r10, height;
   imul r10, r9;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm0, xmm0, height;
   
   lea rax, tmp;
   vmovsd [rax], xmm0; 
   vbroadcastsd ymm2, [rax]; // vbroadcastsd ymm2, xmm0; // avx2

   lea rax, [rip + cOne];
   vbroadcastsd ymm5, [rax]; 

   // for x := 0 to width - 1:
   mov r11, Width;
   sub r11, 4;
   jl @@addforxloop4end;

   // 4 columns at once
   @@addforxloop4:
       vxorpd ymm1, ymm1, ymm1; 

       // for y := 0 to height - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforyloop4:
           vmovupd ymm3, [r8 + rax]; 
           vaddpd ymm1, ymm1, ymm3; 
       add rax, r9;
       jnz @addforyloop4;

       // build result
       vdivpd ymm0, ymm1, ymm2; 

       // calculate final standard deviation
       // for y := 0 to height - 1;
       // prepare for reverse loop
       vxorpd ymm4, ymm4, ymm4; 
       mov rax, r10;
       @addforyloop4_2:
           vmovupd ymm1, [r8 + rax]; 
           vsubpd ymm1, ymm1, ymm0; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm4, ymm4, ymm1; 
       add rax, r9;
       jnz @addforyloop4_2;

       // check if we need to use the unbiased version
       cmp unbiased, 0;
       jz @@dobiased_4;

       vsubpd ymm3, ymm2, ymm5; 
       vmaxpd ymm3, ymm3, ymm5; 

       vdivpd ymm4, ymm4, ymm3; 

       jmp @@writeRes_4;

       @@dobiased_4:
       vdivpd ymm4, ymm4, ymm2; 

       // write result
       @@writeRes_4:
       vmovupd [rcx], ymm4; 

       // next columns:
       add rcx, 32;
       add r8, 32;

   // loop x end
   sub r11, 4;
   jge @@addforxloop4;

   @@addforxloop4end:

   add r11, 4;
   jz @@endProc;

   sub r11, 2;
   jl @@lastcolumn;

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop2:
       vmovupd xmm3, [r8 + rax]; 
       vaddpd xmm1, xmm1, xmm3; 
   add rax, r9;
   jnz @addforyloop2;

   // build result
   vdivpd xmm0, xmm1, xmm2; 

   // calculate final standard deviation
   // for y := 0 to height - 1;
   // prepare for reverse loop
   vxorpd xmm4, xmm4, xmm4; 
   mov rax, r10;
   @addforyloop2_2:
      vmovupd xmm1, [r8 + rax]; 
      vsubpd xmm1, xmm1, xmm0; 
      vmulpd xmm1, xmm1, xmm1; 
      vaddpd xmm4, xmm4, xmm1; 
   add rax, r9;
   jnz @addforyloop2_2;

   // check if we need to use the unbiased version
   cmp unbiased, 0;
   jz @@dobiased_2;

   vsubpd xmm3, xmm2, xmm5; 
   vmaxpd xmm3, xmm3, xmm5; 

   vdivpd xmm4, xmm4, xmm3; 

   jmp @@writeRes2;

   @@dobiased_2:
   vdivpd xmm4, xmm4, xmm2; 

   // write result
   @@writeRes2:
   vmovupd [rcx], xmm4; 

   // next columns:
   add rcx, 16;
   add r8, 16;

   dec r11;
   jnz @@endProc;

   @@lastcolumn:

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop_1:
       vaddsd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop_1;

   // build result
   vdivsd xmm0, xmm1, xmm2; 

   // calculate final standard deviation
   // for y := 0 to height - 1;
   // prepare for reverse loop
   vxorpd xmm4, xmm4, xmm4; 
   mov rax, r10;
   @addforyloop1_2:
      vmovsd xmm1, [r8 + rax]; 
      vsubsd xmm1, xmm1, xmm0; 
      vmulsd xmm1, xmm1, xmm1; 
      vaddsd xmm4, xmm4, xmm1; 
   add rax, r9;
   jnz @addforyloop1_2;

   // check if we need to use the unbiased version
   cmp unbiased, 0;
   jz @@dobiased_2;

   vsubsd xmm3, xmm2, xmm5; 
   vmaxsd xmm3, xmm3, xmm5; 

   vdivsd xmm4, xmm4, xmm3; 

   jmp @@writeRes_1;

   @@dobiased_1:
   vdivsd xmm4, xmm4, xmm2; 

   // write result
   @@writeRes_1:
   vmovsd [rcx], xmm4; 

   @@endProc:

   vmovupd xmm4, [rsp + $00]; 
   vmovupd xmm5, [rsp + $10]; 
   add rsp, $20;
   vzeroupper; 
end;

// #####################################################
// #### Combined mean variance calculation
// #####################################################

procedure AVXMatrixMeanVarRowAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
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

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth

   // prolog
   sub rsp, $10;
   vmovupd [rsp + $00], xmm4; 

   // iters := -width*sizeof(double)
   mov r10, width;
   imul r10, -8;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm3, xmm3, width;

   // for y := 0 to height - 1:
   mov r11, Height;
   @@addforyloop:
       vxorpd ymm0, ymm0, ymm0; 
       vxorpd ymm1, ymm1, ymm1; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;
           // prefetch data...
           // prefetch [r8 + rax];

           // addition:
           vaddpd ymm0, ymm0, [r8 + rax - 128]; 
           vaddpd ymm1, ymm1, [r8 + rax - 96]; 
           vaddpd ymm0, ymm0, [r8 + rax - 64]; 
           vaddpd ymm1, ymm1, [r8 + rax - 32]; 
       jmp @addforxloop

       @loopEnd:

       vaddpd ymm0, ymm0, ymm1; 
       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       sub rax, 128;

       jz @buildRes;

       @addforxloop2:
           add rax, 16;
           jg @@addforxloop2end;

           vaddpd xmm0, xmm0, [r8 + rax - 16]; 
       jmp @addforxloop2;

       @@addforxloop2end:

       sub rax, 16;
       jz @buildRes;

       vaddsd xmm0, xmm0, [r8 + rax]; 

       @buildRes:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 
       vdivsd xmm0, xmm0, xmm3; 
       vmovsd [rcx], xmm0; 

       // we have calculated the mean ->
       // repeat the loop to calculate the variance
       vbroadcastsd ymm4, [rcx]; // need avx2
       vxorpd xmm0, xmm0, xmm0; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       // variance = sum (x - mean)^2
       mov rax, r10;
       @addforxloop3:
           add rax, 128;
           jg @loopEnd2;
           // prefetch data...
           // prefetch [ecx + rax];

           // addition:
           vmovapd ymm1, [r8 + rax - 128]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovapd ymm1, [r8 + rax - 96]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovapd ymm1, [r8 + rax - 64]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovapd ymm1, [r8 + rax - 32]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

       jmp @addforxloop3

       @loopEnd2:

       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       sub rax, 128;
       jz @buildRes2;

       @addforxloop4:
           add rax, 16;
           jg @addforxloop4end;

           vmovapd xmm1, [r8 + rax - 16]; 
           vsubpd xmm1, xmm1, xmm4; 
           vmulpd xmm1, xmm1, xmm1; 
           vaddpd xmm0, xmm0, xmm1; 
       jmp @addforxloop4;

       @addforxloop4end:

       sub rax, 16;
       jz @buildRes2;

       // last column
       vmovsd xmm1, [r8 + rax]; 
       vsubsd xmm1, xmm1, xmm4; 
       vmulsd xmm1, xmm1, xmm1; 
       vaddsd xmm0, xmm0, xmm1; 


       @buildRes2:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 

       // check if we need to use the unbiased version
       cmp unbiased, 0;
       jz @@dobiased;

       lea rax, [rip + cOne];
       vmovsd xmm2, [rax]; 
       vsubsd xmm4, xmm3, xmm2; 
       vmaxsd xmm4, xmm4, xmm2; 

       vdivsd xmm0, xmm0, xmm4; 

       jmp @@writeRes;

       @@dobiased:
       vdivsd xmm0, xmm0, xmm3; 

       // write result
       @@writeRes:
       vmovsd [rcx + 8], xmm0; 

       // next line:
       add r8, r9;
       add rcx, rdx;

   // loop y end
   dec r11;
   jnz @@addforyloop;

   // epilog
   vmovupd xmm4, [rsp + $00]; 
   add rsp, $10;
   vzeroupper; 
end;

procedure AVXMatrixMeanVarRowUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
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

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth

   // prolog
   sub rsp, $10;
   vmovupd [rsp + $00], xmm4; 

   // iters := -width*sizeof(double)
   mov r10, width;
   imul r10, -8;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm3, xmm3, width;

   // for y := 0 to height - 1:
   mov r11, Height;
   @@addforyloop:
       vxorpd ymm0, ymm0, ymm0; 
       vxorpd ymm1, ymm1, ymm1; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;
           // prefetch data...
           // prefetch [r8 + rax];

           // addition:
           vmovupd ymm2, [r8 + rax - 128]; 
           vaddpd ymm0, ymm0, ymm2; 
           vmovupd ymm2, [r8 + rax - 96]; 
           vaddpd ymm1, ymm1, ymm2; 
           vmovupd ymm2, [r8 + rax - 64]; 
           vaddpd ymm0, ymm0, ymm2; 
           vmovupd ymm2, [r8 + rax - 32]; 
           vaddpd ymm1, ymm1, ymm2; 
       jmp @addforxloop

       @loopEnd:

       vaddpd ymm0, ymm0, ymm1; 
       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       sub rax, 128;

       jz @buildRes;

       @addforxloop2:
           add rax, 16;
           jg @@addforxloop2end;

           vmovupd xmm2, [r8 + rax - 16]; 
           vaddpd xmm0, xmm0, xmm2; 
       jmp @addforxloop2;

       @@addforxloop2end:

       sub rax, 16;
       jz @buildRes;

       vaddsd xmm0, xmm0, [r8 + rax]; 

       @buildRes:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 
       vdivsd xmm0, xmm0, xmm3; 
       vmovsd [rcx], xmm0; 

       // we have calculated the mean ->
       // repeat the loop to calculate the variance

       vbroadcastsd ymm4, [rcx]; // need avx2
       vxorpd xmm0, xmm0, xmm0; 

       // for x := 0 to w - 1;
       // prepare for reverse loop
       // variance = sum (x - mean)^2
       mov rax, r10;
       @addforxloop3:
           add rax, 128;
           jg @loopEnd2;
           // prefetch data...
           // prefetch [ecx + rax];

           // addition:
           vmovupd ymm1, [r8 + rax - 128]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovupd ymm1, [r8 + rax - 96]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovupd ymm1, [r8 + rax - 64]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

           vmovupd ymm1, [r8 + rax - 32]; 
           vsubpd ymm1, ymm1, ymm4; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm0, ymm0, ymm1; 

       jmp @addforxloop3

       @loopEnd2:

       sub rax, 128;

       vextractf128 xmm2, ymm0, 1; 
       vhaddpd xmm0, xmm0, xmm2; 

       jz @buildRes2;

       @addforxloop4:
           add rax, 16;
           jg @addforxloop4end;

           vmovupd xmm1, [r8 + rax - 16]; 
           vsubpd xmm1, xmm1, xmm4; 
           vmulpd xmm1, xmm1, xmm1; 
           vaddpd xmm0, xmm0, xmm1; 
       jmp @addforxloop4;

       @addforxloop4end:

       sub rax, 16;
       jz @buildRes2;

       // last column
       vmovsd xmm1, [r8 + rax]; 
       vsubsd xmm1, xmm1, xmm4; 
       vmulsd xmm1, xmm1, xmm1; 
       vaddsd xmm0, xmm0, xmm1; 


       @buildRes2:

       // build result
       vhaddpd xmm0, xmm0, xmm0; 

       // check if we need to use the unbiased version
       cmp unbiased, 0;
       jz @@dobiased;

       lea rax, [rip + cOne];
       vmovsd xmm2, [rax]; 
       vsubsd xmm4, xmm3, xmm2; 
       vmaxsd xmm4, xmm4, xmm2; 

       vdivsd xmm0, xmm0, xmm4; 

       jmp @@writeRes;

       @@dobiased:
       vdivsd xmm0, xmm0, xmm3; 

       // write result
       @@writeRes:
       vmovsd [rcx + 8], xmm0; 

       // next line:
       add r8, r9;
       add rcx, rdx;

   // loop y end
   dec r11;
   jnz @@addforyloop;

   // epilog
   vmovupd xmm4, [rsp + $00]; 
   add rsp, $10;
   vzeroupper; 
end;

procedure AVXMatrixMeanVarColumnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
var tmp : double;
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

   // prolog
   sub rsp, $20;
   vmovupd [rsp + $00], xmm4; 
   vmovupd [rsp + $10], xmm5; 

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth
   xor r10, r10;
   sub r10, height;
   imul r10, r9;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm0, xmm0, height;
   
   lea rax, tmp;
   vmovsd [rax], xmm0; 
   vbroadcastsd ymm2, [rax]; // vbroadcastsd ymm2, xmm0;  // avx2

   lea rax, [rip + cOne];
   vbroadcastsd ymm5, [rax]; 


   // for x := 0 to width - 1:
   mov r11, Width;
   sub r11, 4;
   jl @@addforxloop4end;

   // 4 columns at once
   @@addforxloop4:
       vxorpd ymm1, ymm1, ymm1; 

       // for y := 0 to height - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforyloop4:
           vaddpd ymm1, ymm1, [r8 + rax]; 
       add rax, r9;
       jnz @addforyloop4;

       // build result
       vdivpd ymm0, ymm1, ymm2; 
       vmovapd [rcx], ymm0; 

       // calculate final standard deviation
       // for y := 0 to height - 1;
       // prepare for reverse loop
       vxorpd ymm4, ymm4, ymm4; 
       mov rax, r10;
       @addforyloop4_2:
           vmovapd ymm1, [r8 + rax]; 
           vsubpd ymm1, ymm1, ymm0; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm4, ymm4, ymm1; 
       add rax, r9;
       jnz @addforyloop4_2;

       // check if we need to use the unbiased version
       cmp unbiased, 0;
       jz @@dobiased_4;

       lea rax, [rip + cOne];

       vbroadcastsd ymm1, [rax]; 
       vsubpd ymm3, ymm2, ymm1; 
       vmaxpd ymm3, ymm3, ymm1; 

       vdivpd ymm4, ymm4, ymm3; 

       jmp @@writeRes_4;

       @@dobiased_4:
       vdivpd ymm4, ymm4, ymm2; 

       // write result
       @@writeRes_4:
       vmovapd [rcx + rdx], ymm4; 

       // next columns:
       add rcx, 32;
       add r8, 32;

   // loop x end
   sub r11, 4;
   jge @@addforxloop4;

   @@addforxloop4end:

   add r11, 4;
   jz @@endProc;

   sub r11, 2;
   jl @@lastcolumn;

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop2:
       vaddpd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop2;

   // build result
   vdivpd xmm0, xmm1, xmm2; 
   vmovapd [rcx], xmm0; 

   // calculate final standard deviation
   // for y := 0 to height - 1;
   // prepare for reverse loop
   vxorpd xmm4, xmm4, xmm4; 
   mov rax, r10;
   @addforyloop2_2:
      vmovapd xmm1, [r8 + rax]; 
      vsubpd xmm1, xmm1, xmm0; 
      vmulpd xmm1, xmm1, xmm1; 
      vaddpd xmm4, xmm4, xmm1; 
   add rax, r9;
   jnz @addforyloop2_2;

   // check if we need to use the unbiased version
   cmp unbiased, 0;
   jz @@dobiased_2;

   vsubpd xmm3, xmm2, xmm5; 
   vmaxpd xmm3, xmm3, xmm5; 

   vdivpd xmm4, xmm4, xmm3; 

   jmp @@writeRes2;

   @@dobiased_2:
   vdivpd xmm4, xmm4, xmm2; 

   // write result
   @@writeRes2:
   vmovapd [rcx + rdx], xmm4; 

   // next columns:
   add rcx, 16;
   add r8, 16;

   dec r11;
   jnz @@endProc;

   @@lastcolumn:

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop_1:
       vaddsd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop_1;

   // build result
   vdivsd xmm0, xmm1, xmm2; 
   vmovsd [rcx], xmm0; 

   // calculate final standard deviation
   // for y := 0 to height - 1;
   // prepare for reverse loop
   vxorpd xmm4, xmm4, xmm4; 
   mov rax, r10;
   @addforyloop2_1:
      vmovsd xmm1, [r8 + rax]; 
      vsubsd xmm1, xmm1, xmm0; 
      vmulsd xmm1, xmm1, xmm1; 
      vaddsd xmm4, xmm4, xmm1; 
   add rax, r9;
   jnz @addforyloop2_1;

   // check if we need to use the unbiased version
   cmp unbiased, 0;
   jz @@dobiased_1;

   vmovsd xmm3, xmm3, xmm2; 
   vsubsd xmm3, xmm3, xmm5; 
   vmaxsd xmm3, xmm3, xmm5; 

   vdivsd xmm4, xmm4, xmm3; 

   jmp @@writeRes_1;

   @@dobiased_1:
   vdivsd xmm4, xmm4, xmm2; 

   // write result
   @@writeRes_1:
   vmovsd [rcx + rdx], xmm4; 

   @@endProc:

   // epilog
   vmovupd xmm4, [rsp + $00]; 
   vmovupd xmm5, [rsp + $10]; 
   add rsp, $20;
   vzeroupper; 
end;

procedure AVXMatrixMeanVarColumnUnAligned(dest : PDouble; const destLineWidth : NativeInt; Src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt; unbiased : boolean); assembler;
var tmp : double;
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

   // prolog
   sub rsp, $20;
   vmovupd [rsp + $00], xmm4; 
   vmovupd [rsp + $10], xmm5; 

   // note: RCX = dest, RDX = destLineWidth, R8 = src, R9 = srcLineWidth
   xor r10, r10;
   sub r10, height;
   imul r10, r9;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;

   vcvtsi2sd xmm0, xmm0, height;
   
   lea rax, tmp;
   vmovsd [rax], xmm0; 
   vbroadcastsd ymm2, [rax]; //vbroadcastsd ymm2, xmm0; // avx2

   lea rax, [rip + cOne];
   vbroadcastsd ymm5, [rax]; 

   // for x := 0 to width - 1:
   mov r11, Width;
   sub r11, 4;
   jl @@addforxloop4end;

   // 4 columns at once
   @@addforxloop4:
       vxorpd ymm1, ymm1, ymm1; 

       // for y := 0 to height - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforyloop4:
           vmovupd ymm3, [r8 + rax]; 
           vaddpd ymm1, ymm1, ymm3; 
       add rax, r9;
       jnz @addforyloop4;

       // build result
       vdivpd ymm0, ymm1, ymm2; 
       vmovupd [rcx], ymm0; 

       // calculate final standard deviation
       // for y := 0 to height - 1;
       // prepare for reverse loop
       vxorpd ymm4, ymm4, ymm4; 
       mov rax, r10;
       @addforyloop4_2:
           vmovupd ymm1, [r8 + rax]; 
           vsubpd ymm1, ymm1, ymm0; 
           vmulpd ymm1, ymm1, ymm1; 
           vaddpd ymm4, ymm4, ymm1; 
       add rax, r9;
       jnz @addforyloop4_2;

       // check if we need to use the unbiased version
       cmp unbiased, 0;
       jz @@dobiased_4;

       vsubpd ymm3, ymm2, ymm5; 
       vmaxpd ymm3, ymm3, ymm5; 

       vdivpd ymm4, ymm4, ymm3; 

       jmp @@writeRes_4;

       @@dobiased_4:
       vdivpd ymm4, ymm4, ymm2; 

       // write result
       @@writeRes_4:
       vmovupd [rcx + rdx], ymm4; 

       // next columns:
       add rcx, 32;
       add r8, 32;

   // loop x end
   sub r11, 4;
   jge @@addforxloop4;

   @@addforxloop4end:

   add r11, 4;
   jz @@endProc;

   sub r11, 2;
   jl @@lastcolumn;

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop2:
       vmovupd xmm3, [r8 + rax]; 
       vaddpd xmm1, xmm1, xmm3; 
   add rax, r9;
   jnz @addforyloop2;

   // build result
   vdivpd xmm0, xmm1, xmm2; 
   vmovupd [rcx], xmm0; 

   // calculate final standard deviation
   // for y := 0 to height - 1;
   // prepare for reverse loop
   vxorpd xmm4, xmm4, xmm4; 
   mov rax, r10;
   @addforyloop2_2:
      vmovupd xmm1, [r8 + rax]; 
      vsubpd xmm1, xmm1, xmm0; 
      vmulpd xmm1, xmm1, xmm1; 
      vaddpd xmm4, xmm4, xmm1; 
   add rax, r9;
   jnz @addforyloop2_2;

   // check if we need to use the unbiased version
   cmp unbiased, 0;
   jz @@dobiased_2;

   vsubpd xmm3, xmm2, xmm5; 
   vmaxpd xmm3, xmm3, xmm5; 

   vdivpd xmm4, xmm4, xmm3; 

   jmp @@writeRes2;

   @@dobiased_2:
   vdivpd xmm4, xmm4, xmm2; 

   // write result
   @@writeRes2:
   vmovupd [rcx + rdx], xmm4; 

   // next columns:
   add rcx, 16;
   add r8, 16;

   dec r11;
   jnz @@endProc;

   @@lastcolumn:

   vxorpd xmm1, xmm1, xmm1; 

   // for y := 0 to height - 1;
   // prepare for reverse loop
   mov rax, r10;
   @addforyloop_1:
       vaddsd xmm1, xmm1, [r8 + rax]; 
   add rax, r9;
   jnz @addforyloop_1;

   // build result
   vdivsd xmm0, xmm1, xmm2; 
   vmovsd [rcx], xmm0; 

   // calculate final standard deviation
   // for y := 0 to height - 1;
   // prepare for reverse loop
   vxorpd xmm4, xmm4, xmm4; 
   mov rax, r10;
   @addforyloop2_1:
      vmovsd xmm1, [r8 + rax]; 
      vsubsd xmm1, xmm1, xmm0; 
      vmulsd xmm1, xmm1, xmm1; 
      vaddsd xmm4, xmm4, xmm1; 
   add rax, r9;
   jnz @addforyloop2_1;

   // check if we need to use the unbiased version
   cmp unbiased, 0;
   jz @@dobiased_1;

   vsubsd xmm3, xmm2, xmm5; 
   vmaxsd xmm3, xmm3, xmm5; 

   vdivsd xmm4, xmm4, xmm3; 

   jmp @@writeRes_1;

   @@dobiased_1:
   vdivsd xmm4, xmm4, xmm2; 

   // write result
   @@writeRes_1:
   vmovsd [rcx + rdx], xmm4; 

   @@endProc:

   vmovupd xmm4, [rsp + $00]; 
   vmovupd xmm5, [rsp + $10]; 
   add rsp, $20;
   vzeroupper; 
end;


end.
