# IPA Scanner

A powerful iOS IPA analyzer that provides detailed insights into app composition, metrics, and optimization opportunities. Built with Swift and Vapor for both CLI and web interfaces.

## 🚀 Features

- **Complete Analysis**: Detailed extraction and analysis of IPA contents
- **Advanced Metrics**: Size breakdown by category, duplicate detection, framework analysis
- **Optimization Suggestions**: Automatic recommendations to reduce app size
- **Web Interface**: Modern web UI built with Vapor for easy IPA analysis
- **Multiple Export Formats**: JSON, text reports, and web visualization
- **Localization**: Supports multiple languages (EN, FR, ES, DE)
- **Real-time Analysis**: Fast processing with progress tracking

## 📦 Installation

### Requirements

- macOS 13+
- Swift 5.9+
- Xcode 15+

### Build from source

```bash
git clone https://github.com/joey-barbier/ipaScanner.git
cd ipaScanner
swift build -c release
```

Executables will be in `.build/release/`

## 🔧 Usage

### CLI Usage

```bash
# Basic analysis
./ipascanner analyze MyApp.ipa

# JSON output
./ipascanner analyze MyApp.ipa --format json --output report.json

# Verbose mode
./ipascanner analyze MyApp.ipa --verbose
```

### Web Interface (Vapor)

```bash
# Start the web server
swift run ipascanner-web serve --hostname 127.0.0.1 --port 8083

# Access the interface
open http://127.0.0.1:8083
```

The web interface provides:
- Drag & drop IPA upload
- Real-time analysis progress
- Interactive charts and visualizations
- Downloadable reports
- Multi-language support

## 📊 Exemple de sortie

```
📱 IPA Analysis Report
==================================================

📋 App Information:
   Bundle ID: com.example.myapp
   Name: My Application  
   Version: 1.2.3 (456)
   Analyzed: Sep 2, 2025 at 4:45 PM

📊 Size Overview:
   Total Size: 45.8 MB
   Files: 1,247
   Directories: 156

🔧 Technical Details:
   Architectures: arm64
   Supported Devices: iPhone, iPad
   Minimum iOS: 14.0

📦 Size Breakdown:
   Executable: 12.4 MB
   Resources: 28.9 MB
   Frameworks: 4.5 MB

🗂  File Categories:
   🖼 Image: 22.1 MB (48.3%) - 387 files
   ⚙️ Executable: 12.4 MB (27.1%) - 1 files
   📚 Library: 4.5 MB (9.8%) - 12 files
   🎵 Audio: 3.2 MB (7.0%) - 45 files

💡 Optimization Suggestions:
   ⚠️ [HIGH] Optimize large images
      Images consume 22.1 MB (48.3% of app size). Consider using WebP or HEIF formats.
      Potential savings: 6.6 MB
```

## 🏗 Architecture

### Core Modules

- **IPAFoundation**: Base types, protocols and shared models
- **Parser**: IPA extraction and binary analysis
- **Analyzer**: Metrics calculation and optimization detection
- **VaporApp**: Web server with REST API and file handling
- **App**: CLI interface and orchestration

### Structure des données

```
Sources/
├── Foundation/           # Types de base et protocoles
│   ├── Models/          # IPAContent, AnalysisResult, FileCategory
│   ├── Protocols/       # Extractable, Analyzable, Exportable
│   ├── Extensions/      # URL+Extensions, Int64+Extensions
│   └── Errors/          # IPAScannerError
├── Parser/              # Extraction et parsing IPA
│   ├── ClientApi/       # IPAExtractor, PlistParser, BinaryAnalyzer
│   ├── InterfacePublic/ # IPAParserProtocol
│   └── IPAParser.swift  # Orchestrateur principal
├── Analyzer/            # Analyse et métriques
│   ├── ClientApi/       # SizeCalculator, DuplicationDetector, OptimizationSuggester
│   ├── InterfacePublic/ # IPAAnalyzerProtocol
│   └── IPAAnalyzer.swift # Analyseur principal
└── App/                 # Interface et orchestration
    ├── CLI/             # AnalyzeCommand (ArgumentParser)
    ├── UseCases/        # AnalyzeIPAUseCase
    ├── Data/Export/     # JSONFormatter, TextFormatter, ExportService
    └── main.swift       # Point d'entrée
```

## 🧪 Tests

```bash
# Lancer tous les tests
swift test

# Tests avec verbose
swift test --verbose

# Tests d'un module spécifique
swift test --filter IPAFoundationTests
```

### Couverture de tests

- ✅ Tests unitaires pour tous les modules principaux
- ✅ Tests d'intégration pour les workflows complets  
- ✅ Tests de régression pour les formats d'export
- ✅ Tests de validation des erreurs

## 🔍 Fonctionnalités techniques

### Métriques analysées

- **Taille globale** : Taille totale de l'IPA et répartition
- **Catégorisation automatique** : Classification intelligente des fichiers
- **Top fichiers** : Identification des plus gros consommateurs d'espace
- **Frameworks** : Analyse des frameworks (système vs tiers, dynamiques vs statiques)
- **Architectures** : Détection des architectures supportées
- **Localisation** : Comptage des langues supportées

### Détection d'optimisations

- **Fichiers dupliqués** : Hash SHA-256 pour détecter les doublons exacts
- **Images volumineuses** : Identification des images candidates à l'optimisation
- **Architectures inutilisées** : Détection d'architectures obsolètes
- **Assets non compressés** : Fichiers texte volumineux non compressés
- **Frameworks volumineux** : Identification des dépendances lourdes

## 🛠 Development

⚠️ **Current Status**: This codebase is currently in "vibe-coded" state and requires cleanup for proper Swift 6.2 best practices. Future work includes:
- Proper Sendable conformance across all types
- Complete async/await migration  
- Enhanced error handling patterns
- Full concurrency safety audit

### Development Environment

```bash
# Compile in debug mode
swift build

# Run tool in development
swift run ipascanner analyze example.ipa

# Generate documentation
swift package generate-documentation
```

### Contribution

1. Fork the project
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'add(scope) - Description'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Standards

- Modular architecture with clear separation of concerns
- Unit tests required for new functionality
- Public API documentation
- Commit style: `add/update/delete(scope) - Description`

## 🔒 Sécurité

- **Extraction sécurisée** : Validation stricte des IPAs, sandbox pour l'extraction
- **Nettoyage automatique** : Suppression des fichiers temporaires
- **Pas de données sensibles** : Aucune information personnelle collectée ou transmise
- **Traitement local** : Toute l'analyse se fait en local, pas de communication réseau

## 📋 Prérequis système

- **Outils système** : `lipo`, `file`, `nm` (inclus dans Xcode Command Line Tools)
- **Formats supportés** : IPA (iOS App Store Package)
- **Mémoire** : Recommandé 1GB RAM libre pour les gros IPAs

## 🐛 Dépannage

### Erreurs communes

**"File not found"**
- Vérifier que le chemin vers l'IPA est correct
- S'assurer que l'extension est bien `.ipa`

**"Permission denied"**  
- Vérifier les permissions de lecture sur le fichier IPA
- Essayer avec `sudo` si nécessaire

**"Invalid IPA format"**
- Vérifier que le fichier est un IPA valide (fichier ZIP contenant Payload/)
- Essayer de renommer `.ipa` vers `.zip` et extraire manuellement pour diagnostiquer

### Debug mode

```bash
# Activer les logs détaillés
./ipascanner analyze MyApp.ipa --verbose

# Analyser un IPA corrompu
./ipascanner analyze suspect.ipa --verbose --format json 2> debug.log
```

## 📄 Licence

Ce projet est sous licence MIT - voir le fichier [LICENSE](LICENSE) pour plus de détails.

## 🙏 Acknowledgments

- [ZIPFoundation](https://github.com/weichsel/ZIPFoundation) for ZIP extraction
- [Swift Argument Parser](https://github.com/apple/swift-argument-parser) for CLI interface
- [Vapor](https://vapor.codes) for web framework
- Architecture inspiration from [LibTracker](https://app.libtracker.io/)

## ☕ Support

If you find this tool useful, consider [buying me a coffee](https://buymeacoffee.com/horka_tv)!

## 📞 Contact

For bugs or feature requests:
- Open a [GitHub issue](https://github.com/joey-barbier/ipaScanner/issues)

---

[🇫🇷 Version française](README_FR.md)

Made with ❤️ for the iOS community