// ###################################################################
// #### This file is part of the vmath project - a 64-bit, double-
// #### precision (mode objfpc) fork of mrMath:
// ####   https://github.com/mikerabat/mrmath
// ####
// #### Derived from mrMath. Copyright (c) 2011-2024, Michael R.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ####
// #### vmath is an independent fork and is not affiliated with,
// #### endorsed by, or supported by the mrMath project or its author.
// ###################################################################


unit BaseMathPersistence;

// ###################################################
// #### Base abstract I/O functionality
// ###################################################

interface

{$mode objfpc}{$H+}  
{$interfaces default}  

uses SysUtils, Classes, Types, LightStrings;

// #############################################################
// #### Loading/saving data
type
  TCustomMathPersistenceIO = class;
  TCustomMathPersistenceIOClass = TClass;  // stands in for "class of TCustomMathPersistenceIO"

  IMathPersistence = interface
    ['{16A5F1D0-CA39-4BD0-BABE-E1E70B0045C3}']
    procedure SaveToFile(const FileName : string; WriterClass : TClass);
    procedure SaveToStream(stream : TStream; WriterClass : TClass);
  end;

  TPropType = (ptUnknown, ptDouble, ptInteger, ptString, ptObject, ptBinary, ptList, ptIntArray, ptDoubleArray);

  // a reader's copy of an int-array property, kept until the object is freed
  TIntArrayEntry = record
    Name : string;
    Values : TIntegerDynArray;
  end;

  TBaseMathPersistence = class(TInterfacedObject, IMathPersistence)
  private
    fWriter : TCustomMathPersistenceIO;
    fInList : boolean;
    // TStrList is a stack record: no allocation, no cleanup code
    fLoadedProps : TStrList;
    fIntArrays : array of TIntArrayEntry;
    function IntArrayIndex(const Name : String) : integer;
  protected
    // functions to add and load properties
    procedure BeginList(const Name : String; count : integer);
    procedure EndList;
    procedure AddObjectDescription(const Name : String; const Value : String);
    procedure AddDoubleProperty(const Name : String; const Value : double);
    procedure AddStringProperty(const Name : String; const Value : String);
    procedure AddIntProperty(const Name : String; const Value : integer);
    procedure AddBinaryProperty(const Name : String; const Value; size : integer);
    procedure AddDoubleArr(const Name : String; const Value : TDoubleDynArray);
    procedure AddListDoubleArr(const Value : TDoubleDynArray);
    procedure AddIntArr(const Name : String; const Value : TIntegerDynArray);
    procedure AddListIntArr(const Value : TIntegerDynArray);
    procedure AddObject(Obj : TBaseMathPersistence); overload;
    procedure AddObject(const Name : String; obj : TBaseMathPersistence); overload;
  protected
    procedure FinishReading; virtual;
    procedure OnLoadDoubleProperty(const Name : String; const Value : double); virtual;
    procedure OnLoadStringProperty(const Name : String; const Value : String); virtual;
    procedure OnLoadIntProperty(const Name : String; Value : integer); virtual;
    procedure OnLoadBinaryProperty(const Name : String; const Value; size : integer); virtual;
    function OnLoadObject(Obj : TBaseMathPersistence) : boolean; overload; virtual;
    function OnLoadObject(const Name : String; Obj : TBaseMathPersistence) : boolean; overload; virtual;
    procedure OnLoadBeginList(const Name : String; count : integer); virtual;
    procedure OnLoadEndList; virtual;
    procedure OnLoadDoubleArr(const Name : String; const Value : TDoubleDynArray); virtual;
    procedure OnLoadIntArr(const Name : String; const Value : TIntegerDynArray); virtual;
    procedure OnLoadListDoubleArr(const Value : TDoubleDynArray); virtual;
    procedure OnLoadListIntArr(const Value : TIntegerDynArray); virtual;

    procedure InitWriter(Writer : TCustomMathPersistenceIO);
    class function ClassIdentifier : String; virtual;
    procedure DefineProps; virtual; abstract;
    function PropTypeOfName(const Name : string) : TPropType; virtual;
	procedure CleanupWriter;
  public
    // what the readers applied while loading, so PropGetAsString and
    // HasProperty work for every class without extra code
    procedure RecordProp(const Name, Value : String); overload;
    procedure RecordProp(const Name : String; Value : Int64); overload;
    procedure RecordProp(const Name : String; const Value : double); overload;
    procedure RecordPropObject(const Name : String; Obj : TBaseMathPersistence);
    procedure RecordPropSummary(const Name, Kind : String; Count : integer);
    procedure RecordIntArray(const Name : String; const Values : TIntegerDynArray);
    procedure ResetLoadedProps;
    function PropGetAsString(const Name: String; const Default: String = ''): String; virtual;
	function HasProperty(const Name: String): Boolean; virtual;
	function PropGetAsIntArray(const Name: String): TIntegerDynArray; virtual;    
    procedure SaveToFile(const FileName : string; WriterClass : TClass);  
    procedure SaveToStream(stream : TStream; WriterClass : TClass);  
  end;
  TBaseMathPersistenceClass = TClass;  

// ###################################################
// #### Base IO functionality
  TCustomMathPersistenceIO = class(TObject)
  private
    fStream : TStream;
  protected
    property Stream : TStream read fStream;

    class function CanReadStream(aStream : TStream) : boolean; virtual; abstract;

    function PropTypeOfName(readObj : TBaseMathPersistence; const Name : string) : TPropType;

    // ###########################################################
    // #### Reading routines - these call the onLoad xx routines
    procedure ReadDoubleProperty(readObj : TBaseMathPersistence; const Name : String; const Value : double);
    procedure ReadStringProperty(readObj : TBaseMathPersistence; const Name : String; const Value : String);
    procedure ReadIntProperty(readObj : TBaseMathPersistence; const Name : String; Value : integer);
    procedure ReadBinaryProperty(readObj : TBaseMathPersistence; const Name : String; const Value; size : integer);
    function ReadObject(readObj : TBaseMathPersistence; Obj : TBaseMathPersistence) : boolean; overload;
    function ReadObject(readObj : TBaseMathPersistence; const Name : String; Obj : TBaseMathPersistence) : boolean; overload;
    procedure ReadBeginList(readObj : TBaseMathPersistence; const Name : String; count : integer);
    procedure ReadEndList(readObj : TBaseMathPersistence);
    procedure ReadDoubleArr(readObj : TBaseMathPersistence; const Name : String; const Value : TDoubleDynArray);
    procedure ReadIntArr(readObj : TBaseMathPersistence; const Name : String; const Value : TIntegerDynArray);
    procedure ReadListDoubleArr(readObj : TBaseMathPersistence; const Value : TDoubleDynArray);
    procedure ReadListIntArr(readObj : TBaseMathPersistence; const Value : TIntegerDynArray);

    procedure ReadFinalize(readObj : TBaseMathPersistence);

    // ###########################################################
    // #### Writing routines - called from the TBaseMathPersistence objects
    procedure WriteStreamHeader; virtual; abstract;
    procedure FinalizeStream; virtual; abstract;

    procedure WriteVersion(ver : integer); virtual;
    procedure WriteObjDescriptor(const Name : String; const Value : String); virtual; abstract;
    procedure WriteListBegin(const Name : String; count : integer); virtual; abstract;
    procedure WriteListEnd; virtual; abstract;
    procedure WriteProperty(const Name : String; const Value : double); overload; virtual; abstract;
    procedure WriteProperty(const Name : String; const Value : String); overload; virtual; abstract;
    procedure WriteProperty(const Name : String; const Value : integer); overload; virtual; abstract;
    procedure WriteDoubleArr(const Name : String; const Value : Array of double); virtual; abstract;
    procedure WriteListDoubleArr(const Value : Array of double); virtual; abstract;
    procedure WriteIntArr(const Name : String; const Value : Array of Integer); virtual; abstract;
    procedure WriteListIntArr(const Value : Array of Integer); virtual; abstract;
    procedure WriteBinaryProperty(const Name : String; const Value; size : integer); virtual; abstract;
    procedure WriteObject(Obj : TBaseMathPersistence); overload; virtual; abstract;
    procedure WriteObject(const Name : String; Obj : TBaseMathPersistence); overload; virtual; abstract;
  public
    function LoadFromFile(const FileName : string) : TBaseMathPersistence; virtual;
    function LoadFromStream(aStream : TStream) : TBaseMathPersistence; virtual; //abstract;

    procedure SaveToFile(aMathObj : TBaseMathPersistence; const FileName : string);
    procedure SaveToStream(aMathObj : TBaseMathPersistence; aStream : TStream); virtual;

    class procedure StaticSaveToFile(aMathObj : TBaseMathPersistence; const FileName : string);
    class procedure StaticSaveToStream(aMathObj : TBaseMathPersistence; aStream : TStream);
  end;

function CreateMathIOReader(const FileName : TFileName) : TClass; overload;
function CreateMathIOReader(Stream : TStream) : TClass; overload;

function ReadObjFromFile(const FileName : TFileName) : TBaseMathPersistence;
function ReadObjFromStream(aStream : TStream) : TBaseMathPersistence;

// every math IO file type must be registered here to be recognized
procedure RegisterMathIOReader(reader : TClass);

// every classifier must be registered here in order to get recognized in the IO routines
procedure RegisterMathIO(AMathIOClass : TBaseMathPersistenceClass);
function MathIOClassFromName(const CLName : String) : TBaseMathPersistenceClass;

// for dll deinitalizations:
procedure FinalizeMathIO;

implementation

uses Contnrs, MatrixConst;

// ###################################################
// #### Global functions / reader writer handling
// ###################################################

var IOObjects : TClassList;
    MathIOClasses : TClassList;

function GetIOObjects : TClassList;
begin
     if not Assigned(IOObjects) then
        IOObjects := TClassList.Create;

     Result := IOObjects;
end;

function GetMathIOClasses : TClassList;
begin
     if not Assigned(MathIOClasses) then
        MathIOClasses := TClassList.Create;

     Result := MathIOClasses;
end;

procedure RegisterMathIOReader(reader : TClass);
begin
     if Assigned(reader) and reader.InheritsFrom(TCustomMathPersistenceIO) then
        GetIOObjects.Add(reader);  
end;

procedure RegisterMathIO(AMathIOClass : TBaseMathPersistenceClass);
begin
     GetMathIOClasses.Add(AMathIOClass);
end;

function MathIOClassFromName(const CLName : String) : TBaseMathPersistenceClass;
var cl : TBaseMathPersistenceClass;
    i : integer;
begin
     Result := nil;

     for i := 0 to GetMathIOClasses.Count - 1 do
     begin
          cl := TBaseMathPersistenceClass(GetMathIOClasses[i]);

          if CompareText(String(TBaseMathPersistence(cl).ClassIdentifier), String(CLName)) = 0 then
          begin
               Result := cl;
               exit;
          end;
     end;
end;

function CreateMathIOReader(const FileName : TFileName) : TCustomMathPersistenceIOClass;
var fs : TFileStream;
begin
     fs := TFileStream.Create(FileName, fmOpenRead);
     try
        Result := CreateMathIOReader(fs);
     finally
            fs.Free;
     end;
end;

function CreateMathIOReader(Stream : TStream) : TClass;
var i : integer;
    startPos : Int64;
    ReaderClass : TCustomMathPersistenceIOClass;
begin
     startPos := stream.Position;
     Result := nil;
     for i := 0 to GetIOObjects.Count - 1 do
     begin
          try
               ReaderClass := TCustomMathPersistenceIOClass(GetIOObjects[i]);
               if Assigned(ReaderClass) and ReaderClass.InheritsFrom(TCustomMathPersistenceIO) then
               begin
                   if TCustomMathPersistenceIO(ReaderClass).CanReadStream(stream) then
                   begin
                       // CanReadStream may consume bytes while sniffing, so rewind
                       // before delegating or the reader sees a truncated header
                      stream.Position := startPos;
                      Result := ReaderClass;
                      break;
                   end;
               end;
          except
          end;

          stream.Position := startPos;
          if Assigned(Result) then
             break;
     end;
end;

function ReadObjFromFile(const FileName : TFileName) : TBaseMathPersistence;
var readerClass : TCustomMathPersistenceIOClass;
    readerInstance : TCustomMathPersistenceIO;
begin
     Result := nil;

     readerClass := CreateMathIOReader(FileName);
     if not Assigned(readerClass) then
        exit;

     readerInstance := TCustomMathPersistenceIO(readerClass.Create);  
     try
        Result := readerInstance.LoadFromFile(FileName);
     finally
            readerInstance.Free;
     end;
end;

function ReadObjFromStream(aStream : TStream) : TBaseMathPersistence;
var readerClass : TCustomMathPersistenceIOClass;
    readerInstance : TCustomMathPersistenceIO;
begin
     Result := nil;

     readerClass := CreateMathIOReader(aStream);
     if not Assigned(readerClass) then
        exit;

     readerInstance := TCustomMathPersistenceIO(readerClass.Create);
     try
        Result := readerInstance.LoadFromStream(aStream);
     finally
            readerInstance.Free;
     end;
end;

{ TBaseMathPersistence }

procedure TBaseMathPersistence.AddBinaryProperty(const Name: String;
  const Value; size: integer);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteBinaryProperty(Name, Value, size);
end;

procedure TBaseMathPersistence.AddDoubleArr(const Name: String;
  const Value: TDoubleDynArray);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteDoubleArr(Name, Value);
end;

procedure TBaseMathPersistence.AddObject(const Name: String;
  obj: TBaseMathPersistence);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteObject(Name, obj);
end;

procedure TBaseMathPersistence.AddObjectDescription(const Name,
  Value: String);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteObjDescriptor('obj', Value);
end;

procedure TBaseMathPersistence.AddObject(Obj: TBaseMathPersistence);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteObject(Obj);
end;

procedure TBaseMathPersistence.AddStringProperty(const Name, Value: String);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteProperty(Name, Value);
end;

procedure TBaseMathPersistence.AddDoubleProperty(const Name: String;
  const Value: double);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteProperty(Name, Value);
end;

procedure TBaseMathPersistence.AddIntProperty(const Name: String;
  const Value: integer);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteProperty(Name, Value);
end;

procedure TBaseMathPersistence.BeginList(const Name: String; count: integer);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteListBegin(Name, count);
     fInList := True;
end;

class function TBaseMathPersistence.ClassIdentifier: String;
begin
     Result := String(ClassName);
end;

procedure TBaseMathPersistence.CleanupWriter;
begin
     fWriter := nil;
end;

procedure TBaseMathPersistence.EndList;
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteListEnd;
     fInList := False;
end;

procedure TBaseMathPersistence.FinishReading;
begin
     // do nothing in the base class
end;

procedure TBaseMathPersistence.InitWriter(Writer: TCustomMathPersistenceIO);
begin
     fInList := False;
     fWriter := Writer;

     // init the stream with a header
     AddObjectDescription('hea', ClassIdentifier);
end;

procedure TBaseMathPersistence.OnLoadBeginList(const Name: String;
  count: integer);
begin
     // do nothing in the base class
end;

procedure TBaseMathPersistence.OnLoadBinaryProperty(const Name: String;
  const Value; size: integer);
begin
     // do nothing in the base class
end;

procedure TBaseMathPersistence.OnLoadDoubleArr(const Name: String;
  const Value: TDoubleDynArray);
begin
     // do nothing in the base class
end;

procedure TBaseMathPersistence.OnLoadEndList;
begin
     // do nothing in the base class
end;

procedure TBaseMathPersistence.OnLoadIntArr(const Name: String;
  const Value: TIntegerDynArray);
begin
     // do nothing in the base class
end;

procedure TBaseMathPersistence.OnLoadListDoubleArr(
  const Value: TDoubleDynArray);
begin
     // do nothing in the base class
end;

procedure TBaseMathPersistence.OnLoadListIntArr(const Value: TIntegerDynArray);
begin
     // do nothing in the base class
end;

function TBaseMathPersistence.OnLoadObject(const Name: String;
  Obj: TBaseMathPersistence) : boolean;
begin
     Result := False;
end;

function TBaseMathPersistence.OnLoadObject(Obj: TBaseMathPersistence) : boolean;
begin
     // do nothing in the base class
     Result := False;
end;

procedure TBaseMathPersistence.OnLoadStringProperty(const Name, Value: String);
begin
     // do nothing in the base class
end;

procedure TBaseMathPersistence.SaveToFile(const FileName: string;
  WriterClass: TCustomMathPersistenceIOClass);
var fs : TFileStream;
begin
     fs := TFileStream.Create(FileName, fmCreate or fmOpenWrite);
     try
        SaveToStream(fs, WriterClass);
     finally
            fs.Free;
     end;
end;

procedure TBaseMathPersistence.SaveToStream(stream: TStream;
  WriterClass : TClass);
var obj : TCustomMathPersistenceIO;
begin
     if not Assigned(WriterClass) or not WriterClass.InheritsFrom(TCustomMathPersistenceIO) then
        raise Exception.Create('Invalid WriterClass type');

     obj := TCustomMathPersistenceIO(WriterClass.Create);
     try
        obj.SaveToStream(self, stream);
     finally
            obj.Free;
     end;
end;

procedure TBaseMathPersistence.OnLoadIntProperty(const Name: String;
  Value: integer);
begin
     // do nothing in the base class
end;

procedure TBaseMathPersistence.OnLoadDoubleProperty(const Name: String;
  const Value: double);
begin
     // do nothing in the base class
end;

procedure FinalizeMathIO;
begin
     FreeAndNil(IOObjects);
     FreeAndNil(MathIOClasses);
end;

procedure TBaseMathPersistence.AddIntArr(const Name: String;
  const Value: TIntegerDynArray);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     fWriter.WriteIntArr(Name, Value);
end;

procedure TBaseMathPersistence.AddListDoubleArr(const Value: TDoubleDynArray);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     if not fInList then
        raise EWriteError.Create('Error call "addlist x" function without call of BeginList');
        
     fWriter.WriteListDoubleArr(Value);
end;

procedure TBaseMathPersistence.AddListIntArr(const Value: TIntegerDynArray);
begin
     assert(Assigned(fWriter), 'No writer assigned');
     if not fInList then
        raise EWriteError.Create('Error call "addlist x" function without call of BeginList');
        
     fWriter.WriteListIntArr(Value);
end;

function TBaseMathPersistence.PropTypeOfName(const Name: string): TPropType;
begin
     Result := ptUnknown;
end;

function TCustomMathPersistenceIO.PropTypeOfName(
  readObj: TBaseMathPersistence; const Name : string): TPropType;
begin
     Result := readObj.PropTypeOfName(Name);
end;

function TBaseMathPersistence.IntArrayIndex(const Name: String): integer;
begin
     Result := 0;
     while (Result < Length(fIntArrays)) and (fIntArrays[Result].Name <> Name) do
        inc(Result);
     if Result >= Length(fIntArrays) then
        Result := -1;
end;

procedure TBaseMathPersistence.RecordProp(const Name, Value: String);
var
  idx : integer;
begin
  // a property with an empty value (a matrix 'Name' is the empty string) has to
  // stay visible, so the entry is written rather than deleted
  idx := fLoadedProps.IndexOfName(Name);
  if idx >= 0 then
    fLoadedProps[idx] := Name + TStrList.NameValueSeparator + Value
  else
    fLoadedProps.AddPair(Name, Value);
end;

procedure TBaseMathPersistence.RecordProp(const Name: String; Value: Int64);
begin
  RecordProp(Name, IntToStr(Value));
end;

procedure TBaseMathPersistence.RecordProp(const Name: String;
  const Value: double);
begin
  // a display value, not a round-trip representation
  RecordProp(Name, FloatToStr(Value));
end;

procedure TBaseMathPersistence.RecordPropObject(const Name: String;
  Obj: TBaseMathPersistence);
begin
  if Assigned(Obj) then
    RecordProp(Name, Obj.ClassName)
  else
    RecordProp(Name, '');
end;

procedure TBaseMathPersistence.RecordPropSummary(const Name, Kind: String;
  Count: integer);
begin
  RecordProp(Name, Format('<%s %d>', [Kind, Count]));
end;

procedure TBaseMathPersistence.ResetLoadedProps;
begin
  fLoadedProps.Clear;
end;

function TBaseMathPersistence.PropGetAsString(const Name: String; const Default: String): String;
begin
  if fLoadedProps.IndexOfName(Name) >= 0 then
    Result := fLoadedProps.Values(Name)
  else
    Result := Default;
end;

function TBaseMathPersistence.HasProperty(const Name: String): Boolean;
begin
  Result := fLoadedProps.IndexOfName(Name) >= 0;
  if not Result then
    // the stream header fields, present for every persisted object
    Result := SameText(Name, 'Lib') or SameText(Name, 'Version');
end;

procedure TBaseMathPersistence.RecordIntArray(const Name: String;
  const Values: TIntegerDynArray);
var
  idx : integer;
begin
  idx := IntArrayIndex(Name);
  if idx < 0 then
  begin
    idx := Length(fIntArrays);
    SetLength(fIntArrays, idx + 1);
    fIntArrays[idx].Name := Name;
  end;
  fIntArrays[idx].Values := Copy(Values, 0, Length(Values));
end;

function TBaseMathPersistence.PropGetAsIntArray(const Name: String): TIntegerDynArray;
var
  idx : integer;
begin
  idx := IntArrayIndex(Name);
  if idx >= 0 then
    Result := Copy(fIntArrays[idx].Values, 0, Length(fIntArrays[idx].Values))
  else
    Result := nil;
end;

{ TCustomMathPersistenceIO }

procedure TCustomMathPersistenceIO.WriteVersion(ver: integer);
begin
     // do nothing here
end;

// ################################################
// #### writing propertyies - called from the reader classes
// and serve as surrogates between the reader classes and the objects themself

procedure TCustomMathPersistenceIO.ReadDoubleProperty(
  readObj: TBaseMathPersistence; const Name: String; const Value: double);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadDoubleProperty(Name, Value);
end;

procedure TCustomMathPersistenceIO.ReadStringProperty(
  readObj: TBaseMathPersistence; const Name, Value: String);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadStringProperty(Name, value);
end;

procedure TCustomMathPersistenceIO.ReadIntProperty(
  readObj: TBaseMathPersistence; const Name: String; Value: integer);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadIntProperty(Name, Value);
end;

procedure TCustomMathPersistenceIO.ReadBinaryProperty(
  readObj: TBaseMathPersistence; const Name: String; const Value;
  size: integer);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadBinaryProperty(Name, Value, Size);
end;

function TCustomMathPersistenceIO.ReadObject(readObj: TBaseMathPersistence;
  const Name: String; Obj: TBaseMathPersistence): boolean;
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     Result := readObj.OnLoadObject(Name, Obj);
end;

function TCustomMathPersistenceIO.ReadObject(readObj,
  Obj: TBaseMathPersistence): boolean;
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     Result := readObj.OnLoadObject(Obj);
end;

procedure TCustomMathPersistenceIO.ReadBeginList(readObj: TBaseMathPersistence;
  const Name: String; count: integer);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadBeginList(Name, Count);
end;

procedure TCustomMathPersistenceIO.ReadEndList(readObj: TBaseMathPersistence);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadEndList;
end;

procedure TCustomMathPersistenceIO.ReadDoubleArr(readObj: TBaseMathPersistence;
  const Name: String; const Value: TDoubleDynArray);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadDoubleArr(Name, Value);
end;

procedure TCustomMathPersistenceIO.ReadIntArr(readObj: TBaseMathPersistence;
  const Name: String; const Value: TIntegerDynArray);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadIntArr(Name, Value);
end;

procedure TCustomMathPersistenceIO.ReadListDoubleArr(
  readObj: TBaseMathPersistence; const Value: TDoubleDynArray);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadListDoubleArr(Value);
end;

procedure TCustomMathPersistenceIO.ReadListIntArr(readObj: TBaseMathPersistence;
  const Value: TIntegerDynArray);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.OnLoadListIntArr(Value);
end;

procedure TCustomMathPersistenceIO.ReadFinalize(readObj: TBaseMathPersistence);
begin
     assert(assigned(readObj), 'Error: tried write a property on a nil object');
     readObj.FinishReading;
end;

function TCustomMathPersistenceIO.LoadFromFile(const FileName : string) : TBaseMathPersistence;
var fs : TFileStream;
begin
     fs := TFileStream.Create(FileName, fmOpenRead or fmShareDenyWrite);
     try
        Result := LoadFromStream(fs);
     finally
            fs.Free;
     end;
end;

function TCustomMathPersistenceIO.LoadFromStream(aStream : TStream) : TBaseMathPersistence; 
begin
     // Default impl: Raise if not overridden (abstract behavior)
     raise EAbstractError.Create('LoadFromStream must be implemented in concrete subclass (e.g., TJsonReaderWriter)');
end;

procedure TCustomMathPersistenceIO.SaveToFile(aMathObj : TBaseMathPersistence; const FileName: string);
var fs : TFileStream;
begin
     fs := TFileStream.Create(FileName, fmCreate or fmOpenWrite);
     try
        SaveToStream(aMathObj, fs);
     finally
            fs.Free;
     end;
end;

procedure TCustomMathPersistenceIO.SaveToStream(aMathObj: TBaseMathPersistence;
  aStream: TStream);
begin
     fStream := aStream;
     try
        WriteStreamHeader;
        aMathObj.InitWriter(Self);
        aMathObj.DefineProps;
        FinalizeStream;
     finally
            aMathObj.CleanupWriter;
            fStream := nil;
     end;
end;

class procedure TCustomMathPersistenceIO.StaticSaveToFile(
  aMathObj: TBaseMathPersistence; const FileName: string);
begin
     with self.Create do
     try
        SaveToFile(aMathObj, FileName);
     finally
            Free;
     end;
end;

class procedure TCustomMathPersistenceIO.StaticSaveToStream(
  aMathObj: TBaseMathPersistence; aStream: TStream);
begin
     with self.Create do
     try
        SaveToStream(aMathObj, aStream);
     finally
            Free;
     end;
end;


initialization
  IOObjects := nil;
  MathIOClasses := nil;

finalization
  FinalizeMathIO;

end.
