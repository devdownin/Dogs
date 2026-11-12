#!/usr/bin/env bash
# Construit les paquets Android de Dogs of Gods.
#
#   tools/build_android.sh apk   APK de test, signé avec la clé de débogage (installation directe)
#   tools/build_android.sh aab   AAB pour le Play Store, signé avec la clé d'envoi (via Gradle)
#
# Variables attendues :
#   GODOT          binaire Godot 4.7 (défaut : godot)
#   ANDROID_HOME   SDK Android avec build-tools 36.1.0 et platforms;android-36
#   JAVA_HOME      JDK 17 ou plus
# Pour « aab » seulement :
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD   clé d'envoi Play (jamais dans le dépôt)
set -euo pipefail

MODE="${1:-apk}"
GODOT="${GODOT:-godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
VERSION="4.7.stable"
TEMPLATES="${XDG_DATA_HOME:-$HOME/.local/share}/godot/export_templates/$VERSION"
SETTINGS="${XDG_CONFIG_HOME:-$HOME/.config}/godot/editor_settings-4.7.tres"
DEBUG_KS="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HOME/.android/debug.keystore}"

die() { echo "Erreur : $*" >&2; exit 1; }
[[ -d "$TEMPLATES" && -f "$TEMPLATES/android_source.zip" ]] || die "modèles d'export absents dans $TEMPLATES"
[[ -n "${ANDROID_HOME:-}" && -x "$ANDROID_HOME/build-tools/36.1.0/apksigner" ]] || die "ANDROID_HOME sans build-tools 36.1.0"
[[ -n "${JAVA_HOME:-}" && -x "$JAVA_HOME/bin/java" ]] || die "JAVA_HOME invalide"

# 1. Clé de débogage (créée une fois, sert aussi à la signature de test).
if [[ ! -f "$DEBUG_KS" ]]; then
  mkdir -p "$(dirname "$DEBUG_KS")"
  "$JAVA_HOME/bin/keytool" -genkeypair -keystore "$DEBUG_KS" -storepass android -alias androiddebugkey \
    -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" >/dev/null
fi

# 2. Réglages de l'éditeur : chemins du SDK, de Java et de la clé de débogage.
[[ -f "$SETTINGS" ]] || "$GODOT" --headless --editor --quit --path "$ROOT" >/dev/null 2>&1 || true
[[ -f "$SETTINGS" ]] || die "réglages de l'éditeur introuvables ($SETTINGS)"
python3 - "$SETTINGS" "$ANDROID_HOME" "$JAVA_HOME" "$DEBUG_KS" <<'EOF'
import re, sys
path, sdk, jdk, ks = sys.argv[1:]
s = open(path).read()
for key, val in [("export/android/android_sdk_path", sdk), ("export/android/java_sdk_path", jdk),
                 ("export/android/debug_keystore", ks), ("export/android/debug_keystore_user", "androiddebugkey"),
                 ("export/android/debug_keystore_pass", "android")]:
    line = f'{key} = "{val}"'
    if re.search(rf"^{re.escape(key)} = .*$", s, re.M):
        s = re.sub(rf"^{re.escape(key)} = .*$", line, s, flags=re.M)
    else:
        s = s.replace("[resource]\n", "[resource]\n" + line + "\n", 1)
open(path, "w").write(s)
EOF

# 3. Import du projet (classes, traductions).
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
"$GODOT" --headless --path "$ROOT" --import >/dev/null 2>&1 || true
mkdir -p "$ROOT/build"

case "$MODE" in
  apk)
    "$GODOT" --headless --path "$ROOT" --export-debug "Android APK test" "$ROOT/build/dogs-of-gods-test.apk"
    OUT="$ROOT/build/dogs-of-gods-test.apk"
    ;;
  aab)
    [[ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]] || die "clé d'envoi non fournie (GODOT_ANDROID_KEYSTORE_RELEASE_*)"
    # Modèle de compilation Gradle, installé comme le fait l'éditeur.
    if [[ "$(cat "$ROOT/android/.build_version" 2>/dev/null)" != "$VERSION" ]]; then
      rm -rf "$ROOT/android/build" && mkdir -p "$ROOT/android/build"
      unzip -qo "$TEMPLATES/android_source.zip" -d "$ROOT/android/build"
      echo "$VERSION" > "$ROOT/android/.build_version"
      touch "$ROOT/android/build/.gdignore"
    fi
    "$GODOT" --headless --path "$ROOT" --export-release "Android AAB Play" "$ROOT/build/dogs-of-gods.aab"
    OUT="$ROOT/build/dogs-of-gods.aab"
    ;;
  *) die "mode inconnu : $MODE (apk ou aab)" ;;
esac

[[ -s "$OUT" ]] || die "l'export n'a pas produit $OUT"
echo "Produit : $OUT ($(du -h "$OUT" | cut -f1))"
