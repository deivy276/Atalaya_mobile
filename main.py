import flet as ft
import flet_charts as fch
import threading
import time
import math
import pg8000.native
from datetime import datetime, timedelta, timezone

# -----------------------------
# 1. CONFIGURATION
# -----------------------------
# Recommended: put a local logo in your project at: assets/Atalaya.png
# and keep LOGO_ASSET = "Atalaya.png".
# If you don't want/need local assets, keep LOGO_URL fallback.
ASSETS_DIR = "assets"
LOGO_ASSET = "Atalaya.png"
LOGO_URL = "https://raw.githubusercontent.com/deivy276/Atalaya/main/Logos/Logo%20Atalaya.png"

DB_CONFIG = {
    "host": "dpg-d5hbi64hg0os73ft22ng-a.oregon-postgres.render.com",
    "database": "atalaya_db",
    "user": "atalaya_db_user",
    "port": 5432,
    "password": None,
}

STALE_THRESHOLD_SECONDS = 10  # >10s => STALE (yellow)
OFFLINE_MAX_RETRIES = 5       # X retries => OFFLINE (red)


def main(page: ft.Page):

    # -----------------------------
    # PRO PALETTE
    # -----------------------------
    COLORS = {
        "bg": "#0B1220",
        "panel": "#0F1B33",
        "card": "#111827",
        "stroke": "#22304A",
        "text": "#E5E7EB",
        "muted": "#94A3B8",
        "accent": "#34D399",
        "ok": "#22C55E",
        "warn": "#F59E0B",
        "danger": "#EF4444",
        "chip_bg": "#0B1220",
        "overlay": "#000000AA",
    }

    # ---- Page
    page.title = "Atalaya Mobile v2"
    page.bgcolor = COLORS["bg"]
    page.padding = 0
    # Some runtimes (mobile/web) may not support forcing window size.
    try:
        page.window_width = 390
        page.window_height = 800
    except Exception:
        pass

    # Prefer enum when available; fallback to string for older versions.
    try:
        page.theme_mode = ft.ThemeMode.DARK
    except Exception:
        page.theme_mode = "dark"

    # ==========================================
    # THREAD-SAFE UI UPDATE
    # ==========================================
    ui_lock = threading.Lock()

    def safe_page_update():
        """Safely call page.update() from background threads."""
        try:
            with ui_lock:
                page.update()
        except Exception as ex:
            print(f"UI update error: {ex}")

    def run_bg(fn):
        """Run a function in background in the most stable way available."""
        try:
            if hasattr(page, "run_thread"):
                # Some Flet runtimes provide page.run_thread
                page.run_thread(fn)
                return
        except Exception:
            pass
        threading.Thread(target=fn, daemon=True).start()


    # ==========================================
    # FLET VERSION COMPAT HELPERS (Wrap / Row.wrap)
    # ==========================================
    def make_buttons_group(btns, spacing=8, run_spacing=8):
        """Return a wrapping group of buttons if available; fallback to Row/Column."""
        # Prefer Wrap if available (newer Flet)
        if hasattr(ft, 'Wrap'):
            WA = getattr(ft, 'WrapAlignment', None)
            return ft.Wrap(
                btns,
                spacing=spacing,
                run_spacing=run_spacing,
                alignment=(WA.END if WA else None),
            )

        # Fallback: Row (some versions support wrap=True)
        MA = getattr(ft, 'MainAxisAlignment', None)
        align_end = MA.END if MA else 'end'
        try:
            return row_maybe_wrap(btns, spacing=spacing, alignment=align_end, wrap=True)
        except TypeError:
            # Older Flet: Row has no wrap param
            return ft.Row(btns, spacing=spacing, alignment=align_end)

    def row_maybe_wrap(controls, spacing=8, wrap=False, alignment=None):
        """Create a Row with optional wrap when supported."""
        if not wrap:
            return ft.Row(controls, spacing=spacing, alignment=alignment)
        # Some Flet versions support Row(wrap=True); older ones don't.
        try:
            return ft.Row(controls, spacing=spacing, alignment=alignment, wrap=True)
        except TypeError:
            return ft.Row(controls, spacing=spacing, alignment=alignment)
    # ==========================================
    # HELPERS
    # ==========================================
    def norm_key(s: str) -> str:
        return str(s).strip().upper()

    def norm_tag(s: str) -> str:
        s = str(s).strip()
        while s.endswith("."):
            s = s[:-1]
        return s.strip()

    def norm_unit(u: str) -> str:
        u = "" if u is None else str(u).strip()
        if not u:
            return ""
        u_low = u.strip().lower()

        # normalize spacing
        u_low = u_low.replace("^", "")
        u_low = u_low.replace(" ", "")

        # common aliases
        if u_low in ("lb", "lbs", "lbf"):
            return "lbs"
        if u_low in ("klbf", "kips"):
            return "klbf"
        if u_low in ("kn", "knf"):
            return "kN"
        if "ton(us" in u_low or "tonus" in u_low or "shortton" in u_low:
            return "ton (US)"
        if u_low == "ton":
            return "ton"  # metric ton

        if u_low in ("psi", "psia"):
            return "psi"
        if u_low in ("bar",):
            return "bar"
        if u_low in ("kpa",):
            return "kPa"
        if u_low in ("mpa",):
            return "MPa"

        if u_low in ("m", "meter", "metre"):
            return "m"
        if u_low in ("ft", "feet"):
            return "ft"

        if u_low in ("m/min", "mpermin", "mmin"):
            return "m/min"
        if u_low in ("ft/min", "ftpermin", "ftmin"):
            return "ft/min"

        # flow
        if u_low in ("m3/min", "m³/min", "m3min", "m3permin"):
            return "m3/min"
        if u_low in ("bbl/min", "bblmin", "bblpermin", "bpm"):
            return "bbl/min"

        # temperature
        if u_low in ("c", "°c", "degc"):
            return "°C"
        if u_low in ("f", "°f", "degf"):
            return "°F"

        return str(u).strip()

    def to_datetime_safe(x):
        if x is None:
            return None
        if isinstance(x, datetime):
            return x
        try:
            s = str(x).strip()
            if s.endswith("Z"):
                s = s[:-1] + "+00:00"
            return datetime.fromisoformat(s)
        except Exception:
            return None

    def to_utc_aware(dt):
        if dt is None:
            return None
        if dt.tzinfo is None:
            return dt.replace(tzinfo=timezone.utc)
        return dt.astimezone(timezone.utc)

    # Timezone handling (Mexico City) with safe fallback
    try:
        from zoneinfo import ZoneInfo
        MX_TZ = ZoneInfo("America/Mexico_City")
    except Exception:
        MX_TZ = None

    def to_local_mx(dt_utc_or_any):
        dt_utc = to_utc_aware(dt_utc_or_any)
        if dt_utc is None:
            return None
        if MX_TZ is not None:
            try:
                return dt_utc.astimezone(MX_TZ).replace(tzinfo=None)
            except Exception:
                pass
        return (dt_utc - timedelta(hours=6)).replace(tzinfo=None)

    def age_seconds_from_dt(dt_utc_or_any):
        dt_utc = to_utc_aware(dt_utc_or_any)
        if dt_utc is None:
            return None
        now_utc = datetime.now(timezone.utc)
        return (now_utc - dt_utc).total_seconds()

    def fmt_num(x: float) -> str:
        try:
            x = float(x)
        except Exception:
            return str(x)
        ax = abs(x)
        if ax >= 1000:
            return f"{x:.0f}"
        if ax >= 100:
            return f"{x:.0f}"
        if ax >= 1:
            return f"{x:.1f}"
        return f"{x:.3f}"

    # ==========================================
    # UNIT CONVERSION (per variable)
    # ==========================================
    # Preferences depend on context and raw unit received.
    # Key format: WELL|JOB|SLOTn|TAG|RAW_UNIT
    # Preferences store (persisted locally when possible)
    try:
        unit_prefs = page.client_storage.get("unit_prefs") or {}
        if not isinstance(unit_prefs, dict):
            unit_prefs = {}
    except Exception:
        unit_prefs = {}

    # Shared context for unit preferences (well/job)
    ctx_state = {"well": "---", "job": "---"}


    # conversion factors
    PSI_TO_BAR = 0.0689475729
    M_TO_FT = 3.280839895
    M3_TO_BBL = 6.289810770432105
    LBF_TO_N = 4.4482216152605
    LBF_PER_METRIC_TON = 2204.6226218487757
    LBF_PER_SHORT_TON = 2000.0

    def unit_dimension(u: str) -> str:
        u = norm_unit(u)
        if u in ("psi", "bar", "kPa", "MPa"):
            return "pressure"
        if u in ("m", "ft"):
            return "length"
        if u in ("m/min", "ft/min"):
            return "velocity"
        if u in ("m3/min", "bbl/min"):
            return "flow"
        if u in ("lbs", "klbf", "kN", "ton", "ton (US)"):
            return "force"
        if u in ("°C", "°F"):
            return "temperature"
        return ""

    def convert_value(val: float, from_u: str, to_u: str):
        """Convert numeric value between supported units."""
        from_u = norm_unit(from_u)
        to_u = norm_unit(to_u)
        if not from_u or not to_u or from_u == to_u:
            return val

        dim = unit_dimension(from_u)
        if dim != unit_dimension(to_u):
            # unsupported cross-dimension conversion
            return val

        # Pressure
        if dim == "pressure":
            # psi <-> bar
            if from_u == "psi" and to_u == "bar":
                return val * PSI_TO_BAR
            if from_u == "bar" and to_u == "psi":
                return val / PSI_TO_BAR
            # psi <-> kPa
            if from_u == "psi" and to_u == "kPa":
                return val * 6.89475729
            if from_u == "kPa" and to_u == "psi":
                return val / 6.89475729
            # psi <-> MPa
            if from_u == "psi" and to_u == "MPa":
                return val * 0.00689475729
            if from_u == "MPa" and to_u == "psi":
                return val / 0.00689475729
            # bar <-> kPa
            if from_u == "bar" and to_u == "kPa":
                return val * 100.0
            if from_u == "kPa" and to_u == "bar":
                return val / 100.0
            # bar <-> MPa
            if from_u == "bar" and to_u == "MPa":
                return val / 10.0
            if from_u == "MPa" and to_u == "bar":
                return val * 10.0
            # kPa <-> MPa
            if from_u == "kPa" and to_u == "MPa":
                return val / 1000.0
            if from_u == "MPa" and to_u == "kPa":
                return val * 1000.0
            return val

        # Length
        if dim == "length":
            if from_u == "m" and to_u == "ft":
                return val * M_TO_FT
            if from_u == "ft" and to_u == "m":
                return val / M_TO_FT
            return val

        # Velocity
        if dim == "velocity":
            if from_u == "m/min" and to_u == "ft/min":
                return val * M_TO_FT
            if from_u == "ft/min" and to_u == "m/min":
                return val / M_TO_FT
            return val

        # Flow
        if dim == "flow":
            if from_u == "m3/min" and to_u == "bbl/min":
                return val * M3_TO_BBL
            if from_u == "bbl/min" and to_u == "m3/min":
                return val / M3_TO_BBL
            return val

        # Force / weight
        if dim == "force":
            # Normalize everything to lbs first
            lbs = None
            if from_u == "lbs":
                lbs = val
            elif from_u == "klbf":
                lbs = val * 1000.0
            elif from_u == "kN":
                lbs = (val * 1000.0) / LBF_TO_N
            elif from_u == "ton":
                lbs = val * LBF_PER_METRIC_TON
            elif from_u == "ton (US)":
                lbs = val * LBF_PER_SHORT_TON

            if lbs is None:
                return val

            if to_u == "lbs":
                return lbs
            if to_u == "klbf":
                return lbs / 1000.0
            if to_u == "kN":
                return (lbs * LBF_TO_N) / 1000.0
            if to_u == "ton":
                return lbs / LBF_PER_METRIC_TON
            if to_u == "ton (US)":
                return lbs / LBF_PER_SHORT_TON
            return val

        # Temperature
        if dim == "temperature":
            if from_u == "°C" and to_u == "°F":
                return (val * 9.0 / 5.0) + 32.0
            if from_u == "°F" and to_u == "°C":
                return (val - 32.0) * 5.0 / 9.0
            return val

        return val

    def make_pref_key(slot_idx: int, tag: str, raw_unit: str, well: str, job: str) -> str:
        well_k = norm_key(well)
        job_k = norm_key(job)
        slot_k = f"SLOT{slot_idx + 1}"
        tag_k = norm_tag(tag)
        raw_u = norm_unit(raw_unit)
        return "|".join([well_k, job_k, slot_k, tag_k, raw_u])

    def get_unit_options(raw_unit: str):
        raw_u = norm_unit(raw_unit)
        if not raw_u:
            return []
        dim = unit_dimension(raw_u)
        # Always include RAW
        if dim == "pressure":
            # SI preference requested: bar
            opts = ["RAW", raw_u, "bar", "psi", "MPa", "kPa"]
        elif dim == "length":
            opts = ["RAW", raw_u, "m", "ft"]
        elif dim == "velocity":
            opts = ["RAW", raw_u, "m/min", "ft/min"]
        elif dim == "flow":
            opts = ["RAW", raw_u, "m3/min", "bbl/min"]
        elif dim == "force":
            opts = ["RAW", raw_u, "lbs", "klbf", "kN", "ton", "ton (US)"]
        elif dim == "temperature":
            opts = ["RAW", raw_u, "°C", "°F"]
        else:
            opts = ["RAW", raw_u]

        # unique, keep order
        seen = set()
        out = []
        for x in opts:
            x = "RAW" if str(x).upper() == "RAW" else norm_unit(x)
            if not x:
                continue
            if x not in seen:
                seen.add(x)
                out.append(x)
        return out

    def get_display_unit_for(slot_idx: int, tag: str, raw_unit: str, well: str, job: str) -> str:
        raw_u = norm_unit(raw_unit)
        if not raw_u:
            return ""
        k = make_pref_key(slot_idx, tag, raw_u, well, job)
        pref = unit_prefs.get(k, "RAW")
        pref = "RAW" if str(pref).upper() == "RAW" else norm_unit(pref)
        if pref == "RAW" or not pref:
            return raw_u
        # Ensure the pref is valid for this raw unit
        if pref not in get_unit_options(raw_u):
            return raw_u
        return pref

    # ==========================================
    # FLAGS
    # ==========================================
    force_refresh_event = threading.Event()
    force_reconnect_event = threading.Event()
    retry_count = 0
    data_loop_started = False

    # ==========================================
    # LOGIN OVERLAY
    # ==========================================
    pass_input = ft.TextField(
        label="Database Password",
        password=True,
        can_reveal_password=True,
        bgcolor=COLORS["card"],
        border_color=COLORS["stroke"],
        color="white",
        text_align="center",
        width=250,
    )
    login_error_txt = ft.Text("", size=12, text_align="center", color=COLORS["danger"])

    login_overlay = ft.Container(
        bgcolor=COLORS["bg"],
        alignment=ft.alignment.Alignment(0, 0),
        visible=True,
        expand=True,
        padding=20,
    )

    def iniciar_app_tras_login():
        nonlocal data_loop_started
        login_overlay.visible = False
        page.snack_bar = ft.SnackBar(ft.Text("Connection successful"), bgcolor=COLORS["ok"])
        page.snack_bar.open = True
        safe_page_update()
        if not data_loop_started:
            data_loop_started = True
            run_bg(data_loop)

    def intentar_conectar(e):
        login_error_txt.value = "Checking..."
        login_error_txt.color = COLORS["warn"]
        login_overlay.update()

        clave = pass_input.value.strip()
        DB_CONFIG["password"] = clave

        try:
            conn = pg8000.native.Connection(**DB_CONFIG)
            conn.close()
            iniciar_app_tras_login()
        except Exception as ex:
            DB_CONFIG["password"] = None
            login_error_txt.value = "Error: wrong password."
            login_error_txt.color = COLORS["danger"]
            print(f"Login Error: {ex}")
            login_overlay.update()

    def cerrar_login(e):
        login_overlay.visible = False
        safe_page_update()

    card_login = ft.Container(
        bgcolor=COLORS["card"],
        padding=28,
        border_radius=18,
        border=ft.border.all(1, COLORS["stroke"]),
        content=ft.Column(
            [
                ft.Text("SECURE ACCESS", size=18, weight="bold", color=COLORS["accent"]),
                ft.Container(height=10),
                ft.Text("Enter database password:", size=12, color=COLORS["muted"]),
                pass_input,
                ft.Container(height=10),
                login_error_txt,
                ft.Container(height=14),
                ft.Row(
                    [
                        ft.TextButton("CANCEL", on_click=cerrar_login),
                        ft.ElevatedButton(
                            "CONNECT",
                            on_click=intentar_conectar,
                            bgcolor=COLORS["accent"],
                            color="black",
                        ),
                    ],
                    alignment="center",
                ),
            ],
            horizontal_alignment="center",
            spacing=6,
            width=300,
        ),
    )
    login_overlay.content = card_login

    def abrir_login_manual(e):
        login_overlay.visible = True
        safe_page_update()

    # ==========================================
    # STATUS UI
    # ==========================================
    txt_well = ft.Text("---", size=14, weight="bold", color=COLORS["accent"], no_wrap=True)
    txt_job = ft.Text("---", size=12, color=COLORS["text"], no_wrap=True)
    txt_last_data = ft.Text(
        "---",
        size=10,
        color=COLORS["muted"],
        no_wrap=True,
        max_lines=1,
        overflow=ft.TextOverflow.ELLIPSIS,
    )

    status_txt = ft.Text("WAITING...", size=11, weight="bold", color=COLORS["muted"])
    status_dot = ft.Container(width=9, height=9, border_radius=12, bgcolor=COLORS["muted"])

    def set_status(mode: str):
        if mode == "CONNECTED":
            status_txt.value = "CONNECTED"
            status_txt.color = COLORS["ok"]
            status_dot.bgcolor = COLORS["ok"]
        elif mode == "STALE":
            status_txt.value = "STALE"
            status_txt.color = COLORS["warn"]
            status_dot.bgcolor = COLORS["warn"]
        elif mode == "OFFLINE":
            status_txt.value = "OFFLINE"
            status_txt.color = COLORS["danger"]
            status_dot.bgcolor = COLORS["danger"]
        elif mode == "RETRYING":
            status_txt.value = "RETRYING..."
            status_txt.color = COLORS["danger"]
            status_dot.bgcolor = COLORS["danger"]
        else:
            status_txt.value = "WAITING..."
            status_txt.color = COLORS["muted"]
            status_dot.bgcolor = COLORS["muted"]

    # ==========================================
    # PRO CHIP BUTTONS
    # ==========================================
    def chip_button(text, fg, bg, on_click):
        return ft.Container(
            padding=ft.padding.symmetric(horizontal=10, vertical=8),
            border_radius=14,
            bgcolor=bg,
            border=ft.border.all(1, COLORS["stroke"]),
            content=ft.Text(text, size=10, weight="bold", color=fg),
            on_click=on_click,
        )

    def on_refresh(e):
        force_refresh_event.set()
        page.snack_bar = ft.SnackBar(ft.Text("Refreshing data..."), bgcolor=COLORS["card"])
        page.snack_bar.open = True
        safe_page_update()

    def on_reconnect(e):
        force_reconnect_event.set()
        force_refresh_event.set()
        page.snack_bar = ft.SnackBar(ft.Text("Reconnecting..."), bgcolor=COLORS["card"])
        page.snack_bar.open = True
        safe_page_update()

    btn_refresh = chip_button("⟳ REF", COLORS["accent"], COLORS["chip_bg"], on_refresh)
    btn_reconnect = chip_button("⟲ REC", COLORS["warn"], COLORS["chip_bg"], on_reconnect)

    btn_key = ft.Container(
        padding=ft.padding.symmetric(horizontal=12, vertical=8),
        border_radius=14,
        bgcolor=COLORS["accent"],
        content=ft.Text("LOGIN", size=11, weight="bold", color=COLORS["bg"]),
        on_click=abrir_login_manual,
    )

    # ==========================================
    # TREND MODAL (FLET-CHARTS)
    # ==========================================
    current_trend = {"tag": "", "raw_unit": "", "label": "", "range": "2h", "slot": -1, "pref_key": ""}
    trend_req_id = 0

    trend_title = ft.Text("TREND", size=14, weight="bold", color=COLORS["accent"])
    trend_subtitle = ft.Text("", size=11, color=COLORS["muted"], no_wrap=True, max_lines=2, overflow=ft.TextOverflow.ELLIPSIS)
    trend_status = ft.Text("", size=11, color=COLORS["muted"])

    # Units selector (per-variable)
    units_dd = ft.Dropdown(
        width=170,
        dense=True,
        border_color=COLORS["stroke"],
        bgcolor=COLORS["panel"],
        color=COLORS["text"],
        content_padding=8,
        options=[],
        value=None,
    )

    # Dropdown option helper compatible with older Flet versions
    def dd_option(key: str, text=None):
        try:
            if text is None:
                return ft.dropdown.Option(key)
            return ft.dropdown.Option(key, text=text)
        except TypeError:
            # Older Flet: Option may not accept text in constructor
            opt = ft.dropdown.Option(key)
            try:
                if text is not None:
                    opt.text = text
            except Exception:
                pass
            return opt

    def option_key(opt):
        """Get option key across Flet versions."""
        return getattr(opt, "key", getattr(opt, "value", None))



    def _legend_item(color: str, text: str):
        return ft.Row(
            [
                ft.Container(width=10, height=10, border_radius=2, bgcolor=color),
                ft.Text(text, size=10, color=COLORS["muted"], weight="bold"),
            ],
            spacing=6,
        )

    legend_row = row_maybe_wrap(
        [
            _legend_item(COLORS["accent"], "Signal"),
            _legend_item(COLORS["warn"], "Avg (last 30m)"),
            _legend_item(COLORS["ok"], "Last"),
        ],
        spacing=14,
        wrap=True,
    )

    trend_chart_container = ft.Container(
        height=320,
        border_radius=18,
        bgcolor=COLORS["panel"],
        border=ft.border.all(1, COLORS["stroke"]),
        padding=12,
        content=ft.Column(
            [
                ft.ProgressRing(width=24, height=24),
                ft.Text("Loading trend...", size=12, color=COLORS["muted"]),
            ],
            alignment="center",
            horizontal_alignment="center",
        ),
    )

    def close_trend(e=None):
        nonlocal trend_req_id
        trend_overlay.visible = False
        trend_req_id += 1  # invalidate any running worker
        safe_page_update()

    btn_close_trend = chip_button("CLOSE ✕", COLORS["text"], COLORS["chip_bg"], close_trend)

    def set_range(rng):
        current_trend["range"] = rng
        load_trend()

    btn_r_30m = chip_button("30m", COLORS["text"], COLORS["chip_bg"], lambda e: set_range("30m"))
    btn_r_2h = chip_button("2h", COLORS["accent"], COLORS["chip_bg"], lambda e: set_range("2h"))
    btn_r_6h = chip_button("6h", COLORS["text"], COLORS["chip_bg"], lambda e: set_range("6h"))

    range_row = ft.Row([btn_r_30m, btn_r_2h, btn_r_6h], spacing=8)

    # Units row
    units_row = row_maybe_wrap(
        [
            ft.Text("Units:", size=11, color=COLORS["muted"], weight="bold"),
            units_dd,
            ft.Text("(per variable)", size=10, color=COLORS["muted"]),
        ],
        spacing=8,
        wrap=True,
    )

    trend_card = ft.Container(
        bgcolor=COLORS["card"],
        border_radius=22,
        border=ft.border.all(1, COLORS["stroke"]),
        padding=14,
        width=360,
        content=ft.Column(
            [
                ft.Row([trend_title, btn_close_trend], alignment="spaceBetween"),
                ft.Container(height=4),
                trend_subtitle,
                ft.Container(height=8),
                units_row,
                ft.Container(height=8),
                range_row,
                ft.Container(height=10),
                legend_row,
                ft.Container(height=10),
                trend_chart_container,
                ft.Container(height=10),
                trend_status,
            ],
            spacing=0,
        ),
    )

    trend_overlay = ft.Container(
        visible=False,
        expand=True,
        bgcolor=COLORS["overlay"],
        alignment=ft.alignment.Alignment(0, -0.10),
        padding=14,
        content=trend_card,
    )

    def _update_range_buttons(rng):
        btn_r_30m.content.color = COLORS["text"]
        btn_r_2h.content.color = COLORS["text"]
        btn_r_6h.content.color = COLORS["text"]
        if rng == "30m":
            btn_r_30m.content.color = COLORS["accent"]
        elif rng == "2h":
            btn_r_2h.content.color = COLORS["accent"]
        elif rng == "6h":
            btn_r_6h.content.color = COLORS["accent"]

    def _make_axis_labels_from_indices(indices, labels_text, color, size=11):
        labels = []
        for idx, txt in zip(indices, labels_text):
            labels.append(
                fch.ChartAxisLabel(
                    value=float(idx),
                    label=ft.Container(
                        margin=ft.Margin.only(top=8),
                        content=ft.Text(txt, size=size, color=color, weight="bold"),
                    ),
                )
            )
        return labels

    def _configure_units_dropdown(raw_unit: str, pref_value: str):
        opts = get_unit_options(raw_unit)
        if not opts:
            units_dd.options = []
            units_dd.value = None
            units_dd.disabled = True
            return

        raw_u = norm_unit(raw_unit)
        dd_options = []
        for u in opts:
            if u == 'RAW':
                dd_options.append(dd_option('RAW', f'RAW ({raw_u})'))
            else:
                dd_options.append(dd_option(u, u))

        units_dd.options = dd_options
        units_dd.disabled = False

        # Enforce value
        pref = 'RAW' if str(pref_value).upper() == 'RAW' else norm_unit(pref_value)
        keys = [option_key(o) for o in dd_options]
        if pref not in keys:
            pref = 'RAW'
        units_dd.value = pref

    def _current_context():
        return (ctx_state.get("well", "") or ""), (ctx_state.get("job", "") or "")

    def current_pref_key():
        """Compute preference key using *current* well/job context."""
        slot = int(current_trend.get('slot', -1))
        tag = current_trend.get('tag', '')
        raw_unit = current_trend.get('raw_unit', '')
        if slot < 0 or not tag or not raw_unit:
            return ''
        well, job = _current_context()
        return make_pref_key(slot, tag, raw_unit, well, job)

    def _refresh_tile(slot_idx: int):
        """Re-render a single grid tile using its stored raw value/unit and preferences."""
        if slot_idx < 0 or slot_idx >= len(grid_items):
            return
        info = grid_items[slot_idx]
        tag = info.get("current_tag", "")
        raw_unit = info.get("raw_unit", "")
        raw_val = info.get("raw_value", None)
        raw_val_is_num = isinstance(raw_val, (int, float))
        well, job = _current_context()

        ui_value = info["value_ctrl"]

        if raw_val is None:
            ui_value.value = "---"
            return

        # If not numeric, just print
        if not raw_val_is_num:
            ui_value.value = f"{raw_val}\n{raw_unit}" if raw_unit else str(raw_val)
            return

        disp_unit = get_display_unit_for(slot_idx, tag, raw_unit, well, job)
        try:
            disp_val = convert_value(float(raw_val), raw_unit, disp_unit)
        except Exception:
            disp_val = raw_val

        ui_value.value = f"{fmt_num(disp_val)}\n{disp_unit}" if disp_unit else f"{fmt_num(disp_val)}"

    def _on_units_change(e):
        """User changed units for the current variable."""
        slot = current_trend.get("slot", -1)
        try:
            slot_i = int(slot)
        except Exception:
            slot_i = -1
        if slot_i < 0:
            return

        pref_key = current_pref_key()
        if not pref_key:
            return

        sel = units_dd.value or "RAW"
        unit_prefs[pref_key] = sel

        try:
            page.client_storage.set("unit_prefs", unit_prefs)
        except Exception:
            pass

        # Update tile immediately
        _refresh_tile(slot_i)

        # Reload trend
        load_trend()

    units_dd.on_change = _on_units_change


    def load_trend():
        """Load and render trend chart for current_trend."""
        nonlocal trend_req_id

        tag = current_trend.get("tag", "")
        label = current_trend.get("label", "")
        rng = current_trend.get("range", "2h")
        slot = current_trend.get("slot", -1)
        raw_unit = current_trend.get("raw_unit", "")
        pref_key = current_pref_key()
        current_trend["pref_key"] = current_pref_key()

        _update_range_buttons(rng)

        # Determine display unit
        well, job = _current_context()
        disp_unit = get_display_unit_for(slot, tag, raw_unit, well, job) if raw_unit else ""

        trend_title.value = f"TREND {rng.upper()}"
        trend_subtitle.value = f"{label}{f' ({disp_unit})' if disp_unit else ''}  •  Tag: {tag}"
        trend_status.value = ""

        trend_chart_container.content = ft.Column(
            [
                ft.ProgressRing(width=24, height=24),
                ft.Text("Loading trend...", size=12, color=COLORS["muted"]),
            ],
            alignment="center",
            horizontal_alignment="center",
        )

        # Configure units dropdown for this variable
        pref_val = unit_prefs.get(pref_key, "RAW") if pref_key else "RAW"
        _configure_units_dropdown(raw_unit, pref_val)

        safe_page_update()

        # SQL interval
        if rng == "30m":
            interval_sql = "30 minutes"
        elif rng == "6h":
            interval_sql = "6 hours"
        else:
            interval_sql = "2 hours"

        # Request id guard
        trend_req_id += 1
        my_req = trend_req_id

        def is_stale():
            return (my_req != trend_req_id) or (not trend_overlay.visible)

        def worker():
            try:
                conn_t = pg8000.native.Connection(**DB_CONFIG)

                tag_clean = str(tag).strip()
                tag_norm = norm_tag(tag_clean)
                tag_dot = (tag_clean + ".") if tag_clean and (not tag_clean.endswith(".")) else tag_clean

                q = (
                    "SELECT created_at, value "
                    "FROM public.atalaya_samples "
                    "WHERE (tag = :t1 OR tag = :t2 OR tag = :t3) "
                    f"AND created_at >= NOW() - INTERVAL '{interval_sql}' "
                    "ORDER BY created_at ASC"
                )

                rows = conn_t.run(q, t1=tag_clean, t2=tag_norm, t3=tag_dot)
                try:
                    conn_t.close()
                except Exception:
                    pass

                if is_stale():
                    return

                if not rows or len(rows) < 3:
                    trend_chart_container.content = ft.Column(
                        [
                            ft.Text("No data in selected range", size=13, color=COLORS["muted"], weight="bold"),
                            ft.Text("Check signal / ingestion / tag.", size=11, color=COLORS["muted"]),
                        ],
                        alignment="center",
                        horizontal_alignment="center",
                    )
                    safe_page_update()
                    return

                times_utc = []
                vals_raw = []
                for ts, v in rows:
                    dt = to_datetime_safe(ts)
                    if dt is None:
                        continue
                    try:
                        y = float(v)
                    except Exception:
                        continue
                    times_utc.append(to_utc_aware(dt))
                    vals_raw.append(y)

                if len(vals_raw) < 3:
                    trend_chart_container.content = ft.Column(
                        [ft.Text("Not enough data to plot", size=13, color=COLORS["muted"], weight="bold")],
                        alignment="center",
                        horizontal_alignment="center",
                    )
                    safe_page_update()
                    return

                # Downsample (mobile-friendly)
                MAX_POINTS = 350
                if len(vals_raw) > MAX_POINTS:
                    step_ds = max(1, math.ceil(len(vals_raw) / MAX_POINTS))
                    times_utc = times_utc[::step_ds]
                    vals_raw = vals_raw[::step_ds]

                times_local = [to_local_mx(t) for t in times_utc]

                # Apply unit conversion for the trend (raw -> preferred)
                vals = []
                if raw_unit and disp_unit and (norm_unit(raw_unit) != norm_unit(disp_unit)):
                    for v in vals_raw:
                        try:
                            vals.append(float(convert_value(float(v), raw_unit, disp_unit)))
                        except Exception:
                            vals.append(float(v))
                else:
                    vals = [float(v) for v in vals_raw]

                y_min = min(vals)
                y_max = max(vals)
                y_last = vals[-1]
                pad = (y_max - y_min) * 0.12 if y_max > y_min else 1.0

                # Avg of last 30 minutes (reference line)
                try:
                    dt_end = times_utc[-1]
                    dt_cut = dt_end - timedelta(minutes=30)
                    vals_30 = [vals[i] for i, t in enumerate(times_utc) if t >= dt_cut]
                    y_avg30 = (sum(vals_30) / len(vals_30)) if len(vals_30) >= 3 else (sum(vals) / len(vals))
                except Exception:
                    y_avg30 = sum(vals) / len(vals)

                y_avg_all = sum(vals) / len(vals)

                # X axis: 0..N-1
                n = len(vals)

                # Points with tooltip (value + time)
                points = []
                for i in range(n):
                    tm = times_local[i].strftime("%H:%M") if times_local[i] else "--:--"
                    yv = float(vals[i])
                    tip_txt = f"{fmt_num(yv)}{(' ' + disp_unit) if disp_unit else ''}\n{tm}"
                    points.append(
                        fch.LineChartDataPoint(
                            float(i),
                            float(yv),
                            tooltip=tip_txt,
                        )
                    )

                # Series: main + Avg30m + Last
                data = [
                    fch.LineChartData(
                        stroke_width=3,
                        color=COLORS["accent"],
                        curved=True,
                        rounded_stroke_cap=True,
                        points=points,
                    ),
                    fch.LineChartData(
                        stroke_width=1.6,
                        color=COLORS["warn"],
                        curved=False,
                        rounded_stroke_cap=True,
                        points=[
                            fch.LineChartDataPoint(0.0, float(y_avg30)),
                            fch.LineChartDataPoint(float(n - 1), float(y_avg30)),
                        ],
                    ),
                    fch.LineChartData(
                        stroke_width=1.6,
                        color=COLORS["ok"],
                        curved=False,
                        rounded_stroke_cap=True,
                        points=[
                            fch.LineChartDataPoint(0.0, float(y_last)),
                            fch.LineChartDataPoint(float(n - 1), float(y_last)),
                        ],
                    ),
                ]

                # Bottom ticks
                tick_count = 5
                if n < tick_count:
                    tick_idx = list(range(n))
                else:
                    tick_idx = [0, n // 4, n // 2, (3 * n) // 4, n - 1]
                tick_idx = sorted(list(dict.fromkeys(tick_idx)))

                tick_lbl = [times_local[i].strftime("%H:%M") if times_local[i] else "--:--" for i in tick_idx]

                bottom_axis = fch.ChartAxis(
                    label_size=32,
                    labels=_make_axis_labels_from_indices(tick_idx, tick_lbl, COLORS["muted"], size=10),
                )

                # ------------------------------
                # Y-axis scale (nice)
                # ------------------------------
                def _nice_step(raw_step: float) -> float:
                    """Return a human-friendly step: 1, 2, 5, 10 * 10^n."""
                    if raw_step <= 0:
                        return 1.0
                    mag = 10 ** math.floor(math.log10(raw_step))
                    norm = raw_step / mag
                    if norm <= 1:
                        mult = 1
                    elif norm <= 2:
                        mult = 2
                    elif norm <= 5:
                        mult = 5
                    else:
                        mult = 10
                    return mult * mag

                # Use the *visible* range (including padding) to avoid extremely small
                # grid intervals when the signal is flat.
                y_view_min = y_min - pad
                y_view_max = y_max + pad

                span_y = max(1e-9, y_view_max - y_view_min)
                target_ticks = 5
                step_y = _nice_step(span_y / (target_ticks - 1))
                y_start = math.floor(y_view_min / step_y) * step_y
                y_end = math.ceil(y_view_max / step_y) * step_y

                y_ticks = []
                v = y_start
                while v <= y_end + step_y * 0.001:
                    y_ticks.append(round(float(v), 6))
                    v += step_y

                # Reduce tick count on mobile
                MAX_Y_LABELS = 4
                if len(y_ticks) > MAX_Y_LABELS:
                    idxs = [round(i * (len(y_ticks) - 1) / (MAX_Y_LABELS - 1)) for i in range(MAX_Y_LABELS)]
                    idxs = sorted(set(int(i) for i in idxs))
                    y_ticks = [y_ticks[i] for i in idxs]

                def _fmt_y(val: float) -> str:
                    if abs(val) >= 1000:
                        return f"{val:.0f}"
                    if abs(step_y) >= 1:
                        return f"{val:.0f}"
                    if abs(step_y) >= 0.1:
                        return f"{val:.1f}"
                    return f"{val:.2f}"

                left_axis = fch.ChartAxis(
                    show_labels=True,
                    title=ft.Text(disp_unit or "", size=10, color=COLORS["muted"]),
                    label_size=60,
                    labels=[
                        fch.ChartAxisLabel(
                            value=float(v),
                            label=ft.Text(_fmt_y(v), size=10, color=COLORS["muted"], weight="bold"),
                        )
                        for v in y_ticks
                    ],
                )

                chart = fch.LineChart(
                    data_series=data,
                    min_x=0,
                    max_x=max(1, n - 1),
                    min_y=y_view_min,
                    max_y=y_view_max,
                    expand=True,
                    bgcolor=COLORS["panel"],
                    border=ft.Border(
                        bottom=ft.BorderSide(2, COLORS["stroke"]),
                        left=ft.BorderSide(1, COLORS["stroke"]),
                        right=ft.BorderSide(1, COLORS["stroke"]),
                        top=ft.BorderSide(1, COLORS["stroke"]),
                    ),
                    bottom_axis=bottom_axis,
                    left_axis=left_axis,
                    horizontal_grid_lines=fch.ChartGridLines(
                        interval=step_y,
                        color=ft.Colors.with_opacity(0.18, COLORS["stroke"]),
                        width=1,
                    ),
                    tooltip=fch.LineChartTooltip(
                        bgcolor=ft.Colors.with_opacity(0.92, COLORS["card"]),
                        border_radius=8,
                        padding=6,
                    ),
                    right_axis=fch.ChartAxis(show_labels=False),
                    top_axis=fch.ChartAxis(show_labels=False),
                    interactive=True,
                )

                if is_stale():
                    return

                trend_chart_container.content = chart

                ini = times_local[0].strftime("%H:%M") if times_local[0] else "--:--"
                fin = times_local[-1].strftime("%H:%M") if times_local[-1] else "--:--"
                u = f" {disp_unit}" if disp_unit else ""

                trend_status.value = (
                    f"Range: {ini} → {fin}  •  N={n}  |  "
                    f"Min={fmt_num(y_min)}{u}  Avg30m={fmt_num(y_avg30)}{u}  Avg={fmt_num(y_avg_all)}{u}  "
                    f"Max={fmt_num(y_max)}{u}  Last={fmt_num(y_last)}{u}"
                )

                safe_page_update()

            except Exception as ex:
                if is_stale():
                    return
                trend_chart_container.content = ft.Column(
                    [
                        ft.Text("Error loading trend", size=13, color=COLORS["danger"], weight="bold"),
                        ft.Text(str(ex)[:180], size=10, color=COLORS["muted"]),
                    ],
                    alignment="center",
                    horizontal_alignment="center",
                )
                safe_page_update()

        run_bg(worker)

    # ==========================================
    # GRID VARIABLES (tap = trend)
    # ==========================================
    grid_items = []
    grid = ft.GridView(
        runs_count=3,
        max_extent=120,
        child_aspect_ratio=1.05,
        spacing=12,
        run_spacing=12,
        expand=False,
    )

    def open_trend(idx: int):
        info = grid_items[idx]
        tag = info.get("current_tag", "")
        raw_unit = info.get("raw_unit", "")
        label = info.get("current_label", f"VAR {idx+1}")

        if DB_CONFIG["password"] in (None, ""):
            page.snack_bar = ft.SnackBar(ft.Text("Please LOGIN first."), bgcolor=COLORS["danger"])
            page.snack_bar.open = True
            safe_page_update()
            return

        if not tag:
            page.snack_bar = ft.SnackBar(ft.Text("This variable is not configured."), bgcolor=COLORS["warn"])
            page.snack_bar.open = True
            safe_page_update()
            return
        # Preference key is computed dynamically using current well/job context

        current_trend["tag"] = tag
        current_trend["raw_unit"] = raw_unit
        current_trend["label"] = label
        current_trend["range"] = "2h"
        current_trend["slot"] = idx
        current_trend["pref_key"] = current_pref_key()

        trend_overlay.visible = True
        load_trend()
        safe_page_update()

    def crear_tarjeta_dinamica(index):
        lbl = ft.Text(
            f"VAR {index + 1}",
            size=9,
            color=COLORS["muted"],
            weight="bold",
            no_wrap=True,
            text_align="center",
        )
        val = ft.Text("---", size=18, weight="bold", color="white", text_align="center")

        item = {
            "label_ctrl": lbl,
            "value_ctrl": val,
            "current_tag": "",
            "raw_unit": "",
            "current_label": "",
            "raw_value": None,
        }
        grid_items.append(item)

        tile = ft.Container(
            bgcolor=COLORS["card"],
            border_radius=16,
            padding=12,
            border=ft.border.all(1, COLORS["stroke"]),
            content=ft.Column([lbl, val], spacing=8, horizontal_alignment="center", alignment="center"),
        )
        tile.on_click = lambda e, idx=index: open_trend(idx)
        return tile

    for i in range(12):
        grid.controls.append(crear_tarjeta_dinamica(i))

    # ==========================================
    # ALERTS UI
    # ==========================================
    alerts_col = ft.Column(spacing=10, scroll="auto")
    alerts_box = ft.Container(
        height=300,
        padding=12,
        border_radius=18,
        bgcolor=COLORS["panel"],
        border=ft.border.all(1, COLORS["stroke"]),
        content=alerts_col,
    )

    # ==========================================
    # LOGO (asset first, URL fallback when supported)
    # ==========================================
    def make_logo_image():
        """Create a logo image with graceful fallback across Flet versions."""
        try:
            # Newer Flet: Image.error_content provides native fallback.
            return ft.Image(
                src=LOGO_ASSET,
                fit="contain",
                error_content=ft.Image(src=LOGO_URL, fit="contain"),
            )
        except TypeError:
            # Older Flet: no error_content. Keep asset (or set LOGO_ASSET to a URL).
            return ft.Image(src=LOGO_ASSET, fit="contain")

    # ==========================================
    # HEADER
    # ==========================================
    # NOTE: use Wrap if available; otherwise fallback to Row for older Flet
    buttons_wrap = make_buttons_group([btn_refresh, btn_reconnect, btn_key])
    header_card = ft.Container(
        padding=12,
        border_radius=18,
        bgcolor=COLORS["panel"],
        border=ft.border.all(1, COLORS["stroke"]),
        content=ft.Row(
            [
                ft.Container(
                    width=46,
                    height=46,
                    border_radius=14,
                    bgcolor="white",
                    padding=6,
                    # Use local asset by default; if missing, the image may be blank.
                    # Keep LOGO_URL in config if you want to switch back.
                    content=make_logo_image(),
                ),
                ft.Column(
                    [
                        ft.Row([ft.Text("Well:", size=11, color=COLORS["muted"]), txt_well], spacing=6),
                        ft.Row([ft.Text("Job:", size=11, color=COLORS["muted"]), txt_job], spacing=6),
                        ft.Row(
                            [
                                ft.Text("Last:", size=10, color=COLORS["muted"]),
                                ft.Container(expand=True, content=txt_last_data),
                            ],
                            spacing=6,
                        ),
                    ],
                    spacing=2,
                    expand=True,
                ),
                ft.Column(
                    [
                        ft.Container(
                            padding=ft.padding.symmetric(horizontal=10, vertical=6),
                            border_radius=999,
                            bgcolor=COLORS["chip_bg"],
                            border=ft.border.all(1, COLORS["stroke"]),
                            content=ft.Row([status_dot, status_txt], spacing=6),
                        ),
                        buttons_wrap,
                    ],
                    spacing=10,
                    horizontal_alignment="end",
                ),
            ],
            alignment="spaceBetween",
            vertical_alignment="center",
        ),
    )

    dashboard_ui = ft.Container(
        padding=14,
        content=ft.Column(
            [
                header_card,
                ft.Container(height=12),
                ft.Text("LIVE VARIABLES (tap for trend)", size=12, weight="bold", color=COLORS["accent"]),
                ft.Container(height=6),
                grid,
                ft.Container(height=16),
                ft.Text("ALERTS & COMMENTS", size=12, weight="bold", color=COLORS["accent"]),
                ft.Container(height=6),
                alerts_box,
            ],
            spacing=0,
            scroll="auto",
        ),
    )

    page.add(
        ft.Stack(
            [
                dashboard_ui,
                trend_overlay,
                login_overlay,
            ],
            expand=True,
        )
    )

    # ==========================================
    # DATA LOOP
    # ==========================================
    def data_loop():
        nonlocal retry_count
        conn = None

        while True:
            try:
                if force_reconnect_event.is_set():
                    force_reconnect_event.clear()
                    try:
                        if conn:
                            conn.close()
                    except Exception:
                        pass
                    conn = None

                if conn is None:
                    if DB_CONFIG["password"]:
                        conn = pg8000.native.Connection(**DB_CONFIG)
                    else:
                        set_status("WAITING")
                        safe_page_update()
                        force_refresh_event.wait(1)
                        force_refresh_event.clear()
                        continue

                rows_alerts = conn.run(
                    "SELECT description, severity, created_at "
                    "FROM public.atalaya_alerts "
                    "ORDER BY created_at DESC LIMIT 30"
                )

                samples_has_ts = True
                try:
                    rows_samples = conn.run(
                        "SELECT tag, value, created_at FROM public.atalaya_samples "
                        "ORDER BY id DESC LIMIT 300"
                    )
                except Exception:
                    rows_samples = conn.run(
                        "SELECT tag, value FROM public.atalaya_samples "
                        "ORDER BY id DESC LIMIT 300"
                    )
                    samples_has_ts = False

                rows_kp = conn.run("SELECT key, value FROM public.kp_state")

                retry_count = 0
                kp_dict = {norm_key(row[0]): row[1] for row in rows_kp}

                # Update well/job
                txt_well.value = kp_dict.get("CURRENT_WELL", "---")
                txt_job.value = kp_dict.get("CURRENT_JOB", "---")
                # Stable context for unit preferences (shared)
                ctx_state["well"] = kp_dict.get("CURRENT_WELL", "---")
                ctx_state["job"] = kp_dict.get("CURRENT_JOB", "---")

                # Determine data age / status
                last_dt = None
                if samples_has_ts and rows_samples:
                    last_dt = to_datetime_safe(rows_samples[0][2])
                elif rows_alerts:
                    last_dt = to_datetime_safe(rows_alerts[0][2])

                if last_dt:
                    local_last = to_local_mx(last_dt)
                    age_s = age_seconds_from_dt(last_dt)
                    age_s = int(age_s) if age_s is not None else None

                    if local_last:
                        ts_str = local_last.strftime("%Y-%m-%d %H:%M:%S")
                    else:
                        ts_str = "---"

                    if age_s is None:
                        txt_last_data.value = ts_str
                        set_status("STALE")
                    else:
                        txt_last_data.value = f"{ts_str}  •  {age_s}s"
                        set_status("STALE" if age_s > STALE_THRESHOLD_SECONDS else "CONNECTED")
                else:
                    txt_last_data.value = "---"
                    set_status("STALE")

                # Build samples dict
                samples_dict = {}
                if samples_has_ts:
                    for tag, val, _ts in rows_samples:
                        tag_raw = str(tag).strip()
                        tag_n = norm_tag(tag_raw)
                        if tag_raw not in samples_dict:
                            samples_dict[tag_raw] = val
                        if tag_n not in samples_dict:
                            samples_dict[tag_n] = val
                        # Also store dotless variants (robust tag matching)
                        tag_nd = tag_raw.replace(".", "")
                        if tag_nd and tag_nd not in samples_dict:
                            samples_dict[tag_nd] = val
                        tag_n_nd = tag_n.replace(".", "")
                        if tag_n_nd and tag_n_nd not in samples_dict:
                            samples_dict[tag_n_nd] = val
                else:
                    for tag, val in rows_samples:
                        tag_raw = str(tag).strip()
                        tag_n = norm_tag(tag_raw)
                        if tag_raw not in samples_dict:
                            samples_dict[tag_raw] = val
                        if tag_n not in samples_dict:
                            samples_dict[tag_n] = val
                        # Also store dotless variants (robust tag matching)
                        tag_nd = tag_raw.replace(".", "")
                        if tag_nd and tag_nd not in samples_dict:
                            samples_dict[tag_nd] = val
                        tag_n_nd = tag_n.replace(".", "")
                        if tag_n_nd and tag_n_nd not in samples_dict:
                            samples_dict[tag_n_nd] = val

                # VARIABLES
                well, job = _current_context()

                for i in range(12):
                    var_num = i + 1

                    possible_keys_tag = [
                        f"VAR_{var_num}",
                        f"VARIABLE_{var_num}",
                        f"VAR_{var_num}_TAG",
                        f"VARIABLE_{var_num}_TAG",
                    ]
                    possible_keys_unit = [f"VAR_{var_num}_UNIT", f"VARIABLE_{var_num}_UNIT"]

                    tag_config = ""
                    for k in possible_keys_tag:
                        v = kp_dict.get(norm_key(k), None)
                        if v not in (None, ""):
                            tag_config = str(v).strip()
                            break

                    unit_config = ""
                    for k in possible_keys_unit:
                        v = kp_dict.get(norm_key(k), None)
                        if v not in (None, ""):
                            unit_config = str(v).strip()
                            break

                    ui_label = grid_items[i]["label_ctrl"]
                    ui_value = grid_items[i]["value_ctrl"]

                    if tag_config:
                        tag_clean = tag_config.strip()
                        tag_normed = norm_tag(tag_clean)

                        display_name = tag_normed.replace(".", "").replace("_", " ")
                        ui_label.value = display_name

                        grid_items[i]["current_tag"] = tag_clean
                        grid_items[i]["raw_unit"] = norm_unit(unit_config)
                        grid_items[i]["current_label"] = display_name

                        val_raw = None
                        if tag_clean in samples_dict:
                            val_raw = samples_dict[tag_clean]
                        elif tag_normed in samples_dict:
                            val_raw = samples_dict[tag_normed]
                        else:
                            val_raw = samples_dict.get(tag_clean.replace(".", ""), None)

                        # Store raw value
                        raw_num = None
                        if val_raw is not None:
                            try:
                                raw_num = float(val_raw)
                            except Exception:
                                raw_num = None

                        grid_items[i]["raw_value"] = raw_num if raw_num is not None else val_raw

                        if val_raw is not None:
                            if raw_num is not None:
                                disp_unit = get_display_unit_for(i, tag_clean, unit_config, well, job)
                                disp_val = convert_value(raw_num, unit_config, disp_unit)
                                ui_value.value = f"{fmt_num(disp_val)}\n{disp_unit}" if disp_unit else f"{fmt_num(disp_val)}"
                            else:
                                # Non-numeric
                                u = norm_unit(unit_config)
                                ui_value.value = f"{val_raw}\n{u}" if u else str(val_raw)
                        else:
                            ui_value.value = "---"

                    else:
                        ui_label.value = f"VAR {var_num}"
                        ui_value.value = "---"
                        grid_items[i]["current_tag"] = ""
                        grid_items[i]["raw_unit"] = ""
                        grid_items[i]["current_label"] = ""
                        grid_items[i]["raw_value"] = None

                # ALERTS
                alerts_col.controls.clear()
                for r in rows_alerts:
                    desc = str(r[0])
                    sev = str(r[1])
                    raw_dt = to_datetime_safe(r[2])
                    ts_short = to_local_mx(raw_dt).strftime("%Y-%m-%d %H:%M:%S") if raw_dt else "--"

                    sev_color = COLORS["ok"]
                    sev_label = "OK"
                    if sev == "CRITICAL":
                        sev_color = COLORS["danger"]
                        sev_label = "CRIT"
                    elif sev == "ATTENTION":
                        sev_color = COLORS["warn"]
                        sev_label = "ATTN"

                    item = ft.Container(
                        padding=10,
                        border_radius=14,
                        bgcolor=COLORS["card"],
                        border=ft.border.all(1, COLORS["stroke"]),
                        content=ft.Row(
                            [
                                ft.Container(width=6, height=44, border_radius=8, bgcolor=sev_color),                                ft.Container(width=140, content=ft.Text(ts_short, size=10, color=COLORS["muted"], no_wrap=True, overflow=ft.TextOverflow.ELLIPSIS)),
                                ft.Text(desc, size=12, color=COLORS["text"], expand=True, weight="w500"),
                                ft.Container(
                                    padding=ft.padding.symmetric(horizontal=10, vertical=6),
                                    border_radius=12,
                                    bgcolor=COLORS["chip_bg"],
                                    border=ft.border.all(1, COLORS["stroke"]),
                                    content=ft.Text(sev_label, size=10, weight="bold", color=sev_color),
                                ),
                            ],
                            alignment="spaceBetween",
                            vertical_alignment="center",
                            spacing=10,
                        ),
                    )
                    alerts_col.controls.append(item)

                safe_page_update()

            except Exception as e:
                retry_count += 1
                print(f"Loop Error ({retry_count}/{OFFLINE_MAX_RETRIES}): {e}")

                if retry_count >= OFFLINE_MAX_RETRIES:
                    set_status("OFFLINE")
                else:
                    set_status("RETRYING")

                try:
                    if conn:
                        conn.close()
                except Exception:
                    pass
                conn = None
                safe_page_update()

            force_refresh_event.wait(4)
            force_refresh_event.clear()


if __name__ == "__main__":
    # Try to enable assets directory (for logo). If the runtime doesn't support it, fallback.
    try:
        ft.run(main, assets_dir=ASSETS_DIR)
    except TypeError:
        ft.run(main)
