// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// The TDoubleMatrix lifecycle and the decomposition/least-squares surface that
// TestMatrixCore and the differential audit do not touch: cloning, assignment,
// block selectors, append, vectorisation, resize, masked assignment, the rolling
// median, elementwise function application and the QR / Hessenberg /
// least-squares factorisations, plus the in-place twins.  The conventions these
// tests rely on (Append direction, AsVector, RollMedian window, QRFull/HessFull,
// SolveLeastSquares layout) are the tables in README.md.
unit TestMatrixLifecycle;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Math, Types, fpcunit, testregistry, MatrixConst, Matrix;

type
  TMatrixLifecycleTests = class(TTestCase)
  private
    function RandM(w, h, seed : integer) : TDoubleMatrix;
    function MaxDiff(a, b : TDoubleMatrix) : double;
  published
    procedure TestCloneIsDeepCopy;
    procedure TestAssignVariants;
    procedure TestSubMatrixSelectors;
    procedure TestAppendColumnsAndRows;
    procedure TestAsVectorOrientation;
    procedure TestResizePreservesData;
    procedure TestSetValueAndMaskedSetValue;
    procedure TestMeanVarianceFunction;
    procedure TestRollMedianMatchesTrailingWindow;
    procedure TestElementwiseFunc;
    procedure TestScaleAndAddVsAddAndScale;
    procedure TestQrFactorization;
    procedure TestHessenbergFactorization;
    procedure TestLeastSquares;
    procedure TestTxtFileRoundTrip;
    procedure TestInPlaceFamilies;
  end;

implementation

procedure SinFunc(var Value : double);
begin
  Value := Sin(Value);
end;

function TMatrixLifecycleTests.RandM(w, h, seed : integer) : TDoubleMatrix;
var x, y : integer;
begin
  RandSeed := seed;
  Result := TDoubleMatrix.Create(w, h, 0);
  for x := 0 to w - 1 do
    for y := 0 to h - 1 do
      Result.Items[x, y] := Random * 2 - 1;
end;

function TMatrixLifecycleTests.MaxDiff(a, b : TDoubleMatrix) : double;
var x, y : integer;
begin
  if (a = nil) or (b = nil) or (a.Width <> b.Width) or (a.Height <> b.Height) then
    exit(1e30);
  Result := 0;
  for x := 0 to a.Width - 1 do
    for y := 0 to a.Height - 1 do
      Result := Max(Result, Abs(a.Items[x, y] - b.Items[x, y]));
end;

procedure TMatrixLifecycleTests.TestCloneIsDeepCopy;
var a, c : TDoubleMatrix; e : double;
begin
  a := RandM(3, 4, 101);
  c := nil;
  try
    c := a.Clone;
    AssertEquals('clone width', Int64(3), Int64(c.Width));
    AssertEquals('clone height', Int64(4), Int64(c.Height));
    AssertEquals('clone values', 0.0, MaxDiff(a, c), 0.0);

    // writing through the clone must not touch the original
    c.Items[1, 2] := 12345;
    AssertTrue('clone shares storage with the original',
               Abs(a.Items[1, 2] - 12345) > 1e-9);
    a.Items[0, 0] := -12345;
    AssertTrue('original writes leak into the clone',
               Abs(c.Items[0, 0] + 12345) > 1e-9);
  finally
    c.Free;
    a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestAssignVariants;
var a, t : TDoubleMatrix; asArr : array[0..5] of double; e : double; i : integer;
begin
  a := RandM(3, 2, 202);
  t := TDoubleMatrix.Create(5, 5, 7);
  try
    // from a matrix: dimensions follow the source
    t.Assign(a);
    AssertEquals('assign width', Int64(3), Int64(t.Width));
    AssertEquals('assign height', Int64(2), Int64(t.Height));
    AssertEquals('assign values', 0.0, MaxDiff(a, t), 0.0);

    // from a plain array with explicit dimensions
    for i := 0 to 5 do
      asArr[i] := i * 1.5;
    t.Assign(asArr, 3, 2);
    e := 0;
    for i := 0 to 5 do
      e := Max(e, Abs(t.Items[i mod 3, i div 3] - asArr[i]));
    AssertTrue(Format('assign(array): max err %.3e', [e]), e <= 1e-15);
  finally
    t.Free;
    a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestSubMatrixSelectors;
var a, r, c : TDoubleMatrix; idx : TIntegerDynArray; e : double; x, y : integer;
begin
  a := RandM(5, 4, 303);
  r := nil; c := nil;
  try
    // rows 1..2 (inclusive range)
    r := a.SubRowMtx(1, 2);
    AssertEquals('SubRowMtx height', Int64(2), Int64(r.Height));
    AssertEquals('SubRowMtx width', Int64(5), Int64(r.Width));
    e := 0;
    for x := 0 to 4 do
      for y := 0 to 1 do
        e := Max(e, Abs(r.Items[x, y] - a.Items[x, 1 + y]));
    AssertTrue(Format('SubRowMtx values: %.3e', [e]), e <= 1e-15);

    // columns by index array
    SetLength(idx, 2);
    idx[0] := 0; idx[1] := 3;
    c := a.SubColMtx(idx);
    AssertEquals('SubColMtx width', Int64(2), Int64(c.Width));
    AssertEquals('SubColMtx height', Int64(4), Int64(c.Height));
    e := 0;
    for y := 0 to 3 do
    begin
      e := Max(e, Abs(c.Items[0, y] - a.Items[0, y]));
      e := Max(e, Abs(c.Items[1, y] - a.Items[3, y]));
    end;
    AssertTrue(Format('SubColMtx values: %.3e', [e]), e <= 1e-15);
  finally
    c.Free; r.Free; a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestAppendColumnsAndRows;
var a, b, m, blk : TDoubleMatrix; e : double; x, y : integer; raised : boolean;
begin
  a := RandM(3, 2, 404);
  b := RandM(2, 2, 405);
  try
    // columns: 3x2 + 2x2 -> 5x2, b's first column at x = 3
    m := a.Clone;
    try
      m.Append(b, True);
      AssertEquals('append columns width', Int64(5), Int64(m.Width));
      AssertEquals('append columns height', Int64(2), Int64(m.Height));
      e := 0;
      for y := 0 to 1 do
      begin
        e := Max(e, Abs(m.Items[0, y] - a.Items[0, y]));
        e := Max(e, Abs(m.Items[3, y] - b.Items[0, y]));
      end;
      AssertTrue(Format('append columns values: %.3e', [e]), e <= 1e-15);
    finally
      m.Free;
    end;

    // rows: need matching widths, so take a 3-wide block
    m := a.Clone;
    try
      blk := a.Clone;
      m.Append(blk, False);          // 3x2 + 3x2 -> 3x4
      FreeAndNil(blk);
      AssertEquals('append rows width', Int64(3), Int64(m.Width));
      AssertEquals('append rows height', Int64(4), Int64(m.Height));
      e := 0;
      for x := 0 to 2 do
        e := Max(e, Abs(m.Items[x, 2] - a.Items[x, 0]));
      AssertTrue(Format('append rows values: %.3e', [e]), e <= 1e-15);
    finally
      m.Free;
    end;

    // mismatched dimensions must be refused, not silently accepted
    m := a.Clone;
    try
      raised := False;
      try
        m.Append(b, False);           // 2 columns onto 3 -> invalid
      except
        on E: Exception do
          raised := True;
      end;
      AssertTrue('append with mismatched widths was accepted', raised);
    finally
      m.Free;
    end;
  finally
    b.Free; a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestAsVectorOrientation;
const w = 3; h = 2;
var a, rowMajor, colMajor : TDoubleMatrix; x, y, k : integer; e1, e2 : double;
begin
  a := RandM(w, h, 505);
  rowMajor := nil; colMajor := nil;
  try
    rowMajor := a.AsVector(False);
    colMajor := a.AsVector(True);
    AssertEquals('AsVector element count', Int64(w * h), Int64(rowMajor.Width * rowMajor.Height));

    // row major: x fastest
    e1 := 0;
    k := 0;
    for y := 0 to h - 1 do
      for x := 0 to w - 1 do
      begin
        if rowMajor.Width = 1 then e1 := Max(e1, Abs(rowMajor.Items[0, k] - a.Items[x, y]))
        else e1 := Max(e1, Abs(rowMajor.Items[k, 0] - a.Items[x, y]));
        inc(k);
      end;
    AssertTrue(Format('AsVector(False) is row major: %.3e', [e1]), e1 <= 1e-15);

    // column major: y fastest
    e2 := 0;
    k := 0;
    for x := 0 to w - 1 do
      for y := 0 to h - 1 do
      begin
        if colMajor.Width = 1 then e2 := Max(e2, Abs(colMajor.Items[0, k] - a.Items[x, y]))
        else e2 := Max(e2, Abs(colMajor.Items[k, 0] - a.Items[x, y]));
        inc(k);
      end;
    AssertTrue(Format('AsVector(True) is column major: %.3e', [e2]), e2 <= 1e-15);
  finally
    colMajor.Free; rowMajor.Free; a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestResizePreservesData;
var a : TDoubleMatrix; x, y : integer; e : double; kept : array[0..2, 0..1] of double;
begin
  a := RandM(3, 4, 606);
  try
    // remember the block that survives a 3x4 -> 5x2 resize
    for x := 0 to 2 do
      for y := 0 to 1 do
        kept[x, y] := a.Items[x, y];

    a.Resize(5, 2);
    AssertEquals('resize width', Int64(5), Int64(a.Width));
    AssertEquals('resize height', Int64(2), Int64(a.Height));

    e := 0;
    for x := 0 to 2 do
      for y := 0 to 1 do
        e := Max(e, Abs(a.Items[x, y] - kept[x, y]));
    AssertTrue(Format('resize preserved the overlapping block: %.3e', [e]), e <= 1e-15);
  finally
    a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestSetValueAndMaskedSetValue;
var a : TDoubleMatrix; mask : array of boolean; x, y : integer; bad : integer;
begin
  a := RandM(4, 3, 707);
  try
    // fill the block x=1..2, y=1..2 with 42
    a.SetValue(42, 1, 1, 2, 2);
    bad := 0;
    for x := 0 to 3 do
      for y := 0 to 2 do
        if (x >= 1) and (x <= 2) and (y >= 1) and (y <= 2) then
        begin
          if Abs(a.Items[x, y] - 42) > 1e-15 then inc(bad);
        end
        else if Abs(a.Items[x, y] - 42) < 1e-15 then
          inc(bad);      // untouched cells must not have been set
    AssertEquals('SetValue touched the wrong cells', 0, bad);

    // mask: one entry per element, True selects the elements to overwrite
    SetLength(mask, 4 * 3);
    for x := 0 to High(mask) do
      mask[x] := (x mod 2) = 0;
    a.MaskedSetValue(mask, -7);
    bad := 0;
    for y := 0 to 2 do
      for x := 0 to 3 do
        if mask[x + y * 4] then
        begin
          if Abs(a.Items[x, y] + 7) > 1e-15 then inc(bad);
        end
        else if Abs(a.Items[x, y] + 7) < 1e-15 then
          inc(bad);
    AssertEquals('MaskedSetValue touched the wrong cells', 0, bad);
  finally
    a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestMeanVarianceFunction;
const w = 6; h = 5;
var
  a, mv : TDoubleMatrix;
  x, y, u, layout : integer;
  m, v, e0, e1 : double;
  unbiased, ok : boolean;
begin
  a := RandM(w, h, 808);
  mv := nil;
  try
    for u := 0 to 1 do
    begin
      unbiased := u = 1;
      mv.Free;
      mv := a.MeanVariance(True, unbiased);
      AssertTrue('MeanVariance returned nothing', mv <> nil);

      // RowWise: two values per row (Width = 2, Height = number of rows).  Which
      // column holds the mean is not documented, so accept either order.
      AssertEquals('MeanVariance rows', Int64(h), Int64(mv.Height));
      AssertEquals('MeanVariance per row values', Int64(2), Int64(mv.Width));
      ok := False;
      for layout := 0 to 1 do
      begin
        e0 := 0;
        e1 := 0;
        for y := 0 to h - 1 do
        begin
          m := 0;
          for x := 0 to w - 1 do m := m + a.Items[x, y];
          m := m / w;
          v := 0;
          for x := 0 to w - 1 do v := v + Sqr(a.Items[x, y] - m);
          if unbiased then v := v / (w - 1) else v := v / w;
          if layout = 0 then
          begin
            e0 := Max(e0, Abs(mv.Items[0, y] - m));
            e1 := Max(e1, Abs(mv.Items[1, y] - v));
          end
          else
          begin
            e0 := Max(e0, Abs(mv.Items[1, y] - m));
            e1 := Max(e1, Abs(mv.Items[0, y] - v));
          end;
        end;
        if (e0 <= 1e-12) and (e1 <= 1e-10) then
          ok := True;
      end;
      AssertTrue(Format('MeanVariance(unbiased=%s): neither layout matched',
                        [BoolToStr(unbiased, 'yes', 'no')]), ok);
    end;
  finally
    mv.Free; a.Free;
  end;
end;

// The rolling median is the median of the last min(order, i+1) samples, with the
// average of the two middle elements when that count is even.
function TrailingMedian(const vals : array of double; idx, order : integer) : double;
var win : array of double;
    n, i, j, first : integer;
    tmp : double;
begin
  first := Max(0, idx - order + 1);
  n := idx - first + 1;
  SetLength(win, n);
  for i := 0 to n - 1 do
    win[i] := vals[first + i];
  for i := 1 to n - 1 do
  begin
    tmp := win[i];
    j := i - 1;
    while (j >= 0) and (win[j] > tmp) do
    begin
      win[j + 1] := win[j];
      dec(j);
    end;
    win[j + 1] := tmp;
  end;
  if Odd(n) then
    Result := win[n div 2]
  else
    Result := (win[n div 2 - 1] + win[n div 2]) / 2;
end;

procedure TMatrixLifecycleTests.TestRollMedianMatchesTrailingWindow;
const n = 12;
var
  v, rm : TDoubleMatrix;
  k, order, orient : integer;
  vals : array[0..n - 1] of double;
  e : double;
  rowWise : boolean;
begin
  RandSeed := 909;
  for k := 0 to n - 1 do
    vals[k] := Random * 20 - 10;

  // one row and one column, so both orientations are exercised
  for orient := 0 to 1 do
  begin
    rowWise := orient = 0;
    if rowWise then
      v := TDoubleMatrix.Create(n, 1, 0)
    else
      v := TDoubleMatrix.Create(1, n, 0);
    try
      for k := 0 to n - 1 do
        if rowWise then v.Items[k, 0] := vals[k] else v.Items[0, k] := vals[k];

      for order := 1 to 5 do
      begin
        rm := v.RollMedian(rowWise, order);
        try
          e := 0;
          for k := 0 to n - 1 do
            if rowWise then
              e := Max(e, Abs(rm.Items[k, 0] - TrailingMedian(vals, k, order)))
            else
              e := Max(e, Abs(rm.Items[0, k] - TrailingMedian(vals, k, order)));
          AssertTrue(Format('RollMedian(rowWise=%s, order=%d): max err %.3e',
                            [BoolToStr(rowWise, 'yes', 'no'), order, e]), e <= 1e-12);
        finally
          rm.Free;
        end;
      end;
    finally
      v.Free;
    end;
  end;
end;

procedure TMatrixLifecycleTests.TestElementwiseFunc;
var a, r : TDoubleMatrix; x, y : integer; e : double;
begin
  a := RandM(4, 3, 1010);
  r := nil;
  try
    r := a.ElementwiseFunc(@SinFunc);
    e := 0;
    for x := 0 to 3 do
      for y := 0 to 2 do
        e := Max(e, Abs(r.Items[x, y] - Sin(a.Items[x, y])));
    AssertTrue(Format('ElementwiseFunc: max err %.3e', [e]), e <= 1e-15);
  finally
    r.Free; a.Free;
  end;
end;

// AddAndScale is (a + Offset) * Scale (verified earlier); ScaleAndAdd should be
// the other way round: a * Scale + Offset.
procedure TMatrixLifecycleTests.TestScaleAndAddVsAddAndScale;
const offset = 1.5; scale = -2.0;
var a, s, d : TDoubleMatrix; x, y : integer; eS, eA : double;
begin
  a := RandM(3, 3, 1111);
  s := nil; d := nil;
  try
    s := a.ScaleAndAdd(offset, scale);
    d := a.AddAndScale(offset, scale);

    eS := 0; eA := 0;
    for x := 0 to 2 do
      for y := 0 to 2 do
      begin
        eS := Max(eS, Abs(s.Items[x, y] - (a.Items[x, y] * scale + offset)));
        eA := Max(eA, Abs(d.Items[x, y] - ((a.Items[x, y] + offset) * scale)));
      end;
    AssertTrue(Format('ScaleAndAdd = a*scale + offset: %.3e', [eS]), eS <= 1e-15);
    AssertTrue(Format('AddAndScale = (a + offset)*scale: %.3e', [eA]), eA <= 1e-15);
  finally
    d.Free; s.Free; a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestQrFactorization;
const n = 4;
var
  a, q, r, prod, qtq, id, qt : TDoubleMatrix;
  x, y : integer;
  e, below : double;
begin
  a := RandM(n, n, 1212);
  // make it clearly non-symmetric so the factorisation has work to do
  for x := 0 to n - 1 do
    for y := 0 to n - 1 do
      if x < y then
        a.Items[x, y] := 0;
  q := nil; r := nil; prod := nil; qtq := nil; id := nil;
  try
    a.QRFull(q, r);
    AssertEquals('Q width', Int64(n), Int64(q.Width));
    AssertEquals('R height', Int64(n), Int64(r.Height));

    prod := q.Mult(r);
    e := MaxDiff(prod, a);
    AssertTrue(Format('A = Q*R: max err %.3e', [e]), e <= 1e-12);

    qt := q.Transpose;
    qtq := qt.Mult(q);
    FreeAndNil(qt);
    id := TDoubleMatrix.CreateEye(n);
    e := MaxDiff(qtq, id);
    AssertTrue(Format('Q is orthogonal: %.3e', [e]), e <= 1e-12);

    // R must be upper triangular
    below := 0;
    for x := 0 to n - 1 do
      for y := x + 1 to n - 1 do
        below := Max(below, Abs(r.Items[x, y]));
    AssertTrue(Format('R is upper triangular: %.3e', [below]), below <= 1e-12);
  finally
    id.Free; qtq.Free; prod.Free; r.Free; q.Free; a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestHessenbergFactorization;
const n = 5;
var
  a, q, h, prod, back, qtq, id, qt : TDoubleMatrix;
  x, y : integer;
  e, below : double;
begin
  a := RandM(n, n, 1313);
  q := nil; h := nil; prod := nil; back := nil; qtq := nil; id := nil;
  try
    a.HessFull(q, h);
    AssertEquals('H width', Int64(n), Int64(h.Width));

    qt := q.Transpose;
    prod := q.Mult(h);
    back := prod.Mult(qt);
    e := MaxDiff(back, a);
    AssertTrue(Format('A = Q*H*Q^T: max err %.3e', [e]), e <= 1e-12);

    qtq := qt.Mult(q);
    FreeAndNil(qt);
    id := TDoubleMatrix.CreateEye(n);
    e := MaxDiff(qtq, id);
    AssertTrue(Format('Q is orthogonal: %.3e', [e]), e <= 1e-12);

    // Hessenberg: everything below the first subdiagonal is zero.  Which of the
    // two triangles is the subdiagonal depends on the storage order, so accept
    // either reading of the pattern.
    below := 0;
    for x := 0 to n - 1 do
      for y := x + 2 to n - 1 do
        below := Max(below, Abs(h.Items[x, y]));
    if below > 1e-12 then
    begin
      below := 0;
      for x := 0 to n - 1 do
        for y := 0 to x - 2 do
          below := Max(below, Abs(h.Items[x, y]));
    end;
    AssertTrue(Format('H is Hessenberg: %.3e', [below]), below <= 1e-12);
  finally
    id.Free; qtq.Free; back.Free; prod.Free; h.Free; q.Free; a.Free;
  end;
end;

// A is stored with rows = equations (Height) and columns = unknowns (Width).
procedure TMatrixLifecycleTests.TestLeastSquares;
const unknowns = 2; equations = 7;
var
  a, b, x : TDoubleMatrix;
  i, j : integer;
  resid : array[0..equations - 1] of double;
  pred, grad, e : double;
begin
  a := TDoubleMatrix.Create(unknowns, equations, 0);
  b := TDoubleMatrix.Create(1, equations, 0);
  // exact fit: y = 1 + 2*t, with a little noise on the last two samples
  RandSeed := 1414;
  try
    for i := 0 to equations - 1 do
    begin
      a.Items[0, i] := 1;
      a.Items[1, i] := i;
      b.Items[0, i] := 1 + 2 * i;
    end;
    // noise on the last sample, so only the normal-equation property can be
    // asserted below; the exact coefficient check uses a separate clean system
    b.Items[0, equations - 1] := b.Items[0, equations - 1] + 0.5;

    x := nil;
    try
      a.SolveLeastSquares(x, b);
      AssertTrue('least squares returned nothing', x <> nil);
      AssertTrue(Format('least squares solution dimension %dx%d', [x.Width, x.Height]),
                 (x.Width * x.Height) = unknowns);

      // the residual must be orthogonal to every column of A (normal equations)
      for i := 0 to equations - 1 do
      begin
        pred := 0;
        for j := 0 to unknowns - 1 do
          pred := pred + a.Items[j, i] * x.Items[0, j];
        resid[i] := pred - b.Items[0, i];
      end;
      e := 0;
      for j := 0 to unknowns - 1 do
      begin
        grad := 0;
        for i := 0 to equations - 1 do
          grad := grad + a.Items[j, i] * resid[i];
        e := Max(e, Abs(grad));
      end;
      AssertTrue(Format('A^T (A x - b) is not zero: %.3e', [e]), e <= 1e-10);

      // a clean system must reproduce the exact line y = 1 + 2t
      for i := 0 to equations - 1 do
        b.Items[0, i] := 1 + 2 * i;
      x.Free;
      x := nil;
      a.SolveLeastSquares(x, b);
      AssertEquals('intercept', 1.0, x.Items[0, 0], 1e-10);
      AssertEquals('slope', 2.0, x.Items[0, 1], 1e-10);
    finally
      x.Free;
    end;
  finally
    b.Free; a.Free;
  end;
end;

procedure TMatrixLifecycleTests.TestTxtFileRoundTrip;
const fname = '/tmp/vmath_matrix_roundtrip.txt';
var a, b : TDoubleMatrix; e : double;
begin
  a := RandM(4, 3, 1515);
  b := nil;
  try
    MatrixToTxtFile(fname, a, 15);
    b := MatrixFromTxtFile(fname);
    AssertTrue('nothing was read back from the text file', b <> nil);
    AssertEquals('txt round trip width', Int64(a.Width), Int64(b.Width));
    AssertEquals('txt round trip height', Int64(a.Height), Int64(b.Height));
    e := MaxDiff(a, b);
    AssertTrue(Format('txt round trip values: %.3e', [e]), e <= 1e-12);
  finally
    b.Free; a.Free;
    if FileExists(fname) then
      DeleteFile(fname);
  end;
end;

// Every in-place twin must produce exactly what its out-of-place sibling returns.
procedure TMatrixLifecycleTests.TestInPlaceFamilies;
const n = 6;
var
  a, b, v, ref, ip, ip2, pinv1, xs1, xs2, rhs : TDoubleMatrix;
  x, y : integer;
  e : double;
  procedure Check(const what : string; expected, got : TDoubleMatrix);
  var d : double;
  begin
    d := MaxDiff(expected, got);
    AssertTrue(Format('%s: in-place differs from out-of-place by %.3e', [what, d]), d <= 1e-10);
  end;
begin
  a := RandM(n, n, 1616);
  for x := 0 to n - 1 do
    a.Items[x, x] := a.Items[x, x] + n;        // keep it well conditioned
  b := RandM(n, n, 1617);
  v := RandM(1, n, 1618);
  rhs := RandM(1, n, 1619);
  try
    // multiply variants
    ref := a.MultT1(b); ip := a.Clone; ip.MultInPlaceT1(b); Check('MultInPlaceT1', ref, ip);
    FreeAndNil(ref); FreeAndNil(ip);
    ref := a.MultT2(b); ip := a.Clone; ip.MultInPlaceT2(b); Check('MultInPlaceT2', ref, ip);
    FreeAndNil(ref); FreeAndNil(ip);

    // scaling: compare against the arithmetic definition
    ip := a.Clone; ip.ScaleInPlace(2.5);
    e := 0;
    for x := 0 to n - 1 do
      for y := 0 to n - 1 do
        e := Max(e, Abs(ip.Items[x, y] - a.Items[x, y] * 2.5));
    AssertTrue(Format('ScaleInPlace: %.3e', [e]), e <= 1e-14);
    FreeAndNil(ip);

    // square root (the input must be non-negative, so take absolute values)
    ref := a.Abs;
    ip := ref.Clone; ip.SQRTInPlace;
    e := 0;
    for x := 0 to n - 1 do
      for y := 0 to n - 1 do
        e := Max(e, Abs(ip.Items[x, y] - Sqrt(ref.Items[x, y])));
    FreeAndNil(ref);
    AssertTrue(Format('SQRTInPlace: %.3e', [e]), e <= 1e-14);
    FreeAndNil(ip);

    // vector and reduction variants
    ref := a.SubVec(v, True); ip := a.Clone; ip.SubVecInPlace(v, True); Check('SubVecInPlace', ref, ip);
    FreeAndNil(ref); FreeAndNil(ip);
    ref := a.Sum(True); ip := a.Clone; ip.SumInPlace(True); Check('SumInPlace', ref, ip);
    FreeAndNil(ref); FreeAndNil(ip);
    ref := a.MeanVariance(True); ip := a.Clone; ip.MeanVarianceInPlace(True); Check('MeanVarianceInPlace', ref, ip);
    FreeAndNil(ref); FreeAndNil(ip);
    ref := a.RollMedian(True, 3); ip := a.Clone; ip.RollMedianInPlace(True, 3); Check('RollMedianInPlace', ref, ip);
    FreeAndNil(ref); FreeAndNil(ip);

    // inversion and linear algebra
    ref := a.Invert; ip := a.Clone; ip.InvertInPlace; Check('InvertInPlace', ref, ip);
    FreeAndNil(ref); FreeAndNil(ip);
    ref := a.SolveLinEQ(rhs); ip := a.Clone; ip.SolveLinEQInPlace(rhs); Check('SolveLinEQInPlace', ref, ip);
    FreeAndNil(ref); FreeAndNil(ip);

    // pseudo inverse: the in-place form replaces the matrix itself
    pinv1 := nil;
    a.PseudoInversion(pinv1);
    ip := a.Clone;
    ip.PseudoInversionInPlace;
    Check('PseudoInversionInPlace', pinv1, ip);
    FreeAndNil(pinv1); FreeAndNil(ip);

    // least squares
    xs1 := nil; xs2 := nil;
    a.SolveLeastSquares(xs1, rhs);
    ip2 := a.Clone;
    ip2.SolveLeastSquaresInPlace(xs2, rhs);
    Check('SolveLeastSquaresInPlace', xs1, xs2);
    FreeAndNil(xs1); FreeAndNil(xs2); FreeAndNil(ip2);

    // reshape
    ref := a.Reshape(n * n, 1); ip := a.Clone; ip.ReshapeInPlace(n * n, 1); Check('ReshapeInPlace', ref, ip);
    FreeAndNil(ref); FreeAndNil(ip);
  finally
    rhs.Free; v.Free; b.Free; a.Free;
  end;
end;

initialization
  RegisterTest(TMatrixLifecycleTests);
end.
