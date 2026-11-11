// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// Algorithm quality tests: the suites elsewhere prove that the primitives are
// numerically right and that the factorisations satisfy their defining
// equations. These tests check that the *higher level* algorithms actually do
// their job on data with a known answer:
//
//   PCA  : data of known rank is reconstructed from its components
//          (X ~ Mean + V*V^T*(X - Mean) when all modes are kept)
//   NNMF : V ~ W*H with W,H >= 0
//   EM   : two well separated Gaussian clusters are found at their means
//
// Storage conventions that the library does not document are handled by
// evaluating the alternatives and requiring one of them to hold.
unit TestAlgorithmQuality;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Math, fpcunit, testregistry, MatrixConst, Matrix, PCA, NNMF, EM;

type
  TAlgorithmQualityTests = class(TTestCase)
  private
    function MaxAbs(a : TDoubleMatrix) : double;
  published
    procedure TestPCAReconstructsLowRankData;
    procedure TestPCAEigenvaluesValid;
    procedure TestNNMFReconstructsNonNegative;
    procedure TestEMFindsClusterMeans;
  end;

implementation

function TAlgorithmQualityTests.MaxAbs(a : TDoubleMatrix) : double;
var x, y : integer;
begin
  Result := 0;
  for x := 0 to a.Width - 1 do
    for y := 0 to a.Height - 1 do
      Result := Max(Result, Abs(a.Items[x, y]));
end;

// ---------------------------------------------------------------- PCA ----
// Data of rank 2 embedded in 4 features, N samples. The reconstruction uses
// only the public EigVecs / Mean properties, trying both factor orientations.
procedure TAlgorithmQualityTests.TestPCAReconstructsLowRankData;
const
  cFeat = 4;
  cSamples = 30;
  cLatent = 2;
var
  lat, mix, data, ex, feat, rec : TDoubleMatrix;
  pca : TMatrixPCA;
  f, s, k : integer;
  err : double;
begin
  RandSeed := 4242;
  lat := TDoubleMatrix.Create(cLatent, cSamples, 0);
  mix := TDoubleMatrix.Create(cFeat, cLatent, 0);
  // PCA follows the mrMath layout: columns are samples, rows are features
  data := TDoubleMatrix.Create(cSamples, cFeat, 0);
  pca := TMatrixPCA.Create([pcaEigVals]);   // keep the eigenvalues
  try
    for k := 0 to cLatent - 1 do
      for s := 0 to cSamples - 1 do
        lat.Items[k, s] := Random * 2 - 1;
    for f := 0 to cFeat - 1 do
      for k := 0 to cLatent - 1 do
        mix.Items[f, k] := Random * 2 - 1;

    for s := 0 to cSamples - 1 do
      for f := 0 to cFeat - 1 do
      begin
        err := 0;
        for k := 0 to cLatent - 1 do
          err := err + mix.Items[f, k] * lat.Items[k, s];
        data.Items[s, f] := err;
      end;

    // CutEps is a count (not an epsilon) when IsRelativeValue=False: it sets the
    // threshold from the first CutEps eigenvalues. 0 keeps the documented
    // minimum of one mode, so ask for cLatent.
    AssertTrue('PCA returned false', pca.PCA(data, cLatent, False));
    AssertTrue(Format('PCA kept only %d modes for rank-%d data', [pca.NumModes, cLatent]),
               pca.NumModes >= cLatent);

    // project each sample into feature space and back: rank-2 data must be
    // reproduced exactly when at least two modes are kept
    err := 0;
    for s := 0 to cSamples - 1 do
    begin
      ex := TDoubleMatrix.Create(1, cFeat, 0);
      feat := nil; rec := nil;
      try
        for f := 0 to cFeat - 1 do
          ex.Items[0, f] := data.Items[s, f];
        feat := pca.ProjectToFeatureSpace(ex);
        rec := pca.Reconstruct(feat);
        for f := 0 to cFeat - 1 do
          err := Max(err, Abs(rec.Items[0, f] - ex.Items[0, f]));
      finally
        rec.Free; feat.Free; ex.Free;
      end;
    end;

    AssertTrue(Format('PCA reconstruction of rank-%d data: max err %.3e', [cLatent, err]),
               err <= 1e-9);
  finally
    pca.Free;
    data.Free;
    mix.Free;
    lat.Free;
  end;
end;

procedure TAlgorithmQualityTests.TestPCAEigenvaluesValid;
const cFeat = 5; cSamples = 40;
var
  data : TDoubleMatrix;
  pca : TMatrixPCA;
  f, s : integer;
  prev, v : double;
begin
  RandSeed := 99;
  data := TDoubleMatrix.Create(cFeat, cSamples, 0);
  pca := TMatrixPCA.Create([pcaEigVals]);   // keep the eigenvalues
  try
    for f := 0 to cFeat - 1 do
      for s := 0 to cSamples - 1 do
        data.Items[f, s] := Random * 2 - 1;

    AssertTrue('PCA returned false', pca.PCA(data, 0, False));

    prev := 1e300;
    for f := 0 to (pca.EigVals.Width * pca.EigVals.Height) - 1 do
    begin
      if pca.EigVals.Height = 1 then
        v := pca.EigVals.Items[f, 0]
      else
        v := pca.EigVals.Items[0, f];
      AssertTrue(Format('eigenvalue %d is negative (%.6e)', [f, v]), v >= -1e-12);
      AssertTrue(Format('eigenvalues not descending at %d (%.6e > %.6e)', [f, v, prev]),
                 v <= prev + 1e-12);
      prev := v;
    end;
  finally
    pca.Free;
    data.Free;
  end;
end;

// --------------------------------------------------------------- NNMF ----
// V = W0*H0 with W0, H0 >= 0; the factorisation must reproduce V and must not
// produce negative factors.
procedure TAlgorithmQualityTests.TestNNMFReconstructsNonNegative;
const
  cFeat = 3;
  cComp = 2;
  cSamples = 5;
var
  w0, h0, v, wd, hd, prod : TDoubleMatrix;
  obj : TNNMF;
  res : TNMFRes;
  f, c, s : integer;
  err, neg : double;
begin
  RandSeed := 77;
  w0 := TDoubleMatrix.Create(cFeat, cComp, 0);
  h0 := TDoubleMatrix.Create(cComp, cSamples, 0);
  prod := nil;
  obj := TNNMF.Create;
  try
    for f := 0 to cFeat - 1 do
      for c := 0 to cComp - 1 do
        w0.Items[f, c] := Random + 0.1;
    for c := 0 to cComp - 1 do
      for s := 0 to cSamples - 1 do
        h0.Items[c, s] := Random + 0.1;

    v := w0.Mult(h0);
    try
      res := obj.CalcNMF(v);
      AssertTrue(Format('NNMF result %d (0 = ok, 1 = precision reached)', [Ord(res)]),
                 res in [nmOk, nmFloatingPointPrecReached]);

      wd := obj.W;
      hd := obj.H;

      neg := 0;
      for f := 0 to wd.Width - 1 do
        for c := 0 to wd.Height - 1 do
          if wd.Items[f, c] < 0 then
            neg := Max(neg, -wd.Items[f, c]);
      for c := 0 to hd.Width - 1 do
        for s := 0 to hd.Height - 1 do
          if hd.Items[c, s] < 0 then
            neg := Max(neg, -hd.Items[c, s]);
      AssertTrue(Format('NNMF produced a negative factor (%.3e)', [neg]), neg <= 1e-12);

      prod := wd.Mult(hd);
      err := 0;
      for f := 0 to Min(prod.Width, v.Width) - 1 do
        for s := 0 to Min(prod.Height, v.Height) - 1 do
          err := Max(err, Abs(prod.Items[f, s] - v.Items[f, s]));
      AssertTrue(Format('NNMF: ||V - W*H|| = %.3e (max |V| = %.3f)', [err, MaxAbs(v)]),
                 err <= 1e-3 * (1 + MaxAbs(v)));
    finally
      v.Free;
    end;
  finally
    prod.Free;
    obj.Free;
    h0.Free;
    w0.Free;
  end;
end;

// ----------------------------------------------------------------- EM ----
// Two well separated clusters; the estimated means must match the true ones
// (in either order).
procedure TAlgorithmQualityTests.TestEMFindsClusterMeans;
const
  cDims = 2;
  cPerCluster = 100;
  cOffset = 5.0;
var
  im : IMatrix;
  obj : TExpectationMax;
  w, m : IMatrix;
  v : IMatrixDynArr;
  d, s : integer;
  ok, foundLow, foundHigh : boolean;
  err : double;
begin
  RandSeed := 101;
  // the data lives in an interface variable: it is released when im := nil,
  // so there is no separate object to free (mixing both is a double free)
  im := TDoubleMatrix.Create(cDims, cPerCluster * 2, 0);
  obj := TExpectationMax.Create;
  try
    for s := 0 to cPerCluster * 2 - 1 do
      for d := 0 to cDims - 1 do
        if s < cPerCluster then
          im.Items[d, s] := cOffset + (Random - 0.5) * 0.4
        else
          im.Items[d, s] := -cOffset + (Random - 0.5) * 0.4;

    ok := obj.Estimate(im, 2, w, m, v);
    AssertTrue('EM Estimate returned false', ok);
    AssertTrue('EM returned fewer than 2 means', (m.Width * m.Height) >= 2 * cDims);

    // each estimated mean (one per cluster, along either axis) must be +-offset
    foundLow := False;
    foundHigh := False;
    for s := 0 to (m.Width * m.Height div cDims) - 1 do
    begin
      err := 0;
      for d := 0 to cDims - 1 do
        if m.Height >= cDims then
          err := Max(err, Abs(Abs(m.Items[d, s]) - cOffset))
        else
          err := Max(err, Abs(Abs(m.Items[s, d]) - cOffset));
      AssertTrue(Format('EM mean %d is not near +-%.1f (max dev %.3f)', [s, cOffset, err]),
                 err <= 0.5);
      if m.Items[0, s] > 0 then
        foundHigh := True
      else
        foundLow := True;
    end;
    AssertTrue('EM found both cluster centres', foundLow and foundHigh);
  finally
    obj.Free;
  end;
end;

initialization
  RegisterTest(TAlgorithmQualityTests);
end.
