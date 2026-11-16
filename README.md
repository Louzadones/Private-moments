# Private Moments

Aplicativo para Windows que registra vendas, controla estoque e prepara os relatórios por hora e de fechamento para enviar pelo WhatsApp.

Interface clara com fundo branco e detalhes em vinho e rosa. O menu lateral organiza **Vendas e relatórios**, **Fechamento detalhado** e **Histórico**. Os dados iniciais continuam em **Turno e estoque**.

## Usar

Baixe [Private-Moments-V22.zip](releases/Private-Moments-V22.zip), extraia todos os arquivos para uma pasta e abra **Private Moments.exe**. Mantenha a pasta `assets` junto ao aplicativo. Só a janela do aplicativo aparece. A interface roda no próprio executável, com ícone e identidade próprios na barra de tarefas.

A segunda loja tem seu próprio pacote: [Sweet-Sensation-V10.zip](releases/Sweet-Sensation-V10.zip). Extraia em outra pasta e abra **Sweet Sensation.exe**. Ela tem logo S, nome e relatórios próprios. Cinema custa **€15 no Sweet Sensation** e **€18 no Private Moments**. As duas versões podem funcionar ao mesmo tempo, cada uma com seus arquivos de vendas, estoque e turnos. Não misture os arquivos `dados.json` das lojas.

Promoções nos dois apps: **5 pacotes de WD (20 comprimidos) por €180** e **7 JD por €90**. WD usa automaticamente grupos de 5 pacotes, com os pacotes restantes a €50 e avulsos a €15: 6 pacotes = €230, 10 = €360. A baixa continua sendo pela quantidade real vendida. Valores de vendas já salvas não são alterados retroativamente.

O calendário de um novo turno abre com a data atual do PC e mostra o dia da semana. A data do registro é separada da abertura: um cadastro na madrugada de terça pode mostrar terça no calendário e manter segunda no fechamento. Corrigir estoque ou nome sem mudar a data do calendário preserva a data de abertura já salva. Vendas históricas conservam seus valores; o novo preço de Cinema se aplica aos novos lançamentos e às correções confirmadas pelo operador.

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

Iniciar um turno entre 00:00 e 02:59 sugere a data de abertura do dia anterior. O fechamento usa essa data fixa para DATE e DAY, inclusive depois da meia-noite. A V14 corrige uma vez os dados antigos que gravaram o novo dia ao cadastrar o turno de madrugada, sem alterar vendas ou estoques. Datas explicitamente salvas no formato atual continuam sendo respeitadas. Reabrir o app durante uma hora programada emite o aviso pendente daquela hora uma vez, respeitando o último horário já avisado.

O WhatsApp abre a mensagem pronta. Você escolhe a conversa e confirma o envio; não há envio automático nem confirmação de recebimento.

## Dados e atualização

O **X** esconde a janela silenciosamente no ícone perto do relógio, mantendo o turno, campos ainda digitados e lembretes ativos. Clique no ícone ou abra o executável novamente para voltar. Ao chegar um lembrete, a janela volta à barra de tarefas sem tomar o foco.

Para encerrar de verdade, clique com o botão direito no ícone e escolha **Sair do aplicativo** (também disponível no menu Turno). As vendas registradas são gravadas em disco e reaparecem ao abrir novamente. A saída explícita confirma que campos ainda não registrados serão descartados; o X apenas os mantém na janela escondida. Encerrar o Windows encerra o processo normalmente.

Os arquivos `dados.json`, `dados.backup.json`, `Vendas_*.txt` e as pastas de histórico ficam junto ao aplicativo. Contêm informações financeiras e estão excluídos do Git. Não há sincronização entre computadores.

## Fechar turno, histórico diário e mensal

Depois de enviar o último relatório, clique em **Fechar turno**. A confirmação informa a data e o total. Campos com venda ainda digitada impedem fechar até registrar ou limpar. O app salva o turno, seu fechamento e o resumo diário, e prepara o início do próximo turno. Reabrir depois mostra o calendário atual e os campos de estoque para o novo dia. Se não fechou o turno, o aplicativo conserva os registros em andamento.

- `historico/turnos/<id>.json`: dados completos de cada turno fechado.
- `historico/fechamentos/Fechamento_AAAA-MM-DD_<id>.txt`: fechamento detalhado.
- `historico/diarios/Vendas_AAAA-MM-DD.txt`: totais de WD, Shop, Cinema e TOTAL para os turnos fechados naquele dia de abertura.
- `Vendas_AAAA-MM.txt`: registro mensal na pasta principal, pronto para abrir no Bloco de Notas. Exemplo: `Vendas_2026-11.txt`.

No último dia do mês, o app gera e mantém atualizado o registro mensal, incluindo o turno atual. Ao fechar o turno de madrugada, o valor continua pertencendo ao mês de abertura. Se o app estava fechado na virada do mês, gera o arquivo pendente ao reabrir. O app precisa estar aberto para executar a gravação no próprio último dia; não instala serviço ou tarefa agendada no Windows.

A aba **Histórico e arquivos** lista os turnos fechados e permite abrir o diário ou gerar um resumo de qualquer mês. A linha WD soma WD + JD + SD, como no relatório por hora. O histórico antigo em `turnos/*.json` também é usado; turnos repetidos são desduplicados. Valores anteriores não são recalculados pelos preços atuais. Arquivos inválidos geram uma mensagem, em vez de serem ignorados silenciosamente.

O fechamento é identificado por um ID estável: repetir uma tentativa não soma o mesmo turno duas vezes. Um reinício entre arquivar e preparar o próximo turno recupera o estado de início sem perder o turno salvo. As gravações substituem arquivos de forma atômica, com cópia `.backup` quando há uma versão anterior.

Para atualizar mantendo o turno, feche a versão anterior e copie seu `dados.json` para a pasta nova antes de abrir. Não substitua dados de outro turno. As vendas anteriores mantêm seus valores históricos; editar uma linha aplica os preços atuais. Dados da V1 precisam ter pagamentos e quantidades completados.

## Desenvolvimento

A identidade visual usa o P com beijo escolhido pelo usuário, vinho `#590027` e rosa `#F7A6CE`. O fundo da logo foi finalizado por código para ter cor uniforme. A marca aparece no executável, janela, cabeçalho e ícone de notificação. A interface usa essa paleta com superfícies claras para leitura. Os controles do sistema operacional mantêm suas convenções de plataforma.

- `app/`: aplicativo e regras de negócio em PowerShell/Windows Forms.
- `src/Launcher.cs`: executável Windows que hospeda o motor PowerShell em sua própria thread STA. A janela pertence ao aplicativo, em vez de a `powershell.exe`, e usa seu ícone e AppUserModelID.
- `app/History.ps1`: fechamento idempotente, histórico diário e exportação mensal, com importação dos arquivos antigos.
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

## Entradas de estoque e mensagens

Use **Entrada de estoque** para registrar o que chegou durante o turno: WD e SD em pacotes de quatro e avulsos; JD por unidade. Cada entrada fica salva com data e identificador no turno e não altera as vendas ou o estoque inicial. O disponível e o estoque final incluem as entradas, descontando as vendas.

Ao salvar os dados iniciais, o app mostra o texto de abertura com botão para copiar. **Texto do estoque inicial** recupera esse texto. Após registrar uma entrada, **Copiar Update** copia o estoque disponível atualizado, com o título da loja seguido de Update. **Texto Update atual** permite consultar novamente. O Float permanece €150.
