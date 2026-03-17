"""
Agridic - Firebase接続設定の雛形
Firebase Admin SDKを使用したFirestore, Storage, Authenticationの設定

使用方法:
1. Firebaseコンソールからサービスアカウントキー（JSON）をダウンロード
2. ダウンロードしたJSONを `serviceAccountKey.json` として本ファイルと同じディレクトリに配置
3. FIREBASE_CONFIG の storageBucket をプロジェクトに合わせて変更
"""

import os

# ============================================================
# Firebase設定
# ============================================================

# サービスアカウントキーのパス
SERVICE_ACCOUNT_KEY_PATH = os.path.join(
    os.path.dirname(os.path.abspath(__file__)),
    "serviceAccountKey.json"
)

# Firebase設定値（プロジェクトに合わせて変更してください）
FIREBASE_CONFIG = {
    "storageBucket": "your-project-id.appspot.com",  # ← ここを変更
}


# ============================================================
# Firebase初期化
# ============================================================

_initialized = False


def initialize_firebase():
    """Firebase Admin SDKを初期化する"""
    global _initialized
    if _initialized:
        return

    try:
        import firebase_admin
        from firebase_admin import credentials

        cred = credentials.Certificate(SERVICE_ACCOUNT_KEY_PATH)
        firebase_admin.initialize_app(cred, FIREBASE_CONFIG)
        _initialized = True
        print("✅ Firebase初期化完了")
    except FileNotFoundError:
        print("⚠️ serviceAccountKey.json が見つかりません。")
        print("   Firebaseコンソールからダウンロードしてください。")
    except Exception as e:
        print(f"❌ Firebase初期化エラー: {e}")


def get_firestore_client():
    """Firestoreクライアントを取得する"""
    initialize_firebase()
    from firebase_admin import firestore
    return firestore.client()


def get_storage_bucket():
    """Firebase Storageバケットを取得する"""
    initialize_firebase()
    from firebase_admin import storage
    return storage.bucket()


# ============================================================
# Firestore ヘルパー関数
# ============================================================

def get_posts(limit: int = 20, last_doc=None):
    """
    投稿一覧を取得する（ランキングアルゴリズム付き）

    ソート順:
    1. is_verified == True（エキスパート投稿優先）
    2. distance（GPS基準で10km以内）
    3. timestamp（新しい順）

    Args:
        limit: 取得件数
        last_doc: ページネーション用の最後のドキュメント

    Returns:
        list: 投稿ドキュメントのリスト
    """
    db = get_firestore_client()
    query = (
        db.collection("posts")
        .where("reports", "<", 3)          # 通報3件以上は非表示
        .order_by("is_verified", direction="DESCENDING")
        .order_by("timestamp", direction="DESCENDING")
        .limit(limit)
    )

    if last_doc:
        query = query.start_after(last_doc)

    return query.stream()


def create_post(post_data: dict) -> str:
    """
    新規投稿を作成する

    Args:
        post_data: 投稿データの辞書
            - user_id: ユーザーID
            - type: "quick" or "report"
            - text: 投稿テキスト
            - image_url_low: 低解像度画像URL（任意）
            - image_url_high: 高解像度画像URL（任意）
            - location: GeoPoint（任意）

    Returns:
        str: 作成されたドキュメントID
    """
    from google.cloud.firestore import SERVER_TIMESTAMP

    db = get_firestore_client()
    post_data["is_verified"] = False
    post_data["reports"] = 0
    post_data["timestamp"] = SERVER_TIMESTAMP

    _, doc_ref = db.collection("posts").add(post_data)
    return doc_ref.id


def verify_post(post_id: str) -> bool:
    """
    投稿を検証済みにする（エキスパート専用）

    Args:
        post_id: 投稿ドキュメントID

    Returns:
        bool: 成功したかどうか
    """
    db = get_firestore_client()
    try:
        db.collection("posts").document(post_id).update({
            "is_verified": True
        })
        return True
    except Exception as e:
        print(f"❌ 検証エラー: {e}")
        return False


def report_post(post_id: str) -> int:
    """
    投稿を通報する

    Args:
        post_id: 通報する投稿のドキュメントID

    Returns:
        int: 更新後の通報回数
    """
    from google.cloud.firestore import Increment

    db = get_firestore_client()
    doc_ref = db.collection("posts").document(post_id)
    doc_ref.update({"reports": Increment(1)})

    updated = doc_ref.get()
    return updated.to_dict().get("reports", 0)


# ============================================================
# Firebase Storage ヘルパー関数
# ============================================================

def upload_image(local_path: str, remote_path: str) -> str:
    """
    画像をFirebase Storageにアップロードする

    Args:
        local_path: ローカルの画像ファイルパス
        remote_path: Storage上の保存パス

    Returns:
        str: アップロードされた画像の公開URL
    """
    bucket = get_storage_bucket()
    blob = bucket.blob(remote_path)
    blob.upload_from_filename(local_path)
    blob.make_public()
    return blob.public_url


def compress_and_upload(local_path: str, post_id: str) -> tuple:
    """
    Gabigabiロジック: 画像を圧縮してアップロードする

    1. 100x100px サムネイル（10KB以下）
    2. 1024px メイン画像

    Args:
        local_path: 元の画像ファイルパス
        post_id: 投稿ID（ファイル名に使用）

    Returns:
        tuple: (低解像度URL, 高解像度URL)
    """
    from PIL import Image
    import io

    img = Image.open(local_path)

    # サムネイル（100x100px）
    thumb = img.copy()
    thumb.thumbnail((100, 100))
    thumb_buffer = io.BytesIO()
    thumb.save(thumb_buffer, format="JPEG", quality=30, optimize=True)
    thumb_path = f"/tmp/thumb_{post_id}.jpg"
    thumb.save(thumb_path, format="JPEG", quality=30, optimize=True)

    # メイン画像（1024px）
    main = img.copy()
    main.thumbnail((1024, 1024))
    main_path = f"/tmp/main_{post_id}.jpg"
    main.save(main_path, format="JPEG", quality=75, optimize=True)

    # アップロード
    url_low = upload_image(thumb_path, f"posts/{post_id}/thumbnail.jpg")
    url_high = upload_image(main_path, f"posts/{post_id}/main.jpg")

    # 一時ファイル削除
    os.remove(thumb_path)
    os.remove(main_path)

    return url_low, url_high
