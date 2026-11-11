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

unit AVXChaChax64;

interface

{$MODE OBJFPC}{$H+}

uses RandomEng;

{$I 'vMath_CPU.inc'}


procedure AVXChaChaDoubleQuarterRound( chachaMtx : PChaChaAVXMtx );
procedure AVXRealingAndAddMtx( chaChaMtx : PChaChaAVXMtx; inpChaCha : PChaChaMtx );


implementation



uses MatrixConst;

const cShuf16 : Array[0..31] of byte = (3, 0, 1, 2,
                                        7, 4, 5, 6,
                                        11, 8, 9, 10,
                                        15, 12, 13, 14,
                                        3, 0, 1, 2,
                                        7, 4, 5, 6,
                                        11, 8, 9, 10,
                                        15, 12, 13, 14);

procedure AVXChaChaDoubleQuarterRound( chachaMtx : PChaChaAVXMtx );
var dYMM4, dYMM5 : TYMMArr;
begin
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // The parameters are passed in the following order:
   // RDI, RSI, RDX, RCX, r8, r9 -> mov to RCX, RDX, R8, R9, width and height
   // in our case only rdi to rcx
   mov rcx, rdi;
   {$ENDIF}
   vmovupd dYMM4, ymm4; 
   vmovupd dYMM5, ymm5; 

   // 64bit version
   lea rdx, [rip + cShuf16];
   vmovdqu ymm5, [rdx]; 

   // move the matrix to xmm0 to xmm3
   vmovdqa ymm0, [rcx]; 
   vmovdqa ymm1, [rcx + 32]; 
   vmovdqa ymm2, [rcx + 64]; 
   vmovdqa ymm3, [rcx + 96]; 

   // v0 += v1; v3 ^= v0; v3 <<<= 16
   vpaddd ymm0, ymm0, ymm1; 
   vpxor ymm3, ymm3, ymm0; 
   vpshufhw ymm3, ymm3, $B1; // 10 11 00 01
   vpshuflw ymm3, ymm3, $B1; 

   // v2 += v3; v1 ^= v2; v1 <<<= (12, 12, 12, 12);
   vpaddd ymm2, ymm2, ymm3; 
   vpxor ymm1, ymm1, ymm2; 
   // rotate is x << n | x >> 32 - n
   vpslld ymm4, ymm1, 12; 
   vpsrld ymm1, ymm1, 20; // 32 - 12
   vpor ymm1, ymm1, ymm4; 

   // v0 += v1; v3 ^= v0; v3 <<<= ( 8,  8,  8,  8);
   vpaddd ymm0, ymm0, ymm1; 
   vpxor ymm3, ymm3, ymm0; 
   vpshufb ymm3, ymm3, ymm5; 

   // v2 += v3; v1 ^= v2; v1 <<<= ( 7,  7,  7,  7);
   vpaddd ymm2, ymm2, ymm3; 
   vpxor ymm1, ymm1, ymm2; 
   vpslld ymm4, ymm1, 7; 
   vpsrld ymm1, ymm1, 25; // 32 - 7
   vpor ymm1, ymm1, ymm4; 

   // v1 >>>= 32; v2 >>>= 64; v3 >>>= 96;

   // palignr is actually a sse3 opcode but ok...
   vmovapd ymm4, ymm1; 
   vpalignr ymm1, ymm1, ymm4, 4; 
   vmovapd ymm4, ymm2; 
   vpalignr ymm2, ymm2, ymm4, 8; 
   vmovapd ymm4, ymm3; 
   vpalignr ymm3, ymm3, ymm4, 12; 

   // v0 += v1; v3 ^= v0; v3 <<<= 16
   vpaddd ymm0, ymm0, ymm1; 
   vpxor ymm3, ymm3, ymm0; 
   vpshufhw ymm3, ymm3, $B1; // 10 11 00 01
   vpshuflw ymm3, ymm3, $B1; 

   // v2 += v3; v1 ^= v2; v1 <<<= (12, 12, 12, 12);
   vpaddd ymm2, ymm2, ymm3; 
   vpxor ymm1, ymm1, ymm2; 
   // rotate is x << n | x >> 32 - n
   vpslld ymm4, ymm1, 12; 
   vpsrld ymm1, ymm1, 20; // 32 - 12
   vpor ymm1, ymm1, ymm4; 

   // v0 += v1; v3 ^= v0; v3 <<<= ( 8,  8,  8,  8);
   vpaddd ymm0, ymm0, ymm1; 
   vpxor ymm3, ymm3, ymm0; 
   vpshufb ymm3, ymm3, ymm5; 

   // v2 += v3; v1 ^= v2; v1 <<<= ( 7,  7,  7,  7);
   vpaddd ymm2, ymm2, ymm3; 
   vpxor ymm1, ymm1, ymm2; 
   vpslld ymm4, ymm1, 7; 
   vpsrld ymm1, ymm1, 25; // 32 - 7
   vpor ymm1, ymm1, ymm4; 

   // v1 <<<= 32; v2 <<<= 64; v3 <<<= 96; Return
   vmovapd ymm4, ymm1; 
   vpalignr ymm1, ymm1, ymm4, 12; 
   vmovapd ymm4, ymm2; 
   vpalignr ymm2, ymm2, ymm4, 8; 
   vmovapd ymm4, ymm3; 
   vpalignr ymm3, ymm3, ymm4, 4; 

   // move back
   vmovdqa [rcx], ymm0; 
   vmovdqa [rcx + 32], ymm1; 
   vmovdqa [rcx + 64], ymm2; 
   vmovdqa [rcx + 96], ymm3; 

   // cleanup registers
   vmovupd ymm4, dYMM4; 
   vmovupd ymm5, dYMM5; 
   vzeroupper; 
end;
end;

// realign the chacha matrix such that further access to it is linear
procedure AVXRealingAndAddMtx( chaChaMtx : PChaChaAVXMtx; inpChaCha : PChaChaMtx );
var dXMM4, dXMM5 : TXMMArr;
begin
asm
   {$IFDEF UNIX}
   // Linux uses a diffrent ABI -> copy over the registers so they meet with winABI
   // The parameters are passed in the following order:
   // RDI, RSI -> mov to RCX, RDX
   mov rcx, rdi;
   mov rdx, rsi;
   {$ENDIF}
   vmovupd dXMM4, xmm4; 
   vmovupd dXMM5, xmm5; 

   // store second matrix
   vmovdqa xmm0, [rcx + 16]; 
   vmovdqa xmm1, [rcx + 48]; 
   vmovdqa xmm2, [rcx + 80]; 
   vmovdqa xmm3, [rcx + 112]; 

   vpaddd xmm0, xmm0, [rdx]; 
   vpaddd xmm1, xmm1, [rdx + 16]; 
   vpaddd xmm2, xmm2, [rdx + 32]; 
   vpaddd xmm3, xmm3, [rdx + 48]; 


   // move positions
   vmovapd xmm5, [rcx]; 
   vpaddd xmm5, xmm5, [rdx]; 
   vmovdqa [rcx], xmm5; 
   vmovdqa xmm5, [rcx + 32]; 
   vpaddd xmm5, xmm5, [rdx + 16]; 
   vmovdqa [rcx + 16], xmm5; 
   vmovdqa xmm5, [rcx + 64]; 
   vpaddd xmm5, xmm5, [rdx + 32]; 
   vmovdqa [rcx + 32], xmm5; 
   vmovdqa xmm5, [rcx + 96]; 
   vpaddd xmm5, xmm5, [rdx + 48]; 
   vmovdqa [rcx + 48], xmm5; 

   // append second matrix
   vmovdqa [rcx + 64], xmm0; 
   vmovdqa [rcx + 80], xmm1; 
   vmovdqa [rcx + 96], xmm2; 
   vmovdqa [rcx + 112], xmm3; 

   // cleanup registers
   vmovupd xmm4, dXMM4; 
   vmovupd xmm5, dXMM5; 

   vzeroupper; 
end;
end;


end.

