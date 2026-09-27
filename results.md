# Results

One line per run, newest last. `run.sh` prints the line; paste it here. Lost answers are shown as lost / requests.

| date | host (kernel, glibc, curl) | Kotlin | Ktor | seconds | native lost | JVM lost | verdict |
|---|---|---|---|---|---|---|---|
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | 11 / 1575338 | — | reproduced (native only) |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | 16 / 1557766 | — | reproduced (native only) |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | — | 0 / 1548235 | control (JVM only) |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | 13 / 1639097 | — | reproduced (native only) |

The first four lines predate `run.sh` and were run one build at a time, with an earlier version of the same load.
The host was Ubuntu 24.04 on WSL2, 20 cores, Java 25, and it was shared with other builds while the runs went on.
