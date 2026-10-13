#!/bin/bash
# /usr/bin/time -v comparison, BCC vs pythonbpf sys_enter_execve
# Writes to /root/experiment/timev/ (separate from the perf stat out/ dirs).
set -u
N_LIST="${N_LIST:-20 50 100 1000 2000 2000000}"
VENV=/root/experiment/.venv/bin/python
TRIGGER=/usr/local/bin/gen_exec
OUT=/root/experiment/timev
mkdir -p "$OUT"

run_one() {
  local impl="$1" dir="$2" n="$3"
  local base="${OUT}/${impl}_N${n}"
  local tout="${base}.timev.txt"      # /usr/bin/time -v report (stderr)
  local sout="${base}.stdout.txt"     # program stdout
  local slog="${base}.log"

  # start program under /usr/bin/time -v
  setsid bash -c "cd '$dir'; exec /usr/bin/time -v '$VENV' perf_timed_execve.py" \
      > "$sout" 2> "$tout" &
  local pgid=$!

  # wait for attach
  local armed=0
  for _ in $(seq 1 600); do
    if grep -q "Starting to poll" "$sout" 2>/dev/null; then armed=1; break; fi
    sleep 0.2
  done
  echo "armed=$armed" > "$slog"
  sleep 0.3

  # fire trigger as operator (uid 1000)
  local t0 t1
  t0=$(date +%s.%N)
  sudo -u operator "$TRIGGER" "$n" > /dev/null 2>&1
  t1=$(date +%s.%N)
  echo "trigger_wall=$(echo "$t1 - $t0" | bc)" >> "$slog"

  # drain, then stop
  sleep 2
  kill -INT -"$pgid" 2>/dev/null
  sleep 0.5
  kill -KILL -"$pgid" 2>/dev/null
  wait "$pgid" 2>/dev/null

  echo "events=$(grep -c 'UID 1000' "$sout" 2>/dev/null || echo 0)" >> "$slog"
  echo "[DONE] $impl N=$n armed=$armed events=$(grep -c 'UID 1000' "$sout" 2>/dev/null || echo 0)"
}

for N in $N_LIST; do
  run_one pythonbpf /root/experiment/without_map/pythonbpf/sys_enter_execve "$N"
  run_one bcc      /root/experiment/without_map/bcc/sys_enter_execve      "$N"
done
echo ALL-DONE
