function Write-StoreText([string]$Path,[string]$Text) {
    $null=New-Item -ItemType Directory -Path ([IO.Path]::GetDirectoryName($Path)) -Force
    $temp=$Path+'.tmp'
    [IO.File]::WriteAllText($temp,$Text,(New-Object Text.UTF8Encoding($true)))
    if(Test-Path -LiteralPath $Path){[IO.File]::Replace($temp,$Path,$Path+'.backup')}else{[IO.File]::Move($temp,$Path)}
}
function Get-ClosedShiftPath([string]$Root,$State) {
    $id=([guid]::Parse($State.ShiftId)).ToString('N')
    return Join-Path $Root "historico/turnos/$id.json"
}
function Get-StoreLedger([string]$Root,$Active=$null) {
    $records=New-Object 'System.Collections.Generic.List[object]'
    $ids=New-Object 'System.Collections.Generic.HashSet[string]'
    $starts=New-Object 'System.Collections.Generic.HashSet[string]'
    $items=@()
    foreach($folder in @('historico/turnos','turnos')){
        $directory=Join-Path $Root $folder
        if(Test-Path -LiteralPath $directory){
            foreach($file in @(Get-ChildItem -LiteralPath $directory -Filter '*.json' -File | Sort-Object LastWriteTime -Descending)){
                try{$record=Get-Content -LiteralPath $file.FullName -Raw -Encoding UTF8 | ConvertFrom-Json}
                catch{throw "Não foi possível ler o histórico $($file.Name). Seus arquivos foram mantidos."}
                $items+= [pscustomobject]@{State=$record;Closed=$true;Path=$file.FullName}
            }
        }
    }
    if($null -ne $Active -and ($Active.Settings.Ready -or @($Active.Sales).Count -gt 0)){
        $items+= [pscustomobject]@{State=$Active;Closed=$false;Path=''}
    }
    foreach($item in $items){
        $record=$item.State
        if($null -eq $record.Sales -or -not $record.Started){throw 'Há um turno de histórico sem data ou vendas válidas.'}
        $id=[string]$record.ShiftId
        $start=[string]$record.Started
        if(($id -ne '' -and $ids.Contains($id)) -or $starts.Contains($start)){continue}
        if($id -ne ''){$null=$ids.Add($id)}
        $null=$starts.Add($start)
        if($null -eq $record.Settings){
            $record | Add-Member -NotePropertyName Settings -NotePropertyValue (New-ShiftSettings ([datetimeoffset]::Parse($start).DateTime))
        }
        $day=Get-ShiftOpeningDate $record
        $null=Get-Totals $record.Sales
        $records.Add([pscustomobject]@{State=$record;Date=$day;Closed=$item.Closed;Path=$item.Path})
    }
    return $records.ToArray()
}
function Get-LedgerTotals($Records) {
    $summary=@{WD=[long]0;Shop=[long]0;Cinema=[long]0;Total=[long]0;Shifts=0}
    foreach($record in @($Records)){
        if($null -eq $record){continue}
        $t=Get-Totals $record.State.Sales
        $summary.WD+=$t.WD+$t.JD+$t.SD; $summary.Shop+=$t.Shop; $summary.Cinema+=$t.Cinema; $summary.Shifts++
    }
    $summary.Total=$summary.WD+$summary.Shop+$summary.Cinema
    return $summary
}
function Export-MonthlySales([string]$Root,[string]$Month,$Active=$null,[datetime]$Now=(Get-Date)) {
    $date=[datetime]::ParseExact($Month,'yyyy-MM',[Globalization.CultureInfo]::InvariantCulture)
    $records=@(Get-StoreLedger $Root $Active | Where-Object {$_.Date.ToString('yyyy-MM') -eq $Month})
    $t=Get-LedgerTotals $records
    $title=$date.ToString('MMMM yyyy',[Globalization.CultureInfo]::GetCultureInfo('pt-PT')).ToUpperInvariant()
    $text="PRIVATE MOMENTS`r`nREGISTRO MENSAL — $title`r`n`r`nWD: $(Format-Money $t.WD)`r`nShop: $(Format-Money $t.Shop)`r`nCinema: $(Format-Money $t.Cinema)`r`nTOTAL:  $(Format-Money $t.Total)`r`n`r`nWD inclui os valores de WD, JD e SD.`r`nTurnos incluídos: $($t.Shifts)`r`nAtualizado: $($Now.ToString('dd/MM/yyyy HH:mm'))`r`n"
    $path=Join-Path $Root "Vendas_$Month.txt"
    Write-StoreText $path $text
    return $path
}
function Sync-MonthlySales([string]$Root,$Active=$null,[datetime]$Now=(Get-Date)) {
    $currentMonth=$Now.ToString('yyyy-MM')
    $lastDay=$Now.Day -eq [datetime]::DaysInMonth($Now.Year,$Now.Month)
    $months=@(Get-StoreLedger $Root $Active | ForEach-Object {$_.Date.ToString('yyyy-MM')} | Sort-Object -Unique)
    if($lastDay){$months=@($months + $currentMonth | Sort-Object -Unique)}
    foreach($month in $months){
        if($month -lt $currentMonth -or ($month -eq $currentMonth -and $lastDay) -or (Test-Path -LiteralPath (Join-Path $Root "Vendas_$month.txt"))){
            $null=Export-MonthlySales $Root $month $Active $Now
        }
    }
}
function Export-DailySales([string]$Root,[datetime]$Date,[datetime]$Now=(Get-Date)) {
    $records=@(Get-StoreLedger $Root | Where-Object {$_.Date.Date -eq $Date.Date})
    $t=Get-LedgerTotals $records
    $text="PRIVATE MOMENTS`r`nREGISTRO DIÁRIO — $($Date.ToString('dd/MM/yyyy'))`r`n`r`nWD: $(Format-Money $t.WD)`r`nShop: $(Format-Money $t.Shop)`r`nCinema: $(Format-Money $t.Cinema)`r`nTOTAL:  $(Format-Money $t.Total)`r`n`r`nWD inclui WD, JD e SD.`r`nTurnos fechados: $($t.Shifts)`r`nAtualizado: $($Now.ToString('dd/MM/yyyy HH:mm'))`r`n"
    $path=Join-Path $Root ('historico/diarios/Vendas_'+$Date.ToString('yyyy-MM-dd')+'.txt')
    Write-StoreText $path $text
    return $path
}
function Close-StoreShift([string]$Root,$State,[datetime]$Now=(Get-Date)) {
    Assert-ClosingReady $State
    $closing=Get-ClosingReport $State
    $path=Get-ClosedShiftPath $Root $State
    if(-not(Test-Path -LiteralPath $path)){
        $copy=($State | ConvertTo-Json -Depth 10) | ConvertFrom-Json
        $copy | Add-Member -NotePropertyName ClosedAt -NotePropertyValue $Now.ToString('o') -Force
        Write-StoreText $path ($copy | ConvertTo-Json -Depth 10)
    }
    $day=Get-ShiftOpeningDate $State
    $id=([guid]::Parse($State.ShiftId)).ToString('N')
    Write-StoreText (Join-Path $Root "historico/fechamentos/Fechamento_$($day.ToString('yyyy-MM-dd'))_$id.txt") $closing
    $null=Export-DailySales $Root $day $Now
    Sync-MonthlySales $Root $null $Now
    return $path
}
