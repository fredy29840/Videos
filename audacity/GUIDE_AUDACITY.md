# Nettoyer une voix avec Audacity (pas à pas)

## 0. Récupérer le son d'une vidéo
```bash
./audio_video.sh extraire ma_video.mp4      # crée ma_video.wav
```
Ouvrir `ma_video.wav` dans Audacity (Fichier > Ouvrir).

## 1. Réduction de bruit (souffle, ventilation, bourdonnement)
1. Sélectionner à la souris **1 à 2 secondes où l'on n'entend que le bruit** (pas de voix).
2. **Effet > Réduction du bruit et restauration > Réduction du bruit** → **Prendre le profil du bruit**.
3. `Ctrl+A` pour tout sélectionner.
4. Rouvrir **Réduction du bruit** : Réduction **12 dB**, Sensibilité **6**, Lissage **3** → **Aperçu** → **Valider**.
   - Son « métallique / sous l'eau » → baisser la réduction (6-9 dB).
   - Mieux vaut **deux passes douces** (2 × 8 dB) qu'une seule forte.

## 2. Macro automatique « Nettoyage_voix »
**Outils > Macros > Nettoyage_voix > Appliquer au projet**. Elle fait :
- filtre passe-haut 70 Hz (grondements, vent, manipulations du micro) ;
- suppression du décalage DC ;
- normalisation à **−16 LUFS** (volume standard YouTube / podcast).

Pour traiter plusieurs fichiers d'un coup : **Outils > Macros > Nettoyage_voix > Fichiers…**

## 3. Corrections facultatives
| Problème | Effet Audacity | Réglage de départ |
|---|---|---|
| Volume irrégulier (voix proches/lointaines) | Effet > Compresseur | Seuil −20 dB, ratio 3:1 |
| Voix sourde, étouffée | Effet > Égaliseur (Égalisation filtre graphique) | +2 à +4 dB vers 3 kHz |
| « S » qui sifflent | Effet > Égaliseur | −3 dB vers 6-8 kHz |
| Bourdonnement électrique 50 Hz | Effet > Filtre coupe-bande (Notch) | 50 Hz, puis 100 et 150 Hz |
| Clics, craquements (vinyle) | Effet > Suppression des clics | Seuil 200, largeur 20 |
| Son saturé | Effet > Réparation de la saturation (Clip Fix) | seuil 95 % |
| Pics trop forts | Effet > Limiteur | −1 dB |

## 4. Exporter et remettre dans la vidéo
1. **Fichier > Exporter l'audio > WAV** (par ex. `propre.wav`).
2. ```bash
   ./audio_video.sh remettre ma_video.mp4 propre.wav   # -> ma_video_son_propre.mp4
   ```
   L'image n'est pas réencodée : aucune perte de qualité, c'est instantané.

> Astuce : pour combiner les deux, lancez d'abord `./ameliorer.sh -i ma_video.mp4 --audio copie`
> (image améliorée, son intact), puis remettez le son retravaillé dans Audacity sur le résultat.
