source server/.venv/bin/activate
source server/set_env.sh
server/.venv/bin/uvicorn server.main:app --host 0.0.0.0 --port 8000 --workers 4

