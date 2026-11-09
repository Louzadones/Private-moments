# Revisão de UX — versão 7

Base funcional sólida; os principais atritos eram feedback tardio de pagamento e pouca distinção da ação principal.

## Avaliação aplicada

- **Carga cognitiva:** a soma já era automática, mas o operador precisava descobrir por tentativa se o pagamento estava completo. A interface agora informa o valor que falta ou excede antes de registrar.
- **H1 — estado visível:** a mensagem abaixo do total distingue formulário vazio, pendências e venda pronta.
- **H5/H9 — prevenir e corrigir erros:** registrar só fica disponível para vendas válidas. A validação no momento de salvar continua existindo como segunda verificação.
- **H7 — eficiência:** Ctrl+Enter registra; Esc cancela correção. A sequência de Tab do estoque permanece WD pacote → WD avulso → JD → SD pacote → SD avulso.
- **H8 — hierarquia:** a ação principal tem cor de destaque; ações de correção e exclusão continuam secundárias. A grade, as colunas de pagamento e os campos vazios definidos pelo usuário foram preservados.
- **Reconhecimento e acessibilidade:** campos têm nomes acessíveis com categoria e finalidade; instruções de preço e pagamento ficam em dicas junto ao controle. As opções não são pré-selecionadas. O estado inválido tem explicação textual além da cor.

Não foi realizada auditoria com leitor de tela nem certificação WCAG; os testes cobrem lógica, navegação de teclado e interação programática, complementados por inspeção visual.

## Fontes e atribuição

### Awesome UX Skills — Tommy Jepsen

Repositório: https://github.com/tommyjepsen/awesome-ux-skills

Revisão consultada: `4e5d0925e1a0d34894734611b225205aa10e5a2f`.

Skills consultadas: `cognitive-load-conversion`, `ux-heuristics-review`, `accessibility` e `craft`. Aplicação: reduzir decisões e ruído, distinguir a ação principal, informar pendências, preservar controle do usuário e facilitar navegação.

### Revenue-Centric Design — Richard / @richardrx

Ideias e frameworks: Richard, https://x.com/richardrx. Curadoria: https://github.com/heliocosta-dev/revenue-centric-design, revisão `1942760c2242f609bf63ce2c97204f5a1791bd68`.

Mecanismos usados: reduzir fricção em formulários e mostrar a próxima ação relevante no painel. Referências específicas:

- “You lose money on the boring screens”: https://x.com/richardrx/status/2003495704849760387
- “Removing information creates room for direction”: https://x.com/richardrx/status/2075623473565647202

Os textos completos das skills não foram incorporados ao aplicativo. Os termos da referência Revenue-Centric Design são preservados integralmente em `third-party/revenue-centric-design-LICENSE.txt`, incluindo sua exclusão de uso em apostas, cassino e jogos de azar. Os preços, modelos de relatório e fluxos deste aplicativo são as regras definidas pelo usuário; não foram introduzidas práticas de persuasão comercial.
