// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// The ASMMatrix* entry points dispatch on two properties of a call - whether
// the destination and line width are 16-byte aligned, and whether the width is
// even or odd - into four separate hand-written routines, so all four paths are
// exercised for every operation; that is where the tail and alignment bugs live.
// Part 2 requires the FPU/SSE/AVX/FMA tiers to agree and verifies with
// GetCurCPUInstrType that InitMathFunctions did not silently downgrade; part 3
// checks Strassen against the direct multiply.
unit TestSIMDTiers;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Math, fpcunit, testregistry, MatrixConst, Matrix, MatrixASMStubSwitch,
  ASMMatrixOperations, CPUFeatures;

type
  TRefKind = (rkAdd, rkSub, rkElemMult, rkElemDiv);

  TBinaryOp = procedure(dest : PDouble; destLineWidth : NativeInt; mt1, mt2 : PDouble;
                        width : NativeInt; height : NativeInt;
                        LineWidth1, LineWidth2 : NativeInt);

  TBuffer = record
    Base : Pointer;
    Data : PDouble;
  end;

  TSIMDTierTests = class(TTestCase)
  private
    function NewBuf(numDoubles : integer; misalign : boolean) : TBuffer;
    procedure FreeBuf(var b : TBuffer);
    procedure CheckBinary(const name : string; op : TBinaryOp; kind : TRefKind;
                          destMisalign : boolean; width, height : integer);
    procedure CheckUnary(const name : string; value : array of double;
                         destMisalign : boolean; width, height : integer;
                         mode : integer; const offset, scale : double);
  protected
    procedure TearDown; override;
  published
    procedure TestBinaryOpsAlignmentAndParity;
    procedure TestUnaryOpsAlignmentAndParity;
    procedure TestTransposeAlignmentAndParity;
    procedure TestTierAgreementElementwise;
    procedure TestTierAgreementMultiply;
    procedure TestTierAgreementReductions;
    procedure TestStrassenAgreesWithDirect;
    procedure TestCpuFeatureDetection;
  end;

implementation

function TSIMDTierTests.NewBuf(numDoubles : integer; misalign : boolean) : TBuffer;
begin
  Result.Base := GetMem(numDoubles * SizeOf(double) + 256);
  if Result.Base = nil then
    raise Exception.Create('out of memory');
  // 64-byte aligned, optionally shifted by one double to break 16-byte alignment
  Result.Data := PDouble((NativeUInt(Result.Base) + 63) and not NativeUInt(63));
  if misalign then
    Result.Data := Result.Data + 1;
end;

procedure TSIMDTierTests.FreeBuf(var b : TBuffer);
begin
  if b.Base <> nil then
    FreeMem(b.Base);
  b.Base := nil;
  b.Data := nil;
end;

procedure TSIMDTierTests.TearDown;
begin
  // leave the library in its start-up state: FMA where available, no Strassen
  InitMathFunctions(itFMA, False);
end;

procedure TSIMDTierTests.CheckBinary(const name : string; op : TBinaryOp; kind : TRefKind;
  destMisalign : boolean; width, height : integer);
var
  ba, bb, bd : TBuffer;
  lwA, lwB, lwD : NativeInt;
  x, y, stepA, stepB, stepD : integer;
  e, expected : double;
begin
  stepA := width;                                  // tightly packed
  stepB := width + 2;                              // different stride for B
  if destMisalign then
    stepD := width + 1                              // odd double count -> line width not /16
  else
    stepD := width + (width and 1);                 // even double count -> line width /16
  lwA := stepA * SizeOf(double);
  lwB := stepB * SizeOf(double);
  lwD := stepD * SizeOf(double);

  ba := NewBuf(height * stepA + 8, False);
  bb := NewBuf(height * stepB + 8, False);
  bd := NewBuf(height * stepD + 8, destMisalign);
  try
    RandSeed := 4711;
    for y := 0 to height - 1 do
      for x := 0 to width - 1 do
      begin
        ba.Data[x + y * stepA] := Random * 2 - 1;
        bb.Data[x + y * stepB] := (Random * 2 - 1) + 3;   // keeps divisors away from 0
        bd.Data[x + y * stepD] := 12345;                  // poison value
      end;

    op(bd.Data, lwD, ba.Data, bb.Data, width, height, lwA, lwB);

    e := 0;
    for y := 0 to height - 1 do
      for x := 0 to width - 1 do
      begin
        case kind of
          rkAdd     : expected := ba.Data[x + y * stepA] + bb.Data[x + y * stepB];
          rkSub     : expected := ba.Data[x + y * stepA] - bb.Data[x + y * stepB];
          rkElemMult: expected := ba.Data[x + y * stepA] * bb.Data[x + y * stepB];
        else
          expected := ba.Data[x + y * stepA] / bb.Data[x + y * stepB];
        end;
        e := Max(e, Abs(bd.Data[x + y * stepD] - expected));
      end;

    AssertTrue(Format('%s (dest %s, width %d, height %d): max err %.3e',
                      [name, BoolToStr(destMisalign, 'misaligned', 'aligned'), width, height, e]),
               e <= 1e-13);
  finally
    FreeBuf(bd); FreeBuf(bb); FreeBuf(ba);
  end;
end;

// mode: 0 = abs, 1 = dest + offset, 2 = (dest + offset) * scale, 3 = sqrt
procedure TSIMDTierTests.CheckUnary(const name : string; value : array of double;
  destMisalign : boolean; width, height : integer; mode : integer;
  const offset, scale : double);
var
  b : TBuffer;
  lw : NativeInt;
  x, y, step : integer;
  e : double;
  orig : array of double;
  expected : double;
begin
  if destMisalign then
    step := width + 1
  else
    step := width + (width and 1);
  lw := step * SizeOf(double);

  b := NewBuf(height * step + 8, destMisalign);
  try
    SetLength(orig, height * step);
    RandSeed := 9911;
    for y := 0 to height - 1 do
      for x := 0 to step - 1 do
        if x < width then
        begin
          b.Data[x + y * step] := 0.5 + Random * 1.5;      // strictly positive: sqrt is real
          orig[x + y * step] := b.Data[x + y * step];
        end
        else
        begin
          b.Data[x + y * step] := -999;                    // sentinel in the stride padding
          orig[x + y * step] := -999;
        end;

    case mode of
      0: ASMMatrixAbs(b.Data, lw, width, height);
      1: ASMMatrixElemAdd(b.Data, lw, width, height, offset);
      2: ASMMatrixAddAndScale(b.Data, lw, width, height, offset, scale);
    else
      ASMMatrixSQRT(b.Data, lw, width, height);
    end;

    e := 0;
    for y := 0 to height - 1 do
      for x := 0 to width - 1 do
      begin
        case mode of
          0: expected := Abs(orig[x + y * step]);
          1: expected := orig[x + y * step] + offset;
          2: expected := (orig[x + y * step] + offset) * scale;
        else
          expected := Sqrt(orig[x + y * step]);
        end;
        e := Max(e, Abs(b.Data[x + y * step] - expected));
      end;
    AssertTrue(Format('%s (dest %s, width %d, height %d): max err %.3e',
                      [name, BoolToStr(destMisalign, 'misaligned', 'aligned'), width, height, e]),
               e <= 1e-13);

    // the stride padding must be left alone
    e := 0;
    for y := 0 to height - 1 do
      for x := width to step - 1 do
        e := Max(e, Abs(b.Data[x + y * step] - (-999)));
    AssertTrue(Format('%s (dest %s, width %d): wrote into the stride padding (dev %.3e)',
                      [name, BoolToStr(destMisalign, 'misaligned', 'aligned'), width, e]),
               e = 0);
  finally
    FreeBuf(b);
  end;
end;

procedure TSIMDTierTests.TestBinaryOpsAlignmentAndParity;
const sizes : array[0..3] of integer = (16, 8, 7, 1);
var i, k, w : integer; mis : boolean;
begin
  for i := 0 to 1 do
  begin
    mis := (i = 1);
    for k := Low(sizes) to High(sizes) do
    begin
      w := sizes[k];
      CheckBinary('ASMMatrixAdd', @ASMMatrixAdd, rkAdd, mis, w, 5);
      CheckBinary('ASMMatrixSub', @ASMMatrixSub, rkSub, mis, w, 5);
      CheckBinary('ASMMatrixElemMult', @ASMMatrixElemMult, rkElemMult, mis, w, 5);
      CheckBinary('ASMMatrixElemDiv', @ASMMatrixElemDiv, rkElemDiv, mis, w, 5);
    end;
  end;
end;

procedure TSIMDTierTests.TestUnaryOpsAlignmentAndParity;
const sizes : array[0..3] of integer = (16, 8, 7, 1);
var i, k, w : integer; mis : boolean;
begin
  for i := 0 to 1 do
  begin
    mis := (i = 1);
    for k := Low(sizes) to High(sizes) do
    begin
      w := sizes[k];
      CheckUnary('ASMMatrixAbs', [], mis, w, 4, 0, 0, 0);
      CheckUnary('ASMMatrixElemAdd', [], mis, w, 4, 1, 2.5, 0);
      CheckUnary('ASMMatrixAddAndScale', [], mis, w, 4, 2, 2.5, -0.75);
      CheckUnary('ASMMatrixSQRT', [], mis, w, 4, 3, 0, 0);
    end;
  end;
end;

procedure TSIMDTierTests.TestTransposeAlignmentAndParity;
const sizes : array[0..3] of integer = (16, 8, 7, 1);
var
  i, k, x, y, w, h : integer;
  mis : boolean;
  src, dst : TBuffer;
  lwSrc, lwDst, stepSrc, stepDst : NativeInt;
  e : double;
begin
  h := 5;
  for i := 0 to 1 do
  begin
    mis := (i = 1);
    for k := Low(sizes) to High(sizes) do
    begin
      w := sizes[k];
      stepSrc := w + 1;
      stepDst := h + 1;
      lwSrc := stepSrc * SizeOf(double);
      if mis then
        lwDst := stepDst * SizeOf(double)
      else
        lwDst := (h + (h and 1)) * SizeOf(double);
      src := NewBuf(h * stepSrc + 8, False);
      dst := NewBuf(w * (lwDst div 8) + 8, mis);
      try
        RandSeed := 7717;
        for y := 0 to h - 1 do
          for x := 0 to w - 1 do
            src.Data[x + y * stepSrc] := Random * 2 - 1;
        ASMMatrixTranspose(dst.Data, lwDst, src.Data, lwSrc, w, h);
        e := 0;
        for y := 0 to h - 1 do
          for x := 0 to w - 1 do
            e := Max(e, Abs(dst.Data[y + x * (lwDst div 8)] - src.Data[x + y * stepSrc]));
        AssertTrue(Format('ASMMatrixTranspose (dest %s, %dx%d): max err %.3e',
                          [BoolToStr(mis, 'misaligned', 'aligned'), w, h, e]), e <= 1e-15);
      finally
        FreeBuf(dst); FreeBuf(src);
      end;
    end;
  end;
end;

procedure FillRandom(m : TDoubleMatrix; amplitude : double);
var x, y : integer;
begin
  for x := 0 to m.Width - 1 do
    for y := 0 to m.Height - 1 do
      m.Items[x, y] := (Random * 2 - 1) * amplitude;
end;

function TierName(t : TCPUInstrType) : string;
begin
  case t of
    itSSE: Result := 'SSE';
    itAVX: Result := 'AVX';
    itFMA: Result := 'FMA';
  else
    Result := 'FPU';
  end;
end;

function MaxDiff(a, b : TDoubleMatrix) : double;
var x, y : integer;
begin
  if (a.Width <> b.Width) or (a.Height <> b.Height) then
    exit(1e30);
  Result := 0;
  for x := 0 to a.Width - 1 do
    for y := 0 to a.Height - 1 do
      Result := Max(Result, Abs(a.Items[x, y] - b.Items[x, y]));
end;

// Element-wise families: add, sub, elementwise multiply, abs and transpose must
// produce the same bits under every instruction tier the CPU supports.
procedure TSIMDTierTests.TestTierAgreementElementwise;
const sizes : array[0..2] of integer = (7, 16, 33);
var
  a, b : TDoubleMatrix;
  baseAdd, baseSub, baseEm, baseAbs, baseTr : TDoubleMatrix;
  rAdd, rSub, rEm, rAbs, rTr : TDoubleMatrix;
  t : TCPUInstrType;
  k : integer;
  tested : string;
  e : double;
begin
  for k := Low(sizes) to High(sizes) do
  begin
    a := TDoubleMatrix.Create(sizes[k], sizes[k] - 1, 0);
    b := TDoubleMatrix.Create(sizes[k], sizes[k] - 1, 0);
    RandSeed := 5000 + k;
    FillRandom(a, 8.0);
    RandSeed := 6000 + k;
    FillRandom(b, 8.0);
    baseAdd := nil; baseSub := nil; baseEm := nil; baseAbs := nil; baseTr := nil;
    rAdd := nil; rSub := nil; rEm := nil; rAbs := nil; rTr := nil;
    tested := '';
    try
      InitMathFunctions(itFPU, False);
      baseAdd := a.Add(b);
      baseSub := a.Sub(b);
      baseEm := a.ElementWiseMult(b);
      baseAbs := a.Abs;
      baseTr := a.Transpose;

      for t := itSSE to itFMA do
      begin
        InitMathFunctions(t, False);
        if GetCurCPUInstrType <> t then
          Continue;                       // tier not supported by this CPU
        tested := tested + TierName(t) + ' ';

        rAdd := a.Add(b);
        rSub := a.Sub(b);
        rEm := a.ElementWiseMult(b);
        rAbs := a.Abs;
        rTr := a.Transpose;
        try
          AssertEquals(Format('%s Add: differs from FPU', [TierName(t)]), 0.0, MaxDiff(rAdd, baseAdd), 0.0);
          AssertEquals(Format('%s Sub: differs from FPU', [TierName(t)]), 0.0, MaxDiff(rSub, baseSub), 0.0);
          AssertEquals(Format('%s ElementWiseMult: differs from FPU', [TierName(t)]), 0.0, MaxDiff(rEm, baseEm), 0.0);
          AssertEquals(Format('%s Abs: differs from FPU', [TierName(t)]), 0.0, MaxDiff(rAbs, baseAbs), 0.0);
          AssertEquals(Format('%s Transpose: differs from FPU', [TierName(t)]), 0.0, MaxDiff(rTr, baseTr), 0.0);
        finally
          FreeAndNil(rTr); FreeAndNil(rAbs); FreeAndNil(rEm); FreeAndNil(rSub); FreeAndNil(rAdd);
        end;
      end;

      // record what was actually compared, so a CPU without AVX/FMA is visible
      AssertTrue('elementwise tiers compared: FPU ' + tested, Pos('SSE', tested) + Pos('AVX', tested) > 0);
    finally
      FreeAndNil(baseTr); FreeAndNil(baseAbs); FreeAndNil(baseEm); FreeAndNil(baseSub); FreeAndNil(baseAdd);
      b.Free; a.Free;
    end;
  end;
end;

procedure TSIMDTierTests.TestTierAgreementMultiply;
const sizes : array[0..2] of integer = (16, 33, 64);
var
  a, b, base, r : TDoubleMatrix;
  t : TCPUInstrType;
  k : integer;
  tested : string;
  e : double;
begin
  for k := Low(sizes) to High(sizes) do
  begin
    a := TDoubleMatrix.Create(sizes[k], sizes[k], 0);
    b := TDoubleMatrix.Create(sizes[k], sizes[k], 0);
    RandSeed := 7100 + k; FillRandom(a, 1.0);
    RandSeed := 7200 + k; FillRandom(b, 1.0);
    base := nil; r := nil; tested := '';
    try
      InitMathFunctions(itFPU, False);
      base := a.Mult(b);
      for t := itSSE to itFMA do
      begin
        InitMathFunctions(t, False);
        if GetCurCPUInstrType <> t then
          Continue;
        tested := tested + TierName(t) + ' ';
        r := a.Mult(b);
        try
          e := MaxDiff(r, base);
          AssertTrue(Format('%dx%d Mult under %s: max deviation from FPU %.3e',
                            [sizes[k], sizes[k], TierName(t), e]), e <= 1e-11);
        finally
          FreeAndNil(r);
        end;
      end;
      AssertTrue('multiply tiers compared: ' + tested, Length(tested) > 0);
    finally
      base.Free; b.Free; a.Free;
    end;
  end;
end;

procedure TSIMDTierTests.TestTierAgreementReductions;
const sizes : array[0..1] of integer = (17, 64);
var
  a : TDoubleMatrix;
  baseMean, baseSum, baseCumSum, baseScaled, baseVar, baseStd : TDoubleMatrix;
  rMean, rSum, rCumSum, rScaled, rVar, rStd : TDoubleMatrix;
  baseNorm, norm : double;
  t : TCPUInstrType;
  k : integer;
  tested : string;
  e : double;
  procedure Check(const what, tier : string; got, expected : TDoubleMatrix; tol : double);
  var d : double;
  begin
    d := MaxDiff(got, expected);
    AssertTrue(Format('%s %s: dev from FPU %.3e', [tier, what, d]), d <= tol);
  end;
begin
  for k := Low(sizes) to High(sizes) do
  begin
    a := TDoubleMatrix.Create(sizes[k], sizes[k] + 3, 0);
    RandSeed := 8100 + k;
    FillRandom(a, 5.0);
    baseMean := nil; baseSum := nil; baseCumSum := nil; baseScaled := nil;
    baseVar := nil; baseStd := nil;
    rMean := nil; rSum := nil; rCumSum := nil; rScaled := nil; rVar := nil; rStd := nil;
    tested := '';
    try
      InitMathFunctions(itFPU, False);
      baseMean := a.Mean(True);
      baseSum := a.Sum(True);
      baseCumSum := a.CumulativeSum(True);
      baseScaled := a.AddAndScale(0.5, 2.0);
      baseVar := a.Variance(True);
      baseStd := a.Std(True);
      baseNorm := a.ElementwiseNorm2(True);

      for t := itSSE to itFMA do
      begin
        InitMathFunctions(t, False);
        if GetCurCPUInstrType <> t then
          Continue;                       // tier not supported by this CPU
        tested := tested + TierName(t) + ' ';

        rMean := a.Mean(True);
        Check('Mean', TierName(t), rMean, baseMean, 1e-12);
        FreeAndNil(rMean);

        rSum := a.Sum(True);
        Check('Sum', TierName(t), rSum, baseSum, 1e-12);
        FreeAndNil(rSum);

        rCumSum := a.CumulativeSum(True);
        Check('CumulativeSum', TierName(t), rCumSum, baseCumSum, 1e-12);
        FreeAndNil(rCumSum);

        rScaled := a.AddAndScale(0.5, 2.0);
        Check('AddAndScale', TierName(t), rScaled, baseScaled, 1e-12);
        FreeAndNil(rScaled);

        rVar := a.Variance(True);
        Check('Variance', TierName(t), rVar, baseVar, 1e-10);
        FreeAndNil(rVar);

        rStd := a.Std(True);
        Check('Std', TierName(t), rStd, baseStd, 1e-10);
        FreeAndNil(rStd);

        norm := a.ElementwiseNorm2(True);
        e := Abs(norm - baseNorm) / Max(1e-30, Abs(baseNorm));
        AssertTrue(Format('%s ElementwiseNorm2: relative dev from FPU %.3e', [TierName(t), e]), e <= 1e-12);
      end;
      AssertTrue('reduction tiers compared: FPU ' + tested, Length(tested) > 0);
    finally
      rStd.Free; rVar.Free; rScaled.Free; rCumSum.Free; rSum.Free; rMean.Free;
      baseStd.Free; baseVar.Free; baseScaled.Free; baseCumSum.Free; baseSum.Free; baseMean.Free;
      a.Free;
    end;
  end;
end;

procedure TSIMDTierTests.TestStrassenAgreesWithDirect;
const sizes : array[0..2] of integer = (32, 64, 129);
var
  a, b, direct, strassen : TDoubleMatrix;
  k : integer;
  e : double;
begin
  for k := Low(sizes) to High(sizes) do
  begin
    a := TDoubleMatrix.Create(sizes[k], sizes[k], 0);
    b := TDoubleMatrix.Create(sizes[k], sizes[k], 0);
    RandSeed := 9100 + k; FillRandom(a, 1.0);
    RandSeed := 9200 + k; FillRandom(b, 1.0);
    direct := nil; strassen := nil;
    try
      InitMathFunctions(itFMA, False);
      direct := a.Mult(b);
      InitMathFunctions(itFMA, True);
      strassen := a.Mult(b);
      e := MaxDiff(strassen, direct);
      AssertTrue(Format('%dx%d Mult: Strassen deviates from direct by %.3e', [sizes[k], sizes[k], e]), e <= 1e-11);
    finally
      strassen.Free; direct.Free; b.Free; a.Free;
    end;
  end;
end;


// The CPU probe (CPUID + xgetbv for the OS AVX state) drives tier selection.  The
// assertions are consistency checks rather than hardware assumptions, so they
// hold on any machine.
// reads the CPU flag list from /proc/cpuinfo (Linux only); returns false when the
// file is not available
function KernelCpuFlag(const flag : string) : boolean;
var
  f : TextFile;
  line : string;
  flags : string;
  p : integer;
begin
  Result := False;
  if not FileExists('/proc/cpuinfo') then
    exit;
  flags := '';
  AssignFile(f, '/proc/cpuinfo');
  {$I-}
  Reset(f);
  {$I+}
  if IOResult <> 0 then
    exit;
  try
    while not Eof(f) and (flags = '') do
    begin
      ReadLn(f, line);
      if Pos('flags', line) = 1 then
        flags := ' ' + Copy(line, Pos(':', line) + 1, Length(line)) + ' ';
    end;
  finally
    CloseFile(f);
  end;
  if flags = '' then
    exit;
  p := Pos(' ' + flag + ' ', flags);
  Result := p > 0;
end;

procedure TSIMDTierTests.TestCpuFeatureDetection;
var
  tier, applied : TCPUInstrType;
  asked, got : integer;
  haveIt : boolean;
begin
  // FMA implies AVX on every x86-64 part that has it
  if IsFMAPresent then
    AssertTrue('FMA reported without AVX', IsAVXPresent);

  // cross-check the CPUID/xgetbv probe against the kernel's view of the CPU; a
  // broken xgetbv would show up here as a mismatch
  if FileExists('/proc/cpuinfo') then
  begin
    AssertEquals('avx support disagrees with /proc/cpuinfo',
                 Ord(KernelCpuFlag('avx')), Ord(IsAVXPresent));
    AssertEquals('fma support disagrees with /proc/cpuinfo',
                 Ord(KernelCpuFlag('fma')), Ord(IsFMAPresent));
  end;

  for tier := itFPU to itFMA do
  begin
    InitMathFunctions(tier, False);
    applied := GetCurCPUInstrType;
    asked := Ord(tier);
    got := Ord(applied);

    // when the CPU supports the requested tier it must be applied exactly - a
    // silent downgrade would mean the feature probe is wrong; otherwise the
    // documented downgrade to a lower tier is allowed
    case tier of
      itSSE: haveIt := IsSSE3Present;
      itAVX: haveIt := IsAVXPresent;
      itFMA: haveIt := IsFMAPresent;
    else
      haveIt := True;
    end;
    if haveIt then
      AssertEquals(Format('requested tier %d on a capable CPU, got %d', [asked, got]),
                   Int64(asked), Int64(got))
    else
      AssertTrue(Format('requested unsupported tier %d, got %d (must not upgrade)', [asked, got]),
                 got <= asked);

    // and the applied tier must be consistent with the detected features
    case applied of
      itFMA: AssertTrue('FMA tier without FMA support', IsFMAPresent);
      itAVX: AssertTrue('AVX tier without AVX support', IsAVXPresent);
    end;
  end;

  // leave the library on its start-up tier
  InitMathFunctions(itFMA, False);
  AssertTrue('the detected tier after restoration is valid',
             Ord(GetCurCPUInstrType) <= Ord(itFMA));
end;

initialization
  RegisterTest(TSIMDTierTests);
end.
