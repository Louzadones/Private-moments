param([string]$ReferencePath)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Drawing
Add-Type -Path (Join-Path $PSScriptRoot 'LogoAssets.cs') -ReferencedAssemblies System.Drawing
if (-not $ReferencePath) { $ReferencePath=Join-Path $PSScriptRoot 'logo-reference.png' }
$destination=Join-Path $PSScriptRoot '../app/assets'
[LogoAssets]::Create($ReferencePath,$destination)
$image=[Drawing.Bitmap]::new((Join-Path $destination 'logo.png'))
try {
    $colors=New-Object 'System.Collections.Generic.HashSet[int]'
    for($y=0;$y -lt $image.Height;$y++){for($x=0;$x -lt $image.Width;$x++){
        $c=$image.GetPixel($x,$y)
        if($c.A -eq 255){$null=$colors.Add($c.ToArgb())}
        elseif($c.A -ne 0){throw 'Logo must not have partially transparent interior pixels.'}
    }}
    if($colors.Count -ne 2){throw 'Logo must use exactly two opaque flat colors.'}
    'PASS: logo uses exactly two flat colors, with fully opaque artwork and transparent exterior.'
} finally {$image.Dispose()}
