#!/bin/sh

PID_FILE="/tmp/appjs.pid"
LOG_FILE="/home/USERNAME/run.log"

if [ ! -f "$PID_FILE" ]; then
  echo "[ERROR] PID file not found. Process may not be running." >> "$LOG_FILE"
  echo "No running process found."
  exit 1
fi

PID=$(cat "$PID_FILE")

if kill "$PID" 2>/dev/null; then
  echo "[INFO] Successfully stopped app.js loop (PID=$PID) at $(date)." >> "$LOG_FILE"
  rm -f "$PID_FILE"
  echo "Stopped process with PID $PID."
else
  echo "[ERROR] Failed to stop process with PID $PID. It may have already exited." >> "$LOG_FILE"
  rm -f "$PID_FILE"
  echo "Process not running, cleaned up PID file."
fi
