// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// FPCUnit suite: TThreadedMatrix must produce the same results as the
// single threaded TDoubleMatrix. Equivalence is a numerical tolerance, not
// bit-for-bit: the threaded paths sum in a different order.
unit TestThreadedMatrix;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, Matrix, ThreadedMatrix;

type
  TThreadedMatrixTests = class(TTestCase)
  private
    function MakePlain(seed : integer) : TDoubleMatrix;
    function MakeThreaded(seed : integer) : TThreadedMatrix;
  published
    procedure TestMultMatchesSingleThreaded;
    procedure TestAddMatchesSingleThreaded;
    procedure TestTransposeMatchesSingleThreaded;
    procedure TestMult768MatchesSingleThreaded;
  end;

implementation

const
  cSize = 256;                 // exercises the threaded paths
  cBigSize = 768;              // regression size: persistent-stage protocol
  cTolerance = 1e-10;          // explicit tolerance: sum order differs

function TThreadedMatrixTests.MakePlain(seed : integer) : TDoubleMatrix;
var
  x, y : integer;
begin
  RandSeed := seed;
  Result := TDoubleMatrix.Create(cSize, cSize, 0);
  for x := 0 to cSize - 1 do
    for y := 0 to cSize - 1 do
      Result.Items[x, y] := Random;
end;

function TThreadedMatrixTests.MakeThreaded(seed : integer) : TThreadedMatrix;
var
  src : TDoubleMatrix;
  x, y : integer;
begin
  src := MakePlain(seed);
  try
    Result := TThreadedMatrix.Create(cSize, cSize, 0);
    for x := 0 to cSize - 1 do
      for y := 0 to cSize - 1 do
        Result.Items[x, y] := src.Items[x, y];
  finally
    src.Free;
  end;
end;

procedure TThreadedMatrixTests.TestMultMatchesSingleThreaded;
var
  a, b : TDoubleMatrix;
  ta : TThreadedMatrix;
  plain, thr : TDoubleMatrix;
  x, y : integer;
  worst : double;
  d : double;
begin
  a := MakePlain(11);
  b := MakePlain(37);
  ta := MakeThreaded(11);
  plain := nil;
  thr := nil;
  try
    plain := a.Mult(b);
    thr := ta.Mult(b);

    worst := 0;
    for x := 0 to cSize - 1 do
      for y := 0 to cSize - 1 do
      begin
        d := Abs(plain.Items[x, y] - thr.Items[x, y]);
        if d > worst then
          worst := d;
      end;

    AssertTrue(Format('max |plain - threaded| = %g (tolerance %g)', [worst, cTolerance]),
               worst <= cTolerance);
  finally
    thr.Free;
    plain.Free;
    ta.Free;
    b.Free;
    a.Free;
  end;
end;

procedure TThreadedMatrixTests.TestAddMatchesSingleThreaded;
var
  a, b : TDoubleMatrix;
  ta : TThreadedMatrix;
  plain, thr : TDoubleMatrix;
  x, y : integer;
  worst : double;
  d : double;
begin
  a := MakePlain(5);
  b := MakePlain(6);
  ta := MakeThreaded(5);
  plain := nil;
  thr := nil;
  try
    plain := a.Add(b);
    thr := ta.Add(b);

    worst := 0;
    for x := 0 to cSize - 1 do
      for y := 0 to cSize - 1 do
      begin
        d := Abs(plain.Items[x, y] - thr.Items[x, y]);
        if d > worst then
          worst := d;
      end;

    AssertTrue(Format('max |plain - threaded| = %g (tolerance %g)', [worst, cTolerance]),
               worst <= cTolerance);
  finally
    thr.Free;
    plain.Free;
    ta.Free;
    b.Free;
    a.Free;
  end;
end;

procedure TThreadedMatrixTests.TestTransposeMatchesSingleThreaded;
var
  a : TDoubleMatrix;
  ta : TThreadedMatrix;
  plain, thr : TDoubleMatrix;
  x, y : integer;
  worst : double;
  d : double;
begin
  a := MakePlain(9);
  ta := MakeThreaded(9);
  plain := nil;
  thr := nil;
  try
    plain := a.Transpose;
    thr := ta.Transpose;

    worst := 0;
    for x := 0 to cSize - 1 do
      for y := 0 to cSize - 1 do
      begin
        d := Abs(plain.Items[x, y] - thr.Items[x, y]);
        if d > worst then
          worst := d;
      end;

    AssertTrue(Format('max |plain - threaded| = %g (tolerance %g)', [worst, cTolerance]),
               worst <= cTolerance);
  finally
    thr.Free;
    plain.Free;
    ta.Free;
    a.Free;
  end;
end;


// 768x768 is the size that reproduces the "pool never initialised" crash and,
// on the PasMP experiment branch, the stage-protocol deadlock. Keep it.
procedure TThreadedMatrixTests.TestMult768MatchesSingleThreaded;
var
  a, b, plain, thr : TDoubleMatrix;
  x, y : integer;
  worst, d : double;
begin
  a := TDoubleMatrix.Create(cBigSize, cBigSize, 0);
  b := TDoubleMatrix.Create(cBigSize, cBigSize, 0);
  plain := nil;
  thr := nil;
  try
    RandSeed := 123;
    for x := 0 to cBigSize - 1 do
      for y := 0 to cBigSize - 1 do
      begin
        a.Items[x, y] := Random;
        b.Items[x, y] := Random;
      end;

    plain := a.Mult(b);
    thr := TThreadedMatrix(a).Mult(b);

    worst := 0;
    for x := 0 to cBigSize - 1 do
      for y := 0 to cBigSize - 1 do
      begin
        d := Abs(plain.Items[x, y] - thr.Items[x, y]);
        if d > worst then
          worst := d;
      end;

    AssertTrue(Format('768x768: max |plain - threaded| = %g (tolerance %g)',
               [worst, cTolerance]), worst <= cTolerance);
  finally
    thr.Free;
    plain.Free;
    b.Free;
    a.Free;
  end;
end;

initialization
  RegisterTest(TThreadedMatrixTests);
end.
