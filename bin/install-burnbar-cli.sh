#!/usr/bin/env bash
set -euo pipefail

APP="/Applications/Burnbar.app"
HELPER="$APP/Contents/Helpers/CodexBarCLI"
TARGETS=("/usr/local/bin/burnbar" "/opt/homebrew/bin/burnbar")

if [[ ! -x "$HELPER" ]]; then
  echo "Burnbar CLI helper not found at $HELPER. Please reinstall Burnbar." >&2
  exit 1
fi

install_script=$(mktemp)
cat > "$install_script" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
HELPER="__HELPER__"
TARGETS=("/usr/local/bin/burnbar" "/opt/homebrew/bin/burnbar")

for t in "${TARGETS[@]}"; do
  mkdir -p "$(dirname "$t")"
  ln -sf "$HELPER" "$t"
  echo "Linked $t -> $HELPER"
done
EOF

perl -pi -e "s#__HELPER__#$HELPER#g" "$install_script"

osascript -e "do shell script \"bash '$install_script'\" with administrator privileges"
rm -f "$install_script"

echo "Burnbar CLI installed. Try: burnbar usage"
