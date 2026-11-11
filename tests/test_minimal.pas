// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

program test_minimal;

{$MODE OBJFPC}{$H+}

uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required by the thread pool (see README)
  SysUtils, Classes, Types, Math,
  BaseMathPersistence, CBOR, CBORReadWrite;

type
  TAdjList = array of TIntegerDynArray;

  TGraphPersistence = class(TBaseMathPersistence)
  private
    FAdjList: TAdjList;
    FNumNodes: Integer;
    FName: String;
  public
    constructor Create;
    procedure DefineProps; override;
    procedure OnLoadBeginList(const Name: String; count: integer); override;
    procedure OnLoadListIntArr(const Value: TIntegerDynArray); override;
    procedure OnLoadEndList; override;
    procedure OnLoadStringProperty(const Name, Value: String); override;
    procedure OnLoadIntProperty(const Name: String; Value: Integer); override;
    function PropTypeOfName(const aName: string): TPropType; override;
    property AdjList: TAdjList read FAdjList;
    property NumNodes: Integer read FNumNodes;
    property Name: String read FName;
  end;

{ TGraphPersistence }

constructor TGraphPersistence.Create;
begin
  inherited Create;
  FName := '';
  FNumNodes := 0;
end;

procedure TGraphPersistence.DefineProps;
var
  i: Integer;
begin
  AddStringProperty('Name', FName);
  AddIntProperty('NumNodes', FNumNodes);
  BeginList('AdjList', Length(FAdjList));
  for i := 0 to High(FAdjList) do
    AddListIntArr(FAdjList[i]);
  EndList;
end;

procedure TGraphPersistence.OnLoadBeginList(const Name: String; count: integer);
begin
  if SameText(Name, 'AdjList') then
    SetLength(FAdjList, count);
end;

procedure TGraphPersistence.OnLoadListIntArr(const Value: TIntegerDynArray);
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

procedure TGraphPersistence.OnLoadEndList;
begin
  // NOP
end;

procedure TGraphPersistence.OnLoadStringProperty(const Name, Value: String);
begin
  if SameText(Name, 'Name') then
    FName := Value;
end;

procedure TGraphPersistence.OnLoadIntProperty(const Name: String; Value: Integer);
begin
  if SameText(Name, 'NumNodes') then
    FNumNodes := Value;
end;

function TGraphPersistence.PropTypeOfName(const aName: string): TPropType;
begin
  if SameText(aName, 'Name') then Exit(ptString);
  if SameText(aName, 'NumNodes') then Exit(ptInteger);
  if SameText(aName, 'AdjList') then Exit(ptList);
  Result := inherited PropTypeOfName(aName);
end;

var
  OriginalGraph, LoadedGraph: TGraphPersistence;
  Stream: TMemoryStream;
  CBORReader: TCBORReaderWriter;
begin
  RegisterMathIO(TGraphPersistence);
  OriginalGraph := TGraphPersistence.Create;
  CBORReader := TCBORReaderWriter.Create;
  Stream := TMemoryStream.Create;

  try
    OriginalGraph.FName := 'TestGraph';
    OriginalGraph.FNumNodes := 3;
    SetLength(OriginalGraph.FAdjList, 3);
    SetLength(OriginalGraph.FAdjList[0], 2);
    OriginalGraph.FAdjList[0][0] := 1;
    OriginalGraph.FAdjList[0][1] := 2;
    SetLength(OriginalGraph.FAdjList[1], 1);
    OriginalGraph.FAdjList[1][0] := 0;
    SetLength(OriginalGraph.FAdjList[2], 0); // Empty array

    OriginalGraph.SaveToStream(Stream, TCBORReaderWriter);
    WriteLn('Saved to stream');

    Stream.Position := 0;
    LoadedGraph := TGraphPersistence(CBORReader.LoadFromStream(Stream));
    WriteLn('Loaded from stream');

    if OriginalGraph.FName <> LoadedGraph.FName then
      raise Exception.Create('Name mismatch');
    if OriginalGraph.FNumNodes <> LoadedGraph.FNumNodes then
      raise Exception.Create('NumNodes mismatch');
    if Length(OriginalGraph.FAdjList) <> Length(LoadedGraph.FAdjList) then
      raise Exception.Create('AdjList length mismatch');
    if Length(OriginalGraph.FAdjList[0]) <> Length(LoadedGraph.FAdjList[0]) then
      raise Exception.Create('AdjList[0] length mismatch');
    if OriginalGraph.FAdjList[0][0] <> LoadedGraph.FAdjList[0][0] then
      raise Exception.Create('AdjList[0][0] mismatch');
    if OriginalGraph.FAdjList[0][1] <> LoadedGraph.FAdjList[0][1] then
      raise Exception.Create('AdjList[0][1] mismatch');
    if Length(OriginalGraph.FAdjList[1]) <> Length(LoadedGraph.FAdjList[1]) then
      raise Exception.Create('AdjList[1] length mismatch');
    if OriginalGraph.FAdjList[1][0] <> LoadedGraph.FAdjList[1][0] then
      raise Exception.Create('AdjList[1][0] mismatch');
    if Length(OriginalGraph.FAdjList[2]) <> Length(LoadedGraph.FAdjList[2]) then
      raise Exception.Create('AdjList[2] length mismatch');

    WriteLn('Verification successful!');

  finally
    OriginalGraph.Free;
    LoadedGraph.Free;
    CBORReader.Free;
    Stream.Free;
  end;
end.
