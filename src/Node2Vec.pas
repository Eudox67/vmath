// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

unit Node2Vec;

{$MODE OBJFPC}{$H+}
{$MODESWITCH ADVANCEDRECORDS}

interface

uses
  SysUtils, Classes, Math, Types,
  Matrix, RandomEng, MtxUtilFunc, SimpleMatrixOperations, MatrixConst,
  JSONReaderWriter, CBORReadWrite,
   BaseMathPersistence;

type
  TAdjList = array of TIntegerDynArray;
  TGraph = record
    NumNodes: Integer;
    AdjList: TAdjList;
    procedure CreateEmpty(ANumNodes: Integer);
    procedure AddEdge(u, v: Integer);
    function Degree(node: Integer): Integer;
    procedure RemoveSelfLoops;
    function IsConnected: Boolean;
  end;

  TNode2VecParams = record
    WalkLength: Integer;
    NumWalks: Integer;
    Dim: Integer;
    Window: Integer;
    Epochs: Integer;
    LearningRate: Double;
    P: Double;
    Q: Double;
    NegSamples: Integer;
    procedure Init(ALen: Integer = 80; ANumWalks: Integer = 10;
      ADim: Integer = 128; AWindow: Integer = 10; AEpochs: Integer = 1;
      ALR: Double = 0.025; AP: Double = 1.0; AQ: Double = 1.0;
      ANeg: Integer = 5);
  end;
  
  TGraphPersistence = class(TBaseMathPersistence)
  private
    FGraph: TGraph;
    FCurrentNodeIndex: Integer;
  protected
    class function ClassIdentifier: String; override;
    procedure DefineProps; override;
    function PropTypeOfName(const Name: string): TPropType; override;
    procedure OnLoadIntProperty(const Name: String; Value: integer); override;
    procedure OnLoadBeginList(const Name: String; count: integer); override;
    procedure OnLoadListIntArr(const Value: TIntegerDynArray); override;
  public
    property Graph: TGraph read FGraph write FGraph;
    constructor Create(const AGraph: TGraph); overload;
    constructor Create; overload;
  end;  

  TAliasTable = record
    Alias: TIntegerDynArray;
    Prob: TDoubleDynArray;
  end;
  
  TEmbeddingFormat = (efCBOR, efJSON, efText);

  TWalks = TIntegerDynArray; // Flattened node sequences

  EN2VException = class(Exception);

function LoadGraphFromJSON(const FileName: String): TGraph;
function TrainNode2Vec(const Graph: TGraph; Params: TNode2VecParams; Rand: TRandomGenerator = nil): TDoubleMatrix;
procedure SaveEmbeddings(const Embeddings: TDoubleMatrix; const FileName: String); overload;
procedure SaveEmbeddings(const Embeddings: TDoubleMatrix; const FileName: String; Format: TEmbeddingFormat); overload;
procedure SaveEmbeddings(const Embeddings: TDoubleMatrix; const FileName: String; Format: TEmbeddingFormat; Prec: Integer); overload;
function LoadEmbeddings(const FileName: String): TDoubleMatrix;

procedure SaveGraphToCBOR(const Graph: TGraph; const FileName: String);
function LoadGraphFromCBOR(const FileName: String): TGraph;

// internal: alias method, sorted with MtxUtilFunc
// Internal: Alias method (using MtxUtilFunc for sorting)
procedure AliasSetup(Probs: TDoubleDynArray; out Alias: TIntegerDynArray; out Prob: TDoubleDynArray);
function AliasSample(Rand: TRandomGenerator; Alias: TIntegerDynArray; Prob: TDoubleDynArray): Integer;

var
  EmbedFormat : TEmbeddingFormat = efCBOR;

implementation

procedure TGraph.CreateEmpty(ANumNodes: Integer);
var
  i: Integer;
begin
  NumNodes := ANumNodes;
  SetLength(AdjList, NumNodes);
  for i := 0 to NumNodes - 1 do
    SetLength(AdjList[i], 0);
end;

procedure TGraph.AddEdge(u, v: Integer);
var
  idx: Integer;
begin
  if (u < 0) or (u >= NumNodes) or (v < 0) or (v >= NumNodes) or (u = v)
  then
    raise EN2VException.Create('Invalid or self-loop edge');
  idx := Length(AdjList[u]);
  SetLength(AdjList[u], idx + 1);
  AdjList[u][idx] := v;
  idx := Length(AdjList[v]);
  SetLength(AdjList[v], idx + 1);
  AdjList[v][idx] := u;
end;

function TGraph.Degree(node: Integer): Integer;
begin
  if (node < 0) or (node >= NumNodes) then
    raise EN2VException.Create('Invalid node');
  Result := Length(AdjList[node]);
end;

procedure TGraph.RemoveSelfLoops;
var
  i, j: Integer;
begin
  for i := 0 to NumNodes - 1 do
  begin
    j := 0;
    while j < Length(AdjList[i]) do
      if AdjList[i][j] = i then
      begin
        // Remove by swap and pop
        if j < High(AdjList[i]) then
          AdjList[i][j] := AdjList[i][High(AdjList[i])];
        SetLength(AdjList[i], High(AdjList[i]));
      end
      else
        Inc(j);
  end;
end;

function TGraph.IsConnected: Boolean;
var
  visited: TIntegerDynArray;
  stack: TIntegerDynArray;
  i, top: Integer;
begin
  SetLength(visited, NumNodes);
  FillChar(visited[0], SizeOf(visited[0]) * NumNodes, 0);
  SetLength(stack, NumNodes);
  top := 0;
  stack[0] := 0;
  visited[0] := 1;
  i := 0;
  while i < NumNodes do
  begin
    while top > 0 do
    begin
    end;
    Inc(i);
  end;
  // TODO: the loop above is a stub, connectivity is not really checked
  Result := True;
end;

procedure TNode2VecParams.Init(ALen: Integer = 80; ANumWalks: Integer = 10;
  ADim: Integer = 128; AWindow: Integer = 10; AEpochs: Integer = 1;
  ALR: Double = 0.025; AP: Double = 1.0; AQ: Double = 1.0;
  ANeg: Integer = 5);
begin
  if (AP <= 0) or (AQ <= 0) then
    raise EN2VException.Create('Node2Vec parameters P and Q must be positive.');
  Self.WalkLength := ALen;
  Self.NumWalks := ANumWalks;
  Self.Dim := ADim;
  Self.Window := AWindow;
  Self.Epochs := AEpochs;
  Self.LearningRate := ALR;
  Self.P := AP;
  Self.Q := AQ;
  Self.NegSamples := ANeg;
end;

{ TGraphPersistence }

class function TGraphPersistence.ClassIdentifier: String;
begin
  Result := 'GRF'; 
end;

constructor TGraphPersistence.Create(const AGraph: TGraph);
begin
  inherited Create;
  FGraph := AGraph;
end;

constructor TGraphPersistence.Create;
begin
  inherited Create;
  FGraph.CreateEmpty(0);
  FCurrentNodeIndex := -1;
end;

function TGraphPersistence.PropTypeOfName(const Name: string): TPropType;
begin
  if SameText(Name, 'NumNodes') then
    Result := ptInteger
  else
    Result := inherited PropTypeOfName(Name);
end;

procedure TGraphPersistence.DefineProps;
var
  i: Integer;
begin
  AddIntProperty('NumNodes', FGraph.NumNodes);
  BeginList('AdjList', FGraph.NumNodes);
  for i := 0 to FGraph.NumNodes - 1 do
  begin
    AddListIntArr(FGraph.AdjList[i]);
  end;
  EndList;
end;

procedure TGraphPersistence.OnLoadIntProperty(const Name: String; Value: integer);
begin
  if SameText(Name, 'NumNodes') then
    FGraph.CreateEmpty(Value);
end;

procedure TGraphPersistence.OnLoadBeginList(const Name: String; count: integer);
begin
  if SameText(Name, 'AdjList') then
  begin
    // The graph should already be created via NumNodes property
    if FGraph.NumNodes <> count then
      raise EN2VException.Create('Adjacency list count does not match NumNodes');
    SetLength(FGraph.AdjList, count);
    FCurrentNodeIndex := 0;
  end;
end;

procedure TGraphPersistence.OnLoadListIntArr(const Value: TIntegerDynArray);
begin
  if (FCurrentNodeIndex >= 0) and (FCurrentNodeIndex < FGraph.NumNodes) then
  begin
    FGraph.AdjList[FCurrentNodeIndex] := Value;
    Inc(FCurrentNodeIndex);
  end;
end;

function LoadGraphFromJSON(const FileName: String): TGraph;
var
  jsonStream: TFileStream;
  reader: TJsonReaderWriter;
  obj: TBaseMathPersistence;
  numNodes: Integer;
  edges: TIntegerDynArray;
  i, u, v: Integer;
begin
  Result.CreateEmpty(0);
  if not FileExists(FileName) then
    raise EN2VException.Create('JSON file not found: ' + FileName);
  jsonStream := TFileStream.Create(FileName, fmOpenRead);
  try
    reader := TJsonReaderWriter.Create;
    try
      obj := reader.LoadFromStream(jsonStream);
      if not Assigned(obj) then
        raise EN2VException.Create('Failed to parse JSON');

      // NumNodes is required: the edge list alone cannot size the graph
      numNodes := StrToIntDef(obj.PropGetAsString('NumNodes', '0'), 0);
      Result.CreateEmpty(numNodes);

      // only the flat "Edges" list (u,v,u,v,...) is read; a graph saved with
      // nested "AdjList" adjacency is not reconstructed here
      edges := obj.PropGetAsIntArray('Edges');
      i := 0;
      while i < Length(edges) do
      begin
        u := edges[i];
        if i + 1 < Length(edges) then
        begin
          v := edges[i + 1];
          Result.AddEdge(u, v);
        end;
        Inc(i, 2);
      end;

      Result.RemoveSelfLoops;
      if not Result.IsConnected then
        raise EN2VException.Create('Graph is disconnected');
    finally
      obj.Free;
      reader.Free;
    end;
  finally
    jsonStream.Free;
  end;
end;

procedure SaveGraphToCBOR(const Graph: TGraph; const FileName: String);
var
  graphPersist: TGraphPersistence;
begin
  graphPersist := TGraphPersistence.Create(Graph);
  try
    graphPersist.SaveToFile(FileName, TCBORReaderWriter);
  finally
    graphPersist.Free;
  end;
end;

function LoadGraphFromCBOR(const FileName: String): TGraph;
var
  obj: TBaseMathPersistence;
begin
  // ReadObjFromFile sniffs the format, so JSON files load here as well
  obj := ReadObjFromFile(FileName);
  if not (obj is TGraphPersistence) then
  begin
    obj.Free;
    raise EN2VException.Create('File does not contain a valid graph object.');
  end;
  try
    Result := TGraphPersistence(obj).Graph;
    // Detach the graph data from the persistence object before freeing it
    TGraphPersistence(obj).FGraph.AdjList := nil;
  finally
    obj.Free;
  end;
end;

procedure AppendToDynArray(var arr: TIntegerDynArray; val: Integer);
var
  len: Integer;
begin
  len := Length(arr);
  SetLength(arr, len + 1);
  arr[len] := val;
end;

function PopFromDynArray(var arr: TIntegerDynArray): Integer;
var
  len: Integer;
begin
  len := Length(arr);
  if len = 0 then
    raise Exception.Create('Cannot pop from an empty dynamic array.');
  Result := arr[len - 1];
  SetLength(arr, len - 1);
end;

procedure RemoveFromDynArray(var arr: TIntegerDynArray; index: Integer);
var
  i, len: Integer;
begin
  len := Length(arr);
  if (index < 0) or (index >= len) then
    Exit;
  for i := index to len - 2 do
    arr[i] := arr[i + 1];
  SetLength(arr, len - 1);
end;

procedure AliasSetup(Probs: TDoubleDynArray; out Alias: TIntegerDynArray;
  out Prob: TDoubleDynArray);
var
  n, i, g, l: Integer;
  sumProb: Double;
  small, large: TIntegerDynArray;
begin
  n := Length(Probs);
  SetLength(Alias, n);
  SetLength(Prob, n);

  // 1. Calculate sum and check for invalid input
  sumProb := 0;
  for i := 0 to n - 1 do
    sumProb := sumProb + Probs[i];

  if sumProb <= 0 then
    raise EN2VException.Create('Cannot create alias table for non-positive probabilities.');

  // 2. Create scaled probabilities and partition into small/large lists
  SetLength(small, 0);
  SetLength(large, 0);
  for i := 0 to n - 1 do
  begin
    Prob[i] := Probs[i] * n / sumProb;
    if Prob[i] < 1.0 then
      AppendToDynArray(small, i)
    else
      AppendToDynArray(large, i);
  end;

  // 3. Populate the alias table
  while (Length(small) > 0) and (Length(large) > 0) do
  begin
    l := PopFromDynArray(small);
    g := large[0];
    g := large[0]; // Peek

    Alias[l] := g;
    Prob[g] := (Prob[g] + Prob[l]) - 1.0; // Prob[g] -= (1.0 - Prob[l]);

    if Prob[g] < 1.0 then
    begin
      AppendToDynArray(small, g);
      RemoveFromDynArray(large, 0);
    end;
  end;

  // 4. Handle remaining items due to floating point inaccuracies
  while Length(large) > 0 do
  begin
    g := PopFromDynArray(large);
    Prob[g] := 1.0;
  end;

  while Length(small) > 0 do
  begin
    l := PopFromDynArray(small);
    Prob[l] := 1.0;
  end;
end;

function AliasSample(Rand: TRandomGenerator; Alias: TIntegerDynArray;
  Prob: TDoubleDynArray): Integer;
var
  n, col: Integer;
  r: Double;
begin
  n := Length(Prob);
  col := Rand.RandInt(n);
  r := Rand.Random;
  if r < Prob[col] then // Simplified from r * n < Prob[col] * n
    Result := col
  else
    Result := Alias[col];
end;

function GenerateBiasedWalks(const Graph: TGraph; Params: TNode2VecParams;
  Rand: TRandomGenerator): TWalks;
var
  totalLen: Integer;
  walks: TWalks;
  walkStart, node, walk, step, next: Integer;
  deg: Integer;
  transProbs: TDoubleDynArray;
  aliasRes: TAliasTable;
  neighbors: TIntegerDynArray;
  i, j, aliasIdx: Integer;
  weight: Double;
  isCommon: Boolean;
  currentNode: Integer;
  prevNode: Integer;
begin
  totalLen := Graph.NumNodes * Params.NumWalks * Params.WalkLength;
  SetLength(walks, totalLen);

  walkStart := 0;
  for node := 0 to Graph.NumNodes - 1 do
    for walk := 0 to Params.NumWalks - 1 do
    begin
      walks[walkStart] := node;
      for step := 1 to Params.WalkLength - 1 do
      begin
        currentNode := walks[walkStart + step - 1];
        if step = 1 then
          prevNode := -1
        else
          prevNode := walks[walkStart + step - 2];

        deg := Graph.Degree(currentNode);
        if deg = 0 then
          break;
        neighbors := Graph.AdjList[currentNode];

        SetLength(transProbs, deg);
        for i := 0 to deg - 1 do
        begin
          next := neighbors[i];
          if prevNode = -1 then
            weight := 1.0 // First step is uniform, normalization happens in AliasSetup
          else
          begin
            if next = prevNode then
              weight := 1.0 / Params.P
            else
            begin
              isCommon := False;
              for j := 0 to Graph.Degree(prevNode) - 1 do
                if Graph.AdjList[prevNode][j] = next then
                begin
                  isCommon := True;
                  break;
                end;
              if isCommon then
                weight := 1.0
              else
                weight := 1.0 / Params.Q;
            end;
          end;
          transProbs[i] := weight;
        end;

        AliasSetup(transProbs, aliasRes.Alias, aliasRes.Prob);
        aliasIdx := AliasSample(Rand, aliasRes.Alias, aliasRes.Prob);
        walks[walkStart + step] := neighbors[aliasIdx];
      end;
      Inc(walkStart, Params.WalkLength);
    end;

  SetLength(walks, walkStart);
  Result := walks;
end;

function Sigmoid(x: Double): Double;
begin
  if x < -30 then
    Result := 0.0
  else if x > 30 then
    Result := 1.0
  else
    Result := 1.0 / (1.0 + Exp(-x));
end;

function VecDot(u, v: PDouble; dim: Integer): Double;
begin
  Result := GenericVecDotMult(u, 1, v, 1, dim);
end;

function TrainNode2Vec(const Graph: TGraph; Params: TNode2VecParams;
  Rand: TRandomGenerator = nil): TDoubleMatrix;
var
  walks: TWalks;
  W, C, uRow, vRow, negRow, gradVec: TDoubleMatrix;
  unigramAlias: TAliasTable;
  i, epoch, pos, d, j, t, context, neg: Integer;
  lr, dotProd: Double;
  grad: Double;
  degrees: TDoubleDynArray;
  sumDegPow: Double;
  stdInit: Double;
  localRand: TRandomGenerator;
begin
  if (Graph.NumNodes = 0) or (Params.Dim <= 0) then
    raise EN2VException.Create('Invalid params or empty graph');

  if not Assigned(Rand) then
  begin
    localRand := TRandomGenerator.Create(raMersenneTwister);
    localRand.Init(42);
  end
  else
    localRand := Rand;

  walks := GenerateBiasedWalks(Graph, Params, localRand);

  // Degrees for unigram
  SetLength(degrees, Graph.NumNodes);
  sumDegPow := 0;
  for i := 0 to Graph.NumNodes - 1 do
  begin
    degrees[i] := Power(Graph.Degree(i), 0.75);
    sumDegPow := sumDegPow + degrees[i];
  end;
  
  if sumDegPow <= 0 then
    raise EN2VException.Create('Cannot train on a graph with no edges (all node degrees are zero).');
  
  for i := 0 to Graph.NumNodes - 1 do
    degrees[i] := degrees[i] / sumDegPow;
  AliasSetup(degrees, unigramAlias.Alias, unigramAlias.Prob);

  // Init embeddings: Uniform [-std, std] or Gaussian
  stdInit := 1.0 / Sqrt(Params.Dim);
  W := TDoubleMatrix.Create(Graph.NumNodes, Params.Dim);
  W.InitRandom(raMersenneTwister, 42);
  W.ScaleInPlace(stdInit * 2);
  W.AddInPlace(-stdInit); // [-std, std]
  C := TDoubleMatrix.Create(Graph.NumNodes, Params.Dim);
  C.InitRandom(raMersenneTwister, 43);
  C.ScaleInPlace(stdInit * 2);
  C.AddInPlace(-stdInit);

  gradVec := TDoubleMatrix.Create(1, Params.Dim);

  lr := Params.LearningRate;
  for epoch := 0 to Params.Epochs - 1 do
  begin
    lr := Params.LearningRate * (1 - (epoch / Params.Epochs));
    for pos := 0 to High(walks) do
    begin
      t := walks[pos];
      for d := Max(0, pos - Params.Window) to Min(High(walks), pos +
        Params.Window) do
      begin
        if d = pos then
          Continue;
        context := walks[d];

        uRow := W.SubRowMtx([t]);
        vRow := C.SubRowMtx([context]);

        dotProd := VecDot(uRow.StartElement, vRow.StartElement, Params.Dim);
        grad := lr * (1 - Sigmoid(dotProd));

        gradVec.Assign(uRow);
        gradVec.ScaleInPlace(grad);
        C.SetRow(context, vRow.Add(gradVec));

        gradVec.Assign(vRow);
        gradVec.ScaleInPlace(grad);
        W.SetRow(t, uRow.Add(gradVec));

        // Negatives
        for j := 1 to Params.NegSamples do
        begin
          neg := AliasSample(localRand, unigramAlias.Alias,
            unigramAlias.Prob);
          if (neg = t) or (neg = context) then
            Continue;

          negRow := C.SubRowMtx([neg]);
          dotProd := VecDot(uRow.StartElement, negRow.StartElement,
            Params.Dim);
          grad := lr * (0 - Sigmoid(dotProd));

          gradVec.Assign(uRow);
          gradVec.ScaleInPlace(grad);
          C.SetRow(neg, negRow.Add(gradVec));
        end;
      end;
    end;
  end;

  Result := W.Add(C);
  Result.ScaleInPlace(0.5);
  W.Free;
  C.Free;
  gradVec.Free;
  if not Assigned(Rand) then
    localRand.Free;
end;

procedure SaveEmbeddings(const Embeddings: TDoubleMatrix; const FileName: String); overload;
begin
  SaveEmbeddings(Embeddings, FileName, EmbedFormat, 8);
end;

procedure SaveEmbeddings(const Embeddings: TDoubleMatrix; const FileName: String; Format: TEmbeddingFormat); overload;
begin
  SaveEmbeddings(Embeddings, FileName, Format, 8);
end;

procedure SaveEmbeddings(const Embeddings: TDoubleMatrix; const FileName: String; Format: TEmbeddingFormat; Prec: Integer); overload;
var
  writerClass: TCustomMathPersistenceIOClass;
  f: TextFile;
  i, j: Integer;
begin
  case Format of
    efText:
    begin
      // Manual, human-readable plain text format
      AssignFile(f, FileName);
      Rewrite(f);
      try
        for i := 0 to Embeddings.Height - 1 do
        begin
          for j := 0 to Embeddings.Width - 1 do
            Write(f, Embeddings[j, i]:0:Prec, ' ');
          Writeln(f);
        end;
      finally
        CloseFile(f);
      end;
    end;

    efJSON, efCBOR:
    begin
      // Let the vmath persistence framework handle saving
      if Format = efJSON then
        writerClass := TJsonReaderWriter
      else
        writerClass := TCBORReaderWriter;

      // the matrix writes itself; only the writer class has to be chosen
      Embeddings.SaveToFile(FileName, writerClass);
    end;
  end;
end;

function LoadEmbeddings(const FileName: String): TDoubleMatrix;
var
  obj: TBaseMathPersistence;
begin
  if not FileExists(FileName) then
    raise EN2VException.Create('Embeddings file not found: ' + FileName);

  obj := ReadObjFromFile(FileName);

  if not Assigned(obj) then
    raise EN2VException.Create('Failed to read or identify object in file: ' + FileName);

  // Check that the file contained the correct type of object
  if not (obj is TDoubleMatrix) then
  begin
    obj.Free;
    raise EN2VException.Create('File does not contain a valid embeddings matrix.');
  end;

  // ownership moves to the caller; obj must not be freed here
  Result := TDoubleMatrix(obj);
end;

procedure Example;
var
  g: TGraph;
  params: TNode2VecParams;
  rand: TRandomGenerator;
  embeds: TDoubleMatrix;
begin
  Writeln('--- Starting Node2Vec Example ---');
  if FileExists('graph.json') then
    g := LoadGraphFromJSON('graph.json')
  else
  begin
    g.CreateEmpty(5);
    g.AddEdge(0, 1);
    g.AddEdge(1, 2);
    g.AddEdge(2, 3);
    g.AddEdge(3, 4);
    g.AddEdge(0, 4);
    g.RemoveSelfLoops;
  end;

  params.Init(40, 8, 64, 5, 3, 0.025, 0.25, 4.0, 15);
  rand := TRandomGenerator.Create(raMersenneTwister);
  try
    Writeln('Training Node2Vec model...');
    embeds := TrainNode2Vec(g, params, rand);
    try
      Writeln('Model trained. Now saving embeddings...');

      Writeln('  - Saving to embeddings.cbor using the default format (efCBOR)...');
      SaveEmbeddings(embeds, 'embeddings.cbor');

      Writeln('  - Changing the global default format to efJSON...');
      EmbedFormat := efJSON;
      Writeln('  - Saving to embeddings.json using the new default...');
      SaveEmbeddings(embeds, 'embeddings.json');

      Writeln('  - Saving to embeddings.txt by explicitly overriding the default...');
      SaveEmbeddings(embeds, 'embeddings.txt', efText);

      Writeln('All embeddings saved successfully.');

    finally
      embeds.Free;
    end;
  finally
    rand.Free;
  end;
  Writeln('--- Example Finished ---');
end;

initialization
  RegisterMathIO(TGraphPersistence);

end.
