#!/bin/bash

# cleanup.sh
# Script pour nettoyer toutes les ressources du projet SAE503

echo "Nettoyage des ressources du projet SAE503..."

# Vérifier si kubectl est installé
if ! command -v kubectl &> /dev/null; then
    echo "Erreur: kubectl n'est pas installé."
    exit 1
fi

# Supprimer toutes les ressources avec Kustomize
kubectl delete -k .

echo "Attente que les ressources soient supprimées..."
sleep 10

# Vérifier que tout a été supprimé
echo "Ressources restantes:"
kubectl get all

echo "Nettoyage terminé!"
