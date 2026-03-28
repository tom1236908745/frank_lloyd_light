import time
import logging
import statistics
import requests
import paho.mqtt.client as mqtt
from datetime import datetime
from pathlib import Path

# ===== ログ設定 =====
LOG_FORMAT = "%(asctime)s [%(levelname)s] %(message)s"
LOG_DATE_FORMAT = "%Y-%m-%d %H:%M:%S"

def get_log_path():
    now = datetime.now()
    return Path("logs") / now.strftime("%Y-%m") / f"{now.strftime('%d')}.log"

def setup_logger():
    log_path = get_log_path()
    log_path.parent.mkdir(parents=True, exist_ok=True)

    logger = logging.getLogger("sensor")
    logger.setLevel(logging.INFO)
    logger.handlers.clear()

    logger.addHandler(logging.FileHandler(log_path, encoding="utf-8"))
    logger.addHandler(logging.StreamHandler())

    for handler in logger.handlers:
        handler.setFormatter(logging.Formatter(LOG_FORMAT, datefmt=LOG_DATE_FORMAT))

    return logger

logger = setup_logger()
current_log_date = datetime.now().date()

# ===== SwitchBot設定 =====
# TODO: SwitchBot設定追加
TOKEN = "xxxxx"

# デバイスリスト
# TODO: SwitchBot設定追加
DEVICES = [
    {"id": "xxxxx", "name": "xxxxx"},
    {"id": "xxxxx", "name": "xxxxx"},
]

headers = {
    "Authorization": TOKEN,
    "Content-Type": "application/json"
}

# ===== MQTT設定 =====
MQTT_BROKER = "localhost"
TOPIC = "sensor/light"

# ===== OpenWeatherMap設定 =====
# TODO: OpenWeatherMap設定追加
OWM_API_KEY = "xxxxx"

# ===== lux フィルタ設定 =====
LUX_MIN = 10    # これ未満は真っ暗とみなして除外
LUX_MAX = 800   # これ以上は明るすぎとみなして除外

# ===== brightness 下限設定 =====
BRIGHTNESS_MIN = 5  # センサーデータがあるときに送る最低輝度（0送信防止）

lux_buffer = []
start_time = time.time()
location = None  # 起動時に取得してキャッシュ


# IPアドレスから現在地（緯度・経度）を取得
def get_location():
    try:
        res = requests.get("http://ip-api.com/json/", timeout=5)
        data = res.json()
        if data.get("status") == "success":
            logger.info(f"現在地取得: {data['city']} ({data['lat']}, {data['lon']})")
            return data["lat"], data["lon"]
    except Exception as e:
        logger.warning(f"現在地取得失敗: {e}")
    return None


# 天候に応じた色温度オフセットを取得（晴れ=補正なし、悪天候=暖色寄り）
def get_weather_color_temp_offset(lat, lon):
    try:
        url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={OWM_API_KEY}"
        res = requests.get(url, timeout=5)
        data = res.json()

        main = data["weather"][0]["main"]
        clouds = data["clouds"]["all"]  # 雲量 0〜100%
        logger.info(f"天候（色温度用）: {main}, 雲量: {clouds}%")

        if main == "Thunderstorm":
            return -1500
        elif main in ("Rain", "Drizzle"):
            return -1200
        elif main == "Clouds":
            if clouds <= 30:
                return -200
            elif clouds <= 60:
                return -500
            elif clouds <= 90:
                return -800
            else:
                return -1000
        else:  # Clear
            return 0

    except Exception as e:
        logger.warning(f"天候取得失敗（色温度）: {e}")
        return 0


# 天候に応じたlux補正倍率を取得
def get_weather_multiplier(lat, lon):
    try:
        url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={OWM_API_KEY}"
        res = requests.get(url, timeout=5)
        data = res.json()

        main = data["weather"][0]["main"]
        clouds = data["clouds"]["all"]  # 雲量 0〜100%
        logger.info(f"天候（lux補正用）: {main}, 雲量: {clouds}%")

        if main == "Thunderstorm":
            return 0.1
        elif main in ("Rain", "Drizzle"):
            return 0.2
        elif main == "Clouds":
            if clouds <= 30:
                return 0.85
            elif clouds <= 60:
                return 0.6
            elif clouds <= 90:
                return 0.4
            else:
                return 0.25
        else:  # Clear など
            return 1.0

    except Exception as e:
        logger.warning(f"天候取得失敗（lux補正）: {e}")
        return 1.0


# lux → 照明brightness変換
def lux_to_brightness(lux, apply_min=True):

    MAX_LUX = 1000
    STEP = 20

    normalized = min(lux / MAX_LUX, 1)
    level = int(normalized * (STEP - 1))
    brightness = int(level * (100 / (STEP - 1)))

    if apply_min:
        brightness = max(brightness, BRIGHTNESS_MIN)

    return brightness


# 時刻に応じた色温度テーブル（Kelvin）
# 朝・夕方は暖色（2700K）、昼は昼白色（6500K）
COLOR_TEMP_BY_HOUR = {
     9: 2700,
    10: 3500,
    11: 4500,
    12: 5500,
    13: 6500,
    14: 6000,
    15: 5000,
    16: 3800,
    17: 2700,
}

def get_color_temp_by_time():
    now = datetime.now()
    h = now.hour
    m = now.minute

    if h not in COLOR_TEMP_BY_HOUR:
        return 4000  # デフォルト値

    temp_now = COLOR_TEMP_BY_HOUR[h]
    temp_next = COLOR_TEMP_BY_HOUR.get(h + 1, temp_now)

    # 分単位で線形補間
    color_temp = int(temp_now + (temp_next - temp_now) * (m / 60.0))
    return color_temp


# SwitchBot API送信（全デバイスに送る）
def send_switchbot(brightness, color_temp):

    for device in DEVICES:
        url = f"https://api.switch-bot.com/v1.1/devices/{device['id']}/commands"

        # 明るさ送信
        requests.post(url, json={
            "command": "setBrightness",
            "parameter": str(brightness),
            "commandType": "command"
        }, headers=headers)

        # 色温度送信
        response = requests.post(url, json={
            "command": "setColorTemperature",
            "parameter": str(color_temp),
            "commandType": "command"
        }, headers=headers)

        logger.info(f"    [{device['name']}] 送信完了 → response: {response.text}")


# 稼働時間帯チェック（9:00〜17:00）
def is_active_hour():
    hour = datetime.now().hour
    return 9 <= hour < 17


# センサー取得失敗時の太陽光lux推定（時刻テーブル＋線形補間）
# 各時刻の屋内到達光量の目安値（lux）
LUX_BY_HOUR = {
     9: 150,
    10: 320,
    11: 530,
    12: 700,
    13: 800,
    14: 730,
    15: 560,
    16: 340,
    17:  80,
}

def estimate_lux_by_time():
    now = datetime.now()
    h = now.hour
    m = now.minute

    if h not in LUX_BY_HOUR:
        return 0.0

    lux_now = LUX_BY_HOUR[h]
    lux_next = LUX_BY_HOUR.get(h + 1, lux_now)

    # 分単位で次の時刻との線形補間
    estimated = lux_now + (lux_next - lux_now) * (m / 60.0)
    return round(estimated, 2)


# MQTT受信
def on_message(client, userdata, msg):

    global lux_buffer

    if not is_active_hour():
        return

    lux = float(msg.payload.decode())

    if lux < LUX_MIN or lux > LUX_MAX:
        logger.warning(f"lux: {lux} → 範囲外のためスキップ ({LUX_MIN}〜{LUX_MAX})")
        return

    logger.info(f"lux受信: {lux} (バッファ件数: {len(lux_buffer) + 1})")
    lux_buffer.append(lux)


location = get_location()

client = mqtt.Client()
client.on_message = on_message

client.connect(MQTT_BROKER, 1883, 60)
client.subscribe(TOPIC)

client.loop_start()

logger.info("MQTT subscriber started")

while True:

    # 日付が変わったらloggerを切り替え
    today = datetime.now().date()
    if today != current_log_date:
        logger = setup_logger()
        current_log_date = today
        logger.info(f"日付変更 → 新しいログファイルに切り替え: {get_log_path()}")

    current_time = time.time()

    if current_time - start_time >= 3600:  # 1時間ごとに処理

        now_str = datetime.now().strftime("%H:%M")
        logger.info(f"{'='*50}")
        logger.info(f"  処理開始 [{now_str}]")
        logger.info(f"{'='*50}")

        if is_active_hour():

            # --- センサーデータ ---
            logger.info(f"  [センサー]")
            if len(lux_buffer) > 0:
                avg_lux = statistics.mean(lux_buffer)
                lux_min = min(lux_buffer)
                lux_max = max(lux_buffer)
                logger.info(f"    取得方法 : 実測値")
                logger.info(f"    サンプル数: {len(lux_buffer)} 件")
                logger.info(f"    lux      : 平均={avg_lux:.1f}  最小={lux_min:.1f}  最大={lux_max:.1f}")
            else:
                avg_lux = estimate_lux_by_time()
                if location:
                    multiplier = get_weather_multiplier(*location)
                    avg_lux = round(avg_lux * multiplier, 2)
                    logger.warning(f"    取得方法 : フォールバック（時刻推定 + 天候補正）")
                    logger.warning(f"    lux      : {avg_lux}  (補正倍率: {multiplier})")
                else:
                    logger.warning(f"    取得方法 : フォールバック（時刻推定のみ）")
                    logger.warning(f"    lux      : {avg_lux}")

            # --- 照明制御値 ---
            brightness = lux_to_brightness(avg_lux)
            color_temp = get_color_temp_by_time()
            logger.info(f"  [照明制御]")
            if location:
                offset = get_weather_color_temp_offset(*location)
                color_temp = max(2700, min(6500, color_temp + offset))
                logger.info(f"    brightness : {brightness}%")
                logger.info(f"    color_temp : {color_temp}K  (天候オフセット: {offset:+d}K)")
            else:
                logger.info(f"    brightness : {brightness}%")
                logger.info(f"    color_temp : {color_temp}K")

            # --- API送信 ---
            logger.info(f"  [SwitchBot API]")
            send_switchbot(brightness, color_temp)

        else:
            logger.info(f"  稼働時間外のためスキップ")

        logger.info(f"{'='*50}\n")
        lux_buffer = []
        start_time = time.time()