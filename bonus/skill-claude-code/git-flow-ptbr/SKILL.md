---
name: git-flow
description: Auxilia no fluxo git flow (AVH edition) para abrir/fechar features, releases e hotfixes. Usar quando o usuário pedir para "abrir/criar/fechar feature", "começar/finalizar uma release", "abrir um hotfix", "subir versão", "gerar changelog", ou descrever uma demanda que deve virar uma branch de feature. Orquestra as funções do ~/.zshrc (gfs, gff, gfrs, gfrf, gfhs, gfhf, gup) e monta commits/changelog no padrão Conventional Commits + SemVer a partir da análise real do diff e do histórico.
---

# git flow — features, releases e hotfixes

Este projeto usa **git flow (AVH edition)** com funções auxiliares já definidas no
`~/.zshrc` do usuário. A skill **não reimplementa** o fluxo: ela decide nomes/versões,
roda as funções certas e escreve os textos (commits e changelog).

## Funções disponíveis (no ~/.zshrc)

| Função | O que faz |
| --- | --- |
| `gup` | checkout+pull de `develop` e `master`/`main`; stash/pop automático; volta pra branch de origem. |
| `gfs <nome>` | Abre feature: stash → `gup` → `git flow feature start` → **`git flow feature publish`** → `git stash pop` na feature. |
| `gff [nome] [--no-push]` | Fecha feature (tudo commitado): `gup` → `git flow feature finish` (remove a branch local e remota) → push de `develop`. Sem nome, usa a branch atual. |
| `gfrs [--minor\|--major\|--patch]` | Abre release: `git fetch --tags` → calcula a próxima versão (**default: bump da minor**) → trata arquivos não commitados (ver abaixo) → se a branch já existe (local/origin) só faz checkout; senão `gup` → `git flow release start` → **`git flow release publish`**. |
| `gfrf [versão] [-f <arq>\|-m <msg>] [--no-push]` | Fecha release: `gup` → `git flow release finish` (merges sem editor + tag anotada com o changelog) → `checkout master && git push && git push --tags` → `checkout develop && git push`. |
| `gfhs` | Abre hotfix: `git fetch --tags` → calcula a próxima versão (**bump da patch**) → stash das alterações não commitadas → se a branch já existe (local/origin) checkout + `stash pop`; senão `gup` → `git flow hotfix start` (a partir de `master`) → **`git flow hotfix publish`** → `stash pop` no hotfix. |
| `gfhf [versão] [-f <arq>\|-m <msg>] [--no-push]` | Fecha hotfix: igual a `gfrf` (mesma lógica interna `_gf_finish`), com `git flow hotfix finish`. |
| `gcMsg <tipo> <escopo> "msg" [--no-push] [--breaking]` | Commit Conventional Commits: `git add .` → commit → pull → push. `<escopo>` opcional. |

Rodar sempre via shell do usuário (as funções vivem no `.zshrc`). Se um comando
falhar, **parar e mostrar a saída** — não contornar por fora.

Convenções do projeto:
- **Tags:** SemVer **sem** prefixo `v` — apenas `major.minor.patch` (ex.: `1.5.0`).
- **Commits:** Conventional Commits, mensagem em português, imperativo, minúsculo, sem ponto final.

---

## FEATURE

### Abrir

1. **Escolher o nome** a partir da demanda discutida na conversa: kebab-case, curto,
   compreensão imediata, sem o prefixo `feature/` (o git flow adiciona).
   - "login social com Google" → `login-google`
   - "cálculo de frete duplicado" → `frete-duplicado`
   - Na dúvida entre dois nomes, propor um e confirmar antes de criar.
2. Conferir repo + git flow inicializado (`git config gitflow.branch.develop`).
3. Rodar `gfs <nome>`.
4. Confirmar: branch criada **e publicada na origin**; se havia alterações não
   commitadas, foram levadas pra feature (`git status`).

### Commitar durante a feature

Para cada unidade lógica de mudança, montar o commit com `gcMsg` **analisando o diff
real** (`git status`, `git diff`, `git diff --staged`):
- `<tipo>`: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert`.
- `<escopo>`: módulo/área em uma palavra (ex.: `auth`, `frete`, `imagens`); omitir se não houver um claro.
- `"msg"`: descreve **o quê** mudou, baseada nas alterações reais — não no nome da feature.
- `--breaking`: só quando quebra compatibilidade de API/contrato/interface pública.
- `--no-push`: quando o usuário pedir para não enviar ainda.
- `gcMsg` roda `git add .`. Se só parte das mudanças deve entrar, fazer `git add`
  seletivo + `git commit` manual seguindo a mesma convenção.

### Fechar

1. Garantir `git status` limpo; se não, montar os commits pendentes com `gcMsg`.
2. Estar na branch da feature (ou passar o nome).
3. Rodar `gff` (ou `gff <nome>` / `gff --no-push`).
4. `gff` roda `gup` → `git flow feature finish` (merge em `develop` + remove a branch) → push de `develop`.
5. Conflito de merge no finish → avisar o usuário e **não forçar**: ele resolve e roda
   `git flow feature finish <nome>` de novo.

---

## RELEASE

> **Abrir e fechar são passos separados, nunca encadeados.** `gfrs` cria a branch e
> para; o usuário trabalha nela (bump de versão, changelog, ajustes finais, commits
> com `gcMsg`) pelo tempo que quiser; só depois, num pedido explícito, roda-se `gfrf`.
> "Fechar a release" = só `gfrf` (a branch já existe). Se não existir branch de
> release, perguntar se é pra abrir — não assumir abrir+fechar.

### Abrir

1. **Antes de rodar `gfrs`, checar `git status`.** Se houver arquivos não commitados:
   - **Na branch `develop`:** commitá-los primeiro com `gcMsg <tipo> <escopo> "msg"`
     (mensagem derivada do diff real). Só então rodar `gfrs`. — Se `gfrs` for chamado
     com `develop` sujo, ele **aborta** pedindo isso.
   - **Em qualquer outra branch:** rodar `gfrs` direto. Ele guarda as alterações num
     stash, cria e **publica** a `release/<versão>`, e faz `stash pop` lá deixando as
     alterações restauradas (não commitadas). Em seguida, commitar essas alterações
     na release com `gcMsg <tipo> <escopo> "msg"` (a branch já tem upstream).
2. Decidir o incremento SemVer. **Default: minor** (`gfrs`). Usar `--major` só se
   houver breaking change acumulado; `--patch` para release só de correções.
   - `gfrs` descobre a última tag e calcula a próxima (ex.: `1.4.2` → `1.5.0`).
   - Se já existir `release/<versão>` local ou na origin, `gfrs` só faz checkout nela
     (não recria); se for local e ainda não estiver na origin, publica.
3. Rodar `gfrs` (ou `gfrs --major` / `gfrs --patch`).
4. `gfrs` roda `gup`, cria a branch a partir de `develop` e **publica na origin**
   (`git flow release publish`). Confirmar a versão calculada e a branch criada.
5. Nesta branch entram só ajustes finais de release (bump de versão em arquivos,
   correções de última hora) — commitados com `gcMsg`.

### Fechar

1. Garantir `git status` limpo na branch de release.
2. **Escrever o changelog** da versão (é a "tela 2" do finish, a mensagem da tag
   anotada). Gerar analisando o histórico desde a última tag:
   ```
   git log --no-merges --pretty=format:'- %s' <última-tag>..HEAD
   ```
   Organizar por seção (ex.: `### Features`, `### Fixes`, `### Breaking changes`),
   em português, legível — não colar a lista crua de commits. Salvar num arquivo
   temporário e passar com `-f`:
   ```
   gfrf -f /caminho/CHANGELOG-1.5.0.md
   ```
   (Alternativa: `gfrf -m "texto multi-linha"` — a função roteia por arquivo
   internamente. Se nada for passado, `gfrf` gera um changelog automático simples.)
3. `gfrf` roda `gup`, depois `git flow release finish`:
   
   - merges em `master` e `develop` com mensagem padrão (sem abrir editor);
   - tag anotada `major.minor.patch` (sem `v`) com o changelog;
   - remove a branch de release (local e remota).
   Depois: `checkout master` + `git push && git push --tags`, `checkout develop` + `git push`.
4. **Conflito de merge** → `gfrf` interrompe e mostra como retomar. Avisar o usuário
   para resolver manualmente; **não forçar**. O arquivo de changelog é preservado para
   ele concluir com `git flow release finish -f <arquivo> <versão>`.
5. Confirmar ao usuário: versão tagueada, `master` e `develop` publicados.

---

## HOTFIX

Correção urgente que sai direto de `master` (produção), sem passar por `develop`.

> **Abrir (`gfhs`) e fechar (`gfhf`) são passos separados**, como na release — o
> usuário corrige e commita na branch entre um e outro.

### Abrir

1. Se houver arquivos não commitados, `gfhs` já guarda tudo num stash e devolve
   (`stash pop`) na branch de hotfix criada — não precisa commitar antes.
2. Rodar `gfhs` (sem argumentos). Ele:
   - descobre a última tag da origin e calcula a próxima **incrementando a patch**
     (ex.: `2.3.1` → `2.3.2`);
   - se já existir `hotfix/<versão>` (local ou origin), só faz checkout nela + `stash pop`;
   - senão: `gup` → `git flow hotfix start <versão>` (a partir de `master`) →
     **`git flow hotfix publish`** → `stash pop`.
3. Fazer a correção e commitar com `gcMsg` (mensagem derivada do diff real).

### Fechar

1. Garantir `git status` limpo na branch de hotfix.
2. **Escrever o changelog** do hotfix (é a "tela 2" do finish / mensagem da tag),
   analisando `git log --no-merges --pretty=format:'- %s' <última-tag>..HEAD`.
   Organizar de forma legível, em português. Passar com `-f <arquivo>` (ou `-m`).
3. Rodar `gfhf` (ou `gfhf <versão>` / `gfhf --no-push`). Ele roda `gup` e
   `git flow hotfix finish`:
   - merges em `master` **e** `develop` sem abrir editor;
   - tag anotada `major.minor.patch` (sem `v`) com o changelog;
   - remove a branch de hotfix;
   - `checkout master` + `git push && git push --tags`, `checkout develop` + `git push`.
4. **Conflito de merge** → `gfhf` interrompe e mostra como retomar; o arquivo de
   changelog é preservado. Avisar o usuário; **não forçar**.
5. Confirmar: versão tagueada, `master` e `develop` publicados.

---

## Observações

- `master`/`main`: as funções detectam automaticamente qual existe (`gitflow.branch.master`).
- `gfrf` e `gfhf` compartilham a função interna `_gf_finish` — mesma lógica de finish.
- Nunca rodar `git flow init`, `git push --force` ou `git tag -d` sem o usuário pedir.
