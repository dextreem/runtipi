#!/usr/bin/env bash
set -e  # Exit immediately if a command exits with a non-zero status.

# use greadlink instead of readlink on osx
if [[ "$(uname)" == "Darwin" ]]; then
  readlink=greadlink
else
  readlink=readlink
fi

ROOT_FOLDER="$($readlink -f $(dirname "${BASH_SOURCE[0]}")/..)"
STATE_FOLDER="${ROOT_FOLDER}/state"
DOMAIN=local

INTERNAL_IP="$(hostname -I | awk '{print $1}')"
PUID="$(id -u)"
PGID="$(id -g)"
TZ="$(cat /etc/timezone)"

if [[ $UID != 0 ]]; then
    echo "Tipi must be started as root"
    echo "Please re-run this script as"
    echo "  sudo ./scripts/start"
    exit 1
fi

# Configure Umbrel if it isn't already configured
if [[ ! -f "${STATE_FOLDER}/configured" ]]; then
  "${ROOT_FOLDER}/scripts/configure.sh"
fi

# Copy the app state if it isn't here
if [[ ! -d "${STATE_FOLDER}/apps.json" ]]; then
  cp "${STATE_FOLDER}/apps.example.json" "${STATE_FOLDER}/apps.json"
fi

export DOCKER_CLIENT_TIMEOUT=240
export COMPOSE_HTTP_TIMEOUT=240

# Store paths to intermediary config files
ENV_FILE="$ROOT_FOLDER/templates/.env"

# Remove intermediary config files
[[ -f "$ENV_FILE" ]] && rm -f "$ENV_FILE"

# Copy template configs to intermediary configs
[[ -f "$ROOT_FOLDER/templates/.env-sample" ]] && cp "$ROOT_FOLDER/templates/.env-sample" "$ENV_FILE"

echo "Generating config files..."
for template in "${ENV_FILE}"; do
  sed -i "s/<internal_ip>/${INTERNAL_IP}/g" "${template}"
  sed -i "s/<puid>/${PUID}/g" "${template}"
  sed -i "s/<pgid>/${PGID}/g" "${template}"
  sed -i "s/<tz>/${TZ}/g" "${template}"
done

mv -f "$ENV_FILE" "$ROOT_FOLDER/.env"

ansible-playbook ansible/start.yml -i ansible/hosts -K

# Run docker-compose
docker-compose --env-file "${ROOT_FOLDER}/.env" up --detach --remove-orphans --build || {
  echo "Failed to start containers"
  exit 1
}

echo "Tipi is now running"
echo "To stop it, run sudo ./scripts/stop.sh"
echo "Visit http://${INTERNAL_IP}:3000 to view the dashboard"
# Get field from json file
# function get_json_field() {
#     local json_file="$1"
#     local field="$2"

#     echo $(jq -r ".${field}" "${json_file}")
# }

# str=$(get_json_field ${STATE_FOLDER}/apps.json installed)
# apps_to_start=($str)

# for app in "${apps_to_start[@]}"; do
#     "${ROOT_FOLDER}/scripts/app.sh" start $app
# done

