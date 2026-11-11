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


unit MatrixConst;

// ##############################################
// #### Constants for the mathematic utilities
// ##############################################

interface

{$MODE OBJFPC}{$H+}

{$IF FPC_FULLVERSION > 30203}  
  {$MODESWITCH FUNCTIONREFERENCES}
  {$MODESWITCH ANONYMOUSFUNCTIONS}
  {$DEFINE ANONMETHODS}  
{$ENDIF}

uses SysUtils, Types;

type
  TLinEquResult = (leOk, leSingular);
  TSVDResult = (srOk, srNoConvergence);
  TCholeskyResult = (crOk, crNoPositiveDefinite);
  TLinEquProgress = procedure(Progress : Integer) of Object;
  TLinEquProgressWOObj = procedure(Progress : Integer);
  TMtxProgress = procedure(Sender : TObject; progress : integer) of Object;

 type
   TXMMArr = Array[0..1] of double;
   PXMMArr = ^TXMMArr;

   TYMMArr = Array[0..3] of double;
   PYMMArr = ^TYMMArr;

   TZMMArr = Array[0..7] of double;
   PZMMArr = ^TZMMArr;

   TMeanVarRec = record
     aMean : double;
     aVar : double;
   end;

   TComplex = record
     real : double;
     imag : double;
   end;
   PComplex = ^TComplex;
   TComplexDynArray = Array of TComplex;

   TConstPDoubleArr = Array[0..MaxInt div sizeof(double) - 1] of PDouble;
   PPConstDoubleArr = ^TConstPDoubleArr;

const cDefEpsilon : double = 1e-20;
      cMinusOne : double = -1;
      cOne : double = 1;
      cOnes : Array[0..1] of double = (1, 1);
      cDivBy2 : Array[0..1] of double = (0.5, 0.5);

      cSignBits : Array[0..1] of int64 = ($7FFFFFFFFFFFFFFF, $7FFFFFFFFFFFFFFF);
      cSignBits4 : Array[0..3] of int64 = ($7FFFFFFFFFFFFFFF, $7FFFFFFFFFFFFFFF, $7FFFFFFFFFFFFFFF, $7FFFFFFFFFFFFFFF);
      cNegMaxDouble : double = -1.7e+308;
      cMaxDouble : double = 1.7e+308;
      cMinDouble : double = 2.225E-307;
      cNegMinDouble : double = -2.225E-307;

const cNegMaxDoubles : Array[0..1] of double = (-1.7e+308, -1.7e+308);
      cMaxDoubles : Array[0..1] of double = (1.7e+308, 1.7e+308);
      cMulM1Bits : Array[0..1] of Int64 = ($8000000000000000, $0);


type
  TEigenvalueConvergence = (qlOk, qlNoConverge, qlMatrixError);
  TEigenvalueEivecNormalize = ( enNone, enLen, enMaxVal ); // none, normalize to length 1, normalize to max = 1

type
  TMathOperationRes = (moSuccess, moFailure);

type
  TDynArrayofDoubleArray = Array of TDoubleDynArray;

type
  TConstDoubleArr = Array[0..MaxInt div sizeof(double) - 1] of double;
  PConstDoubleArr = ^TConstDoubleArr;

  TConstComplexArr = Array[0..MaxInt div sizeof(TComplex) - 1] of TComplex;
  PConstComplexArr = ^TConstComplexArr;

type
  TMatrixFunc = procedure(var Value : double);
  TMatrixObjFunc = procedure(var Value : double) of Object;
  TMatrixMtxRefFunc = procedure(var Value : double; const data : PDouble; LineWidth : NativeInt; x, y : NativeInt);
  TMatrixMtxRefObjFunc = procedure(var Value : double; const data : PDouble; LineWidth : NativeInt; x, y : NativeInt) of Object;

  TCplxMatrixFunc = procedure(var Value : TComplex);
  TCplxMatrixObjFunc = procedure(var Value : TComplex) of Object;
  TCplxMatrixMtxRefFunc = procedure(var Value : TComplex; const data : PComplex; LineWidth : NativeInt; x, y : NativeInt);
  TCplxMatrixMtxRefObjFunc = procedure(var Value : TComplex; const data : PComplex; LineWidth : NativeInt; x, y : NativeInt) of Object;


{.$DEFINE ANONMETHODS}

{$IFDEF ANONMETHODS}
  TMatrixFuncRef = reference to procedure(var Value : double);
  TMatrixMtxRefFuncRef = reference to procedure(var Value : double; const data : PDouble; LineWidth : NativeInt; x, y : NativeInt);

  TCplxMatrixFuncRef = reference to procedure(var Value : TComplex);
  TCplxMatrixMtxRefFuncRef = reference to procedure(var Value : TComplex; const data : PComplex; LineWidth : NativeInt; x, y : NativeInt);
{$ENDIF}

function ConvEQUProgress(value : TLinEquProgressWOObj) : TLinEquProgress;


// ###########################################
// #### Matrix multiplication constants
const cStrassenMinSize = 32;
      cCacheMtxSize = 256;
      cCacheBlkSize = 16;
      cSymEigSmallSize = 25;

{$I 'vMath_CPU.inc'}

type
  TMatrixMultDestOperation = (doNone, doAdd, doSub);


// ###########################################
// #### Creates a pointer to the x, y element of the given matrix (row major)
function GenPtr(const A : PDouble; incX, incY : NativeInt; const LineWidthA : NativeInt) : PDouble;
function GenPtrArr(const A : PDouble; incX, incY : NativeInt; const LineWidthA : NativeInt) : PConstDoubleArr;

// complex version
function CplxGenPtr(const A : PComplex; incX, incY : NativeInt; const LineWidthA : NativeInt) : PComplex; 
function CplxGenPtrArr(const A : PComplex; incX, incY : NativeInt; const LineWidthA : NativeInt) : PConstComplexArr; 


// ###########################################
// #### Sets the pointer to the next available 32bytes alligned address
// note: the function does not check if there is still enough memory allocated and left for this operation!
function AlignPtr32( A : Pointer ) : Pointer; 
function AlignPtr64( A : Pointer ) : Pointer; 

// ###########################################
// #### Complex init
function InitComplex( aReal, aImag : double ) : TComplex;

implementation

function InitComplex( aReal, aImag : double ) : TComplex;
begin
     Result.real := aReal;
     Result.imag := aImag;
end;

function GenPtr(const A : PDouble; incX, incY : NativeInt; const LineWidthA : NativeInt) : PDouble; 
begin
     Result := A;
     inc(Result, incX);
     inc(PByte(Result), incY*LineWidthA);
end;

function GenPtrArr(const A : PDouble; incX, incY : NativeInt; const LineWidthA : NativeInt) : PConstDoubleArr;
begin
     Result := PConstDoubleArr(A);
     Result := @Result^[incX];
     inc(PByte(Result), incY*LineWidthA);
end;

function CplxGenPtr(const A : PComplex; incX, incY : NativeInt; const LineWidthA : NativeInt) : PComplex; 
begin
     Result := A;
     inc(Result, incX);
     inc(PByte(Result), incY*LineWidthA);
end;

function CplxGenPtrArr(const A : PComplex; incX, incY : NativeInt; const LineWidthA : NativeInt) : PConstComplexArr; 
begin
     Result := PConstComplexArr(A);
     Result := @Result^[incX];
     inc(PByte(Result), incY*LineWidthA);
end;

function AlignPtr32( A : Pointer ) : Pointer;
begin
     Result := A;
     if (NativeUint(A) and $1F) <> 0 then
        Result := Pointer( NativeUint(Result) + $20 - NativeUint(Result) and $1F );
end;

function AlignPtr64( A : Pointer ) : Pointer;
begin
     Result := A;
     if (NativeUint(A) and $3F) <> 0 then
        Result := Pointer( NativeUint(Result) + $40 - NativeUint(Result) and $3F );
end;

function ConvEQUProgress(value : TLinEquProgressWOObj) : TLinEquProgress;
var meth : TMethod;
begin
     meth.Data := nil;
     meth.Code := Pointer(@Value);

     Result := TLinEquProgress(meth);
end;

end.
