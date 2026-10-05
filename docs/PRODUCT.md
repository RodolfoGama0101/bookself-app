# Produto e expansão

Revisão: 05/10/2026. Planejamento; não representa funcionalidades já disponíveis.

## Direção solicitada

Expandir para **livros, filmes, séries e músicas**, com integração entre casais em todas as categorias. Preservar contas e acompanhamento bíblico. O centro da experiência passa a ser o repertório pessoal e as descobertas compartilhadas.

## Experiência proposta

Cada pessoa mantém registros, progresso e opiniões próprios. Com vínculo aceito por ambas, pode consultar o que foi compartilhado, escolher o próximo item e registrar experiências conjuntas. O app continua útil antes do vínculo e após desvinculação.

A proposta inicial é organizar catálogos e experiências. Reprodução de áudio/vídeo no app, sessões sincronizadas e importação automática de históricos são ideias posteriores, sujeitas a validação. Links externos podem atender à descoberta sem depender desses recursos.

| Categoria | Experiência individual proposta | Experiência em casal proposta |
| --- | --- | --- |
| Livros | Preservar estados de leitura e data de conclusão. | Consultar estante compartilhada e escolher leituras em comum. |
| Filmes | Busca/cadastro, “Quero assistir”/“Assistido”, data e avaliação opcional. | Lista para assistir juntos e sessão compartilhada com avaliações individuais. |
| Séries | Temporadas/episódios; distinguir em andamento, em dia, concluída e pausada. | Comparar progresso, evitar spoilers, registrar episódios juntos. |
| Músicas | Escopo escolhido: faixas e álbuns salvos, favoritos e registros de escuta. | Listas internas do casal; detalhes de momentos conjuntos ainda dependem de COUPLE-05. |
| Bíblia | Preservar capítulos lidos e percentuais. | Preservar comparação de progresso e futura visibilidade configurável. |

Estados são propostas. Séries em exibição não ficam definitivamente concluídas por estarem em dia. Música pode ser ouvida repetidas vezes e não precisa de um estado permanente “concluído”.

## Escopo musical escolhido — PROD-01

Em 05/10/2026, o usuário escolheu **faixas e álbuns salvos, favoritos e escutas, com listas do casal** para a primeira versão. A alternativa de começar apenas com faixas foi descartada para esse escopo. A escolha não define fornecedor nem autoriza reprodução interna, sincronização de playlists externas ou importação de histórico.

A proposta executável abaixo detalha essa escolha para revisão antes dos modelos de DATA-01. Campos e estados ainda são propostas; somente o escopo acima foi escolhido.

| Recurso | Proposta para o MVP | Critério de sucesso proposto |
| --- | --- | --- |
| Faixa | Título e artista obrigatórios; álbum, versão, duração e capa opcionais. Referência externa quando disponível; cadastro manual independente do catálogo. | Salvar e consultar uma faixa sem capa ou API; distinguir versões sem misturar registros pessoais. |
| Álbum | Título e artista obrigatórios; ano, tipo de edição, capa e faixas opcionais. | Salvar um álbum mesmo com lista de faixas incompleta; não presumir que salvar/ouvir o álbum salva ou conclui cada faixa. |
| Biblioteca e favoritos | Entrada pessoal por obra; favorito como preferência independente; sem estado permanente de conclusão. | Salvar novamente a mesma referência não criar uma segunda entrada involuntária; pessoas distintas manterem preferências próprias. Política de versões/manuais depende de DATA-01. |
| Escuta | Registro pessoal separado da obra, com data informada; repetições permitidas. | Duas escutas intencionais permanecerem distintas; repetição de envio não duplicar a mesma operação. Não inferir escuta ao favoritar/salvar. |
| Listas do casal | Seleções internas de faixas/álbuns com autoria, dependentes de vínculo e permissões. | Ambos adicionarem/retirarem itens com concorrência tratada; lista não depender de conta em serviço musical. |

Ficam para depois: reprodução, letras, sincronização externa, playlists de fornecedor, recomendações automáticas e estatísticas avançadas. Registro de experiência conjunta depende de COUPLE-05; não altera escuta/favorito do parceiro automaticamente. API-03 deve comparar os fornecedores para faixas **e** álbuns, incluindo versões, imagens e acesso, antes de escolher um.

PROD-01 permanece em andamento: confirmar estados/campos e critérios das demais categorias, além dos detalhes musicais propostos. Filmes, séries e música continuam ausentes do aplicativo atual.

## Compartilhamento

O vínculo deve usar convite e aceite. Cada pessoa controla autoria e visibilidade; e-mail não deve ser exposto desnecessariamente. Uma ação “assistimos juntos” não deve concluir progresso do parceiro sem uma regra explícita e consentida.

Em 05/10/2026, o usuário escolheu **compartilhar biblioteca e progresso por padrão após aceite, permitindo ocultar itens**. O padrão privado com compartilhamento item a item foi a alternativa considerada. A decisão vale para a evolução consentida; COUPLE-03 substituiu novos vínculos por convites consentidos no código/regras locais; controles de ocultação permanecem pendentes em COUPLE-04. Ocultar um item deverá ser um controle de autorização no servidor, abrangendo consultas, detalhes, feed e estatísticas do parceiro.

Em 05/10/2026, o usuário adotou a [política v1 de consentimento e visibilidade](COUPLE_POLICY.md), concluindo COUPLE-01 como decisão. Convites valem sete dias, com um enviado ativo por conta e aceite único; identidade mínima usa nome/foto. Biblioteca existente entra no compartilhamento preservando itens ocultos, sem atividades retroativas no feed. Bíblia tem ocultação por livro; favoritos, opiniões e escutas pessoais ficam privados. Bloquear encerra o vínculo e impede novos convites até desbloqueio; desbloquear exige novo aceite. Separar o e-mail e demais campos privados em SEC-04 não pode depender apenas de escondê-los na interface.

Desvinculação preserva dados pessoais e encerra acesso à biblioteca/progresso do ex-parceiro. Listas e experiências conjuntas ficam em histórico restrito aos participantes antigos, sem edição conjunta e sem herança por novo vínculo. Experiências exigem confirmação dos dois e não alteram progresso pessoal automaticamente. Prazo de retenção, exportação e exclusão de conta continuam em SEC-05; detalhes técnicos de experiências/listas ficam em COUPLE-05/06. A política aprovada está parcialmente implementada: convites consentidos estão validados localmente em COUPLE-03; bloqueio, ocultação, feed sem retroatividade e cache permanecem em COUPLE-04/DATA-05. Implantação e distribuição continuam pendentes.

## Navegação proposta

Avaliar **Início, Biblioteca, Nós e Perfil**, com categorias na Biblioteca e Bíblia acessível em seção própria. Validar mapa e rótulos em tela pequena. Início mostra atividades e estatísticas por categoria; não soma capítulos, episódios e músicas como uma mesma medida. Nós concentra vínculo, listas e escolhas em comum.

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
| Música | Escopo de faixas/álbuns, favoritos, escutas e listas escolhido em 05/10/2026; detalhes do MVP em revisão. | PROD-01 |
| Compartilhamento | Política v1 aprovada em 05/10/2026; perfil privado separado localmente em SEC-04, convites locais em COUPLE-03; implantação remota e visibilidade pendentes. | SEC-06, COUPLE-03/04 |
| Experiência conjunta | Sem concluir automaticamente o progresso alheio. | COUPLE-05 |
| Séries | Separar “em dia”/“concluída” e definir spoilers. | SERIES-01 |
| Bíblia | Preservar progresso; leitor de texto como ideia opcional. | BIBLE-03 |
| APIs | Avaliar TMDB e comparar catálogos musicais. | API-02, API-03 |
