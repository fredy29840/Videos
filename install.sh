#!/usr/bin/env bash
# Installation de la boîte à outils d'amélioration vidéo/audio (Ubuntu / Debian).
#   ./install.sh            -> ffmpeg + modèles RNNoise (débruitage voix)
#   ./install.sh --ia       -> + Real-ESRGAN (agrandissement IA, nécessite une carte graphique Vulkan)
#   ./install.sh --ia-audio -> + DeepFilterNet (débruitage voix IA, Python)
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTILS="$DIR/outils"
mkdir -p "$OUTILS/rnnoise"

IA=0; IA_AUDIO=0
for a in "$@"; do
  case "$a" in
    --ia) IA=1 ;;
    --ia-audio) IA_AUDIO=1 ;;
    -h|--help) sed -n '2,6p' "$0"; exit 0 ;;
    *) echo "Option inconnue : $a" >&2; exit 1 ;;
  esac
done

SUDO=""; [ "$(id -u)" -ne 0 ] && SUDO="sudo"

echo "==> Paquets système (ffmpeg, unzip, wget)"
$SUDO apt-get update -y
$SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y ffmpeg unzip wget

echo "==> Modèles RNNoise pour le débruitage de la voix (filtre arnndn)"
BASE="https://raw.githubusercontent.com/richardpl/arnndn-models/master"
for m in std.rnnn sh.rnnn cb.rnnn; do
  [ -s "$OUTILS/rnnoise/$m" ] || wget -q -O "$OUTILS/rnnoise/$m" "$BASE/$m" || echo "   (échec du téléchargement de $m, le débruitage FFT sera utilisé)"
done

if [ "$IA" = 1 ]; then
  echo "==> Real-ESRGAN (ncnn-vulkan)"
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y libvulkan1 mesa-vulkan-drivers || true
  ZIP="realesrgan-ncnn-vulkan-20220424-ubuntu.zip"
  URL="https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0/$ZIP"
  if [ ! -x "$OUTILS/realesrgan/realesrgan-ncnn-vulkan" ]; then
    wget -q --show-progress -O "/tmp/$ZIP" "$URL"
    mkdir -p "$OUTILS/realesrgan"
    unzip -o -q "/tmp/$ZIP" -d "$OUTILS/realesrgan"
    chmod +x "$OUTILS/realesrgan/realesrgan-ncnn-vulkan"
    rm -f "/tmp/$ZIP"
  fi
  "$OUTILS/realesrgan/realesrgan-ncnn-vulkan" -h >/dev/null 2>&1 \
    && echo "   Real-ESRGAN OK" \
    || echo "   Attention : Real-ESRGAN ne démarre pas (pas de GPU Vulkan ?). Le mode --ia ne fonctionnera pas."
fi

if [ "$IA_AUDIO" = 1 ]; then
  echo "==> DeepFilterNet (environnement Python isolé)"
  $SUDO DEBIAN_FRONTEND=noninteractive apt-get install -y python3-venv python3-pip
  python3 -m venv "$OUTILS/venv"
  "$OUTILS/venv/bin/pip" install --upgrade pip
  "$OUTILS/venv/bin/pip" install torch torchaudio --index-url https://download.pytorch.org/whl/cpu
  "$OUTILS/venv/bin/pip" install deepfilternet
fi

chmod +x "$DIR"/*.sh
echo
echo "Installation terminée. Exemple :"
echo "  ./ameliorer.sh -i ma_video.mp4"
