// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################

// ###########################################################
// #### CBOR Encoder/Decoder for Free Pascal
// ###########################################################
unit CBOR;
{$MODE OBJFPC}{$H+}
{$MODESWITCH ADVANCEDRECORDS}
{$PACKENUM 4}{$PACKRECORDS C}
{$NOTES OFF}

interface
uses
  SysUtils, Classes;

const
  CBOR_BREAK = $FF; // Break byte for indefinite-length containers

type
  // #########################################################
  // #### Generic CBOR value type for dynamic reading
  // #########################################################
  TCBORType = (
    ctInvalid,
    ctUInt,
    ctNegInt,
    ctByteString,
    ctTextString,
    ctArrayDefinite,
    ctArrayIndefinite,
    ctMapDefinite,
    ctMapIndefinite,
    ctFloat,
    ctSimple,
    ctTag
  );

  TCBORValue = record
    Kind: TCBORType;
    // Managed types stored separately (must be before variant section)
    TextVal: UTF8String;
    ByteVal: TBytes;
    // Variant part for simple/unmanaged types - MUST be last
    case Integer of
      0: (UIntVal: UInt64);
      1: (NegIntVal: Int64);
      2: (FloatVal: Double);
      3: (ArraySize: UInt64);
      4: (MapSize: UInt64);
      5: (SimpleVal: Byte);
      6: (TagVal: UInt64);
  end;

  // #########################################################
  // #### Forward declaration of map reader (needed for TCBORReader)
  // #########################################################
  TCBORMapReader = record
  private
    FReader: Pointer; // Use generic pointer to avoid circular definition
    FIsIndefinite: Boolean;
    FRemaining: UInt64;
  public
    procedure Init(AReader: Pointer; IsIndefinite: Boolean; Count: UInt64 = 0); inline;
    function HasNext: Boolean; inline;
    function ReadNextKey: UTF8String;
    function ReadNextValue: TCBORValue; inline;
    procedure SkipValue; inline;
  end;

  // #########################################################
  // #### CBOR Reader (record)
  // #########################################################
  TCBORReader = record
  private
    FStream: TStream;
  public
    function PeekByte: Byte; inline;
    function ReadByte: Byte; inline;
    function ReadUInt64BE: UInt64; inline;
    procedure ReadBytes(var buf; len: SizeInt); inline;
    function DecodeLength(minor: Byte): UInt64; inline;
    function InternalReadValue(ReadContent: Boolean): TCBORValue; inline;
  public
    procedure Init(AStream: TStream); inline;
    function ReadUInt: UInt64; inline;
    function ReadInt: Int64; inline;
    function ReadFloat: Double; inline;
    function ReadText: UTF8String;
    function ReadBytes: TBytes;
    function ReadArrayHeader: UInt64; inline;
    function ReadMapHeader: UInt64; inline;
    function PeekType: TCBORType; inline;
    function ReadValue: TCBORValue; inline;
    procedure SkipValue; inline;
    function ReadBreak: Boolean; inline;
    function BeginMap: TCBORMapReader; inline;
    function BeginArray: TCBORMapReader; inline;
    function ReadTag: UInt64; inline;
  end;
  
  // #########################################################
  // #### CBOR Writer (record, zero heap allocation)
  // #########################################################
  TCBORWriter = record
  private
    FStream: TStream;
    procedure WriteInitialByte(b: Byte); inline;
    procedure WriteUInt64BE(val: UInt64); inline;
  public
    procedure Init(AStream: TStream); inline;
    procedure WriteUInt(val: UInt64);
    procedure WriteInt(val: Int64);
    procedure WriteFloat(val: Double);
    procedure WriteText(const s: UTF8String);
    procedure WriteBytes(const data; len: SizeInt);
    procedure WriteArrayHeader(count: UInt64);
    procedure WriteMapHeader(count: UInt64);
    
    // Indefinite-length support
    procedure WriteIndefiniteArrayStart; inline;
    procedure WriteIndefiniteMapStart; inline;
    procedure WriteBreak; inline;
    
    // Tag support
    procedure WriteTag(tag: UInt64);
  end;

implementation

const
  MT_UNSIGNED = $00;
  MT_NEGATIVE = $20;
  MT_BYTES    = $40;
  MT_TEXT     = $60;
  MT_ARRAY    = $80;
  MT_MAP      = $A0;
  MT_TAG      = $C0;
  MT_SIMPLE   = $E0;
  
  SV_FALSE    = $14; // 20
  SV_TRUE     = $15; // 21
  SV_NULL     = $16; // 22
  SV_FLOAT16  = $19;
  SV_FLOAT32  = $1A;
  SV_FLOAT64  = $1B;
  
  // Indefinite-length markers
  MT_ARRAY_INDEF = $9F; // 100_11111
  MT_MAP_INDEF   = $BF; // 101_11111

// #########################################################
// #### Endian helpers (portable, no external units)
// #########################################################
function SwapEndian32(v: UInt32): UInt32; inline;
begin
  Result := ((v and $000000FF) shl 24) or
            ((v and $0000FF00) shl 8)  or
            ((v and $00FF0000) shr 8)  or
            ((v and $FF000000) shr 24);
end;

function SwapEndian64(v: UInt64): UInt64; inline;
begin
  Result := (UInt64(SwapEndian32(UInt32(v))) shl 32) or
            UInt64(SwapEndian32(UInt32(v shr 32)));
end;

// #########################################################
// #### TCBORMapReader Implementation
// #########################################################
procedure TCBORMapReader.Init(AReader: Pointer; IsIndefinite: Boolean; Count: UInt64);
begin
  FReader := AReader;
  FIsIndefinite := IsIndefinite;
  FRemaining := Count;
end;

function TCBORMapReader.HasNext: Boolean; inline;
var
  Reader: ^TCBORReader absolute FReader;
begin
  if FIsIndefinite then
  begin
    // Check for break byte without consuming it
    Result := (Reader^.PeekByte <> CBOR_BREAK);
  end
  else
  begin
    Result := (FRemaining > 0);
    if not Result then
      Reader^.SkipValue; // Skip break byte if present after definite map
  end;
end;

function TCBORMapReader.ReadNextKey: UTF8String;
var
  Reader: ^TCBORReader absolute FReader;
begin
  // Keys must be text strings in our use case
  if Reader^.PeekType <> ctTextString then
    raise EReadError.Create('Map key must be text string');
  Result := Reader^.ReadText;
  
  if not FIsIndefinite then
    Dec(FRemaining);
end;

function TCBORMapReader.ReadNextValue: TCBORValue; inline;
var
  Reader: ^TCBORReader absolute FReader;
begin
  Result := Reader^.ReadValue;
  
  if not FIsIndefinite then
    Dec(FRemaining);
end;

procedure TCBORMapReader.SkipValue; inline;
var
  Reader: ^TCBORReader absolute FReader;
begin
  Reader^.SkipValue;
  
  if not FIsIndefinite then
    Dec(FRemaining);
end;

// #########################################################
// #### TCBORReader Implementation
// #########################################################
procedure TCBORReader.Init(AStream: TStream); inline;
begin
  FStream := AStream;
end;

function TCBORReader.BeginMap: TCBORMapReader; inline;
var
  b: Byte;
  isIndefinite: Boolean;
  count: UInt64;
begin
  b := ReadByte;
  if (b and $E0) = MT_MAP then
  begin
    isIndefinite := (b and $1F) = 31;
    if isIndefinite then
      count := 0
    else
      count := DecodeLength(b and $1F);
  end
  else if b = MT_MAP_INDEF then
  begin
    isIndefinite := True;
    count := 0;
  end
  else
    raise EReadError.Create('Expected map start');
  
  Result.Init(@Self, isIndefinite, count);
end;

function TCBORReader.BeginArray: TCBORMapReader; inline;
var
  b: Byte;
  isIndefinite: Boolean;
  count: UInt64;
begin
  b := ReadByte;
  if (b and $E0) = MT_ARRAY then
  begin
    isIndefinite := (b and $1F) = 31;
    if isIndefinite then
      count := 0
    else
      count := DecodeLength(b and $1F);
  end
  else if b = MT_ARRAY_INDEF then
  begin
    isIndefinite := True;
    count := 0;
  end
  else
    raise EReadError.Create('Expected array start');
  
  Result.Init(@Self, isIndefinite, count);
end;

function TCBORReader.PeekByte: Byte; inline;
var
  pos: Int64;
begin
  pos := FStream.Position;
  try
    FStream.ReadBuffer(Result, 1);
  finally
    FStream.Position := pos;
  end;
end;

function TCBORReader.ReadByte: Byte; inline;
begin
  FStream.ReadBuffer(Result, 1);
end;

function TCBORReader.ReadUInt64BE: UInt64; inline;
begin
  FStream.ReadBuffer(Result, 8);
  Result := SwapEndian64(Result);
end;

procedure TCBORReader.ReadBytes(var buf; len: SizeInt); inline;
begin
  if len > 0 then
    FStream.ReadBuffer(buf, len);
end;

function TCBORReader.DecodeLength(minor: Byte): UInt64; inline;
begin
  case minor of
    0..23: Result := minor;
    24:    Result := ReadByte;
    25:
      begin
        Result := (UInt64(ReadByte) shl 8) or ReadByte;
      end;
    26:
      begin
        Result := (UInt64(ReadByte) shl 24) or (UInt64(ReadByte) shl 16) or
                  (UInt64(ReadByte) shl 8)  or ReadByte;
      end;
    27:    Result := ReadUInt64BE;
    31:    raise EReadError.Create('Unexpected indefinite-length marker');
  else
    raise EReadError.Create('Invalid additional info: ' + IntToStr(minor));
  end;
end;

function TCBORReader.ReadUInt: UInt64; inline;
var 
  b, minor: Byte;
begin
  b := ReadByte;
  if (b and $E0) <> MT_UNSIGNED then
    raise EReadError.Create('Expected unsigned integer');
  minor := b and $1F;
  Result := DecodeLength(minor);
end;

function TCBORReader.ReadInt: Int64; inline;
var 
  b, minor: Byte;
  uintVal: UInt64;
begin
  b := ReadByte;
  minor := b and $1F;
  case b and $E0 of
    MT_UNSIGNED: 
      Result := DecodeLength(minor);
    MT_NEGATIVE: 
      begin
        uintVal := DecodeLength(minor);
        if uintVal > UInt64(High(Int64)) + 1 then
          raise EReadError.Create('Negative integer too large for Int64');
        Result := -1 - Int64(uintVal);
      end;
  else
    raise EReadError.Create('Expected integer');
  end;
end;

function TCBORReader.ReadFloat: Double; inline;
var 
  b, minor: Byte;
  u32: UInt32;
  u64: UInt64;
  buf: array[0..1] of Byte;
begin
  b := ReadByte;
  minor := b and $1F;
  case b and $E0 of
    MT_UNSIGNED: 
      Result := DecodeLength(minor);
    MT_NEGATIVE: 
      Result := -1 - Int64(DecodeLength(minor));
    MT_SIMPLE:
      case minor of
        SV_FLOAT16:
          begin
            FStream.ReadBuffer(buf, 2);
            raise EReadError.Create('Half-float not implemented');
          end;
        SV_FLOAT32:
          begin
            // big-endian float32
            FStream.ReadBuffer(u32, SizeOf(UInt32));
            u32 := SwapEndian32(u32);
            Result := PSingle(@u32)^;
          end;
        SV_FLOAT64:
          begin
            // big-endian float64
            FStream.ReadBuffer(u64, SizeOf(UInt64));
            u64 := SwapEndian64(u64);
            Result := PDouble(@u64)^;
          end;
        SV_FALSE:   Result := 0.0;
        SV_TRUE:    Result := 1.0;
      else
        raise EReadError.Create('Unsupported simple value: ' + IntToStr(minor));
      end;
  else
    raise EReadError.Create('Expected number or float');
  end;
end;

function TCBORReader.ReadText: UTF8String;
var 
  b, minor: Byte;
  len: UInt64;
begin
  b := ReadByte;
  if (b and $E0) <> MT_TEXT then
    raise EReadError.Create('Expected text string');
  minor := b and $1F;
  len := DecodeLength(minor);
  
  // Check for valid string length
  if len > MaxInt then
    raise EReadError.Create('Text string too large');
  
  SetLength(Result, len);
  if len > 0 then
    ReadBytes(Result[1], len);
end;

function TCBORReader.ReadBytes: TBytes;
var 
  b, minor: Byte;
  len: UInt64;
begin
  b := ReadByte;
  if (b and $E0) <> MT_BYTES then
    raise EReadError.Create('Expected byte string');
  minor := b and $1F;
  len := DecodeLength(minor);
  
  // Check for valid byte length
  if len > MaxInt then
    raise EReadError.Create('Byte string too large');
  
  SetLength(Result, len);
  if len > 0 then
    ReadBytes(Result[0], len);
end;

function TCBORReader.ReadArrayHeader: UInt64; inline;
var 
  b, minor: Byte;
begin
  b := ReadByte;
  if (b and $E0) <> MT_ARRAY then
    raise EReadError.Create('Expected array');
  minor := b and $1F;
  Result := DecodeLength(minor);
end;

function TCBORReader.ReadMapHeader: UInt64; inline;
var 
  b, minor: Byte;
begin
  b := ReadByte;
  if (b and $E0) <> MT_MAP then
    raise EReadError.Create('Expected map');
  minor := b and $1F;
  Result := DecodeLength(minor);
end;

function TCBORReader.PeekType: TCBORType; inline;
var
  b, major, minor: Byte;
begin
  b := PeekByte;
  
  if b = CBOR_BREAK then
  begin
    Result := ctInvalid;  // Correctly identify break as special marker
    Exit;
  end;
  
  major := b and $E0;
  minor := b and $1F;
  
  case major of
    MT_UNSIGNED: 
      Result := ctUInt;
    MT_NEGATIVE: 
      Result := ctNegInt;
    MT_BYTES:
      if minor = 31 then 
        Result := ctArrayIndefinite  // Actually indefinite byte string, but we treat as array
      else 
        Result := ctByteString;
    MT_TEXT:
      if minor = 31 then 
        Result := ctMapIndefinite   // Actually indefinite text string
      else 
        Result := ctTextString;
    MT_ARRAY:
      if minor = 31 then 
        Result := ctArrayIndefinite 
      else 
        Result := ctArrayDefinite;
    MT_MAP:
      if minor = 31 then 
        Result := ctMapIndefinite 
      else 
        Result := ctMapDefinite;
    MT_TAG:
      Result := ctTag;
    MT_SIMPLE:
      case minor of
        20..23: Result := ctSimple;  // false, true, null, undefined
        25: Result := ctFloat;        // float16
        26: Result := ctFloat;        // float32
        27: Result := ctFloat;        // float64
      else
        if minor < 24 then
          Result := ctSimple
        else
          Result := ctInvalid;  // Reserved (including 31)
      end;
  else
    Result := ctInvalid;
  end;
end;

function TCBORReader.InternalReadValue(ReadContent: Boolean): TCBORValue; inline;
var
  b, major, minor: Byte;
  len: UInt64;
  u32: UInt32;
  u64: UInt64;
  tempSingle: TCBORValue;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Kind := ctInvalid;

  b := ReadByte;
  major := b and $E0;
  minor := b and $1F;

  case major of
    MT_UNSIGNED:
      begin
        Result.Kind := ctUInt;
        Result.UIntVal := DecodeLength(minor);
      end;

    MT_NEGATIVE:
      begin
        Result.Kind := ctNegInt;
        Result.NegIntVal := -1 - Int64(DecodeLength(minor));
      end;

    MT_BYTES:
      if minor = 31 then
      begin
        Result.Kind := ctArrayIndefinite;
        // Don't read content yet - caller must handle indefinite containers
      end
      else
      begin
        Result.Kind := ctByteString;
        len := DecodeLength(minor);
        if ReadContent then
        begin
          if len > MaxInt then raise EReadError.Create('Byte string too large');
          SetLength(Result.ByteVal, len);
          if len > 0 then ReadBytes(Result.ByteVal[0], len);
        end
        else
          FStream.Position := FStream.Position + len;
      end;

    MT_TEXT:
      if minor = 31 then
      begin
        Result.Kind := ctMapIndefinite;
        // Don't read content yet
      end
      else
      begin
        Result.Kind := ctTextString;
        len := DecodeLength(minor);
        if ReadContent then
        begin
          if len > MaxInt then raise EReadError.Create('Text string too large');
          SetLength(Result.TextVal, len);
          if len > 0 then ReadBytes(Result.TextVal[1], len);
        end
        else
          FStream.Position := FStream.Position + len;
      end;

    MT_ARRAY:
      if minor = 31 then
      begin
        Result.Kind := ctArrayIndefinite;
      end
      else
      begin
        Result.Kind := ctArrayDefinite;
        Result.ArraySize := DecodeLength(minor);
      end;

    MT_MAP:
      if minor = 31 then
      begin
        Result.Kind := ctMapIndefinite;
      end
      else
      begin
        Result.Kind := ctMapDefinite;
        Result.MapSize := DecodeLength(minor);
      end;

    MT_TAG:
      begin
        Result.Kind := ctTag;
        Result.TagVal := DecodeLength(minor);
      end;

    MT_SIMPLE:
      if minor < 24 then
      begin
        // Simple value
        Result.Kind := ctSimple;
        Result.SimpleVal := minor;
      end
      else
      begin
        case minor of
          24:
            begin
              Result.Kind := ctSimple;
              Result.SimpleVal := ReadByte;
            end;
          25: // SV_FLOAT16
            begin
              Result.Kind := ctFloat;
              raise EReadError.Create('Half-float not implemented');
            end;
        SV_FLOAT32:
         begin
            Result.Kind := ctFloat;
            FStream.ReadBuffer(u32, SizeOf(UInt32));
            u32 := SwapEndian32(u32);
            Result.FloatVal := PSingle(@u32)^;
          end;
        SV_FLOAT64:
          begin
            Result.Kind := ctFloat;
            FStream.ReadBuffer(u64, SizeOf(UInt64));
            u64 := SwapEndian64(u64);
            Result.FloatVal := PDouble(@u64)^;
          end;
          31:
            raise EReadError.Create('Unexpected break byte');
        else
          raise EReadError.Create('Invalid additional info for simple value: ' + IntToStr(minor));
        end;
      end;
  else
    raise EReadError.Create('Invalid major type: ' + IntToHex(major, 2));
  end;
end;

function TCBORReader.ReadValue: TCBORValue; inline;
begin
  Result := InternalReadValue(True);
end;

procedure TCBORReader.SkipValue; inline;
var
  b, major, minor: Byte;
  count: UInt64;
  i: UInt64;
begin
  b := ReadByte;
  
  if b = CBOR_BREAK then Exit;  
        
  major := b and $E0;
  minor := b and $1F;
  
  case major of
    MT_BYTES, MT_TEXT:
      if minor = 31 then
      begin
        // Skip indefinite-length byte/text string chunks
        repeat
          if PeekByte = CBOR_BREAK then
          begin
            ReadBreak;
            Break;
          end;
          SkipValue; // Skip each chunk
        until False;
      end
      else
      begin
        count := DecodeLength(minor);
        FStream.Position := FStream.Position + count;
      end;
      
    MT_ARRAY:
      if minor = 31 then
      begin
        // Skip indefinite-length array items
        repeat
          if PeekByte = CBOR_BREAK then
          begin
            ReadBreak;
            Break;
          end;
          SkipValue;
        until False;
      end
      else
      begin
        count := DecodeLength(minor);
        for i := 1 to count do
          SkipValue;
      end;
      
    MT_MAP:
      if minor = 31 then
      begin
        // Skip indefinite-length map items
        repeat
          if PeekByte = CBOR_BREAK then
          begin
            ReadBreak;
            Break;
          end;
          SkipValue; // Skip key
          SkipValue; // Skip value
        until False;
      end
      else
      begin
        count := DecodeLength(minor);
        for i := 1 to count do
        begin
          SkipValue; // Skip key
          SkipValue; // Skip value
        end;
      end;
      
    MT_TAG:
      begin
        DecodeLength(minor); // Skip tag number
        SkipValue;           // Skip tagged item
      end;
      
    MT_SIMPLE:
      if minor >= 24 then
      begin
        case minor of
          24: FStream.Position := FStream.Position + 1; // Skip simple value byte
          25: FStream.Position := FStream.Position + 2; // Skip half-float (not implemented)
          26: FStream.Position := FStream.Position + 4; // Skip single-float
          27: FStream.Position := FStream.Position + 8; // Skip double-float
        else
          raise EReadError.Create('Invalid additional info for simple value: ' + IntToStr(minor));
        end;
      end;
      
  else
    // For other types, length is already handled by DecodeLength
    if minor >= 24 then
      DecodeLength(minor); // This advances the stream
  end;
end;

function TCBORReader.ReadBreak: Boolean; inline;
var
  b: Byte;
begin
  b := ReadByte;
  Result := (b = CBOR_BREAK);
  if not Result then
    raise EReadError.Create('Expected break byte ($FF), got $' + IntToHex(b, 2));
end;

function TCBORReader.ReadTag: UInt64; inline;
var
  b, minor: Byte;
begin
  b := ReadByte;
  if (b and $E0) <> MT_TAG then
    raise EReadError.Create('Expected tag');
  minor := b and $1F;
  Result := DecodeLength(minor);
end;

// #########################################################
// #### TCBORWriter Implementation
// #########################################################
procedure TCBORWriter.Init(AStream: TStream); inline;
begin
  FStream := AStream;
end;

procedure TCBORWriter.WriteInitialByte(b: Byte); inline;
begin
  FStream.WriteByte(b);
end;

procedure TCBORWriter.WriteUInt64BE(val: UInt64); inline;
begin
  val := SwapEndian64(val);
  FStream.WriteBuffer(val, 8);
end;

procedure TCBORWriter.WriteUInt(val: UInt64);
begin
  if val < 24 then
    WriteInitialByte(Byte(val))
  else if val <= High(Byte) then
  begin
    WriteInitialByte($18);
    FStream.WriteByte(Byte(val));
  end
  else if val <= High(Word) then
  begin
    WriteInitialByte($19);
    val := SwapEndian32(UInt32(val));
    FStream.WriteBuffer(val, 2);
  end
  else if val <= High(UInt32) then
  begin
    WriteInitialByte($1A);
    val := SwapEndian32(UInt32(val));
    FStream.WriteBuffer(val, 4);
  end
  else
  begin
    WriteInitialByte($1B);
    WriteUInt64BE(val);
  end;
end;

procedure TCBORWriter.WriteInt(val: Int64);
begin
  if val >= 0 then
    WriteUInt(UInt64(val))
  else
  begin
    // CBOR negative integers are encoded as -1 - n
    WriteInitialByte(MT_NEGATIVE or $1B);
    WriteUInt64BE(UInt64(-1 - val));
  end;
end;

procedure TCBORWriter.WriteFloat(val: Double);
var
  sgl: Single;
  u32: UInt32;
  u64: UInt64;
begin
  sgl := Single(val);
  if (val >= -3.4028234663852886e38) and 
     (val <= 3.4028234663852886e38) and 
     (Double(sgl) = val) then
  begin
    WriteInitialByte(MT_SIMPLE or SV_FLOAT32);
    u32 := PUInt32(@sgl)^;
    u32 := SwapEndian32(u32);
    FStream.WriteBuffer(u32, 4);
  end
  else
  begin
    WriteInitialByte(MT_SIMPLE or SV_FLOAT64);
    u64 := PUInt64(@val)^;
    u64 := SwapEndian64(u64);
    FStream.WriteBuffer(u64, 8);
  end;
end;

procedure TCBORWriter.WriteText(const s: UTF8String);
var
  len: SizeInt;
begin
  len := Length(s);
  if len < 24 then
    WriteInitialByte(MT_TEXT or Byte(len))
  else if len <= High(Byte) then
  begin
    WriteInitialByte(MT_TEXT or $18);
    FStream.WriteByte(Byte(len));
  end
  else if len <= High(Word) then
  begin
    WriteInitialByte(MT_TEXT or $19);
    len := SwapEndian32(UInt32(len));
    FStream.WriteBuffer(len, 2);
  end
  else if len <= High(UInt32) then
  begin
    WriteInitialByte(MT_TEXT or $1A);
    len := SwapEndian32(UInt32(len));
    FStream.WriteBuffer(len, 4);
  end
  else
  begin
    WriteInitialByte(MT_TEXT or $1B);
    WriteUInt64BE(len);
  end;
  
  if len > 0 then
    FStream.WriteBuffer(s[1], len);
end;

procedure TCBORWriter.WriteBytes(const data; len: SizeInt);
begin
  if len < 24 then
    WriteInitialByte(MT_BYTES or Byte(len))
  else if len <= High(Byte) then
  begin
    WriteInitialByte(MT_BYTES or $18);
    FStream.WriteByte(Byte(len));
  end
  else if len <= High(Word) then
  begin
    WriteInitialByte(MT_BYTES or $19);
    len := SwapEndian32(UInt32(len));
    FStream.WriteBuffer(len, 2);
  end
  else if len <= High(UInt32) then
  begin
    WriteInitialByte(MT_BYTES or $1A);
    len := SwapEndian32(UInt32(len));
    FStream.WriteBuffer(len, 4);
  end
  else
  begin
    WriteInitialByte(MT_BYTES or $1B);
    WriteUInt64BE(len);
  end;
  
  if len > 0 then
    FStream.WriteBuffer(data, len);
end;

procedure TCBORWriter.WriteArrayHeader(count: UInt64);
var
  w: word; 
  dw: Uint32;
begin
  if count < 24 then
    WriteInitialByte(MT_ARRAY or Byte(count))
  else if count <= High(Byte) then
  begin
    WriteInitialByte(MT_ARRAY or $18);
    FStream.WriteByte(Byte(count));
  end
  else if count <= High(Word) then
	begin
	  WriteInitialByte(MT_ARRAY or $19);
	  w := Word(count);
	  w := (w shr 8) or (w shl 8); // 16-bit byte swap
	  FStream.WriteBuffer(w, 2);
	end
	else if count <= High(UInt32) then
	begin
	  WriteInitialByte(MT_ARRAY or $1A);
	  dw := UInt32(count);
	  dw := ((dw and $FF) shl 24) or ((dw and $FF00) shl 8) or
	        ((dw and $FF0000) shr 8) or ((dw and $FF000000) shr 24);
	  FStream.WriteBuffer(dw, 4);
	end
  else
  begin
    WriteInitialByte(MT_ARRAY or $1B);
    WriteUInt64BE(count);
  end;
end;

procedure TCBORWriter.WriteMapHeader(count: UInt64);
begin
  if count < 24 then
    WriteInitialByte(MT_MAP or Byte(count))
  else if count <= High(Byte) then
  begin
    WriteInitialByte(MT_MAP or $18);
    FStream.WriteByte(Byte(count));
  end
  else if count <= High(Word) then
  begin
    WriteInitialByte(MT_MAP or $19);
    count := SwapEndian32(UInt32(count));
    FStream.WriteBuffer(count, 2);
  end
  else if count <= High(UInt32) then
  begin
    WriteInitialByte(MT_MAP or $1A);
    count := SwapEndian32(UInt32(count));
    FStream.WriteBuffer(count, 4);
  end
  else
  begin
    WriteInitialByte(MT_MAP or $1B);
    WriteUInt64BE(count);
  end;
end;

procedure TCBORWriter.WriteIndefiniteArrayStart; inline;
begin
  WriteInitialByte(MT_ARRAY_INDEF);
end;

procedure TCBORWriter.WriteIndefiniteMapStart; inline;
begin
  WriteInitialByte(MT_MAP_INDEF);
end;

procedure TCBORWriter.WriteBreak; inline;
begin
  WriteInitialByte(CBOR_BREAK);
end;

procedure TCBORWriter.WriteTag(tag: UInt64);
begin
  if tag < 24 then
    WriteInitialByte(MT_TAG or Byte(tag))
  else if tag <= High(Byte) then
  begin
    WriteInitialByte($C1);
    FStream.WriteByte(Byte(tag));
  end
  else if tag <= High(Word) then
  begin
    WriteInitialByte($C2);
    tag := SwapEndian32(UInt32(tag));
    FStream.WriteBuffer(tag, 2);
  end
  else if tag <= High(UInt32) then
  begin
    WriteInitialByte($C3);
    tag := SwapEndian32(UInt32(tag));
    FStream.WriteBuffer(tag, 4);
  end
  else
  begin
    WriteInitialByte($C4);
    WriteUInt64BE(tag);
  end;
end;

end.
