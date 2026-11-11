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

unit MtxTimer;

interface

{$MODE OBJFPC}{$H+}


function MtxGetTime: Int64;

// used to convert to sec
var mtxFreq : Int64;

implementation

uses 
  {$IFDEF MSWINDOWS} Windows {$ENDIF}
  {$IFDEF LINUX} unixtype, linux {$ENDIF}
  {$IFDEF DARWIN} unixtype {$ENDIF}
  ;
{$IFDEF MACOS}
var sw:  TStopWatch; //wrc
{$ENDIF}

{$IFDEF DARWIN}
type
  TTimebaseInfoData = packed record
    numer: UInt32;
    denom: UInt32;
  end;

var timeInfo : TTimebaseInfoData;
  
function mach_timebase_info(var TimebaseInfoData: TTimebaseInfoData): Integer; cdecl; external 'libc';
function mach_absolute_time: QWORD; cdecl; external 'libc';
{$ENDIF}
  

function MtxGetTime: Int64;
{$IFDEF LINUX}
var loc_Start : TTimeSpec;
{$ENDIF}
begin
   {$IFDEF MACOS}
   Result := sw.GetTimeStamp;
   {$ENDIF}

   {$IFDEF LINUX}
   clock_gettime(CLOCK_MONOTONIC, @loc_Start);
   Result := loc_Start.tv_sec*1000000000 + loc_Start.tv_nsec;
   {$ENDIF}

   {$IFDEF MSWINDOWS}
   Result := 0;
   QueryPerformanceCounter(Result);
   {$ENDIF}

   {$IFDEF DARWIN}
   Result := Int64( mach_absolute_time*QWORD(timeInfo.numer) div QWORD(timeInfo.denom) );
   {$ENDIF}
end;

initialization
  {$IFDEF MSWINDOWS}
  QueryPerformanceFrequency(mtxFreq);
  {$ENDIF}

  {$IFDEF LINUX}
  mtxFreq := 1000000000;
  {$ENDIF}

  {$IFDEF DARWIN}
  mtxFreq := 1000000000;
  {AM}
  mach_timebase_info(timeInfo);
  {AM}
  {$ENDIF}

  {$IFDEF MACOS}
  sw := TStopWatch.Create() ;
  sw.Start;
  mtxFreq := SW.Frequency;
finalization
  sw.Stop;
  {$ENDIF}

end.
