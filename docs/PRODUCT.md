# Produto e expansão

Revisão: 08/10/2026. **PROD-01 concluída como decisão de MVP aprovada pelo usuário; PROD-02 definida e DATA-01 consolidada como especificação proposta v1.** O escopo abaixo orienta a expansão; filmes e música têm entregas locais incrementais; séries continuam pendentes.

## Direção solicitada

**Entrega local de COUPLE-05/06 em 08/10/2026:** listas internas e experiências consentidas por revisão já aceitam seleções manuais das cinco mídias, com histórico restrito após término. Não substituem as bibliotecas/progresso pessoal de filmes, séries ou músicas ainda planejados. [Comportamento implementado](COUPLE_WORKSPACE.md).

Expandir para **livros, filmes, séries e músicas**, com integração entre casais em todas as categorias. Preservar contas e acompanhamento bíblico. O centro da experiência passa a ser o repertório pessoal e as descobertas compartilhadas.

## Experiência proposta

Cada pessoa mantém registros, progresso e opiniões próprios. Com vínculo aceito por ambas, pode consultar o que foi compartilhado, escolher o próximo item e registrar experiências conjuntas. O app continua útil antes do vínculo e após desvinculação.

A proposta inicial é organizar catálogos e experiências. Reprodução de áudio/vídeo no app, sessões sincronizadas e importação automática de históricos são ideias posteriores, sujeitas a validação. Links externos podem atender à descoberta sem depender desses recursos.

| Categoria | Experiência individual proposta | Experiência em casal proposta |
| --- | --- | --- |
| Livros | Preservar estados de leitura e data de conclusão. | Consultar estante compartilhada e escolher leituras em comum. |
| Filmes | Busca/cadastro, “Quero assistir”/“Assistido” e data da sessão. | Lista para assistir juntos e sessão compartilhada confirmada pelos dois. |
| Séries | Temporadas/episódios; distinguir em andamento, em dia, concluída e pausada. | Comparar progresso, evitar spoilers, registrar episódios juntos. |
| Músicas | Escopo escolhido: faixas e álbuns salvos, favoritos e registros de escuta. | Listas internas do casal; detalhes de momentos conjuntos ainda dependem de COUPLE-05. |
| Bíblia | Preservar capítulos lidos e percentuais. | Comparação somente do progresso permitido; ocultação local por livro bíblico entregue em COUPLE-04. |

Os estados gerais do MVP foram aprovados. Séries em exibição não ficam definitivamente concluídas por estarem em dia; regras detalhadas ainda dependem de SERIES-01. Música pode ser ouvida repetidas vezes e não recebe estado permanente “concluído”.

## MVP aprovado — PROD-01

Em 05/10/2026, após escolher o escopo musical, o usuário respondeu **“Aprovar esse MVP (recomendado)”** à proposta completa das categorias. A aprovação abrange preservação de livros/Bíblia, filmes, séries com progresso individual, faixas/álbuns, cadastro manual, listas do casal e experiências confirmadas pelos dois, sem reprodução interna, importação externa ou avaliações nesta primeira versão.

| Categoria | Campos e estados do MVP | Critério de sucesso |
| --- | --- | --- |
| Livros | Preservar o contrato e os registros atuais: título/autores, capa e referência quando houver, “Quero Ler”, “Lendo”, “Lido” e conclusão opcional. | Contas, IDs, datas e biblioteca existentes permanecem; registros sem data continuam utilizáveis; edição é pessoal e ocultação é respeitada. |
| Bíblia | Manter os 66 livros, identificação e capítulos lidos por livro; sem texto/versículos ou nova tradução. | Os 1.189 capítulos continuam acompanháveis; marcar/desmarcar preserva os demais, com e sem parceiro; comparação usa só livros permitidos. |
| Filmes | Título obrigatório; ano, capa, referência externa e data da sessão quando informada são opcionais. Estados “Quero assistir” e “Assistido”. | Buscar ou cadastrar manualmente, salvar sem capa/API e atualizar estado/data próprios; ausência de data não inventa sessão nem afeta livros. |
| Séries | Título obrigatório; temporadas/episódios e referências quando conhecidos, capa/ano opcionais. Progresso pessoal por episódio; estados gerais “Em andamento”, “Em dia”, “Concluída”, “Pausada”. | Salvar com metadados incompletos sem presumir episódios vistos; marcar/desmarcar episódios conhecidos persiste progresso próprio; estar em dia não conclui uma série em exibição. |
| Faixas | Título/artista obrigatórios; álbum, versão, duração, capa e referência externa opcionais. Obra salva e favorito independente, sem conclusão permanente. | Cadastro manual funciona sem API/capa; versões e registros de pessoas distintas não se misturam; salvar/favoritar não presume escuta. |
| Álbuns | Título/artista obrigatórios; ano, edição, capa, referência e lista de faixas opcionais. Favorito independente, sem conclusão permanente. | Salvar com lista incompleta; salvar/ouvir um álbum não salva ou conclui suas faixas automaticamente. |
| Escutas | Registro pessoal separado da obra com data informada; repetições intencionais permitidas. | Duas escutas intencionais permanecem distintas; repetir envio da mesma operação não duplica; escutas e favoritos não são expostos pelo compartilhamento da obra. |

Os campos opcionais não impedem cadastro manual nas novas mídias. Busca depende de fornecedor aprovado, mas salvar/consultar uma entrada própria não exige conta externa. IDs, versões, ausência/nulidade e estados internos foram consolidados como [proposta v1 em DATA-01](DATA_MODEL.md), com implementação pendente em DATA-02; os rótulos desta decisão não são um contrato de persistência ativo.

| Experiência do casal | Escopo aprovado | Critério de sucesso |
| --- | --- | --- |
| Consulta e escolha | Biblioteca/progresso permitidos por categoria e seleção do próximo item. | Ocultos ficam fora de detalhes, comparação, feed e contagens; término preserva dados próprios e revoga acesso pessoal do ex. Cada nova categoria precisa de seus testes de autorização. |
| Listas internas | Listas do casal para livros, filmes, séries, faixas e álbuns, com origem/autoria. | Ambos adicionam/retiram seleções com concorrência tratada; não dependem de playlist/conta de fornecedor. Listas pessoais ficam fora desta primeira entrega. |
| Experiência conjunta | Participantes, data e confirmação explícita dos dois, conforme COUPLE-01. | Proposta não presume participação; confirmação conjunta não sobrescreve progresso, favorito, opinião ou escuta alheios. Modelo/fluxo em COUPLE-05; histórico do término em COUPLE-05/06. |

Ficam para depois: avaliações/comentários novos, reprodução interna, letras, sessões sincronizadas, importação de histórico e playlists externas, recomendações automáticas, leitor de texto bíblico e estatísticas avançadas. Não remover campos pessoais legados por estarem fora do MVP.

Continuam decisões pendentes: marca (NAME-01), fornecedores e condições de acesso (API-02/03) e regras detalhadas de especiais, episódios futuros, reassistir e spoilers (SERIES-01). A navegação foi definida separadamente em PROD-02, conforme [mapa v1](NAVIGATION.md); o esquema foi consolidado como [proposta v1 em DATA-01](DATA_MODEL.md), ainda sem código, contrato ativo ou aprovação específica pelo usuário. A aprovação do MVP não escolhe silenciosamente as alternativas pendentes nem autoriza migração, implantação ou publicação.

## Escopo musical escolhido — PROD-01

Em 05/10/2026, o usuário escolheu **faixas e álbuns salvos, favoritos e escutas, com listas do casal** para a primeira versão. A alternativa de começar apenas com faixas foi descartada para esse escopo. A escolha não define fornecedor nem autoriza reprodução interna, sincronização de playlists externas ou importação de histórico.

A tabela abaixo detalha a escolha, posteriormente aprovada junto do MVP completo. Serve como critério de produto para DATA-01; não define fornecedor ou esquema técnico.

| Recurso | MVP aprovado | Critério de sucesso |
| --- | --- | --- |
| Faixa | Título e artista obrigatórios; álbum, versão, duração e capa opcionais. Referência externa quando disponível; cadastro manual independente do catálogo. | Salvar e consultar uma faixa sem capa ou API; distinguir versões sem misturar registros pessoais. |
| Álbum | Título e artista obrigatórios; ano, tipo de edição, capa e faixas opcionais. | Salvar um álbum mesmo com lista de faixas incompleta; não presumir que salvar/ouvir o álbum salva ou conclui cada faixa. |
| Biblioteca e favoritos | Entrada pessoal por obra; favorito como preferência independente; sem estado permanente de conclusão. | Salvar novamente a mesma referência não criar uma segunda entrada involuntária; pessoas distintas manterem preferências próprias. Política de versões/manuais depende de DATA-01. |
| Escuta | Registro pessoal separado da obra, com data informada; repetições permitidas. | Duas escutas intencionais permanecerem distintas; repetição de envio não duplicar a mesma operação. Não inferir escuta ao favoritar/salvar. |
| Listas do casal | Seleções internas de faixas/álbuns com autoria, dependentes de vínculo e permissões. | Ambos adicionarem/retirarem itens com concorrência tratada; lista não depender de conta em serviço musical. |

Ficam para depois: reprodução, letras, sincronização externa, playlists de fornecedor, recomendações automáticas e estatísticas avançadas. Registro de experiência conjunta depende de COUPLE-05; não altera escuta/favorito do parceiro automaticamente. API-03 deve comparar os fornecedores para faixas **e** álbuns, incluindo versões, imagens e acesso, antes de escolher um.

PROD-01 está concluída como decisão: escopo, estados gerais, campos obrigatórios/opcionais, critérios e adiamentos foram aprovados e registrados acima. Filmes e música têm implementações incrementais condicionadas ao ambiente, descritas em [MOVIES.md](MOVIES.md) e [MUSIC.md](MUSIC.md); séries continuam pendentes; conclusão da decisão libera suas dependências, sem concluir implementação.

## Compartilhamento

O vínculo deve usar convite e aceite. Cada pessoa controla autoria e visibilidade; e-mail não deve ser exposto desnecessariamente. Uma ação “assistimos juntos” não deve concluir progresso do parceiro sem uma regra explícita e consentida.

Em 05/10/2026, o usuário escolheu **compartilhar biblioteca e progresso por padrão após aceite, permitindo ocultar itens**. O padrão privado com compartilhamento item a item foi a alternativa considerada. A decisão vale para a evolução consentida; COUPLE-03 substituiu novos vínculos por convites consentidos no código/regras locais; COUPLE-04 acrescentou controles de ocultação locais para livros e Bíblia. Ocultar um item deverá ser um controle de autorização no servidor, abrangendo consultas, detalhes, feed e estatísticas do parceiro.

Em 05/10/2026, o usuário adotou a [política v1 de consentimento e visibilidade](COUPLE_POLICY.md), concluindo COUPLE-01 como decisão. Convites valem sete dias, com um enviado ativo por conta e aceite único; identidade mínima usa nome/foto. Biblioteca existente entra no compartilhamento preservando itens ocultos, sem atividades retroativas no feed. Bíblia tem ocultação por livro; favoritos, opiniões e escutas pessoais ficam privados. Bloquear encerra o vínculo e impede novos convites até desbloqueio; desbloquear exige novo aceite. Separar o e-mail e demais campos privados em SEC-04 não pode depender apenas de escondê-los na interface.

Desvinculação preserva dados pessoais e encerra acesso à biblioteca/progresso do ex-parceiro. Listas e experiências conjuntas ficam em histórico restrito aos participantes antigos, sem edição conjunta e sem herança por novo vínculo. Experiências exigem confirmação dos dois e não alteram progresso pessoal automaticamente. Prazo de retenção, exportação e exclusão de conta continuam em SEC-05; detalhes técnicos de experiências/listas ficam em COUPLE-05/06. A política aprovada está parcialmente implementada: convites consentidos estão validados localmente em COUPLE-03; ocultação, feed sem retroatividade e revogação de livros/Bíblia foram validados localmente em COUPLE-04, incluindo bloqueio do parceiro ativo. COUPLE-09 implementou localmente o bloqueio fora do vínculo em 08/10/2026, com identificação mínima privada por interação autorizada ([registro 010](decisions/010-bloqueios-independentes.md)). Novas mídias e sincronização geral em DATA-05 ainda estão pendentes. Implantação e distribuição continuam pendentes.

## Navegação proposta

**PROD-02 definida e revisada documentalmente em 08/10/2026:** quatro destinos **Início, Biblioteca, Nós e Perfil**, com filtros das mídias implementadas na Biblioteca. Bíblia conserva uma jornada própria, acessível por “Acompanhar Bíblia” na Biblioteca e no Início. Nós concentra consulta do parceiro, convites, gestão do vínculo e bloqueios; listas/experiências entram quando funcionais. Início mostra atividades e estatísticas por categoria, sem somar capítulos, episódios e músicas como uma mesma medida.

O [mapa v1 e os fluxos](NAVIGATION.md) detalham inclusão manual/catálogo, estados por mídia, conta sem parceiro, falha/revogação de dados compartilhados, contexto de retorno, telas pequenas/texto ampliado e entrega incremental. UI-01/02 e BIBLE-01 implementaram em 08/10/2026 a base Início/Biblioteca/Nós/Perfil para livros/Bíblia e relação atual; categorias futuras permanecem nos próprios itens. Protótipos/uso real e revisão completa de acessibilidade ficam em PROD-03/UI-03. Não atribuir aprovação específica do desenho ao usuário nem considerar as categorias futuras já implementadas.

## Nome

Bookself remete a livros e fica estreito para a expansão. Sugestão inicial: **Entrelace**, com **“Histórias e descobertas a dois.”** Representa conexão entre pessoas e experiências sem limitar o formato.

| Candidato | Ideia | Ponto a avaliar |
| --- | --- | --- |
| **Entrelace** | Repertórios e experiências conectados. | Frase de apoio ajuda a explicar o produto. |
| Nosso Repertório | Coleção cultural em conjunto. | Descritivo, mas longo para marca/ícone. |
| A Dois | Experiência do casal. | Expressão genérica, descoberta em buscas a avaliar. |
| Sintonia | Afinidade de gostos. | Pode sugerir foco exclusivamente musical. |

São propostas criativas. Disponibilidade de marca, domínio, lojas e identificadores sociais não foi verificada. Escolha e verificações constam no backlog. Não foi aplicada mudança de nome ao app.

Aplicação da marca deve abranger interface, ícone, títulos web, manifestos e nomes exibidos Android/iOS. Preservar inicialmente IDs técnicos e Firebase; alterá-los exige motivo e plano específicos.

## Sequência proposta

| Etapa | Resultado | Condição para avançar |
| --- | --- | --- |
| 0. Confiabilidade | Inicialização, dados, erros e testes. | Validar o fluxo atual e corrigir regressões. |
| 1. Vínculo e acesso | Convites, aceite, desvínculo e regras. | Garantir isolamento entre contas/relações. |
| 2. Base e marca | Modelo de mídia, migração, nome e navegação. | Ensaiar preservação de dados; confirmar nome antes de aplicá-lo. |
| 3. Filmes | Primeira categoria nova individual/em casal. | Validar busca, registros e experiência compartilhada. |
| 4. Séries | Progresso por episódio e comparação. | Validar séries em andamento e proteção contra spoilers. |
| 5. Músicas | Catálogo e descobertas do casal. | Confirmar escopo e fornecedor viável. |
| 6. Evolução opcional | Memórias, metas e integrações adicionais. | Priorizar após uso das categorias básicas. |

Etapas indicam dependências, não prazos. Tarefas executáveis estão em [BACKLOG.md](../BACKLOG.md).

## Decisões pendentes

| Tema | Proposta inicial | Tarefa |
| --- | --- | --- |
| Marca | Entrelace, a confirmar. | NAME-01 |
| Música | MVP de faixas/álbuns, favoritos, escutas e listas aprovado; fornecedor e implementação pendentes. | API-03, MUSIC-01/02/03 |
| Compartilhamento | Política v1 aprovada em 05/10/2026; perfil privado separado localmente em SEC-04, convites locais em COUPLE-03; visibilidade local de livros/Bíblia em COUPLE-04 e bloqueios independentes locais em COUPLE-09; implantação pendente. | SEC-06 |
| Experiência conjunta | Sem concluir automaticamente o progresso alheio. | COUPLE-05 |
| Séries | Separar “em dia”/“concluída” e definir spoilers. | SERIES-01 |
| Bíblia | Preservar progresso; leitor de texto como ideia opcional. | BIBLE-03 |
| APIs | Avaliar TMDB e comparar catálogos musicais. | API-02, API-03 |
