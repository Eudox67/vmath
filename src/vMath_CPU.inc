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
// ###################################################################
// #### contains the used cpu definitions in the project
// ###################################################################

// vmath targets x86-64. FPC defines CPUX64 (and the alias CPUX86_64) for that
// architecture, so no project-local "x64"/"x86" defines are needed:
// the 32-bit assembler implementations and their {$IFDEF x64} switches are gone.
// On any other CPU the units fall back to their Pascal implementations.
{$IFNDEF CPUX64}
  {$DEFINE VMATH_NOASM}
{$ENDIF}

// ###########################################
// #### Free Pascal specific
{$IFNDEF VMATH_NOASM}
{$ASMMODE intel} {$S-}
{$ENDIF}
