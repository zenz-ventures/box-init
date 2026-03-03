set -euo pipefail

if ! command -v pwsh >/dev/null 2>&1; then
  if ! command -v brew >/dev/null 2>&1; then
    echo "Homebrew not found. Install Homebrew first: https://brew.sh"
    exit 1
  fi
  brew install --cask powershell
fi

echo ""
echo "PowerShell 7 is ready."
echo "Next: run pwsh and then your private bootstrap."
echo ""
echo "  pwsh"
echo ""
