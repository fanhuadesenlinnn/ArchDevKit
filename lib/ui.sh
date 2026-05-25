#!/usr/bin/env bash
# 交互式输入辅助：短输入框、编号菜单和默认值处理。

ui_trim() {
  sed 's/^[[:space:]]*//;s/[[:space:]]*$//' <<<"$1"
}

ask_value_default() {
  local prompt="$1" current="$2" answer
  printf "%s [%s]: " "${prompt}" "${current}" >&2
  IFS= read -r answer || answer=""
  printf "%s" "${answer:-${current}}"
}

ask_bool_default() {
  local prompt="$1" current="$2" answer
  if [[ "${current:-0}" -eq 1 ]]; then
    printf "%s [Y/n]: " "${prompt}" >&2
    IFS= read -r answer || answer=""
    case "${answer}" in
      n|N|no|NO|No) printf "0" ;;
      *) printf "1" ;;
    esac
  else
    printf "%s [y/N]: " "${prompt}" >&2
    IFS= read -r answer || answer=""
    case "${answer}" in
      y|Y|yes|YES|Yes) printf "1" ;;
      *) printf "0" ;;
    esac
  fi
}

ask_menu_default() {
  local title="$1" current="$2"
  shift 2

  local item key desc answer default_index="" default_prompt
  local keys=()
  local descriptions=()
  local index=0

  for item in "$@"; do
    key="${item%%|*}"
    desc="${item#*|}"
    keys+=("${key}")
    descriptions+=("${desc}")
    index=$((index + 1))
    [[ "${key}" == "${current}" ]] && default_index="${index}"
  done

  while true; do
    printf '\n[%s]\n\n' "${title}" >&2
    for index in "${!keys[@]}"; do
      printf "  %2d. %-14s %s\n" "$((index + 1))" "${keys[index]}" "${descriptions[index]}" >&2
    done

    if [[ -n "${default_index}" ]]; then
      default_prompt="${default_index}"
      printf '\n默认：%s. %s\n' "${default_index}" "${current}" >&2
    else
      default_prompt="${current}"
      printf '\n默认：%s\n' "${current}" >&2
    fi
    printf "请选择%s [%s]: " "${title}" "${default_prompt}" >&2

    IFS= read -r answer || answer=""
    answer="$(ui_trim "${answer}")"
    [[ -z "${answer}" ]] && {
      printf "%s" "${current}"
      return 0
    }

    if [[ "${answer}" =~ ^[0-9]+$ ]] && (( answer >= 1 && answer <= ${#keys[@]} )); then
      printf "%s" "${keys[answer - 1]}"
      return 0
    fi

    for key in "${keys[@]}"; do
      if [[ "${answer}" == "${key}" ]]; then
        printf "%s" "${key}"
        return 0
      fi
    done

    log_warn "请输入编号或可选名称" >&2
  done
}

ask_choice_default() {
  local prompt="$1" current="$2" choices="$3" choice
  local items=()
  for choice in ${choices}; do
    items+=("${choice}|${choice}")
  done
  ask_menu_default "${prompt}" "${current}" "${items[@]}"
}
