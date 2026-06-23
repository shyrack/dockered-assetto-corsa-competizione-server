#!/bin/sh
set -e

cleanup() {
    echo "[entrypoint] Shutting down..."
    wineserver -k 2>/dev/null || true
    [ -n "$XVFB_PID" ] && kill $XVFB_PID 2>/dev/null || true
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

Xvfb :99 -screen 0 1024x768x16 +extension RANDR &
XVFB_PID=$!

for _ in 1 2 3 4 5 6 7 8 9 10; do
    [ -e /tmp/.X99-lock ] && break
    sleep 0.5
done

if ! kill -0 $XVFB_PID 2>/dev/null; then
    echo '[entrypoint] ERROR: Xvfb failed to start' >&2
    exit 1
fi

wineboot -u

wine accServer.exe &
ACC_PID=$!
wait $ACC_PID
EXIT_CODE=$?

wineserver -k 2>/dev/null || true
kill $XVFB_PID 2>/dev/null || true

if [ $EXIT_CODE -ne 0 ]; then
    echo "[entrypoint] ACC server exited with code $EXIT_CODE" >&2
fi

exit $EXIT_CODE
