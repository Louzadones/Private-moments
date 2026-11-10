function ConvertTo-Cents([string]$Text, [switch]$AllowZero) {
    $clean = $Text.Trim()
    if ($clean -notmatch '^\d{1,7}([.,]\d{1,2})?$') { throw 'Digite um valor como 10, 10,50 ou 10.50 (sem o símbolo €).' }
    $number = [decimal]::Parse($clean.Replace(',', '.'), [Globalization.CultureInfo]::InvariantCulture)
    if (-not $AllowZero -and $number -le 0) { throw 'O valor precisa ser maior que zero.' }
    return [long]($number * 100)
}
function Format-Number([long]$Cents) { return ([decimal]$Cents / 100).ToString('0.##', [Globalization.CultureInfo]::InvariantCulture) }
function Format-Money([long]$Cents) { return '€' + (Format-Number $Cents) }
function Format-Stock([string]$Category, [long]$Units) {
    if ($Category -eq 'JD') { return [string]$Units }
    $packs = [long][math]::Floor($Units / 4); $loose = $Units % 4
    if ($loose -gt 0) { return "$packs-$loose" }
    return [string]$packs
}
function New-ShiftSettings([datetime]$Now = (Get-Date)) {
    $shiftDay=$Now.Date
    if($Now.Hour -lt 3){$shiftDay=$shiftDay.AddDays(-1)}
    return [pscustomobject]@{
        Ready = $false; Date = $shiftDay.ToString('yyyy-MM-dd'); Name = 'Renan'
        StartTime = '11.AM'; EndTime = '02.AM'; Float = [long]15000
        Stock = [pscustomobject]@{ WD = 0; JD = 0; SD = 0 }
    }
}
function Get-Report($Sales) {
    $t = Get-Totals $Sales
    return "Private Moments`r`nWD: $(Format-Money ($t.WD + $t.JD + $t.SD))`r`nShop: $(Format-Money $t.Shop)`r`nCinema: $(Format-Money $t.Cinema)`r`nTOTAL:  $(Format-Money ($t.WD + $t.JD + $t.SD + $t.Shop + $t.Cinema))"
}
function Get-ClosingReport($State) {
    Assert-ClosingReady $State
    $b = Get-Breakdown $State.Sales; $t = Get-Totals $State.Sales
    $stock = Get-RemainingStock $State
    $date = [datetime]::ParseExact($State.Settings.Date, 'yyyy-MM-dd', [Globalization.CultureInfo]::InvariantCulture)
    $tokens = @{
        DATE = $date.ToString('dd MMMM yyyy', [Globalization.CultureInfo]::GetCultureInfo('en-GB')).ToUpperInvariant()
        DAY = $date.ToString('dddd', [Globalization.CultureInfo]::GetCultureInfo('en-GB')).ToUpperInvariant()
        INITIAL_WD = (Format-Stock 'WD' $State.Settings.Stock.WD); INITIAL_JD = (Format-Stock 'JD' $State.Settings.Stock.JD); INITIAL_SD = (Format-Stock 'SD' $State.Settings.Stock.SD)
        FINAL_WD = (Format-Stock 'WD' $stock.WD); FINAL_JD = (Format-Stock 'JD' $stock.JD); FINAL_SD = (Format-Stock 'SD' $stock.SD)
        NAME = [string]$State.Settings.Name
        PRODUCTS_TOTAL = (Format-Number ($t.WD + $t.JD + $t.SD))
        CASH = (Format-Number $b.Cash); CARD = (Format-Number $b.Card)
        GRAND_TOTAL = (Format-Number ($b.Cash + $b.Card))
    }
    foreach ($c in @('WD', 'JD', 'SD', 'Shop', 'Cinema')) {
        $tokens[$c.ToUpperInvariant() + '_CASH'] = Format-Number $b[$c].Cash
        $tokens[$c.ToUpperInvariant() + '_CARD'] = Format-Number $b[$c].Card
        $tokens[$c.ToUpperInvariant() + '_TOTAL'] = Format-Number $t[$c]
    }
    $template = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Fechamento.txt') -Raw -Encoding UTF8
    return [regex]::Replace($template.TrimEnd("`r", "`n"), '\{\{([A-Z_]+)\}\}', { param($m)
        $key = $m.Groups[1].Value
        if (-not $tokens.ContainsKey($key)) { throw "Campo desconhecido no modelo: $key" }
        return [string]$tokens[$key]
    }).Replace("`r`n", "`n").Replace("`n", "`r`n")
}
function New-State {
    return [pscustomobject]@{ Version = 2; LastReminder = ''; Started = (Get-Date).ToString('o'); Phone = ''; Settings = (New-ShiftSettings); Sales = @() }
}
function Get-Totals($Sales) {
    $t = @{}; foreach ($c in @('WD', 'JD', 'SD', 'Shop', 'Cinema')) { $t[$c] = [long]0 }
    foreach ($sale in @($Sales)) {
        if ($null -eq $sale) { continue }
        if (-not $t.ContainsKey([string]$sale.Category) -or [long]$sale.Cents -le 0) { throw 'Registro de venda inválido.' }
        $t[[string]$sale.Category] += [long]$sale.Cents
    }
    return $t
}
function Get-SoldQuantities($Sales) {
    $q = @{ WD = [long]0; JD = [long]0; SD = [long]0 }
    foreach ($sale in @($Sales)) {
        if ($null -ne $sale -and $q.ContainsKey([string]$sale.Category)) { $q[[string]$sale.Category] += [long]$sale.Quantity }
    }
    return $q
}
function Get-RemainingStock($State) {
    $sold = Get-SoldQuantities $State.Sales
    return @{ WD = ([long]$State.Settings.Stock.WD - $sold.WD); JD = ([long]$State.Settings.Stock.JD - $sold.JD); SD = ([long]$State.Settings.Stock.SD - $sold.SD) }
}
function Get-Breakdown($Sales) {
    $b = @{ Cash = [long]0; Card = [long]0; Unknown = [long]0 }
    foreach ($c in @('WD', 'JD', 'SD', 'Shop', 'Cinema')) { $b[$c] = @{ Cash = [long]0; Card = [long]0; Unknown = [long]0 } }
    foreach ($sale in @($Sales)) {
        if ($null -eq $sale) { continue }
        if ($sale.Payment -eq 'Split') {
            if ([long]$sale.CashCents + [long]$sale.CardCents -ne [long]$sale.Cents -or [long]$sale.CashCents -lt 0 -or [long]$sale.CardCents -lt 0) { throw 'Divisão de pagamento inválida.' }
            $b[[string]$sale.Category].Cash += [long]$sale.CashCents; $b.Cash += [long]$sale.CashCents
            $b[[string]$sale.Category].Card += [long]$sale.CardCents; $b.Card += [long]$sale.CardCents
            continue
        }
        $p = [string]$sale.Payment
        if ($p -notin @('Cash', 'Card', 'Unknown')) { throw 'Forma de pagamento inválida.' }
        $b[[string]$sale.Category][$p] += [long]$sale.Cents
        $b[$p] += [long]$sale.Cents
    }
    return $b
}
function Assert-ClosingReady($State) {
    if (-not $State.Settings.Ready) { throw 'Preencha e salve os dados em Início do turno.' }
    foreach ($sale in @($State.Sales)) {
        if ($sale.Payment -notin @('Cash', 'Card', 'Split')) { throw 'Há vendas antigas sem forma de pagamento. Edite essas vendas antes do fechamento.' }
        if ($sale.Category -in @('WD', 'JD', 'SD') -and [long]$sale.Quantity -lt 1) { throw 'Há vendas sem quantidade. Edite essas vendas antes do fechamento.' }
    }
    $remaining = Get-RemainingStock $State
    foreach ($c in @('WD', 'JD', 'SD')) { if ($remaining[$c] -lt 0) { throw "Estoque de $c negativo. Confira o estoque inicial e as vendas." } }
}
function Get-Price([string]$Category, [int]$Packs, [int]$Loose, [int]$Count) {
    switch ($Category) {
        WD { return [long]($Packs * 5000 + $Loose * 1500) }
        SD { return [long]($Packs * 6000 + $Loose * 2000) }
        Cinema { return [long]($Count * 1800) }
        JD {
            if ($null -eq $script:jdPrices) { $script:jdPrices = New-Object 'System.Collections.Generic.List[long]'; $script:jdPrices.Add(0) }
            for ($i = $script:jdPrices.Count; $i -le $Count; $i++) {
                $best = $script:jdPrices[$i - 1] + 2000
                if ($i -ge 4) { $best = [math]::Min($best, $script:jdPrices[$i - 4] + 5500) }
                if ($i -ge 7) { $best = [math]::Min($best, $script:jdPrices[$i - 7] + 9000) }
                $script:jdPrices.Add([long]$best)
            }
            return $script:jdPrices[$Count]
        }
    }
}
function Get-DueReminder($Settings, [datetime]$After, [datetime]$Now, [string]$LastReminder) {
    if (-not $Settings.Ready -or $Now -lt $After) { return $null }
    $day = Get-ReminderDay $Settings $Now
    $due = $null
    for ($hour = 12; $hour -le 26; $hour++) {
        $slot = $day.AddHours($hour)
        if ($slot -gt $After -and $slot -le $Now -and $slot -ge $Now.Date.AddHours($Now.Hour) -and $slot.ToString('s') -ne $LastReminder) { $due = $slot }
    }
    return $due
}
function Get-ReminderText([datetime]$Slot) {
    $text = $Slot.ToString('HH:mm') + ' — Enviar relatório'
    if ($Slot.Hour -eq 2) { $text += ' de fechamento' }
    return $text
}
function Get-ReminderDay($Settings,[datetime]$Now) {
    $day=[datetime]::ParseExact($Settings.Date,'yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture)
    # After midnight, a shift entered with today's date still closes this morning.
    # Keep the report's explicitly saved date unchanged; adjust scheduling only.
    if($Now.Hour -lt 3 -and $day.Date -eq $Now.Date){$day=$day.AddDays(-1)}
    return $day
}
function Get-ReminderCheckpoint([datetime]$Now) {
    # On reopening, catch this hour once; persisted LastReminder prevents duplicates.
    return $Now.Date.AddHours($Now.Hour).AddTicks(-1)
}
function Get-NextReminder($Settings, [datetime]$Now) {
    if (-not $Settings.Ready) { return $null }
    $day = Get-ReminderDay $Settings $Now
    for ($hour = 12; $hour -le 26; $hour++) {
        $slot = $day.AddHours($hour)
        if ($slot -gt $Now) { return $slot }
    }
    return $null
}
function Upgrade-State($State) {
    if ($State.Version -eq 1) {
        $State | Add-Member -NotePropertyName Settings -NotePropertyValue (New-ShiftSettings)
        foreach ($sale in @($State.Sales)) {
            $sale | Add-Member -NotePropertyName Payment -NotePropertyValue 'Unknown'
            $sale | Add-Member -NotePropertyName Quantity -NotePropertyValue 0
        }
        $State.Version = 2
    }
    if ($State.Version -ne 2 -or $null -eq $State.Sales -or $null -eq $State.Settings -or $null -eq $State.Started) { throw 'Formato de dados desconhecido.' }
    $null = Get-Totals $State.Sales; $null = Get-Breakdown $State.Sales
    return $State
}
