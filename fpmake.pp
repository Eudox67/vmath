program fpmake;

{$mode objfpc}{$H+}

uses
{$ifdef unix}
  cthreads,
{$endif}
  fpmkunit;

var
  P: TPackage;
begin
  with Installer do
  begin
    P := AddPackage('vmath');
    P.Version := '1.0.0';
    P.Author := 'vmath Contributors';
    P.License := 'Apache-2.0';
    P.Description := 'Double-precision matrix and numerical library for Free Pascal';

    P.OSes := [linux];
    P.CPUs := [x86_64];

    // SourcePath locates the files named in AddUnit; UnitPath feeds -Fu
    // and IncludePath feeds -Fi for the shared *.inc files.
    P.SourcePath.Add('src');
    P.UnitPath.Add('src');
    P.IncludePath.Add('src');

    // The units declare {$mode objfpc} themselves; stating it keeps the
    // package build identical to a hand-written fpc invocation.
    P.Options.Add('-Mobjfpc');

    // fpmkunit injects an implicit dependency on the "rtl" package, which
    // needs a per-package unit-config file (<unitdir>/rtl/rtl.fpc) that
    // many FPC installs do not ship; the lookup then aborts with
    //   Could not find unit directory for dependency package "rtl"
    // The compiler already knows where its own RTL is, so the dependency
    // is dropped and this package needs no external resolution.
    P.Dependencies.Clear;

    // External packages this one cannot be built without. fpmake looks
    // for their <dep>.fpm only in its own directory and in --searchpath
    // entries, so an installed dependency is otherwise reported as "Could
    // not find unit directory for dependency package". BaseInstallDir is
    // the FPC prefix when it comes from the environment and the lib/fpc
    // directory when it comes from --prefix; one of the two exists.
    Defaults.SearchPath.Add(Defaults.BaseInstallDir);
    Defaults.SearchPath.Add(Defaults.BaseInstallDir + 'lib/fpc/' + Defaults.CompilerVersion + '/');
    P.Dependencies.Add('lightstrings');

    P.Targets.AddUnit('ASMMatrixAbsOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixAddSubOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixCumSumDiffOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixElementwiseMultOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixMeanOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixMinMaxOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixMultOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixMultTransposedOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixNormOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixOperations.pas');
    P.Targets.AddUnit('ASMMatrixRotationsx64.pas');
    P.Targets.AddUnit('ASMMatrixScaleOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixSqrtOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixSumOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixTransposeOperationsx64.pas');
    P.Targets.AddUnit('ASMMatrixVectorMultOperationsx64.pas');
    P.Targets.AddUnit('ASMMoveOperationsx64.pas');
    P.Targets.AddUnit('ASMVecConvolvex64.pas');
    P.Targets.AddUnit('ASMVecDistx64.pas');
    P.Targets.AddUnit('AVXChaChax64.pas');
    P.Targets.AddUnit('AVXMatrixAbsOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixAddSubOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixCumSumDiffOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixElementwiseMultOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixMeanOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixMinMaxOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixMultOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixMultTransposedOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixNormOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixOperations.pas');
    P.Targets.AddUnit('AVXMatrixRotationsx64.pas');
    P.Targets.AddUnit('AVXMatrixScaleOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixSqrtOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixSumOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixTransposeOperationsx64.pas');
    P.Targets.AddUnit('AVXMatrixVectorMultOperationsx64.pas');
    P.Targets.AddUnit('AVXMoveOperationsx64.pas');
    P.Targets.AddUnit('AVXVecConvolvex64.pas');
    P.Targets.AddUnit('BaseMathPersistence.pas');
    P.Targets.AddUnit('BinaryReaderWriter.pas');
    P.Targets.AddUnit('BlockedMult.pas');
    P.Targets.AddUnit('BlockSizeSetup.pas');
    P.Targets.AddUnit('cbor.pas');
    P.Targets.AddUnit('CBORReadWrite.pas');
    P.Targets.AddUnit('CCA.pas');
    P.Targets.AddUnit('Corr.pas');
    P.Targets.AddUnit('CplxSimpleMatrixOperations.pas');
    P.Targets.AddUnit('CPUFeatures.pas');
    P.Targets.AddUnit('Dist.pas');
    P.Targets.AddUnit('Eigensystems.pas');
    P.Targets.AddUnit('EM.pas');
    P.Targets.AddUnit('FMAMatrixMultOperationsx64.pas');
    P.Targets.AddUnit('FMAMatrixMultTransposedOperationsx64.pas');
    P.Targets.AddUnit('FMAMatrixOperations.pas');
    P.Targets.AddUnit('FMAMatrixVectorMultOperationsx64.pas');
    P.Targets.AddUnit('FMAVecConvolvex64.pas');
    P.Targets.AddUnit('HouseholderReflectors.pas');
    P.Targets.AddUnit('ICA.pas');
    P.Targets.AddUnit('IncrementalPCA.pas');
    P.Targets.AddUnit('JSONReaderWriter.pas');
    P.Targets.AddUnit('KernelPCA.pas');
    P.Targets.AddUnit('LinAlgCholesky.pas');
    P.Targets.AddUnit('LinAlgLU.pas');
    P.Targets.AddUnit('LinAlgQR.pas');
    P.Targets.AddUnit('LinAlgSVD.pas');
    P.Targets.AddUnit('LinearAlgebraicEquations.pas');
    P.Targets.AddUnit('linuxthrpool.pas');
    P.Targets.AddUnit('MathUtilFunc.pas');
    P.Targets.AddUnit('Matrix.pas');
    P.Targets.AddUnit('MatrixASMStubSwitch.pas');
    P.Targets.AddUnit('MatrixConst.pas');
    P.Targets.AddUnit('MatrixRotations.pas');
    P.Targets.AddUnit('MtxThreadPool.pas');
    P.Targets.AddUnit('MtxTimer.pas');
    P.Targets.AddUnit('MtxUtilFunc.pas');
    P.Targets.AddUnit('NNMF.pas');
    P.Targets.AddUnit('Node2Vec.pas');
    P.Targets.AddUnit('NonLinearFit.pas');
    P.Targets.AddUnit('PCA.pas');
    P.Targets.AddUnit('PLS.pas');
    P.Targets.AddUnit('RandomEng.pas');
    P.Targets.AddUnit('RBSplines.pas');
    P.Targets.AddUnit('RollingMedMean.pas');
    P.Targets.AddUnit('Roots.pas');
    P.Targets.AddUnit('SimpleMatrixOperations.pas');
    P.Targets.AddUnit('SSA.pas');
    P.Targets.AddUnit('Statistics.pas');
    P.Targets.AddUnit('ThreadedMatrix.pas');
    P.Targets.AddUnit('ThreadedMatrixOperations.pas');
    P.Targets.AddUnit('tSNE.pas');
    P.Targets.AddUnit('Wavelets.pas');

    Run;
  end;
end.
