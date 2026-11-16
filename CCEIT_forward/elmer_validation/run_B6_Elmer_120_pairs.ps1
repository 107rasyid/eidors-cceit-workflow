param(
    [string]$ElmerSolverPath = $env:ELMER_SOLVER,
    [string]$OctaveCliPath = $env:OCTAVE_CLI
)

$ErrorActionPreference = 'Stop'
$validationDir = $PSScriptRoot
$projectDir = Split-Path -Parent $validationDir
$meshSource = Join-Path $validationDir 'elmer_case\mesh'
$runRoot = Join-Path $validationDir 'results\b6_basis_runs'
$resultDir = Join-Path $validationDir 'results'

if (-not $ElmerSolverPath) {
    $solverCommand = Get-Command 'ElmerSolver.exe' -ErrorAction SilentlyContinue
    if ($solverCommand) { $ElmerSolverPath = $solverCommand.Source }
}
if (-not $ElmerSolverPath) {
    $candidate = 'C:\Program Files\Elmer 26.1-Release\bin\ElmerSolver.exe'
    if (Test-Path -LiteralPath $candidate) { $ElmerSolverPath = $candidate }
}
if (-not $ElmerSolverPath -or -not (Test-Path -LiteralPath $ElmerSolverPath)) {
    throw 'Set ELMER_SOLVER to the full path of ElmerSolver.exe, or add it to PATH.'
}

if (-not $OctaveCliPath) {
    $octaveCommand = Get-Command 'octave-cli.exe' -ErrorAction SilentlyContinue
    if ($octaveCommand) { $OctaveCliPath = $octaveCommand.Source }
}
if (-not $OctaveCliPath) {
    $candidate = 'C:\Program Files\GNU Octave\Octave-11.3.0\mingw64\bin\octave-cli.exe'
    if (Test-Path -LiteralPath $candidate) { $OctaveCliPath = $candidate }
}
if (-not $OctaveCliPath -or -not (Test-Path -LiteralPath $OctaveCliPath)) {
    throw 'Set OCTAVE_CLI to octave-cli.exe. It is used only to assemble the 120 CSV rows.'
}

$meshFiles = @('mesh.header', 'mesh.nodes', 'mesh.elements', 'mesh.boundary')
foreach ($name in $meshFiles) {
    $source = Join-Path $meshSource $name
    if (-not (Test-Path -LiteralPath $source) -or (Get-Item -LiteralPath $source).Length -eq 0) {
        throw "Missing/empty B6 mesh file: $source. Restore the reference mesh first."
    }
}
New-Item -ItemType Directory -Force -Path $runRoot, $resultDir | Out-Null

for ($basis = 1; $basis -le 16; $basis++) {
    $basisName = 'basis_{0:D2}' -f $basis
    $basisDir = Join-Path $runRoot $basisName
    $basisMesh = Join-Path $basisDir 'mesh'
    New-Item -ItemType Directory -Force -Path $basisMesh | Out-Null
    foreach ($name in $meshFiles) {
        Copy-Item -LiteralPath (Join-Path $meshSource $name) -Destination (Join-Path $basisMesh $name) -Force
    }

    $bc = [System.Collections.Generic.List[string]]::new()
    for ($electrode = 1; $electrode -le 16; $electrode++) {
        $boundaryId = 10 + $electrode
        $voltage = if ($electrode -eq $basis) { '1' } else { '0' }
        $bc.Add(@"
Boundary Condition $electrode
  Name = "Electrode $electrode - basis $basis"
  Target Boundaries(1) = $boundaryId
  Potential 1 = Real $voltage
  Potential 2 = Real 0
End
"@.Trim())
    }

    $sif = @"
Header
  CHECK KEYWORDS Warn
  Mesh DB "." "mesh"
  Results Directory ""
End

Simulation
  Max Output Level = 5
  Coordinate System = "Cartesian 2D"
  Simulation Type = Steady State
  Steady State Max Iterations = 1
  Output Intervals = 1
  Angular Frequency = 3141592.653589793
  Post File = "$basisName.vtu"
End

Constants
  Permittivity of Vacuum = 8.8541878128e-12
End

Equation 1
  Name = "Harmonic current conduction"
  Active Solvers(1) = 1
End

Solver 1
  Exec Solver = Always
  Equation = "Harmonic current conduction"
  Procedure = "StatCurrentSolve" "StatCurrentSolver"
  Variable = Potential
  Variable DOFs = 1
  Harmonic Mode = Logical True
  Calculate Volume Current = Logical True
  Calculate Joule Heating = Logical False
  Linear System Solver = Direct
  Linear System Direct Method = UMFPACK
End

Material 1
  Name = "Water phantom medium"
  Electric Conductivity = Real 0.025
  Relative Permittivity = Real 80
End

Material 2
  Name = "Explicit dielectric ring"
  Electric Conductivity = Real 1e-12
  Relative Permittivity = Real 3
End

Body 1
  Name = "Medium"
  Target Bodies(1) = 1
  Equation = 1
  Material = 1
End

Body 2
  Name = "Dielectric ring"
  Target Bodies(1) = 2
  Equation = 1
  Material = 2
End

$($bc -join "`r`n`r`n")
"@
    $sifPath = Join-Path $basisDir "$basisName.sif"
    Set-Content -LiteralPath $sifPath -Value $sif -Encoding ascii
    $logPath = Join-Path $basisDir "$basisName.log"
    Write-Host "Running Elmer port basis $basis/16..."
    Push-Location $basisDir
    try {
        & $ElmerSolverPath "$basisName.sif" 2>&1 | Tee-Object -FilePath $logPath
        if ($LASTEXITCODE -ne 0) { throw "Elmer failed for $basisName; see $logPath" }
    }
    finally { Pop-Location }
    $vtuPath = Join-Path $basisMesh "$($basisName)_t0001.vtu"
    if (-not (Test-Path -LiteralPath $vtuPath) -or (Get-Item -LiteralPath $vtuPath).Length -eq 0) {
        throw "Elmer did not produce $vtuPath; see $logPath"
    }
}

$env:CCEIT_ELMER_RUN_ROOT = $runRoot
$octaveAddPath = $validationDir.Replace('\','/')
Write-Host 'Collecting port currents and forming all 120 floating-electrode responses...'
& $OctaveCliPath --quiet --no-gui --eval "addpath('$octaveAddPath'); collect_B6_Elmer_120_pairs();"
if ($LASTEXITCODE -ne 0) { throw 'Octave current extraction failed; inspect the error above.' }
Write-Host "Done. Results are in: $resultDir"
