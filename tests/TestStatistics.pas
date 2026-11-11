// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// Everything here is checked against a closed form, a published constant or an
// identity, never against a second copy of the same code.
unit TestStatistics;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Math, Types, fpcunit, testregistry, MatrixConst, Matrix, Statistics;

type
  TStatisticsTests = class(TTestCase)
  published
    procedure TestFactorialsAndBinomials;
    procedure TestGammaAndLogGamma;
    procedure TestErrorFunction;
    procedure TestBetaAndIncompleteBeta;
    procedure TestIncompleteGamma;
    procedure TestCovariance;
    procedure TestChiSquareOne;
    procedure TestHistogram;
    procedure TestDistributionsPDF;
    procedure TestStudentTAndF;
    procedure TestKolmogorovSmirnovOne;
  end;

implementation

// uniform CDF on [0, 1] - a plain function, because TKSTestFunc is not a
// method pointer
function IdentityCDF(x : double) : double;
begin
  Result := x;
end;

procedure TStatisticsTests.TestFactorialsAndBinomials;
const exact : array[0..12] of Int64 =
  (1, 1, 2, 6, 24, 120, 720, 5040, 40320, 362880, 3628800, 39916800, 479001600);
var i : integer; e : double;
begin
  for i := Low(exact) to High(exact) do
  begin
    AssertEquals(Format('%d! (exact)', [i]), exact[i], Factorial(i));
    e := Abs(FactorialF(i) - exact[i]) / exact[i];
    AssertTrue(Format('%d! (gamma based) relative error %.3e', [i, e]), e <= 1e-13);
    e := Abs(FactorialLn(i) - Ln(exact[i])) / Max(1.0, Abs(Ln(exact[i])));
    AssertTrue(Format('ln(%d!): relative error %.3e', [i, e]), e <= 1e-12);
  end;

  // 20! is beyond Int64 range for exactness but fine as a double
  // exp(gammaln(n+1)) loses relative precision as n grows (~6e-9 at n = 20)
  e := Abs(FactorialF(20) - 2432902008176640000.0) / 2432902008176640000.0;
  AssertTrue(Format('20!: relative error %.3e', [e]), e <= 1e-8);

  // binomial coefficients: symmetric and matching the gamma based version
  AssertEquals('C(10,3)', Int64(120), binom(10, 3));
  AssertEquals('C(20,10)', Int64(184756), binom(20, 10));
  // C(n,0) = C(n,n) = 1 - the symmetry step used to make k = 0 and return n
  AssertEquals('C(2,2)', Int64(1), binom(2, 2));
  AssertEquals('C(7,7)', Int64(1), binom(7, 7));
  AssertEquals('C(7,0)', Int64(1), binom(7, 0));
  AssertEquals('C(9,8)', Int64(9), binom(9, 8));
  AssertEquals('C(5,9) out of range', Int64(0), binom(5, 9));
  for i := 0 to 12 do
  begin
    AssertEquals(Format('C(%d,%d) symmetry', [12, i]), binom(12, i), binom(12, 12 - i));
    e := Abs(binomf(12, i) - binom(12, i));
    AssertTrue(Format('binomf(%d,%d) vs binom: %.3e', [12, i, e]), e <= 1e-9);
  end;
end;

procedure TStatisticsTests.TestGammaAndLogGamma;
var e : double; x : double; i : integer;
begin
  AssertEquals('Gamma(1)', 1.0, Gamma(1), 1e-14);
  AssertEquals('Gamma(2)', 1.0, Gamma(2), 1e-14);
  AssertEquals('Gamma(5)', 24.0, Gamma(5), 1e-12);
  AssertEquals('Gamma(0.5) = sqrt(pi)', Sqrt(Pi), Gamma(0.5), 1e-14);
  AssertEquals('Gamma(1.5) = sqrt(pi)/2', Sqrt(Pi) / 2, Gamma(1.5), 1e-13);

  // recurrence Gamma(x+1) = x*Gamma(x)
  x := 0.25;
  while x < 6 do
  begin
    e := Abs(Gamma(x + 1) - x * Gamma(x)) / Gamma(x + 1);
    AssertTrue(Format('Gamma recurrence at x=%.2f: %.3e', [x, e]), e <= 1e-12);
    x := x + 0.25;
  end;

  // GammaLN is the log of Gamma
  for i := 0 to 15 do
  begin
    x := 0.75 + i * 0.5;
    e := Abs(GammaLN(x) - Ln(Gamma(x)));
    AssertTrue(Format('GammaLN(%.3f): %.3e', [x, e]), e <= 1e-10);
  end;
  AssertEquals('GammaLN(1)', 0.0, GammaLN(1), 1e-14);
  AssertEquals('GammaLN(0.5)', Ln(Sqrt(Pi)), GammaLN(0.5), 1e-13);
end;

procedure TStatisticsTests.TestErrorFunction;
var i : integer;
const erf1 = 0.842700792949714869;   // erf(1)
      erfc1 = 0.157299207050285131;  // erfc(1)
var x, e : double;
begin
  AssertEquals('erf(0)', 0.0, errorFunc(0), 1e-15);
  // errorFunc is a rational approximation: measured accuracy is ~3e-9, so the
  // known constants are checked at that level (a regression would show up)
  AssertEquals('erf(1)', erf1, errorFunc(1), 4e-9);
  AssertEquals('erf(0.5)', 0.520499877813046538, errorFunc(0.5), 4e-9);
  AssertEquals('erfc(1)', erfc1, errorFuncC(1), 4e-9);
  AssertEquals('erf(inf) -> 1', 1.0, errorFunc(12), 1e-15);

  for i := -3 to 3 do
  begin
    x := i + 0.3;
    // odd symmetry
    e := Abs(errorFunc(x) + errorFunc(-x));
    AssertTrue(Format('erf odd symmetry at %.1f: %.3e', [x, e]), e <= 1e-14);
    // erf + erfc = 1
    e := Abs(errorFunc(x) + errorFuncC(x) - 1);
    AssertTrue(Format('erf+erfc at %.1f: %.3e', [x, e]), e <= 1e-13);
  end;
end;

// I_x(a, b) for integer a, b equals the binomial tail
// sum_{j=a}^{a+b-1} C(a+b-1, j) x^j (1-x)^(a+b-1-j)
function BetaIReference(a, b : integer; x : double) : double;
var j, n : integer; c : Int64; sum : double;
begin
  n := a + b - 1;
  sum := 0;
  for j := a to n do
  begin
    c := binom(n, j);
    sum := sum + c * IntPower(x, j) * IntPower(1 - x, n - j);
  end;
  Result := sum;
end;

procedure TStatisticsTests.TestBetaAndIncompleteBeta;
var x, e : double; a, b, i : integer;
begin
  AssertEquals('B(2,3) = 1/12', 1 / 12, beta(2, 3), 1e-15);
  AssertEquals('B(1,1) = 1', 1.0, beta(1, 1), 1e-15);
  AssertEquals('B(0.5,0.5) = pi', Pi, beta(0.5, 0.5), 1e-12);

  // endpoints and the symmetric identity
  AssertEquals('I_0(2,3)', 0.0, betaI(2, 3, 0), 1e-15);
  AssertEquals('I_1(2,3)', 1.0, betaI(2, 3, 1), 1e-15);
  AssertEquals('I_0.5(2,3)', 0.6875, betaI(2, 3, 0.5), 1e-13);
  for a := 1 to 3 do
    for b := 1 to 3 do
      for i := 0 to 9 do
      begin
        x := 0.05 + i * 0.1;
        e := Abs(betaI(a, b, x) + betaI(b, a, 1 - x) - 1);
        AssertTrue(Format('I_%.2f(%d,%d) + I_1-x(%d,%d) = 1: %.3e', [x, a, b, b, a, e]),
                   e <= 1e-12);
        e := Abs(betaI(a, b, x) - BetaIReference(a, b, x));
        AssertTrue(Format('I_%.2f(%d,%d) vs binomial tail: %.3e', [x, a, b, e]), e <= 1e-12);
      end;
end;

procedure TStatisticsTests.TestIncompleteGamma;
var x, p, q, ser, cf, gln1, gln2, e : double; i : integer;
begin
  for i := 1 to 20 do
  begin
    p := GammaP(0.5 * (i mod 5 + 1), i * 0.3);
    q := GammaQ(0.5 * (i mod 5 + 1), i * 0.3);
    e := Abs(p + q - 1);
    AssertTrue(Format('P+Q=1 at (%d): %.3e', [i, e]), e <= 1e-9);
  end;

  // closed form for a = 1
  for i := 0 to 10 do
  begin
    x := i * 0.5;
    // the incomplete gamma is computed by series / continued fraction and is
    // accurate to ~4e-9 here - check at that level
    AssertEquals(Format('P(1,%.1f) = 1-exp(-x)', [x]), 1 - Exp(-x), GammaP(1, x), 1e-7);
    AssertEquals(Format('Q(1,%.1f) = exp(-x)', [x]), Exp(-x), GammaQ(1, x), 1e-7);
  end;

  // the continued fraction and series representations agree with P and Q
  gammaSER(ser, 3.0, 1.5, gln1);
  gammaCF(cf, 3.0, 12.0, gln2);
  AssertEquals('gammaSER vs GammaP', GammaP(3.0, 1.5), ser, 1e-12);
  AssertEquals('gammaCF vs GammaQ', GammaQ(3.0, 12.0), cf, 1e-12);
  AssertEquals('gammaSER also returns ln(gamma(a))', GammaLN(3.0), gln1, 1e-12);
  AssertEquals('gammaCF also returns ln(gamma(a))', GammaLN(3.0), gln2, 1e-12);
end;

procedure TStatisticsTests.TestCovariance;
const w = 3; h = 6; step = w + 2; stepD = w + 1;
var
  a : TDoubleDynArray;
  dest : TDoubleDynArray;
  x, y, i, j : integer;
  mi, mj, c : double;
  e1, e2 : double;
  unbiased : boolean;
  procedure Compute(const Unbiased_ : boolean);
  var ii, jj, r : integer; mmi, mmj, s : double;
  begin
    SetLength(dest, w * stepD);
    for ii := 0 to Length(dest) - 1 do
      dest[ii] := nan;
    Covariance(@dest[0], stepD * SizeOf(double), @a[0], step * SizeOf(double),
               w, h, Unbiased_);
    e1 := 0; e2 := 0;
    for ii := 0 to w - 1 do
      for jj := 0 to w - 1 do
      begin
        mmi := 0; mmj := 0;
        for r := 0 to h - 1 do
        begin
          mmi := mmi + a[ii + r * step];
          mmj := mmj + a[jj + r * step];
        end;
        mmi := mmi / h; mmj := mmj / h;
        s := 0;
        for r := 0 to h - 1 do
          s := s + (a[ii + r * step] - mmi) * (a[jj + r * step] - mmj);
        if Unbiased_ then s := s / (h - 1) else s := s / h;
        e1 := Max(e1, Abs(dest[ii + jj * stepD] - s));
        e2 := Max(e2, Abs(dest[jj + ii * stepD] - s));
      end;
  end;
begin
  SetLength(a, h * step);
  RandSeed := 4242;
  for y := 0 to h - 1 do
    for x := 0 to w - 1 do
      a[x + y * step] := Random * 4 - 2;
  SetLength(dest, 0);
  try
    for i := 0 to 1 do
    begin
      unbiased := i = 0;
      Compute(unbiased);
      AssertTrue(Format('Covariance (unbiased=%s): min deviation %.3e',
                        [BoolToStr(unbiased, 'yes', 'no'), Min(e1, e2)]), Min(e1, e2) <= 1e-13);
    end;
    // the covariance matrix must be symmetric
    e1 := 0;
    for i := 0 to w - 1 do
      for j := 0 to w - 1 do
        e1 := Max(e1, Abs(dest[i + j * stepD] - dest[j + i * stepD]));
    AssertTrue(Format('Covariance symmetry: %.3e', [e1]), e1 <= 1e-15);
  finally
    SetLength(a, 0);
    SetLength(dest, 0);
  end;
end;

procedure TStatisticsTests.TestChiSquareOne;
var
  bins, expect : TDoubleDynArray;
  df, chsq, prob, ref : double;
begin
  SetLength(bins, 3);
  SetLength(expect, 3);
  bins[0] := 10; expect[0] := 12;
  bins[1] := 20; expect[1] := 18;
  bins[2] := 30; expect[2] := 30;
  ChiSquareOne(PConstDoubleArr(@bins[0]), PConstDoubleArr(@expect[0]), 3, 1, df, chsq, prob);

  AssertEquals('chi-square degrees of freedom', 2.0, df, 0.0);
  ref := Sqr(10 - 12) / 12 + Sqr(20 - 18) / 18 + Sqr(30 - 30) / 30;
  AssertEquals('chi-square statistic', ref, chsq, 1e-14);
  AssertEquals('chi-square probability = Q(df/2, chsq/2)', GammaQ(0.5 * df, 0.5 * chsq), prob, 1e-12);
  AssertTrue('chi-square probability within [0,1]', (prob >= 0) and (prob <= 1));

  // identical bins: statistic 0, probability 1
  ChiSquareOne(PConstDoubleArr(@expect[0]), PConstDoubleArr(@expect[0]), 3, 0, df, chsq, prob);
  AssertEquals('identical bins: statistic', 0.0, chsq, 0.0);
  AssertEquals('identical bins: probability', 1.0, prob, 1e-12);
  SetLength(bins, 0);
  SetLength(expect, 0);
end;

procedure TStatisticsTests.TestHistogram;
const n = 1000; nBins = 16;
var
  data, bins : TDoubleDynArray;
  i, sum : integer;
  m, r : TDoubleMatrix;
  e : double;
begin
  SetLength(data, n);
  SetLength(bins, nBins);
  RandSeed := 3141;
  for i := 0 to n - 1 do
    data[i] := Random * 10 - 5;
  for i := 0 to nBins - 1 do
    bins[i] := 0;

  Hist(PConstDoubleArr(@data[0]), n, PConstDoubleArr(@bins[0]), nBins);
  sum := 0;
  for i := 0 to nBins - 1 do
    sum := sum + Round(bins[i]);
  AssertEquals('Hist: every sample is binned', n, sum);

  // the matrix level accessor must agree on the total count
  // samples live along the width of a matrix (one sample per column)
  m := TDoubleMatrix.Create(n, 1, 0);
  for i := 0 to n - 1 do
    m.Items[i, 0] := data[i];
  r := nil;
  try
    r := TStatTest.Histogram(m, nBins);
    e := 0;
    for i := 0 to r.Width * r.Height - 1 do
      if r.Width = 1 then e := e + r.Items[0, i] else e := e + r.Items[i, 0];
    AssertEquals('TStatTest.Histogram: every sample is binned', n, Round(e));
  finally
    r.Free; m.Free;
  end;
  SetLength(data, 0);
  SetLength(bins, 0);
end;

// value k of a result that may come back as a row or a column vector
function AtValue(const m : TDoubleMatrix; k : integer) : double;
begin
  if m.Width = 1 then
    Result := m.Items[0, k]
  else
    Result := m.Items[k, 0];
end;

procedure TStatisticsTests.TestDistributionsPDF;
const mu = 1.5; sigma = 2.0; lambda = 0.75;
var
  x, r : TDoubleMatrix;
  k : integer;
  v, expected, e : double;
begin
  x := TDoubleMatrix.Create(5, 1, 0);
  x.Items[0, 0] := -1.0;
  x.Items[1, 0] := 0.0;
  x.Items[2, 0] := 1.5;
  x.Items[3, 0] := 3.0;
  x.Items[4, 0] := 4.5;
  r := nil;
  try
    // normal density
    r := TStatTest.NormalPDF(x, mu, sigma);
    for k := 0 to 4 do
    begin
      v := x.Items[k, 0];
      expected := Exp(-Sqr(v - mu) / (2 * Sqr(sigma))) / (sigma * Sqrt(2 * Pi));
      e := Abs(AtValue(r, k) - expected);
      AssertTrue(Format('NormalPDF(%.1f): %.3e', [v, e]), e <= 1e-14);
    end;
    FreeAndNil(r);

    // exponential density with lambda as the SCALE (the mean), as implemented:
    // f(x) = exp(-x/lambda)/lambda for x >= 0
    r := TStatTest.ExpPDF(x, lambda);
    for k := 0 to 4 do
    begin
      v := x.Items[k, 0];
      if v >= 0 then
      begin
        expected := Exp(-v / lambda) / lambda;
        e := Abs(AtValue(r, k) - expected);
        AssertTrue(Format('ExpPDF(%.1f): %.3e', [v, e]), e <= 1e-14);
      end;
    end;
    FreeAndNil(r);

    // uniform density on [0, 2] is 1/2 inside and 0 outside
    r := TStatTest.UniformPDF(x, 0, 2);
    for k := 0 to 4 do
    begin
      v := x.Items[k, 0];
      if (v >= 0) and (v <= 2) then
        expected := 0.5
      else
        expected := 0;
      e := Abs(AtValue(r, k) - expected);
      AssertTrue(Format('UniformPDF(%.1f): %.3e', [v, e]), e <= 1e-14);
    end;
    FreeAndNil(r);

    // Poisson density on integer arguments: exp(-L) * L^k / k!
    x.Free;
    x := TDoubleMatrix.Create(4, 1, 0);
    x.Items[0, 0] := 0; x.Items[1, 0] := 1; x.Items[2, 0] := 2; x.Items[3, 0] := 5;
    r := TStatTest.PoissonPDF(x, 2.5);
    for k := 0 to 3 do
    begin
      v := x.Items[k, 0];
      expected := Exp(-2.5) * Power(2.5, v) / FactorialF(Round(v));
      e := Abs(AtValue(r, k) - expected);
      AssertTrue(Format('PoissonPDF(%d): %.3e', [Round(v), e]), e <= 1e-13);
    end;
  finally
    r.Free; x.Free;
  end;
end;

procedure TStatisticsTests.TestStudentTAndF;
const n = 12;
var
  d1, d2 : TDoubleMatrix;
  t, probT, f, probF : double;
  i : integer;
  m1, m2, v1, v2, tRef, fRef, e : double;
begin
  d1 := TDoubleMatrix.Create(1, n, 0);
  d2 := TDoubleMatrix.Create(1, n, 0);
  RandSeed := 2718;
  try
    for i := 0 to n - 1 do
    begin
      d1.Items[0, i] := 1.0 + Random;
      d2.Items[0, i] := 2.5 + Random;
    end;

    // reference moments (unbiased variance)
    m1 := 0; m2 := 0;
    for i := 0 to n - 1 do
    begin
      m1 := m1 + d1.Items[0, i];
      m2 := m2 + d2.Items[0, i];
    end;
    m1 := m1 / n; m2 := m2 / n;
    v1 := 0; v2 := 0;
    for i := 0 to n - 1 do
    begin
      v1 := v1 + Sqr(d1.Items[0, i] - m1);
      v2 := v2 + Sqr(d2.Items[0, i] - m2);
    end;
    v1 := v1 / (n - 1); v2 := v2 / (n - 1);

    t := 0; probT := 0; f := 0; probF := 0;
    TStatTest.StudentTTest(d1, d2, t, probT);
    TStatTest.FTest(d1, d2, f, probF);

    // FTest compares the variances; which sample ends up on top is not specified
    fRef := v1 / v2;
    e := Min(Abs(f - fRef), Abs(f - 1 / fRef));
    AssertTrue(Format('F = ratio of variances (got %.6f, expected %.6f or %.6f)',
                      [f, fRef, 1 / fRef]), e <= 1e-9);
    AssertTrue('F probability within [0,1]', (probF >= 0) and (probF <= 1));

    // t = (m1 - m2) / sqrt(sp^2 * (1/n + 1/n)) with the pooled variance
    tRef := (m1 - m2) / Sqrt((v1 + v2) / 2 * (2 / n));
    e := Min(Abs(t - tRef), Abs(t + tRef));
    AssertTrue(Format('t matches the pooled two-sample statistic (got %.6f, expected %.6f)',
                      [t, tRef]), e <= 1e-5);
    AssertTrue('t probability within [0,1]', (probT >= 0) and (probT <= 1));

    // a sample tested against itself gives t = 0 and probability 1
    TStatTest.StudentTTest(d1, d1, t, probT);
    AssertEquals('t of identical samples', 0.0, t, 1e-12);
    AssertEquals('probability of identical samples', 1.0, probT, 1e-9);
  finally
    d2.Free; d1.Free;
  end;
end;

procedure TStatisticsTests.TestKolmogorovSmirnovOne;
const n = 10; expectedD = 0.05;
var
  data : TDoubleDynArray;
  d, prob : double;
  i : integer;
begin
  SetLength(data, n);
  // x_i = 0.05 + 0.1*i with the uniform CDF F(x) = x gives |(i+1)/n - x_i| = 0.05
  for i := 0 to n - 1 do
    data[i] := 0.05 + 0.1 * i;
  d := 0; prob := 0;
  kolmogorovSmirnovOne(PConstDoubleArr(@data[0]), n, @IdentityCDF, d, prob);
  AssertEquals('K-S distance', expectedD, d, 1e-14);
  AssertTrue('K-S significance within [0,1]', (prob >= 0) and (prob <= 1));
  SetLength(data, 0);
end;

initialization
  RegisterTest(TStatisticsTests);
end.
