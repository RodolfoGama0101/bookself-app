# 011 — Proposta de modelo de múltiplas mídias v1

## Estado

Proposta consolidada e validada documentalmente em **08/10/2026** para DATA-01, a pedido do usuário para executar a próxima tarefa. [Especificação](../DATA_MODEL.md) e [exemplos fictícios](../data-model/v1.examples.json). Não representa aprovação específica do esquema pelo usuário, implementação de DATA-02 ou contrato ativo no Firestore.

## Alternativas e escolha proposta

- Documento único com catálogo, progresso, preferências e experiências: descartado como base da expansão, porque não separa autoria nem campos pessoais dos consultáveis.
- Catálogo global com cadastro manual público: não adotado. A proposta usa snapshots privados por dono, preservando identidade externa comum sem criar diretório de itens manuais ou cache de fornecedor não aprovado.
- ID externo como ID pessoal: não adotado. Referência é a tupla de mídia/fornecedor/ID, ou mídia/dono/ID manual, com codificação reversível; entradas pessoais mantêm IDs opacos próprios. Um slot por dono/referência trata repetição e concorrência.
- Um status universal para toda mídia: não adotado. Estados internos específicos não dependem dos rótulos em português; música separa favorito/escutas e séries separam progresso por episódio.
- Confirmação conjunta como atualização de duas bibliotecas: não adotada. Experiência tem revisão e resposta de cada participante; somente duas confirmações atuais permitem contagem conjunta.

## Consequências

`schemaVersion: 1` identifica a proposta. Metadados, entrada pessoal, episódios, escutas, relação, listas, experiências e eventos têm responsabilidades próprias. Projeções permitidas excluem favoritos/opiniões/escutas pessoais; autorização depende da relação atual/visibilidade, enquanto o histórico intencional de listas/experiências segue a política dos participantes antigos. Nenhum novo compartilhamento é presumido por consultar um catálogo.

Datas pessoais são civis, separadas dos instantes do servidor. Retry conserva IDs da intenção; eventos não substituem `createdAt`, e duas confirmações não duplicam uma experiência. Casos de metadados desconhecidos, legado sem data, colisões entre tipos/fornecedores, duas contas e correção/retirada de confirmação estão explicitados na especificação e exemplos.

## Validação e implementação posterior

JSON parseado e invariantes cruzados localmente com Node, somente leitura e sem rede/banco: versão, referências, estados por mídia, identidade reversível/isolada, slots por dono, campos privados ausentes da projeção, três escutas intencionais e três estados de experiência. Links e diff conferidos; revisão contra MVP, política e modelos atuais. Não houve execução Flutter/emuladores nesta tarefa documental.

DATA-02 implementará modelos/repositórios incrementais e suas regressões. DATA-03 mantém migração, backup, conflitos legados, ensaio de clientes antigos e rollback separados; nenhum `books`, `bible_progress` ou vínculo é substituído agora. DATA-04/05/06, COUPLE-05/06 e SERIES-01 continuam responsáveis pelos critérios específicos de consultas, sincronização, eventos, experiências/listas e regras de séries. Fornecedores, marca, retenção e implantação permanecem decisões distintas; SEC-06 continua pendente.
