# Versiones de Nook

El manifiesto firmado de cada versión publicada de Nook: qué imagen es
(`ghcr.io/ulzuhan/nook`, por digest), de qué commit sale y el SHA-256 de cada
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
y baja cada fichero de la web y nook-agent para compararlos. Hace falta curl
y python3.

## Qué hay

- `versiones/<versión>.json`: el manifiesto. `commit` y `etiqueta` en el
  repositorio de Nook; `imagen` (por digest) y `config` (el id de la imagen);
  `build`, la compilación de la web que se ve en Ajustes › General; `web`,
  ruta → SHA-256 de cada fichero tal como se sirve; `agente`, la versión y
  el SHA-256 de `/agente/nook-agent.mjs`.
- `versiones/<versión>.json.sigstore.json`: su firma, un bundle de cosign,
  también en el registro público de transparencia de Sigstore (Rekor).
- `cosign.pub`: la clave pública con que se firman los manifiestos y las
  imágenes.

## Comprobar a mano

```bash
cosign verify-blob --key cosign.pub \
  --bundle versiones/0.1.27.json.sigstore.json versiones/0.1.27.json
```

La firma de la imagen va en el registro, junto a ella (de momento el paquete
es privado: hace falta acceso a él para comprobarla):

```bash
cosign verify --key cosign.pub ghcr.io/ulzuhan/nook@sha256:<digest del manifiesto>
```

Los ficheros de la web, uno a uno: `curl -s https://<Nook>/<ruta> | shasum -a 256`
y comparar con `web` del manifiesto. La web se compila de forma reproducible:
recompilarla desde su commit da los mismos bytes.

## Cómo se publica una versión

1. La imagen se construye desde la etiqueta y se sube a GHCR; se apunta su
   digest.
2. En el repositorio de Nook, `node scripts/manifiesto.mjs <versión> <imagen@digest>`
   mide la imagen misma (`nook huellas`, el SHA-256 de lo que lleva dentro).
3. Quien tiene la clave firma el manifiesto y la imagen con cosign, y el
   manifiesto llega aquí **antes** de desplegar la versión.

Los manifiestos y `comprobar.sh` son de dominio público (CC0).
