# Kill any already-running instance first - restarting without this would
# leave the old one bound to :8000 and the new one failing to start (or,
# worse, both answering requests on different ports/states).
pkill -f "uvicorn server.main:app" || true
sleep 1

source server/.venv/bin/activate
source server/set_env.sh
server/.venv/bin/uvicorn server.main:app --host 0.0.0.0 --port 8000 &

