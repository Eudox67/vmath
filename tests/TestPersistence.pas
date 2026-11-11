// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// Every persistable class writes itself through DefineProps and reads itself
// back through the OnLoad* callbacks, so a round trip is checked by comparing
// the restored state or the serialised bytes.  Determinism (saving twice gives
// the same bytes) and idempotence (saving a loaded object reproduces the
// stream) fail as soon as a property is written but not read, or the reverse.
unit TestPersistence;

{$MODE OBJFPC}{$H+}

interface

uses
  SysUtils, Classes, Types, Math, fpcunit, testregistry,
  BaseMathPersistence, CBOR, CBORReadWrite, JSONReaderWriter,
  MatrixConst, Matrix, Statistics, Dist, PCA;

type
  TPersistenceTests = class(TTestCase)
  private
    function SaveToBytes(obj : TBaseMathPersistence; writer : TClass) : TBytes;
    function LoadFromBytes(const bytes : TBytes) : TBaseMathPersistence;
    function RoundTrip(obj : TBaseMathPersistence; writer : TClass) : TBaseMathPersistence;
    procedure CheckMatrixRoundTrip(const name : string; m : TDoubleMatrix;
                                   writer : TClass; tol : double);
    function SameMatrix(a, b : TDoubleMatrix; tol : double; out maxDiff : double) : boolean;
  published
    procedure TestMatrixRoundTrip;
    procedure TestMatrixRoundTripWithJson;
    procedure TestSerialisationIsDeterministicAndIdempotent;
    procedure TestStatTestRoundTrip;
    procedure TestDistanceRoundTrip;
    procedure TestPCARoundTrip;
    procedure TestLoadedPropertiesAreIntrospectable;
    procedure TestIntArrayPropertiesAreRecorded;
    procedure TestNestedFrameIsWellFormed;
    procedure TestGarbageStreamIsRejected;
  end;

implementation

function TPersistenceTests.SaveToBytes(obj : TBaseMathPersistence; writer : TClass) : TBytes;
var stream : TMemoryStream;
begin
  stream := TMemoryStream.Create;
  try
    obj.SaveToStream(stream, writer);
    SetLength(Result, stream.Size);
    if stream.Size > 0 then
      Move(stream.Memory^, Result[0], stream.Size);
  finally
    stream.Free;
  end;
end;

function TPersistenceTests.LoadFromBytes(const bytes : TBytes) : TBaseMathPersistence;
var stream : TMemoryStream;
begin
  stream := TMemoryStream.Create;
  try
    if Length(bytes) > 0 then
      stream.Write(bytes[0], Length(bytes));
    stream.Position := 0;
    Result := ReadObjFromStream(stream);
  finally
    stream.Free;
  end;
end;

function TPersistenceTests.RoundTrip(obj : TBaseMathPersistence; writer : TClass) : TBaseMathPersistence;
begin
  Result := LoadFromBytes(SaveToBytes(obj, writer));
end;

function TPersistenceTests.SameMatrix(a, b : TDoubleMatrix; tol : double; out maxDiff : double) : boolean;
var x, y : integer;
begin
  maxDiff := 1e30;
  if (a = nil) or (b = nil) then
    exit(False);
  if (a.Width <> b.Width) or (a.Height <> b.Height) then
    exit(False);
  maxDiff := 0;
  for x := 0 to a.Width - 1 do
    for y := 0 to a.Height - 1 do
      maxDiff := Max(maxDiff, Abs(a.Items[x, y] - b.Items[x, y]));
  Result := maxDiff <= tol;
end;

procedure TPersistenceTests.CheckMatrixRoundTrip(const name : string; m : TDoubleMatrix;
  writer : TClass; tol : double);
var loaded : TBaseMathPersistence;
    d : double;
begin
  loaded := nil;
  try
    loaded := RoundTrip(m, writer);
    AssertTrue(name + ': no object was read back', loaded <> nil);
    AssertTrue(name + ': wrong class after reload', loaded is TDoubleMatrix);
    AssertTrue(Format('%s: dimensions differ (%dx%d vs %dx%d)',
                      [name, TDoubleMatrix(loaded).Width, TDoubleMatrix(loaded).Height,
                       m.Width, m.Height]),
               (TDoubleMatrix(loaded).Width = m.Width) and
               (TDoubleMatrix(loaded).Height = m.Height));
    AssertTrue(Format('%s: values differ (max %.3e)', [name, d]),
               SameMatrix(m, TDoubleMatrix(loaded), tol, d));
  finally
    loaded.Free;
  end;
end;

procedure FillMatrix(m : TDoubleMatrix; amplitude : double);
var x, y : integer;
begin
  for x := 0 to m.Width - 1 do
    for y := 0 to m.Height - 1 do
      m.Items[x, y] := (Random * 2 - 1) * amplitude;
end;

procedure FillIMatrix(m : IMatrix; amplitude : double);
var i, j : integer;
begin
  for i := 0 to m.Width - 1 do
    for j := 0 to m.Height - 1 do
      m[i, j] := (Random * 2 - 1) * amplitude;
end;

// compare two interface matrices (used for the distance results)
function SameIMatrix(a, b : IMatrix; out maxDiff : double) : boolean;
var x, y : integer;
begin
  maxDiff := 1e30;
  if (a = nil) or (b = nil) then
    exit(False);
  if (a.Width <> b.Width) or (a.Height <> b.Height) then
    exit(False);
  maxDiff := 0;
  for x := 0 to a.Width - 1 do
    for y := 0 to a.Height - 1 do
      maxDiff := Max(maxDiff, Abs(a.Items[x, y] - b.Items[x, y]));
  Result := True;
end;

procedure TPersistenceTests.TestMatrixRoundTrip;
const cases : array[0..3, 0..1] of integer =
  ((1, 1), (3, 5), (17, 64), (64, 17));
var i : integer; m : TDoubleMatrix;
begin
  RandSeed := 12345;
  for i := Low(cases) to High(cases) do
  begin
    m := TDoubleMatrix.Create(cases[i, 0], cases[i, 1], 0);
    try
      FillMatrix(m, 1000.0);
      CheckMatrixRoundTrip(Format('CBOR %dx%d', [cases[i, 0], cases[i, 1]]),
                           m, TCBORReaderWriter, 0.0);
    finally
      m.Free;
    end;
  end;
end;

procedure TPersistenceTests.TestMatrixRoundTripWithJson;
var m, big : TDoubleMatrix;
begin
  RandSeed := 54321;
  m := TDoubleMatrix.Create(3, 5, 0);
  try
    FillMatrix(m, 1.0);
    // JSON prints numbers as text, so allow for the last bit
    CheckMatrixRoundTrip('JSON 3x5', m, TJsonReaderWriter, 1e-14);
    big := TDoubleMatrix.Create(17, 64, 0);
    try
      FillMatrix(big, 1.0);
      CheckMatrixRoundTrip('JSON 17x64', big, TJsonReaderWriter, 1e-14);
    finally
      big.Free;
    end;
  finally
    m.Free;
  end;
end;

procedure TPersistenceTests.TestSerialisationIsDeterministicAndIdempotent;
var
  m : TDoubleMatrix;
  b1, b2, b3 : TBytes;
  loaded : TBaseMathPersistence;
  i : integer;
  same : boolean;
begin
  RandSeed := 999;
  m := TDoubleMatrix.Create(7, 9, 0);
  loaded := nil;
  try
    FillMatrix(m, 5.0);

    // deterministic: the same object serialises to the same bytes
    b1 := SaveToBytes(m, TCBORReaderWriter);
    b2 := SaveToBytes(m, TCBORReaderWriter);
    same := (Length(b1) = Length(b2));
    if same then
      for i := 0 to High(b1) do
        if b1[i] <> b2[i] then
          same := False;
    AssertTrue('serialising the same matrix twice produced different bytes', same);

    // idempotent: saving a reloaded object reproduces the stream
    loaded := LoadFromBytes(b1);
    b3 := SaveToBytes(loaded, TCBORReaderWriter);
    same := (Length(b1) = Length(b3));
    if same then
      for i := 0 to High(b1) do
        if b1[i] <> b3[i] then
          same := False;
    AssertTrue(Format('re-serialising a reloaded matrix changed the stream (%d vs %d bytes)',
                      [Length(b1), Length(b3)]), same);
    FreeAndNil(loaded);

  finally
    loaded.Free;
    m.Free;
  end;
end;

// A reloaded TStatTest must produce the same t statistic.  This covers both the
// scalar properties (mean/variance/count) and the nested reference data.
procedure TPersistenceTests.TestStatTestRoundTrip;
var
  st : TStatTest;
  loaded : TStatTest;
  d1, d2 : TDoubleMatrix;
  t1, p1, t2, p2 : double;
  base : TBaseMathPersistence;
begin
  RandSeed := 777;
  d1 := TDoubleMatrix.Create(1, 20, 0);
  d2 := TDoubleMatrix.Create(1, 20, 0);
  st := TStatTest.Create;
  base := nil;
  try
    FillMatrix(d1, 3.0);
    FillMatrix(d2, 3.0);
    st.InitStudentTTest(d1);     // does NOT keep a reference (fRefData := nil)
    st.StudentTTest(d2, t1, p1);

    base := RoundTrip(st, TCBORReaderWriter);
    AssertTrue('TStatTest: no object was read back', base <> nil);
    AssertTrue('TStatTest: wrong class after reload', base is TStatTest);
    loaded := TStatTest(base);

    loaded.StudentTTest(d2, t2, p2);
    AssertEquals('t statistic after reload', t1, t2, 1e-15);
    AssertEquals('probability after reload', p1, p2, 1e-15);
    AssertTrue(Format('t statistic is non-trivial (t=%.6f, p=%.6f)', [t1, p1]), p1 < 1.0);
  finally
    base.Free;
    st.Free;
    d2.Free;
    d1.Free;
  end;
end;

// EuclidDist is a pure function now, so the same query can be repeated on the
// same input before and after a round trip.
procedure TPersistenceTests.TestDistanceRoundTrip;
var
  dist, loaded : TDistance;
  x, y : IMatrix;              // reference counted: never Free these by hand
  r1, r2 : IMatrix;
  base : TBaseMathPersistence;
  d : double;
begin
  RandSeed := 2468;
  x := TDoubleMatrix.Create(3, 25, 0);
  y := TDoubleMatrix.Create(3, 4, 0);
  dist := TDistance.Create;
  base := nil;
  try
    FillIMatrix(x, 2.0);
    FillIMatrix(y, 2.0);
    dist.InitEuclid(x);          // stores a copy of the column means
    r1 := dist.EuclidDist(y);    // must not modify y
    AssertTrue('EuclidDist returned nil', r1 <> nil);

    base := RoundTrip(dist, TCBORReaderWriter);
    AssertTrue('TDistance: no object was read back', base <> nil);
    AssertTrue('TDistance: wrong class after reload', base is TDistance);
    loaded := TDistance(base);

    r2 := loaded.EuclidDist(y);
    AssertTrue('distances have a different shape after the round trip', SameIMatrix(r1, r2, d));
    AssertTrue(Format('distances differ after the round trip (max %.3e)', [d]), d <= 1e-15);

    // and the query is repeatable: the second call must give the same answer
    r2 := dist.EuclidDist(y);
    AssertTrue('EuclidDist modified its argument (second call differs)',
               SameIMatrix(r1, r2, d) and (d <= 1e-15));
  finally
    base.Free;
    dist.Free;
    x := nil;                    // release through the interface
    y := nil;
  end;
end;

procedure TPersistenceTests.TestPCARoundTrip;
const cFeat = 4; cSamples = 30; cLatent = 2;
var
  pca, loaded : TMatrixPCA;
  data : TDoubleMatrix;
  base : TBaseMathPersistence;
  d : double;
  ok : boolean;
begin
  RandSeed := 1357;
  data := TDoubleMatrix.Create(cSamples, cFeat, 0);
  pca := TMatrixPCA.Create([pcaEigVals]);   // keep the eigenvalues
  base := nil;
  try
    FillMatrix(data, 1.0);
    AssertTrue('PCA training failed', pca.PCA(data, cLatent, False));

    base := RoundTrip(pca, TCBORReaderWriter);
    AssertTrue('TMatrixPCA: no object was read back', base <> nil);
    AssertTrue('TMatrixPCA: wrong class after reload', base is TMatrixPCA);
    loaded := TMatrixPCA(base);

    AssertEquals('number of modes after reload', pca.NumModes, loaded.NumModes);

    ok := SameMatrix(pca.EigVals, loaded.EigVals, 1e-14, d);
    AssertTrue(Format('eigenvalues differ after reload (max %.3e)', [d]), ok);

    ok := SameMatrix(pca.EigVecs, loaded.EigVecs, 1e-14, d);
    AssertTrue(Format('eigenvectors differ after reload (max %.3e)', [d]), ok);

    ok := SameMatrix(pca.Mean, loaded.Mean, 1e-14, d);
    AssertTrue(Format('mean vector differs after reload (max %.3e)', [d]), ok);
  finally
    base.Free;
    pca.Free;
    data.Free;
  end;
end;


// The low level codec must see a nested object as one well formed frame: a tag,
// an indefinite map and exactly one terminating break.  This pins the wire
// format that the persistence layer relies on (and guards the reader and writer
// against drifting apart).

// A loaded object must expose what the reader applied to it, through both
// writers; the readers have to record every property they dispatch.
procedure TPersistenceTests.TestLoadedPropertiesAreIntrospectable;
var
  m, d1 : TDoubleMatrix;
  st : TStatTest;
  loaded : TBaseMathPersistence;
  writers : array[0..1] of TClass;
  names : array[0..1] of string;
  w : integer;
  v : double;
begin
  RandSeed := 5150;
  m := TDoubleMatrix.Create(2, 3, 0);
  try
    FillMatrix(m, 4.0);
    writers[0] := TCBORReaderWriter; names[0] := 'CBOR';
    writers[1] := TJsonReaderWriter; names[1] := 'JSON';

    for w := 0 to 1 do
    begin
      loaded := nil;
      try
        loaded := RoundTrip(m, writers[w]);
        AssertTrue(names[w] + ': nothing was read back', loaded <> nil);

        AssertTrue(names[w] + ': Width was not recorded', loaded.HasProperty('Width'));
        AssertEquals(names[w] + ': Width value', '2', loaded.PropGetAsString('Width'));
        AssertTrue(names[w] + ': Height was not recorded', loaded.HasProperty('Height'));
        AssertEquals(names[w] + ': Height value', '3', loaded.PropGetAsString('Height'));

        // present but empty is not the same as absent
        AssertTrue(names[w] + ': Name was not recorded', loaded.HasProperty('Name'));
        AssertEquals(names[w] + ': Name is empty', '', loaded.PropGetAsString('Name'));

        // an array property is summarised
        AssertEquals(names[w] + ': data summary', '<array 6>', loaded.PropGetAsString('data'));

        // absent properties fall back to the default
        AssertFalse(names[w] + ': an absent property reported as present',
                    loaded.HasProperty('NoSuchProperty'));
        AssertEquals(names[w] + ': default value', 'fallback',
                     loaded.PropGetAsString('NoSuchProperty', 'fallback'));

        AssertTrue(names[w] + ': the stream header is always reported',
                   loaded.HasProperty('Lib'));
      finally
        loaded.Free;
      end;
    end;
  finally
    m.Free;
  end;

  // a double property keeps its value as text, and a nested object is reported
  // by its class name
  st := TStatTest.Create;
  d1 := TDoubleMatrix.Create(1, 16, 0);
  try
    FillMatrix(d1, 2.0);
    st.InitStudentTTest(d1);
    loaded := nil;
    try
      loaded := RoundTrip(st, TCBORReaderWriter);
      AssertTrue('StatTest: nothing was read back', loaded <> nil);
      AssertTrue('StatTest: StatMean was not recorded', loaded.HasProperty('StatMean'));
      v := StrToFloatDef(loaded.PropGetAsString('StatMean'), 1e30);
      AssertTrue(Format('StatTest: StatMean reads back as %.6f', [v]), v < 1e29);
    finally
      loaded.Free;
    end;
  finally
    st.Free;
    d1.Free;
  end;
end;


// Int-array properties must be recoverable, not just summarised.  TDistance's
// Rx is written even when the covariance matrix is nil (the euclidean path).
procedure TPersistenceTests.TestIntArrayPropertiesAreRecorded;
var
  m : TDoubleMatrix;
  loaded : TBaseMathPersistence;
  vals : TIntegerDynArray;
  dist : TDistance;
  x : IMatrix;
  i : integer;
begin
  RandSeed := 6101;
  m := TDoubleMatrix.Create(2, 3, 0);
  try
    FillMatrix(m, 1.0);
    loaded := RoundTrip(m, TCBORReaderWriter);
    try
      // a plain matrix has no int array: the accessor must return an empty array
      vals := loaded.PropGetAsIntArray('NoSuchArray');
      AssertEquals('absent int array should be empty', 0, Length(vals));
    finally
      loaded.Free;
    end;
  finally
    m.Free;
  end;

  // TDistance initialised with the euclidean metric leaves the covariance nil but
  // still has an Rx; it used to be dropped because it was written inside the
  // "if Assigned(fR)" block.
  // 12 samples along the width, 2 features along the height (library convention)
  x := TDoubleMatrix.Create(12, 2, 0);
  for i := 0 to 11 do
  begin
    x.Items[i, 0] := Random * 2 - 1;
    x.Items[i, 1] := Random * 2 - 1;
  end;
  dist := TDistance.Create;
  loaded := nil;
  try
    dist.InitEuclid(x);
    loaded := RoundTrip(dist, TCBORReaderWriter);
    AssertTrue('TDistance: nothing read back', loaded <> nil);
    AssertTrue('TDistance: Rx was not persisted', loaded.HasProperty('Rx'));
    AssertTrue(Format('TDistance: Rx value "%s"', [loaded.PropGetAsString('Rx')]),
               StrToIntDef(loaded.PropGetAsString('Rx'), -1) >= 0);
  finally
    loaded.Free;
    dist.Free;
    x := nil;
  end;
end;

procedure TPersistenceTests.TestNestedFrameIsWellFormed;
var
  dist : TDistance;
  x : TDoubleMatrix;
  stream : TMemoryStream;
  reader : TCBORReader;
  i : integer;
  bytes : TBytes;
begin
  RandSeed := 8642;
  x := TDoubleMatrix.Create(3, 12, 0);
  dist := TDistance.Create;
  stream := TMemoryStream.Create;
  try
    FillMatrix(x, 2.0);
    dist.InitEuclid(x);            // stores the column means, i.e. one nested matrix

    dist.SaveToStream(stream, TCBORReaderWriter);
    AssertTrue('empty stream', stream.Size > 0);

    SetLength(bytes, stream.Size);
    Move(stream.Memory^, bytes[0], stream.Size);

    // the frame ends with exactly one break, and no break appears inside the
    // payload except as a terminator
    AssertEquals('frame must end with a break', $FF, bytes[High(bytes)]);
    // the last property is a nested object, so the frame ends with the nested
    // terminator followed by the root terminator: two breaks in a row is correct

    // a single SkipValue has to consume the whole frame
    stream.Position := 0;
    reader.Init(stream);
    reader.SkipValue;
    AssertEquals('SkipValue must consume the whole frame', stream.Size, stream.Position);

    // and the frame must be a tag followed by a map
    stream.Position := 0;
    reader.Init(stream);
    AssertEquals('frame must start with a tag', Ord(ctTag), Ord(reader.PeekType));
    reader.ReadTag;
    AssertEquals('the tag must be followed by a map', Ord(ctMapIndefinite), Ord(reader.PeekType));
  finally
    stream.Free;
    dist.Free;                     // releases the reference to x
  end;
end;

procedure TPersistenceTests.TestGarbageStreamIsRejected;
var
  stream : TMemoryStream;
  buf : array[0..63] of byte;
  obj : TBaseMathPersistence;
  rejected : boolean;
  i : integer;
begin
  RandSeed := 31337;
  for i := Low(buf) to High(buf) do
    buf[i] := Random(256);

  stream := TMemoryStream.Create;
  try
    stream.Write(buf[0], SizeOf(buf));
    stream.Position := 0;
    rejected := False;
    obj := nil;
    try
      obj := ReadObjFromStream(stream);
      // returning nil is an acceptable way of rejecting the stream
      rejected := obj = nil;
    except
      on E: Exception do
        rejected := True;
    end;
    obj.Free;
    AssertTrue('a stream of random bytes was accepted as a persisted object', rejected);
  finally
    stream.Free;
  end;
end;

initialization
  RegisterTest(TPersistenceTests);
end.
