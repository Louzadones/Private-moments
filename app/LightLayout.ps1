# Presentation only: the existing controls retain all validation and persistence handlers.
$form.SuspendLayout()
$form.MaximumSize = New-Object Drawing.Size(0,0)
$form.MinimumSize = New-Object Drawing.Size(0,0)
$form.ClientSize = New-Object Drawing.Size(1250,750)
$form.MinimumSize = $form.Size
$form.AutoScroll = $true
$menu.Visible = $false
$header.Visible = $false
$tabs.Appearance = 'FlatButtons'; $tabs.SizeMode = 'Fixed'
$tabs.ItemSize = New-Object Drawing.Size(0,1)
$tabs.SetBounds(240,110,996,568)
$tabs.Anchor = 'Top,Left'
$side = New-Object Windows.Forms.Panel
$side.SetBounds(0,0,220,750); $side.BackColor = [Drawing.ColorTranslator]::FromHtml('#FCFAFB')
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
    $nav.Height=48; $nav.Tag=$definition[1]; $nav.FlatAppearance.BorderSize=0
    $nav.Add_Click({param($sender,$e) $tabs.SelectedTab=$sender.Tag})
    $script:navButtons[$definition[0]]=$nav; $navY+=60
}
$setupNav=Button $side 'Turno e estoque' 12 562 196 { Run-Action { Show-Setup } }
$setupNav.Anchor='Bottom,Left'; $setupNav.FlatAppearance.BorderSize=0
$exitNav=Button $side 'Sair do aplicativo' 12 604 196 { Request-Exit }
$exitNav.Anchor='Bottom,Left'; $exitNav.FlatAppearance.BorderSize=0
$localLabel=Label $side '●  100% local' 20 675 180 10 24; $localLabel.Anchor='Bottom,Left'; $localLabel.ForeColor=$Theme.Wine
$localNote=Label $side 'Salvo neste computador.' 20 701 190 9 24; $localNote.Anchor='Bottom,Left'; $localNote.ForeColor=$Theme.Muted
$eyebrow=Label $form 'PRIVATE MOMENTS / PAINEL DA LOJA' 255 18 700 9 22; $eyebrow.ForeColor=$Theme.Wine
$pageTitle=Label $form '' 253 42 850 24 43
$pageTitle.Font=New-Object Drawing.Font('Segoe UI',23,[Drawing.FontStyle]::Bold)
$pageDescription=Label $form '' 255 85 960 10 25; $pageDescription.ForeColor=$Theme.Muted
function Update-Navigation {
    foreach($nav in $script:navButtons.Values){
        $nav.BackColor=$side.BackColor; $nav.ForeColor=$Theme.Muted
        if($tabs.SelectedTab -eq $nav.Tag){$nav.BackColor=$Theme.Focus; $nav.ForeColor=$Theme.Wine}
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
$promo=Label $salesTab 'WD: 5 pacotes por €180  ·  JD: 7 unidades por €90' 500 92 470 9 24; $promo.TextAlign='MiddleRight'; $promo.ForeColor=$Theme.Muted
$grid.Top=124
for($i=0;$i -lt 9;$i++){$cell=$grid.GetControlFromPosition($i,0); $cell.BackColor=$Theme.Focus; $cell.ForeColor=$Theme.Wine}
$basketTotal.Top=341; $basketHint.Top=369; $add.Top=341; $cancel.Top=341
$list.SetBounds(14,423,594,80); $report.SetBounds(626,423,346,80)
$recentHeading=Label $salesTab 'Últimas vendas' 16 393 590 11 27
$hourHeading=Label $salesTab 'Relatório da hora' 628 393 340 11 27
foreach($control in @($salesTab.Controls)){
    if($control -is [BrandButton] -and $control -ne $add -and $control -ne $cancel){$control.Top=515}
}
$report.BackColor=$Theme.Focus; $report.Font=New-Object Drawing.Font('Consolas',10)
$closingReport.SetBounds(16,52,956,430)
foreach($control in @($closingTab.Controls)){if($control -is [BrandButton]){$control.Top=496}}
$historyList.Height=340
foreach($control in @($historyTab.Controls)){if($control -is [BrandButton]){$control.Top=435}}
$monthPicker.Top=439
foreach($control in @($historyTab.Controls)){if($control -is [Windows.Forms.Label] -and $control.Top -ge 450){$control.Top=489}}
$closeShiftButton.SetBounds(1030,690,194,38)
$clockLabel.SetBounds(255,684,755,28)
$status.SetBounds(255,716,755,25); $status.ForeColor=$Theme.Muted
$subtitle.Visible=$false
Update-Navigation
$form.ResumeLayout($true)
