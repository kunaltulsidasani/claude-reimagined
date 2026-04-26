#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${SCRIPT_DIR}/../lib/common.sh"

COMPONENT_ID="deps"
COMPONENT_NAME="System Dependencies"
COMPONENT_DESC="Installs required system packages: curl, git, python3, jq"
COMPONENT_CHANGES="May install packages via Homebrew (macOS) or apt-get/dnf (Linux)"

if is_skipped "${COMPONENT_ID}"; then
    record_result "${COMPONENT_ID}" "SKIPPED" "skipped via flag"
    exit 0
fi

OS="$(detect_os)"
ARCH="$(detect_arch)"

# ── Collect missing deps ───────────────────────────────────────────────────────
declare -a MISSING_HARD=()   # bootstrap cannot proceed without these
declare -a MISSING_SOFT=()   # optional, best-effort

_need_hard() {
    check_command "$1" || MISSING_HARD+=("$1")
}
_need_soft() {
    check_command "$1" || MISSING_SOFT+=("$1")
}

_need_hard curl
_need_hard git
_need_hard python3
_need_soft jq
_need_soft uv

ALL_MISSING=("${MISSING_HARD[@]+"${MISSING_HARD[@]}"}" "${MISSING_SOFT[@]+"${MISSING_SOFT[@]}"}")

if [[ "${#ALL_MISSING[@]}" -eq 0 ]]; then
    log_success "All dependencies already installed"
    record_result "${COMPONENT_ID}" "OK" "all present"
    exit 0
fi

log_info "Missing: ${ALL_MISSING[*]}"

if ! ask_confirm "${COMPONENT_ID}" "${COMPONENT_NAME}" "${COMPONENT_DESC}" "${COMPONENT_CHANGES}"; then
    if [[ "${#MISSING_HARD[@]}" -gt 0 ]]; then
        log_error "Hard dependencies missing (${MISSING_HARD[*]}). Bootstrap may fail."
    fi
    record_result "${COMPONENT_ID}" "DECLINED" "user declined"
    exit 0
fi

# ── macOS ──────────────────────────────────────────────────────────────────────
if [[ "${OS}" == "macos" ]]; then
    if ! check_command brew; then
        log_info "Homebrew not found — installing"
        if is_dry_run; then
            log_dry "Would install Homebrew"
        else
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            # add brew to PATH for Apple Silicon
            if [[ "${ARCH}" == "arm64" ]] && [[ -x /opt/homebrew/bin/brew ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
            fi
        fi
    fi

    _brew_pkgs=()
    for dep in "${ALL_MISSING[@]}"; do
        case "${dep}" in
            python3) _brew_pkgs+=(python3) ;;
            uv)      _brew_pkgs+=(uv) ;;
            *)       _brew_pkgs+=("${dep}") ;;
        esac
    done

    # deduplicate
    IFS=' ' read -ra _brew_pkgs <<< "$(printf '%s\n' "${_brew_pkgs[@]}" | sort -u | tr '\n' ' ')"

    if is_dry_run; then
        log_dry "Would run: brew install ${_brew_pkgs[*]}"
    else
        brew install "${_brew_pkgs[@]}"
    fi

# ── Linux (apt-get) ────────────────────────────────────────────────────────────
elif [[ "${OS}" == "linux" ]]; then
    if check_command apt-get; then
        _apt_pkgs=()
        for dep in "${ALL_MISSING[@]}"; do
            case "${dep}" in
                jq) _apt_pkgs+=(jq) ;;
                uv) log_info "Install uv manually: curl -LsSf https://astral.sh/uv/install.sh | sh" ;;
                *)  _apt_pkgs+=("${dep}") ;;
            esac
        done
        IFS=' ' read -ra _apt_pkgs <<< "$(printf '%s\n' "${_apt_pkgs[@]}" | sort -u | tr '\n' ' ')"

        if is_dry_run; then
            log_dry "Would run: apt-get install -y ${_apt_pkgs[*]}"
        else
            sudo apt-get update -qq
            sudo apt-get install -y "${_apt_pkgs[@]}"
        fi

    elif check_command dnf; then
        _dnf_pkgs=()
        for dep in "${ALL_MISSING[@]}"; do
            case "${dep}" in
                jq) _dnf_pkgs+=(jq) ;;
                uv) log_info "Install uv manually: curl -LsSf https://astral.sh/uv/install.sh | sh" ;;
                *)  _dnf_pkgs+=("${dep}") ;;
            esac
        done
        IFS=' ' read -ra _dnf_pkgs <<< "$(printf '%s\n' "${_dnf_pkgs[@]}" | sort -u | tr '\n' ' ')"

        if is_dry_run; then
            log_dry "Would run: dnf install -y ${_dnf_pkgs[*]}"
        else
            sudo dnf install -y "${_dnf_pkgs[@]}"
        fi

    elif check_command yum; then
        _yum_pkgs=()
        for dep in "${ALL_MISSING[@]}"; do
            case "${dep}" in
                jq) _yum_pkgs+=(jq) ;;
                uv) log_info "Install uv manually: curl -LsSf https://astral.sh/uv/install.sh | sh" ;;
                *)  _yum_pkgs+=("${dep}") ;;
            esac
        done
        IFS=' ' read -ra _yum_pkgs <<< "$(printf '%s\n' "${_yum_pkgs[@]}" | sort -u | tr '\n' ' ')"

        if is_dry_run; then
            log_dry "Would run: yum install -y ${_yum_pkgs[*]}"
        else
            sudo yum install -y "${_yum_pkgs[@]}"
        fi

    else
        log_warn "No supported package manager found (apt-get, dnf, yum). Install manually:"
        for dep in "${ALL_MISSING[@]}"; do
            log_warn "  ${dep}"
        done
        if [[ "${#MISSING_HARD[@]}" -gt 0 ]]; then
            record_result "${COMPONENT_ID}" "FAILED" "no package manager; missing: ${MISSING_HARD[*]}"
            exit 1
        fi
        record_result "${COMPONENT_ID}" "SKIPPED" "no package manager"
        exit 0
    fi
fi

# ── Verify hard deps now present ───────────────────────────────────────────────
STILL_MISSING=()
for dep in "${MISSING_HARD[@]+"${MISSING_HARD[@]}"}"; do
    check_command "${dep}" || STILL_MISSING+=("${dep}")
done

if [[ "${#STILL_MISSING[@]}" -gt 0 ]]; then
    log_error "Still missing after install: ${STILL_MISSING[*]}"
    record_result "${COMPONENT_ID}" "FAILED" "missing: ${STILL_MISSING[*]}"
    exit 1
fi

record_result "${COMPONENT_ID}" "OK" "installed: ${ALL_MISSING[*]}"
log_success "Dependencies installed"
