#!/usr/bin/env bash
set -euo pipefail

PRESETS_DIR="${HOME}/.claude/presets"
BUNDLED_PRESETS_DIR="${PRESETS_DIR}/presets"
SETTINGS_JSON_PATH="${HOME}/.claude/settings.json"
SETTINGS_LOCAL_JSON_PATH="${HOME}/.claude/settings.local.json"
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
MANAGED_SETTINGS_ROOT_KEYS=(
  "apiBaseUrl"
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
  local search_dir=""
  local preset_file=""
  local preset_key=""
  local -a preset_files=()
  declare -A seen_presets=()

  for search_dir in "$PRESETS_DIR" "$BUNDLED_PRESETS_DIR"; do
    [[ -d "$search_dir" ]] || continue

    while IFS= read -r preset_file; do
      [[ -n "$preset_file" ]] || continue
      preset_key="$(basename "$preset_file" .json)"
      preset_key="${preset_key,,}"

      if [[ -n "${seen_presets[$preset_key]+x}" ]]; then
        continue
      fi

      seen_presets["$preset_key"]=1
      preset_files+=("$preset_file")
    done < <(find "$search_dir" -maxdepth 1 -type f -name '*.json' \
      ! -name 'oauth-accounts.json' \
      ! -name 'oauth-backup.json' | sort)
  done

  printf '%s\n' "${preset_files[@]}"
}

find_preset_file_by_name() {
  local preset_name="$1"
  local preset_file=""

  while IFS= read -r preset_file; do
    if [[ "$(basename "$preset_file" .json)" == "$preset_name" ]]; then
      printf '%s\n' "$preset_file"
      return 0
    fi
  done < <(get_preset_files)

  return 1
}

get_settings_local_warning() {
  if [[ ! -f "$SETTINGS_LOCAL_JSON_PATH" ]]; then
    return 0
  fi

  node - "$SETTINGS_LOCAL_JSON_PATH" <<'NODE'
const fs = require('fs');

const filePath = process.argv[2];

try {
  const settings = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  if (!settings || Array.isArray(settings) || typeof settings !== 'object') {
    console.log(`'${filePath}' precisa conter um objeto JSON na raiz. O default persistido sera ignorado ate ele ser corrigido.`);
  }
} catch (_) {
  console.log(`Arquivo invalido em '${filePath}'. O default persistido sera ignorado ate ele ser corrigido.`);
}
NODE
}

get_settings_leak_keys() {
  if [[ ! -f "$SETTINGS_JSON_PATH" ]]; then
    return 0
  fi

  node - "$SETTINGS_JSON_PATH" "${MANAGED_SETTINGS_ROOT_KEYS[@]}" <<'NODE'
const fs = require('fs');

try {
  const settings = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const managedRootKeys = process.argv.slice(3);
  const env = settings.env && typeof settings.env === 'object' ? settings.env : {};
  for (const key of managedRootKeys) {
    if (settings[key] !== undefined && settings[key] !== null) {
      console.log(key);
    }
  }
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

emit_settings_local_managed_env_lines() {
  node - "$SETTINGS_LOCAL_JSON_PATH" "${CLAUDE_ENV_VARS[@]}" <<'NODE'
const fs = require('fs');

const filePath = process.argv[2];
const managedKeys = process.argv.slice(3);

try {
  if (!fs.existsSync(filePath)) {
    process.exit(0);
  }

  const settings = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  const env = settings && settings.env && typeof settings.env === 'object' ? settings.env : {};
  for (const key of managedKeys) {
    if (env[key] !== undefined && env[key] !== null) {
      const value = String(env[key]).trim();
      if (value) {
        console.log(`${key}\t${value}`);
      }
    }
  }
} catch (error) {
  process.exit(0);
}
NODE
}

emit_normalized_env_json() {
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

    if (typeof value === 'string') {
      const valueText = value.trim();
      if (!valueText) {
        continue;
      }
      normalized[key] = valueText;
      continue;
    }

    normalized[key] = value;
  }

  const mainModel = typeof normalized.ANTHROPIC_MODEL === 'string'
    ? normalized.ANTHROPIC_MODEL.trim()
    : '';

  if (mainModel) {
    for (const slotName of modelSlots) {
      if (normalized[slotName] === undefined || normalized[slotName] === null || normalized[slotName] === '') {
        normalized[slotName] = mainModel;
      }
    }
  }

  process.stdout.write(JSON.stringify(normalized));
} catch (_) {
  process.exit(1);
}
NODE
}

write_settings_local_managed_env() {
  local env_json="${1-}"
  local env_json_b64=""

  if [[ -z "$env_json" ]]; then
    env_json='{}'
  fi

  env_json_b64="$(printf '%s' "$env_json" | base64 | tr -d '\r\n')"

  node - "$SETTINGS_LOCAL_JSON_PATH" "${CLAUDE_ENV_VARS[@]}" -- "$env_json_b64" <<'NODE'
const fs = require('fs');
const path = require('path');

const filePath = process.argv[2];
const managedKeys = [];
let index = 3;
while (index < process.argv.length && process.argv[index] !== '--') {
  managedKeys.push(process.argv[index]);
  index += 1;
}
index += 1;
const envJsonBase64 = process.argv[index] || '';
let managedEnv = {};

try {
  const envJson = envJsonBase64
    ? Buffer.from(envJsonBase64, 'base64').toString('utf8')
    : '{}';
  managedEnv = JSON.parse(envJson);
} catch (error) {
  console.error(`Invalid managed env JSON: ${error.message}`);
  process.exit(1);
}

let settings = {};
if (fs.existsSync(filePath)) {
  try {
    settings = JSON.parse(fs.readFileSync(filePath, 'utf8'));
  } catch (error) {
    console.error(`Could not parse '${filePath}': ${error.message}`);
    process.exit(1);
  }
}

if (!settings || Array.isArray(settings) || typeof settings !== 'object') {
  console.error(`'${filePath}' must contain a JSON object at the root.`);
  process.exit(1);
}

delete settings.apiBaseUrl;

let env = settings.env;
if (env === undefined || env === null) {
  env = {};
} else if (Array.isArray(env) || typeof env !== 'object') {
  console.error(`'env' in '${filePath}' must be a JSON object.`);
  process.exit(1);
}

for (const key of managedKeys) {
  delete env[key];
}

for (const [key, value] of Object.entries(managedEnv)) {
  env[key] = value;
}

if (Object.keys(env).length === 0) {
  delete settings.env;
} else {
  settings.env = env;
}

if (Object.keys(settings).length === 0) {
  if (fs.existsSync(filePath)) {
    fs.unlinkSync(filePath);
  }
  process.exit(0);
}

fs.mkdirSync(path.dirname(filePath), { recursive: true });
fs.writeFileSync(filePath, `${JSON.stringify(settings, null, 2)}\n`, 'utf8');
NODE
}

declare -A PRESET_ENV=()
declare -A SESSION_ENV=()
declare -A DEFAULT_ENV=()
PRESET_DISPLAY_NAME=""
PRESET_DESCRIPTION=""
PRESET_ENV_JSON="{}"

load_preset() {
  local preset_file="$1"
  local summary=""

  PRESET_ENV=()
  PRESET_DISPLAY_NAME=""
  PRESET_DESCRIPTION=""
  PRESET_ENV_JSON="{}"

  if ! summary="$(emit_preset_summary "$preset_file")"; then
    return 1
  fi

  if ! PRESET_ENV_JSON="$(emit_normalized_env_json "$preset_file")"; then
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

load_session_env() {
  local key=""
  SESSION_ENV=()

  for key in "${CLAUDE_ENV_VARS[@]}"; do
    if [[ -n "${!key-}" ]]; then
      SESSION_ENV["$key"]="${!key}"
    fi
  done
}

load_default_env() {
  local key=""
  local value=""
  DEFAULT_ENV=()

  while IFS=$'\t' read -r key value; do
    if [[ -z "$key" ]]; then
      continue
    fi
    DEFAULT_ENV["$key"]="$value"
  done < <(emit_settings_local_managed_env_lines)
}

clear_claude_env_vars() {
  local var_name=""
  for var_name in "${CLAUDE_ENV_VARS[@]}"; do
    unset "$var_name" 2>/dev/null || true
  done
}

env_map_matches_loaded_preset() {
  local map_name="$1"
  local -n actual_map="$map_name"
  local key=""

  if [[ "${#PRESET_ENV[@]}" -ne "${#actual_map[@]}" ]]; then
    return 1
  fi

  for key in "${!PRESET_ENV[@]}"; do
    if [[ "${actual_map[$key]-}" != "${PRESET_ENV[$key]}" ]]; then
      return 1
    fi
  done

  return 0
}

test_is_anthropic_session() {
  load_session_env
  [[ "${#SESSION_ENV[@]}" -eq 0 ]]
}

get_active_session_preset() {
  local preset_file=""

  load_session_env
  if [[ "${#SESSION_ENV[@]}" -eq 0 ]]; then
    print_line "anthropic"
    return 0
  fi

  while IFS= read -r preset_file; do
    if ! load_preset "$preset_file"; then
      continue
    fi

    if env_map_matches_loaded_preset SESSION_ENV; then
      basename "$preset_file" .json
      return 0
    fi
  done < <(get_preset_files)

  print_line "custom-session"
}

get_default_preset() {
  local preset_file=""

  load_default_env
  if [[ "${#DEFAULT_ENV[@]}" -eq 0 ]]; then
    print_line "anthropic"
    return 0
  fi

  while IFS= read -r preset_file; do
    if ! load_preset "$preset_file"; then
      continue
    fi

    if env_map_matches_loaded_preset DEFAULT_ENV; then
      basename "$preset_file" .json
      return 0
    fi
  done < <(get_preset_files)

  print_line "custom-default"
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

show_settings_local_warning() {
  local warning_message=""
  warning_message="$(get_settings_local_warning || true)"
  if [[ -z "$warning_message" ]]; then
    return 0
  fi

  print_line ""
  print_line "  [WARN] ~/.claude/settings.local.json esta invalido."
  while IFS= read -r line; do
    [[ -n "$line" ]] || continue
    print_line "         $line"
  done <<< "$warning_message"
}

get_marker_text() {
  local name="$1"
  local session_preset="$2"
  local default_preset="$3"
  local markers=()

  if [[ "$name" == "$session_preset" ]]; then
    markers+=("session")
  fi
  if [[ "$name" == "$default_preset" ]]; then
    markers+=("default")
  fi

  if [[ "${#markers[@]}" -eq 0 ]]; then
    return 0
  fi

  printf ' [%s]' "$(IFS=', '; echo "${markers[*]}")"
}

show_preset_list() {
  local session_preset=""
  local default_preset=""
  local preset_file=""
  local preset_name=""
  local summary=""
  local description=""
  local marker=""

  session_preset="$(get_active_session_preset)"
  default_preset="$(get_default_preset)"

  print_line ""
  print_line "  Presets disponiveis:"
  show_settings_leak_warning
  show_settings_local_warning
  print_line ""

  marker="$(get_marker_text "anthropic" "$session_preset" "$default_preset")"
  print_line "    anthropic$marker - Claude oficial (OAuth limpo)"

  while IFS= read -r preset_file; do
    preset_name="$(basename "$preset_file" .json)"
    summary="$(emit_preset_summary "$preset_file" 2>/dev/null || true)"
    description=""
    if [[ "$summary" == *$'\t'* ]]; then
      description="${summary#*$'\t'}"
    fi
    marker="$(get_marker_text "$preset_name" "$session_preset" "$default_preset")"
    print_line "    $preset_name$marker${description:+ - $description}"
  done < <(get_preset_files)

  if [[ "$session_preset" == "custom-session" ]]; then
    print_line "    custom-session [session]"
  fi

  if [[ "$default_preset" == "custom-default" ]]; then
    print_line "    custom-default [default]"
  fi

  print_line ""
}

declare -a MENU_NAMES=()
declare -a MENU_DESCRIPTIONS=()

build_menu_options() {
  local preset_file=""
  local preset_name=""
  local summary=""
  local description=""

  MENU_NAMES=("anthropic")
  MENU_DESCRIPTIONS=("Claude oficial (OAuth limpo)")

  while IFS= read -r preset_file; do
    preset_name="$(basename "$preset_file" .json)"
    summary="$(emit_preset_summary "$preset_file" 2>/dev/null || true)"
    description=""
    if [[ "$summary" == *$'\t'* ]]; then
      description="${summary#*$'\t'}"
    fi

    MENU_NAMES+=("$preset_name")
    MENU_DESCRIPTIONS+=("$description")
  done < <(get_preset_files)
}

show_preset_menu() {
  local session_preset=""
  local default_preset=""
  local choice=""
  local line=""
  local index=0
  local marker=""

  session_preset="$(get_active_session_preset)"
  default_preset="$(get_default_preset)"
  build_menu_options

  while true; do
    print_line ""
    print_line "  cmodel - escolha um preset:"
    show_settings_leak_warning
    show_settings_local_warning
    print_line ""

    for ((index = 0; index < ${#MENU_NAMES[@]}; index++)); do
      marker="$(get_marker_text "${MENU_NAMES[$index]}" "$session_preset" "$default_preset")"
      line="    [$((index + 1))] ${MENU_NAMES[$index]}$marker"
      if [[ -n "${MENU_DESCRIPTIONS[$index]}" ]]; then
        line+=" - ${MENU_DESCRIPTIONS[$index]}"
      fi
      print_line "$line"
    done

    print_line ""
    read -r -p "  Escolha um numero ou q para sair: " choice || return 1

    case "$choice" in
      q|Q|"")
        return 1
        ;;
      *[!0-9]*)
        print_line ""
        print_line "  [X] Opcao invalida."
        ;;
      *)
        if (( choice >= 1 && choice <= ${#MENU_NAMES[@]} )); then
          PRESET_NAME="${MENU_NAMES[$((choice - 1))]}"
          return 0
        fi

        print_line ""
        print_line "  [X] Opcao invalida."
        ;;
    esac
  done
}

show_session_conflict_warning() {
  local current_preset="$1"
  local new_preset="$2"

  print_line ""
  print_line "  [WARN] Ja existe sessao ativa: '$current_preset'"
  print_line "         Trocando para '$new_preset' nesta sessao."
  print_line ""
}

show_usage() {
  print_line ""
  print_line "  cmodel <preset> [args...]"
  print_line "  cmodel <preset> -ApplyOnly"
  print_line "  cmodel <preset> -SetDefault"
  print_line "  cmodel <preset> -SetDefault -ApplyOnly"
  print_line "  cmodel anthropic"
  print_line "  cmodel -List"
  print_line "  cmodel -Status"
  print_line ""
}

launch_claude() {
  local selected_preset="$1"
  local persist_default="$2"
  shift 2
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

  if [[ "$persist_default" -eq 0 && "$selected_preset" != "anthropic" ]]; then
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
SET_DEFAULT=0
FORWARD_CLAUDE_ARGS=0
SELECTED_FROM_MENU=0
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
    -SetDefault|--set-default|-Default|--default)
      SET_DEFAULT=1
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
  print_line "  Sessao atual: $(get_active_session_preset)"
  print_line "  Padrao VS Code: $(get_default_preset)"
  print_line "  Arquivo monitorado pela extensao: $SETTINGS_LOCAL_JSON_PATH"
  show_settings_leak_warning
  show_settings_local_warning
  print_line ""
  script_exit 0
fi

if [[ -z "$PRESET_NAME" ]]; then
  if [[ -t 0 && -t 1 ]]; then
    if ! show_preset_menu; then
      print_line ""
      print_line "  [i] Cancelado."
      print_line ""
      script_exit 0
    fi
    SELECTED_FROM_MENU=1
  else
    show_preset_list
    show_usage
    script_exit 0
  fi
fi

if [[ "$SELECTED_FROM_MENU" -eq 1 && "$APPLY_ONLY" -eq 0 && "$SET_DEFAULT" -eq 0 ]]; then
  active_session="$(get_active_session_preset)"
  if [[ -n "$active_session" && "$active_session" != "anthropic" && "$active_session" != "custom-session" && "$active_session" != "$PRESET_NAME" ]]; then
    show_session_conflict_warning "$active_session" "$PRESET_NAME"
  fi
fi

clear_claude_env_vars

if [[ "$PRESET_NAME" == "anthropic" ]]; then
  PRESET_DISPLAY_NAME="anthropic (OAuth padrao)"
  PRESET_DESCRIPTION="Claude oficial (OAuth limpo)"
  PRESET_ENV=()
else
  PRESET_FILE="$(find_preset_file_by_name "$PRESET_NAME" || true)"
  if [[ -z "$PRESET_FILE" || ! -f "$PRESET_FILE" ]]; then
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

if [[ "$SET_DEFAULT" -eq 1 ]]; then
  env_json='{}'
  if [[ "$PRESET_NAME" != "anthropic" ]]; then
    env_json="$PRESET_ENV_JSON"
  fi

  if ! write_settings_local_managed_env "$env_json"; then
    print_line ""
    print_line "  [X] Nao foi possivel atualizar $SETTINGS_LOCAL_JSON_PATH."
    print_line ""
    script_exit 1
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
if [[ "$SET_DEFAULT" -eq 1 ]]; then
  print_line "  [i] Padrao persistido em: $SETTINGS_LOCAL_JSON_PATH"
fi
show_settings_leak_warning
show_settings_local_warning

if [[ "$APPLY_ONLY" -eq 1 ]]; then
  if [[ "$SET_DEFAULT" -eq 1 ]]; then
    print_line ""
    if [[ "$PRESET_NAME" == "anthropic" ]]; then
      print_line "  [i] Padrao limpo. O VS Code Claude volta ao OAuth padrao."
    else
      print_line "  [i] Preset salvo como padrao. O VS Code Claude usara esse provider."
    fi
    print_line ""
    script_exit 0
  fi

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

launch_claude "$PRESET_NAME" "$SET_DEFAULT" "${CLAUDE_ARGS[@]}"
exit_code=$?

if [[ "$SET_DEFAULT" -eq 0 ]]; then
  clear_claude_env_vars

  print_line ""
  print_line "  [i] Sessao limpa apos fechar o Claude."
fi

script_exit "$exit_code"
