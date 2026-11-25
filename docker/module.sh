# Inspect installed package identities, never Docker CLI config or authentication.
package_installed() {
    [[ $(dpkg-query -W -f='${Status}' "$1" 2>/dev/null) == 'install ok installed' ]]
}
packages=()
ready=1
if package_installed docker-ce || package_installed docker-ce-cli || package_installed containerd.io; then
    family=upstream
    package_installed docker-ce || packages+=(docker-ce)
    package_installed docker-ce-cli || packages+=(docker-ce-cli)
    if ! docker compose version >/dev/null 2>&1; then packages+=(docker-compose-plugin); fi
elif package_installed docker.io; then
    family=ubuntu
    if ! docker compose version >/dev/null 2>&1; then packages+=(docker-compose-v2); fi
elif command -v docker >/dev/null || command -v dockerd >/dev/null || package_installed podman-docker; then
    family=unknown
    ready=0
    fail 'Unrecognized Docker installation; retain it and resolve Engine/Compose installation manually'
else
    family=ubuntu
    packages=(docker.io docker-compose-v2)
fi
if (( ${#packages[@]} )); then
    status planned "Native Docker Engine/Compose ($family): ${packages[*]}; no Desktop app"
    apt_install "${packages[@]}" || ready=0
else
    [[ $family == unknown ]] || status 'already configured' "Docker Engine/Compose packages ($family)"
fi
local_config "$DOTFILES_ROOT/docker/config.json.example" \
    "$CONFIG_HOME/docker/config.json" "${DOCKER_CONFIG:-$HOME/.docker}/config.json" || true
status 'already configured' 'Existing Docker authentication, daemon settings, group membership and container data retained'
if [[ $MODE != apply ]]; then
    status planned 'Check local service health after installation; offer start only with systemd available'
elif (( ! ready )); then
    status skipped 'Docker package prerequisites incomplete; no service activation attempted'
elif [[ -n ${DOCKER_HOST:-} || -n ${DOCKER_CONTEXT:-} ]]; then
    status skipped 'Remote/explicit Docker selection detected; local service activation skipped'
elif command -v systemctl >/dev/null && [[ -d /run/systemd/system ]]; then
    if systemctl is-active --quiet docker; then
        status 'already configured' 'Docker service active'
    elif confirm 'Start the local Docker service with sudo? No enable/restart or daemon changes.'; then
        privileged systemctl start docker || fail 'Docker service could not be started'
    else status skipped 'Docker service start'; fi
else
    status skipped 'systemd is unavailable in this environment. On WSL enable systemd separately, then start Docker explicitly.'
fi
