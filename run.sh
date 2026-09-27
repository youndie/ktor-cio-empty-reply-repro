#!/usr/bin/env bash
# Builds both targets, puts the same load on the native server and then on the JVM one, and gives a verdict.
#
#   ./run.sh [seconds] [gradle arguments...]
#   ./run.sh 1200 -PktorVersion=3.7.0
#
# Linux x86-64 only: the native server is linuxX64. Needs a JDK, curl and python3; the wrapper fetches Gradle.
# Exit: 0 not reproduced, 1 reproduced, 2 no verdict (the build, the stand, the control or the length of the run).
set -uo pipefail
cd "$(dirname "$0")"
SECONDS_TO_RUN=${1:-1200}
[ $# -gt 0 ] && shift
PORT=18108
CLIENTS=64
# Lost answers per million native requests, measured on 2026-09-27: 40 in 4 772 201 (results.md). Only used to say
# whether a clean run was long enough to mean anything.
KNOWN_RATE_PER_MILLION=8.38
# Below this many requests a second the load is not the load that reproduced it (about 1 300/s on 2026-09-27).
MIN_RATE=300

./gradlew --console=plain -q linkReleaseExecutableLinuxX64 compileKotlinJvm writeJvmRuntimeClasspath "$@" \
    || { echo "no verdict: the build failed"; exit 2; }
CP=$(cat build/jvmRuntimeClasspath.txt)
KOTLIN=$(cat build/kotlinVersion.txt)
KTOR=$(tr ':' '\n' <<< "$CP" | sed -n 's|.*/ktor-server-cio-jvm-\([0-9][^/]*\)\.jar$|\1|p' | head -1)
HOST="$(uname -r), $(ldd --version | head -1 | sed 's/.* //') glibc, curl $(curl --version | head -1 | cut -d' ' -f2)"
echo "Kotlin $KOTLIN, Ktor $KTOR | $HOST | $SECONDS_TO_RUN s per build, $CLIENTS clients"

# The counter's own control: a listener that reads the request and closes without a byte must come out as curl 52,
# or a clean run below would only mean that this curl never reports one.
python3 -c '
import socket
s = socket.socket(); s.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
s.bind(("127.0.0.1", 18109)); s.listen(1); s.settimeout(10)
c, _ = s.accept(); c.recv(65536); c.close()' &
for _ in $(seq 1 50); do
    curl -s -o /dev/null --max-time 5 -X POST http://127.0.0.1:18109/ --data-binary x; rc=$?
    [ "$rc" = 7 ] || break
    sleep 0.1
done
wait
[ "$rc" = 52 ] || { echo "no verdict: an empty reply came out as curl $rc, not 52"; exit 2; }

client() { # until → one "http_code curl_exit" line per request
    while [ "$(date +%s%3N)" -lt "$1" ]; do
        code=$(curl -s -o /dev/null -w '%{http_code}' --max-time 30 -X POST "http://127.0.0.1:$PORT/records" \
            --data-binary x)
        echo "$code $?"
        sleep 0.02
    done
}

load() { # name command... → sets TALLY="requests lost other"
    local name=$1 work pid until c workers=()
    shift
    work=$(mktemp -d /tmp/ktor-cio-empty-reply-XXXX)
    "$@" > "$work/server.log" 2>&1 &
    pid=$!
    for _ in $(seq 1 150); do
        curl -s -o /dev/null -X POST "http://127.0.0.1:$PORT/records" --data-binary w && break
        sleep 0.2
    done
    until=$(( $(date +%s%3N) + SECONDS_TO_RUN * 1000 ))
    for c in $(seq 1 $CLIENTS); do client "$until" > "$work/rc.$c" & workers+=($!); done
    wait "${workers[@]}"
    # The native server closes its listener on SIGTERM but its process does not exit (Ktor 3.6.0, 2026-09-27), so
    # it gets ten seconds and then SIGKILL. Not what this measures, and it happens after the load has ended.
    kill "$pid" 2> /dev/null
    for _ in $(seq 1 100); do kill -0 "$pid" 2> /dev/null || break; sleep 0.1; done
    kill -KILL "$pid" 2> /dev/null
    wait "$pid" 2> /dev/null
    # Lost: curl 52 (empty reply) or 56 (reset while receiving). Other: anything that is neither a 200 nor lost,
    # which is the stand failing (a dead server gives curl 7), not the thing measured.
    TALLY=$(cat "$work"/rc.* | awk '{ n++ } $2 == 52 || $2 == 56 { lost++; next } !($1 == 200 && $2 == 0) { other++ }
        END { print n + 0, lost + 0, other + 0 }')
    echo "[$name] requests, lost, other: $TALLY | $(cat "$work"/rc.* | sort | uniq -c | sort -rn | awk '{ printf "%s×(%s %s) ", $1, $2, $3 }')"
}

load native ./build/bin/linuxX64/releaseExecutable/ktor-cio-empty-reply-repro.kexe
read -r n_total n_lost n_other <<< "$TALLY"
load jvm java -cp "build/classes/kotlin/jvm/main:$CP" MainKt
read -r j_total j_lost j_other <<< "$TALLY"

verdict() { # exit code, text
    echo "| $(date +%F) | $HOST | $KOTLIN | $KTOR | $SECONDS_TO_RUN | $n_lost / $n_total | $j_lost / $j_total | $2 |"
    exit "$1"
}
[ "$n_other" = 0 ] && [ "$j_other" = 0 ] || verdict 2 "no verdict: the stand answered something other than 200"
floor=$(( MIN_RATE * SECONDS_TO_RUN ))
[ "$n_total" -ge "$floor" ] && [ "$j_total" -ge "$floor" ] || verdict 2 "no verdict: under $MIN_RATE requests/s"
[ "$j_lost" = 0 ] || verdict 2 "no verdict: the JVM control lost answers too"
[ "$n_lost" = 0 ] || verdict 1 "reproduced"
expected=$(awk -v n="$n_total" -v r="$KNOWN_RATE_PER_MILLION" 'BEGIN { printf "%.1f", n * r / 1e6 }')
if awk -v e="$expected" 'BEGIN { exit !(e < 5) }'; then
    verdict 2 "no verdict: $expected lost expected at the known rate, too few for a zero to mean anything; run longer"
fi
verdict 0 "not reproduced: $expected lost expected at the known rate, chance of zero if unchanged $(awk -v e="$expected" 'BEGIN { printf "%.1g", exp(-e) }')"
