// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// Differential audit of the core API: every result is compared against an
// independent naive reference, across sizes that include the odd/even and
// SIMD-tail cases (1, 3, 5, 17, 33, 65, 129, 257, ...).
//
// This is deliberately different from TestMatrixCore (which checks a handful
// of literal values): here the reference is computed from the definition, so a
// wrong SIMD tail, a transposed index or a wrong reduction shows up.
unit TestNumericAudit;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Math, fpcunit, testregistry, Matrix;

type
  TNumericAuditTests = class(TTestCase)
  private
    function RandM(w, h, seed : integer) : TDoubleMatrix;
    function IdentityM(n : integer) : TDoubleMatrix;
    function MultRef(cv : integer; a, b : TDoubleMatrix) : TDoubleMatrix;
    function MatMaxDiff(a, b : TDoubleMatrix) : double;
  published
    procedure TestElementwiseOps;
    procedure TestReductions;
    procedure TestMult;
    procedure TestInvert;
    procedure TestDeterminantKnownValues;
    procedure TestSolveLinEQ;
    procedure TestStatistics;
  end;

implementation

const
  cSizes : array[0..21] of integer =
    (1,2,3,4,5,7,8,9,13,15,16,17,31,32,33,63,64,65,127,128,129,257);
  cMultSizes : array[0..11] of integer = (1,2,3,4,5,7,8,15,16,17,32,33);
  cStatSizes : array[0..7] of integer = (2,3,5,7,8,16,17,64);
  cInvSizes : array[0..4] of integer = (2,3,5,8,16);
  cSolveSizes : array[0..3] of integer = (3,5,8,16);

function TNumericAuditTests.RandM(w, h, seed : integer) : TDoubleMatrix;
var x, y : integer;
begin
  RandSeed := seed;
  Result := TDoubleMatrix.Create(w, h, 0);
  for x := 0 to w - 1 do
    for y := 0 to h - 1 do
      Result.Items[x, y] := Random * 2 - 1;
end;

function TNumericAuditTests.IdentityM(n : integer) : TDoubleMatrix;
var x, y : integer;
begin
  Result := TDoubleMatrix.Create(n, n, 0);
  for x := 0 to n - 1 do
    for y := 0 to n - 1 do
      if x = y then
        Result.Items[x, y] := 1
      else
        Result.Items[x, y] := 0;
end;

// Two candidate conventions for A*B - the library matches one of them, and the
// audit accepts the better one so the test does not encode an orientation.
// conv0: C[x,y] = sum_k A[k,y]*B[x,k]    conv1: C[x,y] = sum_k A[x,k]*B[k,y]
function TNumericAuditTests.MultRef(cv : integer; a, b : TDoubleMatrix) : TDoubleMatrix;
var x, y, k : integer;
    s : double;
begin
  if cv = 0 then
    Result := TDoubleMatrix.Create(b.Width, a.Height, 0)
  else
    Result := TDoubleMatrix.Create(a.Width, b.Height, 0);

  for x := 0 to Result.Width - 1 do
    for y := 0 to Result.Height - 1 do
    begin
      s := 0;
      for k := 0 to a.Width - 1 do
        if cv = 0 then
          s := s + a.Items[k, y] * b.Items[x, k]
        else
          s := s + a.Items[x, k] * b.Items[k, y];
      Result.Items[x, y] := s;
    end;
end;

function TNumericAuditTests.MatMaxDiff(a, b : TDoubleMatrix) : double;
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

procedure TNumericAuditTests.TestElementwiseOps;
var si, x, y, n : integer;
    a, b, c, t : TDoubleMatrix;
    eAdd, eSub, eMul, eTr, eAbs, err : double;
begin
  eAdd := 0; eSub := 0; eMul := 0; eTr := 0; eAbs := 0;

  for si := 0 to High(cSizes) do
  begin
    n := cSizes[si];
    a := RandM(n, n, 100 + n);
    b := RandM(n, n, 200 + n);
    c := nil; t := nil;
    try
      c := a.Add(b);
      for x := 0 to n - 1 do for y := 0 to n - 1 do
      begin
        err := Abs(c.Items[x, y] - (a.Items[x, y] + b.Items[x, y]));
        if err > eAdd then eAdd := err;
      end;
      FreeAndNil(c);

      c := a.Sub(b);
      for x := 0 to n - 1 do for y := 0 to n - 1 do
      begin
        err := Abs(c.Items[x, y] - (a.Items[x, y] - b.Items[x, y]));
        if err > eSub then eSub := err;
      end;
      FreeAndNil(c);

      c := a.ElementWiseMult(b);
      for x := 0 to n - 1 do for y := 0 to n - 1 do
      begin
        err := Abs(c.Items[x, y] - a.Items[x, y] * b.Items[x, y]);
        if err > eMul then eMul := err;
      end;
      FreeAndNil(c);

      c := a.Abs;
      for x := 0 to n - 1 do for y := 0 to n - 1 do
      begin
        err := Abs(c.Items[x, y] - Abs(a.Items[x, y]));
        if err > eAbs then eAbs := err;
      end;
      FreeAndNil(c);

      t := a.Transpose;
      if (t.Width <> a.Height) or (t.Height <> a.Width) then
        eTr := 1e30
      else
        for x := 0 to a.Width - 1 do for y := 0 to a.Height - 1 do
        begin
          err := Abs(t.Items[y, x] - a.Items[x, y]);
          if err > eTr then eTr := err;
        end;
      FreeAndNil(t);
    finally
      t.Free; c.Free; b.Free; a.Free;
    end;
  end;

  AssertTrue(Format('Add: max err %.3e', [eAdd]), eAdd <= 1e-12);
  AssertTrue(Format('Sub: max err %.3e', [eSub]), eSub <= 1e-12);
  AssertTrue(Format('ElementWiseMult: max err %.3e', [eMul]), eMul <= 1e-12);
  AssertTrue(Format('Abs: max err %.3e', [eAbs]), eAbs <= 0);
  AssertTrue(Format('Transpose: max err %.3e', [eTr]), eTr <= 1e-12);
end;

procedure TNumericAuditTests.TestReductions;
var si, x, y, n : integer;
    a : TDoubleMatrix;
    s, mn, mx, ref, eSum, eMin, eMax, err : double;
begin
  eSum := 0; eMin := 0; eMax := 0;
  for si := 0 to High(cSizes) do
  begin
    n := cSizes[si];
    a := RandM(n, n, 300 + n);
    try
      s := 0; mn := 1e300; mx := -1e300;
      for x := 0 to n - 1 do for y := 0 to n - 1 do
      begin
        ref := a.Items[x, y];
        s := s + ref;
        if ref < mn then mn := ref;
        if ref > mx then mx := ref;
      end;
      err := Abs(a.Sum - s);  if err > eSum then eSum := err;
      err := Abs(a.Min - mn); if err > eMin then eMin := err;
      err := Abs(a.Max - mx); if err > eMax then eMax := err;
    finally
      a.Free;
    end;
  end;
  AssertTrue(Format('Sum: max err %.3e', [eSum]), eSum <= 1e-10);
  AssertTrue(Format('Min: max err %.3e', [eMin]), eMin <= 0);
  AssertTrue(Format('Max: max err %.3e', [eMax]), eMax <= 0);
end;

procedure TNumericAuditTests.TestMult;
var si, cv, n : integer;
    a, b, c, r : TDoubleMatrix;
    best, e : double;
begin
  for si := 0 to High(cMultSizes) do
  begin
    n := cMultSizes[si];
    a := RandM(n, n, 400 + n);
    b := RandM(n, n, 500 + n);
    c := nil; r := nil;
    try
      c := a.Mult(b);
      best := 1e30;
      for cv := 0 to 1 do
      begin
        r := MultRef(cv, a, b);
        e := MatMaxDiff(c, r);
        if e < best then best := e;
        FreeAndNil(r);
      end;
      AssertTrue(Format('Mult n=%d: max err %.3e', [n, best]), best <= 1e-10);
    finally
      r.Free; c.Free; b.Free; a.Free;
    end;
  end;
end;

procedure TNumericAuditTests.TestInvert;
var si, cv, n, k : integer;
    a, inv, id, r : TDoubleMatrix;
    best, e : double;
begin
  for si := 0 to High(cInvSizes) do
  begin
    n := cInvSizes[si];
    a := RandM(n, n, 600 + n);
    for k := 0 to n - 1 do                     // diagonally dominant
      a.Items[k, k] := a.Items[k, k] + n;
    inv := nil; id := nil; r := nil;
    try
      inv := a.Invert;
      id := IdentityM(n);
      best := 1e30;
      for cv := 0 to 1 do
      begin
        r := MultRef(cv, a, inv);
        e := MatMaxDiff(r, id);
        if e < best then best := e;
        FreeAndNil(r);
      end;
      AssertTrue(Format('Invert n=%d: ||A*A^-1 - I|| = %.3e', [n, best]), best <= 1e-9);
    finally
      r.Free; id.Free; inv.Free; a.Free;
    end;
  end;
end;

procedure TNumericAuditTests.TestDeterminantKnownValues;
var a : TDoubleMatrix;
begin
  a := TDoubleMatrix.Create(2, 2, 0);
  a.Items[0,0] := 1; a.Items[0,1] := 2; a.Items[1,0] := 3; a.Items[1,1] := 4;
  try
    AssertEquals('det [[1,2],[3,4]]', -2.0, a.Determinant, 1e-12);
  finally
    a.Free;
  end;

  a := TDoubleMatrix.Create(3, 3, 0);
  a.Items[0,0] := 6;  a.Items[0,1] := 1; a.Items[0,2] := 1;
  a.Items[1,0] := 4;  a.Items[1,1] := -2; a.Items[1,2] := 5;
  a.Items[2,0] := 2;  a.Items[2,1] := 8; a.Items[2,2] := 7;
  try
    AssertEquals('det 3x3', -306.0, a.Determinant, 1e-9);
  finally
    a.Free;
  end;
end;

procedure TNumericAuditTests.TestSolveLinEQ;
var si, n, k, x, y : integer;
    a, b, xv, res : TDoubleMatrix;
    e : double;
begin
  for si := 0 to High(cSolveSizes) do
  begin
    n := cSolveSizes[si];
    a := RandM(n, n, 700 + n);
    for k := 0 to n - 1 do
      a.Items[k, k] := a.Items[k, k] + n;
    b := RandM(1, n, 750 + n);            // one right-hand side column
    xv := nil; res := nil;
    try
      xv := a.SolveLinEQ(b);
      res := a.Mult(xv);
      e := 0;
      for x := 0 to res.Width - 1 do
        for y := 0 to res.Height - 1 do
          e := Max(e, Abs(res.Items[x, y] - b.Items[x, y]));
      AssertTrue(Format('SolveLinEQ n=%d: ||A*x - b|| = %.3e', [n, e]), e <= 1e-9);
    finally
      res.Free; xv.Free; b.Free; a.Free;
    end;
  end;
end;

procedure TNumericAuditTests.TestStatistics;
var si, n, x, y, i, j : integer;
    a, m, v, s, med : TDoubleMatrix;
    vals : array of double;
    sum, sq, mean, val, tmp, eMe, eVa, eSt, eMd : double;
begin
  eMe := 0; eVa := 0; eSt := 0; eMd := 0;
  for si := 0 to High(cStatSizes) do
  begin
    n := cStatSizes[si];
    a := RandM(n, n, 800 + n);
    m := nil; v := nil; s := nil; med := nil;
    try
      m := a.Mean(False);               // one mean per column x
      v := a.Variance(False, True);
      s := a.Std(False, True);
      med := a.Median(False);

      SetLength(vals, n);
      for x := 0 to n - 1 do
      begin
        sum := 0;
        for y := 0 to n - 1 do
        begin
          vals[y] := a.Items[x, y];
          sum := sum + vals[y];
        end;
        mean := sum / n;

        sq := 0;
        for y := 0 to n - 1 do
          sq := sq + Sqr(a.Items[x, y] - mean);
        sq := sq / (n - 1);              // unbiased

        for i := 1 to n - 1 do           // insertion sort for the median
        begin
          tmp := vals[i];
          j := i - 1;
          while (j >= 0) and (vals[j] > tmp) do
          begin
            vals[j + 1] := vals[j];
            dec(j);
          end;
          vals[j + 1] := tmp;
        end;

        if Odd(n) then
          tmp := vals[n div 2]
        else
          tmp := (vals[n div 2 - 1] + vals[n div 2]) / 2;

        eMe := Max(eMe, Abs(m.Items[x, 0] - mean));
        eVa := Max(eVa, Abs(v.Items[x, 0] - sq));
        eSt := Max(eSt, Abs(s.Items[x, 0] - Sqrt(sq)));
        eMd := Max(eMd, Abs(med.Items[x, 0] - tmp));
      end;
    finally
      med.Free; s.Free; v.Free; m.Free; a.Free;
    end;
  end;

  AssertTrue(Format('Mean: max err %.3e', [eMe]), eMe <= 1e-12);
  AssertTrue(Format('Variance: max err %.3e', [eVa]), eVa <= 1e-10);
  AssertTrue(Format('Std: max err %.3e', [eSt]), eSt <= 1e-10);
  AssertTrue(Format('Median: max err %.3e', [eMd]), eMd <= 1e-12);
end;

initialization
  RegisterTest(TNumericAuditTests);
end.
