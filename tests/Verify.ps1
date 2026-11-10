$ErrorActionPreference = 'Stop'
$source = Join-Path $PSScriptRoot '../app'
. (Join-Path $source 'Core.ps1')
function Assert($Condition, $Message) { if (-not $Condition) { throw $Message } }
function Sale($Category, $Payment, $Cents, $Quantity = 0) {
    [pscustomobject]@{ Id = [guid]::NewGuid().ToString(); At = (Get-Date).ToString('o'); Category = $Category; Payment = $Payment; Cents = [long]$Cents; Quantity = [long]$Quantity }
}
Assert ((ConvertTo-Cents '10,50') -eq 1050) 'comma'
Assert ((ConvertTo-Cents '0.10') -eq 10) 'cents'
foreach ($value in @('-1', '0', '1.999', 'NaN', '1e3')) {
    $failed = $false; try { $null = ConvertTo-Cents $value } catch { $failed = $true }
    Assert $failed "Accepted invalid amount: $value"
}
Assert ((Format-Stock 'WD' 238) -eq '59-2') 'Pack formatting'
Assert ((Format-Stock 'WD' 232) -eq '58') 'No zero suffix'
Assert ((Format-Stock 'SD' 3) -eq '0-3') 'Loose-only stock'
Assert ((Format-Stock 'JD' 42) -eq '42') 'JD units'
$s = New-State; $s.Settings.Ready = $true; $s.Settings.Date = '2025-11-04'
$s.Settings.Stock.WD = 238; $s.Settings.Stock.JD = 42; $s.Settings.Stock.SD = 12
$s.Sales = @((Sale 'Shop' 'Cash' 8400), (Sale 'Shop' 'Card' 7400), (Sale 'Cinema' 'Cash' 3600), (Sale 'Cinema' 'Card' 1800), (Sale 'WD' 'Cash' 6500 4), (Sale 'WD' 'Card' 1500 2))
$expected = @'
PRIVATE MOMENTS
DATE.. 04 NOVEMBER 2025
DAY..  TUESDAY
Time. 11.AM .TO .2.AM
WD:59-2
JD:42
SD:3
.....................................
Shop..cash …€.84
Shop..VISA…..€.74
.....................................
=€.158
.....................................
Cinema..cash..€.36
Cinema..VISA….€.18
.....................................
=€.54
..................................... 
WD..cash ….€.65
WD..VISA…€.15
=.€.80
.....................................
JD..CASH..€.0
JD..VISA..€.0
=.€.0
.....................................
SD..CASH..€.0
SD..VISA..€.0
=.€.0
.....................................
Total…€.80
.....................................
Overall  total.CASH€.185
Overall total VISA €.107
.....................................
=€.292
.....................................
WD.58
JD.42
SD.3
.....................................
By.. Renan 11.AM to 02.AM
FLOAT .€150
IN THE CASH REGISTER 
.....................................
'@
$actual = Get-ClosingReport $s
Assert ($actual.Replace("`r`n", "`n") -ceq $expected.Replace("`r`n", "`n")) 'Exact closing template mismatch'
$legacyNight=New-State
$legacyNight.Started='2026-11-10T00:17:47+00:00'
$legacyNight.Settings.Ready=$true; $legacyNight.Settings.Date='2026-11-10'
$legacyNight.Settings.PSObject.Properties.Remove('DateBasisVersion')
$nightReport=Get-ClosingReport $legacyNight
Assert ($nightReport.Contains('DATE.. 09 NOVEMBER 2026') -and $nightReport.Contains('DAY..  MONDAY')) 'After-midnight legacy closing must keep Monday opening date'
$legacyNight=Upgrade-State $legacyNight
Assert ($legacyNight.Settings.Date -eq '2026-11-09') 'Legacy opening date must be corrected on load'
$legacyNight=Upgrade-State $legacyNight
Assert ($legacyNight.Settings.Date -eq '2026-11-09') 'Opening date must not move back again on reopen'
$reloadedNight=Upgrade-State (($legacyNight | ConvertTo-Json -Depth 8) | ConvertFrom-Json)
Assert ((Get-ClosingReport $reloadedNight).Contains('DAY..  MONDAY')) 'Closing date must remain fixed after persistence/reopen'
$explicitDate=New-State; $explicitDate.Started='2026-11-10T00:17:47+00:00'; $explicitDate.Settings.Date='2026-11-10'
Assert ((Get-ShiftOpeningDate $explicitDate).ToString('yyyy-MM-dd') -eq '2026-11-10') 'Do not override an explicitly saved current-format opening date'
Assert ((Get-Report $s.Sales).EndsWith('TOTAL:  €292')) 'Hourly report'
$s.Sales += (Sale 'JD' 'Card' 500 1); $s.Sales += (Sale 'SD' 'Cash' 200 1)
$t = Get-Totals $s.Sales; $b = Get-Breakdown $s.Sales; $r = Get-RemainingStock $s
Assert ($b.Cash -eq 18700 -and $b.Card -eq 11200) 'Cash/card split'
Assert ($r.JD -eq 41 -and $r.SD -eq 11 -and $r.WD -eq 232) 'Stock subtraction'
Assert ((Get-Report $s.Sales).Contains('WD: €87')) 'WD includes JD/SD revenue'
Assert ((Get-Report $s.Sales).EndsWith('TOTAL:  €299')) 'All category total'
Assert ((Get-ClosingReport $s).Contains('SD.2-3')) 'SD package/loose normalization'
$s.Sales = @($s.Sales | Where-Object { $_.Category -ne 'SD' })
Assert ((Get-RemainingStock $s).SD -eq 12) 'Deletion restores inventory'
$s.Settings.Stock.WD = 1
$rejected = $false; try { $null = Get-ClosingReport $s } catch { $rejected = $true }
Assert $rejected 'Negative stock should block closing'
$old = [pscustomobject]@{ Version = 1; Started = (Get-Date).ToString('o'); Phone = ''; Sales = @([pscustomobject]@{Id='old';At=(Get-Date).ToString('o');Category='WD';Cents=4000}) }
$upgraded = Upgrade-State $old
Assert ($upgraded.Version -eq 2 -and $upgraded.Sales[0].Payment -eq 'Unknown') 'Migration must not invent payment'
$upgraded.Settings.Ready = $true; $upgraded.Settings.Stock.WD = 100
$rejected = $false; try { $null = Get-ClosingReport $upgraded } catch { $rejected = $true }
Assert $rejected 'Unclassified old sale should block closing'
Get-ChildItem -LiteralPath $source -Filter '*.ps1' | ForEach-Object {
    $tokens = $null; $errors = $null
    $null = [Management.Automation.Language.Parser]::ParseFile($_.FullName, [ref]$tokens, [ref]$errors)
    Assert ($errors.Count -eq 0) ($errors | Out-String)
}
Assert ((Get-Price 'WD' 1 1 0) -eq 6500) 'WD price'
Assert ((Get-Price 'SD' 1 1 0) -eq 8000) 'SD price'
foreach ($pair in @(@(1,2000),@(4,5500),@(5,7500),@(7,9000),@(8,11000),@(14,18000))) { Assert ((Get-Price 'JD' 0 0 $pair[0]) -eq $pair[1]) 'JD best price' }
Assert ((Get-Price 'Cinema' 0 0 3) -eq 5400) 'Cinema price'
$settings = New-ShiftSettings; $settings.Ready = $true; $settings.Date = '2026-11-09'
Assert ($null -eq (Get-DueReminder $settings ([datetime]'2026-11-09T10:59:59') ([datetime]'2026-11-09T11:00:00') '')) 'No 11am reminder'
Assert ((Get-DueReminder $settings ([datetime]'2026-11-09T11:59:59') ([datetime]'2026-11-09T12:00:00') '').Hour -eq 12) 'Noon reminder'
Assert ((Get-DueReminder $settings ([datetime]'2026-11-09T23:59:59') ([datetime]'2026-11-10T00:00:00') '').Day -eq 10) 'Midnight reminder'
Assert ((Get-DueReminder $settings ([datetime]'2026-11-10T01:59:59') ([datetime]'2026-11-10T02:00:00') '').Hour -eq 2) 'Closing reminder'
Assert ($null -eq (Get-DueReminder $settings ([datetime]'2026-11-10T02:59:59') ([datetime]'2026-11-10T03:00:00') '')) 'No 3am reminder'
Assert ($null -eq (Get-DueReminder $settings ([datetime]'2026-11-09T11:59:59') ([datetime]'2026-11-09T12:00:00') '2026-11-09T12:00:00')) 'No duplicate reminder'
for ($hour=12; $hour -le 26; $hour++) {
    $slot=([datetime]'2026-11-09').AddHours($hour)
    $expected=$slot.ToString('HH:mm') + ' — Enviar relatório'
    if($hour -eq 26){$expected+=' de fechamento'}
    Assert ((Get-ReminderText $slot) -ceq $expected) 'Reminder text must match its own hourly slot'
    Assert ((Get-NextReminder $settings $slot.AddSeconds(-1)) -eq $slot) 'Next reminder must match actual next slot'
}
Assert ($null -eq (Get-NextReminder $settings ([datetime]'2026-11-10T02:00:00'))) 'No future reminder after closing'
$calendarState=New-State; $calendarState.Settings=New-ShiftSettings ([datetime]'2026-11-10T01:00:00')
Assert ((Get-ShiftCalendarDate $calendarState ([datetime]'2026-11-10T01:00:00')).Day -eq 10) 'Blank shift calendar must follow current PC date'
Assert ((Get-ShiftCalendarDate $calendarState ([datetime]'2026-11-11T14:00:00')).Day -eq 11) 'Unstarted saved shift must refresh calendar on a new day'
$calendarState.Settings.Ready=$true
Assert ((Get-ShiftCalendarDate $calendarState ([datetime]'2026-11-11T14:00:00')).Day -eq 10) 'Registered shift must keep its registration date'
Assert ((Get-OpeningDateFromCalendar ([datetime]'2026-11-10') ([datetime]'2026-11-10T01:00:00')).Day -eq 9) 'Current calendar date must not change overnight closing opening date'
Assert ((Get-OpeningDateFromCalendar ([datetime]'2026-11-10') ([datetime]'2026-11-10T14:00:00')).Day -eq 10) 'Daytime opening date follows calendar'
$nightSettings=New-ShiftSettings ([datetime]'2026-11-10T00:17:00')
Assert ($nightSettings.Date -eq '2026-11-09') 'A new shift after midnight belongs to previous opening day'
$nightSettings.Ready=$true; $nightSettings.Date='2026-11-10'
Assert ((Get-DueReminder $nightSettings ([datetime]'2026-11-10T00:59:59') ([datetime]'2026-11-10T01:00:00') '').Hour -eq 1) 'Existing midnight shift with today date must alert at 1am today'
Assert ((Get-NextReminder $nightSettings ([datetime]'2026-11-10T00:50:00')) -eq [datetime]'2026-11-10T01:00:00') 'Show correct next 1am for midnight shift'
Assert ((Get-NextReminder $nightSettings ([datetime]'2026-11-10T01:10:00')) -eq [datetime]'2026-11-10T02:00:00') 'Next alert after 1am is closing this morning'
Assert ($nightSettings.Date -eq '2026-11-10') 'Scheduling must preserve explicitly saved report date'
$reopened=[datetime]'2026-11-10T01:12:00'
Assert ((Get-DueReminder $nightSettings (Get-ReminderCheckpoint $reopened) $reopened '').Hour -eq 1) 'Reopening at 1:12 must catch current hour'
Assert ($null -eq (Get-DueReminder $nightSettings (Get-ReminderCheckpoint $reopened) $reopened '2026-11-10T01:00:00')) 'Reopening must not repeat acknowledged current hour'
Assert ($null -eq (Get-DueReminder $settings ([datetime]'2026-11-10T01:59:00') ([datetime]'2026-11-10T14:00:00') '')) 'Do not show an old closing reminder in the afternoon'
Assert ((Get-DueReminder $settings ([datetime]'2026-11-09T12:00:00') ([datetime]'2026-11-09T15:40:00') '').Hour -eq 15) 'Resuming must use current hour only'
$smoke = Join-Path $PSScriptRoot ('qa-' + [guid]::NewGuid().ToString('N'))
$null = New-Item -ItemType Directory -Path $smoke
foreach($name in @('Private Moments.exe','Private Moments.ps1','Core.ps1','Fechamento.txt','LEIA-ME.txt','assets')) {
    Copy-Item -LiteralPath (Join-Path $source $name) -Destination $smoke -Recurse
}
$script = Get-Content -LiteralPath (Join-Path $source 'Private Moments.ps1') -Raw -Encoding UTF8
$replacement = @'
$form.Show(); [Windows.Forms.Application]::DoEvents()
if($form.Icon.Width -ne 32 -or $tray.Icon.Width -ne 16){throw 'App and tray must use correctly sized branded icons'}
if($Theme.Wine.ToArgb() -ne [Drawing.ColorTranslator]::FromHtml('#590027').ToArgb() -or $Theme.Pink.ToArgb() -ne [Drawing.ColorTranslator]::FromHtml('#F7A6CE').ToArgb()){throw 'Brand palette is incorrect'}
if($entryRows.WD.CashRadio.ForeColor.ToArgb() -ne $Theme.Wine.ToArgb()){throw 'Payment controls must use brand palette'}
if ($wdPacks.Text -ne '' -or $jdCount.Text -ne '' -or $sdPacks.Text -ne '') { throw 'Initial zero fields must be blank' }
if (-not ($wdPacks.Top -lt $jdCount.Top -and $jdCount.Top -lt $sdPacks.Top)) { throw 'Initial stock order incorrect' }
if (-not ($wdPacks.TabIndex -lt $wdLoose.TabIndex -and $wdLoose.TabIndex -lt $jdCount.TabIndex -and $jdCount.TabIndex -lt $sdPacks.TabIndex -and $sdPacks.TabIndex -lt $sdLoose.TabIndex)) { throw 'Tab order incorrect' }; $wdLoose.Focus() | Out-Null; $form.SelectNextControl($wdLoose, $true, $true, $true, $true) | Out-Null; if (-not $jdCount.Focused) { throw 'Tab from WD loose did not go to JD' }; $form.SelectNextControl($jdCount, $true, $true, $true, $true) | Out-Null; if (-not $sdPacks.Focused) { throw 'Tab from JD did not go to SD packs' }; $form.SelectNextControl($sdPacks, $true, $true, $true, $true) | Out-Null; if (-not $sdLoose.Focused) { throw 'Tab from SD packs did not go to SD loose' }; $wdPacks.Text = '59'; if ($wdPacks.Value -ne 59) { throw 'Typed quantity not parsed' }; $wdPacks.Value = 59; $wdLoose.Value = 2; $jdCount.Value = 42; $sdPacks.Value = 3
$shiftDate.Value = [datetime]'2026-11-09'; $saveSettings.PerformClick()
if ($tabs.TabPages.Contains($setupTab)) { throw 'Setup visible after save' }
if ($add.Enabled) { throw 'Empty sale must not be submittable' }
function Click-Payment($Radio) {
    $method = $Radio.GetType().GetMethod('OnClick', [Reflection.BindingFlags]'Instance,NonPublic')
    $null = $method.Invoke($Radio, @([EventArgs]::Empty))
}
foreach ($category in @('WD','JD','SD','Cinema')) {
    $r = $entryRows[$category]
    foreach ($radio in @($r.CashRadio,$r.CardRadio,$r.SplitRadio)) {
        Click-Payment $radio
        if (-not $radio.Checked) { throw 'First click must select payment' }
        Click-Payment $radio
        if ($radio.Checked) { throw 'Second click must clear payment' }
    }
    Click-Payment $r.CashRadio; Click-Payment $r.CardRadio
    if ($r.CashRadio.Checked -or -not $r.CardRadio.Checked) { throw 'Switching payment must remain exclusive' }
    Click-Payment $r.SplitRadio
    if ($r.CardRadio.Checked -or -not $r.Cash.Visible -or -not $r.Card.Visible) { throw 'Split fields must show on selection' }
    Click-Payment $r.SplitRadio
    if ($r.Cash.Visible -or $r.Card.Visible) { throw 'Split fields must hide on deselection' }
}
$entryRows.WD.Loose.Value=1
if ($add.Enabled -or $basketHint.Text -notmatch 'WD: escolha') { throw 'Missing payment guidance failed' }
$entryRows.WD.SplitRadio.Checked=$true; $entryRows.WD.Cash.Text='10'
if ($add.Enabled -or $basketHint.Text -notmatch 'faltam €5') { throw 'Split remainder feedback failed' }
$entryRows.WD.Cash.Text='20'
if ($add.Enabled -or $basketHint.Text -notmatch 'excede o total em €5') { throw 'Split excess feedback failed' }
$entryRows.WD.CashRadio.Checked=$true
if (-not $add.Enabled) { throw 'Full cash payment should enable registration' }
Reset-Entry
$entryRows.WD.Packs.Value = 1; $entryRows.WD.Loose.Value = 1
$entryRows.WD.SplitRadio.Checked = $true; $entryRows.WD.Cash.Text = '20'; $entryRows.WD.Card.Text = '45'
$entryRows.SD.Packs.Value = 1; $entryRows.SD.Loose.Value = 1
$entryRows.SD.SplitRadio.Checked = $true; $entryRows.SD.Cash.Text = '30'; $entryRows.SD.Card.Text = '50'
$entryRows.JD.Count.Value = 5; $entryRows.JD.CashRadio.Checked = $true
$entryRows.Cinema.Count.Value = 2; $entryRows.Cinema.CardRadio.Checked = $true
$entryRows.Shop.Cash.Text = '5'; $entryRows.Shop.Card.Text = '5,50'
if ($basketTotal.Text -notmatch '266.5') { throw 'Basket calculation failed' }
$add.PerformClick()
if ($script:state.Sales.Count -ne 5) { throw 'Multi-category sale failed' }
$b = Get-Breakdown $script:state.Sales
if ($b.Cash -ne 13000 -or $b.Card -ne 13650) { throw 'Split payment totals incorrect' }
$remaining = Get-RemainingStock $script:state
if ($remaining.WD -ne 233 -or $remaining.SD -ne 7 -or $remaining.JD -ne 37) { throw 'Multi-category stock incorrect' }
if ($entryRows.WD.Packs.Text -ne '' -or $entryRows.WD.CashRadio.Checked -or $entryRows.WD.SplitRadio.Checked -or $entryRows.WD.Cash.Text -ne '') { throw 'Sale not cleared' }
if ($report.Text -notmatch 'WD: €220' -or $report.Text -notmatch 'TOTAL:  €266.5') { throw 'Hourly report totals incorrect' }
if (-not $closingReport.Text.Contains('WD..cash ….€.20') -or -not $closingReport.Text.Contains('SD..VISA..€.50')) { throw 'Closing breakdown incorrect' }
# Invalid mixed payment must reject the entire basket without changing inventory.
$entryRows.WD.Loose.Value = 1; $entryRows.WD.SplitRadio.Checked = $true; $entryRows.WD.Cash.Text = '14'
$rejected = $false; try { Register-Basket } catch { $rejected = $true }
if (-not $rejected -or $script:state.Sales.Count -ne 5) { throw 'Unbalanced payment accepted' }
Reset-Entry
$entryRows.WD.Packs.Value = 1; $entryRows.WD.Loose.Value = 1
$entryRows.SD.Packs.Value = 1; $entryRows.JD.Count.Value = 8; $entryRows.Cinema.Count.Value = 1
function Capture($name) {
 [Windows.Forms.Application]::DoEvents()
 $bmp = New-Object Drawing.Bitmap($form.Width, $form.Height)
 $form.DrawToBitmap($bmp, (New-Object Drawing.Rectangle(0,0,$form.Width,$form.Height)))
 $bmp.Save((Join-Path $PSScriptRoot $name)); $bmp.Dispose()
}
$entryRows.WD.CashRadio.Checked = $true; $entryRows.JD.CardRadio.Checked = $true; $entryRows.SD.SplitRadio.Checked = $true; $entryRows.Cinema.CashRadio.Checked = $true
if ($grid.GetColumn($entryRows.Shop.Cash) -ne 4 -or $grid.GetColumn($entryRows.Shop.Card) -ne 5) { throw 'Shop payment columns incorrect' }; if ($entryRows.WD.Packs.Parent -ne $grid -or $entryRows.JD.Count.Parent -ne $grid) { throw 'Quantity inputs outside grid' }; Capture 'vendas.png'
$script:lastCheck = [datetime]'2026-11-10T01:59:59'
foreach($time in @('2026-11-09T14:00:00','2026-11-09T23:00:00','2026-11-10T00:00:00','2026-11-10T01:00:00')) {
    $now=[datetime]$time; $script:lastCheck=$now.AddSeconds(-1); $script:state.LastReminder=''
    Check-Reminder $now
    $expected=$now.ToString('HH:mm') + ' — Enviar relatório'
    if($tray.BalloonTipTitle -cne $expected -or -not $status.Text.StartsWith($expected) -or $status.Text.Contains('fechamento')){throw 'Hourly notification has wrong text/time'}
    if($tray.BalloonTipText -ne 'O relatório está pronto. Enviar relatório.'){throw 'Notification body must be concise without automatic-send disclaimer'}
    Acknowledge-Reminder
}
$script:state.Settings.Date='2026-11-10'; $script:state.LastReminder=''
$script:lastCheck=Get-ReminderCheckpoint ([datetime]'2026-11-10T01:12:00')
$form.Close(); Check-Reminder ([datetime]'2026-11-10T01:12:00')
if($tray.BalloonTipTitle -cne '01:00 — Enviar relatório' -or -not $form.Visible){throw '1am alert must work for midnight-created shift even after reopening in tray'}
Acknowledge-Reminder
$script:state.Settings.Date='2026-11-09'
$script:lastCheck = [datetime]'2026-11-10T01:59:59'
Check-Reminder ([datetime]'2026-11-10T02:00:00')
if($tray.BalloonTipTitle -cne '02:00 — Enviar relatório de fechamento'){throw 'Closing notification must be exclusive to 02:00'}
if ($tabs.SelectedTab -ne $closingTab -or $script:state.LastReminder -ne '2026-11-10T02:00:00' -or -not $script:reminderPending) { throw 'Closing notification failed' }
Acknowledge-Reminder
if ($script:reminderPending) { throw 'Notification acknowledgement failed' }
Capture 'fechamento.png'
$tabs.SelectedTab = $salesTab
$id = @($script:state.Sales | Where-Object Category -eq 'WD')[0].Id
foreach ($item in $list.Items) { if ($item.Tag -eq $id) { $item.Selected = $true } }
Edit-Selected
if ($entryRows.WD.Packs.Value -ne 1 -or $entryRows.WD.Loose.Value -ne 1) { throw 'Edit did not load separate quantities' }
$entryRows.WD.Loose.Value = 2; $entryRows.WD.Card.Text = '60'; $add.PerformClick()
if ($script:state.Sales.Count -ne 5 -or (Get-RemainingStock $script:state).WD -ne 232) { throw 'Edit stock failed' }
$entryRows.Shop.Cash.Text='12,34'
$noticeBeforeClose=$tray.BalloonTipTitle
$form.Close()
if($tray.BalloonTipTitle -ne $noticeBeforeClose){throw 'Hiding to tray must not replace notification with a minimization notice'}
if ($form.IsDisposed -or $form.Visible -or -not $tray.Visible -or -not $timer.Enabled) { throw 'Close must hide to tray and keep reminders active' }
if ($entryRows.Shop.Cash.Text -ne '12,34' -or $script:state.Sales.Count -ne 5) { throw 'Close lost draft or registered sales' }
$openTrayItem.PerformClick()
if (-not $form.Visible -or $entryRows.Shop.Cash.Text -ne '12,34') { throw 'Tray restore lost draft' }
$form.Close()
$null=[TaskbarAlert]::Restore($form.Handle)
if (-not $form.Visible) { throw 'Opening executable again must restore the hidden managed window' }
$form.Close()
$script:lastCheck=[datetime]'2026-11-10T00:59:59'; $script:state.LastReminder=''
Check-Reminder ([datetime]'2026-11-10T01:00:00')
if (-not $form.Visible -or -not $script:reminderPending) { throw 'Hidden app reminder must return to taskbar' }
Acknowledge-Reminder
$script:allowExit=$true
$form.Close()
if (-not $form.IsDisposed) { throw 'Explicit quit must close app' }
'@
$qaMutex='Local\PrivateMomentsQA-' + [guid]::NewGuid().ToString('N')
$script = $script.Replace('Local\PrivateMomentsSalesApp', $qaMutex)
Assert ($script.Contains($qaMutex)) 'UI tests must use an isolated mutex even when the real store app is running'
$script = $script.Replace('[Windows.Forms.Application]::Run($form)', $replacement)
$script = $script.Replace("[Windows.Forms.MessageBox]::Show(`$_.Exception.Message, 'Confira os dados') | Out-Null", 'throw')
$script = $script.Replace("[Windows.Forms.MessageBox]::Show(`$_.Exception.Message, 'Erro no aplicativo') | Out-Null", 'throw')
$script = "try {`r`n" + $script + "`r`n'PASS' | Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'qa-result.txt')`r`n} catch { (`$_ | Out-String) | Set-Content -LiteralPath (Join-Path `$PSScriptRoot 'qa-result.txt') }"
[IO.File]::WriteAllText((Join-Path $smoke 'Private Moments.ps1'), $script, (New-Object Text.UTF8Encoding($true)))
$launcher = Start-Process -FilePath (Join-Path $smoke 'Private Moments.exe') -PassThru -Wait
$deadline = (Get-Date).AddSeconds(25); $resultPath = Join-Path $smoke 'qa-result.txt'
while (-not (Test-Path -LiteralPath $resultPath) -and (Get-Date) -lt $deadline) { Start-Sleep -Milliseconds 100 }
Assert (Test-Path -LiteralPath $resultPath) 'UI test timeout'
$result = Get-Content -LiteralPath $resultPath -Raw
Assert ($result.Trim() -eq 'PASS') $result
$saved = Get-Content -LiteralPath (Join-Path $smoke 'dados.json') -Raw -Encoding UTF8 | ConvertFrom-Json
Assert ($saved.Sales.Count -eq 5 -and (Get-RemainingStock $saved).WD -eq 232) 'Persistence'
"PASS: prices, JD combinations, multi-category basket, split payments, exact closing template, inventory, editing, reminder boundaries, taskbar API and persistence. Screenshots: $smoke"
