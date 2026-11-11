// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// FPCUnit suite for the core TDoubleMatrix API.
unit TestMatrixCore;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, Matrix;

type
  TMatrixCoreTests = class(TTestCase)
  published
    procedure TestCreateDimensions;
    procedure TestSetAndGetItems;
    procedure TestAdd;
    procedure TestMultByIdentity;
    procedure TestMultByScalar;
    procedure TestTranspose;
    procedure TestSum;
    procedure TestMeanRowWise;
    procedure TestMeanColWise;
    procedure TestDeterminant;
  end;

implementation

const
  cDelta = 1e-12;

// Items[x, y]:  [ 1 2 ]
//               [ 3 4 ]
function MakeMatrix2x2 : TDoubleMatrix;
begin
  Result := TDoubleMatrix.Create(2, 2, 0);
  Result.Items[0, 0] := 1;
  Result.Items[0, 1] := 2;
  Result.Items[1, 0] := 3;
  Result.Items[1, 1] := 4;
end;

function MakeIdentity(N : integer; Scale : double) : TDoubleMatrix;
var
  x, y : integer;
begin
  Result := TDoubleMatrix.Create(N, N, 0);
  for x := 0 to N - 1 do
    for y := 0 to N - 1 do
      if x = y then
        Result.Items[x, y] := Scale
      else
        Result.Items[x, y] := 0;
end;

procedure TMatrixCoreTests.TestCreateDimensions;
var
  M : TDoubleMatrix;
begin
  M := TDoubleMatrix.Create(3, 2, 0);
  try
    AssertEquals('width', Int64(3), Int64(M.Width));
    AssertEquals('height', Int64(2), Int64(M.Height));
  finally
    M.Free;
  end;
end;

procedure TMatrixCoreTests.TestSetAndGetItems;
var
  M : TDoubleMatrix;
begin
  M := TDoubleMatrix.Create(2, 2, 0);
  try
    M.Items[1, 0] := 42.5;
    AssertEquals('Items[1,0]', 42.5, M.Items[1, 0], cDelta);
  finally
    M.Free;
  end;
end;

procedure TMatrixCoreTests.TestAdd;
var
  A, B, C : TDoubleMatrix;
begin
  A := MakeMatrix2x2;
  B := TDoubleMatrix.Create(2, 2, 10);
  C := nil;
  try
    C := A.Add(B);
    AssertEquals('C[0,0]', 11.0, C.Items[0, 0], cDelta);
    AssertEquals('C[0,1]', 12.0, C.Items[0, 1], cDelta);
    AssertEquals('C[1,0]', 13.0, C.Items[1, 0], cDelta);
    AssertEquals('C[1,1]', 14.0, C.Items[1, 1], cDelta);
  finally
    C.Free;
    B.Free;
    A.Free;
  end;
end;

procedure TMatrixCoreTests.TestMultByIdentity;
var
  A, I, C : TDoubleMatrix;
  x, y : integer;
begin
  A := MakeMatrix2x2;
  I := MakeIdentity(2, 1);
  C := nil;
  try
    C := A.Mult(I);
    for x := 0 to 1 do
      for y := 0 to 1 do
        AssertEquals(Format('C[%d,%d]', [x, y]), A.Items[x, y], C.Items[x, y], cDelta);
  finally
    C.Free;
    I.Free;
    A.Free;
  end;
end;

procedure TMatrixCoreTests.TestMultByScalar;
var
  A, I, C : TDoubleMatrix;
begin
  A := MakeMatrix2x2;
  I := MakeIdentity(2, 3);
  C := nil;
  try
    C := A.Mult(I);
    AssertEquals('C[0,0]', 3.0, C.Items[0, 0], cDelta);
    AssertEquals('C[0,1]', 6.0, C.Items[0, 1], cDelta);
    AssertEquals('C[1,0]', 9.0, C.Items[1, 0], cDelta);
    AssertEquals('C[1,1]', 12.0, C.Items[1, 1], cDelta);
  finally
    C.Free;
    I.Free;
    A.Free;
  end;
end;

procedure TMatrixCoreTests.TestTranspose;
var
  A, T : TDoubleMatrix;
begin
  A := MakeMatrix2x2;
  T := nil;
  try
    T := A.Transpose;
    AssertEquals('width', Int64(2), Int64(T.Width));
    AssertEquals('height', Int64(2), Int64(T.Height));
    AssertEquals('T[1,0]', A.Items[0, 1], T.Items[1, 0], cDelta);
    AssertEquals('T[0,1]', A.Items[1, 0], T.Items[0, 1], cDelta);
  finally
    T.Free;
    A.Free;
  end;
end;

procedure TMatrixCoreTests.TestSum;
var
  A : TDoubleMatrix;
begin
  A := MakeMatrix2x2;
  try
    AssertEquals('sum', 10.0, A.Sum, cDelta);
  finally
    A.Free;
  end;
end;

procedure TMatrixCoreTests.TestMeanRowWise;
var
  A, M : TDoubleMatrix;
begin
  A := MakeMatrix2x2;
  M := nil;
  try
    M := A.Mean(True);
    AssertEquals('width', Int64(1), Int64(M.Width));
    AssertEquals('height', Int64(2), Int64(M.Height));
    // RowWise=True reduces along x: one mean per y (mean of column y)
    AssertEquals('y0', 2.0, M.Items[0, 0], cDelta);
    AssertEquals('y1', 3.0, M.Items[0, 1], cDelta);
  finally
    M.Free;
    A.Free;
  end;
end;

procedure TMatrixCoreTests.TestMeanColWise;
var
  A, M : TDoubleMatrix;
begin
  A := MakeMatrix2x2;
  M := nil;
  try
    M := A.Mean(False);
    AssertEquals('width', Int64(2), Int64(M.Width));
    AssertEquals('height', Int64(1), Int64(M.Height));
    // RowWise=False reduces along y: one mean per x (mean of row x)
    AssertEquals('x0', 1.5, M.Items[0, 0], cDelta);
    AssertEquals('x1', 3.5, M.Items[1, 0], cDelta);
  finally
    M.Free;
    A.Free;
  end;
end;

procedure TMatrixCoreTests.TestDeterminant;
var
  A : TDoubleMatrix;
begin
  A := MakeMatrix2x2;
  try
    AssertEquals('det', -2.0, A.Determinant, cDelta);
  finally
    A.Free;
  end;
end;

initialization
  RegisterTest(TMatrixCoreTests);
end.
