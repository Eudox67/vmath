// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// FPCUnit console runner: registers every test unit in tests/ and runs them.
// Built with FPC's own fcl-fpcunit (simpletestrunner), so no Lazarus needed.
//
//   fpc -gh @vmath.cfg tests/run_tests.pas -FUtests/units -FEbin
//   ./bin/run_tests
program run_tests;

{$MODE OBJFPC}{$H+}

uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required by the thread pool (see README)
  Classes,
  SysUtils,
  fpcunit,
  testregistry,
  simpletestrunner,
  BaseMathPersistence,
  CBORReadWrite,
  cbor,
  TestCBORNested,
  TestMatrixCore,
  TestRandomEng,
  TestTSNE,
  TestThreadedMatrix,
  TestNumericAudit,
  TestLinAlgIdentities,
  TestAlgorithmQuality,
  TestCoreCoverage,
  TestSIMDTiers,
  TestStatistics,
  TestPersistence,
  TestMatrixLifecycle,
  TestComplexOps,
  TestAlgorithms;

var
  ARunner : TTestRunner;
begin
  // Force initialization of the persistence units
  RegisterMathIOReader(TCBORReaderWriter);
  RegisterMathIO(TNestedData);

  ARunner := TTestRunner.Create(nil);
  try
    ARunner.Initialize;
    ARunner.Title := 'vmath FPCUnit suite';
    ARunner.Run;
  finally
    ARunner.Free;
  end;
end.
