# Skill `git-flow` para Claude Code

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
