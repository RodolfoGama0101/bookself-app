# Bookself App

Aplicativo de organização de leituras para uso individual e em casal, desenvolvido em Flutter com Firebase. Cada pessoa mantém sua estante, acompanha capítulos bíblicos lidos e pode consultar a estante e o progresso do parceiro vinculado.

O produto está em fase de MVP. A evolução planejada inclui filmes, séries e músicas. **Entrelace** é a proposta inicial de novo nome; a escolha e a aplicação da marca ainda estão pendentes. O aplicativo continua se chamando Bookself App no código.

## Documentação

| Arquivo | Conteúdo |
| --- | --- |
| [BACKLOG.md](BACKLOG.md) | Fonte central de tarefas, prioridades, dependências e critérios de conclusão. |
| [AGENTS.md](AGENTS.md) | Orientações para trabalhar neste repositório. |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Arquitetura atual, limitações e proposta de evolução. |
| [docs/PRODUCT.md](docs/PRODUCT.md) | Expansão, experiência do casal e nomes candidatos. |
| [docs/INTEGRATIONS.md](docs/INTEGRATIONS.md) | Integrações atuais e candidatas, com fontes oficiais. |

## Funcionalidades implementadas

- Cadastro, login, recuperação de senha e saída com Firebase Authentication.
- Restauração de sessão com estados de carregamento/erro e conclusão de perfil após cadastro parcial, preservando perfis existentes.
- Busca de livros no Google Books e cadastro manual.
- Estante com os estados “Quero Ler”, “Lendo” e “Lido”, data de conclusão e histórico por mês e ano.
- Limpeza da data de conclusão ao mudar um livro de “Lido” para “Lendo” ou “Quero Ler”.
- Vínculo de duas contas por código, consulta da estante do parceiro e feed de atividades recentes de livros.
- Acompanhamento de capítulos lidos nos 66 livros da Bíblia, com comparação do progresso do casal. Marcação individual/em lote aguarda confirmação, bloqueia ações repetidas e permite nova tentativa após falha.
- Edição de nome e foto de perfil, além de tema claro e escuro.
- Fechamento seguro de busca, perfil, detalhes e diálogos durante requisições, com resultado de exclusão na estante.

A seção da Bíblia registra progresso: **não contém textos ou versículos para leitura**. Filmes, séries e músicas ainda não estão implementados. O vínculo atual é direto por código, sem etapa de aceite. A preferência de tema ainda não persiste ao reiniciar.

## Tecnologias e plataformas

Flutter/Dart, Provider, Firebase Core, Firebase Authentication, Cloud Firestore, HTTP, Google Fonts, Image Picker e Intl. O requisito declarado de Dart é `^3.12.0` em `pubspec.yaml`.

Há projetos para Android, iOS e web, com opções Firebase para essas plataformas. Isso não significa que todas tenham sido validadas em execução. Windows, macOS e Linux não possuem configuração Firebase nesta versão.

## Configuração e execução

1. Instale um Flutter SDK compatível com o requisito de Dart do projeto.
2. Na raiz do repositório, instale as dependências:

   ```sh
   flutter pub get
   ```

3. Configure um ambiente Firebase de desenvolvimento com Authentication por e-mail/senha e Firestore. O repositório já possui configuração de um projeto Firebase; confirme o ambiente antes de usá-la. Para apontar para outro projeto, use o FlutterFire CLI:

   ```sh
   flutterfire configure
   ```

   O Firebase é necessário ao fluxo atual. Durante a inicialização, o app mostra carregamento; se ela falhar, mostra uma tela com “Tentar novamente”. Os serviços de autenticação e dados só ficam disponíveis após a inicialização válida. Isso não oferece um modo funcional sem Firebase nem comprova conectividade/autorização dos serviços remotos. Regras do Firestore não estão versionadas; autorização e emuladores são tarefas do backlog.

4. Para busca de livros, configure e restrinja a chave do Google Books conforme o ambiente. Atualmente ela está embutida em `lib/services/book_service.dart`; a configuração externa está pendente. O cadastro manual permite registrar livros quando a busca está indisponível.
5. Com um emulador ou dispositivo disponível:

   ```sh
   flutter run
   ```

   Para web:

   ```sh
   flutter run -d chrome
   ```

## Validação

```sh
flutter analyze --no-pub
flutter test --no-pub
```

Na validação de **02/10/2026**, 106 testes passaram: quatro sobre dados bíblicos, cinco sobre inicialização, 13 sobre sessão/ciclo de vida, cinco sobre persistência de perfil, cinco sobre as telas de sessão/recuperação, 14 sobre modelos de livro/usuário, 28 sobre operações assíncronas da interface e 32 sobre persistência/interface do progresso bíblico.

Usam inicializadores controlados e fakes, sem acessar o Firebase remoto. As novas regressões verificam fechamento de busca/perfil/detalhes durante sucesso ou falha, descarte de diálogos por cancelar/barreira/voltar, retorno de seletores de data após fechamento, ausência de sucesso antes da escrita e feedback de exclusão após retirar o cartão do stream. A cobertura bíblica verifica marcar/desmarcar, bloqueio de operações repetidas, rejeição/indisponibilidade, confirmação atrasada, conflito simulado, falha longe do topo em Salmos e tratamento de falha em 320 × 480 com texto 2×. As fontes nesses testes são substituídas por uma fonte já empacotada pelo Flutter, sem rede; não validam tipografia. Cobrem carregamento, erros, limites de espera, recuperação de cadastro parcial, preservação de perfil existente, descarte/logout/troca de conta, limpeza de campos opcionais e layout em tela pequena com texto ampliado e teclado. A repetição de transação por conflito é simulada; autorização e concorrência real precisam de emuladores.

A análise estática encontrou 44 apontamentos informativos, sem erros ou warnings; o comando encerrou com código 1 por esses apontamentos. O baseline inicial era de 47 infos; os três logs brutos removidos nas correções de inicialização/sessão eliminaram três apontamentos.

Não foram validados: login real, regras do banco remoto, telas em dispositivo e builds de distribuição. Há um `build.log` local com falha anterior de compilação Android, cuja causa precisa ser reproduzida com a configuração atual. A configuração Android de release ainda usa assinatura de debug.

## Estrutura

```text
lib/
  main.dart             Inicialização e escolha entre login e navegação
  firebase_options.dart Configuração gerada pelo FlutterFire
  data/                 Modelos e catálogo local de livros bíblicos
  services/             Autenticação, livros, progresso bíblico e tema
  ui/                   Telas, componentes e temas
  utils/                Tratamento de erros
test/                   Testes existentes
docs/                   Documentação técnica e de produto
android/ ios/ web/       Projetos e configuração por plataforma
```

Consulte o [backlog](BACKLOG.md) antes de iniciar uma melhoria. A expansão deve preservar contas, livros e progresso bíblico existentes.
