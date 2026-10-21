# 应用图标

`mail-translation-icon.png` 是应用图标原始素材，使用 Codex 内置 `image_gen` 生成，蓝色圆角方形内以信封和 `A` / `文` 表达邮件翻译，外部背景透明。

`Sources/build.py` 使用 macOS 自带 `sips` 生成 16–1024 像素表示，再通过 `iconutil` 打包为应用的 `AppIcon.icns`；中间文件保存在被 Git 忽略的 `work/` 中。菜单栏继续使用现有的单色系统翻译气泡符号，适应浅色和深色菜单栏。

## 完整生成提示词

```text
Use case: logo-brand.
Asset type: production macOS application icon for a local Apple Mail translation companion, square 1024x1024 raster artwork.
Primary request: Design a beautifully simple, premium native macOS icon communicating email translated between English and Chinese.
Subject: a crisp ivory-white open envelope with two overlapping substantial language cards emerging from it, one bearing exactly the Latin letter "A" and the other exactly the Chinese character "文". Make the two language glyphs large, exceptionally legible and correctly drawn.
Style: polished restrained macOS icon, softly dimensional, smooth porcelain-like envelope and cards, gentle material depth, precise edges. A rich blue rounded-square squircle backing with a subtle cyan-blue gradient; balanced, contemporary, calm.
Composition: one centered icon, straight-on view, strong silhouette that reads at small sizes, generous safe margins, no elements outside the icon tile. Squircle occupies about 86 percent of canvas, transparent surrounding corners. The envelope and two cards fill the center without clutter. Very subtle contact shadows only.
Text (verbatim): "A", "文"; no other text.
Constraints: genuine transparent background outside squircle, no checkerboard baked in, no scene, no desktop, no mockup, no frame, no caption, no border, no watermark, no Apple logo, no cloud or globe, no sparkle, no additional arrows. This is the actual finished app icon, not a presentation board.
```

## 边缘精修提示词

```text
Use case: precise-object-edit. Edit target: the attached finished blue macOS email translation icon. Change ONLY the outer alpha silhouette: remove ALL stray cyan and blue specks, rough halos, noise, pixels, fragments and unwanted shadows outside the rounded blue square. The outer border must be a flawlessly clean smooth continuous rounded-square/squircle with clean antialiasing and a generous fully transparent margin on all four sides, about 8 percent of the square canvas. Preserve the complete icon artwork inside: the blue gradient, white envelope, two white language cards, exact glyphs "A" and "文", materials, layout and proportions. No redesign, no new elements, no cropping, no white background and no checkerboard. Transparent pixels outside the clean rounded square must have zero opacity. Return a square production macOS PNG icon on a truly transparent background.
```
