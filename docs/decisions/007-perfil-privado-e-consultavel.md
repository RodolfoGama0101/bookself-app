# 007 — Perfil privado e apresentação do parceiro

Data: 05/10/2026. Estado: **implementado e validado localmente; implantação remota pendente**. Tarefa: SEC-04.

## Problema e escolha

O parceiro recebia `users/{uid}` inteiro, incluindo e-mail, e a tela de perfil exibia esse campo. A [política v1](../COUPLE_POLICY.md) permite consultar nome/foto, mantendo os demais dados privados. Firestore autoriza documentos inteiros; não é possível restringir a leitura apenas removendo e-mail de um widget. [Referência oficial](https://firebase.google.com/docs/firestore/security/rules-fields).

Manter `users` e suas identidades/campos legados, restringindo sua leitura ao dono nas regras candidatas. Criar `partner_profiles/{uid}` apenas com nome/foto e modelo `PartnerProfile` separado. UID vem do caminho; e-mail, vínculo, criação e campos desconhecidos não são copiados. O parceiro lê somente essa apresentação e nunca usa o documento privado como alternativa. Escritas são exclusivas do dono e conferidas com `getAfter` do perfil privado.

Cadastro/recuperação e edição de nome/foto usam transação. Alterações em projeção atual aplicam só o campo da intenção, preservando edições concorrentes do outro campo. Projeção ausente/desatualizada é reconstruída com nome/foto atuais. Ao receber perfil próprio válido, o app tenta publicar a própria apresentação sem bloquear uso individual; a transação relê os dados atuais e não escreve quando já estiverem iguais.

## Alternativas

- Esconder e-mail na tela e continuar consultando `users`: insuficiente; dados privados continuariam entregues pelo banco.
- Mover/remover campos privados de todos os documentos: exigiria migração e revisão de clientes existentes. A projeção aditiva preserva contas e dados sem migração em lote.
- Ler o documento privado se a projeção estiver ausente: rejeitada por violar a separação. A interface usa apresentação neutra e mantém os fluxos pelo vínculo do próprio usuário.
- Backend para projeção: não necessário para esta etapa; as regras locais restringem autor/campos e conferem a correspondência com o estado privado. Convites e evolução do esquema têm tarefas próprias.

## Validação e limites

32 testes Auth/Firestore passaram no projeto local `demo-bookself`, incluindo terceiros, negação de perfil privado ao parceiro, campos extras, concorrência de nome/foto, atomicidade, legado, desvínculo e novo vínculo. Testes Dart verificam confirmação/rejeição, publicação sem bloquear sessão, ausência/falha sem fallback, parser restrito, limpeza de ouvintes e tela do casal sem e-mail alheio em 320 × 480. Evidências completas em [DEVELOPMENT.md](../DEVELOPMENT.md).

As regras não foram implantadas, e nenhum documento de produção foi consultado ou escrito pelo agente. Clientes antigos perdem a leitura privada do parceiro após a implantação; disponibilidade de projeções e atualização dos clientes precisam de revisão em SEC-06. Publicação pelo próprio usuário ao abrir a versão atual não comprova preenchimento de todas as contas nem recolhe dados já entregues/cacheados. Convites, ocultação e limpeza ampla de cache continuam em COUPLE-03/04 e DATA-05. Não houve migração de livros, vínculos ou Bíblia.
