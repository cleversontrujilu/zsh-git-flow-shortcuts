<a id="english"></a>

# `git-flow` skill for Claude Code

> **Language:** English · [Português](#portugues)

A skill that lets Claude Code drive the project's **git flow (AVH edition)**
workflow — opening and closing features, releases and hotfixes — choosing branch
names, SemVer versions and writing commits and changelog from a real analysis of
the diff and the history.

The skill **does not reimplement** git flow: it orchestrates a set of zsh functions
(`gfs`, `gff`, `gfrs`, `gfrf`, `gfhs`, `gfhf`, `gup`, `gcMsg`) that can also be
used on their own in the terminal. The full manual for those functions is in
[`git-flow-helpers.md`](../../docs/git-flow-helpers.md).

------

## Installation

The skill depends on the git-flow-shortcuts plugin being installed (see the root README.md):

1. **Skill** — place `SKILL.md` at `~/.claude/skills/git-flow/SKILL.md`.
   Claude Code loads the skill automatically at the start of the session.
2. **Repository prerequisites**: `git flow init` already done, `origin` remote,
   base branches `develop` and `master` (or `main` — detected automatically).

---

## What it automates

| Situation | What Claude does |
| --- | --- |
| "Let's open a feature to upload the images to S3" | Chooses the name (`integracao-imagens-s3`), runs `gfs`, publishes the branch to origin |
| "Commit what we did" | Reads the diff, builds the Conventional Commits message and runs `gcMsg` |
| "Close the feature" | Checks the tree is clean, runs `gff` (merge into `develop` + push) |
| "Open the release" | Finds the latest tag, computes the next one (minor bump), runs `gfrs` and publishes |
| "Close the release" | Writes the changelog from `git log <tag>..HEAD`, runs `gfrf` (3 merges, annotated tag, pushes `master`/`develop`/tags) |
| "We need an urgent hotfix" | Computes the next patch, runs `gfhs`, publishes; then `gfhf` to finish |

Conventions applied automatically:

- **Tags** in SemVer **without** the `v` prefix — just `major.minor.patch`.
- **Commits and changelog** in Portuguese, following Conventional Commits
  (`type(scope): message`), imperative, lowercase, no trailing period.
- Every new feature/release/hotfix branch is **published to origin** when created.
- Opening and closing are **always separate steps** — Claude never chains
  `open + close` in one go.

---

## Day-to-day use

Just describe the intent in natural language inside Claude Code. The skill is
triggered by phrases like "open/create/close feature", "start/finish a release",
"open a hotfix", "bump the version", "generate changelog", or by describing a
task that should become a branch.

### Feature

```
you:    let's create a feature for pix payment
claude: (runs gfs pagamento-pix — branch created and published)

... you code, talk to claude ...

you:    you can commit
claude: (git diff → gcMsg feat pagamento "adiciona cobrança via pix")

you:    close the feature
claude: (checks git status → gff → merge into develop → push)
```

### Release

```
you:    open the release
claude: latest tag 1.4.2 → opens release/1.5.0 and publishes (git push -u origin release/1.5.0)

... final adjustments, version bump in files ...
you:    commit the bump
claude: gcMsg chore release "bump para 1.5.0"

you:    now close the release
claude: builds the changelog from git log 1.4.2..HEAD,
        runs gfrf → 3 merges, annotated tag 1.5.0, pushes master+tags and develop
```

If you ask to "close the release" when no release branch exists, Claude
**asks** whether it should open one — it does not assume open+close.

### Hotfix

```
you:    got a 500 error at checkout in production, need a hotfix
claude: latest tag 1.5.0 → opens hotfix/1.5.1 and publishes (git push -u origin hotfix/1.5.1)

you:    fixed, you can commit and close
claude: gcMsg fix checkout "corrige erro 500 ao finalizar pedido"
        → changelog → gfhf → merges into master and develop, tag 1.5.1, pushes
```

---

## When Claude stops and calls you

- **Merge conflict** in any finish → the process stops; you resolve it manually
  and finish. Claude **does not force**.
- **`develop` with uncommitted files** when opening a release → it asks you to
  commit first (with `gcMsg`).
- **Doubt between two feature names** or about the version bump (`--major` vs
  `--minor`) → it proposes and confirms before creating.
- Any function that fails → it shows the output and stops, without working around it.

Claude never runs `git flow init`, `git push --force` or `git tag -d` without you
asking explicitly.

---

## Manual invocation

Besides the automatic trigger, you can call the skill by hand with `/git-flow` in
Claude Code.

---
---

<a id="portugues"></a>

# Skill `git-flow` para Claude Code

> **Idioma:** Português · [English](#english)

Uma skill que deixa o Claude Code conduzir o fluxo **git flow (AVH edition)** do
projeto — abrir e fechar features, releases e hotfixes — escolhendo nomes de
branch, versões SemVer e escrevendo commits e changelog a partir da análise real
do diff e do histórico.

A skill **não reimplementa** o git flow: ela orquestra um conjunto de funções zsh
(`gfs`, `gff`, `gfrs`, `gfrf`, `gfhs`, `gfhf`, `gup`, `gcMsg`) que também podem
ser usadas soltas no terminal. O manual completo dessas funções está em
[`git-flow-helpers.md`](../../docs/git-flow-helpers.md).

------

## Instalação

A skill depende do plugin git-flow-shortcuts instalado (ver README.md da raiz) :

1. **Skill** — colocar `SKILL.md` em `~/.claude/skills/git-flow/SKILL.md`.
   O Claude Code carrega a skill automaticamente no início da sessão.
2. **Pré-requisitos do repositório**: `git flow init` já feito, remoto `origin`,
   branches base `develop` e `master` (ou `main` — detectado automaticamente).

---

## O que ela automatiza

| Situação | O que o Claude faz |
| --- | --- |
| "Vamos abrir uma feature para a funcionalidade para realizarmos o upload das imagens no S3 " | Escolhe o nome (`integracao-imagens-s3`), roda `gfs`, publica a branch na origin |
| "Commita o que fizemos" | Lê o diff, monta a mensagem Conventional Commits e roda `gcMsg` |
| "Fecha a feature" | Confere árvore limpa, roda `gff` (merge em `develop` + push) |
| "Abre a release" | Descobre a última tag, calcula a próxima (bump minor), roda `gfrs` e publica |
| "Fecha a release" | Escreve o changelog a partir de `git log <tag>..HEAD`, roda `gfrf` (3 merges, tag anotada, push de `master`/`develop`/tags) |
| "Precisa de um hotfix urgente" | Calcula a próxima patch, roda `gfhs`, publica; depois `gfhf` para finalizar |

Convenções aplicadas automaticamente:

- **Tags** em SemVer **sem** prefixo `v` — apenas `major.minor.patch`.
- **Commits e changelog** em português, no padrão Conventional Commits
  (`tipo(escopo): mensagem`), imperativo, minúsculo, sem ponto final.
- Toda branch nova de feature/release/hotfix é **publicada na origin** ao ser criada.
- Abrir e fechar são **sempre passos separados** — o Claude nunca encadeia
  `abrir + fechar` numa tacada.

---

## Como usar no dia a dia

Basta descrever a intenção em linguagem natural dentro do Claude Code. A skill é
acionada por frases como "abrir/criar/fechar feature", "começar/finalizar uma
release", "abrir um hotfix", "subir versão", "gerar changelog", ou ao descrever
uma demanda que deve virar uma branch.

### Feature

```
você:  vamos criar uma feature pro pagamento via pix
claude: (roda gfs pagamento-pix — branch criada e publicada)

... você programa, conversa com o claude ...

você:  pode commitar
claude: (git diff → gcMsg feat pagamento "adiciona cobrança via pix")

você:  fecha a feature
claude: (confere git status → gff → merge em develop → push)
```

### Release

```
você:  abre a release
claude: última tag 1.4.2 → abre release/1.5.0 e publica (git push -u origin release/1.5.0)

... ajustes finais, bump de versão nos arquivos ...
você:  commita o bump
claude: gcMsg chore release "bump para 1.5.0"

você:  agora fecha a release
claude: monta o changelog a partir de git log 1.4.2..HEAD,
        roda gfrf → 3 merges, tag anotada 1.5.0, push master+tags e develop
```

Se você pedir "fechar a release" sem que exista uma branch de release, o Claude
**pergunta** se é pra abrir — não assume abrir+fechar.

### Hotfix

```
você:  deu erro 500 no checkout em produção, precisa de hotfix
claude: última tag 1.5.0 → abre hotfix/1.5.1 e publica (git push -u origin hotfix/1.5.1)

você:  corrigido, pode commitar e fechar
claude: gcMsg fix checkout "corrige erro 500 ao finalizar pedido"
        → changelog → gfhf → merges em master e develop, tag 1.5.1, pushes
```

---

## Quando o Claude para e te chama

- **Conflito de merge** em qualquer finish → o processo é interrompido; você
  resolve manualmente e conclui. O Claude **não força**.
- **`develop` com arquivos não commitados** ao abrir uma release → ele pede pra
  commitar antes (com `gcMsg`).
- **Dúvida entre dois nomes de feature** ou sobre o incremento de versão
  (`--major` vs `--minor`) → ele propõe e confirma antes de criar.
- Qualquer função que falhe → ele mostra a saída e para, sem contornar por fora.

O Claude nunca roda `git flow init`, `git push --force` ou `git tag -d` sem você
pedir explicitamente.

---

## Invocação manual

Além do acionamento automático, dá pra chamar a skill na mão com `/git-flow` no
Claude Code.
