.PHONY: build down logs

install:
	@echo "Installation des depandances utillisateur..."
	pip install --no-cache-dir -r user-requirements.txt

build:
	@echo "Construction et lancement des conteneurs Docker..."
	docker compose up --build

test:
	@echo "Construction et lancement des conteneurs Docker..."
	docker compose up -d --build
	sleep 10
	pytest citations_haddock/test_citations_haddock.py
	docker compose down
down:
	@echo "Arrêt et suppression des conteneurs Docker..."
	docker compose down

logs:
	@echo "Affichage des logs des conteneurs Docker..."
	docker compose logs -f

lint:
	@echo "Analyse du code python"
	pylint --rcfile=.pylintrc .




