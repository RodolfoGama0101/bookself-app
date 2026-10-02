# Produto e expansão

Revisão: 02/10/2026. Planejamento; não representa funcionalidades já disponíveis.

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
| Músicas | Proposta: faixas/álbuns salvos, favoritos e registros de escuta; escopo a decidir. | Descobertas e músicas associadas a momentos do casal. |
| Bíblia | Preservar capítulos lidos e percentuais. | Preservar comparação de progresso e futura visibilidade configurável. |

Estados são propostas. Séries em exibição não ficam definitivamente concluídas por estarem em dia. Música pode ser ouvida repetidas vezes e não precisa de um estado permanente “concluído”.

## Compartilhamento

O vínculo deve usar convite e aceite. Cada pessoa controla autoria e visibilidade; e-mail não deve ser exposto desnecessariamente. Uma ação “assistimos juntos” não deve concluir progresso do parceiro sem uma regra explícita e consentida.

Desvinculação preserva dados pessoais e encerra acesso entre participantes. Retenção/divisão de listas e momentos compartilhados, exclusão de conta e acesso após novo vínculo são decisões anteriores à implementação. Um novo relacionamento não deve herdar acesso ao anterior.

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
| Música | Faixas/álbuns, listas internas antes de sincronização externa. | PROD-01 |
| Compartilhamento | Autoria pessoal, consentimento, visibilidade explícita. | COUPLE-01 |
| Experiência conjunta | Sem concluir automaticamente o progresso alheio. | COUPLE-05 |
| Séries | Separar “em dia”/“concluída” e definir spoilers. | SERIES-01 |
| Bíblia | Preservar progresso; leitor de texto como ideia opcional. | BIBLE-03 |
| APIs | Avaliar TMDB e comparar catálogos musicais. | API-02, API-03 |
