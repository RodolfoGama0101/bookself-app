# Validação de séries — QA-03 — 09/10/2026

Projeto exclusivo `demo-bookself`, dados fictícios, Auth/Firestore emulados.
Nenhuma implantação, migração ou escrita em produção.

## Evidências automatizadas

Análise sem apontamentos; 494 testes Flutter e 99 testes Node/demo aprovados.
Build web demo aprovado. As duas jornadas em
`test/series_journey_test.dart` cobrem cadastro manual e catálogo HTTP simulado,
duas bibliotecas independentes, retry, marcação persistida, Em dia/Concluída,
ocultar/reexibir, sessão com seleção mínima, correção/reconfirmação, retirada
após término e preservação do progresso pessoal. O teste simulado verifica
`/series/search` e `/series/{id}`; não comprova fornecedor real.

Widgets incluem tela de 320 × 640 com texto 2×, cadastro, pausa, desmarcação,
comparação em erro/ocultação/troca de conta e navegação para filmes.
Regras demo validam acesso de terceiros/ex/novo parceiro, concorrência,
calendário, ocultação simultânea à marcação e projeções atômicas.

## Correção encontrada na jornada real

A proposta de sessão tentava ler `users/{partner}`, proibido pelas regras.
O serviço agora lê somente o perfil próprio; reciprocidade e bloqueios são
verificados pelas regras no commit. Para inicializar os dois índices privados
sem sobrescrever timestamps, cada participante pode obter exclusivamente o
marcador mínimo `users/{member}/couple_history/{relationshipId}` da relação
aceita conhecida. Esse marcador contém somente ID da relação e criação.
Listar o histórico inteiro do outro, ler seu perfil ou obter marcador de
relação desconhecida/terceiro continua proibido. A regressão Node executa
essas leituras e a escrita completa de sessão/auditoria/projeção/índices
em uma transação; o teste Flutter impede regressão da leitura do perfil.

Também foram corrigidos o caminho HTTP `series`, textos de séries e o
atalho Séries → Filmes. O consentimento do convite explica a visibilidade
padrão de séries, ocultação individual e separação de sessões/progresso
quando a biblioteca de séries está habilitada.

## Limites

Catálogo real depende de API-02/API-04; Android/iOS não foram executados.
QA-03 permanece aberta para essas evidências e as jornadas completas das
demais categorias. COUPLE-08 ainda não inclui eventos de estado pessoal de
filmes/séries no feed. Regras/índices remotos continuam pendentes de SEC-06.

## Jornada visual com duas contas

Duas sessões Chrome independentes, somente contas fictícias, usando a web demo
com Auth 49099/Firestore 48080 e servidor loopback 17362. Cadastro e convite
consentido foram executados pela interface. Cada conta salvou a mesma série
manual; o episódio 1 ficou visto na primeira e não visto na segunda.
A comparação mostrou esses estados sem títulos/sinopses. Ocultar na primeira
retirou imediatamente o progresso da comparação aberta na segunda; reexibir
restaurou a seleção. Proposta com episódio/data/consentimento chegou à segunda,
que confirmou a versão; Atividades contou Séries: 1 e demais categorias: 0.
Desvincular retirou atividades ao vivo, mantendo o progresso pessoal.

Inspeção visual de comparação em desktop e atividades em 390 px, sem corte
do conteúdo; capturas de ensaio permanecem em `build/` ignorado. Acessibilidade
Flutter foi habilitada por teclado. A faixa de aviso do emulador cobriu uma
ação perto do rodapé; confirmação por foco/Enter funcionou. Isso não valida
leitor de tela nem dispositivo nativo.

O Início de contas vazias exibiu erro de dados não confirmados, sem vazamento,
durante este ensaio; biblioteca de séries e atividades funcionaram. A jornada
do feed inicial de leituras requer investigação separada antes de release.
