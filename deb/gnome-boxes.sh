#!/bin/bash
set -euo pipefail

flatpak install -y --system flathub org.gnome.Boxes

echo "Gnome Boxes installed."
