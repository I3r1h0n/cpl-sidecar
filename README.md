# CPL in Docker

As a huge fan of [Crystal Palace](https://tradecraftgarden.org/crystalpalace.html), I always wanted to easily install it anywhere and quickly deploy it. This repo is made exacly for this!
Build CPL from the pinned upstream source release and run its [JSON-over-HTTP sidecar](https://tradecraftgarden.org/sidecar.html) on port `60060`.

Have fun, go nuts! =)

### Table of content

- [Build](#build)
- [Usage](#usage)
  - [Curl request](#example-request)
  - [Python client](#python-client)
  - [CLI](#one-shot-cli-use)
- [Config](#configuration)
  - [Host networking](#host-networking)
  - [Why socat](#why-socat)
- [Creds](#creds)

## Build

To build it, simply run this:
```bash
docker build -t cpl-sidecar:20261029 .
```

## Usage

The sidecar resolves `.spec` and `.file` inside the container. Either:

1. Mount your project at a known path and send container paths:

   ```bash
   -v "$PWD/work:/work"
   ```

   ```json
   {
     "action": "link",
     "params": {
       "spec": "/work/loader.spec",
       "file": "/work/capability.x64.dll"
     }
   }
   ```

2. Mount the project at the same absolute path it has on the host, then send
   host paths unchanged:

   ```bash
   -v /home/me/project:/home/me/project
   ```

> [!NOTE]
>Paths inside a `.spec` file are resolved relative to that `.spec` file, so they keep working as long as the whole project tree is mounted

### Example request

```bash
curl -sS -X POST http://127.0.0.1:60060/link \
  -H 'Content-Type: application/json' \
  -d '{
        "action": "link",
        "params": {
          "spec": "/work/loader.spec",
          "file": "/work/capability.x64.dll"
        },
        "yara": true
      }'
```

See the [sidecar reference](https://tradecraftgarden.org/sidecar.html)

### Python client

Simple python client example:

```python
import base64, sys, requests

spec    = sys.argv[1]
capab   = sys.argv[2]
outfile = sys.argv[3]

r = requests.post("http://127.0.0.1:60060/link", json={
    "action": "link",
    "params": {"spec": spec, "file": capab},
})
r.raise_for_status()
data = r.json()

if data.get("success"):
    with open(outfile, "wb") as f:
        f.write(base64.b64decode(data["output_b64"]))
    print("[*] Success")
else:
    print(f"[-] {data.get('context')}: {data.get('message')}")
```

### One-shot CLI

Arguments passed to the image go straight to `cpl` instead of starting the sidecar:

```bash
docker run --rm cpl-sidecar:20261029 help link
```

```bash
docker run --rm -v "$PWD:/work" cpl-sidecar:20261029 link /work/loader.spec /work/capability.x64.dll /work/out.bin
```

## Configuration

| Variable | Default | Explain |
| --- | --- | --- |
| `CPL_PORT` | `60060` | Port the container listens on (map it with `-p`) |
| `CPL_INTERNAL_PORT` | `60061` | Loopback port used by `cpl` behind socat |
| `CPL_BIND` | `0.0.0.0` | Address socat binds. Set `127.0.0.1` with `--network host` |
| `JAVA_OPTS` | empty | Extra JVM flags |
| `CPL_HOME` | `/opt/crystalpalace` | Location of `crystalpalace.jar` |

### Host networking

In case you want to avoid port publishing:

```bash
docker run -d --network host -e CPL_BIND=127.0.0.1 --name cpl \
  -v "$PWD/work:/work" cpl-sidecar:20260921
```

With `CPL_BIND=127.0.0.1`, socat listens only on the host loopback, so the sidecar is not exposed

### Why socat?

Crystal Palace hardcodes the sidecar listener to `127.0.0.1`. Docker port publishing sends traffic to the containers network interface, so a loopback-only listener would be unreachable. 

The entrypoint runs a small `socat` forwarder in front of the unmodified linker:
```text
host 127.0.0.1:60060 -> container 0.0.0.0:60060 (socat) -> 127.0.0.1:60061 (cpl)
```

## Creds

Big thanks to [Raphael Mudge](https://www.hick.org/~raffi/) and Crystal Palace community! 

prod by _I3r1h0n_.
