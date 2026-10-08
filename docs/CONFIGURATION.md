# Configuração e credenciais

Inventário local de 03/10/2026, sem valores de chaves, tokens ou dados pessoais. Escopo: arquivos versionados e novos arquivos do projeto, excluindo artefatos, dependências e credenciais externas da máquina. Nenhuma credencial foi criada, revogada ou rotacionada.

| Origem | Classificação e ambiente | Situação |
| --- | --- | --- |
| `lib/firebase_options.dart` | Configuração Firebase distribuída de Android/iOS/web, gerada pelo FlutterFire. | Três ocorrências de chave de cliente. Preservada; apontar para outro ambiente exige regeneração deliberada. |
| `android/app/google-services.json` | Configuração nativa Android do Firebase distribuído. | Uma ocorrência de chave de cliente. Preservada. Não há arquivo GoogleService-Info.plist no projeto iOS atual; ele usa as opções Dart. |
| `lib/services/book_service.dart` | Identificador de cliente Google Books. | Literal removido; lê `GOOGLE_BOOKS_API_KEY` em tempo de compilação. |
| `config/google-books.local.json` | Configuração local de Google Books. | Chave preexistente preservada localmente, ignorada por `/config/*.local.json`. Nunca publicar esse arquivo. |
| `config/google-books.example.json` | Exemplo compartilhável. | Valor vazio; não permite consultar o catálogo até ser configurado. |
| `firebase.emulators.json` e defines de emulador | Ambiente isolado Auth/Firestore `demo-bookself`. | Sem credenciais remotas, hosts locais explícitos, sem fallback para produção. |
| Credenciais administrativas/assinatura | Service account, chave privada, keystore e senhas de distribuição. | Nenhuma chave privada PEM nem JSON `service_account` encontrada nos arquivos de texto inventariados. Release Android ainda usa assinatura debug (REL-02); não há armazenamento de assinatura de distribuição implementado. |

As opções de cliente Firebase identificam o projeto, mas não autorizam acesso ao banco. Regras/IAM e restrições de chaves são controles separados. A sessão autenticada do Firebase CLI pertence à máquina, fica fora do repositório e não deve ser copiada para código, logs ou exemplos.

## Google Books por ambiente

Copie `config/google-books.example.json` para `config/google-books.local.json` e preencha somente no arquivo local com a chave de desenvolvimento apropriada. Nesta máquina, a chave antes embutida já foi preservada nesse destino. Não coloque o valor na linha de comando, no backlog ou em logs.

```sh
flutter run --dart-define-from-file=config/google-books.local.json
flutter run -d chrome --dart-define-from-file=config/google-books.local.json
```

Para Auth/Firestore isolados, combine com o modo demo:

```sh
flutter run -d chrome --dart-define=USE_FIREBASE_EMULATORS=true --dart-define-from-file=config/google-books.local.json
```

O define Google Books é independente do Firebase: mesmo no modo demo, uma chave configurada consulta o catálogo externo. Sem chave, o app não envia requisição ao catálogo, informa indisponibilidade e mantém o cadastro manual. CI e builds demo de validação não recebem chave.

Para outro ambiente, mantenha outro arquivo `config/<ambiente>.local.json`, ignorado, e passe-o explicitamente. Não há seleção implícita de chave por ambiente. A configuração padrão Firebase continua sendo a distribuída; alterá-la exige confirmar o destino e usar FlutterFire. Os comandos de emulador estão em [DEVELOPMENT.md](DEVELOPMENT.md).

`--dart-define-from-file` retira o literal do repositório, mas a chave incluída no app pode ser inspecionada no artefato. Não usar esse mecanismo para segredos de servidor. Futuras credenciais confidenciais precisam de armazenamento no backend/gerenciador de segredos e acesso com privilégio mínimo; não há novo fornecedor ou backend aprovado neste trabalho. A documentação do [Google Books](https://developers.google.com/books/docs/v1/using) descreve a identificação de chamadas e a paginação.

## Pendência SEC-03: restrições, quotas e rotação

Para a entrega local de filmes, `USE_MOVIE_LIBRARY` habilita as telas fora do modo demo; distribuição depende das regras/índices de SEC-06. `MOVIE_CATALOG_URL` e `MOVIE_CATALOG_PROVIDER` descrevem somente um intermediário HTTPS normalizado. Sem esses valores, cadastro manual continua disponível. Nunca passar segredo de fornecedor nesses defines; backend e fornecedor continuam pendentes em API-02/04. [Contrato completo de filmes](MOVIES.md#catálogo-configurável).

**A consulta remota não foi executada.** A revisão automática bloqueou a tentativa de consultar metadados de restrições/quotas no Google porque ela enviaria a chave existente para um endpoint externo sem autorização explícita para esse destino. Não foi feita tentativa alternativa para contornar o bloqueio.

Retomar com autorização específica do usuário ou revisão manual por ele no console do projeto correto. Registrar somente: identificação não secreta do recurso/ambiente, APIs permitidas, restrições de aplicativo compatíveis com Android/iOS/web, limites efetivos de quota, alertas e responsável. Conferir configurações reais; não deduzir restrições pelo sucesso de uma chamada nem pela presença de um arquivo local. Referências: [restrições de API Keys](https://docs.cloud.google.com/api-keys/docs/add-restrictions-api-keys) e [quotas Service Usage](https://docs.cloud.google.com/service-usage/docs/overview).

O literal removido ainda existe no histórico Git e em possíveis artefatos antigos. Isso confirma inclusão anterior no código; alcance público e uso indevido não foram verificados. Avaliar restrições, distribuição/exposição e rotação antes de reutilizar a chave em uma release. Nenhuma rotação/revogação ou reescrita de histórico foi feita: uma troca exige plano para clientes já distribuídos e configuração compatível. SEC-03 permanece aberta; API-01 tem implementação local pronta, com essa dependência ainda pendente. Implantação das regras Firebase é outra pendência, SEC-06, já adiada pelo usuário.
