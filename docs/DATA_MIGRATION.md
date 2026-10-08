# Preparação e ensaio recuperável — DATA-03

Implementado localmente em **08/10/2026**. O comando de ensaio é offline: não importa SDK Firebase, não aceita projeto/host, não lê credenciais e não escreve no banco. Preparar uma migração não autoriza executá-la em produção ou implantar regras. Os originais continuam sendo o contrato usado pelas telas atuais.

## Backup e formato

`tool/firebase/migration.cjs` recebe um snapshot JSON com caminhos completos como chaves e conteúdo integral como valores. `backup` cria uma cópia com `formatVersion: 1` e SHA-256 canônico dos documentos; `verifyBackup` recusa corrupção/versão desconhecida. Não omitir coleções privadas, convites, projeções, contatos, bloqueios ou campos desconhecidos de um inventário real. A fixture pública contém somente exemplos fictícios, não um inventário de produção.

JSON não representa nativamente todos os tipos Firestore. O ensaio de emuladores representa timestamps por `{"$timestamp":[segundos,nanos]}`, conservando ambos os componentes; não converte datas para outro fuso. Snapshots reais exigirão exportador/restaurador tipado para timestamps, referências, bytes, geopontos e valores numéricos especiais, além de inventário de subcoleções e contas Auth. Esses componentes não são fornecidos pelo comando offline. Valores JavaScript não representáveis em JSON são recusados; não encaminhar diretamente objetos SDK ou datas JavaScript.

Execute a fixture sem rede:

```sh
node tool/firebase/migration.cjs docs/data-model/migration.fixture.json
node --test tool/firebase/test/migration.test.cjs
```

Para conservar backup/plano de um snapshot **local de desenvolvimento**:

```sh
node tool/firebase/migration.cjs config/snapshot.local.json --archive config/migration-backup.local.json
```

O arquivo de saída precisa terminar em `.local.json`, é criado com exclusividade e nunca substitui um backup. `config/*.local.json` é ignorado pelo Git. Restrinja o acesso ao arquivo e mantenha outra cópia íntegra em armazenamento controlado; permissão Unix solicitada na criação não define uma ACL Windows. O terminal imprime somente contagens e resultado do ensaio, sem IDs, nomes, datas ou conteúdo.

## Plano v1 e compatibilidade

`plan` prepara um documento por livro em `migration_imports/{hashDoCaminho}`. ID/dono, identidade Google Books ou manual e conteúdo original inteiro são conservados. A área de preparação **não é `libraries` nem uma entrada ativa v1**. `createdAt` permanece desconhecido (`null`), pois `addedAt` legado não comprova criação original. Datas ausentes/futuras e campos desconhecidos são guardados sem correção automática; não inventar conclusão, inclusão ou atividade.

Duplicatas de referência, dono ausente, UID divergente do caminho e relações não recíprocas entram em `conflicts`; nenhuma duplicata é fundida e nenhum vínculo é reparado. Um relatório com conflitos pode ser ensaiado para comprovar preservação, mas não libera ativação. O plano registra contagens de documentos, livros, usuários, progresso bíblico e pares recíprocos. Convites, versões e dados do parceiro continuam nos originais; copiar o vínculo antigo não transforma sua origem em aceite novo.

Clientes antigos continuam encontrando `users`, `books` e `bible_progress` intactos. Os clientes atuais continuam usando esses documentos. Ambos são negados na área de preparação pelas regras candidatas; parceiro/terceiro/sem autenticação também são negados. Isso foi verificado nos emuladores e não comprova as regras remotas, cuja implantação continua em SEC-06.

## Aplicação e recuperação ensaiadas

`apply(backup, plan, current)` opera sobre mapas locais e devolve uma nova cópia. Antes de preparar resultados, confere backup/plano e os hashes das origens. Alteração em uma origem exige novo inventário; destino diferente recusa sobrescrita. Repetir o mesmo plano sobre o mesmo resultado é idempotente. Documentos novos fora do snapshot são preservados, mas não importados: um corte real exige novo snapshot consistente e tratamento de escritas concorrentes.

`rollback(backup, plan, current)` verifica **todos** os destinos antes de remover somente os imports reconhecidos. Se algum destino foi alterado, recusa a operação inteira para revisão. Não restaura indiscriminadamente perfis/livros: desvínculo, livro novo e outros dados criados depois do ensaio sobrevivem. Os originais não precisam ser regravados, pois não foram modificados. `rehearse` confirma repetição e recuperação exata por hash.

O teste de emuladores captura documentos fictícios, grava a preparação com contexto administrativo restrito ao ambiente de teste, verifica legado/UID/vínculos/Bíblia e negação a clientes, e remove os imports. O uso de `withSecurityRulesDisabled` é exclusivo do harness local; não há cliente administrativo distribuído ou importador remoto.

## Etapa posterior de ativação

Antes de mudar a leitura das telas ou executar qualquer migração remota: inventário tipado de todos os dados e Auth, backup externo/restauração testada, resolução explícita de conflitos, contrato de origem/data desconhecida, estratégia para escritas durante o corte, compatibilidade de clientes distribuídos, autorização e índices implantados, ensaio com o cliente novo e rollback da ativação. Não remover o legado durante essa transição. O comando desta entrega não efetua nenhuma dessas operações remotas.

DATA-03 encerra a preparação/estratégia repetível ensaiada. A conversão para entradas ativas, eventos históricos e adoção pela interface permanecem nas entregas correspondentes; DATA-06 não pode tratar `addedAt` legado como criação comprovada. [Modelo](DATA_MODEL.md), [autorização](SECURITY.md) e [evidências](DEVELOPMENT.md#preparação-paginação-e-sincronização--data-030405).
