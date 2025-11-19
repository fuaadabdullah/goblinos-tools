#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

python3 -m venv venv
source venv/bin/activate
pip install --upgrade pip
# Make sure setuptools/wheel are present for building PyYAML
pip install --upgrade setuptools wheel
# On macOS, if Homebrew is available try to install libyaml to avoid a source build for PyYAML
if [[ "$(uname)" == "Darwin" ]] && command -v brew >/dev/null 2>&1; then
	echo "Homebrew detected; ensuring libyaml is installed to speed up PyYAML install"
	brew install libyaml || true
fi
# Install main deps stably and optionally try to install PyYAML if available/buildable
grep -v -i pyyaml requirements.txt > requirements_no_yaml.txt || true
pip install -r requirements_no_yaml.txt
if pip install PyYAML; then
	echo "PyYAML installed successfully"
else
	echo "PyYAML failed to build; YAML parsing will be optional.\nTo fully enable YAML support on macOS, run: brew install libyaml && pip install PyYAML"
fi

python cli.py "$@"
