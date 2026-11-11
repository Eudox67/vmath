// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

program test_cbor_readwrite;

{$MODE OBJFPC}{$H+}

uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required by the thread pool (see README)
  SysUtils, Classes, Types, BaseMathPersistence, CBORReadWrite, CBOR, Math;

type
  TDoubleDynArray = array of Double;
  TIntegerDynArray = array of Integer;
  TByteDynArray = array of Byte;
  
  TTestVector = class(TBaseMathPersistence)
  public
    Name: String;
    Value: Double;
    Count: Integer;
    Data: TDoubleDynArray;
    Tag: TByteDynArray;
  protected
    procedure DefineProps; override;
    procedure OnLoadStringProperty(const aName: String; const aValue: String); override;
    procedure OnLoadDoubleProperty(const aName: String; const aValue: double); override;
    procedure OnLoadIntProperty(const aName: String; aValue: LongInt); override;
    procedure OnLoadDoubleArr(const aName: String; const aValue: TDoubleDynArray); override;
    procedure OnLoadBinaryProperty(const aName: String; const aValue; asize: integer); override;
    function PropTypeOfName(const aName: string): TPropType; override;
  end;

  TAdjList = Array of TIntegerDynArray;

  TNestedData = class(TBaseMathPersistence)
  private
    FAdjList: TAdjList; //array of TIntegerDynArray;
    FName: String;
  public
    constructor Create;
    procedure DefineProps; override;
    procedure OnLoadBeginList(const Name: String; count: integer); override;
    procedure OnLoadListIntArr(const Value: TIntegerDynArray); override;
    procedure OnLoadEndList; override;
    procedure OnLoadStringProperty(const Name, Value: String); override;
    function PropTypeOfName(const aName: string): TPropType; override;
    function Equals(Other: TNestedData): Boolean;
    property AdjList: TAdjList read FAdjList;
    property Name: String read FName;
  end;

procedure TTestVector.DefineProps;
begin
  AddStringProperty('Name', Name);
  AddDoubleProperty('Value', Value);
  AddIntProperty('Count', Count);
  AddDoubleArr('Data', Data);
  AddBinaryProperty('Tag', Tag[0], Length(Tag));
end;

procedure TTestVector.OnLoadStringProperty(const aName: String; const aValue: String);
begin
  if aName = 'Name' then Self.Name := aValue
  else inherited;
end;

procedure TTestVector.OnLoadDoubleProperty(const aName: String; const aValue: double);
begin
  if aName = 'Value' then Self.Value := aValue
  else inherited;
end;

procedure TTestVector.OnLoadIntProperty(const aName: String; aValue: LongInt);
begin
  if aName = 'Count' then Self.Count := aValue
  else inherited;
end;

procedure TTestVector.OnLoadDoubleArr(const aName: String;

  const aValue: TDoubleDynArray);

var

  i: Integer;

begin
    if aName = 'Data' then
    begin
      SetLength(Self.Data, Length(aValue));
      if Length(aValue) > 0 then
        Move(aValue[0], Self.Data[0], Length(aValue) * SizeOf(Double));
    end
    else inherited;end;

procedure TTestVector.OnLoadBinaryProperty(const aName: String; const aValue; asize: integer);
var
  i: Integer;
  SrcPtr: Pointer;
begin
  if aName = 'Tag' then
  begin
    Writeln('DEBUG OnLoadBinaryProperty Tag size=', asize);SetLength(Self.Tag, asize);
    if asize > 0 then
    begin
      SrcPtr := @aValue;
      Writeln('DEBUG OnLoadBinaryProperty first byte=', IntToHex(Byte(SrcPtr^), 2));
      Move(SrcPtr^, Self.Tag[0], asize);
    end;
  end
  else inherited;
end;

function TTestVector.PropTypeOfName(const aName: string): TPropType;
begin
  if aName = 'Name' then Exit(ptString);
  if aName = 'Value' then Exit(ptDouble);
  if aName = 'Count' then Exit(ptInteger);
  if aName = 'Data' then Exit(ptDoubleArray);
  if aName = 'Tag' then Exit(ptBinary);
  Result := inherited PropTypeOfName(aName);
end;

{ TNestedData }

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

procedure TNestedData.OnLoadBeginList(const Name: String; count: integer);
begin
  if SameText(Name, 'AdjList') then
    SetLength(FAdjList, count);
end;

procedure TNestedData.OnLoadListIntArr(const Value: TIntegerDynArray);
var
  i: Integer;
begin
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
  // NOP
end;

procedure TNestedData.OnLoadStringProperty(const Name, Value: String);
begin
  if SameText(Name, 'Name') then
    FName := Value;
end;

function TNestedData.PropTypeOfName(const aName: string): TPropType;
begin
  if aName = 'Name' then Exit(ptString);
  if aName = 'AdjList' then Exit(ptList);
  Result := inherited PropTypeOfName(aName);
end;

function TNestedData.Equals(Other: TNestedData): Boolean;
var
  i, j: Integer;
begin
  Result := (Self.FName = Other.FName) and (Length(Self.FAdjList) = Length(Other.FAdjList));
  if not Result then Exit;

  for i := 0 to High(Self.FAdjList) do
  begin
    if Length(Self.FAdjList[i]) <> Length(Other.FAdjList[i]) then Exit(False);
    for j := 0 to High(Self.FAdjList[i]) do
      if Self.FAdjList[i][j] <> Other.FAdjList[i][j] then Exit(False);
  end;
  Result := True;
end;

function VectorsEqual(a, b: TTestVector): Boolean;
var i: Integer;
begin
  Result := (a.Name = b.Name) and
            (Abs(a.Value - b.Value) < 1e-12) and
            (a.Count = b.Count) and
            (Length(a.Data) = Length(b.Data)) and
            (Length(a.Tag) = Length(b.Tag));
  if not Result then Exit;

  for i := 0 to High(a.Data) do
    if Abs(a.Data[i] - b.Data[i]) > 1e-12 then
      Exit(False);
  for i := 0 to High(a.Tag) do
    if a.Tag[i] <> b.Tag[i] then
      Exit(False);
  Result := True;
end;

procedure TestSimpleVector;
var
  orig, loaded: TBaseMathPersistence;
  stream: TMemoryStream;
begin
  WriteLn('--- Running TestSimpleVector ---');
  orig := TTestVector.Create;
  try
    TTestVector(orig).Name := 'Embedding768';
    TTestVector(orig).Value := 3.141592653589793;
    TTestVector(orig).Count := 4;
    SetLength(TTestVector(orig).Data, 4);
    TTestVector(orig).Data[0] := 1.0; TTestVector(orig).Data[1] := -0.5;
    TTestVector(orig).Data[2] := 0.88; TTestVector(orig).Data[3] := 2.71828;
    SetLength(TTestVector(orig).Tag, 4);
    TTestVector(orig).Tag[0] := $CA; TTestVector(orig).Tag[1] := $FE;
    TTestVector(orig).Tag[2] := $BA; TTestVector(orig).Tag[3] := $BE;

    stream := TMemoryStream.Create;
    try
      orig.SaveToStream(stream, TCBORReaderWriter);
      WriteLn('[OK] Serialized to CBOR, size = ', stream.Size, ' bytes');

      stream.Position := 0;
      loaded := ReadObjFromStream(stream);
      if not Assigned(loaded) then
        raise Exception.Create('Failed to load object');

      if VectorsEqual(TTestVector(orig), TTestVector(loaded)) then
        WriteLn('[OK] Round-trip data matches')
      else
        raise Exception.Create('Data mismatch after round-trip');

      loaded.Free;
    finally
      stream.Free;
    end;
  finally
    orig.Free;
  end;
  WriteLn('[SUCCESS] TestSimpleVector passed!');
end;

procedure TestNestedList;
var
  orig, loaded: TNestedData;
  stream: TMemoryStream;
  i: Integer;
begin
  WriteLn('--- Running TestNestedList ---');
  orig := TNestedData.Create;
  try
    orig.FName := 'TestGraph';
    SetLength(orig.FAdjList, 3);
    SetLength(orig.FAdjList[0], 2);
    orig.FAdjList[0][0] := 1;
    orig.FAdjList[0][1] := 2;
    SetLength(orig.FAdjList[1], 1);
    orig.FAdjList[1][0] := 0;
    SetLength(orig.FAdjList[2], 3);
    orig.FAdjList[2][0] := 0;
    orig.FAdjList[2][1] := 1;
    orig.FAdjList[2][2] := 42;

    stream := TMemoryStream.Create;
    try
      orig.SaveToStream(stream, TCBORReaderWriter);
      WriteLn('[OK] Serialized nested list to CBOR, size = ', stream.Size, ' bytes');

      stream.Position := 0;
      loaded := TNestedData(ReadObjFromStream(stream));
      if not Assigned(loaded) then
        raise Exception.Create('Failed to load nested object');

      if orig.Equals(loaded) then
        WriteLn('[OK] Round-trip nested data matches')
      else
        raise Exception.Create('Nested data mismatch after round-trip');

      loaded.Free;
    finally
      stream.Free;
    end;
  finally
    orig.Free;
  end;
  WriteLn('[SUCCESS] TestNestedList passed!');
end;

// #########################################################

var
  b: Byte;
begin
  TCBORReaderWriter.ClassName;
  RegisterMathIO(TTestVector);
  RegisterMathIO(TNestedData);

  TestSimpleVector;
  TestNestedList;

  WriteLn('[ALL TESTS PASSED]');
end.
