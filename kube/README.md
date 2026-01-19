# Projet SAE503 - Déploiement Kubernetes avec Traefik

Ce projet contient la configuration Kubernetes pour déployer Traefik comme ingress controller et des applications de démonstration.

## Structure du projet

```
.
├── kustomization.yaml          # Configuration Kustomize principale
├── deploy-all.sh               # Script pour déployer tout le projet
├── cleanup.sh                  # Script pour nettoyer toutes les ressources
├── traefik/                    # Configuration Traefik
│   ├── kustomization.yaml      # Configuration Kustomize pour Traefik
│   ├── traefik-config.yaml     # Configuration de Traefik
│   ├── traefik-deployment.yaml # Déploiement de Traefik
│   ├── traefik-service.yaml    # Service pour Traefik
│   ├── traefik-rbac.yaml       # Configuration RBAC pour Traefik
│   ├── deploy-traefik-kustomize.sh # Script de déploiement Traefik
│   └── README.md               # Documentation Traefik
├── whoami.yaml                 # Déploiement de l'application whoami
├── whoami-service.yaml         # Service pour l'application whoami
├── Chart.yaml                  # Configuration Helm (héritage)
├── values.yaml                 # Valeurs Helm (héritage)
└── install.sh                  # Script d'installation (héritage)
```

## Prérequis

- Kubernetes (Minikube, Kind, ou Docker Desktop avec Kubernetes activé)
- kubectl installé et configuré (avec support Kustomize)
- Accès à un cluster Kubernetes local

## Déploiement

### Méthode recommandée: Déploiement complet avec Kustomize

```bash
./deploy-all.sh
```

Ce script va:
1. Vérifier les prérequis
2. Déployer Traefik avec toutes ses dépendances
3. Déployer l'application whoami
4. Attendre que tous les services soient prêts
5. Afficher les informations de connexion

### Déploiement manuel

```bash
# Déployer avec Kustomize
kubectl apply -k .

# Vérifier que tout est prêt
kubectl wait --for=condition=available --timeout=300s deployment/traefik
kubectl wait --for=condition=available --timeout=300s deployment/whoami
```

## Accès aux services

- **Tableau de bord Traefik**: http://localhost:8080
- **Service Traefik (HTTP)**: http://localhost:80
- **Service Whoami**: http://localhost:8081 (via NodePort)

## Nettoyage

```bash
./cleanup.sh
```

Ou manuellement:

```bash
kubectl delete -k .
```

## Configuration avec Kustomize

Ce projet utilise [Kustomize](https://kustomize.io/) pour gérer les configurations Kubernetes. Kustomize est intégré nativement dans kubectl depuis la version 1.14.

### Avantages de Kustomize

1. **Gestion centralisée**: Toutes les ressources sont définies dans `kustomization.yaml`
2. **Labels communs**: Tous les objets ont automatiquement des labels cohérents
3. **Personnalisation facile**: Modification centralisée des images, namespaces, etc.
4. **Environnements multiples**: Facile à adapter pour différents environnements

### Visualiser la configuration

Pour voir la configuration finale avant de l'appliquer:

```bash
kubectl kustomize .
```

## Déploiement Traefik seul

Si vous souhaitez déployer uniquement Traefik:

```bash
cd traefik
./deploy-traefik-kustomize.sh
```

Ou manuellement:

```bash
cd traefik
kubectl apply -k .
```

## Configuration avancée

### Personnaliser les images

Modifiez le `kustomization.yaml` principal pour changer les versions des images:

```yaml
images:
  - name: traefik
    newName: traefik
    newTag: v2.11
  - name: containous/whoami
    newName: containous/whoami
    newTag: v1.8
```

### Ajouter des ressources

Pour ajouter de nouvelles applications, ajoutez simplement les fichiers YAML et référencez-les dans le `kustomization.yaml`:

```yaml
resources:
  - traefik/
  - whoami.yaml
  - whoami-service.yaml
  - ma-nouvelle-application.yaml
```

## Dépannage

### Vérifier les logs

```bash
# Logs Traefik
kubectl logs -l app=traefik

# Logs Whoami
kubectl logs -l app=whoami
```

### Vérifier les événements

```bash
kubectl get events --sort-by='.metadata.creationTimestamp'
```

### Vérifier les pods

```bash
kubectl get pods -o wide
```

### Vérifier les services

```bash
kubectl get svc
```

## Configuration Traefik

Traefik est configuré avec:

- **Entrypoints**: web (80), websecure (443)
- **API Dashboard**: Activé sur le port 8080
- **Providers**: Kubernetes CRD et Ingress
- **Logging**: Niveau INFO

Pour plus de détails sur la configuration Traefik, consultez le [README Traefik](traefik/README.md).

## Applications déployées

### Whoami

L'application whoami est une simple application qui retourne des informations sur la requête HTTP. Elle est utile pour tester le routage et le load balancing.

- **Port**: 8081 (NodePort)
- **Type**: NodePort pour un accès facile en local

## Architecture

```
Client → Traefik (Ingress Controller) → Services Kubernetes
          ↓
     Dashboard (port 8080)
```

## Bonnes pratiques

1. **Ne pas exposer le dashboard en production**: Le dashboard Traefik est accessible sans authentification dans cette configuration. Pour la production, ajoutez une authentification.

2. **Utiliser HTTPS**: Cette configuration utilise HTTP pour simplifier le déploiement local. En production, configurez des certificats TLS.

3. **Monitoring**: Pour la production, ajoutez Prometheus et Grafana pour surveiller Traefik.

## Licence

Ce projet est sous licence MIT. Voir le fichier LICENSE pour plus de détails.
