"""
Agridic - 画像圧縮ユーティリティ（ローカル版）
Firebase未接続時はローカルファイルとして保存する。

Gabigabiロジック:
  1. サムネイル: 100x100px, JPEG quality=30, 目標10KB以下
  2. メイン画像: 長辺1024px, JPEG quality=75
"""

import os
import uuid
try:
    from PIL import Image
    HAS_PIL = True
except ImportError:
    HAS_PIL = False
    print("⚠️ Pillow not installed. Run: pip install Pillow")
    print("   Image compression will be disabled.")

# 画像保存先ディレクトリ
IMAGES_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "images")
THUMB_DIR = os.path.join(IMAGES_DIR, "thumbs")
MAIN_DIR = os.path.join(IMAGES_DIR, "main")


def _ensure_dirs():
    """保存ディレクトリが存在しなければ作成"""
    os.makedirs(THUMB_DIR, exist_ok=True)
    os.makedirs(MAIN_DIR, exist_ok=True)


def compress_image(source_path: str, post_id: str = None) -> dict:
    """
    画像を圧縮してローカルに保存する。
    Pillow未インストール時は元画像パスをそのまま返す。
    """
    if not HAS_PIL:
        # Pillow なし → 圧縮せずに元パスをそのまま返す
        return {
            "thumb_path": source_path,
            "main_path": source_path,
            "thumb_size_kb": round(os.path.getsize(source_path) / 1024, 1),
            "main_size_kb": round(os.path.getsize(source_path) / 1024, 1),
        }

    _ensure_dirs()

    if not post_id:
        post_id = uuid.uuid4().hex[:12]

    img = Image.open(source_path)

    # RGBA → RGB 変換（JPEG保存のため）
    if img.mode in ("RGBA", "P", "LA"):
        background = Image.new("RGB", img.size, (255, 255, 255))
        if img.mode == "P":
            img = img.convert("RGBA")
        background.paste(img, mask=img.split()[-1] if img.mode == "RGBA" else None)
        img = background
    elif img.mode != "RGB":
        img = img.convert("RGB")

    # --- サムネイル (100x100px, 目標10KB以下) ---
    thumb = img.copy()
    thumb.thumbnail((100, 100), Image.LANCZOS)

    thumb_path = os.path.join(THUMB_DIR, f"{post_id}_thumb.jpg")

    # quality を下げながら10KB以下を目指す
    quality = 40
    while quality >= 10:
        thumb.save(thumb_path, format="JPEG", quality=quality, optimize=True)
        size_kb = os.path.getsize(thumb_path) / 1024
        if size_kb <= 10:
            break
        quality -= 5

    thumb_size = os.path.getsize(thumb_path) / 1024

    # --- メイン画像 (長辺1024px) ---
    main_img = img.copy()
    main_img.thumbnail((1024, 1024), Image.LANCZOS)

    main_path = os.path.join(MAIN_DIR, f"{post_id}_main.jpg")
    main_img.save(main_path, format="JPEG", quality=75, optimize=True)
    main_size = os.path.getsize(main_path) / 1024

    return {
        "thumb_path": thumb_path,
        "main_path": main_path,
        "thumb_size_kb": round(thumb_size, 1),
        "main_size_kb": round(main_size, 1),
    }
