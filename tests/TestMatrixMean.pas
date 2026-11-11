// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

program TestMatrixMean;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required by the thread pool (see README)
  SysUtils,
  ASMMatrixMeanOperationsx64,
  AVXMatrixMeanOperationsx64;

type
  PDouble = ^Double;

procedure RefMeanRow(
  dest: PDouble;
  destLineWidth: NativeInt;
  src: PDouble;
  srcLineWidth: NativeInt;
  width, height: NativeInt
);
var
  y, x: NativeInt;
  sum: Double;
  rowSrc: PDouble;
  rowDest: PDouble;
begin
  rowDest := dest;
  rowSrc := src;
  for y := 0 to height - 1 do
  begin
    sum := 0.0;
    for x := 0 to width - 1 do
      sum := sum + rowSrc[x];
    rowDest^ := sum / width;
    Inc(PByte(rowSrc), srcLineWidth);
    Inc(PByte(rowDest), destLineWidth);
  end;
end;

procedure RefMeanVarRowUnaligned(
  dest: PDouble;
  destLineWidth: NativeInt;
  src: PDouble;
  srcLineWidth: NativeInt;
  width, height: NativeInt;
  unbiased: Boolean
);
var
  y, x: NativeInt;
  rowSrc: PDouble;
  rowDest: PDouble;
  sum, mean, diff, varSum, denom: Double;
begin
  rowDest := dest;
  rowSrc := src;
  for y := 0 to height - 1 do
  begin
    sum := 0.0;
    for x := 0 to width - 1 do
      sum := sum + rowSrc[x];

    mean := sum / width;
    rowDest^ := mean;

    varSum := 0.0;
    for x := 0 to width - 1 do
    begin
      diff := rowSrc[x] - mean;
      varSum := varSum + diff * diff;
    end;

    if unbiased and (width > 1) then
      denom := width - 1
    else
      denom := width;

    PDouble(PByte(rowDest) + 8)^ := varSum / denom;

    Inc(PByte(rowSrc), srcLineWidth);
    Inc(PByte(rowDest), destLineWidth);
  end;
end;

function AlmostEqual(a, b, eps: Double): Boolean;
var
  d: Double;
begin
  d := a - b;
  if d < 0.0 then
    d := -d;
  Result := d <= eps;
end;

procedure TestMeanRow;
const
  MaxW = 17;
  MaxH = 7;
var
  srcArr: array[0..MaxH - 1, 0..MaxW - 1] of Double;
  dstRefArr: array[0..MaxH - 1] of Double;
  dstAsmArr: array[0..MaxH - 1] of Double;
  w, h, x, y: NativeInt;
  eps: Double;
begin
  eps := 1e-9;

  // Fill source with deterministic data
  for h := 0 to MaxH - 1 do
    for w := 0 to MaxW - 1 do
      srcArr[h, w] := (h + 1) * 100.0 + (w + 1);

  for h := 1 to MaxH do
    for w := 1 to MaxW do
    begin
      // Reference
      FillChar(dstRefArr, SizeOf(dstRefArr), 0);
      RefMeanRow(
        @dstRefArr[0],
        SizeOf(Double),
        @srcArr[0, 0],
        SizeOf(srcArr[0]),
        w,
        h
      );

      // ASM - the Aligned* variants require an aligned source pointer, which
      // these stack arrays are not; the UnAligned* variants do not. Width parity
      // is still part of the routine name.
      FillChar(dstAsmArr, SizeOf(dstAsmArr), 0);
      if Odd(w) then
        ASMMatrixMeanRowUnAlignedOddW(
          @dstAsmArr[0],
          SizeOf(Double),
          @srcArr[0, 0],
          SizeOf(srcArr[0]),
          w,
          h
        )
      else
        ASMMatrixMeanRowUnAlignedEvenW(
          @dstAsmArr[0],
          SizeOf(Double),
          @srcArr[0, 0],
          SizeOf(srcArr[0]),
          w,
          h
        );

      // Compare
      for y := 0 to h - 1 do
      begin
        if not AlmostEqual(dstRefArr[y], dstAsmArr[y], eps) then
        begin
          WriteLn('MeanRow mismatch at w=', w,
                  ' h=', h, ' row=', y,
                  ' ref=', dstRefArr[y]:0:15,
                  ' asm=', dstAsmArr[y]:0:15);
          Halt(1);
        end;
      end;
    end;

  WriteLn('MeanRow tests passed.');
end;

procedure TestMeanVarRowUnaligned;
const
  MaxW = 17;
  MaxH = 7;
var
  srcArr: array[0..MaxH - 1, 0..MaxW - 1] of Double;
  dstRefArr: array[0..MaxH - 1, 0..1] of Double;
  dstAsmArr: array[0..MaxH - 1, 0..1] of Double;
  w, h, x, y: NativeInt;
  eps: Double;
  unbiased: Boolean;
begin
  eps := 1e-9;

  // Fill source with deterministic data (non-trivial pattern)
  for h := 0 to MaxH - 1 do
    for w := 0 to MaxW - 1 do
      srcArr[h, w] := 0.1 * (h + 1) * (w + 2) + (h - w);

  for unbiased in [False, True] do
  begin
    for h := 1 to MaxH do
      for w := 1 to MaxW do
      begin
        FillChar(dstRefArr, SizeOf(dstRefArr), 0);
        FillChar(dstAsmArr, SizeOf(dstAsmArr), 0);

        RefMeanVarRowUnaligned(
          @dstRefArr[0, 0],
          SizeOf(dstRefArr[0]),
          @srcArr[0, 0],
          SizeOf(srcArr[0]),
          w,
          h,
          unbiased
        );

        AVXMatrixMeanVarRowUnAligned(
          @dstAsmArr[0, 0],
          SizeOf(dstAsmArr[0]),
          @srcArr[0, 0],
          SizeOf(srcArr[0]),
          w,
          h,
          unbiased
        );

        for y := 0 to h - 1 do
        begin
          if (not AlmostEqual(dstRefArr[y, 0], dstAsmArr[y, 0], eps)) or
             (not AlmostEqual(dstRefArr[y, 1], dstAsmArr[y, 1], eps)) then
          begin
            WriteLn('MeanVar mismatch (unbiased=', unbiased,
                    ') at w=', w, ' h=', h, ' row=', y);
            WriteLn('  ref mean=', dstRefArr[y, 0]:0:15,
                    ' var=', dstRefArr[y, 1]:0:15);
            WriteLn('  asm mean=', dstAsmArr[y, 0]:0:15,
                    ' var=', dstAsmArr[y, 1]:0:15);
            Halt(1);
          end;
        end;
      end;
  end;

  WriteLn('MeanVarRowUnaligned tests passed.');
end;

begin
  try
    TestMeanRow;
    TestMeanVarRowUnaligned;
    WriteLn('All tests passed.');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
