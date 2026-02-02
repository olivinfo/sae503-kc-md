# 2. Architecture Globale

## 2.1 Vue d'ensemble

L'architecture du projet "Citations Haddock" est basée sur une approche moderne de microservices, orchestrée par Kubernetes et sécurisée selon les meilleures pratiques du domaine.

### Architecture en couches

```txt
┌───────────────────────────────────────────────────────────────┐
│                       Utilisateurs Finaux                     │
└───────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────┐
│                       Reverse Proxy (Traefik)                 │
└───────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────┐
│                        Microservices Applications             │
│  ┌─────────────┐    ┌─────────────┐    ┌───────────────────┐  │
│  │  Users      │    │  Quotes     │    │  Search           │  │
│  │  Service    │    │  Service    │    │  Service          │  │
│  └─────────────┘    └─────────────┘    └───────────────────┘  │
└───────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────┐
│                       Base de données (Redis)                 │
└───────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌───────────────────────────────────────────────────────────────┐
│                        Infrastructure Kubernetes              │
│  ┌─────────────┐    ┌─────────────┐    ┌───────────────────┐  │
│  │  Namespace  │    │  Pods       │    │  Services         │  │
│  │  (haddock)  │    │  &          │    │  & Ingress        │  │
│  └─────────────┘    │  Containers │    └───────────────────┘  │
│                     └─────────────┘                           │
└───────────────────────────────────────────────────────────────┘
```

## 2.2 Composants principaux

### 2.2.1 Microservices

L'application est divisée en trois microservices principaux :

1. **Users Service** : Gestion des utilisateurs
   - Endpoints : `/users`
   - Fonctionnalités : Création, lecture, mise à jour et suppression des utilisateurs
   - Technologie : Flask (Python)

2. **Quotes Service** : Gestion des citations
   - Endpoints : `/quotes`
   - Fonctionnalités : Ajout, suppression et récupération des citations
   - Technologie : Flask (Python)

3. **Search Service** : Recherche de citations
   - Endpoints : `/search`
   - Fonctionnalités : Recherche de citations par mots-clés
   - Technologie : Flask (Python)

### 2.2.2 Infrastructure

1. **Kubernetes** : Orchestrateur de conteneurs
   - Gestion des pods, services et ingress
   - Isolation via namespaces
   - Scalabilité horizontale

2. **Traefik** : Reverse proxy et load balancer
   - Routage des requêtes HTTP
   - Terminaison SSL
   - Rate limiting (configurable)

3. **Redis** : Base de données
   - Stockage des données utilisateurs et citations
   - Cache pour les recherches
   - Persistance des données

4. **Docker** : Conteneurisation
   - Images Docker pour chaque microservice
   - Environnements isolés et reproductibles

## 2.3 Flux de données

### 2.3.1 Flux principal

```txt
1. L'utilisateur envoie une requête HTTP à l'application
2. Traefik reçoit la requête et la route vers le microservice approprié
3. Le microservice traite la requête et interagit avec Redis si nécessaire
4. Le microservice renvoie une réponse au client via Traefik
```

### 2.3.2 Exemple détaillé : Ajout d'une citation

```txt
┌─────────────┐       ┌─────────────────┐       ┌─────────────┐
│             │       │                 │       │             │
│  Client     │─────▶│  Traefik         │─────▶│  Quotes     │
│             │       │                 │       │  Service    │
└─────────────┘       └─────────────────┘       └─────────────┘
        ▲                     ▲                             │
        │                     │                             ▼
        │                     │                   ┌─────────────┐
        │                     │                   │             │
        │                     │                   │  Redis      │
        │                     │                   │             │
        │                     │                   └─────────────┘
        │                     │                             ▲
        │                     │                             │
┌─────────────┐       ┌─────────────────┐       ┌─────────────┐
│             │       │                 │       │             │
│  Client     │◀──────│  Traefik       │◀──────│  Quotes     │
│             │       │                 │       │  Service    │
└─────────────┘       └─────────────────┘       └─────────────┘
```

### 2.3.3 Exemple détaillé : Processus de login et génération de token

```txt
┌─────────────┐       ┌─────────────────┐       ┌─────────────┐
│             │       │                 │       │             │
│  Client     │─────▶│  Traefik         │─────▶│  Users      │
│             │       │                 │       │  Service    │
└─────────────┘       └─────────────────┘       └─────────────┘
        ▲                     ▲                             │
        │                     │                             ▼
        │                     │                   ┌─────────────┐
        │                     │                   │             │
        │                     │                   │  Redis      │
        │                     │                   │  (users)    │
        │                     │                   └─────────────┘
        │                     │                             ▲
        │                     │                             │
        │                     │                   ┌─────────────┐
        │                     │                   │             │
        │                     │                   │  Users      │
        │                     │                   │  Service    │
        │                     │                   │  (génère    │
        │                     │                   │   token)    │
        │                     │                   └─────────────┘
        │                     │                             │
        │                     │                             ▼
        │                     │                   ┌─────────────┐
        │                     │                   │             │
        │                     │                   │  Redis      │
        │                     │                   │  (token)    │
        │                     │                   └─────────────┘
        │                     │                             ▲
        │                     │                             │
┌─────────────┐       ┌─────────────────┐       ┌─────────────┐
│             │       │                 │       │             │
│  Client     │◀──────│  Traefik       │◀──────│  Users      │
│  (reçoit    │       │                 │       │  Service    │
│   token)    │       │                 │       │             │
└─────────────┘       └─────────────────┘       └─────────────┘
```

## 2.4 Diagrammes d'architecture

### 2.4.1 Diagramme de déploiement Kubernetes

```mermaid
graph TD
    subgraph Kubernetes Cluster
        subgraph Namespace: haddock
            TraefikPod[Traefik Pod] -->|Route| UsersService
            TraefikPod -->|Route| QuotesService
            TraefikPod -->|Route| SearchService
            
            UsersService[Users Service Pod] --> RedisService
            QuotesService[Quotes Service Pod] --> RedisService
            SearchService[Search Service Pod] --> RedisService
            
            RedisService[Redis Pod] --> RedisPVC[Persistent Volume]
        end
    end
    
    Client[Client] -->|HTTP| TraefikPod
```

### 2.4.2 Diagramme de composants

```mermaid
graph TD
    Client[Client] -->|HTTP Request| Traefik
    Traefik -->|Route /users| UsersService
    Traefik -->|Route /quotes| QuotesService  
    Traefik -->|Route /search| SearchService
    
    UsersService --> Redis[(Redis DB)]
    QuotesService --> Redis
    SearchService --> Redis
```

### 2.4.3 Diagramme de séquence

**Processus d'ajout de citation avec authentification** :

```mermaid
sequenceDiagram
    participant Client
    participant Traefik
    participant QuotesService
    participant Redis
    
    Client->>Traefik: POST /quotes (avec token)
    Traefik->>QuotesService: Route la requête
    QuotesService->>Redis: Vérifie le token (token:abc123...)
    Redis-->>QuotesService: Token valide
    QuotesService->>Redis: Stocke la nouvelle citation
    Redis-->>QuotesService: Confirmation
    QuotesService-->>Traefik: Réponse 201 Created
    Traefik-->>Client: Retourne la réponse
```

**Processus de login et génération de token** :

```mermaid
sequenceDiagram
    participant Client
    participant Traefik
    participant UsersService
    participant Redis
    
    Client->>Traefik: POST /users/login (avec credentials)
    Traefik->>UsersService: Route la requête
    UsersService->>Redis: Recherche utilisateur
    Redis-->>UsersService: Retourne les données utilisateur
    UsersService->>UsersService: Génère token aléatoire
    UsersService->>Redis: Stocke le nouveau token
    Redis-->>UsersService: Confirmation
    UsersService-->>Traefik: Réponse 200 avec token
    Traefik-->>Client: Retourne {"token": "abc123...", "user_id": "1"}
```

## 2.5 Matrice de flux réseau

| Source          | Destination      | Protocole | Port   | Description                     |
|-----------------|------------------|-----------|--------|---------------------------------|
| Client          | Traefik          | HTTP      | 80     | Accès à l'application           |
| Client          | Traefik          | HTTP      | 5000   | Accès alternatif                |
| Traefik         | Users Service    | HTTP      | 5000   | Routage vers le service users   |
| Traefik         | Quotes Service   | HTTP      | 5000   | Routage vers le service quotes  |
| Traefik         | Search Service   | HTTP      | 5000   | Routage vers le service search  |
| Users Service   | Redis            | TCP       | 6379   | Accès à la base de données      |
| Quotes Service  | Redis            | TCP       | 6379   | Accès à la base de données      |
| Search Service  | Redis            | TCP       | 6379   | Accès à la base de données      |

## 2.6 Matrice des endpoints et authentification

| Service         | Endpoint                | Méthode | Authentification | Description                     |
|-----------------|-------------------------|---------|------------------|---------------------------------|
| Users           | `/`                     | GET     | Non              | Point d'entrée                  |
| Users           | `/users`                | GET     | Oui              | Liste des utilisateurs         |
| Users           | `/users/all`            | GET     | Non              | Liste complète des utilisateurs|
| Users           | `/users/token`          | GET     | Non              | Liste des tokens               |
| Users           | `/users`                | POST    | Oui              | Création d'utilisateur         |
| Users           | `/users/login`          | POST    | Non              | Connexion utilisateur          |
| Users           | `/users/health`         | GET     | Non              | Vérification de santé          |
| Quotes          | `/quotes`               | GET     | Non              | Liste des citations            |
| Quotes          | `/quotes`               | POST    | Oui              | Ajout de citation              |
| Quotes          | `/quotes/<id>`          | DELETE  | Oui              | Suppression de citation        |
| Quotes          | `/quotes/health`        | GET     | Non              | Vérification de santé          |
| Search          | `/search`               | GET     | Oui              | Recherche de citations         |
| Search          | `/search/health`        | GET     | Non              | Vérification de santé          |

## 2.6 Topologie réseau

```txt
┌─────────────────────────────────────────────────────────────────────┐
│                        Réseau Kubernetes (proxy)                    │
│                                                                     │
│  ┌─────────────┐    ┌─────────────┐    ┌─────────────┐    ┌───────┐ │
│  │             │    │             │    │             │    │       │ │
│  │  Traefik    │◀───▶│  Users    │    │  Quotes     │    │ Redis │ │
│  │  (Ingress)  │    │  Service    │    │  Service    │    │       │ │
│  │             │    │             │    │             │    │       │ │
│  └─────────────┘    └─────────────┘    └─────────────┘    └───────┘ │
│          ▲                                                          │
│          │                                                          │
│  ┌───────────────────────────────────────────────────────────────┐  │
│  │                   Réseau Externe (Internet)                   │  │
│  │                                                               │  │
│  │  ┌─────────────┐    ┌─────────────┐    ┌───────────────────┐  │  │
│  │  │             │    │             │    │                   │  │  │
│  │  │  Client 1   │    │  Client 2   │    │  Client N         │  │  │
│  │  │             │    │             │    │                   │  │  │
│  │  └─────────────┘    └─────────────┘    └───────────────────┘  │  │
│  └───────────────────────────────────────────────────────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```
