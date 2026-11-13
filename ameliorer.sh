#!/usr/bin/env bash
# Amélioration de vidéos (et de fichiers audio) de basse qualité avec ffmpeg.
#
# Usage : ./ameliorer.sh -i ENTREE [-o SORTIE] [options]
#
#   -p, --preset leger|standard|fort   Force du débruitage/netteté (défaut : standard)
#   -x, --agrandir N                   Agrandir N fois (2, 3, 4) en Lanczos
#       --hd                           Agrandir jusqu'à 1080 px de haut (si plus petit)
#       --ia                           Agrandir avec Real-ESRGAN (IA, GPU Vulkan requis, lent)
#   -s, --stabiliser                   Stabiliser une vidéo tremblante (2 passes)
#   -d, --desentrelacer                Désentrelacer (vieilles cassettes, TV, DV)
#   -c, --couleurs                     Léger renfort contraste/saturation
#       --audio MODE                   auto|voix|musique|aucun|copie (défaut : auto)
#       --voix-ia                      Débruiter la voix avec DeepFilterNet (si installé)
#       --x265                         Encoder en H.265 (fichier plus petit, plus lent)
#       --crf N                        Qualité (défaut 18 ; plus petit = meilleur)
#       --essai SEC                    N'encoder que SEC secondes (pour tester les réglages)
#
# Fichier audio seul (mp3, wav, m4a, flac...) : seul le traitement audio est appliqué.
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTILS="$DIR/outils"

ENTREE=""; SORTIE=""; PRESET="standard"; ECHELLE=1; HD=0; IA=0
STAB=0; DESENTR=0; COULEURS=0; AUDIO="auto"; VOIX_IA=0; CODEC="libx264"; CRF=18; ESSAI=""

aide() { sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while [ $# -gt 0 ]; do
  case "$1" in
    -i) ENTREE="$2"; shift ;;
    -o) SORTIE="$2"; shift ;;
    -p|--preset) PRESET="$2"; shift ;;
    -x|--agrandir) ECHELLE="$2"; shift ;;
    --hd) HD=1 ;;
    --ia) IA=1 ;;
    -s|--stabiliser) STAB=1 ;;
    -d|--desentrelacer) DESENTR=1 ;;
    -c|--couleurs) COULEURS=1 ;;
    --audio) AUDIO="$2"; shift ;;
    --voix-ia) VOIX_IA=1 ;;
    --x265) CODEC="libx265" ;;
    --crf) CRF="$2"; shift ;;
    --essai) ESSAI="$2"; shift ;;
    -h|--help) aide 0 ;;
    *) echo "Option inconnue : $1" >&2; aide 1 ;;
  esac
  shift
done

[ -n "$ENTREE" ] || aide 1
[ -f "$ENTREE" ] || { echo "Fichier introuvable : $ENTREE" >&2; exit 1; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
LIMITE=(); [ -n "$ESSAI" ] && LIMITE=(-t "$ESSAI")

a_video=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_type -of csv=p=0 "$ENTREE" | head -1 || true)
a_audio=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_type -of csv=p=0 "$ENTREE" | head -1 || true)
# Une pochette d'album (mp3/m4a) n'est pas une vraie vidéo
case "${ENTREE,,}" in *.mp3|*.wav|*.flac|*.m4a|*.aac|*.ogg|*.opus|*.wma) a_video="" ;; esac

base="${ENTREE%.*}"
if [ -z "$SORTIE" ]; then
  if [ -n "$a_video" ]; then SORTIE="${base}_ameliore.mp4"; else SORTIE="${base}_ameliore.${ENTREE##*.}"; fi
fi

# ---------------------------------------------------------------- AUDIO
filtre_audio() {
  local mode="$1" f="highpass=f=70"
  local modele="$OUTILS/rnnoise/std.rnnn"
  if [ "$mode" = auto ]; then mode=voix; fi
  case "$mode" in
    voix)
      if [ "$VOIX_IA" = 0 ]; then
        if [ -s "$modele" ]; then f="$f,arnndn=m='$modele':mix=0.85"
        else f="$f,afftdn=nf=-25:tn=1"; fi
      fi
      f="$f,lowpass=f=12000,equalizer=f=3000:t=q:w=1.5:g=2,deesser=i=0.3"
      f="$f,acompressor=threshold=-20dB:ratio=3:attack=10:release=200,loudnorm=I=-16:TP=-1.5:LRA=11" ;;
    musique)
      f="highpass=f=30,afftdn=nf=-30,loudnorm=I=-14:TP=-1:LRA=11" ;;
  esac
  echo "$f"
}

# Débruitage vocal IA éventuel : produit un wav propre à utiliser comme source audio
SOURCE_AUDIO="$ENTREE"
if [ -n "$a_audio" ] && [ "$VOIX_IA" = 1 ] && [ "$AUDIO" != aucun ] && [ "$AUDIO" != copie ]; then
  if [ -x "$OUTILS/venv/bin/deepFilter" ]; then
    echo "==> Débruitage de la voix par DeepFilterNet"
    ffmpeg -hide_banner -loglevel error -y "${LIMITE[@]}" -i "$ENTREE" -vn -ac 1 -ar 48000 "$TMP/voix.wav"
    "$OUTILS/venv/bin/deepFilter" "$TMP/voix.wav" -o "$TMP/df" >/dev/null
    SOURCE_AUDIO="$(ls "$TMP"/df/*.wav | head -1)"
  else
    echo "   DeepFilterNet non installé (./install.sh --ia-audio) : RNNoise utilisé." >&2
    VOIX_IA=0
  fi
fi

opts_audio() {   # remplit le tableau AOPTS
  AOPTS=()
  if [ -z "$a_audio" ] || [ "$AUDIO" = aucun ]; then AOPTS=(-an); return; fi
  if [ "$AUDIO" = copie ]; then AOPTS=(-c:a copy); return; fi
  AOPTS=(-af "$(filtre_audio "$AUDIO")" -ar 48000)
}

# ------------------------------------------------ CAS : FICHIER AUDIO SEUL
if [ -z "$a_video" ]; then
  [ -n "$a_audio" ] || { echo "Aucune piste audio ou vidéo trouvée." >&2; exit 1; }
  opts_audio
  case "${SORTIE,,}" in
    *.mp3) CA=(-c:a libmp3lame -q:a 2) ;;
    *.wav) CA=(-c:a pcm_s16le) ;;
    *.flac) CA=(-c:a flac) ;;
    *.ogg|*.opus) CA=(-c:a libopus -b:a 160k) ;;
    *) CA=(-c:a aac -b:a 192k) ;;
  esac
  echo "==> Traitement audio : $ENTREE -> $SORTIE"
  ffmpeg -hide_banner -loglevel warning -stats -y "${LIMITE[@]}" -i "$SOURCE_AUDIO" -vn "${AOPTS[@]}" "${CA[@]}" "$SORTIE"
  echo "Terminé : $SORTIE"; exit 0
fi

# ---------------------------------------------------------------- VIDÉO
case "$PRESET" in
  leger)    DEBRUIT="hqdn3d=2:1.5:3:2.5";            NET=0.3 ;;
  standard) DEBRUIT="hqdn3d=4:3:6:4.5,deband";       NET=0.5 ;;
  fort)     DEBRUIT="nlmeans=s=3.5:p=7:r=15,deband"; NET=0.7 ;;
  *) echo "Preset inconnu : $PRESET (leger|standard|fort)" >&2; exit 1 ;;
esac

hauteur=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of csv=p=0 "$ENTREE")
if [ "$HD" = 1 ] && [ "$ECHELLE" = 1 ] && [ "$hauteur" -lt 1080 ]; then
  ECHELLE=$(( (1080 + hauteur - 1) / hauteur )); [ "$ECHELLE" -gt 4 ] && ECHELLE=4
fi

joindre() { local IFS=,; echo "$*"; }

PRE=()
[ "$DESENTR" = 1 ] && PRE+=("bwdif=mode=send_frame")
if [ "$STAB" = 1 ]; then
  echo "==> Stabilisation : analyse du mouvement (passe 1/2)"
  ffmpeg -hide_banner -loglevel error -stats -y "${LIMITE[@]}" -i "$ENTREE" \
    -vf "$(joindre "${PRE[@]}" "vidstabdetect=shakiness=6:accuracy=15:result=$TMP/stab.trf")" -f null -
  PRE+=("vidstabtransform=input=$TMP/stab.trf:smoothing=20:zoom=2")
fi
PRE+=("$DEBRUIT")

POST=()
[ "$COULEURS" = 1 ] && POST+=("eq=contrast=1.05:saturation=1.12:gamma=1.02")
POST+=("cas=$NET" "format=yuv420p")

VOPTS=(-c:v "$CODEC" -crf "$CRF" -preset slow -movflags +faststart)
[ "$CODEC" = libx265 ] && VOPTS+=(-tag:v hvc1)
opts_audio
[ "${AOPTS[0]}" = "-af" ] && AOPTS+=(-c:a aac -b:a 192k)

if [ "$IA" = 1 ]; then
  RE="$OUTILS/realesrgan/realesrgan-ncnn-vulkan"
  [ -x "$RE" ] || { echo "Real-ESRGAN absent : lancez ./install.sh --ia" >&2; exit 1; }
  [ "$ECHELLE" = 1 ] && ECHELLE=2
  fps=$(ffprobe -v error -select_streams v:0 -show_entries stream=avg_frame_rate -of csv=p=0 "$ENTREE")
  mkdir -p "$TMP/img" "$TMP/ia"
  echo "==> Extraction des images"
  ffmpeg -hide_banner -loglevel error -stats -y "${LIMITE[@]}" -i "$ENTREE" -vf "$(joindre "${PRE[@]}")" -fps_mode passthrough "$TMP/img/%08d.png"
  echo "==> Agrandissement IA x$ECHELLE ($(ls "$TMP/img" | wc -l) images, patience...)"
  modele="realesr-animevideov3"; [ "$ECHELLE" = 4 ] && modele="realesrgan-x4plus"
  "$RE" -i "$TMP/img" -o "$TMP/ia" -n "$modele" -s "$ECHELLE" -f png
  echo "==> Réassemblage de la vidéo"
  ffmpeg -hide_banner -loglevel warning -stats -y -framerate "$fps" -i "$TMP/ia/%08d.png" \
    "${LIMITE[@]}" -i "$SOURCE_AUDIO" -map 0:v -map "1:a:0?" \
    -vf "$(joindre "${POST[@]}")" "${VOPTS[@]}" "${AOPTS[@]}" -shortest "$SORTIE"
else
  SCALE=()
  [ "$ECHELLE" != 1 ] && SCALE=("scale=iw*$ECHELLE:ih*$ECHELLE:flags=lanczos")
  VF="$(joindre "${PRE[@]}" "${SCALE[@]}" "${POST[@]}")"
  echo "==> Encodage : $ENTREE -> $SORTIE"
  echo "    filtres vidéo : $VF"
  if [ "$SOURCE_AUDIO" = "$ENTREE" ]; then
    ffmpeg -hide_banner -loglevel warning -stats -y "${LIMITE[@]}" -i "$ENTREE" \
      -map 0:v:0 -map "0:a:0?" -vf "$VF" "${VOPTS[@]}" "${AOPTS[@]}" "$SORTIE"
  else
    ffmpeg -hide_banner -loglevel warning -stats -y "${LIMITE[@]}" -i "$ENTREE" -i "$SOURCE_AUDIO" \
      -map 0:v:0 -map 1:a:0 -vf "$VF" "${VOPTS[@]}" "${AOPTS[@]}" -shortest "$SORTIE"
  fi
fi

echo "Terminé : $SORTIE"
