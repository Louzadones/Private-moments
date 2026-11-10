$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -WarningAction SilentlyContinue -ReferencedAssemblies @('System.Windows.Forms','System.Drawing') -TypeDefinition @"
using System;
using System.Windows.Forms;
using System.Drawing;
public class BrandColors : ProfessionalColorTable {
 public override Color MenuStripGradientBegin {get{return ColorTranslator.FromHtml("#590027");}}
 public override Color MenuStripGradientEnd {get{return MenuStripGradientBegin;}}
 public override Color ToolStripDropDownBackground {get{return MenuStripGradientBegin;}}
 public override Color ImageMarginGradientBegin {get{return MenuStripGradientBegin;}}
 public override Color ImageMarginGradientMiddle {get{return MenuStripGradientBegin;}}
 public override Color ImageMarginGradientEnd {get{return MenuStripGradientBegin;}}
 public override Color MenuItemSelected {get{return ColorTranslator.FromHtml("#F7A6CE");}}
 public override Color MenuItemSelectedGradientBegin {get{return MenuItemSelected;}}
 public override Color MenuItemSelectedGradientEnd {get{return MenuItemSelected;}}
 public override Color MenuItemPressedGradientBegin {get{return MenuItemSelected;}}
 public override Color MenuItemPressedGradientMiddle {get{return MenuItemSelected;}}
 public override Color MenuItemPressedGradientEnd {get{return MenuItemSelected;}}
 public override Color MenuBorder {get{return ColorTranslator.FromHtml("#C8739A");}}
 public override Color MenuItemBorder {get{return MenuBorder;}}
}
public class BrandMenuRenderer : ToolStripProfessionalRenderer {
 public BrandMenuRenderer() : base(new BrandColors()) {}
 protected override void OnRenderItemText(ToolStripItemTextRenderEventArgs e) {
  e.TextColor=ColorTranslator.FromHtml(e.Item.Selected ? "#590027" : "#F7A6CE"); base.OnRenderItemText(e);
 }
}
public class EmptyNumberBox : NumericUpDown {
 protected override void UpdateEditText() { base.UpdateEditText(); if (Text == "0") Text = String.Empty; }
 protected override void OnEnter(EventArgs e) { base.OnEnter(e); Select(0, Text.Length); }
}
public class ToggleRadioButton : RadioButton {
 protected override void OnClick(EventArgs e) {
  bool wasChecked = Checked;
  base.OnClick(e);
  if (wasChecked) Checked = false;
 }
}
public class TrayForm : Form {
 private bool background;
 protected override bool ShowWithoutActivation { get { return background; } }
 public void ShowInBackground() { background = true; try { Show(); } finally { background = false; } }
 protected override void WndProc(ref Message m) {
  if (m.Msg == 0x802A) { Show(); WindowState = FormWindowState.Normal; Activate(); m.Result = IntPtr.Zero; return; }
  base.WndProc(ref m);
 }
}
"@
[Windows.Forms.Application]::EnableVisualStyles()
$script:Theme=@{}
foreach($entry in @{Wine='#590027';Pink='#F7A6CE';Canvas='#FFF3F8';Surface='#FFFBFD';Text='#3B1026';Muted='#76445C';Line='#C8739A';Error='#A31B46';Disabled='#EAD2DE';Hover='#79073C'}.GetEnumerator()){
    $script:Theme[$entry.Key]=[Drawing.ColorTranslator]::FromHtml($entry.Value)
}
. (Join-Path $PSScriptRoot 'Core.ps1')
$dataPath = Join-Path $PSScriptRoot 'dados.json'
$backupPath = Join-Path $PSScriptRoot 'dados.backup.json'
$created = $false
$mutex = New-Object Threading.Mutex($true, 'Local\SweetSensationSalesApp', [ref]$created)
if (-not $created) {
    Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class ExistingWindow {
 [DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern IntPtr FindWindow(string cls, string title);
 [DllImport("user32.dll")] public static extern IntPtr SendMessage(IntPtr handle, int message, IntPtr wparam, IntPtr lparam);
 [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr handle);
}
"@
    $existing = [ExistingWindow]::FindWindow($null, 'Sweet Sensation | Vendas e fechamento')
    if ($existing -ne [IntPtr]::Zero) { $null=[ExistingWindow]::SendMessage($existing,0x802A,[IntPtr]::Zero,[IntPtr]::Zero); $null=[ExistingWindow]::SetForegroundWindow($existing) }
    else { [Windows.Forms.MessageBox]::Show('Sweet Sensation já está iniciando. Aguarde a janela ou abra pelo ícone perto do relógio.', 'Sweet Sensation') | Out-Null }
    $mutex.Dispose(); exit
}
$script:state = New-State
$script:editingId = $null
$script:uiReady = $false
$script:allowExit = $false
try {
    if (Test-Path -LiteralPath $dataPath) {
        $loaded = Get-Content -LiteralPath $dataPath -Raw -Encoding UTF8 | ConvertFrom-Json
        # Preserve a separate original before upgrading the first version.
        if ($loaded.Version -eq 1 -and -not (Test-Path -LiteralPath ($dataPath + '.v1'))) { Copy-Item -LiteralPath $dataPath -Destination ($dataPath + '.v1') }
        $script:state = Upgrade-State $loaded
    }
} catch {
    [Windows.Forms.MessageBox]::Show("Não foi possível ler dados.json. Seus dados foram preservados. Verifique o arquivo ou restaure dados.backup.json.`r`n`r`n$($_.Exception.Message)", 'Erro ao carregar') | Out-Null
    $mutex.ReleaseMutex(); $mutex.Dispose(); exit
}
function Save-State {
    $temp = $dataPath + '.tmp'
    $script:state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $temp -Encoding UTF8
    if (Test-Path -LiteralPath $dataPath) { [IO.File]::Replace($temp, $dataPath, $backupPath) }
    else { [IO.File]::Move($temp, $dataPath) }
}
function Run-Action([scriptblock]$Action) {
    $old = $script:state | ConvertTo-Json -Depth 8
    try { & $Action } catch {
        $script:state = $old | ConvertFrom-Json
        if ($script:uiReady) { Refresh-View }
        [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Confira os dados') | Out-Null
    }
}
function Label($Parent, $Text, $X, $Y, $W, $Size = 10, $H = 26) {
    $o = New-Object Windows.Forms.Label; $o.Text = $Text; $o.SetBounds($X, $Y, $W, $H)
    $o.AutoSize = $false; $o.UseCompatibleTextRendering = $true; $o.Font = New-Object Drawing.Font('Segoe UI', $Size); $Parent.Controls.Add($o); return $o
}
function Button($Parent, $Text, $X, $Y, $W, [scriptblock]$Action) {
    $o = New-Object Windows.Forms.Button; $o.Text = $Text; $o.SetBounds($X, $Y, $W, 36)
    $o.FlatStyle = 'Flat'; $o.BackColor = $Theme.Surface; $o.ForeColor=$Theme.Wine
    $o.FlatAppearance.BorderColor=$Theme.Line; $o.FlatAppearance.MouseOverBackColor=$Theme.Pink; $o.Add_Click($Action)
    $Parent.Controls.Add($o); return $o
}
function Textbox($Parent, $X, $Y, $W) {
    $o = New-Object Windows.Forms.TextBox; $o.SetBounds($X, $Y, $W, 27); $o.BackColor=$Theme.Surface; $o.ForeColor=$Theme.Text; $o.BorderStyle='FixedSingle'
    $o.Add_Enter({param($sender,$e) $sender.BackColor=$Theme.Pink}); $o.Add_Leave({param($sender,$e) $sender.BackColor=$Theme.Surface})
    $Parent.Controls.Add($o); return $o
}
function Numberbox($Parent, $X, $Y, $W, $Max = 100000) {
    $o = New-Object EmptyNumberBox; $o.Minimum = 0; $o.Maximum = $Max; $o.SetBounds($X, $Y, $W, 27); $o.Text = ''; $o.BackColor=$Theme.Surface; $o.ForeColor=$Theme.Text; $o.BorderStyle='FixedSingle'
    $o.Add_Enter({param($sender,$e) $sender.BackColor=$Theme.Pink}); $o.Add_Leave({param($sender,$e) $sender.BackColor=$Theme.Surface})
    $Parent.Controls.Add($o); return $o
}
function Make-Group($Parent, $Text, $X, $Y, $W, $H) {
    $o = New-Object Windows.Forms.GroupBox; $o.Text = $Text; $o.SetBounds($X, $Y, $W, $H); $Parent.Controls.Add($o); return $o
}
function Radio($Parent, $Text, $X, $Y, $W) {
    $o = New-Object ToggleRadioButton; $o.Text = $Text; $o.SetBounds($X, $Y, $W, 28); $o.ForeColor=$Theme.Wine; $o.FlatStyle='Flat'; $Parent.Controls.Add($o); return $o
}
function Reset-Entry {
    $script:editingId = $null; $add.Text = 'Registrar venda'; $cancel.Visible = $false
    foreach ($r in $entryRows.Values) {
        $r.Packs.Value = 0; $r.Loose.Value = 0; $r.Count.Value = 0; $r.Cash.Text = ''; $r.Card.Text = ''
        $r.CashRadio.Checked = $false; $r.CardRadio.Checked = $false; $r.SplitRadio.Checked = $false
    }
    foreach ($c in $entryRows.Keys) { Sync-Payment $c }
    Update-Prices
}
function Entry-Amount($Box) {
    if ($Box.Text.Trim() -eq '') { return [long]0 }
    return ConvertTo-Cents $Box.Text -AllowZero
}
function Row-Price($Category) {
    $r = $entryRows[$Category]
    if ($Category -eq 'Shop') { return (Entry-Amount $r.Cash) + (Entry-Amount $r.Card) }
    return Get-Price $Category ([int]$r.Packs.Value) ([int]$r.Loose.Value) ([int]$r.Count.Value)
}
function Sync-Payment([string]$Category) {
    if (-not $entryRows.ContainsKey($Category)) { return }
    $r = $entryRows[$Category]
    $show = $Category -eq 'Shop' -or $r.SplitRadio.Checked
    $r.Cash.Visible = $show; $r.Card.Visible = $show
    Update-Prices
}
function Update-Prices {
    if (-not $script:uiReady -or $script:updatingPrices) { return }
    $script:updatingPrices = $true
    try {
    $sum = [long]0
    foreach ($c in @('WD', 'JD', 'SD', 'Shop', 'Cinema')) {
        try { $p = Row-Price $c; $entryRows[$c].Total.Text = Format-Money $p; $sum += $p }
        catch { $entryRows[$c].Total.Text = 'Confira o valor' }
    }
    $basketTotal.Text = 'Total desta venda: ' + (Format-Money $sum)
    Update-EntryFeedback
    } finally { $script:updatingPrices = $false }
}
function Update-EntryFeedback {
    if (-not $script:uiReady) { return }
    $issues = @(); $hasItems = $false
    $sold = Get-SoldQuantities $script:state.Sales
    if ($null -ne $script:editingId) { $sold = Get-SoldQuantities @($script:state.Sales | Where-Object { $_.Id -ne $script:editingId }) }
    foreach ($c in @('WD','JD','SD','Shop','Cinema')) {
        $r = $entryRows[$c]; $problem = ''
        try {
            $price = Row-Price $c
            if ($price -gt 0) {
                $hasItems = $true
                if ($c -in @('WD','JD','SD')) {
                    $units = [long]$r.Count.Value
                    if ($c -ne 'JD') { $units = [long]($r.Packs.Value * 4 + $r.Loose.Value) }
                    if (-not $script:state.Settings.Ready) { $problem = 'salve o estoque inicial no menu Turno' }
                    elseif ($sold[$c] + $units -gt [long]$script:state.Settings.Stock.$c) { $problem = 'quantidade maior que o estoque disponível' }
                }
                if ($problem -eq '' -and $c -ne 'Shop') {
                    if (-not ($r.CashRadio.Checked -or $r.CardRadio.Checked -or $r.SplitRadio.Checked)) { $problem = 'escolha Dinheiro, Cartão ou Dividido' }
                    elseif ($r.SplitRadio.Checked) {
                        $paid = (Entry-Amount $r.Cash) + (Entry-Amount $r.Card)
                        if ($paid -lt $price) { $problem = 'faltam ' + (Format-Money ($price - $paid)) + ' no pagamento dividido' }
                        elseif ($paid -gt $price) { $problem = 'pagamento excede o total em ' + (Format-Money ($paid - $price)) }
                    }
                }
            } elseif ($c -ne 'Shop' -and $r.SplitRadio.Checked -and ((Entry-Amount $r.Cash) + (Entry-Amount $r.Card)) -gt 0) { $problem = 'informe a quantidade vendida' }
        } catch { $problem = 'digite um valor válido, como 10,50' }
        $r.Total.ForeColor = $Theme.Text
        if ($problem -ne '') { $issues += "${c}: $problem"; $r.Total.ForeColor = $Theme.Error }
    }
    $add.Enabled = $hasItems -and $issues.Count -eq 0
    if ($add.Enabled) { $add.BackColor=$Theme.Wine; $add.ForeColor=$Theme.Pink }
    else { $add.BackColor=$Theme.Disabled; $add.ForeColor=$Theme.Muted }
    $basketHint.ForeColor = $Theme.Muted
    if ($issues.Count -gt 0) { $basketHint.Text = $issues[0]; $basketHint.ForeColor = $Theme.Error }
    elseif ($hasItems) { $basketHint.Text = 'Tudo conferido. Registre a venda para atualizar o turno.' }
    else { $basketHint.Text = 'Informe as quantidades ou o valor do Shop e escolha o pagamento.' }
}
function Register-Basket {
    $newRows = @(); $batch = [guid]::NewGuid().ToString(); $at = (Get-Date).ToString('o')
    $other = @($script:state.Sales)
    if ($null -ne $script:editingId) {
        $old = @($other | Where-Object { $_.Id -eq $script:editingId })[0]
        $at = $old.At; $other = @($other | Where-Object { $_.Id -ne $script:editingId })
    }
    $sold = Get-SoldQuantities $other
    foreach ($c in @('WD', 'JD', 'SD', 'Shop', 'Cinema')) {
        $r = $entryRows[$c]; $price = Row-Price $c
        $cash = [long]0; $card = [long]0
        if ($c -eq 'Shop' -or $r.SplitRadio.Checked) { $cash = Entry-Amount $r.Cash; $card = Entry-Amount $r.Card }
        if ($c -ne 'Shop') {
            if ($r.CashRadio.Checked) { $cash = $price; $card = 0 }
            elseif ($r.CardRadio.Checked) { $cash = 0; $card = $price }
            elseif (-not $r.SplitRadio.Checked -and $price -gt 0) { throw "${c}: selecione Dinheiro, Cartão ou Dividido." }
        }
        $units = [long]0
        if ($c -in @('WD', 'SD')) { $units = [long]($r.Packs.Value * 4 + $r.Loose.Value) }
        if ($c -in @('JD', 'Cinema')) { $units = [long]$r.Count.Value }
        if ($price -eq 0 -and $cash -eq 0 -and $card -eq 0 -and $units -eq 0) { continue }
        if ($price -le 0) { throw "${c}: informe a quantidade ou o valor da venda." }
        if ($cash + $card -ne $price) { throw "${c}: dinheiro + cartão deve ser exatamente $(Format-Money $price)." }
        if ($c -in @('WD', 'JD', 'SD')) {
            if (-not $script:state.Settings.Ready) { throw 'Salve o estoque inicial antes de registrar produtos.' }
            if ($units -lt 1 -or $sold[$c] + $units -gt [long]$script:state.Settings.Stock.$c) { throw "${c}: confira a quantidade e o estoque disponível." }
        }
        $newRows += [pscustomobject]@{ Id = [guid]::NewGuid().ToString(); BatchId = $batch; At = $at; Category = $c; Payment = 'Split'; Quantity = $units; Cents = $price; CashCents = $cash; CardCents = $card; Packs = [int]$r.Packs.Value; Loose = [int]$r.Loose.Value }
    }
    if ($newRows.Count -eq 0) { throw 'Preencha pelo menos uma categoria da venda.' }
    $script:state.Sales = $other + $newRows
    Save-State; Refresh-View; Reset-Entry
    $status.Text = 'Venda salva. Valores e estoque atualizados; campos limpos para a próxima venda.'
}
function Show-Setup {
    Load-Settings
    if (-not $tabs.TabPages.Contains($setupTab)) { $tabs.TabPages.Insert(0, $setupTab) }
    $setupTab.Text = 'Início do turno'
    if ($script:state.Settings.Ready) { $setupTab.Text = 'Corrigir dados do turno' }
    $tabs.SelectedTab = $setupTab
    $backToSales.Visible = [bool]$script:state.Settings.Ready
}
function Hide-Setup {
    $tabs.SelectedTab = $salesTab
    if ($tabs.TabPages.Contains($setupTab)) { $tabs.TabPages.Remove($setupTab) }
    $entryRows.WD.Packs.Focus()
}
function Load-Settings {
    $s = $script:state.Settings
    $shiftDate.Value = Get-ShiftCalendarDate $script:state
    $nameBox.Text = [string]$s.Name
    $wdPacks.Value = [math]::Floor([long]$s.Stock.WD / 4); $wdLoose.Value = [long]$s.Stock.WD % 4
    $jdCount.Value = [long]$s.Stock.JD
    $sdPacks.Value = [math]::Floor([long]$s.Stock.SD / 4); $sdLoose.Value = [long]$s.Stock.SD % 4
}
function Save-ShiftSettings {
    $name = $nameBox.Text.Trim()
    if ($name -eq '' -or $name -match '[\r\n{}]') { throw 'Informe o nome do responsável em uma única linha.' }
    $stock = [pscustomobject]@{ WD = [long]($wdPacks.Value * 4 + $wdLoose.Value); JD = [long]$jdCount.Value; SD = [long]($sdPacks.Value * 4 + $sdLoose.Value) }
    $sold = Get-SoldQuantities $script:state.Sales
    foreach ($c in @('WD', 'JD', 'SD')) { if ($stock.$c -lt $sold[$c]) { throw "O estoque inicial de $c é menor que a quantidade já vendida." } }
    $previousCalendar=Get-ShiftCalendarDate $script:state
    if(-not $script:state.Settings.Ready -or $shiftDate.Value.Date -ne $previousCalendar.Date){
        $script:state.Settings.Date = (Get-OpeningDateFromCalendar $shiftDate.Value (Get-Date)).ToString('yyyy-MM-dd')
    }
    if($null -eq $script:state.Settings.PSObject.Properties['CalendarDate']){
        $script:state.Settings | Add-Member -NotePropertyName CalendarDate -NotePropertyValue $shiftDate.Value.ToString('yyyy-MM-dd')
    }else{$script:state.Settings.CalendarDate=$shiftDate.Value.ToString('yyyy-MM-dd')}
    $script:state.Settings.Name = $name; $script:state.Settings.Stock = $stock; $script:state.Settings.Ready = $true
    Save-State; Refresh-View; Hide-Setup; Reset-Entry
    $status.Text = 'Dados do turno salvos. O estoque inicial não muda quando você registra vendas.'
}
function Edit-Selected {
    if ($list.SelectedItems.Count -eq 0) { throw 'Selecione uma linha do histórico para corrigir.' }
    $id = [string]$list.SelectedItems[0].Tag
    $sale = @($script:state.Sales | Where-Object { $_.Id -eq $id })[0]
    Reset-Entry
    $script:editingId = $id; $r = $entryRows[[string]$sale.Category]
    if ($sale.Category -in @('WD', 'SD')) {
        if ($null -ne $sale.Packs) { $r.Packs.Value = $sale.Packs; $r.Loose.Value = $sale.Loose }
        else { $r.Packs.Value = [math]::Floor([long]$sale.Quantity / 4); $r.Loose.Value = [long]$sale.Quantity % 4 }
    }
    if ($sale.Category -eq 'JD') { $r.Count.Value = $sale.Quantity }
    if ($sale.Category -eq 'Cinema') {
        if([long]$sale.Quantity -gt 0){$r.Count.Value=$sale.Quantity}
        else{$r.Count.Value=[math]::Max(1,[math]::Round([long]$sale.Cents / (Get-CinemaUnitPrice)))}
    }
    if ($sale.Payment -eq 'Split') { $r.Cash.Text = Format-Number $sale.CashCents; $r.Card.Text = Format-Number $sale.CardCents }
    if ($sale.Payment -eq 'Cash') { $r.Cash.Text = Format-Number $sale.Cents }
    if ($sale.Payment -eq 'Card') { $r.Card.Text = Format-Number $sale.Cents }
    if ($sale.Category -ne 'Shop') {
        if ((Entry-Amount $r.Cash) -gt 0 -and (Entry-Amount $r.Card) -gt 0) { $r.SplitRadio.Checked = $true }
        elseif ((Entry-Amount $r.Cash) -gt 0) { $r.CashRadio.Checked = $true }
        elseif ((Entry-Amount $r.Card) -gt 0) { $r.CardRadio.Checked = $true }
    }
    Sync-Payment ([string]$sale.Category)
    $add.Text = 'Salvar correção'; $cancel.Visible = $true; Update-Prices
    $status.Text = 'Corrigindo esta linha. Os preços fixos atuais serão aplicados ao salvar. Confira dinheiro/cartão.'
}
function Send-Report([string]$Text) {
    Start-Process ('https://wa.me/?text=' + [Uri]::EscapeDataString($Text))
    $status.Text = 'Escolha a conversa no WhatsApp e confirme o envio da mensagem.'
}
function Start-NewShift {
    if ([Windows.Forms.MessageBox]::Show('Arquivar as vendas e começar um novo turno com estoque e totais zerados? O turno atual ficará salvo na pasta turnos.', 'Novo turno', 'YesNo', 'Question') -ne 'Yes') { return }
    $archive = Join-Path $PSScriptRoot 'turnos'; $null = New-Item -ItemType Directory -Path $archive -Force
    $prefix = Join-Path $archive (Get-Date -Format 'yyyy-MM-dd_HH-mm-ss-fff')
    $script:state | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath ($prefix + '.json') -Encoding UTF8
    (Get-Report $script:state.Sales) | Set-Content -LiteralPath ($prefix + '-hora.txt') -Encoding UTF8
    try { (Get-ClosingReport $script:state) | Set-Content -LiteralPath ($prefix + '-fechamento.txt') -Encoding UTF8 } catch { }
    $oldName = $script:state.Settings.Name
    $script:state = New-State; $script:state.Settings.Name = $oldName
    Save-State; Reset-Entry; Refresh-View; Show-Setup
    $status.Text = 'Novo turno. Preencha a data, o responsável e os estoques iniciais e clique em Salvar.'
}
$form = New-Object TrayForm
$form.Text = 'Sweet Sensation | Vendas e fechamento'
$form.ClientSize = New-Object Drawing.Size(1040, 690)
$form.MinimumSize = $form.Size; $form.MaximumSize = $form.Size
$form.StartPosition = 'CenterScreen'; $form.BackColor = $Theme.Canvas; $form.ForeColor = $Theme.Text
$appIcon=New-Object Drawing.Icon((Join-Path $PSScriptRoot 'assets/app.ico'),32,32)
$trayIcon=New-Object Drawing.Icon((Join-Path $PSScriptRoot 'assets/app.ico'),16,16)
$form.Icon=$appIcon
$form.AutoScaleMode = 'Dpi'; $form.Font = New-Object Drawing.Font('Segoe UI', 10)
$menu = New-Object Windows.Forms.MenuStrip
$menu.Renderer=New-Object BrandMenuRenderer; $menu.BackColor=$Theme.Wine; $menu.ForeColor=$Theme.Pink
$shiftMenu = New-Object Windows.Forms.ToolStripMenuItem('Turno')
$editShiftMenu = New-Object Windows.Forms.ToolStripMenuItem('Corrigir dados iniciais...')
$editShiftMenu.Add_Click({ Run-Action { Show-Setup } })
$newShiftMenu = New-Object Windows.Forms.ToolStripMenuItem('Novo turno...')
$newShiftMenu.Add_Click({ Run-Action { Start-NewShift } })
$null = $shiftMenu.DropDownItems.Add($editShiftMenu); $null = $shiftMenu.DropDownItems.Add($newShiftMenu)
$null = $menu.Items.Add($shiftMenu); $form.MainMenuStrip = $menu; $form.Controls.Add($menu)
$header=New-Object Windows.Forms.Panel; $header.SetBounds(0,24,1040,72); $header.BackColor=$Theme.Wine; $header.ForeColor=$Theme.Pink; $form.Controls.Add($header)
$logoImage=[Drawing.Image]::FromFile((Join-Path $PSScriptRoot 'assets/logo.png'))
$logoBox=New-Object Windows.Forms.PictureBox; $logoBox.SetBounds(20,8,48,48); $logoBox.Image=$logoImage; $logoBox.SizeMode='Zoom'; $header.Controls.Add($logoBox)
$null = Label $header 'Sweet Sensation' 80 0 940 20 38
$subtitle = Label $header '' 82 44 936 10
$tabs = New-Object Windows.Forms.TabControl; $tabs.SetBounds(20, 100, 1000, 513); $form.Controls.Add($tabs)
$tabs.DrawMode='OwnerDrawFixed'; $tabs.Add_DrawItem({param($sender,$e)
    $selected=$e.Index -eq $sender.SelectedIndex; $bg=$Theme.Wine; $fg=$Theme.Pink
    if($selected){$bg=$Theme.Pink; $fg=$Theme.Wine}
    $brush=New-Object Drawing.SolidBrush($bg)
    try{$e.Graphics.FillRectangle($brush,$e.Bounds)}finally{$brush.Dispose()}
    [Windows.Forms.TextRenderer]::DrawText($e.Graphics,$sender.TabPages[$e.Index].Text,$sender.Font,$e.Bounds,$fg,([Windows.Forms.TextFormatFlags]::HorizontalCenter -bor [Windows.Forms.TextFormatFlags]::VerticalCenter))
})
$salesTab = New-Object Windows.Forms.TabPage; $salesTab.Text = 'Vendas e relatório por hora'
$setupTab = New-Object Windows.Forms.TabPage; $setupTab.Text = 'Início do turno'
$closingTab = New-Object Windows.Forms.TabPage; $closingTab.Text = 'Fechamento detalhado'
foreach ($tab in @($setupTab, $salesTab, $closingTab)) { $tab.BackColor = $form.BackColor; $tabs.TabPages.Add($tab) }
$totalsLabel = Label $salesTab '' 14 10 964 13 30
$grid = New-Object Windows.Forms.TableLayoutPanel
$grid.SetBounds(14,48,958,212); $grid.ColumnCount = 9; $grid.RowCount = 6
$grid.CellBorderStyle = 'Single'; $grid.Margin = 0; $grid.Padding = 0; $grid.BackColor=$Theme.Canvas
foreach ($w in @(90,105,125,100,120,120,100,95,93)) { $null = $grid.ColumnStyles.Add((New-Object Windows.Forms.ColumnStyle([Windows.Forms.SizeType]::Absolute, $w))) }
$null = $grid.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute, 34)))
for ($i=1;$i -le 5;$i++) { $null = $grid.RowStyles.Add((New-Object Windows.Forms.RowStyle([Windows.Forms.SizeType]::Absolute,34))) }
$salesTab.Controls.Add($grid)
$headers = @('Categoria','Pacotes de 4','Avulsos / un.','Total (€)','Dinheiro','Cartão','Dividido',"Dinheiro (€)`ndividido", "Cartão (€)`ndividido")
for ($i=0;$i -lt 9;$i++) {
 $h=Label $salesTab $headers[$i] 0 0 90 9 34; $h.TextAlign='MiddleCenter'; $h.Dock='Fill'; $h.Margin=0; $h.BackColor=$Theme.Wine; $h.ForeColor=$Theme.Pink
 $grid.Controls.Add($h,$i,0)
}
$entryRows=@{}; $row=1
foreach ($c in @('WD','JD','SD','Shop','Cinema')) {
 $name=Label $salesTab $c 0 0 90 11 30; $name.Dock='Fill'; $name.TextAlign='MiddleLeft'; $name.Padding=New-Object Windows.Forms.Padding(8,0,0,0); $name.Margin=0
 $grid.Controls.Add($name,0,$row)
 $packs=Numberbox $salesTab 0 0 86 100000
 $loose=Numberbox $salesTab 0 0 102 100000
 $count=Numberbox $salesTab 0 0 102 100000
 $total=Label $salesTab '€0' 0 0 90 11 30; $total.TextAlign='MiddleCenter'
 $cash=Textbox $salesTab 0 0 95; $card=Textbox $salesTab 0 0 95
 $panel=New-Object Windows.Forms.Panel; $panel.Dock='Fill'; $panel.Margin=0
 $cashRadio=Radio $panel '' 50 2 24; $cardRadio=Radio $panel '' 170 2 24; $splitRadio=Radio $panel '' 280 2 24
 $panel.Add_Paint({ param($sender,$e) $pen=New-Object Drawing.Pen($Theme.Line); try{$e.Graphics.DrawLine($pen,120,0,120,$sender.Height); $e.Graphics.DrawLine($pen,240,0,240,$sender.Height)}finally{$pen.Dispose()} })
 $grid.Controls.Add($panel,4,$row); $grid.SetColumnSpan($panel,3)
 foreach ($control in @($packs,$loose,$count,$total,$cash,$card)) { $control.Anchor='None'; $control.Margin=New-Object Windows.Forms.Padding(3) }
 $packs.Visible=$c -in @('WD','SD'); $loose.Visible=$c -in @('WD','SD'); $count.Visible=$c -in @('JD','Cinema')
 if ($c -in @('WD','SD')) { $grid.Controls.Add($packs,1,$row) }
 if ($c -in @('WD','SD')) { $grid.Controls.Add($loose,2,$row) }
 if ($c -in @('JD','Cinema')) { $grid.Controls.Add($count,2,$row) }
 $grid.Controls.Add($total,3,$row)
 $panel.Visible=$c -ne 'Shop'
 if ($c -eq 'Shop') {
  $grid.Controls.Remove($panel); $panel.Visible=$false
  $grid.Controls.Add($cash,4,$row); $grid.Controls.Add($card,5,$row)
 } else { $grid.Controls.Add($cash,7,$row); $grid.Controls.Add($card,8,$row) }
 $cashRadio.AccessibleName="$c dinheiro"; $cardRadio.AccessibleName="$c cartão"; $splitRadio.AccessibleName="$c dividido"
 $entryRows[$c]=@{Packs=$packs;Loose=$loose;Count=$count;Total=$total;Cash=$cash;Card=$card;CashRadio=$cashRadio;CardRadio=$cardRadio;SplitRadio=$splitRadio}
 foreach($radio in @($cashRadio,$cardRadio,$splitRadio)) { $radio.Tag=$c; $radio.Add_CheckedChanged({param($sender,$e) if($script:uiReady){Sync-Payment ([string]$sender.Tag)}}) }
 $packs.Add_ValueChanged({Update-Prices});$loose.Add_ValueChanged({Update-Prices});$count.Add_ValueChanged({Update-Prices});$cash.Add_TextChanged({Update-Prices});$card.Add_TextChanged({Update-Prices})
 $row++
}
$basketTotal = Label $salesTab 'Total desta venda: €0' 14 264 580 12 30
$basketHint = Label $salesTab '' 14 289 595 9 16
$add = Button $salesTab 'Registrar venda' 634 264 150 { Run-Action { Register-Basket } }
$add.BackColor = $Theme.Wine; $add.ForeColor = $Theme.Pink
$add.FlatAppearance.BorderSize=0; $add.FlatAppearance.MouseOverBackColor=$Theme.Hover
$cancel = Button $salesTab 'Cancelar correção' 800 264 160 { Reset-Entry }; $cancel.Visible = $false
$list = New-Object Windows.Forms.ListView; $list.SetBounds(14, 306, 594, 126)
$list.View = 'Details'; $list.FullRowSelect = $true; $list.MultiSelect = $false; $list.HideSelection = $false
$list.BackColor=$Theme.Surface; $list.ForeColor=$Theme.Text
foreach ($col in @(@('Hora', 74), @('Categoria', 78), @('Quantidade', 130), @('Dinheiro', 100), @('Cartão', 100), @('Total', 100))) { $null = $list.Columns.Add($col[0], $col[1]) }
$salesTab.Controls.Add($list); $list.Add_DoubleClick({ Run-Action { Edit-Selected } })
$report = Textbox $salesTab 626 306 346; $report.Height = 126; $report.Multiline = $true; $report.ReadOnly = $true
$report.ScrollBars = 'Vertical'; $report.Font = New-Object Drawing.Font('Consolas', 10)
$null = Button $salesTab 'Editar linha' 14 443 136 { Run-Action { Edit-Selected } }
$null = Button $salesTab 'Excluir linha' 162 443 136 {
    Run-Action {
        if ($list.SelectedItems.Count -eq 0) { throw 'Selecione a linha a excluir.' }
        if ([Windows.Forms.MessageBox]::Show('Excluir esta linha e devolver a quantidade ao estoque?', 'Excluir', 'YesNo', 'Question') -ne 'Yes') { return }
        $id = $list.SelectedItems[0].Tag
        $script:state.Sales = @($script:state.Sales | Where-Object { $_.Id -ne $id })
        Save-State; Refresh-View; Reset-Entry
    }
}
$null = Button $salesTab 'Copiar por hora' 626 443 166 { Run-Action { [Windows.Forms.Clipboard]::SetText((Get-Report $script:state.Sales)); Acknowledge-Reminder; $status.Text = 'Relatório por hora copiado.' } }
$null = Button $salesTab 'WhatsApp por hora' 804 443 168 { Run-Action { Send-Report (Get-Report $script:state.Sales); Acknowledge-Reminder } }
$null = Label $setupTab 'Informe o estoque existente no começo do turno.' 20 18 940 14 34
$null = Label $setupTab 'WD e SD: cada pacote tem 4 comprimidos. Exemplo: 59 pacotes + 2 avulsos = 59-2 no relatório.' 20 58 940 10
$null = Label $setupTab 'Calendário / data do registro' 20 104 250
$shiftDate = New-Object Windows.Forms.DateTimePicker; $shiftDate.Format = 'Custom'; $shiftDate.CustomFormat = 'ddd, dd/MM/yyyy'
$shiftDate.SetBounds(20, 136, 210, 28); $setupTab.Controls.Add($shiftDate)
$null = Label $setupTab 'Responsável' 280 104 650
$nameBox = Textbox $setupTab 280 136 620
$null = Label $setupTab 'Categoria' 20 198 210 11
$null = Label $setupTab 'Pacotes de 4' 260 198 210 11
$null = Label $setupTab 'Comprimidos avulsos (0 a 3)' 520 198 380 11
$null = Label $setupTab 'WD' 20 238 200 12
$wdPacks = Numberbox $setupTab 260 238 180; $wdLoose = Numberbox $setupTab 520 238 180 3
$null = Label $setupTab 'SD' 20 334 200 12
$sdPacks = Numberbox $setupTab 260 334 180; $sdLoose = Numberbox $setupTab 520 334 180 3
$null = Label $setupTab 'JD (unidades)' 20 286 230 12
$jdCount = Numberbox $setupTab 260 286 180
$null = Label $setupTab 'Horário fixo: 11.AM a 02.AM   |   FLOAT fixo: €150' 20 390 920 11
$saveSettings = Button $setupTab 'Salvar dados do turno' 20 436 250 { Run-Action { Save-ShiftSettings } }
$backToSales = Button $setupTab 'Voltar sem alterar' 290 436 240 { Hide-Setup }; $backToSales.Visible = $false
$shiftDate.TabIndex=0; $nameBox.TabIndex=1
$wdPacks.TabIndex=2; $wdLoose.TabIndex=3; $jdCount.TabIndex=4; $sdPacks.TabIndex=5; $sdLoose.TabIndex=6
$saveSettings.TabIndex=7; $backToSales.TabIndex=8
$tooltips = New-Object Windows.Forms.ToolTip
$tooltips.AutoPopDelay=15000; $tooltips.InitialDelay=400
foreach ($c in @('WD','JD','SD','Shop','Cinema')) {
    $r=$entryRows[$c]
    $r.Packs.AccessibleName="$c pacotes de quatro"; $r.Loose.AccessibleName="$c comprimidos avulsos"; $r.Count.AccessibleName="$c unidades"
    $r.Cash.AccessibleName="$c valor em dinheiro"; $r.Card.AccessibleName="$c valor em cartão"
    $tooltips.SetToolTip($r.Cash,"${c}: valor em dinheiro. Campo vazio vale zero.")
    $tooltips.SetToolTip($r.Card,"${c}: valor em cartão. Campo vazio vale zero.")
    $tooltips.SetToolTip($r.CashRadio,"$c — pagar tudo em dinheiro")
    $tooltips.SetToolTip($r.CardRadio,"$c — pagar tudo no cartão")
    $tooltips.SetToolTip($r.SplitRadio,"$c — dividir entre dinheiro e cartão")
}
$tooltips.SetToolTip($entryRows.WD.Packs,'WD: pacote com 4 por €50. Avulso: €15.')
$tooltips.SetToolTip($entryRows.WD.Loose,'WD: €15 por comprimido avulso.')
$tooltips.SetToolTip($entryRows.SD.Packs,'SD: pacote com 4 por €60. Avulso: €20.')
$tooltips.SetToolTip($entryRows.SD.Loose,'SD: €20 por comprimido avulso.')
$tooltips.SetToolTip($entryRows.JD.Count,'JD: 1 por €20, 4 por €55, 7 por €90. Combinação mais barata automática.')
$tooltips.SetToolTip($entryRows.Cinema.Count,'Cinema: €15 por entrada.')
$form.KeyPreview=$true
$form.Add_KeyDown({ param($sender,$e)
    if($e.Control -and $e.KeyCode -eq 'Enter' -and $tabs.SelectedTab -eq $salesTab -and $add.Enabled){ $add.PerformClick(); $e.SuppressKeyPress=$true }
    if($e.KeyCode -eq 'Escape' -and $null -ne $script:editingId){ Reset-Entry; $e.SuppressKeyPress=$true }
})
$stockLabel = Label $closingTab '' 16 12 956 11 28
$closingReport = Textbox $closingTab 16 48 956; $closingReport.Height = 382
$closingReport.Multiline = $true; $closingReport.ReadOnly = $true; $closingReport.ScrollBars = 'Vertical'
$closingReport.Font = New-Object Drawing.Font('Consolas', 10); $closingReport.BackColor = $Theme.Surface
$null = Button $closingTab 'Copiar fechamento' 16 442 225 { Run-Action { [Windows.Forms.Clipboard]::SetText((Get-ClosingReport $script:state)); $status.Text = 'Fechamento copiado com o texto do modelo.' } }
$null = Button $closingTab 'WhatsApp: fechamento' 255 442 250 { Run-Action { Send-Report (Get-ClosingReport $script:state) } }
$null = Button $closingTab 'Salvar fechamento .txt' 519 442 235 {
    Run-Action {
        $text = Get-ClosingReport $script:state
        $dialog = New-Object Windows.Forms.SaveFileDialog; $dialog.Filter = 'Texto (*.txt)|*.txt'
        $dialog.FileName = 'Fechamento-' + $script:state.Settings.Date + '.txt'; $dialog.InitialDirectory = $PSScriptRoot
        if ($dialog.ShowDialog() -eq 'OK') { $text | Set-Content -LiteralPath $dialog.FileName -Encoding UTF8; $status.Text = 'Fechamento salvo.' }
        $dialog.Dispose()
    }
}

$null = Button $form 'Novo turno' 806 616 214 { Run-Action { Start-NewShift } }
$status = Label $form '' 22 660 996 9
function Refresh-View {
    $t = Get-Totals $script:state.Sales
    $totalsLabel.Text = "WD (WD + JD + SD): $(Format-Money ($t.WD + $t.JD + $t.SD))     Shop: $(Format-Money $t.Shop)     Cinema: $(Format-Money $t.Cinema)     TOTAL: $(Format-Money ($t.WD + $t.JD + $t.SD + $t.Shop + $t.Cinema))"
    $subtitle.Text = 'Acumulado do turno | ' + $script:state.Settings.Date + ' | ' + $script:state.Settings.Name + ' | 11.AM a 02.AM'
    $report.Text = Get-Report $script:state.Sales
    $list.BeginUpdate(); $list.Items.Clear()
    foreach ($sale in @($script:state.Sales | Sort-Object At -Descending)) {
        $q = '—'; if ($sale.Category -in @('JD', 'Cinema')) { $q = "$($sale.Quantity) un." }
        if ($sale.Category -in @('WD', 'SD')) { $q = "$([math]::Floor([long]$sale.Quantity / 4)) pac + $([long]$sale.Quantity % 4) av" }
        $cash = '—'; $card = '—'
        if ($sale.Payment -eq 'Split') { $cash = Format-Money $sale.CashCents; $card = Format-Money $sale.CardCents }
        if ($sale.Payment -eq 'Cash') { $cash = Format-Money $sale.Cents; $card = '€0' }
        if ($sale.Payment -eq 'Card') { $card = Format-Money $sale.Cents; $cash = '€0' }
        $item = New-Object Windows.Forms.ListViewItem(([datetime]$sale.At).ToString('HH:mm:ss'))
        foreach ($cell in @([string]$sale.Category, $q, $cash, $card, (Format-Money $sale.Cents))) { $null = $item.SubItems.Add($cell) }
        $item.Tag = $sale.Id; $null = $list.Items.Add($item)
    }
    $list.EndUpdate()
    $remaining = Get-RemainingStock $script:state
    if ($script:state.Settings.Ready) { $stockLabel.Text = "Estoque restante: WD $(Format-Stock 'WD' $remaining.WD)   |   JD $(Format-Stock 'JD' $remaining.JD)   |   SD $(Format-Stock 'SD' $remaining.SD)" }
    else { $stockLabel.Text = 'Preencha o estoque inicial na aba Início do turno.' }
    try { $closingReport.Text = Get-ClosingReport $script:state }
    catch { $closingReport.Text = 'Fechamento aguardando dados:' + "`r`n`r`n" + $_.Exception.Message }
}
$tray = New-Object Windows.Forms.NotifyIcon; $tray.Icon = $trayIcon
$tray.Text = 'Sweet Sensation — relatório por hora'; $tray.Visible = $true
function Restore-App {
    $form.Show(); $form.WindowState = 'Normal'; $form.Activate()
}
function Request-Exit {
    $choice = [Windows.Forms.MessageBox]::Show('Encerrar o aplicativo? As vendas registradas estão salvas. Campos ainda não registrados serão descartados e os lembretes vão parar.', 'Sair do Sweet Sensation', 'YesNo', 'Question')
    if ($choice -ne 'Yes') { return }
    $script:allowExit = $true
    $form.Close()
    if (-not $form.IsDisposed) { $script:allowExit = $false }
}
$trayMenu = New-Object Windows.Forms.ContextMenuStrip
$trayMenu.Renderer=New-Object BrandMenuRenderer; $trayMenu.BackColor=$Theme.Wine; $trayMenu.ForeColor=$Theme.Pink
$openTrayItem = New-Object Windows.Forms.ToolStripMenuItem('Abrir Sweet Sensation')
$openTrayItem.Add_Click({ Restore-App })
$exitTrayItem = New-Object Windows.Forms.ToolStripMenuItem('Sair do aplicativo')
$exitTrayItem.Add_Click({ Request-Exit })
$null=$trayMenu.Items.Add($openTrayItem); $null=$trayMenu.Items.Add((New-Object Windows.Forms.ToolStripSeparator)); $null=$trayMenu.Items.Add($exitTrayItem)
$tray.ContextMenuStrip=$trayMenu
$tray.Add_MouseClick({ param($sender,$e) if($e.Button -eq [Windows.Forms.MouseButtons]::Left){ Restore-App } })
$tray.Add_BalloonTipClicked({ Restore-App })
$exitMainItem = New-Object Windows.Forms.ToolStripMenuItem('Sair do aplicativo...')
$exitMainItem.Add_Click({ Request-Exit }); $null=$shiftMenu.DropDownItems.Add($exitMainItem)
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class TaskbarAlert {
 [DllImport("user32.dll")] private static extern IntPtr SendMessage(IntPtr handle, int message, IntPtr wparam, IntPtr lparam);
 public static void Restore(IntPtr handle) { SendMessage(handle, 0x802A, IntPtr.Zero, IntPtr.Zero); }
 [StructLayout(LayoutKind.Sequential)] public struct FLASHWINFO { public uint cbSize; public IntPtr hwnd; public uint dwFlags; public uint uCount; public uint dwTimeout; }
 [DllImport("user32.dll")] public static extern bool FlashWindowEx(ref FLASHWINFO info);
 public static void Flash(IntPtr handle, bool active) { FLASHWINFO f = new FLASHWINFO(); f.cbSize = (uint)Marshal.SizeOf(f); f.hwnd = handle; f.dwFlags = active ? 6u : 0u; f.uCount = 0; f.dwTimeout = 0; FlashWindowEx(ref f); }
}
"@
function Acknowledge-Reminder { [TaskbarAlert]::Flash($form.Handle, $false); $script:reminderPending = $false }
$script:lastCheck = Get-ReminderCheckpoint (Get-Date)
$script:reminderPending = $false
if ($null -eq $script:state.PSObject.Properties['LastReminder']) { $script:state | Add-Member -NotePropertyName LastReminder -NotePropertyValue '' }
$clockLabel = Label $form '' 22 624 770 10
$timer = New-Object Windows.Forms.Timer; $timer.Interval = 500
function Check-Reminder([datetime]$Now) {
    $next = Get-NextReminder $script:state.Settings $Now
    $schedule = 'Cadastre o início do turno para ativar os lembretes.'
    if ($null -ne $next) { $schedule = 'Próximo: ' + (Get-ReminderText $next) }
    elseif ($script:state.Settings.Ready) { $schedule = 'Sem próximos alertas neste turno. Confira a data ou inicie um novo turno.' }
    $clockLabel.Text = 'PC: ' + $Now.ToString('dd/MM/yyyy HH:mm:ss') + ' | ' + $schedule
    $slot = Get-DueReminder $script:state.Settings $script:lastCheck $Now $script:state.LastReminder
    $script:lastCheck = $Now
    if ($null -eq $slot) { return }
    $script:state.LastReminder = $slot.ToString('s')
    try { Save-State } catch { $status.Text = 'Lembrete ativo, mas não foi possível salvar seu horário.' }
    $closing = $slot.Hour -eq 2
    $title = Get-ReminderText $slot
    if ($closing) { $tabs.SelectedTab = $closingTab }
    $status.Text = $title + '. Prepare e envie a mensagem no WhatsApp.'
    if (-not $form.Visible) { $form.ShowInBackground() }
    $script:reminderPending = $true
    [TaskbarAlert]::Flash($form.Handle, $true)
    $tray.BalloonTipTitle = $title
    $tray.BalloonTipText = 'O relatório está pronto. Enviar relatório.'
    $tray.BalloonTipIcon = [Windows.Forms.ToolTipIcon]::Info
    $tray.ShowBalloonTip(15000)
}
$timer.Add_Tick({ Check-Reminder (Get-Date) })
$form.Add_Activated({ if ($script:reminderPending) { Acknowledge-Reminder } })
$form.Add_FormClosing({ param($sender, $e)
    try { Save-State }
    catch { $e.Cancel = $true; [Windows.Forms.MessageBox]::Show("Não foi possível salvar. $($_.Exception.Message)", 'Erro ao salvar') | Out-Null; return }
    if (-not $script:allowExit -and $e.CloseReason -eq [Windows.Forms.CloseReason]::UserClosing) {
        $e.Cancel=$true; $form.Hide()
    }
})
try {
    $script:uiReady = $true; Load-Settings; Reset-Entry; Save-State; Refresh-View
    if ($script:state.Settings.Ready) { Hide-Setup; $form.ActiveControl = $entryRows.WD.Packs }
    else { Show-Setup }
    $status.Text = 'Vendas salvas nesta pasta. O lembrete por hora funciona enquanto o aplicativo estiver aberto.'
    $timer.Start()
    [Windows.Forms.Application]::Run($form)
} catch {
    [Windows.Forms.MessageBox]::Show($_.Exception.Message, 'Erro no aplicativo') | Out-Null
} finally {
    $script:uiReady = $false; $timer.Stop(); $timer.Dispose(); $tray.Visible = $false; $tray.Dispose()
    $trayMenu.Dispose(); $tooltips.Dispose(); $form.Dispose(); $logoImage.Dispose(); $appIcon.Dispose(); $trayIcon.Dispose(); $mutex.ReleaseMutex(); $mutex.Dispose()
}
