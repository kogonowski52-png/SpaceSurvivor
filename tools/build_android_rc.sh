#!/usr/bin/env bash
set -euo pipefail

project="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
engine="${GODOT_BIN:-godot}"
variant="${1:-}"
output="${2:-}"
if [[ -z "$output" || "$#" != 2 ]]; then
    printf 'Usage: %s debug output.apk | play output.aab | play-license output.aab | qa-bundle output-unsigned.aab\n' "$0" >&2
    exit 64
fi
output="$(realpath -m -- "$output")"
case "$variant" in
    debug)
        [[ "$output" == *.apk ]]
        export GALAXY_PLAY_MODE=test
        unset GALAXY_ENABLE_LICENSE_CHECKOUT GALAXY_ENABLE_DRAFT_CATALOG GALAXY_PURCHASE_SERVER
        preset=Android
        mode=--export-debug
        ;;
    qa-bundle)
        [[ "$output" == *-unsigned.aab ]]
        export GALAXY_PLAY_MODE=test
        unset GALAXY_ENABLE_LICENSE_CHECKOUT GALAXY_ENABLE_DRAFT_CATALOG GALAXY_PURCHASE_SERVER
        unset GALAXY_ADMOB_APP_ID GALAXY_PRIVACY_POLICY_URL GALAXY_UMP_DEBUG_DEVICE GALAXY_UMP_DEBUG_GEOGRAPHY
        unset GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD
        preset='Android Play Unsigned QA AAB'
        mode=--export-release
        ;;
    play|play-license)
        [[ "$output" == *.aab ]]
        export GALAXY_PLAY_MODE=test
        for setting in GODOT_ANDROID_KEYSTORE_RELEASE_PATH GODOT_ANDROID_KEYSTORE_RELEASE_USER \
            GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD GALAXY_PRIVACY_POLICY_URL; do
            if [[ -z "${!setting:-}" ]]; then
                printf 'Internal test export requires %s.\n' "$setting" >&2
                exit 65
            fi
        done
        if [[ ! -r "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" ]]; then
            printf 'Configure the owner upload key.\n' >&2
            exit 65
        fi
        if [[ "$variant" == play-license ]]; then
            if [[ -z "${GALAXY_PURCHASE_SERVER:-}" || "${GALAXY_ENABLE_LICENSE_CHECKOUT:-}" != 1 ]]; then
                printf 'License-test AAB requires its HTTPS wallet and explicit license-test flag.\n' >&2
                exit 65
            fi
        else
            unset GALAXY_ENABLE_LICENSE_CHECKOUT GALAXY_ENABLE_DRAFT_CATALOG
        fi
        signing_path="$(realpath -- "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH")"
        if [[ "$signing_path" == "$project/"* ]]; then
            printf 'Keep the upload keystore outside the repository.\n' >&2
            exit 65
        fi
        preset='Android Play AAB'
        mode=--export-release
        ;;
    *)
        printf 'Unknown Android variant. Use debug, play, play-license or qa-bundle.\n' >&2
        exit 64
        ;;
esac
mkdir -p -- "$(dirname -- "$output")"
cd "$project"
bash tools/prepare_android.sh
"$engine" --headless --path "$project" --editor --import
"$engine" --headless --path "$project" "$mode" "$preset" "$output"
test -s "$output"
if [[ "$variant" == play || "$variant" == play-license ]]; then
    verification="$(LC_ALL=C "${JAVA_HOME:+$JAVA_HOME/bin/}jarsigner" -verify "$output")"
    if ! rg -Fxq 'jar verified.' <<<"$verification"; then
        printf 'AAB signature verification failed.\n' >&2
        exit 66
    fi
    keytool="${JAVA_HOME:+$JAVA_HOME/bin/}keytool"
    owner_cert="$("$keytool" -exportcert -alias "$GODOT_ANDROID_KEYSTORE_RELEASE_USER" \
        -keystore "$GODOT_ANDROID_KEYSTORE_RELEASE_PATH" -storepass:env GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD | sha256sum | cut -d' ' -f1)"
    bundle_cert="$(LC_ALL=C "$keytool" -printcert -jarfile "$output" | awk '/SHA256:/{gsub(/:/,"",$2); print tolower($2); exit}')"
    if [[ "$owner_cert" != "$bundle_cert" ]]; then
        printf 'AAB signing certificate differs from the owner upload key.\n' >&2
        exit 66
    fi
    printf 'AAB signature matches the owner upload key.\n'
fi
if [[ "$output" == *.aab && -n "${BUNDLETOOL_JAR:-}" ]]; then
    "${JAVA_HOME:+$JAVA_HOME/bin/}java" -jar "$BUNDLETOOL_JAR" validate --bundle="$output"
fi
