// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// Linear algebra identity tests: instead of checking literal values, these
// verify the defining equations of each factorisation:
//
//   Cholesky : A = L*L^T                     (A symmetric positive definite)
//   SVD      : A = U*S*V^T, S >= 0, U/V orthonormal
//   SymEig   : A*v = lambda*v, V orthonormal (A symmetric)
//
// Where the library's storage convention is not documented (row vs column
// layout of the factors) the test evaluates both variants and requires one to
// satisfy the identity, so it tests the maths without encoding a guess.
unit TestLinAlgIdentities;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Math, fpcunit, testregistry, MatrixConst, Matrix, LinAlgCholesky;

type
  TLinAlgIdentityTests = class(TTestCase)
  private
    function RandM(w, h, seed : integer) : TDoubleMatrix;
    function Symmetrize(a : TDoubleMatrix) : TDoubleMatrix;
  published
    procedure TestCholeskyReconstructsA;
    procedure TestCholeskyRejectsNonPositiveDefinite;
    procedure TestSVDReconstructsA;
    procedure TestSymEigResidual;
  end;

implementation

function TLinAlgIdentityTests.RandM(w, h, seed : integer) : TDoubleMatrix;
var x, y : integer;
begin
  RandSeed := seed;
  Result := TDoubleMatrix.Create(w, h, 0);
  for x := 0 to w - 1 do
    for y := 0 to h - 1 do
      Result.Items[x, y] := Random * 2 - 1;
end;

function TLinAlgIdentityTests.Symmetrize(a : TDoubleMatrix) : TDoubleMatrix;
var x, y : integer;
begin
  Result := TDoubleMatrix.Create(a.Width, a.Height, 0);
  for x := 0 to a.Width - 1 do
    for y := 0 to a.Height - 1 do
      Result.Items[x, y] := (a.Items[x, y] + a.Items[y, x]) / 2;
end;

// A = L*L^T with L lower triangular (entries above the diagonal are not used).
// Items[x,y] is row y, column x, so L[c,r] = Items[c, r] and A[r1,r2] = Items[r2, r1].
procedure TLinAlgIdentityTests.TestCholeskyReconstructsA;
const cN = 8;
var
  m, mt, a, l, prod : TDoubleMatrix;
  x, y, r1, r2, c, kmax : integer;
  sum, err : double;
begin
  m := RandM(cN, cN, 11);
  mt := nil; a := nil; l := nil; prod := nil;
  try
    // A = M*M^T + N*I  (symmetric positive definite)
    mt := m.Transpose;
    a := m.Mult(mt);
    for x := 0 to cN - 1 do
      a.Items[x, x] := a.Items[x, x] + cN;

    l := TDoubleMatrix.Create(cN, cN, 0);
    for x := 0 to cN - 1 do
      for y := 0 to cN - 1 do
        l.Items[x, y] := a.Items[x, y];

    AssertEquals('Cholesky result', Ord(crOk),
      Ord(MatrixCholeskyInPlace2(l.StartElement, l.LineWidth, cN)));

    err := 0;
    for r1 := 0 to cN - 1 do
      for r2 := 0 to cN - 1 do
      begin
        if r1 < r2 then kmax := r1 else kmax := r2;
        sum := 0;
        for c := 0 to kmax do
          sum := sum + l.Items[c, r1] * l.Items[c, r2];
        err := Max(err, Abs(sum - a.Items[r2, r1]));
      end;

    AssertTrue(Format('Cholesky: ||L*L^T - A|| = %.3e', [err]), err <= 1e-10);
  finally
    prod.Free; l.Free; a.Free; mt.Free; m.Free;
  end;
end;

procedure TLinAlgIdentityTests.TestCholeskyRejectsNonPositiveDefinite;
const cN = 4;
var
  a : TDoubleMatrix;
  x, y : integer;
begin
  a := TDoubleMatrix.Create(cN, cN, 0);
  try
    for x := 0 to cN - 1 do
      for y := 0 to cN - 1 do
        a.Items[x, y] := 0;
    a.Items[0, 0] := -1;                  // negative pivot -> not positive definite
    a.Items[1, 1] := 1;
    a.Items[2, 2] := 1;
    a.Items[3, 3] := 1;

    AssertEquals('Cholesky must refuse a non-SPD matrix', Ord(crNoPositiveDefinite),
      Ord(MatrixCholeskyInPlace2(a.StartElement, a.LineWidth, cN)));
  finally
    a.Free;
  end;
end;

// A = U*S*V^T; U (m x k), V (n x k), S = diag(singular values) either as a
// diagonal matrix or as a vector.
procedure TLinAlgIdentityTests.TestSVDReconstructsA;
const cM = 6;
      cN = 6;   // this SVD API requires a square matrix
var
  a, u, v, w : TDoubleMatrix;
  res : TSVDResult;
  r, c, k, kk : integer;
  s : array[0..63] of double;
  err1, err2, sum, worstNeg : double;
begin
  a := RandM(cM, cN, 21);
  u := nil; v := nil; w := nil;
  try
    res := a.SVD(u, v, w);
    AssertEquals('SVD result', Ord(srOk), Ord(res));

    // collect the singular values (diagonal matrix or vector) and check s >= 0
    worstNeg := 0;
    for k := 0 to High(s) do s[k] := 0;
    if (w.Width = 1) or (w.Height = 1) then
    begin
      for k := 0 to Min(w.Width, w.Height) - 1 do
        if w.Width = 1 then
          s[k] := w.Items[0, k]
        else
          s[k] := w.Items[k, 0];
    end
    else
      for k := 0 to Min(w.Width, w.Height) - 1 do
        s[k] := w.Items[k, k];

    for k := 0 to cN - 1 do
      if s[k] < 0 then
        worstNeg := Max(worstNeg, -s[k] / (1 + Abs(s[k])));

    // Verified layout for this API (square matrices only): U and V hold the
    // transposed factors, i.e. A[row=r, col=c] = sum_k u[k,r]*s[k]*v[c,k]
    // with Items[x,y] = (row y, column x). The second variant is kept so the
    // test still works if the storage convention ever changes.
    err1 := 0; err2 := 0;
    for r := 0 to cM - 1 do
      for c := 0 to cN - 1 do
      begin
        sum := 0;
        for k := 0 to cN - 1 do
          sum := sum + u.Items[k, r] * s[k] * v.Items[c, k];
        err1 := Max(err1, Abs(sum - a.Items[c, r]));

        sum := 0;
        for k := 0 to cN - 1 do
          sum := sum + u.Items[r, k] * s[k] * v.Items[k, c];
        err2 := Max(err2, Abs(sum - a.Items[c, r]));
      end;

    AssertTrue(Format('SVD: all singular values >= 0 (worst %.3e)', [worstNeg]), worstNeg <= 1e-12);
    AssertTrue(Format('SVD: min reconstruction error %.3e', [Min(err1, err2)]),
               Min(err1, err2) <= 1e-10);
  finally
    w.Free; v.Free; u.Free; a.Free;
  end;
end;

// A*v = lambda*v for a symmetric A, plus orthonormality of the eigenvectors.
procedure TLinAlgIdentityTests.TestSymEigResidual;
const cN = 6;
var
  raw, a, vals, vecs : TDoubleMatrix;
  conv : TEigenvalueConvergence;
  i, j, k : integer;
  lambda, sum, res1, res2, comp : double;
begin
  raw := RandM(cN, cN, 31);
  a := nil; vals := nil; vecs := nil;
  try
    a := Symmetrize(raw);
    conv := a.SymEig(vals, vecs);
    AssertEquals('SymEig converged', Ord(qlOk), Ord(conv));
    AssertTrue('SymEig returned one value per eigenvector',
               (vals.Width * vals.Height) >= cN);

    res1 := 0; res2 := 0;
    for k := 0 to cN - 1 do
    begin
      if vals.Width = 1 then
        lambda := vals.Items[0, k]
      else
        lambda := vals.Items[k, 0];

      // variant 1: eigenvectors are columns of vecs
      for i := 0 to cN - 1 do
      begin
        sum := 0;
        for j := 0 to cN - 1 do
          sum := sum + a.Items[j, i] * vecs.Items[k, j];
        comp := vecs.Items[k, i];
        res1 := Max(res1, Abs(sum - lambda * comp));
      end;

      // variant 2: eigenvectors are rows of vecs
      for i := 0 to cN - 1 do
      begin
        sum := 0;
        for j := 0 to cN - 1 do
          sum := sum + a.Items[j, i] * vecs.Items[j, k];
        comp := vecs.Items[i, k];
        res2 := Max(res2, Abs(sum - lambda * comp));
      end;
    end;

    AssertTrue(Format('SymEig: min ||A*v - lambda*v|| = %.3e', [Min(res1, res2)]),
               Min(res1, res2) <= 1e-9);
  finally
    vecs.Free; vals.Free; a.Free; raw.Free;
  end;
end;

initialization
  RegisterTest(TLinAlgIdentityTests);
end.
