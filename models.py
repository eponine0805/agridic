"""
Agridic - データモデル定義
詳細仕様書v2: 公式レポート/一般投稿の二層構造に対応
"""

from dataclasses import dataclass, field
from enum import Enum
from datetime import datetime
from typing import Optional, List, Tuple


class ViewMode(Enum):
    """公式レポートの表示モード（一般投稿には適用しない）"""
    TEXT = "text"        # Mode A: テキストのみ（画像フェッチなし）
    MANUAL = "manual"    # Mode B: テキスト＋重要画像＋ステップ表示
    VISUAL = "visual"    # Mode C: 画像メイン＋テキスト補足


class PostType(Enum):
    """投稿タイプ"""
    QUICK = "quick"
    REPORT = "report"


class UserRole(Enum):
    """ユーザーロール"""
    FARMER = "farmer"
    EXPERT = "expert"
    ADMIN = "admin"


@dataclass
class PostContent:
    """投稿コンテンツ（二層構造対応）"""
    text_short: str = ""          # SNS用短文（タイムライン表示）
    text_full: str = ""           # 公式詳細用フルテキスト（Text Onlyモード用 / 後方互換）
    text_full_manual: str = ""    # Text+Imageモード用テキスト
    text_full_visual: str = ""    # Image Mainモード用テキスト
    steps: List[str] = field(default_factory=list)  # ステップ表示用
    image_low: str = ""           # サムネイル（タイムライン用）
    image_high: str = ""          # メイン画像（後方互換）
    images: List[str] = field(default_factory=list)  # 複数画像（![N]挿入用）


@dataclass
class Post:
    """投稿データモデル（Firestore: posts コレクション）

    二層構造:
    - is_official=True  → 公式レポート（静のデータベース）
    - is_official=False → 一般投稿（動のタイムライン）
    """
    post_id: str = ""
    is_official: bool = False     # ★ 公式/一般の区別
    user_role: str = "farmer"     # "expert" / "farmer"
    user_name: str = ""
    content: PostContent = field(default_factory=PostContent)
    location: Optional[Tuple[float, float]] = None
    timestamp: Optional[datetime] = None
    is_verified: bool = False     # ⭐検証済みマーク
    reports: int = 0              # 通報回数
    distance_km: float = 0.0
    view_mode: str = "text"       # 投稿者が選んだ表示モード: "text" / "manual" / "visual"
    # 辞書カテゴリ（公式レポートのみ）
    dict_crop: str = ""
    dict_category: str = ""
    dict_tags: List[str] = field(default_factory=list)

    @property
    def is_hidden(self) -> bool:
        """通報が3回以上の場合は非表示"""
        return self.reports >= 3


@dataclass
class DiseaseEntry:
    """病害辞典エントリ（SQLiteオフライン検索用）"""
    id: str = ""
    name_en: str = ""
    name_sw: str = ""
    symptoms: str = ""
    treatment: str = ""
    crop_type: str = ""
    last_synced: Optional[datetime] = None
