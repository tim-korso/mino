---
name: read-image
description: Read and analyze images. Uses local macOS Vision OCR (zero config, <0.2s) as primary. Triggers on: @myagents_files/ images, "看看这张图", screenshots, photos.
---

# Image Reader

When the user shares an image, do NOT use the Read tool. Use this instead:

## Primary: Local OCR (always works)

```bash
bash ~/.myagents/projects/mino/.claude/skills/macos-automation/scripts/mac-image-read.sh <absolute-path>
```

Uses macOS built-in Vision framework. No API key. Instant (<0.2s). Best for screenshots and text.

## Fallback: myagents vision (only if OCR empty + photo)

```bash
myagents vision analyze --image <relative-path> --prompt "Describe this image"
```

## Steps

1. Find image paths in current turn (`@myagents_files/image_*.png`)
2. Run `mac-image-read.sh <absolute-path>`
3. Report extracted text to user
4. Only if OCR returns empty AND image is a photo → try vision API
