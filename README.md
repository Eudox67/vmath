# Vmath (Vector Math): fast double-precision math for Free Pascal

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
![Free Pascal](https://img.shields.io/badge/Free_Pascal-3.2.2%2B-orange)
![Lazarus](https://img.shields.io/badge/Lazarus-vmath.lpk-1E5AA8)
![Platform](https://img.shields.io/badge/Platform-Linux_x86--64-555555?logo=linux&logoColor=white)
![SIMD](https://img.shields.io/badge/SIMD-SSE2_%7C_AVX_%7C_FMA-007EC6)
![Tests](https://img.shields.io/badge/FPCUnit-115_tests_(15_suites)-brightgreen)

Vmath is a matrix and numerical library for Free Pascal. It gives you one
matrix class (`TDoubleMatrix`) plus ready-made statistical, data-analysis and
signal routines built on it. The heavy arithmetic is tuned assembler
(SSE2/AVX/FMA) for x86-64 machines.

It is a fork of [mrMath](https://github.com/mikerabat/mrmath), converted to
plain Free Pascal (`{$mode objfpc}`), stripped of everything Delphi-specific, and 
refined where possible (statistics densities, the Kolmogorov-Smirnov tail, the wavelet
transform, ICA's whitening and projection and more).  CBOR (read and write) was added 
to remove the serialization/de-serialization time.

I made Vmath for my own use, and others who might prefer the Objfpc mode.
Vmath is an independent project - not affiliated with or endorsed by mrMath -
and keeps the upstream copyright and the Apache-2.0 licence (see [NOTICE](NOTICE)
for the formal statement).


- **115 FPCUnit tests in 15 suites** - closed forms and constants for the
  distributions, independent naive references for every matrix operation over 22
  sizes, and `A = L*L^T` / `A = U*S*V^T` / `A*v = lambda*v` for the
  factorisations;
- the four instruction tiers (**FPU, SSE, AVX, FMA**) must agree with each
  other, and Strassen with the direct multiply;
- the suites also run clean under heaptrc: no unfreed memory blocks.

Vmath targets linux because I do not have a Windows machine. A pull request that adds,
and adequately tests a windows version, is welcomed. ...or you can simply fork the
project.

Modern GPU libraries, along with CPU's that can use OneDNN (AVX512-VNNI and AVX512-VBMI),
will provide more than this library, but if those are not options, this library could 
prove useful. 

## What you can do with it

| You want to ... | Look at |
|---|---|
| create, slice, multiply, invert or decompose matrices | `Matrix`, `LinAlgCholesky`, `LinAlgLU`, `LinAlgQR`, `LinAlgSVD`, `Eigensystems` |
| describe data: densities, histograms, t and F tests, covariance | `Statistics` |
| reduce data: PCA (batch, incremental, kernel), CCA, ICA, NNMF, EM, SSA, t-SNE | `PCA`, `IncrementalPCA`, `KernelPCA`, `CCA`, `ICA`, `NNMF`, `EM`, `SSA`, `tSNE` |
| filter and fit signals: wavelets, rolling median/mean, splines, curve fitting | `Wavelets`, `RollingMedMean`, `RBSplines`, `NonLinearFit`, `Roots` |
| keep results: save and load any of it as CBOR or JSON | `BaseMathPersistence`, `CBORReadWrite`, `JSONReaderWriter` |
| use every core with the same API | `ThreadedMatrix` |

A complete program - solving a small linear system:

```pascal
program Demo;
{$mode objfpc}{$H+}
uses Matrix;

var
  a, b, x : TDoubleMatrix;
begin
  a := TDoubleMatrix.Create([4, 2, 1, 3], 2, 2);   // 2 columns, 2 rows
  b := TDoubleMatrix.Create([1, 2], 1, 2);         // one column, 2 rows
  x := a.SolveLinEQ(b);                            // solve a*x = b
  WriteLn('x = ', x[0, 0]:0:4, ', ', x[0, 1]:0:4);
  a.Free; b.Free; x.Free;
end.
```

That prints `x = -0.1000, 0.7000`. The element accessor is `Items[x, y]`, i.e.
column first - the same order the constructor reads its data in.

## What you need

| Requirement | Notes |
|---|---|
| Free Pascal | 3.2.2 or newer (developed and tested with 3.3.1) |
| System | Linux on x86-64 - the only target in this release |
| LightStrings | one small string library, installed in step 1 below |
| Lazarus | optional, only for the IDE route |

Only x86-64 Linux is supported: this tree contains no 32-bit, Windows or macOS
code. The Pascal fallbacks (`VMATH_NOASM`) exist, but the assembler units have no
portable twin.

## Step 1: install LightStrings

vmath keeps its string lists in **LightStrings** (MIT licence), a separate small
library. One command builds it and installs it into the Free Pascal installation
your compiler already uses:

```bash
./setup.sh --install
```

Run `./setup.sh` whenever you want to know whether everything is in place -
that is also what CI runs. If the LightStrings checkout is not next to vmath,
tell the script where it is:

```bash
LIGHTSTRINGS_DIR=/path/to/LightStrings ./setup.sh --install
```

## Step 2: pick how you want to use vmath

Choose the route that matches what you are doing. All three work, and you can
use more than one at the same time.

| I want to ... | Use |
|---|---|
| try it out with a single file | route A - compile straight from the checkout |
| add units to the  `uses` clause in every project | route B - install it to fpc once |
| work in the Lazarus IDE | route C - the Lazarus package |

### Route A - try it without installing anything

```bash
cd /path/to/vmath
fpc @vmath.cfg my_program.pas
./my_program
```

`vmath.cfg` is a plain text file that carries the compiler switches and unit
paths, so you do not have to type them. Keep the `fpc` call inside the vmath
directory - the paths in it are relative to where you run it - or copy the
switches into your own project.

### Route B - install it once, then just add to the `uses` clause

```bash
./setup.sh --install    # only if you skipped step 1
fpc fpmake.pp               # build the installer (one time)
./fpmake compile            # compile vmath
./fpmake install            # install into the FPC tree your compiler uses
```

`./fpmake install --prefix="$HOME/.local"` installs into your home directory
instead. In that case tell the compiler where to look by adding two lines to
`~/.fpc.cfg` (take the three parts of the path from `fpc -iV`, `fpc -iTP` and
`fpc -iTO`):

```
-Fu$HOME/.local/lib/fpc/3.3.1/units/x86_64-linux/vmath
-Fu$HOME/.local/lib/fpc/3.3.1/units/x86_64-linux/lightstrings
```

Only compiled `.ppu`/`.o` files are installed, and every package gets its own
directory, so vmath and LightStrings never overwrite each other. After this any
of your projects can use the units without extra switches.

### Route C - use it from the Lazarus IDE

*Package -> Open Package File* -> `vmath.lpk` -> **Compile** -> *Use -> Add to
Project*. The first build asks you where `lightstrings_pkg.lpk` lives; browse 
to the copy of LightStrings saved on your computer and select its 
`lightstrings_pkg.lpk` file and Lazarus will remember it.

From a script or CI:

```bash
lazbuild vmath.lpk                          # -> lib/x86_64-linux/*.ppu
lazbuild --add-package vmath.lpk my_app.lpi
lazbuild my_app.lpi
```

### Can I use more than one?

Yes. The usual combination is B + C: the installed package serves `fpc` and
`lazbuild`, and the Lazarus package gives the IDE code completion and
*Ctrl+Click* navigation.

| Setup | `fpc` | `lazbuild` | IDE completion / navigation |
|---|:-:|:-:|:-:|
| B only (installed) | yes | yes | **no** - only compiled units are installed |
| A only (`@vmath.cfg`) | yes | with the same switches in the project | no |
| C only (`vmath.lpk`) | with `-Fu src` | yes | **yes** |
| B + C | yes | yes | yes |

## Multi-threaded matrices (optional)

`TThreadedMatrix` is a drop-in replacement for `TDoubleMatrix` that spreads the
heavy operations over all cores - same API, same results (the tests compare both
at 256x256 and 768x768).

```pascal
uses
{$IFDEF UNIX}cthreads,{$ENDIF}
  Matrix, ThreadedMatrix;

var
  m : TThreadedMatrix;
  other : TDoubleMatrix;
begin
  m := TThreadedMatrix.Create(512, 512, 0);
  other := TDoubleMatrix.Create(512, 512, 0);
  m.MultInPlace(other);      // parallel
  m.Free;
  other.Free;
end;
```

A program that links the pool has to put `cthreads` in its `uses` clause on Linux,
and `cmem` before it for release builds: without `cthreads` the pool crashes
while starting, and a memory manager has to be in place before anything
allocates. `cmem` also switches off heaptrc leak reports, so leave it out while
chasing leaks.

## Running the tests

`tests/` holds FPCUnit suites (one unit per area), standalone check programs and
benchmarks. `run_tests.pas` registers all suites and runs them:

| Suite | Tests | Covers |
|---|---:|---|
| `TestMatrixCore` | 10 | `TDoubleMatrix` basics: create/dimensions, get/set, add, multiply (identity and scalar), transpose, sum, row/col mean, determinant |
| `TestNumericAudit` | 7 | differential audit: elementwise, reduction, multiply, invert, solve and statistics against independent naive references over 22 sizes (1...257, odd and even) |
| `TestLinAlgIdentities` | 4 | factorisation identities: `A = L*L^T` (Cholesky, plus a non-SPD rejection), `A = U*S*V^T` (SVD), `A*v = lambda*v` (SymEig) |
| `TestCoreCoverage` | 15 | in-place vs out-of-place equivalence (16 pairs), elementwise division, `AddAndScale`, cumulative sum/diff, Diag/Trace, SetRow/SetColumn/Swap, `SubMtx`, `Normalize`/`NormZeroMeanVarOne`, `ElementwiseNorm2`, `MultT1`/`MultT2`, `Eig`, `PseudoInversion`, Sort/Median, `RepeatMatrix`, `Reshape` |
| `TestMatrixLifecycle` | 16 | `Clone`, the `Assign` overloads, block selectors, `Append` both directions, `AsVector`, `Resize`, `SetValue`/`MaskedSetValue`, `MeanVariance`, `RollMedian`, `ElementwiseFunc`, `ScaleAndAdd` vs `AddAndScale`, `QRFull`, `HessFull`, `SolveLeastSquares`, a text-file round trip, and twelve in-place/out-of-place twin pairs |
| `TestSIMDTiers` | 8 | the four (alignment x width parity) dispatch paths with mixed strides and a padding sentinel, FPU/SSE/AVX/FMA agreement, the CPU tier actually applied, Strassen vs direct multiply, CPU feature detection |
| `TestStatistics` | 11 | closed forms and identities: factorials, the Gamma recurrence, `erf`/`erfc`, `betaI`, `P+Q=1`, the gamma series/continued fraction, covariance, the chi-square sum of squares, histograms, all density functions, the t and F statistics, the K-S distance |
| `TestPersistence` | 10 | round trips through CBOR and JSON (matrices, a trained `TMatrixPCA`, `TStatTest`, `TDistance`), byte-level determinism and idempotence, rejection of a random-byte stream, property introspection, and the CBOR frame invariants |
| `TestComplexOps` | 10 | the scalar complex functions against a hand-written reference and the algebraic identities, L1 vs euclidean norm, magnitude ordering, principal roots, Euler's identity, and the `PComplex` kernels over a non-tight stride |
| `TestAlgorithms` | 8 | `IncrementalPCA` vs batch PCA, `SSA` on a pure sine, `TRobustBSpline` through its knots, PLS on a linear response, the DWT coefficient pyramid and energy preservation |
| `TestAlgorithmQuality` | 4 | PCA reconstruction of rank-2 data, NNMF factors, EM cluster means |
| `TestRandomEng` | 5 | `raOS` (/dev/urandom), Mersenne Twister and ChaCha reproducibility |
| `TestThreadedMatrix` | 4 | `TThreadedMatrix` vs `TDoubleMatrix` for Mult/Add/Transpose at 256x256 and 768x768 (1e-10) |
| `TestTSNE` | 2 | Barnes-Hut t-SNE runs to completion and yields a finite embedding |
| `TestCBORNested` | 1 | nested-list CBOR round trip |

Standalone programs: `smoke.pas` (checks that the three installation routes
resolve and prints the CPU feature set), `test_minimal.pas`, `test_cbor.pas`,
`test_cbor_readwrite.pas` (persistence), `TestMatrixMean.pas` and
`TestAVXMeanRowUnaligned.pas` (row-mean regression), `bench_cbor.pas` and
`BenchCBORvsJSON.pas` (benchmarks).

```bash
# FPCUnit suites
mkdir -p /tmp/vm-tests/units
fpc @vmath.cfg tests/run_tests.pas -FU/tmp/vm-tests/units -FE/tmp/vm-tests
/tmp/vm-tests/run_tests --all

# smoke program
fpc @vmath.cfg tests/smoke.pas -FU/tmp/vm-tests/units -FE/tmp/vm-tests
/tmp/vm-tests/smoke
```

## API conventions

Everything in this section is verified by the suites above. Where a name suggests
something else, the table is the authority.

### Data orientation

- `Items[x, y]` is **column `x`, row `y`**, and `x` is the fastest index
  (row-major memory layout).
- Matrix data uses **one sample per column, one feature per row** throughout -
  `PCA`, `IncrementalPCA`, `KernelPCA`, `CCA`, `EM`, `NNMF`, `t-SNE`,
  `Histogram`/`Hist`: `Items[sample, feature]`.
- `TKernelPCA.KernelPCA` returns the projection as **`modes x samples`**, i.e.
  transposed with respect to the input matrix.

### `TDoubleMatrix`

| Routine | Behaviour |
|---|---|
| `Append(value, True)` | appends **columns** (heights must match); `Append(value, False)` appends **rows** (widths must match).  A mismatch raises instead of corrupting the matrix |
| `AsVector(False)` | row major (`x` fastest); `AsVector(True)` is column major |
| `MaskedSetValue(mask, ...)` | the mask **selects the elements to overwrite** (`True` = set) |
| `RollMedian(RowWise, order)` | a **causal trailing window** of at most `order` samples per row/column, returning the average of the two middle values when the window holds an even count.  `order = 5` on `1 5 2 8 3 9 4` gives `1 3 2 3.5 3 5 4` |
| `MeanVariance(RowWise=True)` | `Width = 2, Height = number of lines`, one `[mean, variance]` pair per line |
| `QRFull` | `A = Q*R` with `Q` orthogonal and `R` upper triangular; **square input only** (a rectangular input gives factors that do not multiply back to `A`) |
| `HessFull` | `A = Q*H*Q^T` with `H` Hessenberg; **square input only** |
| `SolveLeastSquares(out x, b)` | `A` is stored as *Width = unknowns, Height = equations*, `b` is `1 x equations`, `x` comes back as `1 x unknowns` (it raises `Height must be at least width` otherwise) |
| `SolveLinEQ(b)` | `b` needs **one row per equation** (the same `Height` as `A`) and one column per right-hand side; `x` comes back with that shape. A singular `A` raises `ELinEQSingularException` |
| `AddAndScale(Offset, Scale)` | **(a + Offset) * Scale**, not `a*Scale + Offset`; `ScaleAndAdd` is the other order |
| `Diff(RowWise)` | drops one column: the result is `(Width-1) x Height` |
| `Eig` / `SymEig` | `Eig` returns the eigenvalues as a **2 x n** matrix (row 0 real, row 1 imaginary); `SymEig` returns a plain vector |
| `NormZeroMeanVarOne` | standardises with the **unbiased** (n-1) variance |

### Statistics: parameters and accuracy

- `ExpPDF(x, lambda)` treats **lambda as the scale** (the mean): `f(x) = exp(-x/lambda)/lambda`.
- `WeibullPDF(x, lambda, k)` uses the **rate** form: `f(x) = k*lambda*(lambda*x)^(k-1)*exp(-(lambda*x)^k)`.
- `RayleighPDF(x, sigma)` squares sigma internally and uses it as `sigma^2`.
- `TPCA.PCA(Examples, CutEps, IsRelativeValue)`: with `IsRelativeValue=False`
  `CutEps` is a **count**, not an epsilon - it sets the variance threshold from
  the first `CutEps` eigenvalues, and `0` keeps the documented minimum of one
  mode. Pass the number of modes you want to keep.
- `betaI` is exact to machine precision for integer arguments (checked against the binomial tail).
- `errorFunc` / `GammaP` / `GammaQ` are rational approximations accurate to **~3e-9**, not to
  machine precision; the tests assert that level, so a regression is still caught.
- `FactorialF(n) = exp(gammaln(n+1))` loses relative precision as `n` grows
  (~6e-9 at `n = 20`); `Factorial(n)` is exact in `Int64` up to `n = 20`.
- `TStatTest.StudentTTest` agrees with the pooled two-sample formula to ~1e-6 (it
  accumulates the variance slightly differently); `TStatTest.FTest` is a **variance
  ratio** test, so `t^2 = F` does not hold between the two.

### Complex arithmetic (`CplxSimpleMatrixOperations`)

| Routine | Behaviour |
|---|---|
| `CAbs` / `CAbs1` | euclidean norm / **L1** norm (`|re| + |im|`) |
| `CCmp`, `CMax`, `CMin` | compare **magnitudes**, not components; `CCmp` takes an epsilon for "equal" |
| `CAddMul(x1, x2, x3)` | `x1 + x2*x3`; `CSubMul` is `x1 - x2*x3` |
| `CSqrt` | the **principal** root (so `sqrt(-1) = i`, `sqrt(-i)` has a negative imaginary part) |
| `CplxGenericMtxMult` | the ordinary product, in the same `x`-fastest layout as the inputs |
| `CplxGenericMtxMultTransp` | **`A * B^T`** - both operands must share a width, the result is `height1 x height2` |
| `CplxGenericMtxAddAndScale` | `(z + offset) * scale`; `CplxGenericMtxScaleAndAdd` is `z * scale + offset` |
| `CplGenericVecDotMult` | **no conjugation**: it is the bilinear form `sum(x_i * y_i)`, not the hermitian one |
| `CplxGenericRowSwap` / `CplxGenericColSwap` | swap by pointer: two row starts, or two strided column starts of the same buffer |

### Algorithm classes

| Class | Contract |
|---|---|
| `TMatrixPCA` | `EigVals`/`EigVecs` are only populated when the keep flags are passed to `Create` (`TMatrixPCA.Create([pcaEigVals, pcaTransposedEigVec])`); `ProjectToFeatureSpace` maps a **single** example column (`1 x features`) and `Reconstruct` maps it back |
| `TIncrementalPCA` | reproduces batch `TMatrixPCA` exactly (identical eigenvalues, same mode count) |
| `TKernelPCA` | `SetProperties(TKernelPCAProps)` + `KernelPCA(X, cutEPS, isRelativeValue, ProjData)`; the caller **creates** `ProjData` (it is filled, not assigned), `cutEPS` is a mode **count**, and the projection comes back as `modes x samples` |
| `TMatrixCCA` | samples along the **width** (`N := X.Width`, `p := X.Height`), so a 3x20 matrix is 3 samples of 20 features; `WxT`/`WyT` come back `features x features` |
| `TMatrixICA` | `NumIC` is a **count** (`0` = `min(Width, Height)`); `ProjectToFeatureSpace` and `Reconstruct` are exact inverses; `imInfomax` additionally requires `NumIC = number of features` (its mixing matrix comes from `Invert`) |
| `TSingularSpectrumAnalysis` | `CalcSSA(values, L)` + `Reconstruct(n)`; a pure sine has rank 2, so two components reproduce it and one does not |
| `TRobustBSpline` | the `breaks` list must **span the data range** (include the first and last x), otherwise `InitSpline` raises `EInvalidOp`; at the knots `EvalSpline` reproduces the data exactly |
| `TMatrixPLS` | `PLSRegress(X, Y, NComp)` + `Project(X)`; with an exactly linear response the projection tracks it at r >= 0.99 |
| `TWavelet` | the DWT is orthonormal: a constant signal gives **all detail coefficients zero** and the coefficient energy equals the input energy (Parseval); `conv` is a periodic, centred convolution and needs a 16-byte aligned filter |
| `TExpectationMax`, `TNNMF`, `TMatrixTSNE` | one sample per column; NNMF returns `V ~ W*H` with both factors non-negative |

### Persistence (`BaseMathPersistence`, `CBORReadWrite`, `JSONReaderWriter`)

- A persistable class implements `DefineProps` (write) and the `OnLoad*`
  callbacks (read). `SaveToFile` / `ReadObjFromFile` pick the format by sniffing
  the stream; `CreateMathIOReader` rewinds after `CanReadStream`, because a
  sniffing reader may consume bytes.
- JSON files are recognised by their `"Lib":"vMath"` header. The header is only
  optional when `TJsonReaderWriter` is used directly - a headerless file cannot
  be detected by the generic reader.
- CBOR frame layout: a nested object is a tag plus an indefinite map, and a
  frame ends with exactly one break - the map terminator and the stream
  finaliser are the same byte, so a stream whose last property is a nested
  object legitimately ends with two consecutive breaks. `SkipValue` consumes
  exactly one frame. `WriteFloat` only emits float32 when the double survives
  the conversion exactly.
- `PropTypeOfName` may stay unimplemented: when a name is unknown the CBOR
  reader derives the property type from the encoded value (`ctUInt`/`ctNegInt`
  -> integer, `ctFloat` -> double, `ctTextString` -> string, `ctByteString` ->
  binary, `ctTag`/`ctMap*` -> object).
- Introspection of a loaded object: `HasProperty`, `PropGetAsString`,
  `PropGetAsIntArray`. Scalars and strings come back as text, a nested object as
  its class name, an array or list as `<array N>` / `<list N>`, binary as
  `<binary N>`; absent names return the caller's default, and an empty property
  (a matrix `Name`) is reported as present with an empty value. The recorder
  manages the entries itself, because assigning an empty value through a
  name/value pair would drop the entry.
- `TDistance` persists `Rx` unconditionally: the euclidean initialisation leaves
  `fR` nil but still sets `Rx`, so a round trip exposes it.

### SIMD dispatch

- Every operation exists as an SSE2 (`ASM*`), AVX (`AVX*`) and FMA (`FMA*`)
  implementation; `MatrixASMStubSwitch` picks the fastest tier the CPU supports
  and `InitMathFunctions(itFPU|itSSE|itAVX|itFMA)` forces one.
- A forced tier is a **maximum**, never a minimum: `InitMathFunctions` applies the
  requested tier or a lower one when the CPU lacks it, so a forced AVX build also
  runs on an SSE-only machine. `GetCurCPUInstrType` reports what was applied.
- Within a tier each operation has four variants, selected by whether the
  destination and line width are 16-byte aligned and whether the width is even:
  `*AlignedEvenW`, `*AlignedOddW`, `*UnAlignedEvenW`, `*UnAlignedOddW`.
- `VMATH_NOASM` selects the Pascal implementations where a unit has one; the
  assembler units do not carry that switch.

### Interfaces (`IMatrix`) and threading

`TDoubleMatrix` implements `IMatrix` and derives from
`TBaseMathPersistence : TInterfacedObject`. What that costs:

- **It is not ARC.** In `objfpc` mode classes are not reference counted; only the
  interface is. FPC takes non-atomic fast paths for the single-owner case
  (`rtl/inc/objpas.inc`), and only genuinely shared references reach
  `interlockedincrement`/`interlockeddecrement`.
- **The threaded paths never see it.** `ThreadedMatrix`, `ThreadedMatrixOperations`
  and `BlockedMult` contain no `IMatrix` references: tasks receive raw `PDouble`
  pointers, so no reference counting happens on matrix data.
- **It can bite.** Passing a class instance into an `IMatrix` parameter lets the
  interface release destroy it while your variable still points at it; a later
  `Free` is a double free. Hold such objects in an `IMatrix` variable (and never
  `Free` them) or keep classes away from `IMatrix` parameters.
- **What it buys:** sub-matrix views (`SetSubMatrix`, `SubMtx`) share storage
  through the interface, so passing a view costs nothing, and the persistence
  layer has a common base class.

Pass `TDoubleMatrix` (the class) into task bodies rather than `IMatrix`.

## Known limitations

- `TDoubleMatrix.SVD` accepts **square** matrices only; a rectangular input raises
  `EBaseMatrixException: Dimension error`. The `LinAlgSVD`/`LinAlgQR` routines
  behind it do not share the restriction.
- The SVD factors are stored transposed relative to the textbook notation:
  `A[row=r, col=c] = sum_k U[k,r] * s[k] * V[c,k]`, with `Items[x,y]` = row y,
  column x.
- `QRFull` produces factors that do not multiply back to `A` for non-square
  input; use square input.
- `imInfomax` ICA needs `NumIC = number of features`.
- `Node2Vec` is scaffolding: `TGraph.IsConnected` always returns `True`, and
  `LoadGraphFromJSON` reads only the flat `Edges` form, not `AdjList`. It has no
  test coverage - treat walks and embeddings from it as unverified.
- t-SNE is covered only for completion, a finite embedding and the
  reconstruction properties; the Barnes-Hut tree itself is untested.
- Not covered by any test yet: `NonLinearFit`, `RollingMedMean`, `Corr`,
  `Roots`, `Node2Vec`. The SIMD primitives are exercised through the matrix API
  rather than by name, so a name-based coverage count under-reports them.

## Project layout

```
vmath/
├── src/                  # the 91 library units (flat) + vMath_CPU.inc
├── tests/                # FPCUnit suites, standalone programs, benchmarks
├── docs/                 # USAGE.md - installation detail and per-unit guidance
├── setup.sh              # installs the LightStrings dependency (the only script)
├── fpmake.pp             # route B: native FPC package installer
├── vmath.cfg             # route A: response file (no install needed)
├── vmath.lpk             # route C: Lazarus package
├── README.md
├── LICENSE               # Apache-2.0
├── NOTICE                # derivative-work statement (mrMath)
├── .gitignore
└── .gitattributes        # LF everywhere
```

## License

Apache-2.0 - see [LICENSE](LICENSE). The upstream mrMath copyright and licence
are preserved; [NOTICE](NOTICE) carries the derivative-work statement required
by Apache-2.0 section 4(d). Usage guidance beyond this file lives in
[docs/USAGE.md](docs/USAGE.md).
