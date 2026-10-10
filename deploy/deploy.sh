#!/usr/bin/env bash
set -Eeuo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
cd /opt/vpe03-demo
exec 9>.deploy.lock
flock -w 120 9
sha="${SSH_ORIGINAL_COMMAND:-}"
[[ "$sha" =~ ^[0-9a-f]{40}$ ]] || { echo 'Expected commit SHA'; exit 2; }
image="vpe03-demo:$sha"
# stdin comes from docker save | gzip. The SSH key cannot open a shell.
gzip -dc | docker load
docker image inspect "$image" >/dev/null
old=$(docker inspect vpe03-demo --format '{{.Config.Image}}' 2>/dev/null || true)
run() {
  docker run -d --name vpe03-demo --restart unless-stopped \
    --memory 96m --memory-swap 96m --cpus 0.25 --pids-limit 32 \
    --read-only --cap-drop ALL --security-opt no-new-privileges \
    --log-opt max-size=2m --log-opt max-file=2 \
    -p 18083:8080 "$1"
}
if [[ -n "$old" ]]; then docker rm -f vpe03-demo; fi
success=false
if run "$image"; then
  for attempt in {1..20}; do
    if curl -fsS --max-time 2 http://127.0.0.1:18083/health | python3 -c 'import json,sys; assert json.load(sys.stdin)["commit"] == sys.argv[1]' "$sha"; then
      success=true
      break
    fi
    sleep 2
  done
fi
if [[ "$success" != true ]]; then
  docker logs --tail 30 vpe03-demo || true
  docker rm -f vpe03-demo || true
  if [[ -n "$old" ]]; then run "$old"; fi
  echo 'Deployment failed; previous image restarted if available.'
  exit 1
fi
printf '%s\n' "$old" > previous-image
printf '%s\n' "$image" > current-image
# Retain current and previous project images only. Never prune shared Docker data.
while read -r candidate; do
  if [[ "$candidate" != "$image" && "$candidate" != "$old" ]]; then
    docker image rm "$candidate" || true
  fi
done < <(docker image ls vpe03-demo --format '{{.Repository}}:{{.Tag}}')
echo "DEPLOYED $sha"
