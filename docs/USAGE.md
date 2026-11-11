# Using vmath

A practical guide: how to install the library, and how to use each part of it.
`README.md` carries the requirements, the API convention tables and the project
layout; this file goes deeper on the parts you actually type.

Contents

1. [Installing](#1-installing)
2. [A first program](#2-a-first-program)
3. [Matrices](#3-matrices)
4. [Linear algebra](#4-linear-algebra)
5. [Statistics](#5-statistics)
6. [Machine learning units](#6-machine-learning-units)
7. [Wavelets, splines and fitting](#7-wavelets-splines-and-fitting)
8. [Persistence](#8-persistence)
9. [Threading](#9-threading)
10. [SIMD tiers and tuning](#10-simd-tiers-and-tuning)
11. [Troubleshooting](#11-troubleshooting)

## 1. Installing

### 1.1 Prerequisites

- FPC 3.2.2 or newer, x86-64 Linux (see *Requirements* in `README.md`).
- **LightStrings**, which is a hard requirement. vmath uses its stack-based
  `TStrList` in `BaseMathPersistence` and `Matrix`, so nothing builds without it.

### 1.2 LightStrings, three states

| State | Who finds it | How |
|---|---|---|
| source checkout | `@vmath.cfg` (it carries the path), `./setup.sh --fu` | `-Fu/path/to/LightStrings/src` |
| installed package | `fpmake`, `fpc` (when `fpc.cfg` searches the units tree) | `fpmkinst/<target>/lightstrings.fpm`, units in `units/<target>/lightstrings/` |
| Lazarus link | the IDE and `lazbuild` | `<RequiredPkgs>` in `vmath.lpk` |

```bash
./setup.sh --install     # build + install into the FPC tree (the default route)
./setup.sh               # check only: fpc version, dependency, how it resolves
./setup.sh --fu          # the -Fu flag to add to your own build scripts
```

`--install` builds the sibling `../LightStrings` checkout and installs it into
the prefix of your compiler. If the checkout lives elsewhere, either set
`LIGHTSTRINGS_DIR=/path/to/LightStrings` or pass `--lightstrings DIR`.

### 1.3 Route A - try it without installing anything

```bash
cd /path/to/vmath
fpc @vmath.cfg my_program.pas
```

`vmath.cfg` holds `-Mobjfpc -Sh`, the three `src` paths and the LightStrings
path. The paths are relative, so either run `fpc` from the vmath directory or
copy the flags into your project with absolute paths.

### 1.4 Route B - install once with `fpmake`

```bash
./setup.sh --install     # LightStrings first
fpc fpmake.pp               # build the installer
./fpmake compile            # -> ./units/*.ppu
./fpmake install --prefix="$HOME/.local"
```

Then add both unit directories to `~/.fpc.cfg` (or to a project `fpc.cfg`):

```
-Fu$HOME/.local/lib/fpc/3.3.1/units/x86_64-linux/vmath
-Fu$HOME/.local/lib/fpc/3.3.1/units/x86_64-linux/lightstrings
```

Use `fpc -iV`, `fpc -iTP` and `fpc -iTO` for the three placeholders, and drop
the `--prefix` to install into the compiler's own tree instead (then
`./setup.sh` is the only command you need).

Verify the install with a throwaway program:

```pascal
program checkinstall;
{$mode objfpc}{$H+}
uses Matrix;
var m : TDoubleMatrix;
begin
  m := TDoubleMatrix.Create([1, 2, 3, 4], 2, 2);
  WriteLn('det = ', m.Determinant:0:1);
  m.Free;
end.
```

```bash
fpc checkinstall.pas && ./checkinstall      # det = -2.0
```

### 1.5 Route C - Lazarus

In the IDE: *Package -> Open Package File* -> `vmath.lpk` -> **Compile** ->
*Use -> Add to Project*. The first build asks for `lightstrings_pkg.lpk`; point
it at the LightStrings checkout once and Lazarus remembers it.

Headless:

```bash
lazbuild vmath.lpk                          # -> lib/x86_64-linux/*.ppu
lazbuild --add-package vmath.lpk my_app.lpi
lazbuild my_app.lpi
```

### 1.6 Route D - as a submodule

```bash
git submodule add <vmath-url> libs/vmath
git submodule add <lightstrings-url> libs/LightStrings
fpc -Fulibs/vmath/src -Filibs/vmath/src -Fulibs/LightStrings/src my_program.pas
```

Relative paths in `vmath.cfg` are resolved against the current directory, so a
submodule checkout is easiest to consume with explicit `-Fu` flags or your own
response file.

## 2. A first program

```pascal
program FirstVmath;
{$mode objfpc}{$H+}
uses
{$IFDEF UNIX}cthreads,{$ENDIF}   // required once the thread pool is linked
  SysUtils, Matrix;

var
  a, b, c : TDoubleMatrix;
begin
  a := TDoubleMatrix.Create([1, 2, 3, 4], 2, 2);   // 2 columns, 2 rows, row major
  b := TDoubleMatrix.CreateEye(2);
  c := a.Mult(b);
  WriteLn('det(a) = ', a.Determinant:0:3, '   trace(c) = ', c.Trace:0:3);
  a.Free;
  b.Free;
  c.Free;
end.
```

`TDoubleMatrix` is a class: whatever you `Create` you have to `Free` (or hold it
in an `IMatrix` variable and let the interface release it - see the `IMatrix`
notes in `README.md`, and never both).

## 3. Matrices

### 3.1 Orientation

`Items[x, y]` is **column x, row y**, and x is the fastest index. `Width` counts
columns, `Height` counts rows. `TDoubleMatrix.Create(data, W, H)` reads `data` in
that order.

### 3.2 Views vs copies

```pascal
sub  := m.SubMtx([1, 3], [0, 2]);   // columns 1,3 and rows 0,2 - a copy
rows := m.SubRowMtx(2, 5);          // rows 2..5
vec  := m.AsVector(False);          // row major flattening, x fastest
view := m.SubMtx(1, 3, 0, 2);       // by index range: fromCol, toCol, fromRow, toRow
```

`SetSubMatrix(x, y, w, h)` is the opposite direction: it re-points the instance at
a window of the same buffer, which is what `SubMtx` uses internally.

### 3.3 Functional vs in-place

Almost every operation has two forms: `Mult`, `Add`, `Scale`, `SQRT`, `Diff`,
`CumulativeSum`, `Sort`, `Median`, `Abs` return a new matrix; the `*InPlace`
twins modify the receiver and are the ones to use in a loop.

```pascal
c := a.Mult(b);          // c := a * b, a and b untouched
a.MultInPlace(b);        // a := a * b
c := a.Add(1.0);         // elementwise, also AddInPlace
a.ScaleAndAddInPlace(2, 3);
```

`AddAndScale(offset, scale)` is `(a + offset) * scale`; `ScaleAndAdd` is
`a * scale + offset`. The two are not interchangeable - `README.md` lists the
other conventions worth knowing (`MaskedSetValue`, `RollMedian`, `Append`,
`Eig`, ...).

## 4. Linear algebra

```pascal
x  := A.SolveLinEQ(b);                     // solve A*x = b
inv := A.Invert;                           // or Invert(out inv) : TLinEquResult
A.Cholesky(out L);                         // A = L*L^T, symmetric positive definite
A.QRFull(Q, R);                            // square input only
A.SVD(U, V, W);                            // A = U*S*V^T, W holds the singular values
A.SymEig(eigVals, eigVect);                // symmetric A: A*v = lambda*v
A.Eig(eigVals, eigVect);                   // 2 x n eigenvalues (real, imaginary)
A.SolveLeastSquares(x, b);                 // A is Width = unknowns, Height = equations
```

The `*Result` enums (`TLinEquResult`, `TSVDResult`, `TEigenvalueConvergence`)
report convergence and refinement information; `TDoubleMatrix` raises on
dimension errors instead of returning garbage.

## 5. Statistics

```pascal
uses Statistics;

WriteLn(NormalPDF(0, 0, 1):0:6);      // density
WriteLn(GammaP(2, 1.5):0:6);          // regularised lower incomplete gamma
st := TStatTest.Create;
try
  st.SetData(x, y);
  WriteLn(st.StudentTTest:0:6, ' p = ', st.StudentTTestProb:0:6);
finally
  st.Free;
end;
```

The density and distribution functions are free functions; the tests
(`TStatTest`), histograms and covariance live in classes. Exact accuracy levels
and the parameter conventions (`ExpPDF` takes the mean, `WeibullPDF` the rate)
are tabulated in `README.md`.

## 6. Machine learning units

The full contract of each class is tabulated in `README.md` (*API conventions ->
Algorithm classes*). The two things that catch people out:

- **Sample orientation**: one sample per **column**, one feature per row.
- **Keep flags**: `TMatrixPCA`/`TIncrementalPCA` only fill `EigVals`/`EigVecs`
  when you ask for them (`Create([pcaEigVals, pcaTransposedEigVec])`).

```pascal
uses Matrix, PCA, RandomEng;

var
  pcaModel : TMatrixPCA;
  data, proj, back : TDoubleMatrix;
begin
  data := TDoubleMatrix.Create(4, 10, 0);   // 4 samples (columns) of 10 features
  data.InitRandom(raMersenneTwister, 7);
  pcaModel := TMatrixPCA.Create([pcaEigVals, pcaTransposedEigVec]);
  try
    pcaModel.PCA(data, 2, False);         // 2 = number of modes, not an epsilon
    proj := pcaModel.ProjectToFeatureSpace(data.SubColMtx(0, 0));   // one example
    back := pcaModel.Reconstruct(proj);
    WriteLn(proj.Width, 'x', proj.Height, ' -> ', back.Width, 'x', back.Height);
    proj.Free;
    back.Free;
  finally
    pcaModel.Free;
    data.Free;
  end;
end;
```

Overview of the classes:

| Unit | Class | Entry point |
|---|---|---|
| `PCA` | `TMatrixPCA` | `PCA(data, numModes, False)`, `ProjectToFeatureSpace`, `Reconstruct` |
| `IncrementalPCA` | `TMatrixIncrementalPCA` | update the eigenspace sample block by sample block |
| `KernelPCA` | `TKernelPCA` | `SetProperties`, then `KernelPCA(X, cutEPS, isRelative, ProjData)` |
| `CCA` | `TMatrixCCA` | canonical correlations of two views |
| `ICA` | `TMatrixICA` | `NumIC` components, `FastICA`, `ProjectToFeatureSpace` / `Reconstruct` |
| `NNMF` | `TMatrixNNMF` | non-negative factorisation `V ~ W*H` |
| `EM` | `TExpectationMax` | Gaussian mixture by expectation maximisation |
| `SSA` | `TSingularSpectrumAnalysis` | `CalcSSA(values, L)`, `Reconstruct(n)` |
| `tSNE` | `TMatrixTSNE` | Barnes-Hut t-SNE embedding of a data matrix |
| `PLS` | `TMatrixPLS` | `PLSRegress(X, Y, NComp)`, `Project(X)` |

## 7. Wavelets, splines and fitting

```pascal
uses Types, Math, Matrix, Wavelets;

var
  wav : TWavelet;
  sig, detail : TDoubleDynArray;
  i, level : integer;
begin
  SetLength(sig, 64);
  for i := 0 to High(sig) do
    sig[i] := Sin(i * 0.3);
  wav := TWavelet.Create(wtDaubechies2);
  try
    wav.DWT(sig, 4);                       // 4 levels
    for level := 0 to wav.MaxLevel - 1 do
      detail := wav.getDetailC(level);     // TDoubleDynArray per level
  finally
    wav.Free;
  end;
end.
```

Only `wtDaubechies2` and the biorthogonal types support the DWT; the Gaussian
and Mexican-hat types exist for the continuous transform. The DWT is
orthonormal, so the coefficient energy equals the input energy.

Splines and curve fitting:

```pascal
uses Matrix, RBSplines, NonLinearFit;

// TRobustBSpline: the breaks list must span the whole data range
spline.InitSpline(x, y, breaks);
yFit := spline.EvalSpline(xEval);
```

`TRobustBSpline.InitSpline` raises `EInvalidOp` when the breaks do not cover the
first and last x; at the knots `EvalSpline` reproduces the data exactly.
`Roots` (polynomial roots), `RollingMedMean` (rolling median/mean) and
`NonLinearFit` complete this group.

## 8. Persistence

### 8.1 Built-in classes

`TDoubleMatrix`, `TMatrixPCA`, `TStatTest`, `TDistance` and the graph types
implement persistence already:

```pascal
uses BaseMathPersistence, CBORReadWrite, JSONReaderWriter;

m.SaveToFile('matrix.cbor', TCBORReaderWriter);
m.SaveToFile('matrix.json', TJsonReaderWriter);

obj := ReadObjFromFile('matrix.cbor');       // format is detected
if obj is TDoubleMatrix then
  WriteLn(TDoubleMatrix(obj).Height);
obj.Free;
```

CBOR is the compact default; JSON is meant for inspection. Both are deterministic
(saving twice gives the same bytes) and idempotent (saving a loaded object
reproduces the stream), which is what the persistence tests assert.

### 8.2 Your own class

Derive from `TBaseMathPersistence`, declare what to write in `DefineProps`, and
answer the `OnLoad*` callbacks. The class identifier is what the reader uses to
recreate the object, so it has to be unique and stable, and the class must be
registered once at startup:

```pascal
uses Types, BaseMathPersistence, CBORReadWrite;

type
  TMyData = class(TBaseMathPersistence)
  private
    FName : string;
    FValues : TDoubleDynArray;
  public
    class function ClassIdentifier : string; override;
    procedure DefineProps; override;
    procedure OnLoadStringProperty(const Name, Value : string); override;
    procedure OnLoadDoubleArr(const Name : String; const Value : TDoubleDynArray); override;
    property Name : string read FName;
    property Values : TDoubleDynArray read FValues;
  end;

class function TMyData.ClassIdentifier : string;
begin
  Result := 'MYD';
end;

procedure TMyData.DefineProps;
begin
  AddStringProperty('Name', FName);
  AddDoubleArr('Values', FValues);
end;

procedure TMyData.OnLoadStringProperty(const Name, Value : string);
begin
  if SameText(Name, 'Name') then FName := Value;
end;

procedure TMyData.OnLoadDoubleArr(const Name : String; const Value : TDoubleDynArray);
begin
  if SameText(Name, 'Values') then FValues := Value;
end;

// once, e.g. in the program's initialization section:
RegisterMathIO(TMyData);
```

Lists (`BeginList`/`AddListDoubleArr`/`OnLoadBeginList`/`OnLoadListDoubleArr`) and
nested objects (`AddObject`/`OnLoadObject`) work the same way;
`tests/TestCBORNested.pas` is a complete example of both.

You do not have to override `PropTypeOfName`: the readers take the type of an
unknown property from the encoded value. Overriding it is an optimisation and a
validation, not a requirement.

### 8.3 Inspecting a loaded object

```pascal
if loaded.HasProperty('Name') then
  WriteLn(loaded.PropGetAsString('Name'));
vals := loaded.PropGetAsIntArray('Edges');     // empty array when not recorded
```

Scalars and strings come back as text, a nested object as its class name, arrays
and lists as `<array N>` / `<list N>`, binary as `<binary N>`.

## 9. Threading

`TThreadedMatrix` is a drop-in `TDoubleMatrix` subclass that runs the heavy
operations (Mult, Add, Transpose, elementwise functions) on the thread pool. The
results are identical to the single-threaded class, which is what
`tests/TestThreadedMatrix.pas` asserts at 256x256 and 768x768.

```pascal
uses
{$IFDEF UNIX}cthreads,{$ENDIF}
  Matrix, ThreadedMatrix;

var
  m : TThreadedMatrix;
begin
  m := TThreadedMatrix.Create(512, 512, 0);
  m.InitRandom(raMersenneTwister, 42);
  m.MultInPlace(other);          // parallel
  m.Free;
end.
```

- Link `cthreads` (and `cmem` before it for release builds) - see the threading
  note in `README.md`. Without `cthreads` the pool crashes while starting.
- `TThreadedMatrix.InitThreadPool` exists for symmetry but nothing calls it: the
  pool is created lazily on first use and shut down at unit finalisation.
- Pass the **class**, not `IMatrix`, into task bodies - the threaded paths work on
  raw `PDouble` pointers and never touch reference counting.

## 10. SIMD tiers and tuning

`MatrixASMStubSwitch` decides at unit initialisation which instruction set to
use, based on CPUID and `xgetbv`:

```pascal
uses MatrixASMStubSwitch, MatrixConst;

InitMathFunctions(itAVX, False);     // force AVX (or the best tier below it)
WriteLn(GetCurCPUInstrType);         // what was actually applied
```

A forced tier is an upper bound: asking for AVX on an SSE-only CPU silently
selects SSE. `VMATH_NOASM` (compiler define) switches to the Pascal
implementations in the units that have one.

## 11. Troubleshooting

| Symptom | Cause and fix |
|---|---|
| `Can't find unit LightStrings` | the dependency is missing: run `./setup.sh --install` |
| `Can't find unit Matrix` (installed route) | the `-Fu` line is missing from `fpc.cfg`; run `./setup.sh` and compare its output |
| `Could not find unit directory for dependency package "lightstrings"` (fpmake) | LightStrings is not installed for this target; `./setup.sh --install` |
| `Ambiguous unit found: ... looks like a compiled unit` (lazbuild) | a stray `.ppu`/[.o] sits next to a `.pas` in `src/`; delete those files (`*.ppu` is gitignored, they come from a build that had no `-FU`) |
| `Broken dependency: vmath -> lightstrings_pkg` | the Lazarus package link points at a moved file; open `lightstrings_pkg.lpk` once in the IDE to re-link it |
| access violation at startup, inside the pool | `cthreads` is not linked |
| no heap report from a `-gh` build | `cmem` is linked - it replaces the memory manager, so build the leak check without it |
| JSON file rejected by `ReadObjFromFile` | the file has no `"Lib":"vMath"` header, so it cannot be sniffed; load it with `TJsonReaderWriter` directly |

Where to look next:

- `README.md` - requirements, API conventions tables, known limitations.
- `tests/` - every unit's intended usage, asserted.
- `tests/smoke.pas` - checks that the installation route resolves.
