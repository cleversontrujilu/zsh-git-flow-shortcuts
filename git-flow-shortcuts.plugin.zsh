# git-flow-shortcuts — plugin oh-my-zsh
# Atalhos para o fluxo git flow (AVH edition) com Conventional Commits + SemVer.
# Repositório: https://github.com/cleversontrujilu/zsh-git-flow-shortcuts
#
# Aviso (não bloqueia o carregamento) se o git flow AVH não estiver instalado.
if ! command -v git-flow >/dev/null 2>&1 && ! git flow version >/dev/null 2>&1; then
  print -u2 "git-flow-shortcuts: 'git flow' (AVH edition) não encontrado — instale-o para usar gfs/gff/gfrs/gfrf/gfhs/gfhf."
fi

# ── Git flow helpers ─────────────────────────────────────────────
# gup: atualiza develop e master (ou main) com git pull.
# Faz stash automático dos arquivos não comitados e devolve (stash pop)
# na branch em que você estava.
gup() {
  local start_branch stashed=0 base branches=(develop) rc=0

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "gup: não é um repositório git" >&2
    return 1
  fi

  start_branch=$(git symbolic-ref --short -q HEAD)

  # Descobre se a branch principal se chama master ou main
  if git show-ref --verify --quiet refs/heads/master; then
    branches+=(master)
  elif git show-ref --verify --quiet refs/heads/main; then
    branches+=(main)
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "gup: guardando alterações (git stash)…"
    git stash push -u -m "gup auto-stash" && stashed=1
  fi

  for base in $branches; do
    if git show-ref --verify --quiet "refs/heads/$base"; then
      echo "gup: atualizando $base…"
      git checkout "$base" && git pull --ff-only || rc=1
    else
      echo "gup: branch $base não existe, pulando." >&2
    fi
  done

  if [[ -n "$start_branch" ]]; then
    git checkout "$start_branch"
  fi

  if [[ "$stashed" -eq 1 ]]; then
    echo "gup: restaurando alterações (git stash pop)…"
    git stash pop
  fi

  return $rc
}

# gcMsg: commit no padrão Conventional Commits, com pull/push automáticos.
# Uso: gcMsg <tipo> <escopo> "Mensagem" [--no-push] [--breaking]
#   --no-push : não faz push após o commit
#   --breaking: sinaliza breaking change (adiciona "!" após o escopo)
gcMsg() {
  # ── Tipos válidos e descrições (conventional commit) ──────────
  local -a valid_types=("feat" "fix" "docs" "style" "refactor"
                         "perf" "test" "build" "ci" "chore" "revert")

  local -A type_desc=(
    [feat]="Nova funcionalidade"
    [fix]="Correção de bug"
    [docs]="Apenas documentação (README, comentários, etc)"
    [style]="Formatação, whitespace - sem mudança de lógica"
    [refactor]="Refatoração de código - não é feat nem fix"
    [perf]="Melhoria de performance"
    [test]="Adição ou correção de testes"
    [build]="Sistema de build, dependências externas, tooling"
    [ci]="Configuração de CI/CD pipelines"
    [chore]="Tarefas auxiliares - não altera src nem testes"
    [revert]="Reverte um commit anterior"
  )

  # ── Helpers ───────────────────────────────────────────────────
  _usage() {
    echo "Uso: gcMsg [type] [scope] <descrição> [--breaking] [--no-push]"
    echo ""
    echo "  gcMsg                                   # modo interativo"
    echo "  gcMsg feat \"nova funcionalidade\""
    echo "  gcMsg fix  auth \"corrige token expirado\""
    echo "  gcMsg feat api \"migra para v2\" --breaking"
    echo "  gcMsg chore \"atualiza deps\" --no-push"
    echo ""
    echo "Flags:"
    echo "  --breaking   Marca como breaking change (adiciona !)"
    echo "  --no-push    Faz commit + pull, mas não faz push"
    echo ""
    echo "Tipos: ${valid_types[*]}"
  }

  _is_valid_type() {
    local t="$1"
    for v in "${valid_types[@]}"; do
      [[ "$v" == "$t" ]] && return 0
    done
    return 1
  }

  # ── Seleção interativa de tipo ────────────────────────────────
    _select_type() {
      local t=""
      if command -v fzf &>/dev/null; then
        t=$(for v in "${valid_types[@]}"; do
              printf "%s - %s\\n" "$v" "${type_desc[$v]}"
            done | fzf \
              --header="Selecione o tipo de commit (↑↓ navega, Enter confirma, Esc cancela)" \
              --height=50% \
              --reverse \
            | awk '{print $1}')
      else
        local -a options=()
        for v in "${valid_types[@]}"; do
          options+=("$v - ${type_desc[$v]}")
        done
        local i=1
        local opt
        # Print menu to stderr, one per line
        for opt in "${options[@]}"; do
          echo "$i) $opt" >&2
          ((i++))
        done
        local choice
        while true; do
          echo -n "Tipo de commit (número): " >&2
          read choice
          if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#options[@]} )); then
            # zsh: arrays são 1-indexed, então usamos $choice direto
            t=$(echo "${options[$choice]}" | awk '{print $1}')
            break
          else
            echo "Opção inválida. Por favor, tente novamente." >&2
          fi
        done
      fi
      echo "$t"
    }

  # ── Determinação do tipo ──────────────────────────────────────
  local type=""

  if [[ $# -gt 0 ]] && _is_valid_type "$1"; then
    type="$1"; shift
  else
    type=$(_select_type)
    if [[ -z "$type" ]]; then
      echo "⚠️  Nenhum tipo selecionado. Operação cancelada."
      return 1
    fi
  fi

  # ── Escopo opcional (segundo arg sem espaços e sem --) ────────
  local scope=""
  if [[ $# -gt 1 && "$1" != --* && "$1" != *" "* ]]; then
    scope="$1"; shift
  fi

  # ── Flags: --breaking e --no-push ─────────────────────────────
  local breaking=""
  local no_push=false
  local -a remaining_args=()
  for arg in "$@"; do
    case "$arg" in
      --breaking) breaking="!" ;;
      --no-push)  no_push=true ;;
      *)          remaining_args+=("$arg") ;;
    esac
  done
  local description="${remaining_args[*]}"

  # ── Prompts interativos se faltar scope/descrição ──────────────
  if [[ -z "$description" ]]; then
    if [[ -z "$scope" ]]; then
      read "scope?Escopo (opcional, Enter para pular): "
    fi
    read "description?Descrição do commit: "
    if [[ -z "$description" ]]; then
      echo "⚠️  Erro: descrição do commit não fornecida."
      return 1
    fi
  fi

  # ── Montagem da mensagem ──────────────────────────────────────
  local scope_part=""
  [[ -n "$scope" ]] && scope_part="($scope)"
  local commit_msg="${type}${scope_part}${breaking}: ${description}"

  echo "🚀 Commit: $commit_msg"
  echo "──────────────────────────────────────"

  # ── Fluxo git ─────────────────────────────────────────────────
  # 1. Stage + commit (sempre)
  git add . && git commit -m "$commit_msg" || {
    echo "❌ Falha no commit. Verifique os logs acima."
    return 1
  }

  # 2. Pull (sempre — sincroniza com remote antes de decidir push)
  echo "📥 Sincronizando (pull)..."
  git pull --no-rebase || {
    echo "❌ Falha no pull. Resolva os conflitos manualmente."
    return 1
  }

  # 3. Push (condicional)
  if [[ "$no_push" == true ]]; then
    echo "⏭️  Push ignorado (--no-push)."
  else
    echo "📤 Enviando (push)..."
    git push || {
      echo "❌ Falha no push. Verifique os logs acima."
      return 1
    }
  fi

  echo "✅ Fluxo concluído: $commit_msg"
}

# ── Git flow: feature ────────────────────────────────────────────
# gfs <nome> : abre uma feature.
#   1. guarda alterações não commitadas num stash (se houver)
#   2. roda gup (atualiza develop/master)
#   3. git flow feature start <nome> (a partir de develop)
#   4. git flow feature publish <nome> (sobe a branch para a origin)
#   5. git stash pop na feature recém-criada
gfs() {
  local name="$1"

  if [[ -z "$name" ]]; then
    echo "uso: gfs <nome-da-feature>" >&2
    return 1
  fi

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "gfs: não é um repositório git" >&2
    return 1
  fi

  if ! git config gitflow.branch.develop >/dev/null 2>&1; then
    echo "gfs: git flow não inicializado neste repo. Rode: git flow init" >&2
    return 1
  fi

  local stashed=0
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "gfs: guardando alterações não commitadas (git stash)…"
    if git stash push -u -m "gfs auto-stash: $name"; then
      stashed=1
    else
      echo "gfs: falha ao criar o stash. Abortando." >&2
      return 1
    fi
  fi

  echo "gfs: atualizando branches base…"
  gup

  echo "gfs: criando feature '$name'…"
  if ! git flow feature start "$name"; then
    echo "gfs: falha em 'git flow feature start'." >&2
    if [[ "$stashed" -eq 1 ]]; then
      echo "gfs: restaurando alterações na branch atual (git stash pop)…"
      git stash pop
    fi
    return 1
  fi

  echo "gfs: publicando a feature na origin…"
  git flow feature publish "$name" ||
    echo "gfs: falha em 'git flow feature publish' — publique manualmente depois." >&2

  if [[ "$stashed" -eq 1 ]]; then
    echo "gfs: restaurando alterações na feature (git stash pop)…"
    git stash pop
  fi

  echo "✅ feature '$name' criada e publicada."
}

# gff [nome] [--no-push] : fecha a feature atual (ou a informada).
#   Pressupõe que já está tudo commitado.
#   1. roda gup (atualiza develop/master)
#   2. git flow feature finish <nome>  (merge na develop, remove a branch)
#   3. push da develop (salvo --no-push)
gff() {
  local no_push=false name="" arg

  for arg in "$@"; do
    case "$arg" in
      --no-push) no_push=true ;;
      -*)        echo "gff: flag desconhecida: $arg" >&2; return 1 ;;
      *)         name="$arg" ;;
    esac
  done

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "gff: não é um repositório git" >&2
    return 1
  fi

  if ! git config gitflow.branch.develop >/dev/null 2>&1; then
    echo "gff: git flow não inicializado neste repo. Rode: git flow init" >&2
    return 1
  fi

  local prefix
  prefix=$(git config gitflow.prefix.feature 2>/dev/null)
  prefix=${prefix:-feature/}

  local cur
  cur=$(git symbolic-ref --short -q HEAD)

  if [[ -z "$name" ]]; then
    if [[ "$cur" == ${prefix}* ]]; then
      name=${cur#$prefix}
    else
      echo "gff: você não está numa branch de feature ($prefix*). Informe: gff <nome>" >&2
      return 1
    fi
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "gff: há alterações não commitadas. Faça commit (ex.: gcMsg) antes de fechar." >&2
    return 1
  fi

  if ! git checkout "${prefix}${name}" >/dev/null 2>&1; then
    echo "gff: branch ${prefix}${name} não encontrada." >&2
    return 1
  fi

  echo "gff: atualizando branches base…"
  gup
  git checkout "${prefix}${name}" >/dev/null 2>&1

  echo "gff: finalizando feature '$name'…"
  if ! git flow feature finish "$name"; then
    echo "gff: falha no finish. Resolva e rode 'git flow feature finish $name' de novo." >&2
    return 1
  fi

  if [[ "$no_push" == true ]]; then
    echo "gff: push de $(git config gitflow.branch.develop) ignorado (--no-push)."
  else
    echo "gff: enviando $(git config gitflow.branch.develop) (git push)…"
    git push
  fi

  echo "✅ feature '$name' finalizada e integrada em $(git config gitflow.branch.develop)."
}

# ── Git flow: release ───────────────────────────────────────────
# gfrs [--minor|--major|--patch] : abre uma release.
#   - descobre a última tag SemVer do repo e calcula a próxima
#     (por padrão incrementa a MINOR: 1.4.2 -> 1.5.0)
#   - se já existir branch de release com esse nome (local ou na origin),
#     apenas faz checkout nela
#   - senão: gup e 'git flow release start <versão>'
gfrs() {
  local bump="minor" arg

  for arg in "$@"; do
    case "$arg" in
      --major) bump="major" ;;
      --minor) bump="minor" ;;
      --patch) bump="patch" ;;
      *) echo "gfrs: argumento desconhecido: $arg (use --major|--minor|--patch)" >&2; return 1 ;;
    esac
  done

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "gfrs: não é um repositório git" >&2
    return 1
  fi
  if ! git config gitflow.branch.develop >/dev/null 2>&1; then
    echo "gfrs: git flow não inicializado neste repo. Rode: git flow init" >&2
    return 1
  fi

  echo "gfrs: buscando tags da origin…"
  git fetch --tags --prune origin >/dev/null 2>&1

  local last core MAJ MIN PAT
  last=$(git tag -l | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
  if [[ -z "$last" ]]; then
    echo "gfrs: nenhuma tag SemVer encontrada — assumindo base 0.0.0."
    core="0.0.0"
  else
    echo "gfrs: última tag: $last"
    core=${last#v}
  fi
  IFS=. read -r MAJ MIN PAT <<< "$core"

  case "$bump" in
    major) MAJ=$((MAJ + 1)); MIN=0; PAT=0 ;;
    minor) MIN=$((MIN + 1)); PAT=0 ;;
    patch) PAT=$((PAT + 1)) ;;
  esac
  local next="${MAJ}.${MIN}.${PAT}"

  local relprefix
  relprefix=$(git config gitflow.prefix.release 2>/dev/null)
  relprefix=${relprefix:-release/}
  local relbranch="${relprefix}${next}"

  echo "gfrs: próxima versão (${bump}): $next  ->  branch $relbranch"

  # ── Alterações não commitadas ────────────────────────────────
  #   - em develop: precisa commitar antes (com gcMsg) — aborta pedindo isso
  #   - em outra branch: guarda no stash e leva para a release (pop lá)
  local carried=0
  if [[ -n "$(git status --porcelain)" ]]; then
    local develop_br cur_br
    develop_br=$(git config gitflow.branch.develop)
    cur_br=$(git symbolic-ref --short -q HEAD)
    if [[ "$cur_br" == "$develop_br" ]]; then
      echo "gfrs: você está em '$develop_br' com arquivos não commitados." >&2
      echo "      Commite-os primeiro (Conventional Commits), ex.:" >&2
      echo "        gcMsg <tipo> <escopo> \"mensagem\"" >&2
      echo "      e rode 'gfrs' de novo." >&2
      return 1
    fi
    echo "gfrs: em '$cur_br' — guardando alterações não commitadas no stash…"
    if git stash push -u -m "gfrs: alterações para a release $next"; then
      carried=1
    else
      echo "gfrs: falha ao criar o stash. Abortando." >&2
      return 1
    fi
  fi

  if git show-ref --verify --quiet "refs/heads/${relbranch}"; then
    echo "gfrs: branch $relbranch já existe localmente — fazendo checkout."
    gup
    git checkout "$relbranch" || return $?
    if ! git ls-remote --exit-code --heads origin "$relbranch" >/dev/null 2>&1; then
      echo "gfrs: publicando $relbranch na origin…"
      git flow release publish "$next" ||
        echo "gfrs: falha ao publicar — publique manualmente depois." >&2
    fi
    if [[ "$carried" -eq 1 ]]; then
      echo "gfrs: restaurando alterações em $relbranch (git stash pop)…"
      git stash pop
      echo "⚠️  commite-as nesta branch: gcMsg <tipo> <escopo> \"mensagem\""
    fi
    return 0
  fi

  if git ls-remote --exit-code --heads origin "$relbranch" >/dev/null 2>&1; then
    echo "gfrs: branch $relbranch já existe na origin — fazendo checkout dela."
    gup
    git fetch origin "$relbranch" >/dev/null 2>&1
    git checkout -b "$relbranch" --track "origin/${relbranch}" || return $?
    if [[ "$carried" -eq 1 ]]; then
      echo "gfrs: restaurando alterações em $relbranch (git stash pop)…"
      git stash pop
      echo "⚠️  commite-as nesta branch: gcMsg <tipo> <escopo> \"mensagem\""
    fi
    return 0
  fi

  echo "gfrs: atualizando branches base…"
  gup

  echo "gfrs: criando release $next…"
  if ! git flow release start "$next"; then
    echo "gfrs: falha em 'git flow release start'." >&2
    if [[ "$carried" -eq 1 ]]; then
      echo "gfrs: restaurando alterações na branch atual (git stash pop)…"
      git stash pop
    fi
    return 1
  fi

  echo "gfrs: publicando a release na origin…"
  git flow release publish "$next" ||
    echo "gfrs: falha em 'git flow release publish' — publique manualmente depois." >&2

  if [[ "$carried" -eq 1 ]]; then
    echo "gfrs: restaurando alterações em $relbranch (git stash pop)…"
    git stash pop
    echo ""
    echo "⚠️  gfrs: alterações restauradas em '$relbranch' — AINDA NÃO COMMITADAS."
    echo "    commite-as nesta branch: gcMsg <tipo> <escopo> \"mensagem\""
    return 0
  fi

  echo "✅ release '$next' criada e publicada (branch $relbranch)."
}

# ── Git flow: hotfix ────────────────────────────────────────────
# gfhs : abre um hotfix.
#   - guarda alterações não commitadas num stash e restaura (pop) no hotfix
#   - gup (atualiza develop e master)
#   - calcula a próxima versão incrementando a PATCH da última tag da origin
#     (SemVer, sem prefixo "v"): 1.4.2 -> 1.4.3
#   - se a branch de hotfix já existe (local ou origin), só faz checkout + stash pop
#   - senão: 'git flow hotfix start <versão>' (a partir de master)
#   - sobe a branch para a origin com 'git flow hotfix publish <versão>'
gfhs() {
  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "gfhs: não é um repositório git" >&2
    return 1
  fi
  if ! git config gitflow.branch.develop >/dev/null 2>&1; then
    echo "gfhs: git flow não inicializado neste repo. Rode: git flow init" >&2
    return 1
  fi

  echo "gfhs: buscando tags da origin…"
  git fetch --tags --prune origin >/dev/null 2>&1

  local last core MAJ MIN PAT
  last=$(git tag -l | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
  if [[ -z "$last" ]]; then
    echo "gfhs: nenhuma tag SemVer encontrada — assumindo base 0.0.0."
    core="0.0.0"
  else
    echo "gfhs: última tag: $last"
    core=${last#v}
  fi
  IFS=. read -r MAJ MIN PAT <<< "$core"
  PAT=$((PAT + 1))
  local next="${MAJ}.${MIN}.${PAT}"

  local hfprefix
  hfprefix=$(git config gitflow.prefix.hotfix 2>/dev/null)
  hfprefix=${hfprefix:-hotfix/}
  local hfbranch="${hfprefix}${next}"

  echo "gfhs: próxima versão (patch): $next  ->  branch $hfbranch"

  local stashed=0
  if [[ -n "$(git status --porcelain)" ]]; then
    echo "gfhs: guardando alterações não commitadas (git stash)…"
    if git stash push -u -m "gfhs: alterações para o hotfix $next"; then
      stashed=1
    else
      echo "gfhs: falha ao criar o stash. Abortando." >&2
      return 1
    fi
  fi

  if git show-ref --verify --quiet "refs/heads/${hfbranch}"; then
    echo "gfhs: branch $hfbranch já existe localmente — fazendo checkout."
    gup
    git checkout "$hfbranch" || return $?
    if ! git ls-remote --exit-code --heads origin "$hfbranch" >/dev/null 2>&1; then
      echo "gfhs: publicando $hfbranch na origin…"
      git flow hotfix publish "$next" ||
        echo "gfhs: falha ao publicar — publique manualmente depois." >&2
    fi
    if [[ "$stashed" -eq 1 ]]; then
      echo "gfhs: restaurando alterações (git stash pop)…"
      git stash pop
    fi
    return 0
  fi

  if git ls-remote --exit-code --heads origin "$hfbranch" >/dev/null 2>&1; then
    echo "gfhs: branch $hfbranch já existe na origin — fazendo checkout dela."
    gup
    git fetch origin "$hfbranch" >/dev/null 2>&1
    git checkout -b "$hfbranch" --track "origin/${hfbranch}" || return $?
    if [[ "$stashed" -eq 1 ]]; then
      echo "gfhs: restaurando alterações (git stash pop)…"
      git stash pop
    fi
    return 0
  fi

  echo "gfhs: atualizando branches base…"
  gup

  echo "gfhs: criando hotfix $next…"
  if ! git flow hotfix start "$next"; then
    echo "gfhs: falha em 'git flow hotfix start'." >&2
    if [[ "$stashed" -eq 1 ]]; then
      echo "gfhs: restaurando alterações na branch atual (git stash pop)…"
      git stash pop
    fi
    return 1
  fi

  echo "gfhs: publicando o hotfix na origin…"
  git flow hotfix publish "$next" ||
    echo "gfhs: falha em 'git flow hotfix publish' — publique manualmente depois." >&2

  if [[ "$stashed" -eq 1 ]]; then
    echo "gfhs: restaurando alterações no hotfix (git stash pop)…"
    git stash pop
  fi

  echo "✅ hotfix '$next' criado e publicado (branch $hfbranch)."
}

# ── Git flow: finish (release e hotfix compartilham a lógica) ────
# _gf_finish <release|hotfix> [versão] [-f <arq> | -m <msg>] [--no-push]
#   - gup
#   - 'git flow <kind> finish' com as 3 etapas de merge:
#       telas 1 e 3 (merges em master/develop): mensagem padrão, sem editor
#       tela 2 (mensagem da tag anotada): o changelog fornecido em -f/-m,
#         ou, se nada for passado, um changelog gerado a partir dos commits
#   - conflito de merge => processo INTERROMPIDO para resolução manual
#   - ao final: checkout master + 'git push && git push --tags'
#               checkout develop + 'git push'
_gf_finish() {
  local kind="$1"; shift
  local self bprefix_default label
  case "$kind" in
    release) self="gfrf"; bprefix_default="release/"; label="Release" ;;
    hotfix)  self="gfhf"; bprefix_default="hotfix/";  label="Hotfix"  ;;
    *) echo "_gf_finish: kind inválido: $kind" >&2; return 1 ;;
  esac

  local no_push=false version="" cl_file="" cl_msg=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --no-push) no_push=true; shift ;;
      -f|--messagefile) cl_file="$2"; shift 2 ;;
      -m|--message) cl_msg="$2"; shift 2 ;;
      -*) echo "$self: flag desconhecida: $1" >&2; return 1 ;;
      *) version="$1"; shift ;;
    esac
  done

  if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "$self: não é um repositório git" >&2
    return 1
  fi
  if ! git config gitflow.branch.develop >/dev/null 2>&1; then
    echo "$self: git flow não inicializado neste repo. Rode: git flow init" >&2
    return 1
  fi

  local bprefix master develop vprefix
  bprefix=$(git config "gitflow.prefix.${kind}" 2>/dev/null); bprefix=${bprefix:-$bprefix_default}
  master=$(git config gitflow.branch.master)
  develop=$(git config gitflow.branch.develop)
  # Padrão do projeto: tags sem prefixo (major.minor.patch); só usa prefixo se
  # gitflow.prefix.versiontag estiver explicitamente configurado.
  vprefix=$(git config gitflow.prefix.versiontag 2>/dev/null)

  local cur
  cur=$(git symbolic-ref --short -q HEAD)
  if [[ -z "$version" ]]; then
    if [[ "$cur" == ${bprefix}* ]]; then
      version=${cur#$bprefix}
    else
      echo "$self: você não está numa branch de $kind ($bprefix*). Informe: $self <versão>" >&2
      return 1
    fi
  fi

  if [[ -n "$(git status --porcelain)" ]]; then
    echo "$self: há alterações não commitadas. Faça commit antes de fechar o $kind." >&2
    return 1
  fi

  if ! git checkout "${bprefix}${version}" >/dev/null 2>&1; then
    echo "$self: branch ${bprefix}${version} não encontrada." >&2
    return 1
  fi

  echo "$self: atualizando branches base…"
  gup
  git checkout "${bprefix}${version}" >/dev/null 2>&1

  # ── Mensagem da tag (tela 2 = changelog) ──────────────────────
  local tmp_cl="" finish_args=()
  if [[ -n "$cl_file" ]]; then
    if [[ ! -r "$cl_file" ]]; then
      echo "$self: arquivo de changelog não encontrado: $cl_file" >&2
      return 1
    fi
    finish_args=(-f "$cl_file")
  elif [[ -n "$cl_msg" ]]; then
    # Roteia via arquivo: o '-m' do git flow colapsa quebras de linha.
    tmp_cl=$(mktemp "${TMPDIR:-/tmp}/${self}-changelog.XXXXXX")
    printf '%s\n' "$cl_msg" > "$tmp_cl"
    finish_args=(-f "$tmp_cl")
  else
    local base
    base=$(git tag -l | grep -E '^v?[0-9]+\.[0-9]+\.[0-9]+$' | sort -V | tail -1)
    tmp_cl=$(mktemp "${TMPDIR:-/tmp}/${self}-changelog.XXXXXX")
    {
      echo "${label} ${version}"
      echo ""
      if [[ -n "$base" ]]; then
        git log --no-merges --pretty=format:'- %s' "${base}..HEAD"
      else
        git log --no-merges --pretty=format:'- %s'
      fi
      echo ""
    } > "$tmp_cl"
    finish_args=(-f "$tmp_cl")
    echo "$self: changelog gerado automaticamente a partir dos commits."
  fi

  # ── Finish: telas 1 e 3 sem editor (GIT_MERGE_AUTOEDIT=no) ────
  # Força o prefixo da tag via -c para o git flow (evita tag sem "v" ou com "vv").
  echo "$self: finalizando $kind $version (tag ${vprefix}${version})…"
  if ! GIT_MERGE_AUTOEDIT=no git -c gitflow.prefix.versiontag="$vprefix" \
       flow "$kind" finish "${finish_args[@]}" "$version"; then
    echo "" >&2
    echo "⛔ $self: o 'git flow $kind finish' falhou (provável conflito de merge)." >&2
    echo "   Resolva os conflitos manualmente, conclua o merge e rode de novo:" >&2
    echo "     git flow $kind finish ${finish_args[*]} $version" >&2
    echo "   Depois: git checkout $master && git push && git push --tags && git checkout $develop && git push" >&2
    [[ -n "$tmp_cl" ]] && echo "   (changelog salvo em: $tmp_cl)" >&2
    return 1
  fi
  [[ -n "$tmp_cl" ]] && rm -f "$tmp_cl"

  if [[ "$no_push" == true ]]; then
    echo "$self: pushes ignorados (--no-push). Lembre de enviar $master (com --tags) e $develop."
    echo "✅ $kind '$version' finalizado localmente."
    return 0
  fi

  echo "$self: enviando $master (git push && git push --tags)…"
  git checkout "$master" && git push && git push --tags || {
    echo "$self: falha ao enviar $master." >&2
    return 1
  }

  echo "$self: enviando $develop (git push)…"
  git checkout "$develop" && git push || {
    echo "$self: falha ao enviar $develop." >&2
    return 1
  }

  echo "✅ $kind $version: finish concluído, tag $version criada, $master e $develop publicados."
}

# gfrf [versão] [-f <arquivo> | -m <msg>] [--no-push] : fecha a release.
gfrf() { _gf_finish release "$@"; }

# gfhf [versão] [-f <arquivo> | -m <msg>] [--no-push] : fecha o hotfix.
gfhf() { _gf_finish hotfix "$@"; }