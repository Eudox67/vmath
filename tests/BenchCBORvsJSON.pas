// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

program BenchCBORvsJSON;

{$MODE OBJFPC}{$H+}

uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required by the thread pool (see README)
  SysUtils, Classes, Types, Math, Matrix, MtxTimer,
  BaseMathPersistence, CBOR, CBORReadWrite, JSONReaderWriter;

type
  TAdjList = array of TIntegerDynArray;

  TGraphPersistence = class(TBaseMathPersistence)
  private
    FAdjList: TAdjList;
    FNumNodes: Integer;
    FName: String;
    FCurrentNodeIndex: Integer;
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
  FCurrentNodeIndex := 0;
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
  begin
    SetLength(FAdjList, count);
    FCurrentNodeIndex := 0;
    {$IFDEF DEBUG}
    Writeln(StdErr, 'Loading AdjList with ', count, ' nodes');
    {$ENDIF}
  end;
end;

procedure TGraphPersistence.OnLoadListIntArr(const Value: TIntegerDynArray);
begin
  if FCurrentNodeIndex < Length(FAdjList) then
  begin
    FAdjList[FCurrentNodeIndex] := Value;
    {$IFDEF DEBUG}
    Writeln(StdErr, '  Node ', FCurrentNodeIndex, ' has ', Length(Value), ' neighbors');
    {$ENDIF}
    Inc(FCurrentNodeIndex);
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

function GenerateRandomGraph(NumNodes, MaxDegree: Integer): TGraphPersistence;
var
  Graph: TGraphPersistence;
  i, k, neighbor: Integer;
  neighbors: TIntegerDynArray;
begin
  Graph := TGraphPersistence.Create;
  Graph.FNumNodes := NumNodes;
  Graph.FName := Format('RandomGraph_%d_%d', [NumNodes, MaxDegree]);
  SetLength(Graph.FAdjList, NumNodes);
  
  Randomize;  // Call ONCE, outside the loop
  
  for i := 0 to NumNodes - 1 do
  begin
    SetLength(neighbors, Random(MaxDegree) + 1);  // +1 ensures at least 1 neighbor
    for k := 0 to High(neighbors) do
    begin
      repeat
        neighbor := Random(NumNodes);
      until neighbor <> i;
      neighbors[k] := neighbor;
    end;
    Graph.FAdjList[i] := neighbors;
  end;
  Result := Graph;
end;

procedure Benchmark(const Description: String; NumNodes, MaxDegree, Iterations: Integer);
var
  OriginalGraph, LoadedGraph: TGraphPersistence;
  Stream: TMemoryStream;
  i: Integer;
  cborTime, jsonTime: Int64;
  cborSize, jsonSize: Int64;
  startTime, endTime: Int64;
  CBORReader: TCBORReaderWriter;
  JSONReader: TJSONReaderWriter;
begin
  WriteLn(Description);
  WriteLn('--------------------------------------------------');

  OriginalGraph := GenerateRandomGraph(NumNodes, MaxDegree);
  CBORReader := TCBORReaderWriter.Create;
  JSONReader := TJSONReaderWriter.Create;

  try
    // --- CBOR Benchmark ---
    Stream := TMemoryStream.Create;
    try
      startTime := MtxGetTime;
      for i := 1 to Iterations do
      begin
        Stream.Clear;
        OriginalGraph.SaveToStream(Stream, TCBORReaderWriter);
      end;
      endTime := MtxGetTime;
      cborTime := (endTime - startTime) div (mtxFreq div 1000);
      cborSize := Stream.Size;

      Stream.Position := 0;
      LoadedGraph := TGraphPersistence(TCBORReaderWriter.Create.LoadFromStream(Stream));
      LoadedGraph.Free;

      startTime := MtxGetTime;
      for i := 1 to Iterations do
      begin
        Stream.Position := 0;
        LoadedGraph := TGraphPersistence(CBORReader.LoadFromStream(Stream));
        LoadedGraph.Free;
      end;
      endTime := MtxGetTime;
      cborTime := cborTime + (endTime - startTime) div (mtxFreq div 1000);
    finally
      Stream.Free;
    end;

    // --- JSON Benchmark ---
    Stream := TMemoryStream.Create;
    try
      startTime := MtxGetTime;
      for i := 1 to Iterations do
      begin
        Stream.Clear;
        OriginalGraph.SaveToStream(Stream, TJSONReaderWriter);
      end;
      endTime := MtxGetTime;
      jsonTime := (endTime - startTime) div (mtxFreq div 1000);
      jsonSize := Stream.Size;

      Stream.Position := 0;
      LoadedGraph := TGraphPersistence(JSONReader.LoadFromStream(Stream));
      LoadedGraph.Free;

      startTime := MtxGetTime;
      for i := 1 to Iterations do
      begin
        Stream.Position := 0;
        LoadedGraph := TGraphPersistence(JSONReader.LoadFromStream(Stream));
        LoadedGraph.Free;
      end;
      endTime := MtxGetTime;
      jsonTime := jsonTime + (endTime - startTime) div (mtxFreq div 1000);
    finally
      Stream.Free;
    end;

  finally
    OriginalGraph.Free;
    CBORReader.Free;
    JSONReader.Free;
  end;

  WriteLn(Format('CBOR: %d ms (Size: %d bytes)', [cborTime, cborSize]));
  WriteLn(Format('JSON: %d ms (Size: %d bytes)', [jsonTime, jsonSize]));
  if (cborTime > 0) and (jsonTime > 0) then
    WriteLn(Format('CBOR is %.2fX faster than JSON', [jsonTime / cborTime]));
  WriteLn;
end;

begin
  RegisterMathIO(TGraphPersistence);

  Benchmark('Small Graph (100 nodes, avg degree 5)', 100, 5, 1000);
  Benchmark('Medium Graph (1000 nodes, avg degree 10)', 1000, 10, 100);
  Benchmark('Large Graph (10000 nodes, avg degree 20)', 10000, 20, 10);
end.
