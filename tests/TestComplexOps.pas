// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// CplxSimpleMatrixOperations: the scalar functions are checked against a hand
// written complex implementation and against algebraic identities, the PComplex
// matrix kernels against naive loops over a deliberately non-tight stride.
// The conventions (CAbs vs CAbs1, magnitude comparison, principal root, the
// non-conjugating dot product, AddAndScale vs ScaleAndAdd) are in README.md.
unit TestComplexOps;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Math, Types, fpcunit, testregistry, MatrixConst, CplxSimpleMatrixOperations;

type
  TComplexOpsTests = class(TTestCase)
  private
    function Cx(re, im : double) : TComplex;
    function RandC(amplitude : double) : TComplex;
    function SameC(const a, b : TComplex; eps : double) : boolean;
    function CMulRef(const a, b : TComplex) : TComplex;
    function CDivRef(const a, b : TComplex) : TComplex;
    function ShowC(const z : TComplex) : string;
  published
    procedure TestScalarArithmetic;
    procedure TestComplexIdentities;
    procedure TestAbsAndConjugate;
    procedure TestCompareAndMinMax;
    procedure TestSquareRoot;
    procedure TestExpAndLog;
    procedure TestTrigonometric;
    procedure TestMatrixKernels;
    procedure TestDotProductWithoutConjugation;
    procedure TestMatrixMultiplyTransposed;
  end;

implementation

function TComplexOpsTests.Cx(re, im : double) : TComplex;
begin
  Result.real := re;
  Result.imag := im;
end;

function TComplexOpsTests.RandC(amplitude : double) : TComplex;
begin
  Result.real := (Random * 2 - 1) * amplitude;
  Result.imag := (Random * 2 - 1) * amplitude;
end;

function TComplexOpsTests.ShowC(const z : TComplex) : string;
begin
  Result := Format('(%.6f, %.6f)', [z.real, z.imag]);
end;

function TComplexOpsTests.SameC(const a, b : TComplex; eps : double) : boolean;
begin
  Result := (Abs(a.real - b.real) <= eps) and (Abs(a.imag - b.imag) <= eps);
end;

function TComplexOpsTests.CMulRef(const a, b : TComplex) : TComplex;
begin
  Result := Cx(a.real * b.real - a.imag * b.imag, a.real * b.imag + a.imag * b.real);
end;

function TComplexOpsTests.CDivRef(const a, b : TComplex) : TComplex;
var den : double;
begin
  den := Sqr(b.real) + Sqr(b.imag);
  Result := Cx((a.real * b.real + a.imag * b.imag) / den,
              (a.imag * b.real - a.real * b.imag) / den);
end;

procedure TComplexOpsTests.TestScalarArithmetic;
var a, b, r, e : TComplex; i : integer;
begin
  RandSeed := 2101;
  for i := 0 to 19 do
  begin
    a := RandC(3);
    b := RandC(3);
    if Abs(b.real) + Abs(b.imag) < 0.2 then
      b := Cx(1.5, 0.75);

    r := CAdd(a, b);
    e := Cx(a.real + b.real, a.imag + b.imag);
    AssertTrue(Format('CAdd% s', [ShowC(a)]), SameC(r, e, 1e-15));

    r := CSub(a, b);
    e := Cx(a.real - b.real, a.imag - b.imag);
    AssertTrue('CSub', SameC(r, e, 1e-15));

    r := CMul(a, b);
    e := CMulRef(a, b);
    AssertTrue('CMul', SameC(r, e, 1e-14));

    r := CDiv(a, b);
    e := CDivRef(a, b);
    AssertTrue(Format('CDiv %s / %s got %s want %s', [ShowC(a), ShowC(b), ShowC(r), ShowC(e)]),
               SameC(r, e, 1e-13));

    r := CInv(a);
    e := CDivRef(Cx(1, 0), a);
    AssertTrue('CInv', SameC(r, e, 1e-13));

    r := RCMul(2.5, a);
    e := Cx(2.5 * a.real, 2.5 * a.imag);
    AssertTrue('RCMul', SameC(r, e, 1e-14));

    r := CAddMul(a, b, a);          // a + b * a
    e := CAdd(a, CMulRef(b, a));
    AssertTrue('CAddMul', SameC(r, e, 1e-14));

    r := CSubMul(a, b, a);          // a - b * a
    e := CSub(a, CMulRef(b, a));
    AssertTrue('CSubMul', SameC(r, e, 1e-14));
  end;
end;

procedure TComplexOpsTests.TestComplexIdentities;
var a, b, r, e : TComplex; i : integer;
begin
  RandSeed := 2202;
  for i := 0 to 19 do
  begin
    a := RandC(4);
    b := RandC(4);
    if Abs(a.real) + Abs(a.imag) < 0.2 then
      a := Cx(2, 1);

    // z - z = 0
    AssertTrue('z - z = 0', SameC(CSub(a, a), Cx(0, 0), 0));
    // z / z = 1
    AssertTrue('z / z = 1', SameC(CDiv(a, a), Cx(1, 0), 1e-14));
    // z * z^-1 = 1
    AssertTrue('z * z^-1 = 1', SameC(CMul(a, CInv(a)), Cx(1, 0), 1e-13));
    // conj(conj z) = z
    AssertTrue('conj(conj z) = z', SameC(CConj(CConj(a)), a, 0));
    // |z1 z2| = |z1| |z2|
    r := CMul(a, b);
    AssertEquals('|z1 z2| = |z1||z2|', CAbs(a) * CAbs(b), CAbs(r), 1e-12);
    // z * conj(z) = |z|^2 (purely real)
    e := CMul(a, CConj(a));
    AssertEquals('z*conj(z) is real', 0.0, e.imag, 1e-14);
    AssertEquals('z*conj(z) = |z|^2', Sqr(CAbs(a)), e.real, 1e-12);
  end;
end;

procedure TComplexOpsTests.TestAbsAndConjugate;
var a : TComplex; i : integer; zc : TComplex;
begin
  RandSeed := 2303;
  for i := 0 to 19 do
  begin
    a := RandC(5);
    AssertEquals('CAbs', Sqrt(Sqr(a.real) + Sqr(a.imag)), CAbs(a), 1e-14);
    AssertEquals('CAbs1 is the L1 norm', Abs(a.real) + Abs(a.imag), CAbs1(a), 1e-14);

    zc := CConj(a);
    AssertEquals('conj real', a.real, zc.real, 0);
    AssertEquals('conj imag', -a.imag, zc.imag, 0);
  end;
end;

procedure TComplexOpsTests.TestCompareAndMinMax;
var small, big : TComplex; rel : TValueRelationship;
begin
  small := Cx(1, 0);      // |z| = 1
  big := Cx(0, 3);        // |z| = 3

  rel := CCmp(small, big);
  AssertEquals('CCmp smaller', Ord(LessThanValue), Ord(rel));
  rel := CCmp(big, small);
  AssertEquals('CCmp larger', Ord(GreaterThanValue), Ord(rel));
  rel := CCmp(big, big);
  AssertEquals('CCmp equal', Ord(EqualsValue), Ord(rel));

  // the epsilon makes near-equal magnitudes compare as equal
  rel := CCmp(Cx(1, 0), Cx(1.0000001, 0), 1e-3);
  AssertEquals('CCmp within eps', Ord(EqualsValue), Ord(rel));

  AssertTrue('CMax picks the larger magnitude', SameC(CMax(small, big), big, 0));
  AssertTrue('CMin picks the smaller magnitude', SameC(CMin(small, big), small, 0));
  AssertTrue('CMax is symmetric', SameC(CMax(big, small), big, 0));
  AssertTrue('CMin is symmetric', SameC(CMin(big, small), small, 0));
end;

procedure TComplexOpsTests.TestSquareRoot;
var a, s : TComplex; i : integer;
begin
  // principal roots of known values
  s := CSqrt(Cx(-1, 0));
  AssertTrue('sqrt(-1) = i', SameC(s, Cx(0, 1), 1e-15));
  s := CSqrt(Cx(4, 0));
  AssertTrue('sqrt(4) = 2', SameC(s, Cx(2, 0), 1e-15));
  s := CSqrt(Cx(0, -1));
  AssertTrue('sqrt(-i) has negative imaginary part', s.imag < 0);

  // sqrt(z)^2 = z
  RandSeed := 2404;
  for i := 0 to 19 do
  begin
    a := RandC(4);
    s := CSqrt(a);
    AssertTrue(Format('sqrt(z)^2 = z for %s', [ShowC(a)]),
               SameC(CMul(s, s), a, 1e-12));
  end;
end;

procedure TComplexOpsTests.TestExpAndLog;
var a, r : TComplex; i : integer;
begin
  AssertTrue('exp(0) = 1', SameC(CExp(Cx(0, 0)), Cx(1, 0), 1e-15));
  AssertTrue('ln(1) = 0', SameC(CLn(Cx(1, 0)), Cx(0, 0), 1e-15));

  // Euler: exp(i*pi) = -1
  r := CExp(Cx(0, Pi));
  AssertTrue(Format('exp(i*pi) = -1, got %s', [ShowC(r)]), SameC(r, Cx(-1, 0), 1e-14));

  // ln is the inverse of exp on the principal branch (|Im z| < pi)
  RandSeed := 2505;
  for i := 0 to 19 do
  begin
    a := Cx((Random * 2 - 1) * 2, (Random * 2 - 1) * 3);
    r := CLn(CExp(a));
    AssertTrue(Format('ln(exp(z)) = z for %s, got %s', [ShowC(a), ShowC(r)]),
               SameC(r, a, 1e-12));
  end;
end;

procedure TComplexOpsTests.TestTrigonometric;
var a, s, c, t : TComplex; i : integer;
begin
  AssertTrue('sin(0) = 0', SameC(CSin(Cx(0, 0)), Cx(0, 0), 1e-15));
  AssertTrue('cos(0) = 1', SameC(CCos(Cx(0, 0)), Cx(1, 0), 1e-15));
  AssertTrue('tan(0) = 0', SameC(CTan(Cx(0, 0)), Cx(0, 0), 1e-15));

  RandSeed := 2606;
  for i := 0 to 19 do
  begin
    a := Cx((Random * 2 - 1) * 2, (Random * 2 - 1) * 1.5);
    s := CSin(a);
    c := CCos(a);
    // sin^2 + cos^2 = 1
    AssertTrue(Format('sin^2 + cos^2 = 1 for %s', [ShowC(a)]),
               SameC(CAdd(CMul(s, s), CMul(c, c)), Cx(1, 0), 1e-12));
    // tan = sin / cos
    t := CTan(a);
    AssertTrue(Format('tan = sin/cos for %s', [ShowC(a)]),
               SameC(t, CDiv(s, c), 1e-12));
  end;
end;

// All matrix kernels are exercised with a deliberately non-tight stride, so the
// line width handling is covered as well as the arithmetic.
procedure TComplexOpsTests.TestMatrixKernels;
const w = 3; h = 2; step = w + 1;
var
  a, b, d : array[0..23] of TComplex;
  lw : NativeInt;
  x, y, k : integer;
  e : double;
  want : TComplex;
  offset, scale : TComplex;
begin
  RandSeed := 2707;
  lw := step * SizeOf(TComplex);
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
    begin
      a[x + y * step] := RandC(2);
      b[x + y * step] := RandC(2);
      d[x + y * step] := Cx(-99, -99);
    end;

  // init
  CplxGenericMtxInit(@d[0], lw, w, h, Cx(7, -3));
  e := 0;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
      e := Max(e, Abs(d[x + y * step].real - 7) + Abs(d[x + y * step].imag + 3));
  AssertEquals('CplxGenericMtxInit', 0.0, e, 0.0);

  // copy
  CplxGenericMtxCopy(@d[0], lw, @a[0], lw, w, h);
  e := 0;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
      e := Max(e, Abs(d[x + y * step].real - a[x + y * step].real) +
                     Abs(d[x + y * step].imag - a[x + y * step].imag));
  AssertEquals('CplxGenericMtxCopy', 0.0, e, 0.0);

  // add / sub
  CplxGenericMtxAdd(@d[0], lw, @a[0], @b[0], w, h, lw, lw);
  e := 0;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
    begin
      want := CAdd(a[x + y * step], b[x + y * step]);
      e := Max(e, Abs(d[x + y * step].real - want.real) + Abs(d[x + y * step].imag - want.imag));
    end;
  AssertTrue(Format('CplxGenericMtxAdd: %.3e', [e]), e <= 1e-14);

  CplxGenericMtxSub(@d[0], lw, @a[0], @b[0], w, h, lw, lw);
  e := 0;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
    begin
      want := CSub(a[x + y * step], b[x + y * step]);
      e := Max(e, Abs(d[x + y * step].real - want.real) + Abs(d[x + y * step].imag - want.imag));
    end;
  AssertTrue(Format('CplxGenericMtxSub: %.3e', [e]), e <= 1e-14);

  // element-wise offset and the two scale formulas
  offset := Cx(1, -2);
  scale  := Cx(0.5, 0.25);

  CplxGenericMtxCopy(@d[0], lw, @a[0], lw, w, h);
  CplxGenericMtxElemAdd(@d[0], lw, w, h, offset);
  e := 0;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
    begin
      want := CAdd(a[x + y * step], offset);
      e := Max(e, Abs(d[x + y * step].real - want.real) + Abs(d[x + y * step].imag - want.imag));
    end;
  AssertTrue(Format('CplxGenericMtxElemAdd: %.3e', [e]), e <= 1e-14);

  CplxGenericMtxCopy(@d[0], lw, @a[0], lw, w, h);
  CplxGenericMtxAddAndScale(@d[0], lw, w, h, offset, scale);
  e := 0;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
    begin
      want := CMul(CAdd(a[x + y * step], offset), scale);
      e := Max(e, Abs(d[x + y * step].real - want.real) + Abs(d[x + y * step].imag - want.imag));
    end;
  AssertTrue(Format('CplxGenericMtxAddAndScale = (z+offset)*scale: %.3e', [e]), e <= 1e-14);

  CplxGenericMtxCopy(@d[0], lw, @a[0], lw, w, h);
  CplxGenericMtxScaleAndAdd(@d[0], lw, w, h, offset, scale);
  e := 0;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
    begin
      want := CAdd(CMul(a[x + y * step], scale), offset);
      e := Max(e, Abs(d[x + y * step].real - want.real) + Abs(d[x + y * step].imag - want.imag));
    end;
  AssertTrue(Format('CplxGenericMtxScaleAndAdd = z*scale + offset: %.3e', [e]), e <= 1e-14);

  // row and column swaps
  CplxGenericMtxCopy(@d[0], lw, @a[0], lw, w, h);
  CplxGenericRowSwap(@d[0], @d[step], w);
  e := 0;
  for x := 0 to w - 1 do
  begin
    e := Max(e, Abs(d[x].real - a[x + step].real) + Abs(d[x].imag - a[x + step].imag));
    e := Max(e, Abs(d[x + step].real - a[x].real) + Abs(d[x + step].imag - a[x].imag));
  end;
  AssertEquals('CplxGenericRowSwap', 0.0, e, 0.0);

  CplxGenericMtxCopy(@d[0], lw, @a[0], lw, w, h);
  CplxGenericColSwap(@d[0], @d[1], lw, h);
  e := 0;
  for y := 0 to h - 1 do
  begin
    e := Max(e, Abs(d[y * step].real - a[1 + y * step].real) + Abs(d[y * step].imag - a[1 + y * step].imag));
    e := Max(e, Abs(d[1 + y * step].real - a[y * step].real) + Abs(d[1 + y * step].imag - a[y * step].imag));
  end;
  AssertEquals('CplxGenericColSwap', 0.0, e, 0.0);
end;

// The complex dot product is the plain bilinear form (no conjugation).
procedure TComplexOpsTests.TestDotProductWithoutConjugation;
const n = 6;
var
  xs, ys : array[0..n - 1] of TComplex;
  got, want : TComplex;
  i : integer;
begin
  RandSeed := 2808;
  for i := 0 to n - 1 do
  begin
    xs[i] := RandC(2);
    ys[i] := RandC(2);
  end;

  got := CplGenericVecDotMult(@xs[0], SizeOf(TComplex), @ys[0], SizeOf(TComplex), n);

  want := Cx(0, 0);
  for i := 0 to n - 1 do
    want := CAdd(want, CMulRef(xs[i], ys[i]));

  AssertTrue(Format('dot product %s vs %s', [ShowC(got), ShowC(want)]),
             SameC(got, want, 1e-13));

  // conj(x) . y is the hermitian form; it must be a different number here
  want := Cx(0, 0);
  for i := 0 to n - 1 do
    want := CAdd(want, CMulRef(CConj(xs[i]), ys[i]));
  AssertFalse('the dot product appears to conjugate (hermitian form)',
              SameC(got, want, 1e-13));
end;


// CplxGenericMtxMultTransp computes A * B^T: unlike the plain multiply the two
// operands must have the same width, and the destination is height1 x height2.
procedure TComplexOpsTests.TestMatrixMultiplyTransposed;
const w = 3; h1 = 2; h2 = 4; step = w + 1;
var
  a, b, d : array[0..63] of TComplex;
  lw : NativeInt;
  x, y, k : integer;
  want : TComplex;
  e : double;
begin
  RandSeed := 6202;
  lw := step * SizeOf(TComplex);
  for y := 0 to h1 - 1 do
    for x := 0 to w - 1 do
      a[x + y * step] := RandC(2);
  for y := 0 to h2 - 1 do
    for x := 0 to w - 1 do
      b[x + y * step] := RandC(2);
  for k := 0 to 63 do
    d[k] := Cx(-99, -99);

  CplxGenericMtxMultTransp(@d[0], step * SizeOf(TComplex), @a[0], @b[0],
                           w, h1, w, h2, lw, lw);

  e := 0;
  for y := 0 to h1 - 1 do
    for x := 0 to h2 - 1 do
    begin
      want := Cx(0, 0);
      for k := 0 to w - 1 do
        want := CAdd(want, CMulRef(a[k + y * step], b[k + x * step]));
      e := Max(e, Abs(d[x + y * step].real - want.real) + Abs(d[x + y * step].imag - want.imag));
    end;
  AssertTrue(Format('CplxGenericMtxMultTransp = A*B^T: max err %.3e', [e]), e <= 1e-13);
end;

initialization
  RegisterTest(TComplexOpsTests);
end.
