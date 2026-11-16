# Presentation only: the existing controls retain all validation and persistence handlers.
function Show-StockMessage([switch]$Update) {
    if(-not $script:state.Settings.Ready){throw 'Salve os dados iniciais do turno primeiro.'}
    $dialog=New-Object Windows.Forms.Form
    $dialog.Text='Estoque para WhatsApp'; $dialog.ClientSize=New-Object Drawing.Size(440,255)
    $dialog.StartPosition='CenterParent'; $dialog.Font=$form.Font; $dialog.BackColor=$Theme.Canvas; $dialog.ForeColor=$Theme.Text
    $text=Textbox $dialog 20 20 400; $text.Multiline=$true; $text.ReadOnly=$true; $text.Height=155
    $text.Text=Get-StockMessage $script:state -Update:$Update
    $copy=Button $dialog 'Copiar texto' 20 193 190 { [Windows.Forms.Clipboard]::SetText($text.Text); $copy.Text='Copiado!' }
    $null=Button $dialog 'Fechar' 230 193 190 { $dialog.Close() }
    try{$null=$dialog.ShowDialog($form)}finally{$dialog.Dispose()}
}
function Show-Restock {
    if(-not $script:state.Settings.Ready){throw 'Salve os dados iniciais do turno primeiro.'}
    $dialog=New-Object Windows.Forms.Form
    $dialog.Text='Entrada de estoque'; $dialog.ClientSize=New-Object Drawing.Size(540,515)
    $dialog.StartPosition='CenterParent'; $dialog.Font=$form.Font; $dialog.BackColor=$Theme.Canvas; $dialog.ForeColor=$Theme.Text
    $null=Label $dialog 'Informe apenas o que chegou agora.' 20 15 500 12 30
    $null=Label $dialog 'Produto' 20 60 110
    $null=Label $dialog 'Pacotes de 4' 150 60 150
    $null=Label $dialog 'Avulsos / unidades' 330 60 190
    $null=Label $dialog 'WD' 20 99 110; $wd=Numberbox $dialog 150 98 140; $wl=Numberbox $dialog 330 98 150 3
    $null=Label $dialog 'JD' 20 144 110; $jd=Numberbox $dialog 330 143 150
    $null=Label $dialog 'SD' 20 189 110; $sd=Numberbox $dialog 150 188 140; $sl=Numberbox $dialog 330 188 150 3
    $wd.TabIndex=0; $wl.TabIndex=1; $jd.TabIndex=2; $sd.TabIndex=3; $sl.TabIndex=4
    $result=Textbox $dialog 20 285 500; $result.Multiline=$true; $result.ReadOnly=$true; $result.Height=150
    $apply=Button $dialog 'Registrar entrada' 20 235 235 {
        Run-Action {
            if(Test-Path -LiteralPath (Get-ClosedShiftPath $PSScriptRoot $script:state)){throw 'Este turno já foi fechado.'}
            Add-StockEntry $script:state ([long]($wd.Value*4+$wl.Value)) ([long]$jd.Value) ([long]($sd.Value*4+$sl.Value))
            Save-State; Refresh-View; Update-Prices
            $result.Text=Get-StockMessage $script:state -Update
            $apply.Enabled=$false; $copy.Enabled=$true
            foreach($inputBox in @($wd,$wl,$jd,$sd,$sl)){$inputBox.Enabled=$false}
            $status.Text='Reabastecimento salvo. Copie o texto de Update.'
        }
    }
    $copy=Button $dialog 'Copiar Update' 20 457 235 { [Windows.Forms.Clipboard]::SetText($result.Text); $copy.Text='Copiado!' }; $copy.Enabled=$false
    $null=Button $dialog 'Fechar' 285 457 235 { $dialog.Close() }
    try{$null=$dialog.ShowDialog($form)}finally{$dialog.Dispose()}
}
$form.SuspendLayout()
$form.MaximumSize = New-Object Drawing.Size(0,0)
$form.MinimumSize = New-Object Drawing.Size(0,0)
$form.ClientSize = New-Object Drawing.Size(1250,815)
$form.MinimumSize = $form.Size
$form.AutoScroll = $true
$menu.Visible = $false
$header.Visible = $false
$tabs.Appearance = 'FlatButtons'; $tabs.SizeMode = 'Fixed'
$tabs.ItemSize = New-Object Drawing.Size(0,1)
$tabs.SetBounds(240,110,996,633)
$tabs.Anchor = 'Top,Left'
$side = New-Object Windows.Forms.Panel
$side.SetBounds(0,0,220,815); $side.BackColor = [Drawing.ColorTranslator]::FromHtml('#FCFAFB')
$side.Anchor='Top,Bottom,Left'; $form.Controls.Add($side)
$side.Add_Paint({param($sender,$e) $p=New-Object Drawing.Pen($Theme.Line); try{$e.Graphics.DrawLine($p,$sender.Width-1,0,$sender.Width-1,$sender.Height)}finally{$p.Dispose()}})
$brandLogo=New-Object Windows.Forms.PictureBox
$brandLogo.SetBounds(18,28,44,44); $brandLogo.Image=$logoImage; $brandLogo.SizeMode='Zoom'; $side.Controls.Add($brandLogo)
$brandName=Label $side 'PRIVATE MOMENTS' 72 29 145 11 24
$brandName.Font=New-Object Drawing.Font('Segoe UI',10,[Drawing.FontStyle]::Bold)
$brandName.ForeColor=$Theme.Wine
$brandCaption=Label $side 'CONTROLE DA LOJA' 73 54 140 8 22; $brandCaption.ForeColor=$Theme.Muted
$script:navButtons=@{}
$navY=116
foreach($definition in @(@('Vendas e relatórios',$salesTab),@('Fechamento detalhado',$closingTab),@('Histórico',$historyTab))){
    $nav=Button $side $definition[0] 12 $navY 196 {}
    $nav.Height=48; $nav.Tag=$definition[1]; $nav.FlatAppearance.BorderSize=2
    $nav.Add_Click({param($sender,$e) $tabs.SelectedTab=$sender.Tag})
    $script:navButtons[$definition[0]]=$nav; $navY+=60
}
$restockNav=Button $side 'Entrada de estoque' 12 330 196 { Run-Action { Show-Restock } }; $restockNav.Height=44
$initialNav=Button $side 'Texto do estoque inicial' 12 386 196 { Run-Action { Show-StockMessage } }; $initialNav.Height=44
$updateNav=Button $side 'Texto Update atual' 12 442 196 { Run-Action { Show-StockMessage -Update } }; $updateNav.Height=44
$setupNav=Button $side 'Turno e estoque' 12 627 196 { Run-Action { Show-Setup } }
$setupNav.Anchor='Bottom,Left'; $setupNav.FlatAppearance.BorderSize=2
$exitNav=Button $side 'Sair do aplicativo' 12 669 196 { Request-Exit }
$exitNav.Anchor='Bottom,Left'; $exitNav.FlatAppearance.BorderSize=2
$localLabel=Label $side '●  100% local' 20 740 180 10 24; $localLabel.Anchor='Bottom,Left'; $localLabel.ForeColor=$Theme.Wine
$localNote=Label $side 'Salvo neste computador.' 20 766 190 9 24; $localNote.Anchor='Bottom,Left'; $localNote.ForeColor=$Theme.Muted
$eyebrow=Label $form 'PRIVATE MOMENTS / PAINEL DA LOJA' 255 18 700 9 22; $eyebrow.ForeColor=$Theme.Wine
$pageTitle=Label $form '' 253 42 850 24 43
$pageTitle.Font=New-Object Drawing.Font('Segoe UI',23,[Drawing.FontStyle]::Bold)
$pageDescription=Label $form '' 255 85 960 10 25; $pageDescription.ForeColor=$Theme.Muted
function Update-Navigation {
    foreach($nav in $script:navButtons.Values){
        $nav.BackColor=$Theme.Button; $nav.ForeColor=$Theme.Wine
        if($tabs.SelectedTab -eq $nav.Tag){$nav.BackColor=$Theme.Wine; $nav.ForeColor=[Drawing.Color]::White}
    }
    $pageTitle.Text='Suas vendas, em dia.'
    $pageDescription.Text='Registre as vendas e acompanhe seu turno em um só lugar.'
    if($tabs.SelectedTab -eq $closingTab){$pageTitle.Text='Seu fechamento, conferido.'; $pageDescription.Text='Revise os valores, envie o relatório e encerre seu turno.'}
    if($tabs.SelectedTab -eq $historyTab){$pageTitle.Text='Seu histórico, organizado.'; $pageDescription.Text='Consulte seus dias e acompanhe o total vendido no mês.'}
    if($tabs.SelectedTab -eq $setupTab){$pageTitle.Text='Prepare seu turno.'; $pageDescription.Text='Informe o responsável e o estoque inicial. Depois, é só registrar as vendas.'}
}
$tabs.Add_SelectedIndexChanged({Update-Navigation})

# One soft summary band, with the main figure first.
$summaryBand=New-Object Windows.Forms.Panel
$summaryBand.SetBounds(14,4,958,74); $summaryBand.BackColor=$Theme.Focus; $salesTab.Controls.Add($summaryBand)
$summaryBand.SendToBack()
$summaryCards.TOTAL.Parent=$summaryBand; $summaryCards.TOTAL.SetBounds(18,13,278,48)
$summaryCards.TOTAL.Font=New-Object Drawing.Font('Segoe UI',17,[Drawing.FontStyle]::Bold)
$summaryCards.TOTAL.BackColor=$Theme.Focus; $summaryCards.TOTAL.ForeColor=$Theme.Wine
$summaryX=306
foreach($key in @('WD','Shop','Cinema')){
    $summaryCards[$key].Parent=$summaryBand; $summaryCards[$key].SetBounds($summaryX,21,208,34)
    $summaryCards[$key].BackColor=$Theme.Focus; $summaryCards[$key].ForeColor=$Theme.Wine
    $summaryX+=210
}
$entryHeading=Label $salesTab 'Registrar venda' 16 87 350 13 29
$entryHeading.Font=New-Object Drawing.Font('Segoe UI',13,[Drawing.FontStyle]::Bold)
$promo=Label $salesTab '' 500 92 470 9 24; $promo.TextAlign='MiddleRight'; $promo.ForeColor=$Theme.Muted
$grid.Top=124
for($i=0;$i -lt 9;$i++){$cell=$grid.GetControlFromPosition($i,0); $cell.BackColor=$Theme.Focus; $cell.ForeColor=$Theme.Wine}
$basketTotal.Top=341; $basketHint.Top=369; $add.Top=341; $cancel.Top=341
$list.SetBounds(14,423,594,145); $report.SetBounds(626,423,346,145)
$recentHeading=Label $salesTab 'Últimas vendas' 16 393 590 11 27
$hourHeading=Label $salesTab 'Relatório da hora' 628 393 340 11 27
foreach($control in @($salesTab.Controls)){
    if($control -is [BrandButton] -and $control -ne $add -and $control -ne $cancel){$control.Top=580}
}
$listWidths=@(68,68,125,98,98,105); for($column=0;$column -lt $list.Columns.Count;$column++){$list.Columns[$column].Width=$listWidths[$column]}
$report.BackColor=$Theme.Focus; $report.Font=New-Object Drawing.Font('Consolas',10)
$closingReport.SetBounds(16,52,956,430)
foreach($control in @($closingTab.Controls)){if($control -is [BrandButton]){$control.Top=496}}
$historyList.Height=340
foreach($control in @($historyTab.Controls)){if($control -is [BrandButton]){$control.Top=435}}
$monthPicker.Top=439
foreach($control in @($historyTab.Controls)){if($control -is [Windows.Forms.Label] -and $control.Top -ge 450){$control.Top=489}}
$closeShiftButton.SetBounds(1030,755,194,38)
$clockLabel.SetBounds(255,749,755,28)
$status.SetBounds(255,781,755,25); $status.ForeColor=$Theme.Muted
$subtitle.Visible=$false
Update-Navigation
$form.ResumeLayout($true)
