# Visibilidade e revogação — COUPLE-04

Implementado e validado localmente em 05/10/2026 para **livros e progresso bíblico**, as categorias existentes. Regras remotas, migração e distribuição não foram executadas. A [política aprovada](COUPLE_POLICY.md) continua sendo a referência de produto.

## Controles e preservação

Perfil → Compartilhamento permite ocultar cada livro da estante e todos os capítulos de cada livro bíblico. Não depende de ter parceiro: é possível escolher antes do convite. A preferência `isShared: false` fica no registro pessoal; ausência equivale a visível para compatibilidade. Término, bloqueio e novo vínculo não alteram essa preferência, status, datas ou capítulos.

Ocultar um livro bíblico ainda sem progresso cria somente a preferência e uma lista vazia, sem presumir capítulos. Marcação individual/em lote relê o documento e preserva ocultação e campos legados. Salvar um livro relê a preferência atual; um modelo antigo da tela não pode reexpor um item ocultado por outro dispositivo. Escritas são aguardadas; falha mantém o estado confirmado e permite nova tentativa.

## Fronteira de leitura

`books` e `bible_progress` são privados nas regras candidatas. `shared_books/{id}` e `shared_bible_progress/{id}` são projeções mínimas, com o mesmo ID do registro pessoal. Consultas do parceiro, detalhes, feed, estatísticas e comparação usam somente essas projeções e o vínculo recíproco atual. Ocultos não entram em contagens ou denominadores compartilhados. Favoritos, opiniões e campos privados legados não são copiados.

`SharingService` publica a projeção após reler os dados próprios em transação. Streams pessoais solicitam publicação repetível em segundo plano; uma projeção já igual não é regravada. Abrir a versão atual permite que o dono publique seu legado sem modificar o documento original ou consultar dados privados de outra conta. Falha não bloqueia o uso individual; nova assinatura tenta novamente. Contas que ainda não abriram a versão atual podem ter biblioteca compartilhada incompleta até essa publicação; não há preenchimento administrativo em lote.

Salvar livro/capítulos atualiza a projeção na mesma transação. Ocultar remove a projeção atomicamente. Regras impedem ocultação deixando uma cópia consultável, conteúdo forjado, campos extras e escrita alheia. A exclusão pessoal exige remover a projeção. Campos desconhecidos já existentes são conservados e não podem ser adulterados pelo contrato atual.

Essas coleções são uma adaptação incremental, **não o esquema de múltiplas mídias de DATA-01**. Filmes, séries, faixas e álbuns ainda precisam de modelos, projeções/permissões e testes próprios antes de compartilhar.

## Feed sem retroatividade

O Início mantém a biblioteca permitida para estatísticas por período, mas o feed do casal exige `activityAt` do servidor posterior ao `decidedAt` do convite aceito. Publicar legado não inventa atividade. Novo cadastro ou mudança de status gera o marcador; edição de data não gera. Mostrar novamente um item limpa o marcador, impedindo publicar retroativamente atividade que aconteceu enquanto oculto. Relações legadas sem instante de aceite não reconstroem feed conjunto.

O marcador é o estado de atividade recente, não um histórico imutável. `addedAt` e os rótulos antigos permanecem compatíveis; separar datas e eventos completos continua em DATA-06. Esta entrega não promete conservar todas as atividades nem realiza conversão histórica.

## Término, bloqueio e cache

Mudança de pessoa/relação recria os builders e cancela assinaturas; dados antigos não são reutilizados enquanto a nova consulta carrega. Detalhes compartilhados já abertos acompanham a projeção: remoção, erro, cache/offline ou fim do vínculo retiram o conteúdo. A tela bíblica aberta acompanha a sessão e o vínculo atual, limpando a comparação sem interromper escrita pessoal em curso. Nome/foto alheios também deixam de ser exibidos a partir de cache.

Firestore usa memória em todos os ambientes. A inicialização limpa a persistência antiga **antes dos serviços**; falha mantém a recuperação de inicialização, sem liberar dados antigos. Streams compartilhados só apresentam snapshots confirmados pelo servidor; offline limpa o conteúdo consultável. Isso reduz a disponibilidade offline do casal e não implementa um modo individual offline completo. DATA-05 continua responsável pela estratégia geral de sincronização. Limpeza nativa do SDK não foi executada em Android/iOS nesta entrega.

Bloquear o parceiro ativo grava `partner_blocks/{uid}/targets/{otherUid}`, encerra reciprocamente a relação e incrementa a versão do bloqueador na mesma transação. Bloqueios são privados e impedem descoberta/reserva/aceite entre as duas contas nos dois sentidos. Somente o dono remove seu bloqueio. Desbloquear não restaura vínculo, código consumido ou acesso; novo convite/aceite é necessário. O controle atual parte do parceiro ativo; bloquear após recusa/término e gerir bloqueios independentes fora do vínculo fica em COUPLE-09.

Dados já copiados, capturados ou entregues fora do estado controlado pelo app não podem ser recolhidos. Cache de imagens do navegador/SO e capturas do destinatário não são apagados por regras Firestore. Listas e experiências ainda não existem; histórico conjunto, retenção e exclusão seguem COUPLE-05/06 e SEC-05.

## Evidências e implantação

Formatação, análise limpa, **321 testes Flutter**, **53 testes Auth/Firestore demo** e build web demo com verificação preliminar Wasm. Regressões novas cobrem confirmação/falha, legado sem campos privados na projeção, preferência preservada por edição antiga, capítulos/lotes, offline, detalhes abertos, feed versus estatísticas e controles em 320 × 480 com texto 2×. Servidor emulado cobre terceiros, projeções forjadas, ocultação concorrente, ex/novo parceiro, bloqueio e término concorrentes e novo livro transacional.

Dois Chromes isolados com contas fictícias validaram ocultação de livro retirando detalhes já abertos, ocultação bíblica sem comparação após recarga, bloqueio com término recíproco e desbloqueio sem restaurar vínculo. Capítulos próprios permaneceram. Emuladores/navegadores foram encerrados, credenciais de fixture removidas e capturas mantidas em diretório ignorado. Comandos em [DEVELOPMENT.md](DEVELOPMENT.md); jornada em [WEB_VALIDATION.md](WEB_VALIDATION.md).

As regras mais estritas exigem cliente compatível: clientes antigos consultam documentos pessoais do parceiro e podem editar sem a projeção atômica. Planejar atualização, disponibilidade das projeções, backup e recuperação em [SEC-06](SECURITY.md#implantação-pendente). Esta entrega não confirma proteção em produção.
