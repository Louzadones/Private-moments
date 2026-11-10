param([switch]$Package)
$ErrorActionPreference='Stop'
$destination=Join-Path $PSScriptRoot 'sweet-sensation/app'
$null=New-Item -ItemType Directory -Path $destination -Force
function Convert-StoreText([string]$Text){
    return $Text.Replace('Private Moments','Sweet Sensation').Replace('PRIVATE MOMENTS','SWEET SENSATION').Replace('PrivateMoments','SweetSensation').Replace('private-moments','sweet-sensation')
}
foreach($name in @('Private Moments.ps1','Core.ps1','Fechamento.txt')){
    $text=Get-Content -LiteralPath (Join-Path $PSScriptRoot "app/$name") -Raw -Encoding UTF8
    $target=Join-Path $destination ($name.Replace('Private Moments','Sweet Sensation'))
    [IO.File]::WriteAllText($target,(Convert-StoreText $text),(New-Object Text.UTF8Encoding($true)))
}
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'brands/sweet-sensation/assets') -Destination $destination -Recurse -Force
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'brands/sweet-sensation/LEIA-ME.txt') -Destination $destination -Force
$launcher=Convert-StoreText (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'src/Launcher.cs') -Raw -Encoding UTF8)
$source=Join-Path $PSScriptRoot 'src/SweetSensationLauncher.cs'
[IO.File]::WriteAllText($source,$launcher,(New-Object Text.UTF8Encoding($true)))
$compiler=Join-Path $env:SystemRoot 'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if(-not(Test-Path -LiteralPath $compiler)){$compiler=Join-Path $env:SystemRoot 'Microsoft.NET/Framework/v4.0.30319/csc.exe'}
$binary=Join-Path $destination 'Sweet Sensation.exe'
& $compiler /nologo /target:winexe "/out:$binary" ("/win32icon:"+(Join-Path $destination 'assets/app.ico')) /reference:System.Windows.Forms.dll $source
if($LASTEXITCODE -ne 0){throw 'Falha ao compilar Sweet Sensation.'}
$tests=Convert-StoreText (Get-Content -LiteralPath (Join-Path $PSScriptRoot 'tests/Verify.ps1') -Raw -Encoding UTF8)
$tests=$tests.Replace("Join-Path `$PSScriptRoot '../app'","Join-Path `$PSScriptRoot '../sweet-sensation/app'")
[IO.File]::WriteAllText((Join-Path $PSScriptRoot 'tests/Verify-Sweet.ps1'),$tests,(New-Object Text.UTF8Encoding($true)))
if($Package){
    $null=New-Item -ItemType Directory -Path (Join-Path $PSScriptRoot 'releases') -Force
    $files=@('Sweet Sensation.exe','Sweet Sensation.ps1','Core.ps1','Fechamento.txt','LEIA-ME.txt','assets') | ForEach-Object {Join-Path $destination $_}
    Compress-Archive -LiteralPath $files -DestinationPath (Join-Path $PSScriptRoot 'releases/Sweet-Sensation-V1.zip') -Force
}
