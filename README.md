# Versiones de Nook

El manifiesto firmado de cada versión publicada de Nook: qué imagen es
(por digest: `ghcr.io/kaicorplabs/nook` desde la 0.1.29, `ghcr.io/ulzuhan/nook`
hasta la 0.1.28), de qué commit sale y el SHA-256 de cada
fichero de la web que sirve y de nook-agent. Está aquí, fuera de cualquier
servidor de Nook, para que se pueda comprobar que un Nook sirve lo publicado
y no otra cosa.

Nook cifra de extremo a extremo, pero en el navegador el código lo sirve el
propio servidor: un servidor comprometido podría servir otro. La web fija la
versión que aceptaste y avisa si pasa a correr otra sin aceptarla («Nook ha
pasado a la … sin que lo aceptaras»), con un enlace a su manifiesto aquí. La
app de escritorio no depende de esto: lleva el código dentro.

## Comprobar un Nook

```bash
git clone https://github.com/KaiCorpLabs/nook-versiones
cd nook-versiones
./comprobar.sh https://nook.kaicorplabs.com
```

Pregunta al servidor qué versión es, toma su manifiesto de esta carpeta,
comprueba la firma (si tienes [cosign](https://docs.sigstore.dev/cosign/system_config/installation/))
y baja cada fichero de la web y nook-agent para compararlos (unos 8 MB: con
una conexión lenta, unos minutos). Hace falta curl y python3.

## Qué hay

- `versiones/<versión>.json`: el manifiesto. `commit` y `etiqueta` en el
  repositorio de Nook; `imagen` (por digest) y `config` (el id de la imagen);
  `compose`, el SHA-256 de su `compose.yaml` (desde la 0.1.32); `build`, la
  compilación de la web que se ve en Ajustes › General; `web`, ruta →
  SHA-256 de cada fichero tal como se sirve; `agente`, la versión y el
  SHA-256 de `/agente/nook-agent.mjs`.
- `versiones/<versión>.json.sigstore.json`: su firma, un bundle de cosign,
  también en el registro público de transparencia de Sigstore (Rekor).
- `cosign.pub`: la clave pública de quien publica, con que se firmaron los
  manifiestos y las imágenes hasta la 0.1.31.

## Quién firma

Desde la 0.1.32 firma la CI de Nook, sin clave: cosign firma con la identidad
de la ejecución de GitHub Actions que construyó la imagen, y Sigstore da un
certificado para esa identidad. Se comprueba que sea exactamente

```text
https://github.com/KaiCorpLabs/nook/.github/workflows/docker.yml@refs/tags/v<versión>
```

con el emisor `https://token.actions.githubusercontent.com`. Hasta la 0.1.31
firmaba quien publica, con la clave de `cosign.pub`; la clave sigue de reserva
por si la CI no puede, y `comprobar.sh` acepta las dos (el bundle dice cuál
es).

## Comprobar a mano

Una versión firmada por la CI (desde la 0.1.32):

```bash
cosign verify-blob --bundle versiones/0.1.32.json.sigstore.json \
  --certificate-identity https://github.com/KaiCorpLabs/nook/.github/workflows/docker.yml@refs/tags/v0.1.32 \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  versiones/0.1.32.json
```

Una firmada con la clave (hasta la 0.1.31):

```bash
cosign verify-blob --key cosign.pub \
  --bundle versiones/0.1.27.json.sigstore.json versiones/0.1.27.json
```

La firma de la imagen va en el registro, junto a ella (de momento el paquete
es privado: hace falta acceso a él para comprobarla). Con las mismas
opciones, o `--key cosign.pub` hasta la 0.1.31:

```bash
cosign verify --certificate-identity https://github.com/KaiCorpLabs/nook/.github/workflows/docker.yml@refs/tags/v<versión> \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com \
  ghcr.io/kaicorplabs/nook@sha256:<digest del manifiesto>   # hasta la 0.1.28, ghcr.io/ulzuhan/nook
```

Los ficheros de la web, uno a uno: `curl -s https://<Nook>/<ruta> | shasum -a 256`
y comparar con `web` del manifiesto. La web se compila de forma reproducible:
recompilarla desde su commit da los mismos bytes.

## Cómo se publica una versión

Todo en la CI de Nook, con la etiqueta `v<versión>`:

1. La imagen se construye desde la etiqueta, pasa Trivy y se sube a GHCR.
2. `scripts/manifiesto.mjs` mide la imagen subida (`nook huellas`, el SHA-256
   de lo que lleva dentro).
3. cosign firma el manifiesto y la imagen sin clave, y la CI comprueba las
   dos firmas con la identidad de arriba.
4. Una app de la organización, que solo puede escribir aquí, abre la PR con
   el manifiesto y su firma. No puede juntarla: `main` pide una aprobación, y
   la PR la junta una persona.

Juntarla publica la versión, y el manifiesto llega aquí **antes** de
desplegarla: nook.kaicorplabs.com se despliega solo cuando ve en `main` una
versión más nueva que la suya, después de comprobar él mismo la firma.

Los manifiestos y `comprobar.sh` son de dominio público (CC0).
