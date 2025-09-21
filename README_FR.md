# IPA Scanner

Un analyseur d'IPA iOS puissant qui fournit des insights détaillés sur la composition des apps, les métriques et les opportunités d'optimisation. Construit avec Swift et Vapor pour les interfaces CLI et web.

## 🚀 Fonctionnalités

- **Analyse Complète**: Extraction et analyse détaillée du contenu IPA
- **Métriques Avancées**: Répartition par taille, détection de doublons, analyse de frameworks
- **Suggestions d'Optimisation**: Recommandations automatiques pour réduire la taille de l'app
- **Interface Web**: UI web moderne avec Vapor pour analyser facilement les IPAs
- **Formats d'Export Multiples**: JSON, rapports texte et visualisation web
- **Localisation**: Support multilingue (EN, FR, ES, DE)
- **Analyse Temps Réel**: Traitement rapide avec suivi de progression

## 📦 Installation

### Prérequis

- macOS 13+
- Swift 5.9+
- Xcode 15+

### Compilation depuis les sources

```bash
git clone https://github.com/joey-barbier/ipaScanner.git
cd ipaScanner
swift build -c release
```

Les exécutables seront dans `.build/release/`

## 🔧 Utilisation

### Utilisation CLI

```bash
# Analyse basique
./ipascanner analyze MonApp.ipa

# Sortie JSON
./ipascanner analyze MonApp.ipa --format json --output rapport.json

# Mode verbose
./ipascanner analyze MonApp.ipa --verbose
```

### Interface Web (Vapor)

```bash
# Démarrer le serveur web
swift run ipascanner-web serve --hostname 127.0.0.1 --port 8083

# Accéder à l'interface
open http://127.0.0.1:8083
```

L'interface web offre :
- Upload par glisser-déposer
- Progression de l'analyse en temps réel
- Graphiques et visualisations interactifs
- Rapports téléchargeables
- Support multilingue

## 📊 Exemple de Sortie

```
📱 Rapport d'Analyse IPA
==================================================

📋 Informations de l'App:
   Bundle ID: com.example.monapp
   Nom: Mon Application  
   Version: 1.2.3 (456)
   Analysé: 2 sep 2025 à 16:45

📊 Vue d'Ensemble:
   Taille Totale: 45.8 MB
   Fichiers: 1,247
   Répertoires: 156

📦 Répartition par Taille:
   Exécutable: 12.4 MB
   Ressources: 28.9 MB
   Frameworks: 4.5 MB

💡 Suggestions d'Optimisation:
   ⚠️ [HAUT] Optimiser les grandes images
      Les images consomment 22.1 MB (48.3% de la taille). 
      Économies potentielles: 6.6 MB
```

## 🏗 Architecture

### Modules Principaux

- **IPAFoundation**: Types de base, protocoles et modèles partagés
- **Parser**: Extraction IPA et analyse binaire
- **Analyzer**: Calcul de métriques et détection d'optimisations
- **VaporApp**: Serveur web avec API REST et gestion de fichiers
- **App**: Interface CLI et orchestration

### Structure

```
Sources/
├── Foundation/           # Types et protocoles de base
├── Parser/              # Extraction et parsing IPA
├── Analyzer/            # Analyse et métriques
├── VaporApp/           # Application web Vapor
│   ├── Controllers/    # Contrôleurs API
│   ├── Services/       # Services métier
│   └── Views/          # Templates Leaf
└── App/                # Interface CLI
```

## 🧪 Tests

```bash
# Lancer tous les tests
swift test

# Tests avec détails
swift test --verbose
```

## 🔒 Sécurité

- **Extraction Sécurisée**: Validation stricte des IPAs
- **Nettoyage Automatique**: Suppression des fichiers temporaires
- **Traitement Local**: Aucune donnée envoyée en ligne
- **Pas de Données Sensibles**: Aucune info personnelle collectée

## 🛠 Développement

⚠️ **État Actuel**: Ce code est actuellement en état "vibe-codé" et nécessite un nettoyage pour respecter les bonnes pratiques Swift 6.2. Travail futur inclut :
- Conformité Sendable appropriée pour tous les types
- Migration complète async/await  
- Amélioration des patterns de gestion d'erreurs
- Audit complet de la sécurité de concurrence

### Conventions de Code

- Architecture modulaire
- Tests unitaires requis
- Documentation des APIs publiques
- Style de commit: `add/update/delete(scope) - Description`

## 🙏 Remerciements

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) pour l'extraction ZIP
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) pour l'interface CLI
- [Vapor](https://vapor.codes) pour le framework web
- Inspiration de l'architecture depuis [LibTracker](https://app.libtracker.io/)

## ☕ Support

Si vous trouvez cet outil utile, vous pouvez [m'offrir un café](https://buymeacoffee.com/horka_tv)!

## 📞 Contact

Pour signaler des bugs ou demander des fonctionnalités :
- Ouvrir une [issue GitHub](https://github.com/joey-barbier/ipaScanner/issues)

---

[🇬🇧 English version](README.md)

Fait avec ❤️ pour la communauté iOS