#!/usr/bin/env bash
# Faire un aller-retour vidéo -> Audacity -> vidéo, sans réencoder l'image.
#   ./audio_video.sh extraire video.mp4               -> video.wav (à ouvrir dans Audacity)
#   ./audio_video.sh remettre video.mp4 propre.wav    -> video_son_propre.mp4
set -euo pipefail
case "${1:-}" in
  extraire)
    [ -f "${2:-}" ] || { sed -n '2,4p' "$0"; exit 1; }
    out="${2%.*}.wav"
    ffmpeg -hide_banner -loglevel error -stats -y -i "$2" -vn -c:a pcm_s16le -ar 48000 "$out"
    echo "Ouvrez dans Audacity : $out  (puis Fichier > Exporter en WAV)" ;;
  remettre)
    [ -f "${2:-}" ] && [ -f "${3:-}" ] || { sed -n '2,4p' "$0"; exit 1; }
    out="${4:-${2%.*}_son_propre.mp4}"
    ffmpeg -hide_banner -loglevel error -stats -y -i "$2" -i "$3" -map 0:v:0 -map 1:a:0 \
      -c:v copy -c:a aac -b:a 192k -shortest -movflags +faststart "$out"
    echo "Terminé : $out" ;;
  *) sed -n '2,4p' "$0"; exit 1 ;;
esac
