// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// FPCUnit suite for the Barnes-Hut t-SNE implementation.
//
// This is a regression test for a crash that shipped in 1.2.0: the tree walk
// passed `@fData[idx*fD]` where fData is a PConstDoubleArr (a pointer to an
// array type), so the index scaled by SizeOf(the whole array) instead of by
// one double. The resulting pointer was garbage and the first non-edge force
// raised EAccessViolation.
unit TestTSNE;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, Matrix, tSNE;

type
  TTSNETests = class(TTestCase)
  published
    procedure TestBarnesHutRuns;
    procedure TestOutputIsFinite;
  end;

implementation

const
  cSamples = 120;
  cDims = 10;
  cEmbedDims = 2;
  cIters = 20;
  cPerplexity = 10;

// one example per row: width = dims, height = samples
function MakeData : TDoubleMatrix;
var
  s, d : integer;
begin
  RandSeed := 4711;
  Result := TDoubleMatrix.Create(cDims, cSamples, 0);
  for s := 0 to cSamples - 1 do
    for d := 0 to cDims - 1 do
      Result.Items[d, s] := (s div 12) * 0.3 + Random * 0.4;
end;

procedure TTSNETests.TestBarnesHutRuns;
var
  data, res : TDoubleMatrix;
begin
  data := MakeData;
  res := nil;
  try
    res := TtSNE.SymTSNE(data, cEmbedDims, cDims, cPerplexity, 0.5, cIters);
    AssertEquals('embedding width', Int64(cEmbedDims), Int64(res.Width));
    AssertEquals('embedding height', Int64(cSamples), Int64(res.Height));
  finally
    res.Free;
    data.Free;
  end;
end;

procedure TTSNETests.TestOutputIsFinite;
var
  data, res : TDoubleMatrix;
  s, d : integer;
  v : double;
  bad : integer;
begin
  data := MakeData;
  res := nil;
  try
    res := TtSNE.SymTSNE(data, cEmbedDims, cDims, cPerplexity, 0.5, cIters);
    bad := 0;
    for s := 0 to res.Height - 1 do
      for d := 0 to res.Width - 1 do
      begin
        v := res.Items[d, s];
        // NaN <> NaN, so compare with itself and against +-inf bounds
        if (v <> v) or (v > 1e300) or (v < -1e300) then
          inc(bad);
      end;
    AssertEquals('non-finite embedding values', Int64(0), Int64(bad));
  finally
    res.Free;
    data.Free;
  end;
end;

initialization
  RegisterTest(TTSNETests);
end.
