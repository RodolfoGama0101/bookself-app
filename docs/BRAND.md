# Marca Lume — NAME-01/02/03

## Decisão de nome — 09/10/2026

O usuário escolheu **Lume** explicitamente após avaliar **A Dois** e pedir opções abstratas. O nome sugere descoberta e conexão entre repertórios; funciona para livros, filmes, séries e música, com uso individual ou em casal. Frase de apoio definida para a comunicação: **“Seu repertório, suas conexões.”** Essa decisão encerra NAME-01.

## Busca preliminar de disponibilidade — NAME-02

Consulta em 09/10/2026. Os resultados abaixo demonstram colisões de uso, não estabelecem alcance de direitos nem disponibilidade registral:

| Área | Resultado observado | Fonte |
| --- | --- | --- |
| Produto de livros | Lume se apresenta como ferramenta para organizar estante e conhecer preferências de leitura. É o conflito de produto mais próximo. | [lume.pub](https://lume.pub/) |
| App Store Brasil, Livros | “Lume: Histórias de Ninar” usa Lume no título, com conteúdo de leitura/áudio. | [App Store](https://apps.apple.com/br/app/lume-hist%C3%B3rias-de-ninar/id6743057850) |
| App Store Brasil, casal | “Perguntas para Casais: Lume” usa Lume no título. | [App Store](https://apps.apple.com/br/app/perguntas-para-casais-lume/id6741214759) |
| Google Play Brasil | “Lume: Diário Guiado” usa Lume como marca de app pessoal. | [Google Play](https://play.google.com/store/apps/details?hl=pt_BR&id=com.victorbrndls.lifestory) |
| INPI, busca pública | A [nova busca de marcas](https://servicos.busca.inpi.gov.br/marcas) retornou 475 resultados para “Lume”; 26 após filtro da classe de Nice 09. Entre eles, “GRUPO LUME” (processo 914393227, marca em vigor, especificação “Aplicativos para download”) e pedido “LUME” (928586847, aplicativo de gestão escolar, em recurso contra indeferimento). A interface informa **ambiente de homologação** e dados atualizados até 07/07/2026; esses resultados não determinam colidência jurídica específica nem cobrem pedidos posteriores. | [Busca INPI](https://servicos.busca.inpi.gov.br/marcas) |
| Domínio .com.br | `lume.com.br` já apresenta um site ativo de outro negócio; não é um domínio disponível para a marca. | [lume.com.br](https://www.lume.com.br/) |
| Perfil social | Outro app Lume informa uso do perfil `@br_lume`; a disponibilidade do identificador exato pretendido não foi confirmada. | [Sobre o app](https://brlume.app/sobre) |

O usuário foi informado dos conflitos preliminares e optou por **manter Lume no app local**. A busca nova é de homologação e tem defasagem declarada. Busca comum ou ausência de resultado não autorizam declarar a marca disponível. A avaliação de NAME-02 é uma triagem de conflitos, sem parecer jurídico nem reserva de marca.

### Revisão adicional — 09/10/2026

Na mesma [busca pública de homologação do INPI](https://servicos.busca.inpi.gov.br/marcas), o filtro de Nice **41** mostrou 59 resultados para “Lume”. Entre os resultados exibidos, o pedido nominativo **LUME** 926667262 (serviços de entretenimento, música e publicações eletrônicas) aparecia em recurso contra indeferimento; o pedido misto **Lume** 940319390 incluía produção musical, filmes, vídeos e atividades culturais, aguardando manifestação sobre oposição. O filtro **42** mostrou 26 resultados; **Lume tecnologia** 903990563 aparecia como marca mista em vigor para serviços de software. Esses estados são apenas o retrato exibido pela base defasada; não foram comparados juridicamente os sinais nem as especificações completas com o produto.

A [RPI 2909 de 06/10/2026](https://revistas.inpi.gov.br/rpi/?revista.numerop=1) já está listada pelo INPI. Desde essa edição, a seção de marcas tem [dois volumes PDF e um XML](https://www.gov.br/inpi/pt-br/central-de-conteudo/noticias/inpi-passara-a-publicar-a-secao-de-marcas-da-rpi-em-dois-volumes). A ferramenta de leitura não conseguiu abrir os PDFs grandes nem o ZIP/XML; portanto **não foi verificado se houve despachos novos sobre esses processos**. A busca de homologação ainda declara dados até 07/07/2026.

**Conclusão de NAME-02:** a triagem de 09/10/2026 encontrou colisões em produto semelhante, lojas, domínio e marcas nas classes relacionadas. O resultado é **disponibilidade não demonstrada; Lume não está liberado por esta verificação para publicação ou pedido de registro**. O conflito foi encaminhado ao usuário junto de opções de novo nome; ele optou por manter Lume somente no app local. Não foi definido um identificador social/domínio alternativo exato, logo nenhum foi reservado ou declarado disponível. Antes de publicar sob essa marca, consultar os despachos atuais da RPI e processos relevantes, confirmar classes/semelhança e direitos com profissional qualificado, e verificar domínios e perfis exatos que serão usados. Essas são exigências de publicação, não uma conclusão favorável da triagem. A decisão local do usuário não representa afirmação de exclusividade.

## Aplicação local — NAME-03

Os títulos visíveis Flutter, login, navegação, Android, iOS e web/manifesto usam **Lume**. Um símbolo abstrato de dois arcos e luz central, em dourado/creme sobre marrom escuro, substitui o desenho antigo de livros. Fonte em `assets/lume_icon.png`; ícones de Android, iOS e web regenerados com `flutter pub run flutter_launcher_icons`. Prompt da geração integrada: ícone quadrado abstrato de dois arcos que se encontram em um brilho central, visual geométrico simples, sem livro/filme/nota/chama/letra/texto, dourado e creme sobre marrom escuro.

`pubspec.yaml` mantém o identificador Dart `bookself_app`; package/bundle IDs, projeto Firebase e configuração gerada permanecem intactos. A mudança de marca exibida não implica migração técnica. Validação local: `dart format` sem mudanças adicionais, `flutter analyze --no-pub` sem apontamentos, 506 testes em `flutter test --no-pub`, build web demo e APK debug demo aprovados; XML do iOS e JSON web válidos, PNGs em RGB e dimensões esperadas. O build iOS e a inspeção visual em dispositivos não foram executados neste ambiente Windows. Nenhuma loja ou produção foi atualizada; a triagem NAME-02 não liberou publicação sob Lume.
