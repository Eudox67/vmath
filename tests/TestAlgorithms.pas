// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// The algorithm classes, each on data with a KNOWN answer instead of a random
// fixture: IncrementalPCA against batch PCA on identical data, SSA on a pure
// sine (rank 2, so two components reproduce it and one does not), RBSplines
// through its knots, PLS on an exact linear response, and the wavelet
// coefficient pyramid of a DWT.
unit TestAlgorithms;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Math, Types, fpcunit, testregistry, MatrixConst, Matrix,
  PCA, IncrementalPCA, SSA, RBSplines, PLS, Wavelets, CCA, KernelPCA, ICA;

type
  TAlgorithmTests = class(TTestCase)
  private
    function EigenAt(m : TDoubleMatrix; i : integer) : double;
  published
    procedure TestIncrementalPcaMatchesBatchPca;
    procedure TestSsaReconstructsSine;
    procedure TestSplineInterpolatesKnots;
    procedure TestPlsTracksResponse;
    procedure TestWaveletCoefficientPyramid;
    procedure TestCcaRecoversCorrelatedViews;
    procedure TestKernelPcaContract;
    procedure TestIcaSeparatesSources;
  end;

implementation

// eigenvalues come back as a 1 x n row vector
function TAlgorithmTests.EigenAt(m : TDoubleMatrix; i : integer) : double;
begin
  if m.Width = 1 then
    Result := m.Items[0, i]
  else
    Result := m.Items[i, 0];
end;

// The incremental algorithm must agree with the batch one when both are given
// exactly the same data.
procedure TAlgorithmTests.TestIncrementalPcaMatchesBatchPca;
const nSamples = 40; nFeat = 3; nModes = 2;
var
  data : TDoubleMatrix;
  batch : TMatrixPCA;
  incr : TIncrementalPCA;
  i, j : integer;
  e : double;
begin
  RandSeed := 4101;
  data := TDoubleMatrix.Create(nSamples, nFeat, 0);
  batch := TMatrixPCA.Create([pcaEigVals]);
  incr := TIncrementalPCA.Create([pcaEigVals]);
  try
    // a rank-2 cloud with a little noise on the dependent directions
    for j := 0 to nSamples - 1 do
    begin
      data.Items[j, 0] := Random * 2 - 1;
      data.Items[j, 1] := 2 * data.Items[j, 0] + 0.01 * Random;
      data.Items[j, 2] := -data.Items[j, 0] + 0.01 * Random;
    end;

    AssertTrue('batch PCA failed', batch.PCA(data, nModes, False));
    AssertTrue('incremental PCA failed', incr.PCA(data, nModes, False));
    AssertEquals('number of modes', batch.NumModes, incr.NumModes);
    AssertTrue(Format('batch PCA kept %d modes, expected at least %d',
                      [batch.NumModes, nModes]), batch.NumModes >= nModes);

    e := 0;
    for i := 0 to batch.NumModes - 1 do
      e := Max(e, Abs(EigenAt(batch.EigVals, i) - EigenAt(incr.EigVals, i)));
    AssertTrue(Format('incremental eigenvalues differ from batch by %.3e', [e]), e <= 1e-10);

    // and the eigenvalues are ordered and non-negative
    for i := 1 to batch.NumModes - 1 do
      AssertTrue('eigenvalues are not in descending order',
                 EigenAt(batch.EigVals, i - 1) >= EigenAt(batch.EigVals, i) - 1e-12);
    AssertTrue('a leading eigenvalue is negative', EigenAt(batch.EigVals, 0) > 0);
  finally
    incr.Free; batch.Free; data.Free;
  end;
end;

// A pure sinusoid has a rank-2 trajectory matrix, so SSA with two components
// must reconstruct it and one component must fail.
procedure TAlgorithmTests.TestSsaReconstructsSine;
const n = 64; L = 20;
var
  ssa : TSingularSpectrumAnalysis;
  vals : TDoubleDynArray;
  rec : IMatrix;
  i : integer;
  e2, e1 : double;
  function ReconstructError(const r : IMatrix) : double;
  var k : integer; d : double;
  begin
    d := 0;
    for k := 0 to n - 1 do
      if r.Width = 1 then
        d := Max(d, Abs(r.Items[0, k] - vals[k]))
      else
        d := Max(d, Abs(r.Items[k, 0] - vals[k]));
    Result := d;
  end;
begin
  SetLength(vals, n);
  for i := 0 to n - 1 do
    vals[i] := Sin(2 * Pi * i / 16);

  ssa := TSingularSpectrumAnalysis.Create;
  try
    ssa.CalcSSA(vals, L);

    rec := ssa.Reconstruct(2);
    AssertTrue('Reconstruct returned nothing', rec <> nil);
    AssertEquals('reconstruction length', Int64(n), Int64(rec.Width * rec.Height));
    e2 := ReconstructError(rec);
    AssertTrue(Format('two components should reconstruct a sine exactly, error %.3e', [e2]),
               e2 <= 1e-9);

    rec := ssa.Reconstruct(1);
    e1 := ReconstructError(rec);
    AssertTrue(Format('one component should not reconstruct a sine (error %.3e vs %.3e)', [e1, e2]),
               e1 > 1e-3);
  finally
    ssa.Free;
  end;
end;

// An interpolating spline must reproduce the data at the knots.
procedure TAlgorithmTests.TestSplineInterpolatesKnots;
const n = 10;
var
  spline : TRobustBSpline;
  xv, yv, breaks, res : TDoubleDynArray;
  i : integer;
  e : double;
begin
  SetLength(xv, n);
  SetLength(yv, n);
  for i := 0 to n - 1 do
  begin
    xv[i] := i;
    yv[i] := Sqr(i) - 3 * i + 1;      // any smooth function
  end;

  // the break list must span the data range: three interior knots plus the ends
  SetLength(breaks, 4);
  breaks[0] := 0;
  breaks[1] := 3;
  breaks[2] := 6;
  breaks[3] := 9;

  spline := TRobustBSpline.Create;
  try
    spline.InitSpline(xv, yv, breaks);
    res := spline.EvalSpline(xv);
    AssertEquals('evaluation length', n, Length(res));
    e := 0;
    for i := 0 to n - 1 do
      e := Max(e, Abs(res[i] - yv[i]));
    AssertTrue(Format('the spline does not interpolate its knots (max err %.3e)', [e]), e <= 1e-8);
  finally
    spline.Free;
  end;
end;

// PLS must track a response that is an exact linear function of the predictors.
procedure TAlgorithmTests.TestPlsTracksResponse;
const nSamples = 20; nFeat = 3;
var
  x, y, proj : TDoubleMatrix;
  pls : TMatrixPLS;
  i, j : integer;
  mx, my, sxy, sxx, syy, corr : double;
begin
  RandSeed := 4202;
  x := TDoubleMatrix.Create(nFeat, nSamples, 0);
  y := TDoubleMatrix.Create(1, nSamples, 0);
  pls := TMatrixPLS.Create;
  try
    for j := 0 to nSamples - 1 do
    begin
      for i := 0 to nFeat - 1 do
        x.Items[i, j] := Random * 2 - 1;
      y.Items[0, j] := 2 * x.Items[0, j] - 3 * x.Items[1, j] + 0.5 * x.Items[2, j];
    end;

    AssertTrue('PLSRegress failed', pls.PLSRegress(x, y, 2));
    proj := pls.Project(x);
    AssertTrue('Project returned nothing', proj <> nil);
    AssertEquals('projection length', nSamples, proj.Width * proj.Height);

    // correlation between the projection and the response
    mx := 0; my := 0;
    for j := 0 to nSamples - 1 do
    begin
      if proj.Width = 1 then mx := mx + proj.Items[0, j] else mx := mx + proj.Items[j, 0];
      my := my + y.Items[0, j];
    end;
    mx := mx / nSamples; my := my / nSamples;
    sxy := 0; sxx := 0; syy := 0;
    for j := 0 to nSamples - 1 do
    begin
      if proj.Width = 1 then
        sxy := sxy + (proj.Items[0, j] - mx) * (y.Items[0, j] - my)
      else
        sxy := sxy + (proj.Items[j, 0] - mx) * (y.Items[0, j] - my);
      if proj.Width = 1 then sxx := sxx + Sqr(proj.Items[0, j] - mx)
      else sxx := sxx + Sqr(proj.Items[j, 0] - mx);
      syy := syy + Sqr(y.Items[0, j] - my);
    end;
    corr := Abs(sxy) / Sqrt(sxx * syy);
    AssertTrue(Format('the PLS projection tracks the response poorly (corr %.6f)', [corr]),
               corr >= 0.99);
    proj.Free;
  finally
    pls.Free; y.Free; x.Free;
  end;
end;

// The coefficient pyramid of a 4 level DWT over 64 samples has a fixed shape.
procedure TAlgorithmTests.TestWaveletCoefficientPyramid;
const n = 64;
var
  wav : TWavelet;
  vals, arr : TDoubleDynArray;
  i, level : integer;
  expected : integer;
  eIn, eOut : double;
begin
  RandSeed := 4303;
  SetLength(vals, n);
  for i := 0 to n - 1 do
    vals[i] := Random * 2 - 1;

  wav := TWavelet.Create(wtDaubechies2);
  try
    wav.DWT(vals, 4);
    AssertEquals('max level', 4, wav.MaxLevel);

    expected := n div 2;
    for level := 0 to wav.MaxLevel - 1 do
    begin
      AssertEquals(Format('detail level %d length', [level]),
                   Int64(expected), Int64(Length(wav.getDetailC(level))));
      AssertEquals(Format('approximation level %d length', [level]),
                   Int64(expected), Int64(Length(wav.getApproximationC(level))));
      expected := expected div 2;
    end;

    // the transform must preserve energy (orthonormal Daubechies)
    eIn := 0;
    for i := 0 to n - 1 do
      eIn := eIn + Sqr(vals[i]);
    eOut := 0;
    for level := 0 to wav.MaxLevel - 1 do
    begin
      arr := wav.getDetailC(level);
      for i := 0 to High(arr) do
        eOut := eOut + Sqr(arr[i]);
    end;
    arr := wav.getApproximationC(wav.MaxLevel);
    for i := 0 to High(arr) do
      eOut := eOut + Sqr(arr[i]);
    AssertEquals(Format('energy is preserved (in %.9f out %.9f)', [eIn, eOut]), eIn, eOut, 1e-9);
  finally
    wav.Free;
  end;

  // a constant signal has no high frequency content: every detail coefficient
  // must be zero for a wavelet with a vanishing moment
  for i := 0 to n - 1 do
    vals[i] := 5.0;
  wav := TWavelet.Create(wtDaubechies2);
  try
    wav.DWT(vals, 4);
    eOut := 0;
    for level := 0 to wav.MaxLevel - 1 do
    begin
      arr := wav.getDetailC(level);
      for i := 0 to High(arr) do
        eOut := Max(eOut, Abs(arr[i]));
    end;
    AssertTrue(Format('a constant signal produced detail coefficients up to %.3e', [eOut]),
               eOut <= 1e-10);
  finally
    wav.Free;
  end;
end;

// CCA with samples along the width (the library convention): two views that are
// affine functions of each other must have a canonical correlation of 1, and two
// unrelated views must not.
procedure TAlgorithmTests.TestCcaRecoversCorrelatedViews;
const nSamples = 20; nFeat = 3;
var
  x, y : TDoubleMatrix;
  cc : TMatrixCCA;
  i, j : integer;
  related, unrelated : double;
  procedure Build(const isRelated : boolean);
  var k, f : integer;
  begin
    x := TDoubleMatrix.Create(nSamples, nFeat, 0);
    y := TDoubleMatrix.Create(nSamples, nFeat, 0);
    for k := 0 to nSamples - 1 do
      for f := 0 to nFeat - 1 do
      begin
        x.Items[k, f] := Random * 2 - 1;
        if isRelated then
          y.Items[k, f] := 2 * x.Items[k, f] + 1
        else
          y.Items[k, f] := Random * 2 - 1;
      end;
  end;
begin
  RandSeed := 5101;
  cc := TMatrixCCA.Create;
  try
    Build(True);
    cc.CCA(x, y);
    AssertEquals('WxT holds one vector per feature', Int64(nFeat * nFeat), Int64(cc.WxT.Width * cc.WxT.Height));
    AssertEquals('WyT holds one vector per feature', Int64(nFeat * nFeat), Int64(cc.WyT.Width * cc.WyT.Height));
    AssertEquals('one canonical correlation per feature pair', Int64(nFeat), Int64(cc.R.Width * cc.R.Height));
    related := cc.R.Items[0, 0];
    AssertTrue(Format('related views should correlate at 1.0, got %.6f', [related]), related >= 0.99);
    for j := 0 to nFeat - 1 do
      AssertTrue(Format('canonical correlation %d above 1', [j]),
                 (cc.R.Items[0, j] <= 1 + 1e-9) and (cc.R.Items[0, j] >= 0));
    x.Free; y.Free;

    Build(False);
    cc.CCA(x, y);
    unrelated := cc.R.Items[0, 0];
    AssertTrue(Format('unrelated views should not correlate near 1.0, got %.6f', [unrelated]),
               unrelated < 0.9);
    x.Free; y.Free;
  finally
    cc.Free;
  end;
end;

// TKernelPCA: the driver fills a caller supplied projection matrix with
// (number of modes) x (number of samples), and different kernels give different
// results.  (A numerical equivalence test against classical PCA is not possible
// because the class does not expose its eigenvalues.)
procedure TAlgorithmTests.TestKernelPcaContract;
const nSamples = 24; nFeat = 2;
var
  data, proj1, proj2, proj3 : TDoubleMatrix;
  kp : TKernelPCA;
  props : TKernelPCAProps;
  i, j : integer;
  sum1, diff : double;
begin
  RandSeed := 5202;
  data := TDoubleMatrix.Create(nSamples, nFeat, 0);
  for i := 0 to nSamples - 1 do
  begin
    data.Items[i, 0] := Sin(2 * Pi * i / nSamples);
    data.Items[i, 1] := Cos(2 * Pi * i / nSamples) * 0.5;
  end;

  kp := TKernelPCA.Create;
  proj1 := TDoubleMatrix.Create(2, nSamples, 0);
  proj2 := TDoubleMatrix.Create(2, nSamples, 0);
  proj3 := TDoubleMatrix.Create(1, nSamples, 0);
  try
    props := Default(TKernelPCAProps);
    props.mapping := kmGauss;
    props.sigma := 0.5;
    props.doPseudoCenter := True;
    kp.SetProperties(props);
    AssertTrue('KernelPCA (gauss, sigma 0.5) failed', kp.KernelPCA(data, 2, False, proj1));
    // the projection comes back transposed with respect to the input: the modes
    // run along the width and the samples along the height
    AssertEquals('projection holds one row per mode', Int64(2), Int64(proj1.Width));
    AssertEquals('projection holds one column per sample', Int64(nSamples), Int64(proj1.Height));

    sum1 := 0;
    for i := 0 to proj1.Width - 1 do
      for j := 0 to proj1.Height - 1 do
        sum1 := sum1 + Abs(proj1.Items[i, j]);
    AssertTrue('the projection is all zeros', sum1 > 1e-6);

    props.sigma := 5.0;
    kp.SetProperties(props);
    AssertTrue('KernelPCA (gauss, sigma 5) failed', kp.KernelPCA(data, 2, False, proj2));
    diff := 0;
    for i := 0 to proj1.Width - 1 do
      for j := 0 to proj1.Height - 1 do
        diff := Max(diff, Abs(proj1.Items[i, j] - proj2.Items[i, j]));
    AssertTrue(Format('the kernel width has no effect (max diff %.3e)', [diff]), diff > 1e-3);

    // the requested mode count is honoured
    props.sigma := 0.5;
    kp.SetProperties(props);
    AssertTrue('KernelPCA with one mode failed', kp.KernelPCA(data, 1, False, proj3));
    AssertEquals('one mode requested, projection width', Int64(1), Int64(proj3.Width));
  finally
    proj3.Free; proj2.Free; proj1.Free; kp.Free; data.Free;
  end;
end;


// ICA on a mixture of two independent sources (a sine and a square wave).  The
// recovered components must each track one source and the pair must be a
// permutation of the sources - that is what "independent component analysis"
// promises, and it collapses to nonsense as soon as the whitening is fed the
// wrong number of principal components.
procedure TAlgorithmTests.TestIcaSeparatesSources;
const nSamples = 64; nFeat = 2;
var
  src, mixed, rec : TDoubleMatrix;
  ica : TMatrixICA;
  props : TICAProps;
  W, ic : IMatrix;
  i, k, bestOf : integer;
  e : double;
  r, bestR : double;
  matched : array[0..1] of integer;
  function Corr(a : IMatrix; component : integer; b : TDoubleMatrix; source : integer) : double;
  var ii : integer; ma, mb, sab, saa, sbb : double;
  begin
    ma := 0; mb := 0;
    for ii := 0 to nSamples - 1 do
    begin
      ma := ma + a[ii, component];
      mb := mb + b.Items[ii, source];
    end;
    ma := ma / nSamples; mb := mb / nSamples;
    sab := 0; saa := 0; sbb := 0;
    for ii := 0 to nSamples - 1 do
    begin
      sab := sab + (a[ii, component] - ma) * (b.Items[ii, source] - mb);
      saa := saa + Sqr(a[ii, component] - ma);
      sbb := sbb + Sqr(b.Items[ii, source] - mb);
    end;
    if (saa < 1e-30) or (sbb < 1e-30) then
      Result := 0
    else
      Result := Abs(sab) / Sqrt(saa * sbb);
  end;
begin
  // samples along the width, features (sources) along the height
  src := TDoubleMatrix.Create(nSamples, nFeat, 0);
  mixed := TDoubleMatrix.Create(nSamples, nFeat, 0);
  ica := TMatrixICA.Create;
  rec := nil;
  try
    for i := 0 to nSamples - 1 do
    begin
      src.Items[i, 0] := Sin(2 * Pi * i / 16);
      if Sin(2 * Pi * i / 32) >= 0 then
        src.Items[i, 1] := 1
      else
        src.Items[i, 1] := -1;
    end;
    // a fixed, non-degenerate mixing
    for i := 0 to nSamples - 1 do
    begin
      mixed.Items[i, 0] := src.Items[i, 0] + 0.6 * src.Items[i, 1];
      mixed.Items[i, 1] := 0.4 * src.Items[i, 0] + src.Items[i, 1];
    end;

    props := TMatrixICA.DefProps;
    props.NumIC := nFeat;
    ica.ICA(mixed, props);

    W := ica.W;
    AssertTrue('no unmixing matrix', W <> nil);
    AssertEquals('W maps NumIC components of nFeat features',
                 Int64(nFeat * nFeat), Int64(W.Width * W.Height));

    ic := ica.ProjectToFeatureSpace(mixed);
    AssertTrue('no independent components', ic <> nil);
    AssertEquals('one column per sample', Int64(nSamples), Int64(ic.Width));
    AssertEquals('one component per source', Int64(nFeat), Int64(ic.Height));

    // every component tracks some source, and the two components track different
    // ones (a permutation and a scale - the two freedoms ICA cannot resolve)
    for k := 0 to nFeat - 1 do
    begin
      bestOf := -1;
      bestR := -1;
      for i := 0 to nFeat - 1 do
      begin
        r := Corr(ic, k, src, i);
        if r > bestR then
        begin
          bestR := r;
          bestOf := i;
        end;
      end;
      AssertTrue(Format('component %d does not track any source (best |corr| %.4f)', [k, bestR]),
                 bestR >= 0.99);
      matched[k] := bestOf;
    end;
    AssertTrue(Format('both components track the same source (%d, %d)', [matched[0], matched[1]]),
               matched[0] <> matched[1]);

    // and the pair is inverse: projecting and reconstructing returns the mixed data
    rec := ica.Reconstruct(ic.GetObjRef);
    AssertTrue('Reconstruct returned nothing', rec <> nil);
    AssertEquals('reconstruction width', Int64(nSamples), Int64(rec.Width));
    AssertEquals('reconstruction height', Int64(nFeat), Int64(rec.Height));
    e := 0;
    for i := 0 to nSamples - 1 do
      for k := 0 to nFeat - 1 do
        e := Max(e, Abs(rec.Items[i, k] - mixed.Items[i, k]));
    AssertTrue(Format('project+reconstruct is not the identity (max err %.3e)', [e]), e <= 1e-10);
  finally
    rec.Free;
    ica.Free;
    mixed.Free;
    src.Free;
  end;
end;

initialization
  RegisterTest(TAlgorithmTests);
end.
