# git-flow-shortcuts

Conjunto de funções zsh para agilizar o fluxo **git flow (AVH edition)** com
**Conventional Commits** e **Versionamento Semântico**.

> Repositório: `cleversontrujilu/zsh-git-flow-shortcuts` · nome do plugin: `git-flow-shortcuts`.

> Podem ser usadas soltas no terminal, sem o Claude Code. A skill `git-flow` do
> Claude apenas chama estas mesmas funções.

## Requisitos

- `zsh`
- [`git-flow` (AVH edition)](https://github.com/petervanderdoes/gitflow-avh)

## Instalação

### Como plugin do oh-my-zsh

Clone o repositório numa pasta chamada `git-flow-shortcuts` (é o nome da pasta,
não o do repo, que o oh-my-zsh usa para achar o plugin):

```sh
git clone https://github.com/cleversontrujilu/zsh-git-flow-shortcuts \
  "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/git-flow-shortcuts"
```

Adicione ao array `plugins` no `~/.zshrc`:

```sh
plugins=(... git-flow-shortcuts)
```

Recarregue: `source ~/.zshrc`.

### Sem oh-my-zsh

```sh
git clone https://github.com/cleversontrujilu/zsh-git-flow-shortcuts ~/.git-flow-shortcuts
echo 'source ~/.git-flow-shortcuts/git-flow-shortcuts.plugin.zsh' >> ~/.zshrc
source ~/.zshrc
```

### Com gerenciador de plugins

```sh
# zinit
zinit light cleversontrujilu/zsh-git-flow-shortcuts

# antidote (arquivo .zsh_plugins.txt)
cleversontrujilu/zsh-git-flow-shortcuts
```

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
| [`gup`](#gup) | Atualizar `develop` e `master` locais |
| [`gcMsg`](#gcmsg) | Commit no padrão Conventional Commits (+ pull/push) |
| [`gfs`](#gfs) | Abrir feature |
| [`gff`](#gff) | Fechar feature |
| [`gfrs`](#gfrs) | Abrir release |
| [`gfrf`](#gfrf) | Fechar release |
| [`gfhs`](#gfhs) | Abrir hotfix |
| [`gfhf`](#gfhf) | Fechar hotfix |

---

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
