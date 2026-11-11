// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

unit CBORReadWrite;

{$MODE OBJFPC}{$H+}
{$PACKENUM 4}{$PACKRECORDS C}

interface

uses
  SysUtils, Classes, Types, BaseMathPersistence, CBOR;

type
  TCBORReaderWriter = class(TCustomMathPersistenceIO)
  private
    fWriter: TCBORWriter;
  protected
    class function CanReadStream(aStream: TStream): Boolean; override;

    procedure WriteStreamHeader; override;
    procedure FinalizeStream; override;

    procedure WriteObjDescriptor(const Name, Value: String); override;
    procedure WriteDoubleArr(const Name: String; const Value: array of double); override;
    procedure WriteListBegin(const Name: String; count: integer); override;
    procedure WriteListEnd; override;
    procedure WriteBinaryProperty(const Name: String; const Value; size: integer); override;
    procedure WriteProperty(const Name: String; const Value: double); overload; override;
    procedure WriteProperty(const Name, Value: String); overload; override;
    procedure WriteProperty(const Name: String; const Value: integer); overload; override;
    procedure WriteObject(Obj: TBaseMathPersistence); override;
    procedure WriteObject(const Name: String; Obj: TBaseMathPersistence); overload; override;
    procedure WriteListDoubleArr(const Value: array of double); override;
    procedure WriteIntArr(const Name: String; const Value: array of Integer); override;
    procedure WriteListIntArr(const Value: array of Integer); override;

    procedure HandleListProperty(Reader: TCBORReader; const Key: UTF8String;
      Target: TBaseMathPersistence; ItemCount: UInt64);
    procedure ReadProperty(Reader: TCBORReader; const Key: UTF8String;
      Target: TBaseMathPersistence);
    function ReadObjectFromReader(Reader: TCBORReader): TBaseMathPersistence;
  public
    constructor Create;
    function LoadFromStream(aStream: TStream): TBaseMathPersistence; override;
  end;

implementation

const
  cCBORMagic: UInt64 = 1;

{ TCBORReaderWriter }

constructor TCBORReaderWriter.Create;
begin
  inherited Create;
end;

class function TCBORReaderWriter.CanReadStream(aStream: TStream): Boolean;
var
  startPos: Int64;
  reader: TCBORReader;
  tagNum: UInt64;
  t: TCBORType;
begin
  Result := False;
  if aStream = nil then
    Exit;

  startPos := aStream.Position;
  try
    reader.Init(aStream);

    // Optional tag
    t := reader.PeekType;
    if t = ctTag then
    begin
      tagNum := reader.ReadTag;
      if tagNum <> cCBORMagic then
        Exit;
    end;

    // Expect map (definite or indefinite)
    t := reader.PeekType;
    Result := (t = ctMapDefinite) or (t = ctMapIndefinite);
  except
    Result := False;
  end;
  aStream.Position := startPos;
end;

procedure TCBORReaderWriter.WriteStreamHeader;
begin
  fWriter.Init(Stream);
  fWriter.WriteTag(cCBORMagic);
  fWriter.WriteIndefiniteMapStart;
  fWriter.WriteText('Lib');
  fWriter.WriteText('vMath');
  fWriter.WriteText('Version');
  fWriter.WriteUInt(1);
end;

procedure TCBORReaderWriter.FinalizeStream;
begin
  fWriter.WriteBreak;
end;

procedure TCBORReaderWriter.WriteObjDescriptor(const Name, Value: String);
begin
  // Name is ignored; BaseMathPersistence always passes 'obj'
  fWriter.WriteText('obj');
  fWriter.WriteText(UTF8String(Value));
end;

procedure TCBORReaderWriter.WriteDoubleArr(const Name: String;
  const Value: array of double);
var
  i: Integer;
begin
  fWriter.WriteText(UTF8String(Name));
  fWriter.WriteArrayHeader(Length(Value));
  for i := 0 to High(Value) do
    fWriter.WriteFloat(Value[i]);
end;

procedure TCBORReaderWriter.WriteListBegin(const Name: String; count: integer);
begin
  fWriter.WriteText(UTF8String(Name));
  fWriter.WriteArrayHeader(count);
end;

procedure TCBORReaderWriter.WriteListEnd;
begin
  // no marker needed for definite-length arrays
end;

procedure TCBORReaderWriter.WriteBinaryProperty(const Name: String;
  const Value; size: integer);
begin
  fWriter.WriteText(UTF8String(Name));
  fWriter.WriteBytes(Value, size);
end;

procedure TCBORReaderWriter.WriteProperty(const Name: String;
  const Value: double);
begin
  fWriter.WriteText(UTF8String(Name));
  fWriter.WriteFloat(Value);
end;

procedure TCBORReaderWriter.WriteProperty(const Name, Value: String);
begin
  fWriter.WriteText(UTF8String(Name));
  fWriter.WriteText(UTF8String(Value));
end;

procedure TCBORReaderWriter.WriteProperty(const Name: String;
  const Value: integer);
begin
  fWriter.WriteText(UTF8String(Name));
  fWriter.WriteInt(Value);
end;

procedure TCBORReaderWriter.WriteObject(const Name: String;
  Obj: TBaseMathPersistence);
begin
  fWriter.WriteText(UTF8String(Name));
  Obj.SaveToStream(Stream, TCBORReaderWriter);
end;

procedure TCBORReaderWriter.WriteObject(Obj: TBaseMathPersistence);
begin
  Obj.SaveToStream(Stream, TCBORReaderWriter);
end;

procedure TCBORReaderWriter.WriteListDoubleArr(const Value: array of double);
var
  i: Integer;
begin
  fWriter.WriteArrayHeader(Length(Value));
  for i := 0 to High(Value) do
    fWriter.WriteFloat(Value[i]);
end;

procedure TCBORReaderWriter.WriteIntArr(const Name: String;
  const Value: array of Integer);
var
  i: Integer;
begin
  fWriter.WriteText(UTF8String(Name));
  fWriter.WriteArrayHeader(Length(Value));
  for i := 0 to High(Value) do
    fWriter.WriteInt(Value[i]);
end;

procedure TCBORReaderWriter.WriteListIntArr(const Value: array of Integer);
var
  i: Integer;
begin
  fWriter.WriteArrayHeader(Length(Value));
  for i := 0 to High(Value) do
    fWriter.WriteInt(Value[i]);
end;

procedure TCBORReaderWriter.HandleListProperty(Reader: TCBORReader;
  const Key: UTF8String; Target: TBaseMathPersistence; ItemCount: UInt64);
var
  i, j: Integer;
  innerCount: UInt64;
  arr: TIntegerDynArray;
begin
  {$IFDEF DEBUG}
  Writeln('DEBUG HandleListProperty Key=', string(Key),
          ' ItemCount=', ItemCount);
  {$ENDIF}

  for i := 0 to Integer(ItemCount) - 1 do
  begin
    {$IFDEF DEBUG}
    Writeln('  DEBUG List item ', i,
            ' PeekType=', Ord(Reader.PeekType));
    {$ENDIF}

    if Reader.PeekType <> ctArrayDefinite then
      raise EReadError.CreateFmt(
        'Expected inner array in list (index %d), got type=%d',
        [i, Ord(Reader.PeekType)]);

    innerCount := Reader.ReadArrayHeader;

    {$IFDEF DEBUG}
    Writeln('    DEBUG InnerCount=', innerCount);
    {$ENDIF}

    if innerCount > High(Integer) then
      raise EReadError.Create('Inner array too large');

    SetLength(arr, Integer(innerCount));

    for j := 0 to Integer(innerCount) - 1 do
    begin
      {$IFDEF DEBUG}
      Writeln('      DEBUG Reading int [', i, '][', j,
              '] PeekType=', Ord(Reader.PeekType));
      {$ENDIF}
      arr[j] := Reader.ReadInt;
    end;

    ReadListIntArr(Target, arr);
  end;
end;

procedure TCBORReaderWriter.ReadProperty(Reader: TCBORReader;
  const Key: UTF8String; Target: TBaseMathPersistence);
var
  propType: TPropType;
  itemCount: UInt64;
  iArr: TIntegerDynArray;
  dArr: TDoubleDynArray;
  bytes: TBytes;
  ptrBytes: Pointer;
  zeroByte: Byte = 0;
  i: Integer;
  nameStr: String;
  child: TBaseMathPersistence;
  iv: Int64;
  dv: Double;
  sv: String;
begin
  child := nil;
  nameStr := string(Key);
  propType := PropTypeOfName(Target, nameStr);
	
	if (propType = ptDouble) and (Reader.PeekType = ctArrayDefinite) then
    propType := ptDoubleArray
  else if (propType = ptInteger) and (Reader.PeekType = ctArrayDefinite) then
    propType := ptIntArray;

  // a class need not override PropTypeOfName: every scalar that stayed
  // ptUnknown was dropped via SkipValue (TStatTest lost its mean, variance
  // and count that way), and the wire type is unambiguous, so infer it
  if propType = ptUnknown then
    case Reader.PeekType of
      ctUInt, ctNegInt           : propType := ptInteger;
      ctFloat                    : propType := ptDouble;
      ctTextString               : propType := ptString;
      ctByteString               : propType := ptBinary;
      ctTag, ctMapDefinite,
      ctMapIndefinite            : propType := ptObject;
    end;
	
	{$IFDEF DEBUG}
	Writeln('DEBUG ReadProperty Key="', nameStr, '" PropType=', Ord(propType),
	        ' PeekType=', Ord(Reader.PeekType));
	{$ENDIF}
	
  case propType of
    ptList:
      begin
        {$IFDEF DEBUG}
        Writeln('DEBUG ReadProperty ptList Name=', nameStr,
                ' PeekType=', Ord(Reader.PeekType));
        {$ENDIF}

        if Reader.PeekType <> ctArrayDefinite then
          raise EReadError.Create('Expected definite-length array for list');

        itemCount := Reader.ReadArrayHeader;

        {$IFDEF DEBUG}
        Writeln('DEBUG List itemCount=', itemCount);
        {$ENDIF}

        ReadBeginList(Target, nameStr, itemCount);
        HandleListProperty(Reader, Key, Target, itemCount);
        ReadEndList(Target);
        Target.RecordPropSummary(nameStr, 'list', Integer(itemCount));
      end;

		ptBinary:
      begin
        if Reader.PeekType <> ctByteString then
          raise EReadError.Create('Expected byte string for binary property');

        bytes := Reader.ReadBytes;

        {$IFDEF DEBUG}
        Writeln('DEBUG ptBinary Key="', nameStr, '" len=', Length(bytes));
        if Length(bytes) > 0 then Writeln('DEBUG ptBinary first byte = ', IntToHex(bytes[0], 2));
        {$ENDIF}

        if Length(bytes) > 0 then
        begin
          ptrBytes := @bytes[0];
          ReadBinaryProperty(Target, nameStr, ptrBytes^, Length(bytes));
        end
        else
        begin
          // length = 0: use a stable dummy byte; size 0 means it won't be read
          ReadBinaryProperty(Target, nameStr, zeroByte, 0);
        end;
        Target.RecordPropSummary(nameStr, 'binary', Length(bytes));
      end;
		  
    ptIntArray:
      begin
        if Reader.PeekType <> ctArrayDefinite then
          raise EReadError.Create('Expected array for int array property');
        itemCount := Reader.ReadArrayHeader;
        SetLength(iArr, itemCount);
        for i := 0 to Integer(itemCount) - 1 do
          iArr[i] := Reader.ReadInt;
        ReadIntArr(Target, nameStr, iArr);
        Target.RecordIntArray(nameStr, iArr);
        Target.RecordPropSummary(nameStr, 'array', Integer(itemCount));
      end;

    ptDoubleArray:
      begin
        if Reader.PeekType <> ctArrayDefinite then
          raise EReadError.Create('Expected array for double array property');
        itemCount := Reader.ReadArrayHeader;
        SetLength(dArr, itemCount);
        for i := 0 to Integer(itemCount) - 1 do
          dArr[i] := Reader.ReadFloat;
        ReadDoubleArr(Target, nameStr, dArr);
        Target.RecordPropSummary(nameStr, 'array', Integer(itemCount));
      end;

    ptInteger:
      begin
        iv := Reader.ReadInt;
        Target.RecordProp(nameStr, iv);
        ReadIntProperty(Target, nameStr, iv);
      end;

    ptDouble:
      begin
        dv := Reader.ReadFloat;
        Target.RecordProp(nameStr, dv);
        ReadDoubleProperty(Target, nameStr, dv);
      end;

    ptString:
      begin
        sv := String(Reader.ReadText);
        Target.RecordProp(nameStr, sv);
        ReadStringProperty(Target, nameStr, sv);
      end;

    ptObject:
      begin
        // a nested object is its own CBOR frame, so recurse; without this
        // branch it fell through to SkipValue and every sub-matrix was lost
        child := ReadObjectFromReader(Reader);
        Target.RecordPropObject(nameStr, child);
        if not ReadObject(Target, nameStr, child) then
          child.Free;          // the handler did not take ownership
      end;

  else
    Reader.SkipValue;
  end;
end;

// reads one complete object frame (tag, map, properties) from a reader
// positioned on it; the frame ends with exactly one break, consumed here
function TCBORReaderWriter.ReadObjectFromReader(Reader: TCBORReader): TBaseMathPersistence;
var
  key: UTF8String;
  mathClass: TBaseMathPersistenceClass;
  obj: TBaseMathPersistence;
  t: TCBORType;
begin
  Result := nil;

  // nested frames carry their own stream header, i.e. a magic tag
  if Reader.PeekType = ctTag then
    Reader.ReadTag;

  t := Reader.PeekType;
  if (t <> ctMapDefinite) and (t <> ctMapIndefinite) then
    raise EReadError.Create('Expected map');

  if t = ctMapDefinite then
    Reader.ReadMapHeader
  else
    Reader.ReadByte;      // consume indefinite map start (0xBF)

  obj := nil;

  while Reader.PeekByte <> CBOR_BREAK do
  begin
    key := Reader.ReadText;

    if (obj = nil) and SameText(string(key), 'obj') then
    begin
      if Reader.PeekType <> ctTextString then
        raise EReadError.Create('"obj" value must be a string');
      mathClass := MathIOClassFromName(Reader.ReadText);
      if not Assigned(mathClass) then
        raise EReadError.Create('Unknown class identifier');
      obj := TBaseMathPersistence(mathClass.Create);
      Continue;
    end;

    if obj = nil then
      Reader.SkipValue          // header fields (Lib, Version, ...)
    else
      ReadProperty(Reader, key, obj);
  end;

  // the frame ends with a single break - the map terminator and the stream
  // finaliser are the same byte, so exactly one is consumed here
  if Reader.PeekByte = CBOR_BREAK then
    Reader.ReadBreak;

  if Assigned(obj) then
    ReadFinalize(obj);

  Result := obj;
end;

function TCBORReaderWriter.LoadFromStream(aStream: TStream): TBaseMathPersistence;
var
  reader: TCBORReader;
begin
  if aStream = nil then
    raise EReadError.Create('LoadFromStream: Stream is nil');

  reader.Init(aStream);

  // optional magic tag
  if reader.PeekType = ctTag then
    if reader.ReadTag <> cCBORMagic then
      raise EReadError.Create('Invalid CBOR magic number');

  Result := ReadObjectFromReader(reader);
  if Result = nil then
    raise EReadError.Create('"obj" property missing in CBOR data');
end;

initialization
  RegisterMathIOReader(TCBORReaderWriter);

end.
