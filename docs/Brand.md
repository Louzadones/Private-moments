# Identidade visual — Private Moments

O usuário escolheu o P com beijo entre três propostas geradas por imagem e pediu remover toda textura do fundo, preservando a forma. Depois de uma tentativa de edição por geração de imagem, autorizou explicitamente a finalização dos pixels por código.

## Cores

| Uso | Cor |
| --- | --- |
| Vinho principal e fundo da marca | `#590027` |
| Rosa da marca e realces | `#F7A6CE` |
| Fundo do aplicativo | `#FFF3F8` |
| Superfícies de entrada/leitura | `#FFFBFD` |
| Texto | `#3B1026` |
| Texto secundário | `#76445C` |
| Bordas | `#C8739A` |
| Erro em texto | `#A31B46` |

O sinal de erro inclui explicação escrita; não depende só da cor. A cor forte de foco e os controles nativos de teclado são preservados. Cores de seleção de texto e a moldura do Windows são controladas pelo sistema.

## Arquivos

- `src/logo-reference.png`: proposta de referência escolhida.
- `app/assets/logo.png`: desenho final com exatamente duas cores opacas e exterior transparente, sem manchas ou variação de opacidade no interior.
- `app/assets/app.ico`: quadros de 16, 24, 32, 48, 64, 128 e 256 pixels com suavização ao reduzir.
- `src/LogoAssets.cs`: preserva o desenho do P/beijo por separação de tons claros/escuros e normaliza cor e opacidade; transforma a imagem final em ICO.

O PNG final tem duas cores opacas; os tamanhos pequenos do ICO incluem tons intermediários necessários à suavização das bordas. O script `Build-Logo.ps1` verifica o número de cores e a ausência de transparência parcial no PNG final.

A marca foi criada com geração integrada de imagens e finalizada por código sob autorização do usuário. A interface passou por inspeção visual e testes de cálculo, formulário, ícones, teclado, lembretes e área de notificação. Isso não constitui certificação WCAG nem teste com leitores de tela.
