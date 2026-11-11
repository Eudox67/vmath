// ###################################################################
// #### This file is part of the vmath project - a 64-bit, double-
// #### precision (mode objfpc) fork of mrMath:
// ####   https://github.com/mikerabat/mrmath
// ####
// #### Derived from mrMath. Copyright (c) 2011-2024, Michael R.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ####
// #### vmath is an independent fork.
// ###################################################################

unit MtxThreadPool;

// #####################################################
// #### Thread pool for async matrix operations stub.
// #### The real implementation is OS dependent!
// #####################################################

interface

{$MODE OBJFPC}{$H+}


type
  TMtxProc = procedure(obj : TObject);
  TMtxRecProc = procedure(rec : Pointer);

type
  IMtxAsyncCall = interface
   ['{B5263EB3-FFDE-4D66-B556-31D5E0D05BAC}']
    procedure ExecuteAsync;
    procedure Sync;
  end;
  IMtxAsyncCallGroup = interface
   ['{11438431-7A6A-4FB9-B67A-58CE23E324DB}']
   procedure AddTask(proc : TMtxProc; obj : TObject);
   procedure AddTaskRec(proc : TMtxRecProc; rec : Pointer);
   procedure SyncAll;
  end;

// ################################################
// #### interfaces that need to be implemented for external
// thread pools
type
  IMtxThreadPool = interface
    ['{9BF6425A-A6DD-466E-B642-7BE05282CADD}']
    procedure InitPool( maxNumThreads : integer );
    function CreateTaskGroup : IMtxAsyncCallGroup;
    // stops the workers; safe twice, independent of the reference count
    procedure Shutdown;
  end;

type
  TThreadPoolProviderFunc = function : IMtxThreadPool;

// these functions are called in the matrix library
procedure SetThreadPoolProvider( func : TThreadPoolProviderFunc );

procedure InitMtxThreadPool;
procedure FinalizeMtxThreadPool;
function MtxInitTaskGroup : IMtxAsyncCallGroup;

const cMaxNumCores = 64;                          // limit the maximum usabel cores

type
  TNumCoreOpt = (coAll, coRealCores, coPerformanceCores);
procedure InitNumUsedCores( optType : TNumCoreOpt );

var numUseCPUCores : NativeInt = 0;
    numCPUCores : NativeInt = 0;
    numRealCores : NativeInt = 0;             // cores without hyperthreading
    numCoresForSimpleFuncs : NativeInt = 0;   // for median and scaling operations
    numPCores : NativeInt = 0;                // performance cores
    numECores : NativeInt = 0;                // efficiency cores

implementation

uses
  SysUtils
  {$IFDEF LINUX}, linuxthrpool{$ENDIF};

// ###########################################
// #### Fallback for targets without an OS thread pool (anything but Linux):
// #### every task runs inline, so SyncAll is trivially satisfied.
// #### The Windows (IO completion ports) and macOS (GCD) pools were removed.
// ###########################################
type
  TMtxSyncTaskGroup = class(TInterfacedObject, IMtxAsyncCallGroup)
  public
    procedure AddTask(proc : TMtxProc; obj : TObject);
    procedure AddTaskRec(proc : TMtxRecProc; rec : Pointer);
    procedure SyncAll;
  end;

  TMtxSyncThreadPool = class(TInterfacedObject, IMtxThreadPool)
  public
    procedure InitPool( maxNumThreads : integer );
    function CreateTaskGroup : IMtxAsyncCallGroup;
    procedure Shutdown;
  end;

procedure TMtxSyncTaskGroup.AddTask(proc : TMtxProc; obj : TObject);
begin
  if Assigned(proc) then
    proc(obj);
end;

procedure TMtxSyncTaskGroup.AddTaskRec(proc : TMtxRecProc; rec : Pointer);
begin
  if Assigned(proc) then
    proc(rec);
end;

procedure TMtxSyncTaskGroup.SyncAll;
begin
  // the tasks ran inline - nothing to wait for
end;

procedure TMtxSyncThreadPool.InitPool( maxNumThreads : integer );
begin
  // single threaded - nothing to size
end;

function TMtxSyncThreadPool.CreateTaskGroup : IMtxAsyncCallGroup;
begin
  Result := TMtxSyncTaskGroup.Create;
end;

procedure TMtxSyncThreadPool.Shutdown;
begin
  // nothing to stop - tasks run inline
end;

function CreateSyncThreadPoolObj : IMtxThreadPool;
begin
  Result := TMtxSyncThreadPool.Create;
end;

var threadPoolProviderFunc : TThreadPoolProviderFunc;
    thrPool : IMtxThreadPool = nil;

procedure InitNumUsedCores( optType : TNumCoreOpt );
begin
     case optType of
      coAll: numUseCPUCores := numCPUCores;
      coRealCores: numUseCPUCores := numRealCores;
      coPerformanceCores: numUseCPUCores := numPCores;
     end;
end;

procedure SetThreadPoolProvider( func : TThreadPoolProviderFunc );
begin
     threadPoolProviderFunc := func;
end;

procedure InitMtxThreadPool;
begin
     if thrpool = nil then
     begin
          if not Assigned(threadPoolProviderFunc) then
             raise Exception.Create('MtxThreadPool: no thread pool provider registered');

          thrPool := threadPoolProviderFunc();
          thrPool.InitPool(numUseCPUCores);
     end;
end;

procedure FinalizeMtxThreadPool;
begin
     thrPool := nil;
end;

function MtxInitTaskGroup : IMtxAsyncCallGroup;
begin
      // nothing in the library ever called InitMtxThreadPool, so the first
      // threaded operation dereferenced a nil pool - create it lazily
     if thrPool = nil then
        InitMtxThreadPool;

     Result := thrPool.CreateTaskGroup;
end;

initialization
{$IFDEF LINUX}
  SetThreadPoolProvider( @CreateThreadPoolObj );
{$ELSE}
  SetThreadPoolProvider( @CreateSyncThreadPoolObj );
{$ENDIF}

finalization
  thrPool := nil;

end.
