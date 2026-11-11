// ###########################################################
// #### vmath - double-precision matrix and numerical library
// ####
// #### Copyright 2026 Eudox67. All rights reserved.
// #### Licensed under the Apache License, Version 2.0 - see LICENSE.
// ###########################################################
// Smoke test: resolves the package through any of the three install routes
// and prints the detected CPU feature set.
program smoke;

{$mode objfpc}{$H+}

uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required by the thread pool (see README)
  SysUtils, MatrixConst, CPUFeatures;

begin
  WriteLn('sse3: ', IsSSE3Present);
  WriteLn('avx : ', IsAVXPresent);
  WriteLn('fma : ', IsFMAPresent);
  WriteLn('vmath units resolved');
end.
