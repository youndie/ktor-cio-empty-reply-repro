# Results

One line per run, newest last. `run.sh` prints the line; paste it here. Lost answers are shown as lost / requests.

| date | host (kernel, glibc, curl) | Kotlin | Ktor | seconds | native lost | JVM lost | verdict |
|---|---|---|---|---|---|---|---|
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | 11 / 1575338 | — | reproduced (native only) |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | 16 / 1557766 | — | reproduced (native only) |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | — | 0 / 1548235 | control (JVM only) |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | 13 / 1639097 | — | reproduced (native only) |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 20 | 1 / 27502 | 0 / 26887 | reproduced |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.5.2 | 20 | 0 / 8758 | 0 / 26753 | no verdict: the stand answered something other than 200 |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.5.2 | 20 | 0 / 11675 | 0 / 27025 | no verdict: the stand answered something other than 200 |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.5.2 | 20 | 0 / 12131 | 0 / 24679 | no verdict: the stand answered something other than 200 |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 20 | 0 / 25190 | 0 / 26212 | no verdict: 0.2 lost expected at the known rate, too few for a zero to mean anything; run longer |
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | 13 / 1377851 | 0 / 1037627 | reproduced |

The first four lines predate `run.sh` and were run one build at a time, with an earlier version of the same load.
The host was Ubuntu 24.04 on WSL2, 20 cores, Java 25, and it was shared with other builds while the runs went on.

The 20-second lines are smoke runs of `run.sh`. The first one caught a lost answer by luck.

**Ktor 3.5.2 gives no verdict, for a different reason.** In each of its three runs, every one of the 64 clients
ended on a 30 s timeout (curl 28), and the native server served 9 000 to 12 000 requests where 3.6.0 serves about
27 000 in the same 20 s. That looks like the native server stopping to answer altogether, which was not looked
into further. With 3.6.0 it did not happen in any run. The stand guard turns it into "no verdict" instead of a clean
pass, so 3.5.2 cannot be rechecked with this load.
