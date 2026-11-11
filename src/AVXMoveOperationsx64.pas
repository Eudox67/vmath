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


unit AVXMoveOperationsx64;

// #################################################
// #### SSE optimized move oprationes
// #################################################

interface

{$MODE OBJFPC}{$H+}

{$I 'vMath_CPU.inc'}


procedure AVXMatrixCopyAligned(Dest : PDouble; const destLineWidth : NativeInt; src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
procedure AVXMatrixCopyUnAligned(Dest : PDouble; const destLineWidth : NativeInt; src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;

procedure AVXRowSwapAligned(A, B : PDouble; width : NativeInt); assembler;
procedure AVXRowSwapUnAligned(A, B : PDouble; width : NativeInt); assembler;

procedure AVXInitMemAligned(A : PDouble; NumBytes : NativeInt; Value : double); assembler;


procedure AVXMatrixInitAligned( dest : PDouble; const destLineWidth : NativeInt; Width, Height : NativeInt; {$IFDEF UNIX}unixValue{$ELSE}Value{$ENDIF} : double); assembler;
procedure AVXMatrixInitUnAligned( dest : PDouble; const destLineWidth : NativeInt; Width, Height : NativeInt; {$IFDEF UNIX}unixValue{$ELSE}Value{$ENDIF} : double); assembler;


implementation


// rcx = dest, rdx = destLineWidth;  r8 = width, r9 = height
procedure AVXMatrixInitAligned( dest : PDouble; const destLineWidth : NativeInt; Width, Height : NativeInt; {$IFDEF UNIX}unixValue{$ELSE}Value{$ENDIF} : double); assembler;
{$IFDEF UNIX}
var value : double;
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

   movsd value, unixValue;
   {$ENDIF}

   lea rax, value;
   vbroadcastsd ymm1, [rax]; 

   //iters := -width*sizeof(double);
   imul r8, -8;

   // helper registers for the src and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // move:
           vmovapd [rcx + rax - 128], ymm1; 
           vmovapd [rcx + rax - 96], ymm1; 
           vmovapd [rcx + rax - 64], ymm1; 
           vmovapd [rcx + rax - 32], ymm1; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
          add rax, 16;
          jg @loopEnd2;

          vmovapd [rcx + rax - 16], xmm1; 
       jmp @addforxloop2;

       @loopEnd2:
       sub rax, 16;

       jz @nextLine;

       // last element
       vmovsd [rcx + rax], xmm1;

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   vzeroupper; 
end;

// rcx = dest, rdx = destLineWidth;  r8 = width, r9 = height
procedure AVXMatrixInitUnAligned( dest : PDouble; const destLineWidth : NativeInt; Width, Height : NativeInt; {$IFDEF UNIX}unixValue{$ELSE}Value{$ENDIF} : double); assembler;
{$IFDEF UNIX}
var value : double;
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

   movsd value, unixValue;
   {$ENDIF}

   lea rax, value;
   vbroadcastsd ymm1, [rax]; 

   //iters := -width*sizeof(double);
   imul r8, -8;

   // helper registers for the src and dest pointers
   sub rcx, r8;

   // for y := 0 to height - 1:
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r8;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // move:
           vmovupd [rcx + rax - 128], ymm1; 
           vmovupd [rcx + rax - 96], ymm1; 
           vmovupd [rcx + rax - 64], ymm1; 
           vmovupd [rcx + rax - 32], ymm1; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
          add rax, 16;
          jg @loopEnd2;

          vmovupd [rcx + rax - 16], xmm1; 
       jmp @addforxloop2;

       @loopEnd2:
       sub rax, 16;

       jz @nextLine;

       // last element
       vmovsd [rcx + rax], xmm1; 

       @nextLine:

       // next line:
       add rcx, rdx;

   // loop y end
   dec r9;
   jnz @@addforyloop;

   vzeroupper; 
end;

// uses non temporal moves so the cache is not poisned
// rcx = A, rdx = NumBytes;
procedure AVXInitMemAligned(A : PDouble; NumBytes : NativeInt; Value : double); assembler;
var tmp : Double;
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

   movsd tmp, value;
   lea rax, tmp;
   vbroadcastsd ymm1, [rax]; 

   imul rdx, -1;
   sub rcx, rdx;

   @@loopUnrolled:
      add rdx, 128;
      jg @@loopUnrolledEnd;

      vmovapd [rcx + rdx - 128], ymm1; 
      vmovapd [rcx + rdx - 96], ymm1; 
      vmovapd [rcx + rdx - 64], ymm1; 
      vmovapd [rcx + rdx - 32], ymm1; 
   jmp @@loopUnrolled;

   @@loopUnrolledEnd:

   sub rdx, 128;
   jz @@exitProc;

   add rdx, 32;
   jg @@beginloop3;

   @@loop2:
      vmovapd [rcx + rdx - 32], xmm1; 
      vmovapd [rcx + rdx - 16], xmm1; 
   add rdx, 32;
   jl @@loop2;

   @@beginloop3:
   sub rdx, 32;
   jz @@exitProc;

   @@loop3:
      vmovsd [rcx + rdx], xmm1; 
      add rdx, 8;
   jnz @@loop3;

   @@exitProc:

   vzeroupper; 
end;

procedure AVXRowSwapAligned(A, B : PDouble; width : NativeInt); assembler;
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

   // note: RCX = a, RDX = b, R8 = width
   imul r8, -8;

   sub rcx, r8;
   sub rdx, r8;

   @unrolloop:
     add r8, 128;
     jg @unrolloopend;

     // prefetch data...
     // prefetchw [rcx + r10];
     // prefetchw [rdx + r10];

     vmovdqa ymm0, [rcx + r8 - 128]; 
     vmovdqa ymm1, [rdx + r8 - 128]; 

     vmovdqa [rcx + r8 - 128], ymm1; 
     vmovdqa [rdx + r8 - 128], ymm0; 

     vmovdqa ymm2, [rcx + r8 - 96]; 
     vmovdqa ymm3, [rdx + r8 - 96]; 

     vmovdqa [rcx + r8 - 96], ymm3; 
     vmovdqa [rdx + r8 - 96], ymm2; 

     vmovdqa ymm0, [rcx + r8 - 64]; 
     vmovdqa ymm1, [rdx + r8 - 64]; 

     vmovdqa [rcx + r8 - 64], ymm1; 
     vmovdqa [rdx + r8 - 64], ymm0; 

     vmovdqa ymm2, [rcx + r8 - 32]; 
     vmovdqa ymm3, [rdx + r8 - 32]; 

     vmovdqa [rcx + r8 - 32], ymm3; 
     vmovdqa [rdx + r8 - 32], ymm2; 
   jmp @unrolloop;
   @unrolloopend:

   sub r8, 128;
   jz @endfunc;

   @loop2:
     add r8, 16;
     jg @loop2End;

     vmovdqa xmm0, [rcx + r8 - 16]; 
     vmovdqa xmm1, [rdx + r8 - 16]; 

     vmovdqa [rcx + r8 - 16], xmm1; 
     vmovdqa [rdx + r8 - 16], xmm0; 
   jmp @loop2;

   @loop2End:
   sub r8, 16;

   jz @endfunc;

   vmovsd xmm0, [rcx + r8]; 
   vmovsd xmm1, [rdx + r8]; 

   vmovsd [rcx + r8], xmm1; 
   vmovsd [rdx + r8], xmm0; 

   @endfunc:

   vzeroupper; 
end;

procedure AVXRowSwapUnAligned(A, B : PDouble; width : NativeInt); assembler;
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

   // note: RCX = a, RDX = b, R8 = width
   imul r8, -8;

   sub rcx, r8;
   sub rdx, r8;

   @unrolloop:
     add r8, 128;
     jg @unrolloopend;

     // prefetch data...
     // prefetchw [rcx + r10];
     // prefetchw [rdx + r10];

     vmovdqu ymm0, [rcx + r8 - 128]; 
     vmovdqu ymm1, [rdx + r8 - 128]; 

     vmovdqu [rcx + r8 - 128], ymm1; 
     vmovdqu [rdx + r8 - 128], ymm0; 

     vmovdqu ymm2, [rcx + r8 - 96]; 
     vmovdqu ymm3, [rdx + r8 - 96]; 

     vmovdqu [rcx + r8 - 96], ymm3; 
     vmovdqu [rdx + r8 - 96], ymm2; 

     vmovdqu ymm0, [rcx + r8 - 64]; 
     vmovdqu ymm1, [rdx + r8 - 64]; 

     vmovdqu [rcx + r8 - 64], ymm1; 
     vmovdqu [rdx + r8 - 64], ymm0; 

     vmovdqu ymm2, [rcx + r8 - 32]; 
     vmovdqu ymm3, [rdx + r8 - 32]; 

     vmovdqu [rcx + r8 - 32], ymm3; 
     vmovdqu [rdx + r8 - 32], ymm2; 
   jmp @unrolloop;
   @unrolloopend:

   sub r8, 128;
   jz @endfunc;

   @loop2:
     add r8, 16;
     jg @loop2End;

     vmovdqu xmm0, [rcx + r8 - 16]; 
     vmovdqu xmm1, [rdx + r8 - 16]; 

     vmovdqu [rcx + r8 - 16], xmm1; 
     vmovdqu [rdx + r8 - 16], xmm0; 
   jmp @loop2;

   @loop2End:
   sub r8, 16;

   jz @endfunc;

   vmovsd xmm0, [rcx + r8]; 
   vmovsd xmm1, [rdx + r8]; 

   vmovsd [rcx + r8], xmm1; 
   vmovsd [rdx + r8], xmm0; 

   @endfunc:

   vzeroupper; 
end;

procedure AVXMatrixCopyAligned(Dest : PDouble; const destLineWidth : NativeInt; src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
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
   //iters := -width*sizeof(double);
   mov r10, width;
   imul r10, -8;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;
   sub rcx, r10;

   // for y := 0 to height - 1:
   mov r11, Height;
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetch data...
           // prefetch [r8 + rax];
           // prefetchw [rcx + rax];

           // move:
           vmovdqa ymm0, [r8 + rax - 128]; 
           vmovdqa [rcx + rax - 128], ymm0; 

           vmovdqa ymm1, [r8 + rax - 96]; 
           vmovdqa [rcx + rax - 96], ymm1; 

           vmovdqa ymm2, [r8 + rax - 64]; 
           vmovdqa [rcx + rax - 64], ymm2; 

           vmovdqa ymm3, [r8 + rax - 32]; 
           vmovdqa [rcx + rax - 32], ymm3; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
          add rax, 16;
          jg @loopEnd2;

          vmovdqa xmm0, [r8 + rax - 16]; 
          vmovdqa [rcx + rax - 16], xmm0; 
       jmp @addforxloop2;

       @loopEnd2:
       sub rax, 16;

       jz @nextLine;

       // last element
       vmovsd xmm0, [r8 + rax]; 
       vmovsd [rcx + rax], xmm0; 

       @nextLine:

       // next line:
       add r8, r9;
       add rcx, rdx;

   // loop y end
   dec r11;
   jnz @@addforyloop;

   vzeroupper; 
end;

procedure AVXMatrixCopyUnAligned(Dest : PDouble; const destLineWidth : NativeInt; src : PDouble; const srcLineWidth : NativeInt; {$ifdef UNIX}unixWidth{$ELSE}width{$endif}, {$ifdef UNIX}unixHeight{$ELSE}height{$endif} : NativeInt); assembler;
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
   //iters := -width*sizeof(double);
   mov r10, width;
   imul r10, -8;

   // helper registers for the mt1, mt2 and dest pointers
   sub r8, r10;
   sub rcx, r10;

   // for y := 0 to height - 1:
   mov r11, Height;
   @@addforyloop:
       // for x := 0 to w - 1;
       // prepare for reverse loop
       mov rax, r10;
       @addforxloop:
           add rax, 128;
           jg @loopEnd;

           // prefetch data...
           // prefetch [r8 + rax];
           // prefetchw [rcx + rax];

           // move:
           vmovdqu ymm0, [r8 + rax - 128]; 
           vmovdqu [rcx + rax - 128], ymm0; 

           vmovdqu ymm1, [r8 + rax - 96]; 
           vmovdqu [rcx + rax - 96], ymm1; 

           vmovdqu ymm2, [r8 + rax - 64]; 
           vmovdqu [rcx + rax - 64], ymm2; 

           vmovdqu ymm3, [r8 + rax - 32]; 
           vmovdqu [rcx + rax - 32], ymm3; 

       jmp @addforxloop

       @loopEnd:

       sub rax, 128;

       jz @nextLine;

       @addforxloop2:
          add rax, 16;
          jg @loopEnd2;

          vmovdqu xmm0, [r8 + rax - 16]; 
          vmovdqu [rcx + rax - 16], xmm0; 
       jmp @addforxloop2;

       @loopEnd2:
       sub rax, 16;

       jz @nextLine;

       // last element
       vmovsd xmm0, [r8 + rax]; 
       vmovsd [rcx + rax], xmm0; 

       @nextLine:

       // next line:
       add r8, r9;
       add rcx, rdx;

   // loop y end
   dec r11;
   jnz @@addforyloop;

   vzeroupper; 
end;


end.
