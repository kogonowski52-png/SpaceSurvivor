#!/usr/bin/env bash
set -euo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
version=4.7.2.stable
template="${1:-${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$version/android_source.zip}"
build="$root/android/build"
marker="$root/android/.build_version"

if [[ ! -f "$template" ]]; then
    printf 'Install the Godot %s export templates or pass the path to android_source.zip.\n' "$version" >&2
    exit 1
fi
if [[ ! -d "$build" ]]; then
    mkdir -p "$build"
    unzip -q "$template" -d "$build"
    printf '%s' "$version" > "$marker"
fi
if [[ ! -f "$marker" || "$(cat "$marker")" != "$version" ]]; then
    printf 'Use the Godot %s Android template. Move the existing android/build directory aside first.\n' "$version" >&2
    exit 1
fi

python3 - "$build" <<'PY'
import re
import sys
from pathlib import Path

build = Path(sys.argv[1])
gradle = build / "build.gradle"
application = build / "src/main/AndroidManifest.xml"
wrapper = build / "gradle/wrapper/gradle-wrapper.properties"
hook = "apply from: '../bridge/galaxy.gradle'"
source = gradle.read_text()
if hook not in source:
    gradle.write_text(source.rstrip() + "\n\n" + hook + "\n")

manifest = application.read_text()
start = '<!-- Galaxy Strike bridge -->'
end = '<!-- End Galaxy Strike bridge -->'
entries = """
        <!-- Galaxy Strike bridge -->
        <meta-data android:name="org.godotengine.plugin.v2.GalaxyCommerce"
            android:value="com.galaxystrike.bridge.GalaxyCommercePlugin" />
        <meta-data android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="${galaxyAdmobAppId}" />
        <meta-data android:name="com.google.android.gms.ads.DELAY_APP_MEASUREMENT_INIT"
            android:value="true" />
        <meta-data android:name="com.galaxystrike.rewarded_bonus"
            android:value="${galaxyRewardedBonus}" />
        <meta-data android:name="com.galaxystrike.rewarded_double"
            android:value="${galaxyRewardedDouble}" />
        <meta-data android:name="com.galaxystrike.rewarded_revive"
            android:value="${galaxyRewardedRevive}" />
        <meta-data android:name="com.galaxystrike.rewarded_boss"
            android:value="${galaxyRewardedBoss}" />
        <meta-data android:name="com.galaxystrike.rewarded_materials"
            android:value="${galaxyRewardedMaterials}" />
        <meta-data android:name="com.galaxystrike.purchase_server"
            android:value="${galaxyPurchaseServer}" />
        <meta-data android:name="com.galaxystrike.play_mode"
            android:value="${galaxyPlayMode}" />
        <meta-data android:name="com.galaxystrike.license_checkout"
            android:value="${galaxyLicenseCheckout}" />
        <meta-data android:name="com.galaxystrike.draft_catalog"
            android:value="${galaxyDraftCatalog}" />
        <meta-data android:name="com.galaxystrike.privacy_policy"
            android:value="${galaxyPrivacyPolicy}" />
        <meta-data android:name="com.galaxystrike.ump_debug_device"
            android:value="${galaxyUmpTestDevice}" />
        <meta-data android:name="com.galaxystrike.ump_debug_geography"
            android:value="${galaxyUmpGeography}" />
        <!-- End Galaxy Strike bridge -->
"""
if start in manifest:
    prompt = re.escape(start) + r'.*?' + re.escape(end)
    manifest = re.sub(prompt, lambda _match: entries.strip(), manifest, count=1, flags=re.S)
elif 'org.godotengine.plugin.v2.GalaxyCommerce' not in manifest:
    manifest, count = re.subn(r'(<application\b[^>]*>)', lambda match: match[0] + entries, manifest, count=1)
    if count != 1:
        raise SystemExit("The Godot Android template has no application manifest entry.")
else:
    raise SystemExit("Move the existing android/build aside and reinstall the Android template.")
application.write_text(manifest)

properties = wrapper.read_text()
if "gradle-8.11.1-bin.zip" not in properties:
    raise SystemExit("The project expects the Gradle 8.11.1 wrapper from Godot 4.7.2.")
if "distributionSha256Sum=" not in properties:
    wrapper.write_text(properties.rstrip() + "\ndistributionSha256Sum=f397b287023acdba1e9f6fc5ea72d22dd63669d59ed4a289a29b1a76eee151c6\n")
PY

chmod +x "$build/gradlew"
touch "$build/.gdignore"
printf 'Android bridge prepared in %s\n' "$build"
