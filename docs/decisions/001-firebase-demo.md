# 001 — Instância Firebase separada para emuladores

Data: 03/10/2026. Estado: implementado localmente em SEC-02.

## Contexto e alternativas

Os testes de autorização precisam executar escritas sem alcançar dados reais. Reaproveitar o Firebase padrão trocando somente hosts poderia reutilizar a instância criada pela configuração nativa Android/iOS. Trocar a configuração gerada ou os IDs distribuídos também afetaria clientes existentes. Manter testes apenas com fakes não verifica regras no servidor.

## Escolha e motivos

`FirebaseEnvironment` seleciona uma instância nomeada `demo-bookself`, com opções fictícias e Auth/Firestore locais, mediante opt-in explícito. Todos os serviços usam essa mesma instância. Hosts/portas são validados antes dos providers, cache persistente fica desabilitado no demo e uma falha não faz fallback para produção. `firebase.emulators.json` é separado de `firebase.json`.

Essa escolha permite manter os identificadores/configuração distribuídos e validar autorização em emuladores. Firebase permanece o fornecedor atual; não houve seleção de outro serviço.

## Efeitos e pendências

Trocar o modo exige reinício completo. Emuladores usam contas fictícias e sessões descartáveis. Catálogo Google Books/capas continuam externos; cadastro manual atende testes sem catálogo. A busca externa não virou um serviço demo. Jornada Flutter em dispositivo e migração/privacidade continuam pendentes.

Evidências: quatro testes de `test/firebase_environment_test.dart`, 24 testes de Auth/Firestore e builds web demo/Android debug demo. Comandos e limites: [DEVELOPMENT.md](../DEVELOPMENT.md). Implantação das regras: [SECURITY.md](../SECURITY.md), separada destes testes.
