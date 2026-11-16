$ErrorActionPreference='Stop'
foreach($folder in @('../app','../sweet-sensation/app')) {
    . (Join-Path $PSScriptRoot "$folder/Core.ps1")
    $state=New-State; $state.Settings.Ready=$true
    $state.Settings.Stock=[pscustomobject]@{WD=167;JD=40;SD=9}
    $title='Private Moments'; if($folder -like '*sweet*'){$title='Sweet Sensation'}
    $expected="$title`r`nWD.41-3`r`nJD.40`r`nSD.2-1`r`nFloat :€150"
    if((Get-StockMessage $state) -cne $expected){throw 'Opening message format mismatch'}
    $state.Sales=@([pscustomobject]@{Category='WD';Quantity=7;Cents=6500;Payment='Cash'})
    Add-StockEntry $state 5 2 3
    $update="$title Update`r`nWD.41-1`r`nJD.42`r`nSD.3`r`nFloat :€150"
    if((Get-StockMessage $state -Update) -cne $update){throw 'Update must include receipts and subtract sales'}
    if((Get-StockMessage $state) -cne $expected){throw 'Restock changed opening inventory'}
    if((Get-Totals $state.Sales).WD -ne 6500){throw 'Restock changed sales revenue'}
    $restored=Upgrade-State ($state | ConvertTo-Json -Depth 8 | ConvertFrom-Json)
    if((Get-StockMessage $restored -Update) -cne $update -or @($restored.Restocks).Count -ne 1){throw 'Restock persistence failed'}
    Add-StockEntry $restored 3 0 1
    if((Get-RemainingStock $restored).WD -ne 168 -or (Get-RemainingStock $restored).SD -ne 13){throw 'Multiple receipts failed'}
    $closing=Get-ClosingReport $restored
    if(-not $closing.Contains('WD:41-3') -or -not $closing.Contains('WD.42')){throw 'Closing must preserve opening and show restocked remaining'}
    foreach($values in @(@(0,0,0),@(-1,0,0))){
        $rejected=$false; try{Add-StockEntry $restored $values[0] $values[1] $values[2]}catch{$rejected=$true}
        if(-not $rejected){throw 'Invalid receipt accepted'}
    }
    $new=New-State
    if((Get-AvailableStock $new).WD -ne 0){throw 'Restocks leaked into new shift'}
}
'PASS: exact opening/update messages, receipts, stock, unchanged revenue, closing, persistence and new shift.'
