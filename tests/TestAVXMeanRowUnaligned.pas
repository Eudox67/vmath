// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

program TestAVXMeanRowUnaligned;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required by the thread pool (see README)
  SysUtils,
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

function AlmostEqual(a, b, eps: Double): Boolean;
var
  d: Double;
begin
  d := a - b;
  if d < 0.0 then
    d := -d;
  Result := d <= eps;
end;

procedure RunOne(width, height: NativeInt);
var
  src: array of Double;
  dstRef: array of Double;
  dstAsm: array of Double;
  idx, x, y: NativeInt;
  eps: Double;
  srcStride: NativeInt;
  dstStride: NativeInt;
begin
  eps := 1e-9;
  srcStride := width * SizeOf(Double);
  dstStride := SizeOf(Double);

  SetLength(src, width * height);
  SetLength(dstRef, height);
  SetLength(dstAsm, height);

  for y := 0 to height - 1 do
  begin
    // any deterministic pattern
    // src[y,x] = y*100 + x
    // index = y*width + x
    // fill linear
  end;

  // fill
  idx := 0;
  for y := 0 to height - 1 do
  begin
    for x := 0 to width - 1 do
    begin
      src[idx] := y * 100.0 + x;
      Inc(idx);
    end;
  end;

  RefMeanRow(
    @dstRef[0],
    dstStride,
    @src[0],
    srcStride,
    width,
    height
  );

  AVXMatrixMeanRowUnAligned(
    @dstAsm[0],
    dstStride,
    @src[0],
    srcStride,
    width,
    height
  );

  for y := 0 to height - 1 do
  begin
    if not AlmostEqual(dstRef[y], dstAsm[y], eps) then
    begin
      WriteLn('Mismatch at w=', width, ' h=', height, ' row=', y);
      WriteLn('  ref=', dstRef[y]:0:15);
      WriteLn('  asm=', dstAsm[y]:0:15);
      Halt(1);
    end;
  end;
end;

begin
  try
    RunOne(16, 4);
    RunOne(5, 3);
    RunOne(31, 7);
    WriteLn('AVXMatrixMeanRowUnAligned OK');
  except
    on E: Exception do
    begin
      WriteLn('ERROR: ', E.ClassName, ': ', E.Message);
      Halt(1);
    end;
  end;
end.
