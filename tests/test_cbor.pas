// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

program test_cbor;

{$MODE OBJFPC}{$H+}

uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required by the thread pool (see README)
  SysUtils, Classes, CBOR;
  
const
  C_GREEN = #27'[32m';
  C_RED   = #27'[31m';
  C_RESET = #27'[0m';


procedure TestScalars;
var
  stream: TMemoryStream;
  writer: TCBORWriter;
  reader: TCBORReader;
  u: UInt64;
  i: Int64;
  f: Double;
begin
  stream := TMemoryStream.Create;
  try
    writer.Init(stream);

    // Write values
    writer.WriteUInt(42);
    writer.WriteInt(-17);
    writer.WriteFloat(3.141592653589793238);

    stream.Position := 0;
    reader.Init(stream);

    u := reader.ReadUInt;
    if u <> 42 then
      raise Exception.Create('UInt round-trip failed');

    i := reader.ReadInt;
    if i <> -17 then
      raise Exception.Create('Int round-trip failed');

    f := reader.ReadFloat;
    if Abs(f - 3.141592653589793238) > 1e-15 then
      raise Exception.Create('Float round-trip failed');

    WriteLn(C_GREEN, '✔ ', C_RESET, ' Scalar types: OK');
  finally
    stream.Free;
  end;
end;

procedure TestStringsAndBinary;
var
  stream: TMemoryStream;
  writer: TCBORWriter;
  reader: TCBORReader;
  text: UTF8String;
  bin: TBytes;
  expectedBin: TBytes;
begin
  stream := TMemoryStream.Create;
  try
    writer.Init(stream);

    writer.WriteText('Hello, CBOR!');
    SetLength(expectedBin, 5);
    expectedBin[0] := $DE; expectedBin[1] := $AD; expectedBin[2] := $BE;
    expectedBin[3] := $EF; expectedBin[4] := $00;
    writer.WriteBytes(expectedBin[0], Length(expectedBin));

    stream.Position := 0;
    reader.Init(stream);

    text := reader.ReadText;
    if text <> 'Hello, CBOR!' then
      raise Exception.Create('Text round-trip failed');

    bin := reader.ReadBytes;
    if (Length(bin) <> Length(expectedBin)) or
       (CompareMem(@bin[0], @expectedBin[0], Length(bin)) = False) then
      raise Exception.Create('Binary round-trip failed');

    WriteLn(C_GREEN, '✔ ', C_RESET, ' Strings and binary: OK');
  finally
    stream.Free;
  end;
end;

procedure TestArrays;
var
  stream: TMemoryStream;
  writer: TCBORWriter;
  reader: TCBORReader;
  count: UInt64;
  f: Double;
begin
  stream := TMemoryStream.Create;
  try
    writer.Init(stream);

    writer.WriteArrayHeader(3);
    writer.WriteFloat(1.0);
    writer.WriteFloat(-0.5);
    writer.WriteFloat(2.71828);

    stream.Position := 0;
    reader.Init(stream);

    count := reader.ReadArrayHeader;
    if count <> 3 then
      raise Exception.Create('Array count mismatch');

    f := reader.ReadFloat;
    if Abs(f - 1.0) > 1e-12 then raise Exception.Create('Array[0] failed');
    f := reader.ReadFloat;
    if Abs(f + 0.5) > 1e-12 then raise Exception.Create('Array[1] failed');
    f := reader.ReadFloat;
    if Abs(f - 2.71828) > 1e-12 then raise Exception.Create('Array[2] failed');

    WriteLn(C_GREEN, '✔ ', C_RESET, ' Arrays: OK');
  finally
    stream.Free;
  end;
end;

procedure TestMaps;
var
  stream: TMemoryStream;
  writer: TCBORWriter;
  reader: TCBORReader;
  count: UInt64;
  key, value: UTF8String;
  num: Double;
begin
  stream := TMemoryStream.Create;
  try
    writer.Init(stream);

    writer.WriteMapHeader(2);
    writer.WriteText('name');
    writer.WriteText('embedding');
    writer.WriteText('score');
    writer.WriteFloat(0.98765);

    stream.Position := 0;
    reader.Init(stream);

    count := reader.ReadMapHeader;
    if count <> 2 then
      raise Exception.Create('Map count mismatch');

    key := reader.ReadText;
    if key <> 'name' then raise Exception.Create('Map key 1 failed');
    value := reader.ReadText;
    if value <> 'embedding' then raise Exception.Create('Map value 1 failed');

    key := reader.ReadText;
    if key <> 'score' then raise Exception.Create('Map key 2 failed');
    num := reader.ReadFloat;
    if Abs(num - 0.98765) > 1e-12 then raise Exception.Create('Map value 2 failed');

    WriteLn(C_GREEN, '✔ ', C_RESET, ' Maps: OK');
  finally
    stream.Free;
  end;
end;

procedure TestFloatPrecision;
var
  stream: TMemoryStream;
  writer: TCBORWriter;
  reader: TCBORReader;
  f32, f64: Double;
begin
  stream := TMemoryStream.Create;
  try
    writer.Init(stream);

    f32 := 1.5; // exactly representable in float32
    f64 := 0.123456789012345; // requires float64

    writer.WriteFloat(f32);
    writer.WriteFloat(f64);

    stream.Position := 0;
    reader.Init(stream);

    if Abs(reader.ReadFloat - f32) > 1e-7 then
      raise Exception.Create('Float32 precision failed');

    if Abs(reader.ReadFloat - f64) > 1e-15 then
      raise Exception.Create('Float64 precision failed');

    WriteLn(C_GREEN, '✔ ', C_RESET, ' Float precision: OK');
  finally
    stream.Free;
  end;
end;

begin
  try
    TestScalars;
    TestStringsAndBinary;
    TestArrays;
    TestMaps;
    TestFloatPrecision;
    WriteLn('🎉 All CBOR tests passed!');
  except
    on E: Exception do
      WriteLn(C_RED, '✗ ', C_RESET, ' Test failed: ', E.Message);
  end;
end.
