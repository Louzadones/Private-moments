param([switch]$Package)
$ErrorActionPreference = 'Stop'
$compiler = Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if (-not (Test-Path -LiteralPath $compiler)) { $compiler = Join-Path $env:SystemRoot 'Microsoft.NET/Framework/v4.0.30319/csc.exe' }
$binary = Join-Path $PSScriptRoot 'app/Private Moments.exe'
& $compiler /nologo /target:winexe "/out:$binary" ("/win32icon:" + (Join-Path $PSScriptRoot 'app/assets/app.ico')) /reference:System.Windows.Forms.dll (Join-Path $PSScriptRoot 'src/Launcher.cs')
if ($LASTEXITCODE -ne 0) { throw 'Falha ao compilar o aplicativo.' }
if ($Package) {
    $null = New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'releases') -Force
    $files = @('Private Moments.exe','Private Moments.ps1','Core.ps1','Fechamento.txt','LEIA-ME.txt') | ForEach-Object { Join-Path $PSScriptRoot "app/$_" }
    $files += Join-Path $PSScriptRoot 'app/assets'
    Compress-Archive -LiteralPath $files -DestinationPath (Join-Path $PSScriptRoot 'releases/Private-Moments-V13.zip') -Force
}
