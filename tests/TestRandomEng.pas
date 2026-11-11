// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// FPCUnit suite for the random number engines (RandomEng).
unit TestRandomEng;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, fpcunit, testregistry, RandomEng;

type
  TRandomEngTests = class(TTestCase)
  private
    procedure RequireOsRandom;
  published
    procedure TestOsEngineRange;
    procedure TestOsEngineIsNotConstant;
    procedure TestOsEngineRandIntRange;
    procedure TestMersenneReproducible;
    procedure TestChaChaReproducible;
  end;

implementation

const
  cDraws = 500;

procedure TRandomEngTests.RequireOsRandom;
begin
  if not FileExists('/dev/urandom') then
    Ignore('no /dev/urandom on this system');
end;

procedure TRandomEngTests.TestOsEngineRange;
var
  rg : TRandomGenerator;
  i : integer;
  v : double;
begin
  RequireOsRandom;
  rg := TRandomGenerator.Create(raOS);
  try
    for i := 1 to cDraws do
    begin
      v := rg.Random;
      AssertTrue(Format('draw %d in [0,1): %f', [i, v]), (v >= 0.0) and (v < 1.0));
    end;
  finally
    rg.Free;
  end;
end;

procedure TRandomEngTests.TestOsEngineIsNotConstant;
var
  rg : TRandomGenerator;
  i : integer;
  vals : array[0..7] of double;
  allSame : boolean;
begin
  RequireOsRandom;
  rg := TRandomGenerator.Create(raOS);
  try
    for i := 0 to High(vals) do
      vals[i] := rg.Random;

    allSame := True;
    for i := 1 to High(vals) do
      if vals[i] <> vals[0] then
        allSame := False;

    AssertFalse('the OS engine returned the same value 8 times', allSame);
  finally
    rg.Free;
  end;
end;

procedure TRandomEngTests.TestOsEngineRandIntRange;
var
  rg : TRandomGenerator;
  i, v : integer;
begin
  rg := TRandomGenerator.Create(raOS);
  try
    for i := 1 to cDraws do
    begin
      v := rg.RandInt(10);
      AssertTrue(Format('RandInt(10) out of range: %d', [v]), (v >= 0) and (v < 10));
    end;
  finally
    rg.Free;
  end;
end;

procedure TRandomEngTests.TestMersenneReproducible;
var
  rg : TRandomGenerator;
  i : integer;
  first, second : array[0..4] of double;
begin
  rg := TRandomGenerator.Create(raMersenneTwister);
  try
    rg.Init(12345);
    for i := 0 to High(first) do
      first[i] := rg.Random;

    rg.Init(12345);
    for i := 0 to High(second) do
      second[i] := rg.Random;

    for i := 0 to High(first) do
      AssertEquals(Format('value %d not reproducible', [i]), first[i], second[i], 0.0);
  finally
    rg.Free;
  end;
end;

procedure TRandomEngTests.TestChaChaReproducible;
var
  rg : TRandomGenerator;
  i : integer;
  first, second : array[0..4] of double;
begin
  rg := TRandomGenerator.Create(raChaCha);
  try
    rg.Init(4242);
    for i := 0 to High(first) do
      first[i] := rg.Random;

    rg.Init(4242);
    for i := 0 to High(second) do
      second[i] := rg.Random;

    for i := 0 to High(first) do
      AssertEquals(Format('value %d not reproducible', [i]), first[i], second[i], 0.0);
  finally
    rg.Free;
  end;
end;

initialization
  RegisterTest(TRandomEngTests);
end.
