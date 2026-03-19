#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PRESETS_DIR="$SCRIPT_DIR"
SETTINGS_JSON_PATH="${HOME}/.claude/settings.json"
CLAUDE_ENV_VARS=(
  "ANTHROPIC_BASE_URL"
  "ANTHROPIC_API_KEY"
  "ANTHROPIC_AUTH_TOKEN"
  "ANTHROPIC_MODEL"
  "ANTHROPIC_DEFAULT_SONNET_MODEL"
  "ANTHROPIC_DEFAULT_OPUS_MODEL"
  "ANTHROPIC_DEFAULT_HAIKU_MODEL"
  "ANTHROPIC_SMALL_FAST_MODEL"
  "API_TIMEOUT_MS"
  "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC"
)
MODEL_SLOT_ENV_VARS=(
  "ANTHROPIC_DEFAULT_SONNET_MODEL"
  "ANTHROPIC_DEFAULT_OPUS_MODEL"
  "ANTHROPIC_DEFAULT_HAIKU_MODEL"
  "ANTHROPIC_SMALL_FAST_MODEL"
)

IS_SOURCED=0
if [[ "${BASH_SOURCE[0]}" != "$0" ]]; then
  IS_SOURCED=1
fi

script_exit() {
  local code="${1:-0}"
  if [[ "$IS_SOURCED" -eq 1 ]]; then
    return "$code"
  fi

  exit "$code"
}

print_line() {
  printf '%s\n' "$1"
}

get_preset_files() {
  find "$PRESETS_DIR" -maxdepth 1 -type f -name '*.json' \
    ! -name 'oauth-accounts.json' \
    ! -name 'oauth-backup.json' | sort
}

get_settings_leak_keys() {
  if [[ ! -f "$SETTINGS_JSON_PATH" ]]; then
    return 0
  fi

  node - "$SETTINGS_JSON_PATH" <<'NODE'
const fs = require('fs');

try {
  const settings = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const env = settings.env && typeof settings.env === 'object' ? settings.env : {};
  for (const key of Object.keys(env)) {
    if (key.startsWith('ANTHROPIC_')) {
      console.log(key);
    }
  }
} catch (_) {
  process.exit(0);
}
NODE
}

emit_preset_summary() {
  node - "$1" <<'NODE'
const fs = require('fs');

try {
  const preset = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const name = preset && preset._preset && preset._preset.name ? String(preset._preset.name) : '';
  const description = preset && preset._preset && preset._preset.description ? String(preset._preset.description) : '';
  console.log(`${name}\t${description}`);
} catch (_) {
  process.exit(1);
}
NODE
}

emit_normalized_env_lines() {
  node - "$1" <<'NODE'
const fs = require('fs');

const modelSlots = [
  'ANTHROPIC_DEFAULT_SONNET_MODEL',
  'ANTHROPIC_DEFAULT_OPUS_MODEL',
  'ANTHROPIC_DEFAULT_HAIKU_MODEL',
  'ANTHROPIC_SMALL_FAST_MODEL',
];

try {
  const preset = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const env = preset && preset.env && typeof preset.env === 'object' ? preset.env : {};
  const normalized = {};

  for (const [key, value] of Object.entries(env)) {
    if (value === null || value === undefined) {
      continue;
    }

    const valueText = String(value).trim();
    if (!valueText) {
      continue;
    }

    normalized[key] = valueText;
  }

  const mainModel = normalized.ANTHROPIC_MODEL;
  if (mainModel) {
    for (const slotName of modelSlots) {
      if (!normalized[slotName]) {
        normalized[slotName] = mainModel;
      }
    }
  }

  for (const [key, value] of Object.entries(normalized)) {
    console.log(`${key}\t${value}`);
  }
} catch (_) {
  process.exit(1);
}
NODE
}

declare -A PRESET_ENV=()
PRESET_DISPLAY_NAME=""
PRESET_DESCRIPTION=""

load_preset() {
  local preset_file="$1"
  local summary=""

  PRESET_ENV=()
  PRESET_DISPLAY_NAME=""
  PRESET_DESCRIPTION=""

  if ! summary="$(emit_preset_summary "$preset_file")"; then
    return 1
  fi

  PRESET_DISPLAY_NAME="${summary%%$'\t'*}"
  if [[ "$summary" == *$'\t'* ]]; then
    PRESET_DESCRIPTION="${summary#*$'\t'}"
  fi

  while IFS=$'\t' read -r key value; do
    if [[ -z "$key" ]]; then
      continue
    fi

    PRESET_ENV["$key"]="$value"
  done < <(emit_normalized_env_lines "$preset_file")

  return 0
}

clear_claude_env_vars() {
  local var_name=""
  for var_name in "${CLAUDE_ENV_VARS[@]}"; do
    unset "$var_name" 2>/dev/null || true
  done
}

test_is_anthropic_session() {
  local var_name=""
  for var_name in "${CLAUDE_ENV_VARS[@]}"; do
    local value="${!var_name-}"
    if [[ -n "${value}" ]]; then
      return 1
    fi
  done

  return 0
}

preset_matches_session() {
  local preset_file="$1"
  local key=""

  if ! load_preset "$preset_file"; then
    return 1
  fi

  if [[ "${#PRESET_ENV[@]}" -eq 0 ]]; then
    return 1
  fi

  for key in "${!PRESET_ENV[@]}"; do
    if [[ "${!key-}" != "${PRESET_ENV[$key]}" ]]; then
      return 1
    fi
  done

  return 0
}

get_active_preset() {
  local preset_file=""

  if test_is_anthropic_session; then
    print_line "anthropic"
    return 0
  fi

  while IFS= read -r preset_file; do
    if preset_matches_session "$preset_file"; then
      basename "$preset_file" .json
      return 0
    fi
  done < <(get_preset_files)

  print_line "custom-session"
}

show_settings_leak_warning() {
  local leak_keys=""
  leak_keys="$(get_settings_leak_keys || true)"
  if [[ -z "$leak_keys" ]]; then
    return 0
  fi

  print_line ""
  print_line "  [WARN] ~/.claude/settings.json ainda injeta provider global:"
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    print_line "         $key"
  done <<< "$leak_keys"
  print_line "         Isso pode misturar provider/modelo fora do preset."
}

show_preset_list() {
  local active_preset
  local preset_file=""
  local preset_name=""
  local summary=""
  local display_name=""
  local description=""

  active_preset="$(get_active_preset)"

  print_line ""
  print_line "  Presets disponiveis:"
  show_settings_leak_warning
  print_line ""

  if [[ "$active_preset" == "anthropic" ]]; then
    print_line "    anthropic [active] - Claude oficial (OAuth limpo)"
  else
    print_line "    anthropic - Claude oficial (OAuth limpo)"
  fi

  while IFS= read -r preset_file; do
    preset_name="$(basename "$preset_file" .json)"
    summary="$(emit_preset_summary "$preset_file" 2>/dev/null || true)"
    display_name="${summary%%$'\t'*}"
    description=""
    if [[ "$summary" == *$'\t'* ]]; then
      description="${summary#*$'\t'}"
    fi

    if [[ -n "$description" ]]; then
      description=" - $description"
    fi

    if [[ "$active_preset" == "$preset_name" ]]; then
      print_line "    $preset_name [active]$description"
    else
      print_line "    $preset_name$description"
    fi
  done < <(get_preset_files)

  if [[ "$active_preset" == "custom-session" ]]; then
    print_line "    custom-session [active]"
  fi

  print_line ""
}

show_usage() {
  print_line ""
  print_line "  cmodel <preset> [args...]"
  print_line "  cmodel <preset> -ApplyOnly"
  print_line "  cmodel anthropic"
  print_line "  cmodel -List"
  print_line "  cmodel -Status"
  print_line ""
}

launch_claude() {
  local selected_preset="$1"
  shift
  local -a claude_args=("$@")
  local -a env_cmd=(env)
  local key=""

  if ! command -v claude >/dev/null 2>&1; then
    print_line ""
    print_line "  [X] Comando 'claude' nao encontrado no PATH."
    print_line ""
    return 127
  fi

  print_line ""
  print_line "  [OK] Abrindo Claude Code..."
  print_line ""

  for key in "${CLAUDE_ENV_VARS[@]}"; do
    env_cmd+=("-u" "$key")
  done

  if [[ "$selected_preset" != "anthropic" ]]; then
    for key in "${!PRESET_ENV[@]}"; do
      env_cmd+=("$key=${PRESET_ENV[$key]}")
    done
  fi

  "${env_cmd[@]}" claude "${claude_args[@]}"
}

PRESET_NAME=""
LIST_MODE=0
STATUS_MODE=0
APPLY_ONLY=0
FORWARD_CLAUDE_ARGS=0
CLAUDE_ARGS=()

for arg in "$@"; do
  if [[ "$FORWARD_CLAUDE_ARGS" -eq 1 ]]; then
    CLAUDE_ARGS+=("$arg")
    continue
  fi

  case "$arg" in
    --)
      FORWARD_CLAUDE_ARGS=1
      ;;
    -List|--list)
      LIST_MODE=1
      ;;
    -Status|--status)
      STATUS_MODE=1
      ;;
    -ApplyOnly|--apply-only|-NoLaunch|--no-launch)
      APPLY_ONLY=1
      ;;
    *)
      if [[ -z "$PRESET_NAME" ]]; then
        PRESET_NAME="$arg"
      else
        CLAUDE_ARGS+=("$arg")
      fi
      ;;
  esac
done

if [[ "$LIST_MODE" -eq 1 ]]; then
  show_preset_list
  script_exit 0
fi

if [[ "$STATUS_MODE" -eq 1 ]]; then
  print_line ""
  print_line "  Preset ativo: $(get_active_preset)"
  show_settings_leak_warning
  print_line ""
  script_exit 0
fi

if [[ -z "$PRESET_NAME" ]]; then
  show_preset_list
  show_usage
  script_exit 0
fi

clear_claude_env_vars

if [[ "$PRESET_NAME" == "anthropic" ]]; then
  PRESET_DISPLAY_NAME="anthropic (OAuth padrao)"
  PRESET_DESCRIPTION="Claude oficial (OAuth limpo)"
else
  PRESET_FILE="$PRESETS_DIR/${PRESET_NAME}.json"
  if [[ ! -f "$PRESET_FILE" ]]; then
    print_line ""
    print_line "  [X] Preset '$PRESET_NAME' nao encontrado ou invalido."
    print_line "  [i] Rode: cmodel -List"
    print_line ""
    script_exit 1
  fi

  if ! load_preset "$PRESET_FILE"; then
    print_line ""
    print_line "  [X] Preset '$PRESET_NAME' nao encontrado ou invalido."
    print_line ""
    script_exit 1
  fi

  if [[ -z "$PRESET_DISPLAY_NAME" ]]; then
    PRESET_DISPLAY_NAME="$PRESET_NAME"
  else
    PRESET_DISPLAY_NAME="$PRESET_NAME ($PRESET_DISPLAY_NAME)"
  fi
fi

print_line ""
print_line "  [OK] $PRESET_DISPLAY_NAME"
if [[ -n "$PRESET_DESCRIPTION" ]]; then
  print_line "  [i] $PRESET_DESCRIPTION"
fi
if [[ -n "${PRESET_ENV[ANTHROPIC_BASE_URL]-}" ]]; then
  print_line "  [i] Base URL: ${PRESET_ENV[ANTHROPIC_BASE_URL]}"
fi
if [[ -n "${PRESET_ENV[ANTHROPIC_MODEL]-}" ]]; then
  print_line "  [i] Model:    ${PRESET_ENV[ANTHROPIC_MODEL]}"
fi
show_settings_leak_warning

if [[ "$APPLY_ONLY" -eq 1 ]]; then
  if [[ "$IS_SOURCED" -ne 1 ]]; then
    print_line ""
    print_line "  [X] -ApplyOnly precisa rodar via funcao shell: cmodel <preset> -ApplyOnly"
    print_line ""
    script_exit 1
  fi

  if [[ "$PRESET_NAME" == "anthropic" ]]; then
    print_line ""
    print_line "  [i] Sessao limpa. Claude volta ao OAuth padrao neste terminal."
    print_line ""
    script_exit 0
  fi

  for key in "${!PRESET_ENV[@]}"; do
    export "$key=${PRESET_ENV[$key]}"
  done

  print_line ""
  print_line "  [i] Preset aplicado apenas nesta sessao. Rode 'claude' neste terminal."
  print_line ""
  script_exit 0
fi

launch_claude "$PRESET_NAME" "${CLAUDE_ARGS[@]}"
exit_code=$?

clear_claude_env_vars

print_line ""
print_line "  [i] Sessao limpa apos fechar o Claude."

script_exit "$exit_code"
