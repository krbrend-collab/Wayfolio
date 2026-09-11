#!/bin/zsh

starter_directory="${0:A:h}"
cd "$starter_directory/Host" || exit 1

# Always launch the code beside this command. An older host can otherwise remain
# alive on port 8787 and keep serving an outdated launcher after an update.
existing_host_pids=($(lsof -tiTCP:8787 -sTCP:LISTEN 2>/dev/null))
if (( ${#existing_host_pids[@]} )); then
  echo "Updating the running Wayfolio host…"
  kill -TERM "${existing_host_pids[@]}" 2>/dev/null
  for attempt in {1..20}; do
    if ! lsof -tiTCP:8787 -sTCP:LISTEN >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
fi

npm start &
host_process=$!
trap 'kill "$host_process" 2>/dev/null' EXIT INT TERM

for attempt in {1..30}; do
  if curl --silent --fail http://localhost:8787/launcher >/dev/null 2>&1; then
    open http://localhost:8787/launcher
    wait "$host_process"
    exit $?
  fi
  sleep 0.25
done

echo "Wayfolio could not start. Keep this window open and share its message with the development chat."
wait "$host_process"
