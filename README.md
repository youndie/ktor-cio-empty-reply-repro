# ktor-cio-empty-reply-repro

Ktor's CIO server on Kotlin/Native `linuxX64` occasionally closes a connection without sending the response that
the handler has already written. The client sees `curl: (52) Empty reply from server`, while the handler ran to
the end: `call.respondText` returned normally. When the handler has a side effect (in the service where this was
found, a record written to Kafka), the client is left not knowing about a write that did happen.

The same source compiled for the JVM, under the same load on the same host, has never done it.

This repository keeps the reproduction so it can be rerun against later Kotlin and Ktor versions. It has not been
reported upstream.

## Run it

Linux x86-64, a JDK, `curl` and `python3`. The Gradle wrapper fetches its own distribution.

```bash
./run.sh            # 1200 s on each build
./run.sh 1200 -PktorVersion=3.7.0 -PkotlinVersion=2.5.0
```

`run.sh` builds both targets, runs 64 shell clients against the native server for the given time (one `curl` per
request, so every request is a new connection), then does the same against the JVM server, and ends with one line
in the format of [results.md](results.md):

```
| 2026-09-27 | 6.6.87.2-microsoft-standard-WSL2, 2.39 glibc, curl 8.5.0 | 2.4.20 | 3.6.0 | 1200 | 13 / 1639097 | 0 / 1548235 | reproduced |
```

Exit codes: `1` reproduced, `0` not reproduced, `2` no verdict. Any arguments after the duration go to Gradle, and
the versions in the line are read back from the build, not from the arguments. `gradle.properties` holds the
versions of the last recorded run.

### Reading the verdict

The bug is rare, about 8 lost answers per million requests, so a clean native run means something only when it
was long enough. For that reason the script refuses to judge rather than report a pass:

- **reproduced**: the native server lost at least one answer, and the JVM server lost none.
- **not reproduced**: the native server lost none, and the run was long enough that at the known rate at least 5
  would be expected. The line gives the expected count and the chance of seeing zero if nothing changed. 1200 s
  gives about 13 expected, so the chance of a clean run by luck is about 2 in a million.
- **no verdict**, for any of these reasons:
  - the run was too short;
  - the JVM control lost answers too;
  - some request got anything other than a `200` or a lost answer (a dead server gives curl 7);
  - either server did fewer than 300 requests per second (the reproducing load was about 1 300);
  - `curl` did not report a deliberately empty reply as 52. That check runs first, against a listener that reads
    the request and closes without writing, so a clean run cannot come from a counter that never fires.

"Lost" counts curl 52 (empty reply) and curl 56 (reset while receiving). On 2026-09-27 every lost answer was a 52.

## What is known

| | |
|---|---|
| Rate | 40 in 4 772 201 native requests over three runs; 0 in 1 548 235 on the JVM ([results.md](results.md)) |
| Timing-dependent | in the service where it was found, the rate ranged from about 1 in 375 000 to 1 in 60 000, depending on what the handler did before answering. That looks like a race between completing the response and closing the connection. |
| Not the application | the handler here is the whole server: no plugins, no content negotiation, nothing but `ktor-server-core` and `ktor-server-cio` |
| Not the client | the JVM server under the same `curl` load never loses an answer |

The 10 ms `delay` in the handler is part of the reproduction. It stands for the short piece of I/O the original
handler did before answering, and the rate depends on that timing.

With Ktor 3.5.2, every native client ends on a 30 s timeout within 20 s, so the run gives no verdict and that
version cannot be rechecked with this load (results.md). 3.6.0 does not do this.

A second side observation, not what this repository measures: on `SIGTERM` the native server closes its listener,
but its process does not exit. `SIGTERM` stays caught and blocked, and the process sleeps. Seen once, with Ktor 3.6.0 on
2026-09-27. `run.sh` gives the server ten seconds and then sends `SIGKILL`, after the load has ended.

## Licence

Apache 2.0, matching Ktor.
