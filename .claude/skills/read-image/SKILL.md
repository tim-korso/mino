---
name: read-image
description: Read and analyze images. macOS: Vision OCR. Windows: Tesseract OCR. Fallback: myagents vision. Triggers on: @myagents_files/ images, "看看这张图", screenshots, photos.
---

# Image Reader

When the user shares an image, do NOT use the Read tool. Use this instead:

## Auto-detect OS and route

Check which OS you're running on, then use the appropriate path below.

### macOS: Local Vision OCR (always works)

```bash
bash ~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-image-read.sh <absolute-path>
```

Uses macOS built-in Vision framework. No API key. Instant (<0.2s). Best for screenshots and text.

### Windows: Tesseract OCR (always works, no API key)

```powershell
& "C:\Program Files\Tesseract-OCR\tesseract.exe" <absolute-path> stdout -l chi_sim+eng
```

Or use the wrapper script:
```powershell
powershell -File "windows/skills/read-image-win.ps1" -Path "<absolute-path>" -Format text
```

For structured output:
```powershell
powershell -File "windows/skills/read-image-win.ps1" -Path "<absolute-path>" -Format json
```

Uses Tesseract 5.4.0 with Chinese + English language support. No API key needed. Works offline.

### Fallback: myagents vision (if OCR empty + photo)

```bash
myagents vision analyze --image <relative-path> --prompt "Describe this image"
```

Requires a vision-capable model configured in Settings → Toolbox.

## Steps

1. Find image paths in current turn (`@myagents_files/image_*.png`)
2. **macOS**: Run `mac-image-read.sh <absolute-path>`
3. **Windows**: Run Tesseract via PowerShell as shown above
4. Report extracted text to user
5. Only if OCR returns empty AND image is a photo → try `myagents vision analyze`
