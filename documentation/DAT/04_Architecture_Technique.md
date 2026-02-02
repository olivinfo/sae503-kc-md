# 3. Architecture Technique

## 3.1 Orchestrateur de conteneurs

### 3.1.1 Kubernetes

**Description** : Kubernetes est utilisé comme orchestrateur de conteneurs pour gérer le déploiement, la mise à l'échelle et l'exploitation des applications conteneurisées.

**Configuration actuelle** :

- **Namespace** : `haddock` - Isolement logique de tous les services
- **Pods** : Conteneurs exécutant les microservices et Redis
- **Services** : Exposition des microservices via des services Kubernetes
- **Ingress** : Configuration de Traefik pour le routage des requêtes HTTP
- **Deployments** : Gestion des répliques et des mises à jour

**Fichiers de configuration** :

```yaml
# Exemple de configuration de namespace
apiVersion: v1
kind: Namespace
metadata:
  name: haddock
```

```yaml
# Exemple de deployment pour le service quotes
apiVersion: apps/v1
kind: Deployment
metadata:
  name: quotes-service
  namespace: haddock
spec:
  replicas: 2
  selector:
    matchLabels:
      app: quotes-service
  template:
    metadata:
      labels:
        app: quotes-service
    spec:
      containers:
      - name: quotes-service
        image: kitami1/sae503-quotes:1.0.0
        imagePullPolicy: Always
        ports:
        - containerPort: 5000
```

### 3.1.2 Configuration réseau

**Réseau Kubernetes** :
- **Type** : Network overlay (par défaut avec Kubernetes)
- **Nom** : `proxy` - Réseau dédié pour l'isolation des services
- **Communication** : Tous les pods peuvent communiquer entre eux dans le même namespace

**Configuration Traefik** :
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: reverse-proxy
  namespace: haddock
  annotations:
    traefik.ingress.kubernetes.io/router.entrypoints: web
spec:
  rules:
  - host: localhost.local
    http:
      paths:
      - path: /users
        pathType: Prefix
        backend:
          service:
            name: backend-users
            port:
              number: 80
      - path: /quotes
        pathType: Prefix
        backend:
          service:
            name: backend-quotes
            port:
              number: 80
```

## 3.2 Microservices

### 3.2.1 Users Service

**Fonctionnalités** :
- Gestion des utilisateurs (CRUD)
- Authentification et autorisation via tokens
- Stockage des informations utilisateurs
- Génération dynamique de tokens
- Système de login/session

**Technologies** :
- **Langage** : Python 3.12
- **Framework** : Flask
- **Base de données** : Redis
- **Documentation** : Flasgger (Swagger)
- **Sécurité** : Tokens aléatoires avec secrets.token_hex(16)

**Endpoints** :
- `GET /` - Point d'entrée du service
- `GET /users` - Liste tous les utilisateurs (authentification requise)
- `GET /users/all` - Liste tous les utilisateurs (sans authentification)
- `GET /users/token` - Liste tous les tokens d'authentification
- `POST /users` - Crée un nouvel utilisateur (authentification requise)
- `POST /users/login` - Connexion utilisateur et génération de token
- `GET /users/health` - Vérification de santé du service

**Exemple de code réel** :
```python
@app.route('/users/login', methods=['POST'])
def login_user():
    data = request.get_json()
    name = data.get("name")
    password = data.get("password")

    if not name or not password:
        return jsonify({"error": "Nom et mot de passe sont requis"}), 400

    user_keys = redis_client.smembers("users")
    for user_key in user_keys:
        user_data = redis_client.hgetall(user_key)
        if user_data.get("name") == name and user_data.get("password") == password:
            token = secrets.token_hex(16)

            redis_client.hset(
                f"token:{token}",
                mapping={
                    "id": user_data.get("id"),
                    "name": user_data.get("name"),
                }
            )
            redis_client.sadd("token", f"token:{token}")

            return jsonify({
                "token": token,
                "user_id": user_data.get("id")
            }), 200

    return jsonify({"error": "Nom d'utilisateur ou mot de passe incorrect"}), 401
```

**Système d'authentification** :
```python
def require_auth(f):
    @wraps(f)
    def decorated(*args, **kwargs):
        auth_key = request.headers.get("Authorization")
        if not auth_key:
            return jsonify({"error": "Authorization header is missing"}), 401
        token_key = f"token:{auth_key}"
        if not redis_client.exists(token_key):
            return jsonify({"error": "Unauthorized: Invalid token"}), 401
        token_data = redis_client.hgetall(token_key)
        if not token_data:
            return jsonify({"error": "Unauthorized: Token data is invalid"}), 401
        return f(*args, **kwargs)
    return decorated
```

### 3.2.2 Quotes Service

**Fonctionnalités** :
- Gestion des citations
- Ajout et suppression de citations
- Récupération de toutes les citations
- Authentification requise pour les opérations de modification
- Chargement initial des données depuis CSV
- Génération automatique d'IDs de citations

**Technologies** :
- **Langage** : Python 3.12
- **Framework** : Flask
- **Base de données** : Redis
- **Documentation** : Flasgger (Swagger)
- **Gestion des IDs** : Incrémentation automatique avec Redis

**Endpoints** :
- `GET /quotes` - Liste toutes les citations
- `POST /quotes` - Ajoute une nouvelle citation (authentification requise)
- `DELETE /quotes/<int:quote_id>` - Supprime une citation (authentification requise)
- `GET /quotes/health` - Vérification de santé du service

**Exemple de code réel** :
```python
@app.route('/quotes', methods=['POST'])
@require_auth
def add_quote():
    data = request.get_json()
    user_id = data.get("user_id")
    quote = data.get("quote")

    if not user_id or not quote:
        return jsonify({"error": "user_id et quote sont requis"}), 400

    quote_id = redis_client.incr("quote_id")
    key = f"quotes:{quote_id}"
    redis_client.hset(key, mapping={"user_id": user_id, "quote": quote})
    redis_client.sadd("quotes", key)
    return jsonify({"message": "Citation ajoutée", "id": quote_id}), 201

@app.route('/quotes/<int:quote_id>', methods=['DELETE'])
@require_auth
def delete_quote(quote_id):
    key = f"quotes:{quote_id}"
    if not redis_client.hexists(key, "quote"):
        return jsonify({"error": "Citation non trouvée"}), 404

    redis_client.delete(key)
    redis_client.srem("quotes", key)
    return jsonify({"message": "Citation supprimée"}), 200
```

**Chargement initial des données** :
```python
if not redis_client.exists("quotes:1"):
    if os.path.exists(CSV_FILE_QUOTES):
        print("Citations trouvées")
        with open(CSV_FILE_QUOTES, mode='r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            for row in reader:
                quote=row['quote']
                quote_id = redis_client.incr("quote_id")
                redis_client.hset(f"quotes:{quote_id}", mapping={"quote": quote})
                redis_client.sadd("quotes", f"quotes:{quote_id}")
    else:
        print("/!\ Pas de CSV trouver pour les citations /!\")
```

### 3.2.3 Search Service

**Fonctionnalités** :
- Recherche de citations par mots-clés
- Filtrage des résultats
- Recherche insensible à la casse
- Authentification requise
- Vérification de santé

**Technologies** :
- **Langage** : Python 3.12
- **Framework** : Flask
- **Base de données** : Redis
- **Documentation** : Flasgger (Swagger)

**Endpoints** :
- `GET /search?keyword=<mot>` - Recherche de citations par mot-clé (authentification requise)
- `GET /search/health` - Vérification de santé du service

**Exemple de code réel** :
```python
@app.route('/search', methods=['GET'])
@require_auth
def search_quotes():
    keyword = request.args.get("keyword")
    if not keyword:
        return jsonify({"error": "Mot-clé requis"}), 400
    members = redis_client.smembers("quotes")
    filtered_quotes = []
    for member in members:
        quote_object = redis_client.hgetall(member)
        quote = quote_object.get("quote","")
        if keyword.lower() in quote.lower():
            filtered_quotes.append(quote)
    return jsonify(filtered_quotes), 200
```

**Fonctionnement détaillé** :
1. Récupération du paramètre `keyword` depuis la requête
2. Validation du paramètre (doit être présent)
3. Récupération de tous les IDs de citations depuis le set Redis `quotes`
4. Pour chaque citation, récupération des données complètes
5. Filtrage des citations contenant le mot-clé (recherche insensible à la casse)
6. Retour des citations filtrées au format JSON

## 3.3 Stockage des données

### 3.3.1 Redis

**Choix technique** : Redis a été choisi pour sa simplicité, ses performances et sa compatibilité avec les besoins du projet.

**Configuration** :
- **Version** : Redis 8
- **Port** : 6379
- **Base de données** : DB 0 (par défaut)
- **Persistance** : Configuration par défaut (RDB)

**Structure des données réelles** :

```
# Utilisateurs - Set contenant tous les IDs d'utilisateurs
users: {users:1, users:2, ...}

# Utilisateurs - Hash contenant les informations pour chaque utilisateur
user:{id}:
  - id: "1"
  - name: "Alice"
  - password: "inWonderland"

# Citations - Set contenant tous les IDs de citations
quotes: {quotes:1, quotes:2, ...}

# Citations - Hash contenant les informations pour chaque citation
quotes:{id}:
  - user_id: "1"
  - quote: "Citation exemple"

# Tokens d'authentification - Set contenant tous les tokens valides
token: {token:abc123..., token:def456..., ...}

# Tokens d'authentification - Hash contenant les informations pour chaque token
token:{token_value}:
  - id: "token_value"
  - name: "user_name"

# Compteur automatique pour les IDs de citations
quote_id: 42  # Valeur incrémentée automatiquement
```

**Chargement initial des données** :

Le système charge automatiquement les données depuis des fichiers CSV au démarrage :

1. **Utilisateurs** : Si le set `users` n'existe pas, chargement depuis `CSV_FILE_USERS`
2. **Citations** : Si la citation `quotes:1` n'existe pas, chargement depuis `CSV_FILE_QUOTES`
3. **Tokens admin** : Les clés définies dans `ADMIN_KEY` sont ajoutées comme tokens valides

**Exemple de chargement initial des utilisateurs** :
```python
if not redis_client.exists("users"):
    if os.path.exists(CSV_FILE_USERS):
        with open(CSV_FILE_USERS, mode='r', encoding='utf-8') as file:
            reader = csv.DictReader(file)
            for row in reader:
                uid, name, password = row['id'], row['name'], row['password']
                redis_client.hset(f"users:{uid}", mapping={"id": uid,"name": name, "password": password})
                redis_client.sadd("users", f"users:{uid}")

# Création des tokens admin
if not redis_client.exists("token"):
    for uuid in ADMIN_KEY:
        redis_client.hset(
            f"token:{uuid}",
            mapping={
                "id": uuid,
                "name": "admin",
            }
        )
        redis_client.sadd("token", f"token:{uuid}")
```

**Exemple de déploiement Redis** :
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis-deployment
  namespace: haddock
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - name: redis
        image: redis:8
        ports:
        - containerPort: 6379
```

### 3.3.2 Persistance des données

**Configuration actuelle** :
- Les données sont stockées dans le pod Redis
- Pas de configuration explicite de PersistentVolumeClaim

**Améliorations prévues** :
- Configuration de PersistentVolumeClaims pour Redis
- Mise en place de sauvegardes régulières
- Configuration de stratégies de rétention

## 3.4 Réseau et reverse proxy

### 3.4.1 Traefik

**Fonctionnalités** :
- Reverse proxy et load balancer
- Routage dynamique des requêtes
- Terminaison SSL
- Dashboard de monitoring
- Rate limiting (configurable)

**Configuration Docker Compose** :
```yaml
services:
  traefik:
    image: "traefik"
    container_name: "traefik"
    restart: unless-stopped
    security_opt:
      - no-new-privileges:true
    networks:
      - proxy
    command:
      - "--providers.docker=true"
      - "--api.insecure=true"
      - "--providers.docker.exposedbydefault=false"
      - "--providers.docker.network=proxy"
      - "--entryPoints.web.address=:80"
      - "--entryPoints.haddock.address=:5000"
    ports:
      - "80:80"
      - "5000:5000"
      - "8080:8080"
    volumes:
      - "/var/run/docker.sock:/var/run/docker.sock:ro"
```

### 3.4.2 Configuration réseau

**Réseau Docker** :
```yaml
networks:
  proxy:
    name: proxy
```

**Fonctionnement** :
1. Tous les services sont connectés au réseau `proxy`
2. Traefik découvre automatiquement les services via Docker
3. Les requêtes sont routées en fonction des labels Docker
4. Le trafic est isolé dans le réseau Kubernetes

### 3.4.3 Labels Traefik

Exemple de configuration pour le service quotes :
```yaml
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.quotes.rule=PathPrefix(`/quotes`)"
  - "traefik.http.routers.quotes.entrypoints=haddock"
  - "traefik.http.services.quotes.loadbalancer.server.port=5000"
```

## 3.5 Sécurité

### 3.5.1 Mesures de sécurité implémentées

1. **Authentification** :
   - Système de tokens basé sur Redis
   - Vérification des tokens pour les endpoints sensibles
   - Décorateur `@require_auth` pour la protection

2. **Images Docker sécurisées** :
   - Utilisation d'images minimales (`python:3.12-slim`)
   - Exécution avec utilisateurs non-root
   - Suppression des privilèges root

3. **Configuration Traefik** :
   - Options de sécurité Docker (`no-new-privileges:true`)
   - Isolation réseau
   - Possibilité de rate limiting

4. **Kubernetes** :
   - Isolation via namespace
   - Gestion des secrets
   - Configuration de securityContext

### 3.5.2 Exemple de Dockerfile sécurisé

```dockerfile
FROM python:3.12-slim
LABEL org.opencontainers.image.source=https://github.com/olivinfo/sae503-kc-md
WORKDIR /app

RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y curl --no-install-recommends

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

RUN adduser user
USER user

COPY quotes/ .
COPY data/ .

ENV REDIS_HOST="backend-redis"

EXPOSE 5000

HEALTHCHECK --interval=5s --timeout=2s --retries=2 --start-period=5s CMD curl --fail http://localhost:5000/quotes/health || exit 1

CMD ["python", "quotes.py"]
```

### 3.5.3 Configuration de sécurité Kubernetes

```yaml
securityContext:
  runAsNonRoot: true
  runAsUser: 1000
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
```

### 3.5.4 Améliorations de sécurité prévues

1. **Secrets** : Externalisation complète dans Kubernetes Secrets
2. **Rate Limiting** : Activation et configuration dans Traefik
3. **Network Policies** : Restriction du trafic entre pods
4. **Authentification** : Migration vers JWT ou OAuth2
5. **Monitoring** : Configuration de logs et alertes de sécurité

Voir le fichier [SECURITY.md](../../../SECURITY.md) pour une analyse complète de la sécurité.