import time
import statistics
import requests
import paho.mqtt.client as mqtt
from datetime import datetime

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
            print(f"現在地取得: {data['city']} ({data['lat']}, {data['lon']})")
            return data["lat"], data["lon"]
    except Exception as e:
        print(f"現在地取得失敗: {e}")
    return None


# 天候に応じたlux補正倍率を取得
def get_weather_multiplier(lat, lon):
    try:
        url = f"https://api.openweathermap.org/data/2.5/weather?lat={lat}&lon={lon}&appid={OWM_API_KEY}"
        res = requests.get(url, timeout=5)
        data = res.json()

        main = data["weather"][0]["main"]
        clouds = data["clouds"]["all"]  # 雲量 0〜100%
        print(f"天候: {main}, 雲量: {clouds}%")

        if main == "Thunderstorm":
            return 0.1
        elif main in ("Rain", "Drizzle"):
            return 0.2
        elif main == "Clouds":
            if clouds <= 30:
                return 0.85   # 薄曇り
            elif clouds <= 60:
                return 0.6    # 曇り
            elif clouds <= 90:
                return 0.4    # 厚曇り
            else:
                return 0.25   # ほぼ完全曇天
        else:  # Clear など
            return 1.0

    except Exception as e:
        print(f"天候取得失敗: {e}")
        return 1.0  # 取得失敗時は補正なし


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


# SwitchBot API送信（全デバイスに送る）
def send_switchbot(brightness):

    data = {
        "command": "setBrightness",
        "parameter": str(brightness),
        "commandType": "command"
    }

    for device in DEVICES:
        url = f"https://api.switch-bot.com/v1.1/devices/{device['id']}/commands"
        response = requests.post(url, json=data, headers=headers)
        print(f"[{device['name']}] SwitchBot response:", response.text)


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
        print(f"lux: {lux} → 範囲外のためスキップ ({LUX_MIN}〜{LUX_MAX})")
        return

    print("lux:", lux)
    lux_buffer.append(lux)


location = get_location()

client = mqtt.Client()
client.on_message = on_message

client.connect(MQTT_BROKER, 1883, 60)
client.subscribe(TOPIC)

client.loop_start()

print("MQTT subscriber started")

while True:

    current_time = time.time()

    if current_time - start_time >= 3600:  # 1時間ごとに処理

        if is_active_hour():

            if len(lux_buffer) > 0:
                avg_lux = statistics.mean(lux_buffer)
                print("Average lux:", avg_lux)
            else:
                avg_lux = estimate_lux_by_time()
                if location:
                    multiplier = get_weather_multiplier(*location)
                    avg_lux = round(avg_lux * multiplier, 2)
                    print(f"センサーデータなし → 時刻推定 + 天候補正: {avg_lux} lux")
                else:
                    print(f"センサーデータなし → 時刻から推定: {avg_lux} lux")

            brightness = lux_to_brightness(avg_lux)
            print("Brightness:", brightness)

            send_switchbot(brightness)  # 全デバイスに送信

        lux_buffer = []
        start_time = time.time()