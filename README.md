# Private Moments

Aplicativo para Windows que registra vendas, controla estoque e prepara os relatórios por hora e de fechamento para enviar pelo WhatsApp.

## Usar

Baixe [Private-Moments-V13.zip](releases/Private-Moments-V13.zip), extraia todos os arquivos para uma pasta e abra **Private Moments.exe**. Mantenha a pasta `assets` junto ao aplicativo. Só a janela do aplicativo aparece.

A segunda loja tem seu próprio pacote: [Sweet-Sensation-V1.zip](releases/Sweet-Sensation-V1.zip). Extraia em outra pasta e abra **Sweet Sensation.exe**. Ela tem logo S, nome e relatórios próprios. As duas versões podem funcionar ao mesmo tempo, cada uma com seus arquivos de vendas, estoque e turnos. Não misture os arquivos `dados.json` das lojas.

Requer Windows com Windows PowerShell 5.1 e .NET Framework 4.x. Não requer Python, Excel ou instalação de pacotes.

1. Preencha a data, o responsável e os estoques iniciais de WD, JD e SD.
2. Informe as quantidades vendidas nas linhas WD, JD, SD e Cinema. Os preços são automáticos.
3. Escolha Dinheiro ou Cartão; Dividido abre os dois campos. No Shop, digite os valores diretamente em dinheiro/cartão.
4. Registre a venda. O aplicativo limpa os campos e atualiza estoque e relatórios.

Clique novamente na bolinha marcada para desmarcá-la. Escolher outra opção troca o pagamento diretamente; ao desmarcar Dividido, os campos extras são ocultados. A seleção continua independente por categoria.

O botão de registrar só fica disponível quando a venda está válida. A mensagem abaixo do total explica o que falta ou quanto resta pagar. **Ctrl+Enter** registra uma venda válida; **Esc** cancela uma correção. Passe o mouse nos campos para consultar preços e instruções.

As categorias seguem WD → JD → SD → Shop → Cinema. O modelo de fechamento permanece em [app/Fechamento.txt](app/Fechamento.txt), com substituição apenas dos campos variáveis.

O relatório curto mantém WD como a soma dos valores de WD + JD + SD, conforme a regra do estabelecimento. Os valores são calculados em centavos inteiros; WD e SD usam estoque em comprimidos e mostram pacotes/avulsos.

## Lembretes e envio

O relógio segue o PC. Com o aplicativo aberto, os lembretes vão das 12:00 às 01:00; às 02:00 há o aviso de fechamento. O aplicativo solicita o piscar da barra de tarefas e apresenta uma notificação. A apresentação e pequenos atrasos dependem do Windows. Computador desligado/em suspensão ou aplicativo fechado impedem o aviso no horário exato.

Cada aviso mostra o próprio horário: “14:00 — Enviar relatório”, “00:00 — Enviar relatório” e, exclusivamente às 02:00, “02:00 — Enviar relatório de fechamento”. O rodapé mostra o próximo alerta. Ao retomar após uma pausa, só há aviso se existir um horário programado na hora atual; um fechamento antigo não reaparece à tarde.

Na V13, iniciar um turno entre 00:00 e 02:59 sugere a data de abertura do dia anterior. Dados existentes com a data de hoje cadastrada de madrugada recebem os avisos de 01:00/02:00 na madrugada atual, sem alterar a data salva no relatório. Reabrir o app durante uma hora programada emite o aviso pendente daquela hora uma vez, respeitando o último horário já avisado.

O WhatsApp abre a mensagem pronta. Você escolhe a conversa e confirma o envio; não há envio automático nem confirmação de recebimento.

## Dados e atualização

O **X** esconde a janela silenciosamente no ícone perto do relógio, mantendo o turno, campos ainda digitados e lembretes ativos. Clique no ícone ou abra o executável novamente para voltar. Ao chegar um lembrete, a janela volta à barra de tarefas sem tomar o foco.

Para encerrar de verdade, clique com o botão direito no ícone e escolha **Sair do aplicativo** (também disponível no menu Turno). As vendas registradas são gravadas em disco e reaparecem ao abrir novamente. A saída explícita confirma que campos ainda não registrados serão descartados; o X apenas os mantém na janela escondida. Encerrar o Windows encerra o processo normalmente.

Os arquivos `dados.json`, `dados.backup.json` e a pasta `turnos/` ficam junto ao aplicativo. Contêm informações financeiras e estão excluídos do Git. Não há sincronização entre computadores.

Para atualizar mantendo o turno, feche a versão anterior e copie seu `dados.json` para a pasta nova antes de abrir. Não substitua dados de outro turno. As vendas anteriores mantêm seus valores históricos; editar uma linha aplica os preços atuais. Dados da V1 precisam ter pagamentos e quantidades completados.

## Desenvolvimento

A identidade visual usa o P com beijo escolhido pelo usuário, vinho `#590027` e rosa `#F7A6CE`. O fundo da logo foi finalizado por código para ter cor uniforme. A marca aparece no executável, janela, cabeçalho e ícone de notificação. A interface usa essa paleta com superfícies claras para leitura. Os controles do sistema operacional mantêm suas convenções de plataforma.

- `app/`: aplicativo e regras de negócio em PowerShell/Windows Forms.
- `src/Launcher.cs`: código do executável que inicia o aplicativo sem console.
- `src/LogoAssets.cs` e `src/Build-Logo.ps1`: finalização da logo em duas cores e geração de ICO com tamanhos de 16 a 256 pixels. Execute `src/Build-Logo.ps1` no Windows PowerShell para regenerar a partir de `src/logo-reference.png`.
- `app/assets/`: logo PNG e ícone ICO usados na interface e incorporados ao executável.
- `tests/Verify.ps1`: cálculos, estoque, pagamentos, relatórios, lembretes e interação com a interface, usando dados sintéticos em pastas isoladas.
- `docs/UX.md`: avaliação e mudanças orientadas pelas skills solicitadas.

Compilar e criar ZIP no PowerShell:

```powershell
.\build.ps1 -Package
.\build-sweet.ps1 -Package
```

Testar no Windows PowerShell em modo STA (abre brevemente uma janela de teste):

```powershell
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Verify.ps1
powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File .\tests\Verify-Sweet.ps1
```

`build-sweet.ps1` gera o aplicativo da segunda loja a partir do mesmo código validado, aplicando os nomes e identificadores próprios e usando os assets em `brands/sweet-sensation/`. Também gera os testes equivalentes para essa marca. Os testes usam mutexes únicos para funcionar mesmo com os aplicativos reais das lojas abertos.

## Referências de UX

Foram usados os frameworks de Tommy Jepsen em [Awesome UX Skills](https://github.com/tommyjepsen/awesome-ux-skills) e as orientações de formulários e dashboards de Richard [@richardrx](https://x.com/richardrx), compiladas por Helio Costa em [Revenue-Centric Design](https://github.com/heliocosta-dev/revenue-centric-design). Detalhes e atribuição em [docs/UX.md](docs/UX.md); termos integrais dessa referência em [third-party/revenue-centric-design-LICENSE.txt](third-party/revenue-centric-design-LICENSE.txt).
