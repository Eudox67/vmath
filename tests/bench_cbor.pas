// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

program bench_cbor;

{$MODE OBJFPC}{$H+}

uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required by the thread pool (see README)
  SysUtils, Classes,
  CBOR;

function NowMs: QWord;
begin
  Result := GetTickCount64;
end;

procedure BuildTestPayload(AStream: TStream);
var
  LWriter: TCBORWriter;
  LIdx: Integer;
begin
  LWriter.Init(AStream);

  // Map with three entries:
  // "id": 123456
  // "name": "benchmark"
  // "values": [0.0, 0.5, ... 99.5]
  LWriter.WriteMapHeader(3);

  LWriter.WriteText('id');
  LWriter.WriteUInt(123456);

  LWriter.WriteText('name');
  LWriter.WriteText('benchmark');

  LWriter.WriteText('values');
  LWriter.WriteArrayHeader(200);
  for LIdx := 0 to 199 do
    LWriter.WriteFloat(LIdx * 0.5);
end;

procedure RunDecodeCBOR(AStream: TStream; AIterations: Integer);
var
  LReader: TCBORReader;
  LIter, LIdx: Integer;
  LMapCount, LArrCount: UInt64;
  LKeyStr, LName: UTF8String;
  LId: UInt64;
  LVal: Double;
begin
  for LIter := 1 to AIterations do
  begin
    AStream.Position := 0;
    LReader.Init(AStream);

    LMapCount := LReader.ReadMapHeader;
    if LMapCount <> 3 then
      raise Exception.Create('Map count mismatch (CBOR)');

    // "id"
    LKeyStr := LReader.ReadText;
    LId := LReader.ReadUInt;
    if (LKeyStr <> 'id') or (LId <> 123456) then
      raise Exception.Create('id mismatch (CBOR)');

    // "name"
    LKeyStr := LReader.ReadText;
    LName := LReader.ReadText;
    if (LKeyStr <> 'name') or (LName <> 'benchmark') then
      raise Exception.Create('name mismatch (CBOR)');

    // "values"
    LKeyStr := LReader.ReadText;
    LArrCount := LReader.ReadArrayHeader;
    if (LKeyStr <> 'values') or (LArrCount <> 200) then
      raise Exception.Create('values header mismatch (CBOR)');

    for LIdx := 0 to 199 do
    begin
      LVal := LReader.ReadFloat;
      if Abs(LVal - (LIdx * 0.5)) > 1e-9 then
        raise Exception.Create('values mismatch (CBOR)');
    end;
  end;
end;

procedure Bench;
var
  LBuffer: TMemoryStream;
  LStart, LStop: QWord;
  LIterations: Integer;
begin
  LBuffer := TMemoryStream.Create;
  try
    BuildTestPayload(LBuffer);

    LIterations := 20000;

    LStart := NowMs;
    RunDecodeCBOR(LBuffer, LIterations);
    LStop := NowMs;
    WriteLn('CBOR original: ', LStop - LStart, ' ms');

  finally
    LBuffer.Free;
  end;
end;

begin
  try
    Bench;
  except
    on E: Exception do
      WriteLn('Error: ', E.Message);
  end;
end.
