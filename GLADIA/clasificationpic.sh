#!/bin/bash
# ============================================
# 🧠 Author: Gustavo Silva Da Costa (Eto Demerzel)
# 🌀 License: CC BY-NC-SA 4.0
# ============================================
set -euo pipefail
trap cleanup EXIT

# === Cleanup temporaries ===
cleanup() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - Cleaning temporaries"
    rm -rf /tmp/rename_photos_tmp
    rm -f /tmp/rename_photos_script.py
}

# === Validate path ===
validate_path() {
    if [ ! -d "$1" ]; then
        echo "ERROR: Invalid path"
        exit 1
    fi
}

# --- Prompt user for photos folder ---
read -rp "Enter the path of the folder with photos: " photos_path
validate_path "$photos_path"

# --- Ensure required commands and Python packages ---
command -v python3 >/dev/null 2>&1 || { echo "❌ python3 not installed. Please install it."; exit 1; }

# --- Create light-sculpture folder if not exists ---
mkdir -p "$HOME/light-sculpture/models/timm"
MODEL_PATH="$HOME/light-sculpture/models/timm/mobilenetv3_small_100.pth"

# --- Download model if missing ---
if [ ! -f "$MODEL_PATH" ]; then
    echo "⬇️ Downloading mobilenetv3_small_100 pretrained model..."
    curl -L -o "$MODEL_PATH" "https://download.pytorch.org/models/mobilenetv3_small_100-2220cb62.pth"
fi

# --- Create temporary Python script ---
cat > /tmp/rename_photos_script.py <<'EOF'
import unicodedata, csv, os, sys, json, urllib.request
from pathlib import Path
from datetime import datetime
from PIL import Image
import pytesseract
import torch, timm
import torchvision.transforms as T
from multiprocessing import Pool, cpu_count

# Download ImageNet classes mapping
url = "https://raw.githubusercontent.com/pytorch/hub/master/imagenet_classes.txt"
with urllib.request.urlopen(url) as f:
    IMAGENET_CLASSES = [line.decode("utf-8").strip() for line in f.readlines()]

if len(sys.argv) < 2:
    print("Missing path argument")
    sys.exit(1)

photos_path = Path(sys.argv[1])
if not photos_path.exists() or not photos_path.is_dir():
    print("Invalid path")
    sys.exit(1)

# Load model
device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
model = timm.create_model('mobilenetv3_small_100', pretrained=False)
model.load_state_dict(torch.load(os.path.expanduser("~/light-sculpture/models/timm/mobilenetv3_small_100.pth"), map_location=device))
model.eval()
model.to(device)

transform = T.Compose([
    T.Resize((224,224)),
    T.ToTensor(),
    T.Normalize([0.485,0.456,0.406],[0.229,0.224,0.225])
])

tags = ["screen","document","invoice","person","photo","other"]
for t in tags:
    (photos_path / t).mkdir(exist_ok=True)

def clean_name(name):
    import re
    name = unicodedata.normalize('NFKC', name)
    name = ''.join(c for c in name if unicodedata.category(c)[0] != 'C')
    name = re.sub(r'\s+', ' ', name)
    return name.strip()

def clean_path(path: Path) -> Path:
    return Path(*[clean_name(p) for p in path.parts])

def find_file(path: Path) -> Path:
    import re
    name_clean = clean_name(path.name).lower()
    for f in path.parent.iterdir():
        if f.is_file() and clean_name(f.name).lower() == name_clean:
            return f
    return path

def infer_model(img):
    tensor = transform(img).unsqueeze(0).to(device)
    with torch.no_grad():
        return model(tensor).argmax(1).item()

def ocr_text(img):
    return pytesseract.image_to_string(img)

def assign_tags(name, text, top1):
    tags_set = set()
    n = name.lower(); t = text.lower()
    if "screenshot" in n:
        tags_set.add("screen")
    if "photo" in n or "image" in n:
        tags_set.add("photo")
    if "doc" in n or "pdf" in n:
        tags_set.add("document")
    if "invoice" in t or "total" in t:
        tags_set.add("invoice")
    if "name" in t or "person" in t:
        tags_set.add("person")
    if top1 in range(0,50):
        tags_set.add("document")
    if not tags_set:
        tags_set.add("other")
    return list(tags_set)

def process_image(file_path):
    file_path = find_file(file_path)
    img = Image.open(file_path).convert('RGB')
    text = ocr_text(img)
    top1 = infer_model(img)
    clean_base = clean_name(file_path.stem)
    date = datetime.fromtimestamp(file_path.stat().st_mtime).strftime("%Y-%m-%d")
    new_name = f"{clean_base}_{date}{file_path.suffix}"
    assigned_tags = assign_tags(file_path.name, text, top1)
    destinations = []
    for tag in assigned_tags:
        folder = photos_path / tag / f"{clean_base}_info"
        folder.mkdir(exist_ok=True, parents=True)
        dest = folder / new_name
        file_path.rename(dest)
        with open(folder / "text.txt","w",encoding="utf-8") as f:
            f.write(text)
        with open(folder / "model_info.txt","w") as f:
            f.write(f"Top1 prediction: {top1} -> {IMAGENET_CLASSES[top1]}\n")
        destinations.append(str(dest))
    return {"original": clean_base,"new":new_name,"paths":destinations,"tags":assigned_tags,"ocr":text[:500].replace("\n"," "),"top1":top1}

def main():
    files = [f for f in photos_path.iterdir() if f.suffix.lower() in [".png",".jpg",".jpeg"]]
    with Pool(cpu_count()) as pool:
        results = pool.map(process_image, files)

    # CSV
    csv_path = photos_path / "photos_master.csv"
    with open(csv_path,"w",newline="",encoding="utf-8") as csv_file:
        writer = csv.writer(csv_file)
        writer.writerow(["Original","New","Final paths","Tags","OCR text","Top1 prediction"])
        for r in results:
            writer.writerow([r["original"],r["new"],";".join(r["paths"]),";".join(r["tags"]),r["ocr"],r["top1"]])

    # HTML Dashboard
    html_path = photos_path / "dashboard.html"
    data_json = json.dumps(results, ensure_ascii=False)
    with open(html_path,"w",encoding="utf-8") as html_file:
        html_file.write(f'''<!DOCTYPE html><html><head><meta charset='utf-8'><title>Photo Dashboard</title>
<style>body{{font-family:Arial}}.photo{{border:1px solid #ccc;padding:5px;margin:5px;display:inline-block;vertical-align:top}}img{{max-width:150px;max-height:150px;display:block}}.label{{font-weight:bold}}</style>
</head><body>
<h1>Photo Dashboard</h1>
<input type="text" id="search" placeholder="Search OCR text" onkeyup="filterPhotos()" style="width:300px;padding:5px;margin-bottom:10px;">
<select id="filter" onchange="filterPhotos()" style="padding:5px;margin-left:10px;">
<option value="">-- Filter by tag --</option>''')
        for t in tags:
            html_file.write(f"<option value='{t}'>{t}</option>\n")
        html_file.write(f'''</select>
<div id="gallery"></div>
<script>
const photos = {data_json};
function showPhotos(list){{
    const gal = document.getElementById("gallery"); gal.innerHTML="";
    list.forEach(f=>{{f.paths.forEach(p=>{{const div=document.createElement("div");div.className="photo";
    div.innerHTML=`<p class="label">`+f.new+`</p><p>Tags:`+f.tags.join(", ")+`</p><p>OCR:`+f.ocr+`</p><a href='${{p}}' target='_blank'><img src='${{p}}'></a>`;gal.appendChild(div);}});}})}}
function filterPhotos(){{
    const txt=document.getElementById("search").value.toLowerCase();
    const sel=document.getElementById("filter").value;
    let filtered=photos.filter(f=>f.ocr.toLowerCase().includes(txt));
    if(sel){{filtered=filtered.filter(f=>f.tags.includes(sel));}}
    showPhotos(filtered);
}}
showPhotos(photos);
</script>
</body></html>''')
    print(f"✅ Dashboard generated at: {html_path}")

if __name__=="__main__":
    main()
EOF

# --- Execute the Python script ---
python3 /tmp/rename_photos_script.py "$photos_path"
