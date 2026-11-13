#!/usr/bin/env bash
# Traite tout un dossier : ./lot.sh DOSSIER_ENTREE DOSSIER_SORTIE [options de ameliorer.sh]
# Exemple : ./lot.sh ~/Vidéos/vieilles ~/Vidéos/propres -p fort --hd -d
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ $# -ge 2 ] || { sed -n '2,3p' "$0"; exit 1; }
IN="$1"; OUT="$2"; shift 2
mkdir -p "$OUT"
shopt -s nullglob nocaseglob
n=0; err=0
for f in "$IN"/*.{mp4,mkv,avi,mov,wmv,flv,mpg,mpeg,3gp,webm,m4v,vob,mts,mp3,wav,m4a,flac,ogg}; do
  nom="$(basename "${f%.*}")"
  case "${f,,}" in
    *.mp3|*.wav|*.m4a|*.flac|*.ogg) dest="$OUT/$nom.${f##*.}" ;;
    *) dest="$OUT/$nom.mp4" ;;
  esac
  [ -e "$dest" ] && { echo "Déjà fait : $dest"; continue; }
  echo "### $f"
  if "$DIR/ameliorer.sh" -i "$f" -o "$dest" "$@"; then n=$((n+1)); else err=$((err+1)); rm -f "$dest"; fi
done
echo "Fichiers traités : $n, erreurs : $err"
