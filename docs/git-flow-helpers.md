<a id="english"></a>

# Git Flow Helpers — manual for the `~/.zshrc` functions

> **Language:** English · [Português](#portugues)

Set of zsh functions to speed up the **git flow (AVH edition)** workflow with
**Conventional Commits** and **Semantic Versioning**.

> They can be used on their own in the terminal, without Claude Code. Claude's
> `git-flow` skill just calls these same functions.

## Assumed conventions

- Repository already initialized with `git flow init`.
- Base branches: `develop` and `master` (or `main` — detected automatically).
- SemVer version tags **without** the `v` prefix: `MAJOR.MINOR.PATCH` (e.g. `1.4.2`).
- Remote named `origin`.
- Every new feature/release/hotfix branch is **published to origin** when created.

---

## Index

| Function | Purpose |
| --- | --- |
| [`gup`](#gup) | Update local `develop` and `master` |
| [`gcMsg`](#gcmsg) | Commit following Conventional Commits (+ pull/push) |
| [`gfs`](#gfs) | Open a feature |
| [`gff`](#gff) | Close a feature |
| [`gfrs`](#gfrs) | Open a release |
| [`gfrf`](#gfrf) | Close a release |
| [`gfhs`](#gfhs) | Open a hotfix |
| [`gfhf`](#gfhf) | Close a hotfix |

---

## `gup`

Updates the local base branches.

```
gup
```

What it does:

1. If there are uncommitted changes, runs `git stash push -u`.
2. `git checkout develop && git pull --ff-only`.
3. `git checkout master` (or `main`) `&& git pull --ff-only`.
4. Goes back to the branch you were on.
5. If it stashed something in step 1, runs `git stash pop`.

Used internally by `gfs`, `gff`, `gfrs`, `gfrf`, `gfhs` and `gfhf`.

---

## `gcMsg`

Creates a commit following **Conventional Commits** and syncs with the remote.

```
gcMsg <type> [scope] "message" [--breaking] [--no-push]
gcMsg                    # interactive mode (pick the type via menu/fzf)
```

Flow: builds the message → `git add .` → `git commit` → `git pull --no-rebase` →
`git push` (unless `--no-push`).

Examples:

```
gcMsg feat "adiciona exportação de relatório em PDF"
gcMsg fix auth "corrige refresh de token expirado"
gcMsg chore deps "atualiza dependências" --no-push
gcMsg feat api "migra endpoints para v2" --breaking
```

| Argument | Description |
| --- | --- |
| `<type>` | `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert` |
| `[scope]` | Optional. A single word, no spaces (e.g. `auth`, `shipping`). |
| `"message"` | Imperative, lowercase, no trailing period. |
| `--breaking` | Adds `!` before the `:` — e.g. `feat(api)!: ...`. Only for breaking changes to an API/contract/public interface. |
| `--no-push` | Commits + pulls, but does **not** push. |

Generated message: `type(scope)!: message`.

---

## `gfs`

**Opens a feature.**

```
gfs <feature-name>
```

`<name>` in kebab-case, short, without the `feature/` prefix (git flow adds it).

What it does:

1. If there are uncommitted changes → `git stash push -u`.
2. `gup`.
3. `git flow feature start <name>` (based on `develop`).
4. `git flow feature publish <name>` (pushes to origin).
5. `git stash pop` on the feature (if something was stashed in step 1).

Example:

```
gfs imagens-magalu
```

---

## `gff`

**Closes the feature** (assumes everything is committed).

```
gff [name] [--no-push]
```

Without `name`, uses the current branch (must start with `feature/`).

What it does:

1. Checks that the tree is clean (aborts otherwise).
2. `gup`.
3. `git flow feature finish <name>` — merges into `develop`, removes the local and remote branch.
4. `git push` of `develop` (unless `--no-push`).

Merge conflict: the process stops. Resolve it and run
`git flow feature finish <name>` again.

---

## `gfrs`

**Opens a release.**

```
gfrs [--minor | --major | --patch]      # default: --minor
```

What it does:

1. `git fetch --tags --prune origin` and finds the **latest SemVer tag**.
2. Computes the next version (by default bumps the **minor**: `1.4.2` → `1.5.0`).
3. Handles uncommitted changes:
   - **on `develop`:** aborts, asking you to commit first (with `gcMsg`);
   - **on another branch:** runs `git stash`, creates the release and restores (`stash pop`) there
     — you commit later with `gcMsg`.
4. If `release/<version>` already exists (local or origin): just checks it out (and publishes it,
   if it was local only).
5. Otherwise: `gup` → `git flow release start <version>` → `git flow release publish <version>`.

The release branch is for final adjustments (version bump in files,
last-minute fixes). Commit them with `gcMsg`.

---

## `gfrf`

**Closes the release.**

```
gfrf [version] [-f <file> | -m "<changelog>"] [--no-push]
```

Without `version`, uses the current branch (`release/*`).

What it does:

1. Checks that the tree is clean (aborts otherwise).
2. `gup`.
3. `git flow release finish` with the 3 merge steps:
   - merges into `master` and `develop` → default message, **no editor opened**;
   - **annotated tag** `MAJOR.MINOR.PATCH` (no `v`) → receives the **changelog**;
   - removes the release branch (local and remote).
4. `git checkout master && git push && git push --tags`.
5. `git checkout develop && git push`.

Changelog (tag message):

| Form | Behavior |
| --- | --- |
| `-f file.md` | Uses the file's contents. **Recommended.** |
| `-m "text"` | Text directly (routed through a file internally to preserve line breaks). |
| *(nothing)* | Generates a simple automatic changelog from `git log <latest-tag>..HEAD`. |

`--no-push`: does the finish locally but does not push `master`/`develop`/tags.

Merge conflict: the process **stops**. The function shows how to resume and
preserves the changelog file. Resolve manually and finish with
`git flow release finish -f <file> <version>`, then the pushes.

Example:

```
gfrf -f CHANGELOG-1.5.0.md
gfrf 1.5.0 -m "Release 1.5.0

### Features
- exportação em PDF

### Fixes
- corrige cálculo de frete"
```

---

## `gfhs`

**Opens a hotfix** (urgent fix based on `master`/production).

```
gfhs
```

What it does:

1. `git fetch --tags --prune origin` and finds the **latest SemVer tag**.
2. Computes the next version by bumping the **patch**: `1.5.0` → `1.5.1`.
3. If there are uncommitted changes → `git stash push -u`.
4. If `hotfix/<version>` already exists (local or origin): just checks it out (and publishes it, if
   it was local only).
5. Otherwise: `gup` → `git flow hotfix start <version>` (based on `master`) →
   `git flow hotfix publish <version>`.
6. `git stash pop` on the hotfix (if something was stashed in step 3).

Then make the fix and commit it with `gcMsg`.

---

## `gfhf`

**Closes the hotfix.** Same logic as `gfrf` (they share the internal function
`_gf_finish`), but with `git flow hotfix finish` — which merges into **`master` and
`develop`**.

```
gfhf [version] [-f <file> | -m "<changelog>"] [--no-push]
```

1. Checks that the tree is clean.
2. `gup`.
3. `git flow hotfix finish` — merges with no editor, annotated tag `MAJOR.MINOR.PATCH`
   with the changelog, removes the branch.
4. `git checkout master && git push && git push --tags`.
5. `git checkout develop && git push`.

Changelog and merge conflict: identical to `gfrf`.

---

## Full workflows (summary)

### Feature

```
gfs pagamento-pix                       # opens and publishes feature/pagamento-pix
# ... code ...
gcMsg feat pagamento "adiciona cobrança via pix"
gcMsg test pagamento "cobre casos de expiração do qr code"
gff                                     # closes, merges into develop, pushes
```

### Release

```
gfrs                                    # 1.4.2 -> opens release/1.5.0 and publishes
# version bump in files, final adjustments
gcMsg chore release "bump para 1.5.0"
gfrf -f CHANGELOG-1.5.0.md              # merges, tag 1.5.0, pushes master+tags and develop
```

### Hotfix

```
gfhs                                    # 1.5.0 -> opens hotfix/1.5.1 and publishes
# urgent fix
gcMsg fix checkout "corrige erro 500 ao finalizar pedido"
gfhf -m "Hotfix 1.5.1

### Fixes
- corrige erro 500 no checkout"
```

---

## Name table

| Prefix | Start | Finish |
| --- | --- | --- |
| feature | `gfs` | `gff` |
| release | `gfrs` | `gfrf` |
| hotfix | `gfhs` | `gfhf` |

Mnemonic: **g**it **f**low + **s**tart/**f**inish; `r` = release, `h` = hotfix.

---
---

<a id="portugues"></a>

# Git Flow Helpers — manual das funções do `~/.zshrc`

> **Idioma:** Português · [English](#english)

Conjunto de funções zsh para agilizar o fluxo **git flow (AVH edition)** com
**Conventional Commits** e **Versionamento Semântico**.

> Podem ser usadas soltas no terminal, sem o Claude Code. A skill `git-flow` do
> Claude apenas chama estas mesmas funções.

## Convenções assumidas

- Repositório já inicializado com `git flow init`.
- Branches base: `develop` e `master` (ou `main` — detectado automaticamente).
- Tags de versão em SemVer **sem** prefixo `v`: `MAJOR.MINOR.PATCH` (ex.: `1.4.2`).
- Remoto chamado `origin`.
- Toda branch nova de feature/release/hotfix é **publicada na origin** ao ser criada.

---

## Índice

| Função | Para quê |
| --- | --- |
| [`gup`](#pt-gup) | Atualizar `develop` e `master` locais |
| [`gcMsg`](#pt-gcmsg) | Commit no padrão Conventional Commits (+ pull/push) |
| [`gfs`](#pt-gfs) | Abrir feature |
| [`gff`](#pt-gff) | Fechar feature |
| [`gfrs`](#pt-gfrs) | Abrir release |
| [`gfrf`](#pt-gfrf) | Fechar release |
| [`gfhs`](#pt-gfhs) | Abrir hotfix |
| [`gfhf`](#pt-gfhf) | Fechar hotfix |

---

<a id="pt-gup"></a>

## `gup`

Atualiza as branches base locais.

```
gup
```

O que faz:

1. Se houver alterações não commitadas, faz `git stash push -u`.
2. `git checkout develop && git pull --ff-only`.
3. `git checkout master` (ou `main`) `&& git pull --ff-only`.
4. Volta para a branch em que você estava.
5. Se guardou algo no passo 1, faz `git stash pop`.

Usada internamente por `gfs`, `gff`, `gfrs`, `gfrf`, `gfhs` e `gfhf`.

---

<a id="pt-gcmsg"></a>

## `gcMsg`

Cria um commit no padrão **Conventional Commits** e sincroniza com o remoto.

```
gcMsg <tipo> [escopo] "mensagem" [--breaking] [--no-push]
gcMsg                    # modo interativo (escolhe tipo por menu/fzf)
```

Fluxo: monta a mensagem → `git add .` → `git commit` → `git pull --no-rebase` →
`git push` (salvo `--no-push`).

Exemplos:

```
gcMsg feat "adiciona exportação de relatório em PDF"
gcMsg fix auth "corrige refresh de token expirado"
gcMsg chore deps "atualiza dependências" --no-push
gcMsg feat api "migra endpoints para v2" --breaking
```

| Argumento | Descrição |
| --- | --- |
| `<tipo>` | `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`, `revert` |
| `[escopo]` | Opcional. Uma palavra, sem espaços (ex.: `auth`, `frete`). |
| `"mensagem"` | Imperativo, minúsculo, sem ponto final. |
| `--breaking` | Adiciona `!` antes do `:` — ex.: `feat(api)!: ...`. Só para quebra de compatibilidade de API/contrato/interface pública. |
| `--no-push` | Faz commit + pull, mas **não** faz push. |

Mensagem gerada: `tipo(escopo)!: mensagem`.

---

<a id="pt-gfs"></a>

## `gfs`

**Abre uma feature.**

```
gfs <nome-da-feature>
```

`<nome>` em kebab-case, curto, sem o prefixo `feature/` (o git flow adiciona).

O que faz:

1. Se houver alterações não commitadas → `git stash push -u`.
2. `gup`.
3. `git flow feature start <nome>` (a partir de `develop`).
4. `git flow feature publish <nome>` (sobe para a origin).
5. `git stash pop` na feature (se algo foi guardado no passo 1).

Exemplo:

```
gfs imagens-magalu
```

---

<a id="pt-gff"></a>

## `gff`

**Fecha a feature** (pressupõe tudo commitado).

```
gff [nome] [--no-push]
```

Sem `nome`, usa a branch atual (precisa começar com `feature/`).

O que faz:

1. Verifica que a árvore está limpa (aborta se não).
2. `gup`.
3. `git flow feature finish <nome>` — merge em `develop`, remove a branch local e remota.
4. `git push` de `develop` (salvo `--no-push`).

Conflito no merge: o processo é interrompido. Resolva e rode
`git flow feature finish <nome>` novamente.

---

<a id="pt-gfrs"></a>

## `gfrs`

**Abre uma release.**

```
gfrs [--minor | --major | --patch]      # default: --minor
```

O que faz:

1. `git fetch --tags --prune origin` e descobre a **última tag SemVer**.
2. Calcula a próxima versão (por padrão incrementa a **minor**: `1.4.2` → `1.5.0`).
3. Trata alterações não commitadas:
   - **em `develop`:** aborta pedindo para commitar antes (com `gcMsg`);
   - **em outra branch:** faz `git stash`, cria a release e restaura (`stash pop`) lá
     — você commita depois com `gcMsg`.
4. Se `release/<versão>` já existe (local ou origin): apenas faz checkout (e publica,
   se estava só local).
5. Senão: `gup` → `git flow release start <versão>` → `git flow release publish <versão>`.

A branch de release serve para ajustes finais (bump de versão em arquivos,
correções de última hora). Commite-os com `gcMsg`.

---

<a id="pt-gfrf"></a>

## `gfrf`

**Fecha a release.**

```
gfrf [versão] [-f <arquivo> | -m "<changelog>"] [--no-push]
```

Sem `versão`, usa a branch atual (`release/*`).

O que faz:

1. Verifica árvore limpa (aborta se não).
2. `gup`.
3. `git flow release finish` com as 3 etapas de merge:
   - merges em `master` e `develop` → mensagem padrão, **sem abrir editor**;
   - **tag anotada** `MAJOR.MINOR.PATCH` (sem `v`) → recebe o **changelog**;
   - remove a branch de release (local e remota).
4. `git checkout master && git push && git push --tags`.
5. `git checkout develop && git push`.

Changelog (mensagem da tag):

| Forma | Comportamento |
| --- | --- |
| `-f arquivo.md` | Usa o conteúdo do arquivo. **Recomendado.** |
| `-m "texto"` | Texto direto (roteado por arquivo internamente para preservar quebras de linha). |
| *(nada)* | Gera um changelog automático simples a partir de `git log <última-tag>..HEAD`. |

`--no-push`: faz o finish local mas não envia `master`/`develop`/tags.

Conflito no merge: o processo é **interrompido**. A função mostra como retomar e
preserva o arquivo de changelog. Resolva manualmente e conclua com
`git flow release finish -f <arquivo> <versão>`, depois os pushes.

Exemplo:

```
gfrf -f CHANGELOG-1.5.0.md
gfrf 1.5.0 -m "Release 1.5.0

### Features
- exportação em PDF

### Fixes
- corrige cálculo de frete"
```

---

<a id="pt-gfhs"></a>

## `gfhs`

**Abre um hotfix** (correção urgente a partir de `master`/produção).

```
gfhs
```

O que faz:

1. `git fetch --tags --prune origin` e descobre a **última tag SemVer**.
2. Calcula a próxima versão incrementando a **patch**: `1.5.0` → `1.5.1`.
3. Se houver alterações não commitadas → `git stash push -u`.
4. Se `hotfix/<versão>` já existe (local ou origin): apenas checkout (e publica, se
   estava só local).
5. Senão: `gup` → `git flow hotfix start <versão>` (a partir de `master`) →
   `git flow hotfix publish <versão>`.
6. `git stash pop` no hotfix (se algo foi guardado no passo 3).

Depois, faça a correção e commite com `gcMsg`.

---

<a id="pt-gfhf"></a>

## `gfhf`

**Fecha o hotfix.** Mesma lógica de `gfrf` (compartilham a função interna
`_gf_finish`), mas com `git flow hotfix finish` — que faz merge em **`master` e
`develop`**.

```
gfhf [versão] [-f <arquivo> | -m "<changelog>"] [--no-push]
```

1. Verifica árvore limpa.
2. `gup`.
3. `git flow hotfix finish` — merges sem editor, tag anotada `MAJOR.MINOR.PATCH`
   com o changelog, remove a branch.
4. `git checkout master && git push && git push --tags`.
5. `git checkout develop && git push`.

Changelog e conflito de merge: idênticos ao `gfrf`.

---

## Fluxos completos (resumo)

### Feature

```
gfs pagamento-pix                       # abre e publica feature/pagamento-pix
# ... código ...
gcMsg feat pagamento "adiciona cobrança via pix"
gcMsg test pagamento "cobre casos de expiração do qr code"
gff                                     # fecha, merge em develop, push
```

### Release

```
gfrs                                    # 1.4.2 -> abre release/1.5.0 e publica
# bump de versão nos arquivos, ajustes finais
gcMsg chore release "bump para 1.5.0"
gfrf -f CHANGELOG-1.5.0.md              # merges, tag 1.5.0, push master+tags e develop
```

### Hotfix

```
gfhs                                    # 1.5.0 -> abre hotfix/1.5.1 e publica
# correção urgente
gcMsg fix checkout "corrige erro 500 ao finalizar pedido"
gfhf -m "Hotfix 1.5.1

### Fixes
- corrige erro 500 no checkout"
```

---

## Tabela de nomes

| Prefixo | Start | Finish |
| --- | --- | --- |
| feature | `gfs` | `gff` |
| release | `gfrs` | `gfrf` |
| hotfix | `gfhs` | `gfhf` |

Mnemônico: **g**it **f**low + **s**tart/**f**inish; `r` = release, `h` = hotfix.
