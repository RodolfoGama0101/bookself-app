# Primeira distribuição com Lume — plano e notas preliminares

Preparação de REL-06 em 09/10/2026. **Ainda não é uma release.** A última pré-release publicada é [v1.3.0](v1.3.0.md), anterior à aplicação local de Lume. Número da próxima versão, código Android, tag, artefatos, hashes, certificado e data de publicação serão preenchidos somente após build e validação da entrega concreta; não reutilizar os valores de v1.3.0.

## Checklist de decisão e execução

| Área | Conferência necessária antes de distribuir | Estado em 09/10/2026 |
| --- | --- | --- |
| Escopo e marca | Confirmar o nome, ícone, textos e metadados em Android, iOS e web; resolver os conflitos encontrados em NAME-02 antes de publicar sob Lume. | Aplicação local em NAME-03; a triagem não liberou publicação. |
| Versão e ambiente | Definir versão/código crescentes, commit e tag; registrar SDK/lockfile e separar build demo com emuladores do build com Firebase real. Conferir flags de filmes, séries, música, listas e paginação para a distribuição escolhida. | Versão nova e matriz de ativação não definidas. `pubspec.yaml` ainda descreve a versão publicada anteriormente. |
| Segurança e dados remotos | Reavaliar regras/índices ativos e compatibilidade com clientes já distribuídos; testar regras candidatas, consentimento, terceiros e desvínculo em desenvolvimento. SEC-06 requer aprovação própria antes de qualquer implantação. | Regras novas somente locais; implantação adiada. |
| Migração | Inventariar `users`, `books`, `bible_progress` e vínculos, executar ensaio com backup, contagens e rollback conforme [DATA_MIGRATION.md](../DATA_MIGRATION.md). Não converter dados legados no build ou no teste de release. | Preparação e ensaio demo, sem migração remota. |
| Privacidade | Confirmar a política de compartilhamento e revogação, escopo da cópia pessoal e ausência de exclusão/retensão definitivas; concluir SEC-05 antes de prometer esses direitos na distribuição. | [Cópia parcial](../PRIVACY.md) local; exclusão e retenção pendentes. |
| Assinatura e recuperação | Gerar/guardar a chave definitiva fora do Git, registrar custódia e cópia recuperável, conferir certificado e caminho de atualização de APKs assinados com debug. Verificar recuperação dos dados e reversão do app/regras com clientes antigos. | REL-02 e plano operacional de recuperação pendentes; v1.3.0 usa assinatura debug. |
| Qualidade | Confirmar CI obrigatório para os dois jobs (QA-05), jornada por mídia e casal (QA-03), Android/iOS/web, rede, autenticação e imagens (REL-04/API-05). Registrar falhas e plataformas não executadas. | CI existe sem proteção obrigatória; jornadas e matriz ainda parciais. |
| Publicação | Aprovar separadamente artefato, notas finais, canal e ação de publicar em GitHub/lojas ou implantar Firebase. Após publicação, conferir download, hash, assinatura, versão, estado do canal e comportamento em instalação/atualização. | Nenhuma ação de publicação desta versão autorizada ou realizada. |

## Notas preliminares para a próxima versão

**Nome exibido:** Lume. **Frase:** “Seu repertório, suas conexões.” O ícone abstrato e os títulos visíveis foram alterados localmente; package/bundle IDs e projeto Firebase continuam com identidade técnica Bookself. A disponibilidade da marca segue em NAME-02.

O código local inclui bibliotecas manuais de filmes, séries e música, progresso por episódio, favoritos/escutas e listas/experiências do casal. A ativação em uma distribuição concreta depende de flags, regras/índices remotos, catálogo aprovado e validação por plataforma; não anunciar essas áreas como liberadas antes de cumprir seus gates. Livros e acompanhamento bíblico permanecem; **não há leitor de texto bíblico no MVP**.

**Limites a expor nas notas finais:** catálogo audiovisual e musical real ainda não escolhido/integrado; cópia pessoal é parcial e não restaurável; exclusão de conta e retenção não foram definidas; regras restritivas locais não foram implantadas; validação iOS, autenticação e uso nativo completos estão pendentes. A próxima release pode ter escopo menor do que o código disponível. Listar apenas funcionalidades efetivamente habilitadas e verificadas no artefato produzido.

## Registro final a preencher na entrega concreta

- Versão/código, commit/tag, data e canal.
- Ambiente e flags exatas do build, sem segredos; Firebase e regras/índices implantados identificados por revisão.
- Matriz de testes e dispositivos, resultados de CI, responsável pela aprovação e pendências aceitas.
- APK/AAB/IPA ou web, SHA-256, certificado, procedimento de instalação/atualização e recuperação.
- Links públicos e verificação posterior de cada artefato, caso haja publicação.

Este plano conclui a **preparação documental** de REL-06. Build assinado, migração, implantação e publicação pertencem aos seus itens e decisões próprias.
