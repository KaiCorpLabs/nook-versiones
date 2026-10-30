#!/usr/bin/env bash
# Comprueba que un Nook sirve la versión publicada, fichero a fichero.
#
#   ./comprobar.sh https://nook.ejemplo.org
#
# Lee la versión que dice el servidor (/version.json), toma su manifiesto de
# esta carpeta (versiones/<versión>.json, que llega de GitHub, no del
# servidor), comprueba su firma si tienes cosign, y baja cada fichero de la
# web y nook-agent para compararlo con el SHA-256 del manifiesto. Sale con 0
# si todo casa y con 1 si algo no (o no se pudo bajar).
#
# La firma: desde la 0.1.32 la pone la CI de Nook sin clave, y lo que se
# comprueba es quién firmó (IDENTIDAD, abajo: el fichero de la CI en la
# etiqueta de esa versión). Hasta la 0.1.31, y si alguna vez la CI no puede,
# firma quien publica con su clave: cosign.pub. El bundle dice cuál de las
# dos es.
#
# Hace falta curl y python3; cosign, para la firma (si no está, lo dice y
# sigue con los hashes).
set -euo pipefail

ORIGEN="${1:-}"
[ -n "$ORIGEN" ] || { echo "uso: ./comprobar.sh https://nook.ejemplo.org" >&2; exit 2; }
ORIGEN="${ORIGEN%/}"
AQUI="$(cd "$(dirname "$0")" && pwd)"

VERSION="$(curl -fsS -A "nook-comprobar/1" "$ORIGEN/version.json" | python3 -c 'import json,sys; print(json.load(sys.stdin)["version"])')"
M="$AQUI/versiones/$VERSION.json"
[ -f "$M" ] || { echo "El servidor dice que es la $VERSION, y aquí no hay manifiesto de esa versión (¿git pull?)." >&2; exit 1; }
echo "$ORIGEN dice que es la $VERSION."

IDENTIDAD="https://github.com/KaiCorpLabs/nook/.github/workflows/docker.yml@refs/tags/v$VERSION"
EMISOR="https://token.actions.githubusercontent.com"
if command -v cosign >/dev/null 2>&1 && [ -f "$M.sigstore.json" ]; then
  if python3 -c 'import json,sys; sys.exit(0 if "publicKey" in json.load(open(sys.argv[1]))["verificationMaterial"] else 1)' "$M.sigstore.json"; then
    QUIEN=(--key "$AQUI/cosign.pub")
  else
    QUIEN=(--certificate-identity "$IDENTIDAD" --certificate-oidc-issuer "$EMISOR")
  fi
  if cosign verify-blob "${QUIEN[@]}" --bundle "$M.sigstore.json" "$M" >/dev/null 2>&1; then
    echo "Firma del manifiesto: buena."
  else
    echo "Firma del manifiesto: NO VALE. No te fíes de este manifiesto." >&2
    exit 1
  fi
elif [ -f "$M.sigstore.json" ]; then
  echo "Firma del manifiesto: sin comprobar (instala cosign para comprobarla)."
else
  echo "Firma del manifiesto: no la tiene."
fi

python3 - "$ORIGEN" "$M" <<'PY'
import hashlib, json, subprocess, sys, time
from concurrent.futures import ThreadPoolExecutor

origen, ruta = sys.argv[1], sys.argv[2]
m = json.load(open(ruta))

# Se baja con curl (con un User-Agent propio): urllib de Python tropieza con
# algunos proxies, que lo frenan. Dos a la vez y hasta tres intentos por
# fichero. Sin tope fijo por fichero, que con una conexión lenta cortaba los
# grandes: se deja un fichero solo si va a menos de 1 KB/s durante un minuto
# (y, en cualquier caso, a los 15 minutos).
UA = "nook-comprobar/1 (+https://github.com/KaiCorpLabs/nook-versiones)"

def sha(path):
    for intento in range(3):
        r = subprocess.run(["curl", "-fsS", "--connect-timeout", "20", "--speed-limit", "1024", "--speed-time", "60",
                            "--max-time", "900", "-A", UA, "-H", "Cache-Control: no-cache", f"{origen}/{path}"],
                           capture_output=True)
        if r.returncode == 0:
            return "sha256:" + hashlib.sha256(r.stdout).hexdigest()
        time.sleep(2 + 3 * intento)
    return None

quiero = dict(m["web"])
agente = m.get("agente")
if agente:
    quiero["agente/nook-agent.mjs"] = agente["nook-agent.mjs"]
print(f"Bajando {len(quiero)} ficheros…", flush=True)
tengo = {}
with ThreadPoolExecutor(max_workers=2) as pool:
    for n, (p, h) in enumerate(zip(quiero, pool.map(sha, quiero)), 1):
        tengo[p] = h
        if n % 25 == 0 and n < len(quiero):
            print(f"  {n} de {len(quiero)}", flush=True)

fallan = [p for p, h in tengo.items() if h is None]
malos = [p for p, h in tengo.items() if h is not None and h != quiero[p]]
print(f"Web: {len(m['web'])} ficheros; nook-agent {agente['version'] if agente else '-'}. Imagen: {m['imagen']}")
if fallan:
    print(f"No se pudieron bajar {len(fallan)} (vuelve a probar):", *fallan[:20], sep="\n  ")
if malos:
    print(f"NO CASAN {len(malos)}:", *malos[:20], sep="\n  ")
if fallan or malos:
    sys.exit(1)
print("Todo casa con lo publicado.")
PY
