#!/bin/sh
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
# 💡 lenguaje: bash

SCRIPT="$0"
LENGUAJE=$(grep -m1 '^# 💡 lenguaje:' "$SCRIPT" | cut -d':' -f2 | tr -d ' ')
[ -z "$LENGUAJE" ] && LENGUAJE="${SCRIPT##*.}"

buscar_interprete() {
  case "$1" in
    bash) command -v /opt/homebrew/bin/bash || command -v bash ;;
    zsh)  command -v zsh ;;
    py|python) command -v python3 || command -v python ;;
    sh)   echo /bin/sh ;;
    *)    return 1 ;;
  esac
}

if [ -z "$_AUTO_BOOTSTRAP_DONE" ]; then
  INTERPRETE=$(buscar_interprete "$LENGUAJE")
  if [ -n "$INTERPRETE" ]; then
    export _AUTO_BOOTSTRAP_DONE=1
    exec "$INTERPRETE" "$SCRIPT" "$@"
  else
    echo "❌ Intérprete no encontrado para '$LENGUAJE'"
    exit 1
  fi
fi

# === DEPENDENCIAS ===
for cmd in trans python3 curl unzip; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "❌ Falta dependencia: $cmd"
    exit 1
  fi
done

# === RUTAS ===
MODEL_DIR="$HOME/light-sculpture/models/sdxl"
MODEL_FILE="runwayml-stable-diffusion-v1-5.safetensors"
MODEL_PATH="$MODEL_DIR/$MODEL_FILE"
OUTPUT_DIR="$HOME/proyecto/laboratorio/resultados/outputsmejorados"
VENV="$HOME/modelo/sdxl_test/venv/bin/activate"

mkdir -p "$MODEL_DIR" "$OUTPUT_DIR"

# === DESCARGA DEL MODELO SI NO EXISTE (CON VERIFICACIÓN SHA256) ===
MODEL_URL="https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/$MODEL_FILE"
MODEL_SHA256="${MODEL_SHA256:-}"

verify_sha256() {
  local file="$1" expected="$2"
  if [ -z "$expected" ]; then
    echo "⚠️ SHA256 no configurado para $file, omitiendo verificación" >&2
    return 0
  fi
  local actual
  if command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file" | awk '{print $1}')
  elif command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file" | awk '{print $1}')
  else
    echo "⚠️ No se encontró herramienta SHA256, omitiendo verificación" >&2
    return 0
  fi
  if [ "$actual" != "$expected" ]; then
    echo "❌ SHA256 no coincide para $file" >&2
    echo "   Esperado: $expected" >&2
    echo "   Obtenido: $actual" >&2
    rm -f "$file"
    return 1
  fi
  echo "✅ SHA256 verificado: $file"
  return 0
}

if [ ! -f "$MODEL_PATH" ]; then
  echo "⚡ Modelo no encontrado, descargando $MODEL_FILE..."
  curl -L -o "$MODEL_PATH" "$MODEL_URL" || { echo "❌ Error descargando modelo."; exit 1; }
  verify_sha256 "$MODEL_PATH" "$MODEL_SHA256" || { echo "❌ Verificación de integridad fallida."; exit 1; }
  echo "✅ Modelo descargado y verificado en $MODEL_PATH"
fi

# === ACTIVAR ENTORNO VIRTUAL ===
if [ ! -f "$VENV" ]; then
  echo "❌ Entorno virtual no encontrado: $VENV"
  exit 1
fi
source "$VENV" || { echo "❌ Error al activar entorno."; exit 1; }

# === BUCLE PRINCIPAL ===
while true; do
  echo ""
  read -rp "📝 Prompt a mejorar > " PROMPT
  [ -z "$PROMPT" ] && echo "❌ El prompt no puede estar vacío." && continue

  echo "🌐 Traduciendo prompt a inglés..."
  TRANSLATED=$(trans -brief :en "$PROMPT")
  echo "📤 Traducción sugerida: $TRANSLATED"
  read -rp "✅ Usar esta traducción? (s/n) > " CONFIRM
  [ "$CONFIRM" != "s" ] && continue

  echo "🖼 Ruta de la imagen base (png/jpg):"
  read -rp "📂 Ruta > " IMG_BASE
  IMG_BASE=$(eval echo "$IMG_BASE")
  if [[ ! -f "$IMG_BASE" ]]; then
    echo "❌ Imagen base no encontrada."
    continue
  fi

  read -rp "💾 Nombre de salida (sin extensión) > " FILE
  [ -z "$FILE" ] && FILE="imagen_$(date +%Y%m%d_%H%M%S)"
  FILENAME="$OUTPUT_DIR/$FILE.png"
  PROMPT_TXT="${FILENAME%.png}.txt"

  # === Ejecutar img2img con diffusers ===
  PYFILE="/tmp/generador_img2img.py"
  cat > "$PYFILE" << 'EOF'
import argparse
from diffusers import StableDiffusionImg2ImgPipeline, LMSDiscreteScheduler
from PIL import Image
import torch, os, sys

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--prompt', required=True)
    parser.add_argument('--init_image', required=True)
    parser.add_argument('--output', required=True)
    parser.add_argument('--txt', required=True)
    parser.add_argument('--strength', type=float, default=0.7)
    parser.add_argument('--num_inference_steps', type=int, default=50)
    parser.add_argument('--guidance_scale', type=float, default=6.5)
    args = parser.parse_args()

    if not os.path.exists(args.init_image):
        print(f"❌ Imagen base no encontrada: {args.init_image}")
        sys.exit(1)

    print("🎨 Cargando modelo...")
    pipe = StableDiffusionImg2ImgPipeline.from_pretrained(
        "runwayml/stable-diffusion-v1-5",
        torch_dtype=torch.float32,
        use_safetensors=True,
        safety_checker=None,
        requires_safety_checker=False,
        low_cpu_mem_usage=True
    )
    pipe.scheduler = LMSDiscreteScheduler.from_config(pipe.scheduler.config)
    pipe.to("cpu")

    init_image = Image.open(args.init_image).convert("RGB")
    init_image = init_image.resize((init_image.width - init_image.width % 8, init_image.height - init_image.height % 8))

    output = pipe(
        prompt=args.prompt,
        image=init_image,
        strength=args.strength,
        num_inference_steps=args.num_inference_steps,
        guidance_scale=args.guidance_scale
    )
    if not output.images:
        print("❌ Falló la generación.")
        sys.exit(1)

    os.makedirs(os.path.dirname(args.output), exist_ok=True)
    output.images[0].save(args.output)
    with open(args.txt, "w") as f: f.write(args.prompt)
    print(f"✅ Imagen guardada: {args.output}")
    print(f"📝 Prompt guardado: {args.txt}")

if __name__ == "__main__":
    main()
EOF

  python3 "$PYFILE" --prompt "$TRANSLATED" --init_image "$IMG_BASE" --output "$FILENAME" --txt "$PROMPT_TXT"

  rm "$PYFILE"

  echo "📸 Ver imagen(1)/Otra(2)/Salir(3)?"
  read -rp "Opción > " OPCION
  case "$OPCION" in
    1) [[ -f "$FILENAME" ]] && open "$FILENAME" || echo "⚠️ Archivo no encontrado" ;;
    2) continue ;;
    3) echo "🚪 Saliendo"; break ;;
    *) echo "❌ Opción inválida" ;;
  esac
done
