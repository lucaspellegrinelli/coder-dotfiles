#!/bin/bash

# Install script to be used on Coder workspaces

CODE_SERVER_BINARY="/tmp/code-server/bin/code-server"
SETTINGS_FILE="$HOME/.local/share/code-server/User/settings.json"
KEYBINDINGS_FILE="$HOME/.local/share/code-server/User/keybindings.json"
CONTINUE_CONFIG_FILE="$HOME/.continue/config.json"
MAX_RETRIES=30
RETRY_INTERVAL=2

ensure_jq_installed() {
    if ! command -v jq &> /dev/null; then
        echo "jq not found. Aborting dotfiles installation..."
        exit 1
    fi
}

wait_for_code_server() {
    echo "Waiting for code-server binary to be ready..."
    for ((i=1; i<=MAX_RETRIES; i++)); do
        if [ -x "$CODE_SERVER_BINARY" ]; then
            echo "code-server binary is ready."
            return 0
        fi
        sleep "$RETRY_INTERVAL"
    done
    echo "Error: code-server binary not found or not executable after $((MAX_RETRIES * RETRY_INTERVAL)) seconds."
    exit 1
}

merge_json() {
    local existing_file=$1
    local new_file=$2

    # If there is no existing file or it's empty, simply copy the new file
    if [ ! -s "$existing_file" ]; then
        cp "$new_file" "$existing_file"
        return 0
    fi

    local json_type
    json_type=$(jq -r 'type' "$existing_file" 2>/dev/null)

    if [ "$json_type" = "array" ]; then
        # Merge JSON arrays by concatenating them and removing duplicates.
        if jq -s 'add | unique_by(.key)' "$existing_file" "$new_file" > "${existing_file}.tmp"; then
            mv "${existing_file}.tmp" "$existing_file"
        else
            echo "Error: Failed to merge JSON arrays." >&2
            echo "Contents of $existing_file:" >&2
            cat "$existing_file" >&2
            echo "" >&2
            echo "Contents of $new_file:" >&2
            cat "$new_file" >&2
            return 1
        fi
    else
        # For JSON objects, merge them using the '*' operator.
        if jq -s '.[0] * .[1]' "$existing_file" "$new_file" > "${existing_file}.tmp"; then
            mv "${existing_file}.tmp" "$existing_file"
        else
            echo "Error: Failed to merge JSON objects." >&2
            echo "Contents of $existing_file:" >&2
            cat "$existing_file" >&2
            echo "" >&2
            echo "Contents of $new_file:" >&2
            cat "$new_file" >&2
            return 1
        fi
    fi
}

install_extensions() {
    "$CODE_SERVER_BINARY" --install-extension vscodevim.vim
    "$CODE_SERVER_BINARY" --install-extension catppuccin.catppuccin-vsc
    "$CODE_SERVER_BINARY" --install-extension Continue.continue
}

setup_user_files() {
    echo "Setting up user files..."
    mkdir -p "$(dirname "$SETTINGS_FILE")"
    merge_json "$SETTINGS_FILE" "settings/user_settings.json"
    merge_json "$KEYBINDINGS_FILE" "settings/keybindings.json"
}

setup_continue_config() {
    echo "Setting Continue config..."

    if [ -z "$MIXTRAL_CODESTRA_API_KEY" ]; then
        echo "Error: MIXTRAL_CODESTRA_API_KEY environment variable is not set or empty." >&2
        exit 1
    fi

    mkdir -p "$(dirname "$CONTINUE_CONFIG_FILE")"

    sed "s|\"\\[API_KEY\\]\"|\"${MIXTRAL_CODESTRAL_API_KEY//\//\\/}\"|g" "settings/continue_config.json" > "$CONTINUE_CONFIG_FILE"
}

# Main Script

ensure_jq_installed
wait_for_code_server
setup_user_files
install_extensions
setup_continue_config