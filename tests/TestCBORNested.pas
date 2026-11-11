// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

unit TestCBORNested;

{$MODE OBJFPC}{$H+}

interface

uses
  Classes, SysUtils, Types, fpcunit, testutils, testregistry,
  BaseMathPersistence, CBORReadWrite, MathUtilFunc;

type
  TIntArrList = array of TIntegerDynArray;

  // A simple persistence class to hold our nested test data
  TNestedData = class(TBaseMathPersistence)
  private
    FAdjList: TIntArrList;
    FName: String;
  public
    constructor Create;
    class function ClassIdentifier : String; override;
    procedure DefineProps; override;
    function PropTypeOfName(const Name: string): TPropType; override;
    procedure OnLoadBeginList(const Name: String; count: integer); override;
    procedure OnLoadListIntArr(const Value: TIntegerDynArray); override;
    procedure OnLoadEndList; override;
    procedure OnLoadStringProperty(const Name, Value: String); override;
    property AdjList: TIntArrList read FAdjList;
    property Name: String read FName;
  end;

  // The test fixture
  TTestCBORNested = class(TTestCase)
  published
    procedure TestNestedArray;
  end;

implementation

{ TNestedData }

// the persistence layer resolves a serialised object through the class
// identifier, so it has to be stable and the class has to be registered
class function TNestedData.ClassIdentifier : String;
begin
  Result := 'NestedData';
end;

constructor TNestedData.Create;
begin
  inherited Create;
  FName := '';
end;

procedure TNestedData.DefineProps;
var
  i: Integer;
begin
  AddStringProperty('Name', FName);
  BeginList('AdjList', Length(FAdjList));
  for i := 0 to High(FAdjList) do
    AddListIntArr(FAdjList[i]);
  EndList;
end;

function TNestedData.PropTypeOfName(const Name: string): TPropType;
begin
  if SameText(Name, 'Name') then
    Exit(ptString);
  if SameText(Name, 'AdjList') then
    Exit(ptList);
  Result := inherited PropTypeOfName(Name);
end;

procedure TNestedData.OnLoadBeginList(const Name: String; count: integer);
begin
  if SameText(Name, 'AdjList') then
    SetLength(FAdjList, count);
end;

procedure TNestedData.OnLoadListIntArr(const Value: TIntegerDynArray);
var
  i: Integer;
begin
  // Find the next empty slot in FAdjList to place the array
  for i := 0 to High(FAdjList) do
  begin
    if not Assigned(FAdjList[i]) then
    begin
      FAdjList[i] := Value;
      Exit;
    end;
  end;
end;

procedure TNestedData.OnLoadEndList;
begin
end;

procedure TNestedData.OnLoadStringProperty(const Name, Value: String);
begin
  if SameText(Name, 'Name') then
    FName := Value;
end;

{ TTestCBORNested }

procedure TTestCBORNested.TestNestedArray;
var
  Reader: TCBORReaderWriter;
  Stream: TMemoryStream;
  OriginalData, LoadedData: TNestedData;
  i, j: Integer;
begin
  Stream := TMemoryStream.Create;
  Reader := TCBORReaderWriter.Create;
  OriginalData := TNestedData.Create;
  // the finally block frees this, so it must be defined even when loading raises
  LoadedData := nil;

  try
    OriginalData.FName := 'TestGraph';
    SetLength(OriginalData.FAdjList, 3);
    SetLength(OriginalData.FAdjList[0], 2);
    OriginalData.FAdjList[0][0] := 1;
    OriginalData.FAdjList[0][1] := 2;
    SetLength(OriginalData.FAdjList[1], 1);
    OriginalData.FAdjList[1][0] := 0;
    SetLength(OriginalData.FAdjList[2], 3);
    OriginalData.FAdjList[2][0] := 0;
    OriginalData.FAdjList[2][1] := 1;
    OriginalData.FAdjList[2][2] := 42;

    OriginalData.SaveToStream(Stream, TCBORReaderWriter);

    Stream.Position := 0;

    LoadedData := TNestedData(Reader.LoadFromStream(Stream));

    AssertEquals('Class name should match', OriginalData.ClassName, LoadedData.ClassName);
    AssertEquals('Name property should match', OriginalData.FName, LoadedData.FName);
    AssertEquals('AdjList should have correct length', Length(OriginalData.FAdjList), Length(LoadedData.FAdjList));

    for i := 0 to High(OriginalData.FAdjList) do
    begin
      AssertEquals(Format('Length of sub-array %d should match', [i]),
        Length(OriginalData.FAdjList[i]), Length(LoadedData.FAdjList[i]));
      for j := 0 to High(OriginalData.FAdjList[i]) do
      begin
        AssertEquals(Format('Value at [%d][%d] should match', [i, j]),
          OriginalData.FAdjList[i][j], LoadedData.FAdjList[i][j]);
      end;
    end;

  finally
    OriginalData.Free;
    LoadedData.Free;
    Reader.Free;
    Stream.Free;
  end;
end;

initialization
  RegisterMathIO(TNestedData);
  RegisterTest(TTestCBORNested);
end.
