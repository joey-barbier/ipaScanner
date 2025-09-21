# IPA Scanner - Déploiement Production

Configuration Docker pour le déploiement d'IPA Scanner sur **ipa.tips**.

## Prérequis

- Docker et Docker Compose installés
- Réseau Traefik `web` configuré
- Domaine `ipa.tips` pointant vers le serveur

## Installation

1. **Cloner la configuration**
   ```bash
   cd /var/www/
   git clone <repo-url> ipascanner
   cd ipascanner/deploy
   ```

2. **Configuration environnement**
   ```bash
   cp .env.example .env
   # Éditer .env avec vos valeurs
   ```

3. **Créer les répertoires de données**
   ```bash
   sudo mkdir -p /var/www/ipascanner-data/{data,uploads,logs,temp,backups}
   sudo chown -R 1000:1000 /var/www/ipascanner-data/
   ```

4. **Démarrer les services**
   ```bash
   docker-compose up -d
   ```

## Services inclus

- **ipascanner** : Application principale (port 8080)
- **cleanup** : Nettoyage automatique des fichiers temporaires
- **backup** : Sauvegarde quotidienne des données

## Monitoring

```bash
# Logs
docker-compose logs -f ipascanner

# Status
docker-compose ps

# Santé
docker-compose exec ipascanner curl http://localhost:8080/health
```

## Maintenance

```bash
# Mise à jour
docker-compose pull
docker-compose up -d

# Redémarrage
docker-compose restart ipascanner

# Nettoyage
docker system prune
```

## Configuration Traefik

Le service utilise les labels Traefik pour :
- Routage automatique vers `ipa.tips`
- Certificat SSL/TLS automatique
- Limite d'upload à 500MB