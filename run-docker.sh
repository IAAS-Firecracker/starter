#!/bin/bash

set +e

# Configuration
CONFIG_FILE="docker-order.conf"
DEFAULT_DIRS=(
    "postgresql"
    # "rabbitmq"
    "service-config"
    "service-registry"
    "service-proxy"
    # "user-service-py"
    # "notification-service"
    # "service-cluster"
    # "service-system-image"
    # "service-vm-offer"
)

# Services dépendants de service-config
dependents=(
    "user-service-py"
    # "notification-service"
    # "service-cluster"
    # "service-system-image"
    # "service-vm-offer"
)

# Menu interactif
PS3='🔧 Choisissez une action : '
options=("Démarrer tous les services" "Arrêter tous les services" "Quitter")
select opt in "${options[@]}"; do
    case $REPLY in
        1) BUILD=true; ACTION='up -d'; VERBE='Démarré'; break;;
        2) ACTION=stop; VERBE='Arrêté'; break;;
        3) echo '🚪 Sortie du script'; exit 0;;
        *) echo '❌ Option invalide'; exit 1;;
    esac
done

BASEDIR="$(dirname "$0")"/..
echo "🛠️  Action choisie : $opt"
echo "📂 Exécution depuis: $(pwd)"

# Chargement de la configuration
if [ -f "$CONFIG_FILE" ]; then
    echo "🔍 Utilisation de la configuration $CONFIG_FILE"
    mapfile -t DIRECTORIES < "$CONFIG_FILE"
else
    echo "⚠️  Fichier $CONFIG_FILE non trouvé, utilisation de l'ordre par défaut"
    DIRECTORIES=("${DEFAULT_DIRS[@]}")
fi

success=()
fail=()

cd "$BASEDIR" || exit 1

# Fonction pour vérifier service-config
check_service_config() {
    if [ -d "service-config/" ]; then
        (cd "service-config" && docker-compose ps | grep -q 'Up')
        return $?
    else
        echo "❌ Le dossier service-config n'existe pas."
        return 1
    fi
}

for dir in "${DIRECTORIES[@]}"; do
    dir_path="$dir/"
    if [[ -f "${dir_path}docker-compose.yml" ]]; then
        echo "\n🚀 Traitement de $dir"
        
        if [ "$BUILD" = true ]; then
            echo "🔨 Construction de $dir"
            (cd "$dir_path" && docker-compose build)
            build_status=$?
            
            if [ $build_status -ne 0 ]; then
                echo "🤬 Échec de construction: $dir"
                fail+=("$dir")
                continue
            fi
        fi
        
        # Vérification pour les services dépendants
        if [ "$ACTION" = "up -d" ] && [[ " ${dependents[@]} " =~ " $dir " ]]; then
            echo "🔍 Vérification que service-config est démarré..."
            while ! check_service_config; do
                echo "⚠️ service-config n'est pas démarré. Tentative de démarrage..."
                #(cd "service-config" && docker-compose up -d)
                echo "⏳ Attente de 10 secondes..."
                sleep 10
            done
            echo "✅ service-config est démarré. Démarrage de $dir..."
        fi
        
        echo "🚀 Exécution de la commande: $ACTION pour $dir"
        (cd "$dir_path" && docker-compose $ACTION)
        status=$?
        
        if [ $status -eq 0 ]; then
            echo "😇 Succès: $dir $VERBE"
            success+=("$dir")
        else
            echo "🤬 Échec: $dir"
            fail+=("$dir")
        fi
    else
        echo "⚠️  Dossier $dir ignoré (docker-compose.yml manquant)"
    fi
done

set -e

echo "\n📊 Rapport final :"
echo "-------------------"
printf "\e[32m"
for service in "${success[@]}"; do
  echo "✓ $service $VERBE"
done
printf "\e[31m"
for service in "${fail[@]}"; do
  echo "✗ $service"
done
printf "\e[0m\n"
echo "Services réussis: ${#success[@]} | Échecs: ${#fail[@]}"