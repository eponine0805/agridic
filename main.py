"""
Agridic 🌱 - 農業支援アプリ
メインエントリポイント（投稿機能／Tweet・Report選択 実装版）
"""

import flet as ft
import os
from datetime import datetime, timedelta
from models import ViewMode, PostType, Post, PostContent

try:
    import flet_map as ftm
    HAS_MAP = True
except ImportError:
    HAS_MAP = False

try:
    from flet_geolocator import Geolocator, GeolocatorPermissionStatus
    HAS_GEO = True
except ImportError:
    HAS_GEO = False


# ============================================================
# ダミーデータ
# ============================================================

DUMMY_POSTS = [
    # ==================================================================
    # 【公式レポート①】 Stem Borer — Text+Image モードのデモ
    #   text_full に ![1] ![2] で画像挿入位置を指定
    # ==================================================================
    Post(
        post_id="off_stemborer",
        is_official=True,
        user_role="expert",
        user_name="Gatanga Agric. Office",
        content=PostContent(
            text_short="Maize Stem Borer Alert & Control [Maize] — Gatanga",
            text_full=(
                "## Maize Stem Borer — Alert & Control\n"
                "### Gatanga sub-county\n"
                "\n"
                "## Current Situation\n"
                "Maize stem borer (Busseola fusca / Chilo partellus) reported in multiple farms. "
                "Infestation peaks 3–5 weeks after emergence during long rains.\n"
                "\n"
                "## How to Identify\n"
                "![1]\n"
                "- Small holes on young leaves (shot-hole pattern)\n"
                "- Sawdust-like frass at the leaf whorl\n"
                "- Cream/pink caterpillar (2–3cm) inside damaged leaves\n"
                "\n"
                "## Control Options\n"
                "### Cultural control\n"
                "Remove and destroy crop residues after harvest. Rotate with beans or potatoes.\n"
                "### Biological control (Push-Pull)\n"
                "![2]\n"
                "Intercrop maize with Desmodium — it repels stem borers. Plant Napier grass as a border trap crop.\n"
                "### Chemical control (if severe)\n"
                "Apply Bulldock Star or Thunder OD into the leaf whorl at 2–3 weeks after emergence.\n"
                "\n"
                "## When to Escalate\n"
                "If more than 20% of plants show whorl damage, move to chemical control. "
                "Contact Gatanga Agriculture Office for subsidised pesticides."
            ),
            steps=[
                "IDENTIFY: Look for small holes on leaves and sawdust-like frass at the whorl. Pull damaged leaves to check for larvae.",
                "CULTURAL CONTROL: Remove and destroy crop residues after harvest. Rotate with beans or potatoes.",
                "BIOLOGICAL CONTROL (Push-Pull): Intercrop with Desmodium + Napier grass border.",
                "CHEMICAL CONTROL (if severe): Apply Bulldock Star into the leaf whorl at 2–3 weeks. Re-apply after 14 days.",
                "MONITOR: Scout twice weekly during weeks 2–6. Escalate if >20% plants are damaged.",
                "REPORT: Photo damaged leaves and post to this app. Contact Gatanga Agric. Office."
            ],
            image_low="🐛",
            image_high="🐛",
            images=["🐛 stem-borer-damage.jpg", "🌿 push-pull-desmodium.jpg"],
        ),
        location=(-0.95, 36.87),
        timestamp=datetime.now() - timedelta(hours=3),
        is_verified=True,
        reports=0,
        distance_km=1.5,
        view_mode="manual",
        dict_crop="Maize",
        dict_category="Pests & Diseases",
        dict_tags=["stem borer", "busseola", "chilo", "pest", "insect", "whorl damage"],
    ),

    # ==================================================================
    # 【公式レポート②】 Maize Growing Guide — Text+Image モードのデモ
    # ==================================================================
    Post(
        post_id="off_maize_guide",
        is_official=True,
        user_role="expert",
        user_name="Gatanga Agric. Office",
        content=PostContent(
            text_short="Maize Growing Guide [Maize] — Gatanga, Murang'a County",
            text_full=(
                "## Maize Growing Guide\n"
                "### Gatanga sub-county, Murang'a County\n"
                "\n"
                "A complete guide for smallholder maize cultivation in the Central Highlands (1,400–1,800m).\n"
                "\n"
                "## Recommended Varieties\n"
                "- H614 — reliable mid-altitude hybrid\n"
                "- H625 — drought-tolerant option\n"
                "- KH600-23A — early maturity\n"
                "\n"
                "## Planting\n"
                "![1]\n"
                "- Row spacing: 75cm\n"
                "- Plant spacing: 25cm\n"
                "- Seed depth: 5cm\n"
                "- Window: March–April (long rains)\n"
                "\n"
                "## Fertilizer Schedule\n"
                "### At planting\n"
                "Apply DAP (1 tablespoon per hole) mixed with soil before placing seed.\n"
                "### Top dressing (2–3 weeks)\n"
                "![2]\n"
                "Apply CAN fertilizer (1 tbsp per plant) in a ring 10cm from the stem.\n"
                "### Second top dressing (5–6 weeks)\n"
                "Repeat CAN application at knee height. Hill up soil to support roots.\n"
                "\n"
                "## Harvest\n"
                "![3]\n"
                "Harvest when husks are dry and brown, kernels are hard (dent test). Dry to 13% moisture before storage."
            ),
            steps=[
                "Land prep: Clear field, plough 15–20cm. Apply 1 ton/acre manure 2 weeks before planting.",
                "Planting: Certified seed (H614/H625). Spacing 75×25cm, 1 seed per hole at 5cm depth.",
                "1st weeding + Top dress: Weed at 2–3 weeks. Apply CAN (1 tbsp/plant, 10cm from stem).",
                "2nd weeding: Weed at 5–6 weeks (knee height). Hill up soil around base.",
                "Pest scouting: Check weekly for stem borer, FAW, aphids. Report to this app.",
                "Harvest: Husks dry + brown, kernels hard. Dry to 13% moisture."
            ],
            image_low="🌽",
            image_high="🌽",
            images=["🌱 planting-spacing.jpg", "🧪 can-fertilizer.jpg", "🌾 harvest-ready.jpg"],
        ),
        location=(-0.95, 36.87),
        timestamp=datetime.now() - timedelta(hours=6),
        is_verified=True,
        reports=0,
        distance_km=1.2,
        view_mode="manual",
        dict_crop="Maize",
        dict_category="Growing Guide",
        dict_tags=["maize", "planting", "fertilizer", "CAN", "DAP", "H614", "harvest", "spacing"],
    ),

    # ==================================================================
    # 【公式レポート③】 Fall Armyworm — Text Only モードのデモ
    #   画像なし、テキストだけで完結
    # ==================================================================
    Post(
        post_id="off_faw",
        is_official=True,
        user_role="expert",
        user_name="Min. of Agriculture",
        content=PostContent(
            text_short="Fall Armyworm (FAW) outbreak confirmed [Maize] — Nakuru / spreading to Murang'a",
            text_full=(
                "## Fall Armyworm (FAW) Outbreak\n"
                "### Nakuru County — spreading to Murang'a\n"
                "\n"
                "## Situation\n"
                "Fall Armyworm (Spodoptera frugiperda) outbreak confirmed. "
                "Larvae feed aggressively on maize whorls and ears. Can destroy a field in days.\n"
                "\n"
                "## How to Identify\n"
                "- Ragged, irregular holes on leaves\n"
                "- Heavy frass (sawdust-like waste) in the whorl\n"
                "- Larvae most active at dawn and dusk\n"
                "\n"
                "## Recommended Action\n"
                "### Organic control\n"
                "Apply Bt-based biopesticide (Bacillus thuringiensis) directly into the whorl.\n"
                "### Chemical control (severe)\n"
                "Use Ampligo (chlorantraniliprole + lambda-cyhalothrin). Follow label strictly.\n"
                "### Manual control\n"
                "Handpick and crush larvae where feasible.\n"
                "\n"
                "## Emergency Contact\n"
                "Contact your local extension office for emergency pesticide supply."
            ),
            steps=[],
            image_low="",
            image_high="",
            images=[],
        ),
        location=(-0.3, 36.1),
        timestamp=datetime.now() - timedelta(days=1),
        is_verified=True,
        reports=0,
        distance_km=8.7,
        view_mode="text",
        dict_crop="Maize",
        dict_category="Pests & Diseases",
        dict_tags=["fall armyworm", "FAW", "spodoptera", "pest", "insect", "whorl", "Bt"],
    ),
    # ==================================================================
    Post(
        post_id="off_blight",
        is_official=True,
        user_role="expert",
        user_name="Agridic Official",
        content=PostContent(
            text_short="Tomato Late Blight alert [Tomato] — Kiambu County",
            text_full=(
                "## Tomato Late Blight Alert\n"
                "### Kiambu County\n"
                "\n"
                "## Situation\n"
                "Tomato Late Blight (Phytophthora infestans) detected. Spreading rapidly due to high humidity.\n"
                "\n"
                "## How to Identify\n"
                "![1]\n"
                "- Dark brown/black lesions on leaves, starting from edges\n"
                "- White fuzzy mold on leaf undersides (visible in early morning)\n"
                "- Brown spots on stems and fruit\n"
                "\n"
                "## Recommended Action\n"
                "- Apply copper-based fungicide (Copper Oxychloride) every 7–10 days\n"
                "- Remove and destroy infected leaves — do NOT compost\n"
                "- Improve air circulation with proper plant spacing\n"
                "\n"
                "## Prevention\n"
                "- Use resistant varieties where available\n"
                "- Stake plants to keep foliage off the ground\n"
                "- Rotate with non-solanaceous crops"
            ),
            steps=[
                "Identify dark brown lesions with white fuzzy mold on leaf undersides",
                "Remove infected leaves and destroy (do NOT compost)",
                "Apply copper-based fungicide every 7–10 days",
                "Improve spacing for air circulation"
            ],
            image_low="🍅",
            image_high="🍅",
            images=["🍅 late-blight-symptoms.jpg"],
        ),
        location=(1.1, 36.8),
        timestamp=datetime.now() - timedelta(hours=12),
        is_verified=True,
        reports=0,
        distance_km=2.3,
        view_mode="manual",
        dict_crop="Tomato",
        dict_category="Pests & Diseases",
        dict_tags=["tomato", "late blight", "phytophthora", "fungus", "copper", "fungicide"],
    ),

    # ==================================================================
    # 【一般投稿】 農家の井戸端会議
    # ==================================================================
    Post(
        post_id="usr_001",
        is_official=False,
        user_role="farmer",
        user_name="Mary Wanjiku",
        content=PostContent(
            text_short="My maize leaves have small holes and there is sawdust stuff in the whorl. Is this stem borer? Help!",
            image_low="🌽",
        ),
        location=(-0.96, 36.88),
        timestamp=datetime.now() - timedelta(minutes=45),
        is_verified=False,
        reports=0,
        distance_km=1.8
    ),
    Post(
        post_id="usr_002",
        is_official=False,
        user_role="expert",
        user_name="John Kamau",
        content=PostContent(
            text_short="Mary, that sounds like stem borer. Search 'stem borer' on this app for the official guide. Apply Bulldock into the whorl ASAP.",
            image_low="👨‍🌾",
        ),
        location=(-0.95, 36.87),
        timestamp=datetime.now() - timedelta(minutes=30),
        is_verified=True,
        reports=0,
        distance_km=1.5
    ),
    Post(
        post_id="usr_003",
        is_official=False,
        user_role="farmer",
        user_name="Grace Njeri",
        content=PostContent(
            text_short="Just planted H614 last week, rains are looking good. Anyone else planting maize in Gatanga?",
        ),
        location=(-0.94, 36.86),
        timestamp=datetime.now() - timedelta(hours=4),
        is_verified=False,
        reports=0,
        distance_km=2.1
    ),
    Post(
        post_id="usr_004",
        is_official=False,
        user_role="farmer",
        user_name="Peter Mwangi",
        content=PostContent(
            text_short="When is the best time to apply CAN fertilizer for maize? Plants are about knee height.",
        ),
        location=(-0.97, 36.89),
        timestamp=datetime.now() - timedelta(hours=1),
        is_verified=False,
        reports=0,
        distance_km=2.5
    ),
    Post(
        post_id="usr_005",
        is_official=False,
        user_role="expert",
        user_name="John Kamau",
        content=PostContent(
            text_short="Peter, knee height is perfect for 2nd top dressing. 1 tbsp CAN per plant, 10cm from stem. Wait for rain first.",
            image_low="👨‍🌾",
        ),
        location=(-0.95, 36.87),
        timestamp=datetime.now() - timedelta(minutes=50),
        is_verified=True,
        reports=0,
        distance_km=1.5
    ),
]


# ============================================================
# カラーパレット
# ============================================================

class Colors:
    PRIMARY = "#2E7D32"
    PRIMARY_LIGHT = "#4CAF50"
    PRIMARY_DARK = "#1B5E20"
    ACCENT = "#FF8F00"
    BACKGROUND = "#F1F8E9"
    SURFACE = "#FFFFFF"
    TEXT_PRIMARY = "#212121"
    TEXT_SECONDARY = "#757575"
    VERIFIED_GOLD = "#FFD700"
    DANGER = "#D32F2F"
    MODE_ACTIVE = "#E8F5E9"
    DIVIDER = "#E0E0E0"
    SEARCH_BG = "#FFFFFF"
    OFFICIAL_BG = "#FFF8E1"


# ============================================================
# メインアプリ
# ============================================================

def main(page: ft.Page):

    page.title = "Agridic - Agricultural Disease Information"
    page.bgcolor = Colors.BACKGROUND
    page.padding = 0
    page.window.width = 420
    page.window.min_width = 360
    page.window.height = 800
    page.scroll = None
    page.fonts = {
        "Outfit": "https://fonts.googleapis.com/css2?family=Outfit:wght@300;400;500;600;700&display=swap",
    }
    page.theme = ft.Theme(
        color_scheme_seed=Colors.PRIMARY,
        font_family="Outfit",
    )

    # ------------------------------------------------------------
    # グローバル状態 (State)
    # ------------------------------------------------------------
    state = {
        "search_mode": ViewMode.TEXT,
        "detail_mode": ViewMode.TEXT,
        "search_query": "",
        "current_location": (-0.95, 36.87),
        "nav_stack": [],  # 画面遷移スタック: 各要素は main_layout.controls のスナップショット
    }

    def _push_screen(new_controls, hide_fab=True, hide_nav=False):
        """現在の画面をスタックに保存して新画面に遷移"""
        state["nav_stack"].append({
            "controls": list(main_layout.controls),
            "fab_visible": page.floating_action_button.visible if page.floating_action_button else True,
            "nav_visible": page.navigation_bar.visible if page.navigation_bar else True,
        })
        main_layout.controls = new_controls
        if page.floating_action_button:
            page.floating_action_button.visible = not hide_fab
        if page.navigation_bar:
            page.navigation_bar.visible = not hide_nav
        page.update()

    def _pop_screen(e=None):
        """スタックから前の画面を復元"""
        if state["nav_stack"]:
            prev = state["nav_stack"].pop()
            main_layout.controls = prev["controls"]
            if page.floating_action_button:
                page.floating_action_button.visible = prev["fab_visible"]
            if page.navigation_bar:
                page.navigation_bar.visible = prev["nav_visible"]
            page.update()
        else:
            # スタック空 → ホームに戻る
            main_layout.controls = [header, search_bar, search_mode_container, feed_list]
            if page.floating_action_button:
                page.floating_action_button.visible = True
            if page.navigation_bar:
                page.navigation_bar.visible = True
            update_feed()
            page.update()

    def format_time(ts: datetime) -> str:
        if ts is None:
            return ""
        delta = datetime.now() - ts
        seconds = max(0, delta.total_seconds())
        if seconds < 60:
            return "now"
        elif seconds < 3600:
            return f"{int(seconds // 60)}m"
        elif seconds < 86400:
            return f"{int(seconds // 3600)}h"
        else:
            return f"{delta.days}d"


    # ============================================================
    # 投稿ダイアログ機能
    # ============================================================

    def _make_field(hint, multiline=False, min_lines=1, max_lines=1):
        """統一スタイルのTextField生成"""
        return ft.TextField(
            hint_text=hint,
            multiline=multiline,
            min_lines=min_lines,
            max_lines=max_lines,
            border_radius=8,
            text_size=14,
            content_padding=ft.Padding(12, 10, 12, 10),
        )

    def open_post_dialog():
        """全画面投稿エディタ"""
        dlg_state = {
            "type": "tweet",
            "tweet_image_path": "",
            # レポート用: 3モードそれぞれにブロックリスト
            "blocks_text": [],
            "blocks_manual": [],
            "blocks_visual": [],
            "active_mode": "text",  # 現在編集中のモードタブ
            "pin_location": list(state.get("current_location", (-0.95, 36.87))),
        }

        # ========================================
        # 【Tweet用】
        # ========================================
        tweet_text = _make_field(
            "What's happening in your farm?",
            multiline=True, min_lines=3, max_lines=8,
        )
        tweet_image_preview = ft.Column(spacing=4)

        async def pick_tweet_image(e):
            """Flet 0.82 async FilePicker"""
            try:
                files = await ft.FilePicker().pick_files(
                    file_type="image",
                    allow_multiple=False,
                )
                if files and len(files) > 0 and files[0].path:
                    path = files[0].path
                    dlg_state["tweet_image_path"] = path
                    tweet_image_preview.controls.clear()
                    tweet_image_preview.controls.append(
                        ft.Container(
                            content=ft.Row([
                                ft.Image(src=path, width=60, height=60, fit="cover", border_radius=6),
                                ft.Column([
                                    ft.Text(os.path.basename(path), size=12, color=Colors.PRIMARY),
                                    ft.TextButton(
                                        content=ft.Text("Remove", size=11, color=Colors.DANGER),
                                        on_click=lambda e: _clear_tweet_image(),
                                    ),
                                ], spacing=2),
                            ], spacing=8),
                            bgcolor="#F5F5F5", padding=8, border_radius=8,
                        )
                    )
                    page.update()
            except Exception as ex:
                print(f"FilePicker error: {ex}")

        def _clear_tweet_image():
            dlg_state["tweet_image_path"] = ""
            tweet_image_preview.controls.clear()
            page.update()

        def _remove_tweet_image():
            dlg_state["tweet_image_path"] = ""
            tweet_image_field.value = ""
            tweet_image_preview.controls.clear()
            page.update()

        # ========================================
        # 【Report用 ブロックエディタ】
        # ========================================
        rpt_title = _make_field("Report headline (shown on timeline)")
        rpt_crop = _make_field("Crop: e.g. Maize, Tomato...")
        rpt_location = _make_field("Location: e.g. Gatanga, Kiambu...")
        blocks_container = ft.Column(spacing=6)
        block_counter = {"n": 0}

        def _next_id():
            block_counter["n"] += 1
            return block_counter["n"]

        def _get_blocks():
            mode = dlg_state["active_mode"]
            return dlg_state[f"blocks_{mode}"]

        def _set_blocks(blocks):
            mode = dlg_state["active_mode"]
            dlg_state[f"blocks_{mode}"] = blocks

        def _add_block(block_type, after_id=None):
            """ブロック追加。after_id指定時はその後ろに挿入"""
            bid = _next_id()
            hints = {
                "heading": "Section heading...",
                "text": "Write paragraph text...",
                "bullets": "One bullet point per line...",
                "image": "Describe what this image shows...",
            }
            icons = {
                "heading": ft.Icons.TITLE,
                "text": None,
                "bullets": ft.Icons.FORMAT_LIST_BULLETED,
                "image": ft.Icons.IMAGE_OUTLINED,
            }
            ctrl = ft.TextField(
                hint_text=hints.get(block_type, ""),
                multiline=block_type in ("text", "bullets"),
                min_lines=1 if block_type in ("heading", "image") else 2,
                max_lines=1 if block_type == "heading" else 6,
                border_radius=8,
                text_size=15 if block_type == "heading" else 14,
                text_style=ft.TextStyle(weight=ft.FontWeight.W_600) if block_type == "heading" else None,
                content_padding=ft.Padding(12, 10, 12, 10),
                prefix_icon=icons.get(block_type),
            )
            block = {"type": block_type, "control": ctrl, "id": bid}
            blocks = _get_blocks()
            if after_id is not None:
                idx = next((i for i, b in enumerate(blocks) if b["id"] == after_id), len(blocks))
                blocks.insert(idx + 1, block)
            else:
                blocks.append(block)
            _rebuild_blocks_ui()

        def _remove_block(bid):
            blocks = _get_blocks()
            _set_blocks([b for b in blocks if b["id"] != bid])
            _rebuild_blocks_ui()

        def _move_block(bid, direction):
            blocks = _get_blocks()
            idx = next((i for i, b in enumerate(blocks) if b["id"] == bid), None)
            if idx is None:
                return
            new_idx = idx + direction
            if 0 <= new_idx < len(blocks):
                blocks[idx], blocks[new_idx] = blocks[new_idx], blocks[idx]
                _rebuild_blocks_ui()

        def _insert_btn_row(after_id=None):
            """ブロック間の＋ボタン行"""
            return ft.Container(
                content=ft.Row([
                    ft.TextButton(
                        content=ft.Row([ft.Icon(ft.Icons.TITLE, size=12, color=Colors.PRIMARY), ft.Text("Heading", size=10, color=Colors.PRIMARY)], spacing=2),
                        on_click=lambda e, a=after_id: _add_block("heading", a),
                    ),
                    ft.TextButton(
                        content=ft.Row([ft.Icon(ft.Icons.TEXT_FIELDS, size=12, color=Colors.PRIMARY), ft.Text("Text", size=10, color=Colors.PRIMARY)], spacing=2),
                        on_click=lambda e, a=after_id: _add_block("text", a),
                    ),
                    ft.TextButton(
                        content=ft.Row([ft.Icon(ft.Icons.FORMAT_LIST_BULLETED, size=12, color=Colors.PRIMARY), ft.Text("Bullets", size=10, color=Colors.PRIMARY)], spacing=2),
                        on_click=lambda e, a=after_id: _add_block("bullets", a),
                    ),
                    ft.TextButton(
                        content=ft.Row([ft.Icon(ft.Icons.IMAGE_OUTLINED, size=12, color=Colors.PRIMARY), ft.Text("Image", size=10, color=Colors.PRIMARY)], spacing=2),
                        on_click=lambda e, a=after_id: _add_block("image", a),
                    ),
                ], spacing=2, alignment=ft.MainAxisAlignment.CENTER),
                padding=ft.Padding(0, 2, 0, 2),
            )

        def _rebuild_blocks_ui():
            blocks_container.controls.clear()
            blocks = _get_blocks()

            # 先頭の挿入ボタン
            blocks_container.controls.append(_insert_btn_row(after_id=None))

            type_colors = {
                "heading": Colors.PRIMARY,
                "text": Colors.DIVIDER,
                "bullets": Colors.ACCENT,
                "image": "#90CAF9",
            }
            type_labels = {
                "heading": ("H", ft.Icons.TITLE),
                "text": ("T", ft.Icons.TEXT_FIELDS),
                "bullets": ("Li", ft.Icons.FORMAT_LIST_BULLETED),
                "image": ("Img", ft.Icons.IMAGE_OUTLINED),
            }

            for block in blocks:
                bid = block["id"]
                btype = block["type"]
                lbl, icon = type_labels.get(btype, ("?", ft.Icons.SQUARE))

                # ブロック内容
                block_content = [
                    ft.Row([
                        ft.Icon(icon, size=14, color=type_colors.get(btype, Colors.TEXT_SECONDARY)),
                        ft.Container(expand=True),
                        ft.IconButton(ft.Icons.ARROW_UPWARD, icon_size=14, icon_color=Colors.TEXT_SECONDARY,
                                      on_click=lambda e, b=bid: _move_block(b, -1)),
                        ft.IconButton(ft.Icons.ARROW_DOWNWARD, icon_size=14, icon_color=Colors.TEXT_SECONDARY,
                                      on_click=lambda e, b=bid: _move_block(b, 1)),
                        ft.IconButton(ft.Icons.CLOSE, icon_size=14, icon_color=Colors.DANGER,
                                      on_click=lambda e, b=bid: _remove_block(b)),
                    ], spacing=0),
                ]

                # 画像ブロックにはファイル選択ボタンを追加
                if btype == "image":
                    async def _pick_for_block(e, ctrl=block["control"]):
                        try:
                            files = await ft.FilePicker().pick_files(
                                file_type="image",
                                allow_multiple=False,
                            )
                            if files and len(files) > 0 and files[0].path:
                                ctrl.value = files[0].path
                                page.update()
                        except Exception as ex:
                            print(f"FilePicker error: {ex}")

                    block_content.append(
                        ft.Row([
                            ft.Container(content=block["control"], expand=True),
                            ft.IconButton(
                                ft.Icons.FOLDER_OPEN_OUTLINED,
                                icon_size=20, icon_color=Colors.PRIMARY,
                                on_click=_pick_for_block,
                                tooltip="Browse image",
                            ),
                        ], spacing=4),
                    )
                else:
                    block_content.append(block["control"])

                block_card = ft.Container(
                    content=ft.Column(block_content, spacing=2),
                    padding=ft.Padding(8, 4, 8, 8),
                    border_radius=8,
                    border=ft.Border(
                        left=ft.BorderSide(3, type_colors.get(btype, Colors.DIVIDER)),
                        top=ft.BorderSide(0.5, Colors.DIVIDER),
                        right=ft.BorderSide(0.5, Colors.DIVIDER),
                        bottom=ft.BorderSide(0.5, Colors.DIVIDER),
                    ),
                )
                blocks_container.controls.append(block_card)
                # 各ブロックの後ろに挿入ボタン
                blocks_container.controls.append(_insert_btn_row(after_id=bid))

            page.update()

        # ========================================
        # マップピン選択（レポート用）
        # ========================================
        pin_label = ft.Text(
            f"📍 {dlg_state['pin_location'][0]:.4f}, {dlg_state['pin_location'][1]:.4f}",
            size=12, color=Colors.TEXT_SECONDARY,
        )
        map_picker_container = ft.Container(visible=False)

        def _toggle_map_picker(e):
            show = not map_picker_container.visible
            map_picker_container.visible = show
            if show and HAS_MAP:
                lat, lng = dlg_state["pin_location"]
                pin_marker_ref = ft.Ref[ftm.MarkerLayer]()

                def _on_map_tap(ev):
                    if hasattr(ev, 'coordinates') and ev.coordinates:
                        new_lat = ev.coordinates.latitude
                        new_lng = ev.coordinates.longitude
                        dlg_state["pin_location"] = [new_lat, new_lng]
                        pin_label.value = f"📍 {new_lat:.4f}, {new_lng:.4f}"
                        # ピンを更新
                        pin_marker_ref.current.markers.clear()
                        pin_marker_ref.current.markers.append(
                            ftm.Marker(
                                content=ft.Icon(ft.Icons.LOCATION_ON, color="#D32F2F", size=30),
                                coordinates=ftm.MapLatitudeLongitude(new_lat, new_lng),
                            )
                        )
                        page.update()

                map_picker_container.content = ft.Container(
                    content=ftm.Map(
                        height=200,
                        initial_center=ftm.MapLatitudeLongitude(lat, lng),
                        initial_zoom=12.0,
                        interaction_configuration=ftm.InteractionConfiguration(
                            flags=ftm.InteractionFlag.ALL
                        ),
                        on_tap=_on_map_tap,
                        layers=[
                            ftm.TileLayer(
                                url_template="https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png",
                            ),
                            ftm.MarkerLayer(
                                ref=pin_marker_ref,
                                markers=[
                                    ftm.Marker(
                                        content=ft.Icon(ft.Icons.LOCATION_ON, color="#D32F2F", size=30),
                                        coordinates=ftm.MapLatitudeLongitude(lat, lng),
                                    ),
                                ],
                            ),
                        ],
                    ),
                    border_radius=8,
                    clip_behavior=ft.ClipBehavior.ANTI_ALIAS,
                )
            page.update()

        def _make_location_picker():
            if not HAS_MAP:
                return ft.Container()
            return ft.Container(
                content=ft.Column([
                    ft.Row([
                        pin_label,
                        ft.TextButton(
                            content=ft.Row([
                                ft.Icon(ft.Icons.EDIT_LOCATION_ALT_OUTLINED, size=14, color=Colors.PRIMARY),
                                ft.Text("Pick on Map", size=11, color=Colors.PRIMARY),
                            ], spacing=4),
                            on_click=_toggle_map_picker,
                        ),
                    ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
                    map_picker_container,
                ], spacing=4),
            )

        # ========================================
        # フォーム描画
        # ========================================
        form_scroll = ft.Column(spacing=10)

        def update_form():
            form_scroll.controls.clear()

            if dlg_state["type"] == "tweet":
                form_scroll.controls.extend([
                    ft.Container(
                        content=ft.Row([
                            ft.Icon(ft.Icons.EDIT_NOTE, size=20, color=Colors.PRIMARY),
                            ft.Text("Compose Tweet", weight=ft.FontWeight.BOLD, size=16),
                        ], spacing=8),
                    ),
                    tweet_text,
                    ft.OutlinedButton(
                        content=ft.Row([ft.Icon(ft.Icons.ADD_A_PHOTO_OUTLINED, size=16), ft.Text("Add Photo", size=12)], spacing=4),
                        on_click=pick_tweet_image,
                    ),
                    tweet_image_preview,
                ])
            else:
                # === Report 3モードタブ ===
                def set_mode(mode):
                    dlg_state["active_mode"] = mode
                    update_form()

                def _mode_tab(label, mode_key, icon):
                    is_active = dlg_state["active_mode"] == mode_key
                    return ft.Container(
                        content=ft.Column([
                            ft.Icon(icon, size=16, color=Colors.PRIMARY if is_active else Colors.TEXT_SECONDARY),
                            ft.Text(label, size=10, weight=ft.FontWeight.W_600 if is_active else ft.FontWeight.W_400,
                                    color=Colors.PRIMARY if is_active else Colors.TEXT_SECONDARY,
                                    text_align=ft.TextAlign.CENTER),
                        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=2),
                        padding=ft.Padding(8, 6, 8, 6),
                        border_radius=8,
                        bgcolor=Colors.MODE_ACTIVE if is_active else "transparent",
                        border=ft.Border(
                            bottom=ft.BorderSide(2, Colors.PRIMARY) if is_active else ft.BorderSide(1, Colors.DIVIDER),
                            top=ft.BorderSide(1, Colors.DIVIDER),
                            left=ft.BorderSide(1, Colors.DIVIDER),
                            right=ft.BorderSide(1, Colors.DIVIDER),
                        ),
                        on_click=lambda e, m=mode_key: set_mode(m),
                        expand=True,
                    )

                form_scroll.controls.extend([
                    ft.Container(
                        content=ft.Row([
                            ft.Icon(ft.Icons.VERIFIED_USER, size=20, color=Colors.PRIMARY),
                            ft.Text("Create Official Report", weight=ft.FontWeight.BOLD, size=16),
                        ], spacing=8),
                    ),
                    rpt_title,
                    ft.Row([ft.Container(content=rpt_crop, expand=True), ft.Container(content=rpt_location, expand=True)], spacing=8),
                    # マップピン選択
                    _make_location_picker(),
                    ft.Divider(height=1, color=Colors.DIVIDER),
                    ft.Text("Create content for each view mode:", size=12, color=Colors.TEXT_SECONDARY),
                    ft.Row([
                        _mode_tab("Text Only", "text", ft.Icons.TEXT_SNIPPET_OUTLINED),
                        _mode_tab("Text+Image", "manual", ft.Icons.AUTO_AWESOME_OUTLINED),
                        _mode_tab("Image Main", "visual", ft.Icons.IMAGE_OUTLINED),
                    ], spacing=4),
                    blocks_container,
                ])
                _rebuild_blocks_ui()

            page.update()

        # ========================================
        # タイプ切替
        # ========================================
        def set_type(ptype):
            dlg_state["type"] = ptype
            update_form()

        type_tabs = ft.SegmentedButton(
            selected=["tweet"],
            on_change=lambda e: set_type(list(e.control.selected)[0]),
            segments=[
                ft.Segment(value="tweet", label=ft.Text("Tweet")),
                ft.Segment(value="report", label=ft.Text("Report")),
            ],
        )

        # ========================================
        # Submit
        # ========================================
        def _show_error(msg):
            page.snack_bar = ft.SnackBar(ft.Text(msg), bgcolor=Colors.DANGER)
            page.snack_bar.open = True
            page.update()

        def _blocks_to_text(blocks):
            """ブロックリストを text_full 書式に変換"""
            lines = []
            images = []
            steps = []
            img_counter = 0
            for block in blocks:
                val = block["control"].value
                if not val or not val.strip():
                    continue
                val = val.strip()
                if block["type"] == "heading":
                    lines.append(f"## {val}")
                elif block["type"] == "text":
                    lines.extend([val, ""])
                elif block["type"] == "bullets":
                    for bl in val.split("\n"):
                        bl = bl.strip()
                        if bl:
                            if not bl.startswith("- "):
                                bl = f"- {bl}"
                            lines.append(bl)
                            steps.append(bl[2:] if bl.startswith("- ") else bl)
                    lines.append("")
                elif block["type"] == "image":
                    img_counter += 1
                    images.append(val)
                    lines.append(f"![{img_counter}]")
                    lines.append("")
            return "\n".join(lines), images, steps

        def submit(e):
            if dlg_state["type"] == "tweet":
                if not tweet_text.value or not tweet_text.value.strip():
                    _show_error("Please enter some text.")
                    return
                img_path = dlg_state.get("tweet_image_path", "")
                new_post = Post(
                    post_id=f"new_{len(DUMMY_POSTS)}_{int(datetime.now().timestamp())}",
                    is_official=False,
                    user_role="farmer",
                    user_name="You",
                    content=PostContent(
                        text_short=tweet_text.value.strip(),
                        image_low=img_path,
                        image_high=img_path,
                    ),
                    timestamp=datetime.now(),
                    is_verified=False,
                    location=state.get("current_location", (-0.95, 36.87)),
                )
            else:
                if not rpt_title.value or not rpt_title.value.strip():
                    _show_error("Please enter a headline.")
                    return
                headline = rpt_title.value.strip()
                crop = rpt_crop.value.strip() if rpt_crop.value else ""
                loc = rpt_location.value.strip() if rpt_location.value else ""

                short_parts = [headline]
                if crop:
                    short_parts.append(f"[{crop}]")
                if loc:
                    short_parts.append(f"— {loc}")

                meta_header = ""  # ヘッダーはブロックで自分で作る

                # 選択中モードのブロックのみ使用
                active_mode = dlg_state["active_mode"]
                active_blocks = dlg_state[f"blocks_{active_mode}"]
                tf, imgs, steps = _blocks_to_text(active_blocks)

                new_post = Post(
                    post_id=f"new_{len(DUMMY_POSTS)}_{int(datetime.now().timestamp())}",
                    is_official=True,
                    user_role="expert",
                    user_name="You (Expert)",
                    content=PostContent(
                        text_short=" ".join(short_parts),
                        text_full=tf,
                        steps=steps,
                        images=imgs,
                    ),
                    timestamp=datetime.now(),
                    is_verified=True,
                    location=tuple(dlg_state["pin_location"]),
                    view_mode=active_mode,
                )

            DUMMY_POSTS.insert(0, new_post)
            go_back(None)
            update_feed()
            feed_list.scroll_to(offset=0, duration=300)

            post_label = "Tweet" if dlg_state["type"] == "tweet" else "Report"
            page.snack_bar = ft.SnackBar(
                content=ft.Row([
                    ft.Icon(ft.Icons.CHECK_CIRCLE, color="white", size=18),
                    ft.Text(f"{post_label} posted!", color="white", weight=ft.FontWeight.W_500),
                ], spacing=8),
                bgcolor=Colors.PRIMARY, duration=2000,
            )
            page.snack_bar.open = True
            page.update()

        # ========================================
        # 全画面レイアウト
        # ========================================
        def go_back(e):
            _pop_screen()

        post_header = ft.Container(
            content=ft.Row([
                ft.Row([
                    ft.IconButton(ft.Icons.ARROW_BACK, icon_color="white", icon_size=20, on_click=go_back),
                    ft.Text("New Post", size=18, weight=ft.FontWeight.BOLD, color="white"),
                ], spacing=4),
                type_tabs,
            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
            bgcolor=Colors.PRIMARY,
            padding=ft.Padding(8, 10, 16, 10),
        )

        post_layout = ft.Column(
            controls=[
                post_header,
                ft.Container(
                    content=ft.ListView(controls=[form_scroll], spacing=0, expand=True, auto_scroll=False),
                    expand=True,
                    padding=ft.Padding(16, 8, 16, 8),
                ),
                ft.Container(
                    content=ft.ElevatedButton(
                        "Submit", on_click=submit,
                        bgcolor=Colors.PRIMARY, color="white",
                        width=float("inf"), height=48,
                        style=ft.ButtonStyle(shape=ft.RoundedRectangleBorder(radius=10)),
                    ),
                    padding=ft.Padding(16, 0, 16, 12),
                ),
            ],
            spacing=0,
            expand=True,
        )

        _push_screen([post_layout], hide_fab=True, hide_nav=True)
        update_form()


    # ============================================================
    # モード切り替えコンポーネント (共有UI)
    # ============================================================
    def get_mode_selector(on_change_callback, current_mode=ViewMode.TEXT):
        def _on_click(e, mode):
            on_change_callback(mode)

        MODE_INFO = [
            (ViewMode.TEXT, "Text Only", ft.Icons.TEXT_SNIPPET_OUTLINED, "Lowest data"),
            (ViewMode.MANUAL, "Text + Image", ft.Icons.AUTO_AWESOME_OUTLINED, "Best view"),
            (ViewMode.VISUAL, "Image Main", ft.Icons.IMAGE_OUTLINED, "Visual learners"),
        ]

        def _create_btn(label, icon, mode, desc):
            is_active = current_mode == mode
            return ft.Container(
                content=ft.Column(
                    controls=[
                        ft.Icon(icon, size=18, color=Colors.PRIMARY if is_active else Colors.TEXT_SECONDARY),
                        ft.Text(
                            label, size=11,
                            weight=ft.FontWeight.W_600 if is_active else ft.FontWeight.W_400,
                            color=Colors.PRIMARY if is_active else Colors.TEXT_SECONDARY,
                            text_align=ft.TextAlign.CENTER,
                        ),
                        ft.Text(
                            desc, size=9,
                            color=Colors.PRIMARY if is_active else Colors.TEXT_SECONDARY,
                            text_align=ft.TextAlign.CENTER,
                        ),
                    ],
                    horizontal_alignment=ft.CrossAxisAlignment.CENTER,
                    spacing=1,
                ),
                padding=ft.Padding(8, 8, 8, 8),
                border_radius=8,
                bgcolor=Colors.MODE_ACTIVE if is_active else "transparent",
                border=ft.border.all(
                    2 if is_active else 1,
                    Colors.PRIMARY if is_active else Colors.DIVIDER,
                ),
                on_click=lambda e, m=mode: _on_click(e, m),
                expand=True,
            )

        return ft.Container(
            content=ft.Column(
                [
                    ft.Text("View Mode", size=12, weight=ft.FontWeight.W_600, color=Colors.PRIMARY_DARK),
                    ft.Row(
                        [_create_btn(label, icon, mode, desc) for mode, label, icon, desc in MODE_INFO],
                        spacing=6,
                    ),
                ],
                spacing=6,
            ),
            padding=ft.Padding(12, 10, 12, 10),
            bgcolor=Colors.SURFACE,
            border=ft.border.only(bottom=ft.BorderSide(1, Colors.DIVIDER)),
        )

    def on_search_mode_change(mode):
        state["search_mode"] = mode
        update_feed()
        page.update()

    search_mode_container = ft.Container(visible=False)


    # ============================================================
    # カード生成
    # ============================================================
    def create_timeline_card(post: Post) -> ft.Container:
        """折りたたみ表示 (Twitter風)"""
        is_expert = post.user_role == "expert"

        avatar = ft.CircleAvatar(
            content=ft.Text(post.user_name[0], weight=ft.FontWeight.BOLD, color="white"),
            bgcolor=Colors.PRIMARY if is_expert else Colors.ACCENT,
            radius=20,
        )

        badge_items = []
        # 公式レポートにはバッジを追加
        if post.is_official:
            badge_items.append(
                ft.Container(
                    content=ft.Row([
                        ft.Icon(ft.Icons.VERIFIED_USER, size=12, color=Colors.PRIMARY_DARK),
                        ft.Text("Official", size=10, weight=ft.FontWeight.W_600, color=Colors.PRIMARY_DARK),
                    ], spacing=2),
                    bgcolor=Colors.MODE_ACTIVE,
                    padding=ft.Padding(6, 2, 6, 2),
                    border_radius=4,
                )
            )
        badge_items.append(
            ft.Text(post.user_name, weight=ft.FontWeight.BOLD, size=14, color=Colors.TEXT_PRIMARY),
        )
        if post.is_verified:
            badge_items.append(
                ft.Icon(
                    ft.Icons.VERIFIED,
                    color=Colors.VERIFIED_GOLD if post.is_official else Colors.PRIMARY,
                    size=14,
                )
            )
        badge_items.extend([
            ft.Text(f"@{post.user_role}", size=12, color=Colors.TEXT_SECONDARY),
            ft.Text("•", size=12, color=Colors.TEXT_SECONDARY),
            ft.Text(format_time(post.timestamp), size=12, color=Colors.TEXT_SECONDARY),
        ])

        thumb_row = ft.Container()
        if post.content.image_low:
            # ローカルファイルパスなら実画像を表示、絵文字ならフォールバック
            if os.path.isfile(post.content.image_low):
                thumb_row = ft.Container(
                    content=ft.Image(
                        src=post.content.image_low,
                        width=80, height=80,
                        fit="cover",
                        border_radius=6,
                    ),
                    padding=ft.Padding(0, 4, 0, 0),
                )
            else:
                thumb_row = ft.Container(
                    content=ft.Row([
                        ft.Text(post.content.image_low, size=20),
                        ft.Text("Photo placeholder", size=11, color=Colors.TEXT_SECONDARY),
                    ], spacing=6),
                    bgcolor="#F5F5F5",
                    padding=ft.Padding(8, 4, 8, 4),
                    border_radius=4,
                )

        # 公式レポートには「Tap to read」CTA追加
        cta_row = ft.Container()
        if post.is_official:
            cta_row = ft.Container(
                content=ft.Row([
                    ft.Icon(ft.Icons.MENU_BOOK_OUTLINED, size=14, color=Colors.PRIMARY),
                    ft.Text("Tap to read full report", size=12, color=Colors.PRIMARY, weight=ft.FontWeight.W_500),
                    ft.Icon(ft.Icons.ARROW_FORWARD_IOS, size=12, color=Colors.PRIMARY),
                ], spacing=4),
                padding=ft.Padding(8, 6, 8, 6),
                border_radius=6,
                bgcolor=Colors.MODE_ACTIVE,
                margin=ft.Margin(0, 4, 0, 0),
            )

        content = ft.Column(
            controls=[
                ft.Row(controls=badge_items, spacing=4),
                ft.Text(post.content.text_short, size=14, color=Colors.TEXT_PRIMARY),
                thumb_row,
                cta_row,
                ft.Row(
                    controls=[
                        ft.IconButton(ft.Icons.CHAT_BUBBLE_OUTLINE, icon_size=16, icon_color=Colors.TEXT_SECONDARY),
                        ft.IconButton(ft.Icons.FAVORITE_BORDER, icon_size=16, icon_color=Colors.TEXT_SECONDARY),
                        ft.TextButton(
                            content=ft.Row([
                                ft.Icon(ft.Icons.FLAG_OUTLINED, size=14, color=Colors.TEXT_SECONDARY),
                                ft.Text(f"Report ({post.reports})", size=11, color=Colors.TEXT_SECONDARY),
                            ], spacing=2),
                            on_click=lambda e, p=post: on_report(p),
                        ),
                    ],
                    alignment=ft.MainAxisAlignment.START,
                    spacing=0,
                ),
            ],
            spacing=4,
            expand=True,
        )

        return ft.Container(
            content=ft.Row([avatar, content], vertical_alignment=ft.CrossAxisAlignment.START, spacing=12),
            bgcolor=Colors.OFFICIAL_BG if post.is_official else Colors.SURFACE,
            padding=ft.Padding(16, 16, 16, 16),
            border=ft.border.only(
                bottom=ft.BorderSide(1, Colors.DIVIDER),
                left=ft.BorderSide(3, Colors.PRIMARY) if post.is_official else ft.BorderSide(0, "transparent"),
            ),
            on_click=lambda e, p=post: open_detail_view(p),
        )

    def on_report(post: Post):
        post.reports += 1
        if post.reports >= 3:
            page.snack_bar = ft.SnackBar(ft.Text("Post hidden based on community reports."), bgcolor=Colors.DANGER)
        else:
            page.snack_bar = ft.SnackBar(ft.Text(f"Reported. ({post.reports}/3)"), bgcolor=Colors.ACCENT)
        page.snack_bar.open = True
        update_feed()
        page.update()


    # ============================================================
    # フィード更新処理
    # ============================================================
    feed_list = ft.ListView(spacing=0, expand=True, auto_scroll=False)

    def update_feed():
        controls = []
        visible_posts = [p for p in DUMMY_POSTS if not p.is_hidden]

        if state["search_query"]:
            search_mode_container.visible = False
            search_mode_container.content = None

            query = state["search_query"].lower()
            hit_posts = [
                p for p in visible_posts
                if query in p.content.text_short.lower()
                or query in p.content.text_full.lower()
                or query in p.user_name.lower()
            ]

            officials = sorted(
                [p for p in hit_posts if p.is_official],
                key=lambda x: x.timestamp or datetime.min,
                reverse=True,
            )
            farmers = sorted(
                [p for p in hit_posts if not p.is_official],
                key=lambda x: x.timestamp or datetime.min,
                reverse=True,
            )

            if officials:
                controls.append(
                    ft.Container(
                        ft.Row([
                            ft.Icon(ft.Icons.VERIFIED_USER, size=14, color=Colors.PRIMARY),
                            ft.Text("Official Results", size=13, weight=ft.FontWeight.BOLD, color=Colors.PRIMARY),
                        ], spacing=4),
                        padding=ft.Padding(16, 16, 16, 8),
                    )
                )
                for p in officials:
                    controls.append(create_timeline_card(p))

            if farmers:
                controls.append(
                    ft.Container(
                        ft.Text("Discussions", size=13, weight=ft.FontWeight.BOLD, color=Colors.TEXT_SECONDARY),
                        padding=ft.Padding(16, 16, 16, 8),
                    )
                )
                for p in farmers:
                    controls.append(create_timeline_card(p))

            if not controls:
                controls.append(
                    ft.Container(
                        content=ft.Column([
                            ft.Icon(ft.Icons.SEARCH_OFF, size=40, color=Colors.TEXT_SECONDARY),
                            ft.Text("No results found"),
                        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                        padding=40,
                        alignment=ft.Alignment(0, 0),
                    )
                )
        else:
            search_mode_container.visible = False
            search_mode_container.content = None

            sorted_posts = sorted(
                visible_posts,
                key=lambda x: x.timestamp or datetime.min,
                reverse=True,
            )
            for p in sorted_posts:
                controls.append(create_timeline_card(p))

        feed_list.controls = controls


    # ============================================================
    # リッチテキストパーサー (## 見出し対応)
    # ============================================================
    def parse_rich_text(text: str, images: list = None) -> list:
        """
        text_full をパースして Flet コントロールのリストを返す。

        書式ルール:
          ## 見出し      → 大見出し (緑太字)
          ### 小見出し    → 小見出し (太字)
          - 箇条書き      → ドット付きリスト
          ![N]           → images[N-1] の画像を挿入 (1始まり)
          通常テキスト    → 本文
          空行            → スペーサー
        """
        if not text:
            return []
        if images is None:
            images = []
        controls = []
        for line in text.split("\n"):
            stripped = line.strip()
            if not stripped:
                controls.append(ft.Container(height=4))
            elif stripped.startswith("### "):
                controls.append(
                    ft.Text(stripped[4:], size=14, weight=ft.FontWeight.W_600, color=Colors.TEXT_PRIMARY)
                )
            elif stripped.startswith("## "):
                controls.append(ft.Container(height=4))
                controls.append(
                    ft.Container(
                        content=ft.Text(stripped[3:], size=15, weight=ft.FontWeight.W_600, color=Colors.PRIMARY_DARK),
                        border=ft.border.only(bottom=ft.BorderSide(2, Colors.PRIMARY_LIGHT)),
                        padding=ft.Padding(0, 0, 0, 4),
                    )
                )
            elif stripped.startswith("![") and "]" in stripped:
                # 画像マーカー: ![1], ![2], ...
                try:
                    idx = int(stripped[2:stripped.index("]")]) - 1
                    if 0 <= idx < len(images):
                        img_path = images[idx]
                        if os.path.isfile(img_path):
                            controls.append(
                                ft.Container(
                                    content=ft.Image(
                                        src=img_path,
                                        width=float("inf"),
                                        fit="contain",
                                        border_radius=8,
                                    ),
                                    padding=ft.Padding(0, 4, 0, 4),
                                )
                            )
                        else:
                            # 絵文字やプレースホルダー
                            controls.append(
                                ft.Container(
                                    content=ft.Row([
                                        ft.Icon(ft.Icons.IMAGE_OUTLINED, size=20, color=Colors.TEXT_SECONDARY),
                                        ft.Text(f"[Image {idx+1}: {img_path}]", size=12, color=Colors.TEXT_SECONDARY, italic=True),
                                    ], spacing=6),
                                    bgcolor="#F5F5F5",
                                    padding=ft.Padding(12, 8, 12, 8),
                                    border_radius=6,
                                )
                            )
                except (ValueError, IndexError):
                    controls.append(ft.Text(stripped, size=14, color=Colors.TEXT_PRIMARY))
            elif stripped.startswith("- "):
                controls.append(
                    ft.Row([
                        ft.Container(
                            width=6, height=6, border_radius=3,
                            bgcolor=Colors.PRIMARY,
                            margin=ft.Margin(0, 6, 0, 0),
                        ),
                        ft.Text(stripped[2:], size=14, color=Colors.TEXT_PRIMARY, expand=True),
                    ], spacing=8, vertical_alignment=ft.CrossAxisAlignment.START)
                )
            else:
                controls.append(ft.Text(stripped, size=14, color=Colors.TEXT_PRIMARY))
        return controls

    # ============================================================
    # 詳細画面 (全画面表示)
    # ============================================================
    def _build_steps_card(steps):
        """ステップカードを構築"""
        return ft.Container(
            content=ft.Column([
                ft.Row([
                    ft.Icon(ft.Icons.CHECKLIST_RTL, size=16, color=Colors.PRIMARY_DARK),
                    ft.Text("Action Plan", weight=ft.FontWeight.W_600, size=14, color=Colors.PRIMARY_DARK),
                ], spacing=6),
                ft.Container(height=4),
                *[
                    ft.Row([
                        ft.Container(
                            content=ft.Text(str(i + 1), size=11, weight=ft.FontWeight.W_600, color="white"),
                            width=22, height=22, border_radius=11,
                            bgcolor=Colors.PRIMARY, alignment=ft.Alignment(0, 0),
                        ),
                        ft.Text(step, size=13, color=Colors.TEXT_PRIMARY, expand=True),
                    ], spacing=10, vertical_alignment=ft.CrossAxisAlignment.START)
                    for i, step in enumerate(steps)
                ],
            ], spacing=8),
            bgcolor=Colors.MODE_ACTIVE, padding=16, border_radius=8,
            border=ft.border.all(1, ft.Colors.with_opacity(0.2, Colors.PRIMARY)),
        )

    def open_detail_view(post: Post):

        def build_detail_controls():
            """投稿者が選んだview_modeで表示"""
            details = []
            vm = post.view_mode if post.is_official else "text"
            imgs = post.content.images if post.content.images else []
            full_text = post.content.text_full or post.content.text_short

            if not post.is_official:
                # --- 一般投稿 ---
                details.append(ft.Text(post.content.text_short, size=16, color=Colors.TEXT_PRIMARY))
                if post.content.image_high and os.path.isfile(post.content.image_high):
                    details.append(ft.Image(src=post.content.image_high, width=float("inf"), fit="contain", border_radius=8))
                elif post.content.image_low and os.path.isfile(post.content.image_low):
                    details.append(ft.Image(src=post.content.image_low, width=200, height=200, fit="cover", border_radius=8))
                elif post.content.image_low:
                    details.append(ft.Container(content=ft.Text(post.content.image_low, size=48), alignment=ft.Alignment(0, 0), padding=16))
            else:
                # --- 公式レポート ---
                if vm == "text":
                    # Text Only: テキストのみ。画像なし。
                    text_no_images = "\n".join(
                        line for line in full_text.split("\n")
                        if not (line.strip().startswith("![") and "]" in line.strip())
                    )
                    details.extend(parse_rich_text(text_no_images, images=[]))

                    if post.content.steps:
                        details.append(ft.Container(height=8))
                        details.append(_build_steps_card(post.content.steps))

                elif vm == "manual":
                    # Text + Image: テキスト中に画像挿入。ステップも表示。
                    details.extend(parse_rich_text(full_text, images=imgs))

                    if post.content.steps:
                        details.append(ft.Container(height=8))
                        details.append(_build_steps_card(post.content.steps))

                elif vm == "visual":
                    # Image Main: 画像を先にドーンと並べ、テキストは最小限。
                    for img_path in imgs:
                        if os.path.isfile(img_path):
                            details.append(ft.Image(src=img_path, width=float("inf"), fit="contain", border_radius=8))
                        else:
                            details.append(
                                ft.Container(
                                    content=ft.Row([
                                        ft.Icon(ft.Icons.IMAGE_OUTLINED, size=24, color=Colors.TEXT_SECONDARY),
                                        ft.Text(f"{img_path}", size=12, color=Colors.TEXT_SECONDARY, italic=True),
                                    ], spacing=8),
                                    bgcolor="#F5F5F5", padding=12, border_radius=8,
                                )
                            )
                        details.append(ft.Container(height=4))

                    if not imgs and post.content.image_low:
                        details.append(ft.Container(content=ft.Text(post.content.image_low, size=64), alignment=ft.Alignment(0, 0), padding=16))

                    if post.content.steps:
                        details.append(ft.Container(height=8))
                        for i, step in enumerate(post.content.steps):
                            details.append(
                                ft.Row([
                                    ft.Container(
                                        content=ft.Text(str(i + 1), size=11, weight=ft.FontWeight.W_600, color="white"),
                                        width=22, height=22, border_radius=11,
                                        bgcolor=Colors.PRIMARY, alignment=ft.Alignment(0, 0),
                                    ),
                                    ft.Text(step, size=13, color=Colors.TEXT_PRIMARY, expand=True),
                                ], spacing=10, vertical_alignment=ft.CrossAxisAlignment.START)
                            )
                    else:
                        # ステップなし → テキスト簡潔に
                        plain = full_text
                        for prefix in ["## ", "### ", "- "]:
                            plain = plain.replace(prefix, "")
                        import re
                        plain = re.sub(r"!\[\d+\]", "", plain)
                        plain = "\n".join(line.strip() for line in plain.split("\n") if line.strip())
                        details.append(ft.Container(height=8))
                        details.append(ft.Text(plain, size=13, color=Colors.TEXT_SECONDARY))

            return details

        # --- 利用可能なモードを判定 ---
        available_modes = []
        if post.is_official:
            has_text = bool(post.content.text_full or post.content.text_short)
            has_images = bool(post.content.images)
            has_manual_override = bool(post.content.text_full_manual)
            has_visual_override = bool(post.content.text_full_visual)

            # text_full があれば Text Only は常に利用可能
            if has_text:
                available_modes.append("text")
            # 画像があるか、manual用テキストがあれば Text+Image 利用可能
            if has_text and (has_images or has_manual_override):
                available_modes.append("manual")
            # 画像があるか、visual用テキストがあれば Image Main 利用可能
            if has_images or has_visual_override:
                available_modes.append("visual")

            if not available_modes:
                available_modes.append("text")

        # 初期表示モード = 投稿者が選んだモード
        active_mode = {"value": post.view_mode if post.view_mode in available_modes else (available_modes[0] if available_modes else "text")}

        # --- コンテンツエリア ---
        content_area = ft.Column(spacing=8)
        mode_selector_container = ft.Container()

        def _get_text_for_mode(mode):
            if mode == "manual" and post.content.text_full_manual:
                return post.content.text_full_manual
            elif mode == "visual" and post.content.text_full_visual:
                return post.content.text_full_visual
            else:
                return post.content.text_full or post.content.text_short

        def _build_mode_selector():
            """利用可能なモードが2つ以上ある場合のみセレクターを表示"""
            if len(available_modes) <= 1:
                mode_selector_container.content = None
                return

            MODE_INFO = {
                "text": ("Text Only", ft.Icons.TEXT_SNIPPET_OUTLINED),
                "manual": ("Text + Image", ft.Icons.AUTO_AWESOME_OUTLINED),
                "visual": ("Image Main", ft.Icons.IMAGE_OUTLINED),
            }

            buttons = []
            for m in available_modes:
                label, icon = MODE_INFO.get(m, (m, ft.Icons.SQUARE))
                is_active = active_mode["value"] == m
                buttons.append(
                    ft.Container(
                        content=ft.Column([
                            ft.Icon(icon, size=16, color=Colors.PRIMARY if is_active else Colors.TEXT_SECONDARY),
                            ft.Text(label, size=10,
                                    weight=ft.FontWeight.W_600 if is_active else ft.FontWeight.W_400,
                                    color=Colors.PRIMARY if is_active else Colors.TEXT_SECONDARY,
                                    text_align=ft.TextAlign.CENTER),
                        ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=2),
                        padding=ft.Padding(8, 6, 8, 6),
                        border_radius=8,
                        bgcolor=Colors.MODE_ACTIVE if is_active else "transparent",
                        border=ft.Border(
                            bottom=ft.BorderSide(2, Colors.PRIMARY) if is_active else ft.BorderSide(1, Colors.DIVIDER),
                            top=ft.BorderSide(1, Colors.DIVIDER),
                            left=ft.BorderSide(1, Colors.DIVIDER),
                            right=ft.BorderSide(1, Colors.DIVIDER),
                        ),
                        on_click=lambda e, mode=m: _switch_mode(mode),
                        expand=True,
                    )
                )

            mode_selector_container.content = ft.Container(
                content=ft.Row(buttons, spacing=4),
                padding=ft.Padding(12, 8, 12, 8),
                bgcolor=Colors.SURFACE,
            )

        def _switch_mode(mode):
            active_mode["value"] = mode
            _build_mode_selector()
            _update_content()

        def _update_content():
            content_area.controls.clear()
            vm = active_mode["value"]
            full_text = _get_text_for_mode(vm)
            imgs = post.content.images if post.content.images else []

            if vm == "text":
                text_no_images = "\n".join(
                    line for line in full_text.split("\n")
                    if not (line.strip().startswith("![") and "]" in line.strip())
                )
                content_area.controls.extend(parse_rich_text(text_no_images, images=[]))
                if post.content.steps:
                    content_area.controls.append(ft.Container(height=8))
                    content_area.controls.append(_build_steps_card(post.content.steps))

            elif vm == "manual":
                content_area.controls.extend(parse_rich_text(full_text, images=imgs))
                if post.content.steps:
                    content_area.controls.append(ft.Container(height=8))
                    content_area.controls.append(_build_steps_card(post.content.steps))

            elif vm == "visual":
                for img_path in imgs:
                    if os.path.isfile(img_path):
                        content_area.controls.append(ft.Image(src=img_path, width=float("inf"), fit="contain", border_radius=8))
                    else:
                        content_area.controls.append(
                            ft.Container(
                                content=ft.Row([
                                    ft.Icon(ft.Icons.IMAGE_OUTLINED, size=24, color=Colors.TEXT_SECONDARY),
                                    ft.Text(f"{img_path}", size=12, color=Colors.TEXT_SECONDARY, italic=True),
                                ], spacing=8),
                                bgcolor="#F5F5F5", padding=12, border_radius=8,
                            )
                        )
                    content_area.controls.append(ft.Container(height=4))

                if not imgs and post.content.image_low:
                    content_area.controls.append(ft.Container(content=ft.Text(post.content.image_low, size=64), alignment=ft.Alignment(0, 0), padding=16))

                if post.content.steps:
                    content_area.controls.append(ft.Container(height=8))
                    for i, step in enumerate(post.content.steps):
                        content_area.controls.append(
                            ft.Row([
                                ft.Container(
                                    content=ft.Text(str(i + 1), size=11, weight=ft.FontWeight.W_600, color="white"),
                                    width=22, height=22, border_radius=11,
                                    bgcolor=Colors.PRIMARY, alignment=ft.Alignment(0, 0),
                                ),
                                ft.Text(step, size=13, color=Colors.TEXT_PRIMARY, expand=True),
                            ], spacing=10, vertical_alignment=ft.CrossAxisAlignment.START)
                        )
                else:
                    import re
                    plain = re.sub(r"!\[\d+\]", "", full_text)
                    for prefix in ["## ", "### ", "- "]:
                        plain = plain.replace(prefix, "")
                    plain = "\n".join(line.strip() for line in plain.split("\n") if line.strip())
                    content_area.controls.append(ft.Container(height=8))
                    content_area.controls.append(ft.Text(plain, size=13, color=Colors.TEXT_SECONDARY))

            page.update()

        # --- 戻るボタン ---
        def go_back(e):
            _pop_screen()

        detail_header = ft.Container(
            content=ft.Row([
                ft.Row([
                    ft.IconButton(ft.Icons.ARROW_BACK, icon_color="white", icon_size=20, on_click=go_back),
                    ft.Icon(
                        ft.Icons.VERIFIED_USER if post.is_official else ft.Icons.PERSON,
                        size=16, color="white",
                    ),
                    ft.Text(post.user_name, size=16, weight=ft.FontWeight.BOLD, color="white"),
                ], spacing=4),
                ft.Text(format_time(post.timestamp), size=12, color=ft.Colors.with_opacity(0.7, "white")),
            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
            bgcolor=Colors.PRIMARY,
            padding=ft.Padding(8, 10, 16, 10),
        )

        # 初期化
        _build_mode_selector()
        _update_content()

        detail_layout = ft.Column(
            controls=[
                detail_header,
                mode_selector_container,
                ft.Container(
                    content=ft.ListView(
                        controls=[content_area],
                        expand=True,
                        auto_scroll=False,
                    ),
                    expand=True,
                    padding=ft.Padding(16, 8, 16, 16),
                ),
            ],
            spacing=0,
            expand=True,
        )

        _push_screen([detail_layout], hide_fab=True, hide_nav=True)


    # ============================================================
    # UI構築とイベントバインディング
    # ============================================================
    def on_search(e):
        state["search_query"] = search_field.value or ""
        update_feed()
        page.update()

    def reset_home(e):
        search_field.value = ""
        state["search_query"] = ""
        update_feed()
        page.update()

    header = ft.Container(
        content=ft.Row(
            controls=[
                ft.Row([
                    ft.Icon(ft.Icons.ECO, color="white", size=24),
                    ft.Text("Agridic", size=20, weight=ft.FontWeight.BOLD, color="white", font_family="Outfit"),
                ], spacing=8),
                ft.IconButton(ft.Icons.HOME, icon_color="white", icon_size=20, on_click=reset_home),
            ],
            alignment=ft.MainAxisAlignment.SPACE_BETWEEN,
        ),
        bgcolor=Colors.PRIMARY,
        padding=ft.Padding(16, 12, 16, 12),
        shadow=ft.BoxShadow(0, 4, ft.Colors.with_opacity(0.1, "black"), ft.Offset(0, 2)),
    )

    search_field = ft.TextField(
        hint_text="Search timeline or tags...",
        prefix_icon=ft.Icons.SEARCH,
        border_radius=25,
        bgcolor=Colors.SEARCH_BG,
        content_padding=ft.Padding(16, 10, 16, 10),
        text_size=14,
        on_submit=on_search,
        on_change=lambda e: on_search(e) if not e.control.value else None,
    )
    search_bar = ft.Container(
        content=search_field,
        padding=ft.Padding(16, 12, 16, 12),
        bgcolor=Colors.BACKGROUND,
    )

    page.floating_action_button = ft.FloatingActionButton(
        icon=ft.Icons.ADD,
        bgcolor=Colors.PRIMARY,
        on_click=lambda _: open_post_dialog(),
    )

    # ============================================================
    # 辞書ページ
    # ============================================================
    def open_dict_view():
        """辞書ページ: 作物→カテゴリ→レポート のドリルダウン + 検索"""
        dict_state = {"path": [], "search": ""}  # path: ドリルダウンの階層

        dict_content = ft.Column(spacing=0, expand=True)
        dict_search_field = ft.TextField(
            hint_text="Search official reports...",
            prefix_icon=ft.Icons.SEARCH,
            border_radius=25,
            bgcolor=Colors.SEARCH_BG,
            content_padding=ft.Padding(16, 10, 16, 10),
            text_size=14,
            on_submit=lambda e: _dict_search(e),
            on_change=lambda e: _dict_search(e) if not e.control.value else None,
        )

        def _get_dict_posts():
            """公式レポートでdict_cropが設定されているもの"""
            return [p for p in DUMMY_POSTS if p.is_official and p.dict_crop and not p.is_hidden]

        def _get_crops():
            """作物一覧（重複除去、投稿数付き）"""
            posts = _get_dict_posts()
            crops = {}
            for p in posts:
                if p.dict_crop not in crops:
                    crops[p.dict_crop] = 0
                crops[p.dict_crop] += 1
            return crops

        def _get_categories(crop):
            """指定作物のカテゴリ一覧"""
            posts = _get_dict_posts()
            cats = {}
            for p in posts:
                if p.dict_crop == crop and p.dict_category:
                    if p.dict_category not in cats:
                        cats[p.dict_category] = 0
                    cats[p.dict_category] += 1
            return cats

        def _get_reports(crop, category):
            """指定作物・カテゴリのレポート一覧"""
            return [p for p in _get_dict_posts() if p.dict_crop == crop and p.dict_category == category]

        CROP_ICONS = {
            "Maize": "🌽",
            "Tomato": "🍅",
            "Bean": "🫘",
            "Potato": "🥔",
            "Coffee": "☕",
        }
        CAT_ICONS = {
            "Growing Guide": ft.Icons.MENU_BOOK,
            "Pests & Diseases": ft.Icons.BUG_REPORT,
            "Fertilizer": ft.Icons.SCIENCE,
            "Harvest & Storage": ft.Icons.WAREHOUSE,
        }

        def _make_list_tile(title, subtitle, icon_widget, on_click, count=None):
            """汎用リストタイル"""
            trailing = []
            if count is not None:
                trailing.append(
                    ft.Container(
                        content=ft.Text(str(count), size=12, weight=ft.FontWeight.W_600, color=Colors.PRIMARY),
                        bgcolor=Colors.MODE_ACTIVE,
                        padding=ft.Padding(8, 4, 8, 4),
                        border_radius=12,
                    )
                )
            trailing.append(ft.Icon(ft.Icons.CHEVRON_RIGHT, size=20, color=Colors.TEXT_SECONDARY))

            return ft.Container(
                content=ft.Row([
                    icon_widget,
                    ft.Column([
                        ft.Text(title, size=15, weight=ft.FontWeight.W_500, color=Colors.TEXT_PRIMARY),
                        ft.Text(subtitle, size=12, color=Colors.TEXT_SECONDARY) if subtitle else ft.Container(),
                    ], spacing=2, expand=True),
                    *trailing,
                ], spacing=12),
                padding=ft.Padding(16, 14, 16, 14),
                bgcolor=Colors.SURFACE,
                border=ft.Border(bottom=ft.BorderSide(0.5, Colors.DIVIDER)),
                on_click=on_click,
            )

        def _navigate(level, value=None):
            if value is not None:
                dict_state["path"].append(value)
            dict_state["search"] = ""
            dict_search_field.value = ""
            _rebuild_dict()
            _update_dict_header()

        def _go_back_dict(e=None):
            if dict_state["path"]:
                dict_state["path"].pop()
                dict_state["search"] = ""
                dict_search_field.value = ""
                _rebuild_dict()
                _update_dict_header()
            else:
                _pop_screen()

        def _dict_search(e):
            dict_state["search"] = dict_search_field.value.strip().lower() if dict_search_field.value else ""
            _rebuild_dict()
            _update_dict_header()

        def _rebuild_dict():
            dict_content.controls.clear()
            path = dict_state["path"]
            query = dict_state["search"]

            # --- 検索モード ---
            if query:
                results = []
                for p in _get_dict_posts():
                    searchable = (
                        p.content.text_short.lower() + " " +
                        p.content.text_full.lower() + " " +
                        p.dict_crop.lower() + " " +
                        p.dict_category.lower() + " " +
                        " ".join(p.dict_tags).lower()
                    )
                    if query in searchable:
                        results.append(p)

                if results:
                    dict_content.controls.append(
                        ft.Container(
                            content=ft.Text(f"{len(results)} report(s) found", size=12, color=Colors.TEXT_SECONDARY),
                            padding=ft.Padding(16, 12, 16, 4),
                        )
                    )
                    for p in results:
                        emoji = CROP_ICONS.get(p.dict_crop, "📄")
                        dict_content.controls.append(
                            _make_list_tile(
                                p.content.text_short,
                                f"{emoji} {p.dict_crop} → {p.dict_category}",
                                ft.Icon(ft.Icons.VERIFIED_USER, size=20, color=Colors.PRIMARY),
                                on_click=lambda e, post=p: open_detail_view(post),
                            )
                        )
                else:
                    dict_content.controls.append(
                        ft.Container(
                            content=ft.Column([
                                ft.Icon(ft.Icons.SEARCH_OFF, size=40, color=Colors.TEXT_SECONDARY),
                                ft.Text("No reports found", size=14, color=Colors.TEXT_SECONDARY),
                            ], horizontal_alignment=ft.CrossAxisAlignment.CENTER, spacing=8),
                            padding=40, alignment=ft.Alignment(0, 0),
                        )
                    )

            # --- Level 0: 作物選択 ---
            elif len(path) == 0:
                crops = _get_crops()
                dict_content.controls.append(
                    ft.Container(
                        content=ft.Text("Select a crop", size=13, color=Colors.TEXT_SECONDARY),
                        padding=ft.Padding(16, 12, 16, 4),
                    )
                )
                for crop, count in sorted(crops.items()):
                    emoji = CROP_ICONS.get(crop, "🌱")
                    dict_content.controls.append(
                        _make_list_tile(
                            crop,
                            f"{count} report(s) available",
                            ft.Text(emoji, size=28),
                            on_click=lambda e, c=crop: _navigate(1, c),
                            count=count,
                        )
                    )

            # --- Level 1: カテゴリ選択 ---
            elif len(path) == 1:
                crop = path[0]
                cats = _get_categories(crop)
                emoji = CROP_ICONS.get(crop, "🌱")
                dict_content.controls.append(
                    ft.Container(
                        content=ft.Row([
                            ft.Text(emoji, size=20),
                            ft.Text(crop, size=16, weight=ft.FontWeight.W_600, color=Colors.TEXT_PRIMARY),
                        ], spacing=8),
                        padding=ft.Padding(16, 12, 16, 4),
                    )
                )
                for cat, count in sorted(cats.items()):
                    cat_icon = CAT_ICONS.get(cat, ft.Icons.FOLDER_OUTLINED)
                    dict_content.controls.append(
                        _make_list_tile(
                            cat,
                            f"{count} report(s)",
                            ft.Icon(cat_icon, size=22, color=Colors.PRIMARY),
                            on_click=lambda e, c=cat: _navigate(2, c),
                            count=count,
                        )
                    )

            # --- Level 2: レポート一覧 ---
            elif len(path) == 2:
                crop, category = path[0], path[1]
                reports = _get_reports(crop, category)
                emoji = CROP_ICONS.get(crop, "🌱")
                cat_icon = CAT_ICONS.get(category, ft.Icons.FOLDER_OUTLINED)
                dict_content.controls.append(
                    ft.Container(
                        content=ft.Row([
                            ft.Text(emoji, size=18),
                            ft.Text(f"{crop} → {category}", size=14, weight=ft.FontWeight.W_500, color=Colors.TEXT_SECONDARY),
                        ], spacing=8),
                        padding=ft.Padding(16, 12, 16, 4),
                    )
                )
                for p in reports:
                    dict_content.controls.append(
                        _make_list_tile(
                            p.content.text_short,
                            f"by {p.user_name} • {format_time(p.timestamp)}",
                            ft.Icon(ft.Icons.VERIFIED_USER, size=20, color=Colors.PRIMARY),
                            on_click=lambda e, post=p: open_detail_view(post),
                        )
                    )

            page.update()

        # --- 辞書ヘッダー ---
        def _make_dict_header():
            path = dict_state["path"]
            back_visible = len(path) > 0
            title = "Dictionary"
            if len(path) == 1:
                title = path[0]
            elif len(path) == 2:
                title = path[1]

            return ft.Container(
                content=ft.Row([
                    ft.Row([
                        ft.IconButton(
                            ft.Icons.ARROW_BACK, icon_color="white", icon_size=20,
                            on_click=_go_back_dict,
                            visible=back_visible,
                        ) if back_visible else ft.Container(width=8),
                        ft.Icon(ft.Icons.MENU_BOOK, color="white", size=22),
                        ft.Text(title, size=18, weight=ft.FontWeight.BOLD, color="white"),
                    ], spacing=4),
                ], alignment=ft.MainAxisAlignment.START),
                bgcolor=Colors.PRIMARY_DARK,
                padding=ft.Padding(8, 12, 16, 12),
            )

        dict_header_container = ft.Container()
        def _update_dict_header():
            dict_header_container.content = _make_dict_header()

        # 初期構築
        _rebuild_dict()
        _update_dict_header()

        # レイアウト
        dict_layout = ft.Column(
            controls=[
                dict_header_container,
                ft.Container(
                    content=dict_search_field,
                    padding=ft.Padding(16, 8, 16, 8),
                    bgcolor=Colors.BACKGROUND,
                ),
                ft.Container(
                    content=ft.ListView(controls=[dict_content], expand=True, auto_scroll=False),
                    expand=True,
                ),
            ],
            spacing=0,
            expand=True,
        )

        # イベントハンドラ接続
        dict_search_field.on_submit = _dict_search
        dict_search_field.on_change = lambda e: _dict_search(e) if not e.control.value else None

        _push_screen([dict_layout], hide_fab=True, hide_nav=False)
        _rebuild_dict()
        _update_dict_header()

    # ============================================================
    # マップページ
    # ============================================================
    def open_map_view():
        """マップページ: 公式レポートの位置をピンで表示"""
        if not HAS_MAP:
            page.snack_bar = ft.SnackBar(
                ft.Text("Map not available. Run: pip install flet-map flet-geolocator"),
                bgcolor=Colors.DANGER,
            )
            page.snack_bar.open = True
            page.update()
            return

        # Gatanga中心
        GATANGA_LAT = -0.95
        GATANGA_LNG = 36.87
        DEFAULT_ZOOM = 10.0

        # 公式レポートのピンを作成
        official_posts = [p for p in DUMMY_POSTS if p.is_official and p.location and not p.is_hidden]

        markers = []
        for p in official_posts:
            lat, lng = p.location
            markers.append(
                ftm.Marker(
                    content=ft.Container(
                        content=ft.Column([
                            ft.Icon(ft.Icons.LOCATION_ON, color="#D32F2F", size=30),
                        ], spacing=0, horizontal_alignment=ft.CrossAxisAlignment.CENTER),
                        on_click=lambda e, post=p: open_detail_view(post),
                    ),
                    coordinates=ftm.MapLatitudeLongitude(lat, lng),
                )
            )

        # 一般投稿のピン（小さめ、グレー系）
        farmer_posts = [p for p in DUMMY_POSTS if not p.is_official and p.location and not p.is_hidden]
        for p in farmer_posts:
            lat, lng = p.location
            markers.append(
                ftm.Marker(
                    content=ft.Container(
                        content=ft.Icon(ft.Icons.CIRCLE, color=Colors.ACCENT, size=12),
                        on_click=lambda e, post=p: open_detail_view(post),
                    ),
                    coordinates=ftm.MapLatitudeLongitude(lat, lng),
                )
            )

        # 選択中レポート情報パネル
        info_panel = ft.Container(visible=False)

        def _on_marker_tap(post):
            info_panel.content = ft.Container(
                content=ft.Row([
                    ft.Column([
                        ft.Text(post.content.text_short, size=13, weight=ft.FontWeight.W_500,
                                color=Colors.TEXT_PRIMARY, max_lines=2),
                        ft.Text(f"by {post.user_name} • {format_time(post.timestamp)}",
                                size=11, color=Colors.TEXT_SECONDARY),
                    ], spacing=2, expand=True),
                    ft.IconButton(ft.Icons.ARROW_FORWARD, icon_color=Colors.PRIMARY,
                                  on_click=lambda e: open_detail_view(post)),
                ], spacing=8),
                bgcolor=Colors.SURFACE,
                padding=12,
                border_radius=12,
                shadow=ft.BoxShadow(0, 4, ft.Colors.with_opacity(0.15, "black"), ft.Offset(0, 2)),
            )
            info_panel.visible = True
            page.update()

        # マップ本体
        map_widget = ftm.Map(
            expand=True,
            initial_center=ftm.MapLatitudeLongitude(GATANGA_LAT, GATANGA_LNG),
            initial_zoom=DEFAULT_ZOOM,
            interaction_configuration=ftm.InteractionConfiguration(
                flags=ftm.InteractionFlag.ALL
            ),
            layers=[
                ftm.TileLayer(
                    url_template="https://a.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}@2x.png",
                ),
                ftm.MarkerLayer(markers=markers),
            ],
        )

        # 凡例
        legend = ft.Container(
            content=ft.Row([
                ft.Icon(ft.Icons.LOCATION_ON, color="#D32F2F", size=16),
                ft.Text("Official Report", size=11, color=Colors.TEXT_SECONDARY),
                ft.Container(width=12),
                ft.Icon(ft.Icons.CIRCLE, color=Colors.ACCENT, size=10),
                ft.Text("Farmer Post", size=11, color=Colors.TEXT_SECONDARY),
            ], spacing=4),
            padding=ft.Padding(12, 6, 12, 6),
            bgcolor=ft.Colors.with_opacity(0.9, Colors.SURFACE),
            border_radius=20,
        )

        def go_back_map(e):
            _pop_screen()

        map_header = ft.Container(
            content=ft.Row([
                ft.Row([
                    ft.IconButton(ft.Icons.ARROW_BACK, icon_color="white", icon_size=20, on_click=go_back_map),
                    ft.Icon(ft.Icons.MAP, color="white", size=22),
                    ft.Text("Map", size=18, weight=ft.FontWeight.BOLD, color="white"),
                ], spacing=4),
                ft.Text(f"{len(official_posts)} reports", size=12, color=ft.Colors.with_opacity(0.7, "white")),
            ], alignment=ft.MainAxisAlignment.SPACE_BETWEEN),
            bgcolor=Colors.PRIMARY,
            padding=ft.Padding(8, 12, 16, 12),
        )

        map_layout = ft.Column(
            controls=[
                map_header,
                ft.Stack(
                    controls=[
                        map_widget,
                        ft.Container(content=legend, left=12, top=12),
                        ft.Container(content=info_panel, left=12, right=12, bottom=12),
                    ],
                    expand=True,
                ),
            ],
            spacing=0,
            expand=True,
        )

        _push_screen([map_layout], hide_fab=True, hide_nav=False)

    def on_nav_change(e):
        idx = e.control.selected_index
        if idx == 0:
            # Home
            search_field.value = ""
            state["search_query"] = ""
            state["nav_stack"].clear()  # スタッククリア
            main_layout.controls = [header, search_bar, search_mode_container, feed_list]
            page.floating_action_button.visible = True
            page.navigation_bar.visible = True
            update_feed()
            feed_list.scroll_to(offset=0, duration=200)
            page.update()
        elif idx == 1:
            # Dict
            open_dict_view()
        elif idx == 2:
            # Post
            open_post_dialog()
            e.control.selected_index = 0
            page.update()
        elif idx == 3:
            # Map
            open_map_view()

    bottom_nav = ft.NavigationBar(
        selected_index=0,
        bgcolor=Colors.SURFACE,
        indicator_color=Colors.MODE_ACTIVE,
        on_change=on_nav_change,
        destinations=[
            ft.NavigationBarDestination(icon=ft.Icons.HOME_OUTLINED, selected_icon=ft.Icons.HOME, label="Home"),
            ft.NavigationBarDestination(icon=ft.Icons.MENU_BOOK_OUTLINED, selected_icon=ft.Icons.MENU_BOOK, label="Dict"),
            ft.NavigationBarDestination(icon=ft.Icons.ADD_CIRCLE_OUTLINE, selected_icon=ft.Icons.ADD_CIRCLE, label="Post"),
            ft.NavigationBarDestination(icon=ft.Icons.MAP_OUTLINED, selected_icon=ft.Icons.MAP, label="Map"),
            ft.NavigationBarDestination(icon=ft.Icons.PERSON_OUTLINE, selected_icon=ft.Icons.PERSON, label="Profile"),
        ],
    )
    page.navigation_bar = bottom_nav

    update_feed()
    main_layout = ft.Column(
        controls=[header, search_bar, search_mode_container, feed_list],
        spacing=0,
        expand=True,
    )

    page.add(main_layout)


if __name__ == "__main__":
    ft.app(target=main)
