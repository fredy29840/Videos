# Amélioration de vidéos et d'audio de basse qualité

Scripts basés sur **ffmpeg** pour nettoyer de vieilles vidéos (téléphone, webcam, VHS/DV numérisées, vidéos compressées) et leur son.

## 1. Installation (Ubuntu / Debian)

```bash
git clone <ce dépôt> && cd Videos
./install.sh              # ffmpeg + modèles RNNoise (débruitage voix)  — indispensable
./install.sh --ia         # + Real-ESRGAN : agrandissement par IA (GPU Vulkan requis)
./install.sh --ia-audio   # + DeepFilterNet : débruitage voix par IA (~2 Go, Python)
./install.sh --audacity   # + Audacity et la macro « Nettoyage_voix »
```

## 2. Usage rapide

```bash
./ameliorer.sh -i video.mp4                        # réglage standard -> video_ameliore.mp4
./ameliorer.sh -i video.mp4 --essai 10             # teste sur 10 s avant de tout lancer
./ameliorer.sh -i vhs.avi -d -p fort --hd -c       # cassette VHS : désentrelacer, débruiter fort, 1080p
./ameliorer.sh -i tel.mp4 -s                       # vidéo de téléphone qui tremble
./ameliorer.sh -i petite.mp4 --ia -x 4             # agrandissement IA x4
./ameliorer.sh -i interview.mp3                    # audio seul : voix nettoyée et normalisée
./ameliorer.sh -i concert.mp4 --audio musique      # ne pas traiter le son comme une voix
./lot.sh dossier_source dossier_sortie -p fort --hd   # tout un dossier
```

## 3. Options

| Option | Effet |
|---|---|
| `-p leger\|standard\|fort` | Force du débruitage + netteté. `fort` utilise nlmeans (bien meilleur, ~10× plus lent) |
| `-x N` / `--hd` | Agrandir N fois, ou automatiquement jusqu'à 1080 p |
| `--ia` | Agrandissement Real-ESRGAN (bien plus net que Lanczos, très lent sans bon GPU) |
| `-s` | Stabilisation en 2 passes (vid.stab) |
| `-d` | Désentrelacement (bwdif) – pour les lignes « peigne » des vidéos TV/VHS/DV |
| `-c` | Léger renfort du contraste et des couleurs |
| `--audio auto\|voix\|musique\|aucun\|copie` | Traitement du son |
| `--voix-ia` | Débruitage voix DeepFilterNet au lieu de RNNoise |
| `--x265`, `--crf N` | Codec H.265 (plus petit) ; qualité (18 par défaut, 14-16 = très haute) |
| `--essai SEC` | N'encode que les SEC premières secondes |

## 4. Ce que fait chaque traitement

**Vidéo** (dans l'ordre) : désentrelacement → stabilisation → débruitage (hqdn3d ou nlmeans) → suppression des bandes de couleur (deband) → agrandissement → couleurs → netteté adaptative (CAS) → H.264 CRF 18.

**Voix** : coupe des grondements < 70 Hz → débruitage RNNoise (réseau de neurones, filtre `arnndn`) ou FFT si modèle absent → présence à 3 kHz → réduction des sifflantes → compresseur → normalisation EBU R128 à −16 LUFS (niveau YouTube/podcast).

**Musique** : débruitage FFT doux + normalisation à −14 LUFS.

## 5. Audacity (retouche du son à la main)

Pour un contrôle fin du son (profil de bruit, égaliseur, clics…), voir **[audacity/GUIDE_AUDACITY.md](audacity/GUIDE_AUDACITY.md)**.

```bash
./audio_video.sh extraire ma_video.mp4               # -> ma_video.wav, à ouvrir dans Audacity
./audio_video.sh remettre ma_video.mp4 propre.wav    # -> ma_video_son_propre.mp4 (image intacte)
```

## 6. Conseils

- **Toujours tester avec `--essai 10`** puis comparer avant de lancer un long encodage.
- Trop de débruitage = effet « peinture à l'huile » : redescendez à `leger`.
- Agrandir n'invente pas de détails (sauf l'IA, qui les *imagine*) : `--hd` sert surtout à un affichage propre sur grand écran.
- Vidéos de visages très floues : l'IA visages (GFPGAN/CodeFormer) donne de gros gains mais demande une installation Python + GPU séparée.
- Alternatives graphiques gratuites : **Shotcut** / **Kdenlive** (montage + filtres), **Audacity** (réduction de bruit manuelle), **Upscayl** (Real-ESRGAN avec interface), **Video2X**.
