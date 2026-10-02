# Arquitetura

Revisão: 02/10/2026. As seções iniciais descrevem o código atual; a evolução ao final é uma proposta.

## Inicialização e interface atuais

`lib/main.dart` inicializa Firebase e registra `AuthService` e `ThemeService` em `MultiProvider`. `BookselfApp` observa esses serviços e mostra login ou `MainNavigation` conforme a existência de `currentUserModel`.

`MainNavigation` usa `IndexedStack` com Início, Estante, Bíblia e Perfil. Busca é acessada pela estante. Serviços de livros e Bíblia são instanciados nas telas; não há backend próprio versionado.

Erros de inicialização Firebase são capturados, mas o app continua criando serviços dependentes de Firebase. Não há estado explícito de inicialização/falha ou modo local completo. A sessão autenticada depende também da chegada do documento de usuário no Firestore.

## Responsabilidades

| Camada | Local | Responsabilidade |
| --- | --- | --- |
| Modelos | `lib/data/models/` | Serialização de usuário, livro e progresso bíblico. |
| Dados bíblicos | `lib/data/bible_data.dart` | Nomes, capítulos e testamento dos 66 livros, sem versículos. |
| Autenticação | `lib/services/auth_service.dart` | Conta, streams de perfil/parceiro, vínculo e desvínculo. |
| Livros | `lib/services/book_service.dart` | Google Books, persistência e streams de estante/feed. |
| Bíblia | `lib/services/bible_service.dart` | Progresso e marcação de capítulos com transação. |
| Tema | `lib/services/theme_service.dart` | Alternância em memória, com modo escuro inicial. |
| Interface | `lib/ui/` | Formulários, navegação, estatísticas e exibição. |
| Erros | `lib/utils/error_handler.dart` | Conversão parcial de erros para português. |

`ProfileScreen` escreve nome/foto diretamente no Firestore. Fotos são reduzidas e armazenadas como data URI Base64 no perfil; o código atual não usa Firebase Storage.

## Dados no Firestore

| Coleção e ID | Campos principais | Uso |
| --- | --- | --- |
| `users/{uid}` | `uid`, `name`, `email`, `partnerUid`, `photoUrl`, `createdAt` | Perfil e ligação ao parceiro. |
| `books/{documentId}` | `userId`, `title`, `authors`, `coverUrl`, `status`, `publishedDate`, `finishedDate`, `addedAt` | Livro na estante de uma pessoa. |
| `bible_progress/{uid_nomeNormalizado}` | `userId`, `bookName`, `readChapters`, `updatedAt` | Capítulos lidos por pessoa/livro bíblico. |

Inclusão pela busca e formulário manual força um ID vazio para criar documento próprio. `BookService.saveBook` aceita IDs existentes para atualizar. O ID do Google Books não é mantido em campo próprio no documento, dificultando detecção de duplicatas e reconciliação de catálogo.

O feed consulta livros de uma ou duas pessoas, ordenados por `addedAt` no cliente. Alterações de status também atualizam esse campo: ele representa inclusão e última atividade. Não há histórico separado de eventos. Estatísticas mensais/anuais usam o estado atual `Lido` e `finishedDate`.

## Vínculo e autorização atuais

O código de vínculo é o UID da outra conta. `linkPartner` consulta o perfil, verifica o vínculo do destinatário e atualiza ambos os perfis com batch. Não existe convite pendente, aceite ou validação transacional das duas contas para evitar vínculos concorrentes. Desvinculação também escreve nos dois perfis.

A estante do parceiro aparece sem controles de edição. Não é possível concluir pelo repositório se o banco remoto impede acesso indevido: regras e índices não estão versionados. Essa autorização precisa ser auditada e testada em emuladores.

## Limitações observadas

- `BookModel.copyWith` usa `??`, impossibilitando limpar `finishedDate` com `null`.
- A assinatura de `authStateChanges` não é guardada nem encerrada em `dispose` de `AuthService`.
- Algumas operações assíncronas podem chamar `setState` depois do fechamento da tela.
- Marcação bíblica não aguarda persistência antes de anunciar sucesso/finalizar a interação.
- Falhas de busca recebem mensagem genérica de cota/indisponibilidade.
- Estante/feed não têm paginação; ordenação e estatísticas ocorrem em memória.
- Tema não persiste. Imagens e serviços externos requerem avaliação de uso sem rede.

As tarefas correspondentes estão em [BACKLOG.md](../BACKLOG.md).

## Proposta para múltiplas mídias

Consolidar esta proposta em uma decisão técnica antes da implementação. As entidades abaixo não são o esquema atual nem uma migração já autorizada.

| Entidade proposta | Dados | Motivo da separação |
| --- | --- | --- |
| Item de catálogo | Tipo, fornecedor, ID externo, título, imagem, metadados específicos. | Uma obra pode existir nas bibliotecas de várias pessoas. |
| Entrada pessoal | Dono, item, status, datas, nota/comentário, visibilidade. | Progresso e opinião de uma pessoa não substituem os do parceiro. |
| Progresso específico | Episódios/temporadas e estados apropriados por mídia. | Categorias não compartilham todos os campos. |
| Relação e convite | Participantes, estado, aceite, criação, expiração, encerramento. | Acesso depende de vínculo ativo e consentido. |
| Lista/experiência do casal | Relação, itens, participantes, datas compartilhadas. | Fazer algo juntos difere de possuir a mesma obra. |
| Evento de atividade | Autor, mídia, ação, instante, visibilidade. | Histórico deve ser independente do estado e data de inclusão. |

Identidade de catálogo deve combinar fornecedor, tipo e ID externo. Itens manuais precisam de identidade própria. Estados internos estáveis devem ser traduzidos na apresentação e ter regras por categoria. Bíblia conserva progresso próprio e compatibilidade.

Compartilhar busca, capas, cards e filtros quando útil. Manter formulários/progresso específicos: músicas não precisam de capítulos; séries exigem mais que um único estado assistido.

## Migração proposta

Antes de substituir coleções: inventariar dados/regras, definir versão de esquema, preparar backup e ensaio em ambiente separado, testar migração repetível e compatibilidade com clientes antigos, e documentar recuperação. A publicação da migração é uma etapa explícita, distinta da criação de seu código.

Trocar nome exibido não exige trocar IDs técnicos. Alterações de `applicationId`, bundle ID e projeto Firebase precisam de avaliação própria. A expansão deve preservar contas, livros, vínculos e capítulos lidos.
