# Cópia pessoal, exclusão e retenção

Revisão de 09/10/2026 — SEC-05 em andamento. Este documento descreve o código
local e separa as decisões ainda pendentes. Não é uma declaração de conformidade
legal nem autorização para excluir dados ou alterar produção.

## Cópia pessoal implementada

Perfil → Cópia dos meus dados gera JSON somente após leituras confirmadas do
servidor. Inclui o próprio perfil (UID, nome, e-mail, foto e criação), livros,
progresso bíblico, catálogo e entradas privadas multimídia existentes. Campos de
vínculo/códigos de convite do perfil não são incluídos. Não consulta biblioteca
alheia, projeções compartilhadas, convites, bloqueios, contatos, atividade dos
livros, listas, experiências ou índices internos. Categorias futuras não passam
a existir por causa desse exportador. Nenhuma senha/token de autenticação é lida.

A cópia é **parcial e não restaurável automaticamente**. A interface explica o
escopo antes da ação. Não há escrita no banco, exclusão, envio a terceiros ou
registro do conteúdo em logs. A pessoa escolhe copiar o JSON e salvá-lo em local
privado; a área de transferência pode ser acessada por outros aplicativos e deve
ser limpa depois. O app não limpa automaticamente a área de transferência, pois
isso poderia apagar conteúdo copiado posteriormente pela pessoa.

Consultas usam páginas de 100 documentos, ordenadas por ID, com limite total de
5.000 documentos. Excesso, erro, cache, tipo desconhecido ou mudança de sessão
cancelam a geração inteira; não há truncamento silencioso ou cópia parcial
oferecida. Cada fonte tem espera máxima de 30 segundos. Timestamps preservam
segundos/nanossegundos, além da apresentação UTC; datas civis permanecem strings,
e campos ausentes/null não são preenchidos com datas presumidas.

As páginas/fontes não formam um snapshot atômico. Evite alterações simultâneas
enquanto gera a cópia. Acesso exige a sessão do dono e as regras Firestore;
nenhuma reautenticação adicional foi criada para esta ação de leitura. Troca de
conta retira o resultado da tela e ignora respostas antigas. Isso não revoga uma
cópia que a própria pessoa já tenha salvo. Proteção remota geral permanece em
[SEC-06](SECURITY.md#implantação-pendente).

## Proposta pendente de exclusão e retenção

O app ainda não oferece exclusão completa da conta. Logout, exclusão de livro e
desvínculo não equivalem a exclusão de conta. Nenhum prazo de retenção foi escolhido.
Antes de implementar o fluxo destrutivo, o usuário precisa aprovar:

- Tratamento de listas/experiências de duas pessoas: remoção, anonimização ou
  preservação restrita, conciliando a política de histórico já aprovada.
- Prazo e finalidade de retenção de histórico, auditoria, convites e bloqueios,
  incluindo efeito de uma exclusão sobre os registros da outra pessoa.
- Recuperação ou irreversibilidade e momento em que a conta deixa de poder entrar.

A proposta técnica é reautenticar por credencial recente antes da exclusão,
oferecer a cópia pessoal, encerrar vínculo/revogar projeções e processar remoção
por operação idempotente em backend autorizado. A ordem, recuperação de falhas
parciais e exclusão Auth devem ser testadas em emuladores antes de ativar o fluxo.
Não basta apagar o documento `users` ou chamar exclusão Auth: subcoleções e dados
compartilhados exigem inventário e tratamento explícito. Dados pessoais do parceiro
devem permanecer independentes. Nenhuma dessas operações está implementada ou
autorizada por este documento.

## Verificação local

Testes de serviço/interface verificam escopo, opcionais/timestamps, ausência de
códigos no perfil exportado, limite, falha sem cópia parcial, troca de sessão,
cópia somente por ação explícita e retorno tardio. Teste de consultas percorre
205 livros em três páginas, exclui livro alheio e exige origem servidor; cache
é rejeitado. Fakes não substituem a jornada FlutterFire real em dispositivos.
