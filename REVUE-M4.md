# Dogs of Gods — M4 « Le Veilleur »

Scène de revue du jeu de tuiles Surface, intégrée au projet Godot 4.7 issu de `devdownin/Dogs` (base `53f1c9d`). La mission est lue depuis `data/missions/m4_le_veilleur.json`.

## Revue sur Android

Installer `Dogs-of-Gods-Surface.apk` sur un appareil ARM64 (Android 7.0 ou supérieur). Le paquet de test `org.dogsofgods.m4preview` démarre sur la M4 lors du premier lancement et conserve sa propre sauvegarde. Sélectionner un drone, toucher une case pour afficher le trajet, toucher à nouveau pour le confirmer. Pincer pour zoomer. « Tout voir » permet d'inspecter le décor entier.

## Sources et export

- Ouvrir `project.godot` avec Godot 4.7 et choisir « M4 » dans le sélecteur.
- Les M1 et M4 assemblent les ressources de `assets/terrain/surface/` à partir de leur grille logique. Le jeu contient 24 tuiles de base, 48 bordures et quatre calques d'arches ou de ruines surélevées. Les autres missions suivent leur rendu antérieur. Les sprites de revue sont dans `assets/maps/m4_le_veilleur/`. Les unités et la balise ont des sprites statiques avec des ombres dessinées séparément. Le brouillard, les surcouches et l'interface sont rendus par le prototype.
- `art-src/m4_le_veilleur/` contient le gabarit dérivé du JSON, le décor source RVB, la planche de sprites RGBA, les consignes de génération et le script de recadrage/export. Les originaux sont des images aplaties, la planche de décor générée fait 1 254 × 1 254 px. Les cycles d'animation relèvent du lot suivant.
- `art-src/surface/` contient la planche des reliefs, les calques PNG de 384 × 384, les consignes et le script `export.py`, qui assemble et exporte les textures de 192 × 192 avec les raccords N=1, E=2, S=4, O=8. Les calques reprennent et adaptent des échantillons de la peinture d'origine. Les raccords sont appliqués du côté intérieur du terrain par le rendu.
- Pour réexporter les ressources, installer Pillow, NumPy et SciPy, puis lancer `python art-src/surface/export.py` pour les tuiles ou `python art-src/m4_le_veilleur/export.py` pour les sprites et la planche initiale.
- Pour reconstruire l'APK de revue, configurer le SDK Android, le JDK et les modèles d'export Godot 4.7, puis exporter le préréglage « Android APK revue M4 ».

## Vérifications

Le projet a été importé avec Godot 4.7 stable. Le validateur des données, les rejeux GDScript, les vérifications campagne et la suite d'interface en rendu 720 × 1280 ont réussi. La suite tactile couvre la victoire sans alerte en M4, les commandes de caméra, la sonde et l'affichage des intentions. L'APK ARM64 a été exporté et sa signature vérifiée. La revue sur matériel Android et les mesures de performance restent à effectuer.

## Animations de présentation (revue 0.3.0)

- L'Éclaireur, le Technicien, la Sentinelle et le Patrouilleur utilisent des feuilles de 35 images, à 12 images par seconde. Le mouvement suit le trajet du moteur de jeu et l'état logique de la mission est appliqué immédiatement.
- Le bas de chaque sprite est ancré à 78 % du cadre. Les silhouettes peintes sont déformées localement pour faire bouger pattes, mât et bras. La vue est unique, miroir horizontal pour les déplacements latéraux. La Sentinelle reste fixe, et son orientation est indiquée au sol.
- Le bouton « Réduire les animations » enregistre un réglage persistant. Quand il est actif, les unités sont affichées directement dans leur case de destination.
- Pour reproduire les feuilles, lancer `python art-src/animations_m4/export.py` après l'export des sprites M4. Les orientations nord et sud, le rig 3D et les mesures sur téléphone restent à faire.
