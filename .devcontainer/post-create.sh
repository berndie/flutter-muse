#!/usr/bin/env bash
# .devcontainer/post-create.sh
set -euo pipefail

# Android command-line tools build number; newer ones are listed at
# https://developer.android.com/studio#command-line-tools-only
CMDLINE_TOOLS_VERSION="11076708"
ANDROID_PACKAGES=(
  "platform-tools"
  "platforms;android-36"
  "build-tools;36.0.0"  
)

export ANDROID_HOME="${ANDROID_HOME:-$HOME/android-sdk}"
export PATH="$HOME/flutter/bin:$HOME/.pub-cache/bin:$ANDROID_HOME/cmdline-tools/latest/bin:$ANDROID_HOME/platform-tools:$PATH"

# Named volumes are created root-owned; hand them to the vscode user
sudo chown -R vscode:vscode \
  "$HOME/flutter" "$HOME/android-sdk" "$HOME/.gradle" "$HOME/.pub-cache" "$HOME/.claude"

# Tools Flutter and the SDK installer need
sudo apt-get update
sudo apt-get install -y --no-install-recommends unzip zip xz-utils
sudo rm -rf /var/lib/apt/lists/*

# --- Android SDK -----------------------------------------------------------
if [ ! -x "$ANDROID_HOME/cmdline-tools/latest/bin/sdkmanager" ]; then
  echo "Installing Android command-line tools..."
  tmp="$(mktemp -d)"
  curl -fsSL -o "$tmp/cmdline-tools.zip" \
    "https://dl.google.com/android/repository/commandlinetools-linux-${CMDLINE_TOOLS_VERSION}_latest.zip"
  unzip -q "$tmp/cmdline-tools.zip" -d "$tmp"
  mkdir -p "$ANDROID_HOME/cmdline-tools"
  mv "$tmp/cmdline-tools" "$ANDROID_HOME/cmdline-tools/latest"
  rm -rf "$tmp"
fi

yes | sdkmanager --licenses > /dev/null || true
sdkmanager --install "${ANDROID_PACKAGES[@]}"

# --- Flutter ---------------------------------------------------------------
if [ ! -x "$HOME/flutter/bin/flutter" ]; then
  echo "Installing Flutter (stable)..."
  git clone --depth 1 --branch stable https://github.com/flutter/flutter.git "$HOME/flutter"
fi

flutter config --no-analytics --android-sdk "$ANDROID_HOME" \
  --no-enable-web --no-enable-linux-desktop
dart --disable-analytics
flutter precache --android
yes | flutter doctor --android-licenses > /dev/null || true

# --- Project ---------------------------------------------------------------
if [ -f pubspec.yaml ]; then
  flutter pub get
fi
if [ -f example/pubspec.yaml ]; then
  (cd example && flutter pub get)
fi

flutter doctor -v || true