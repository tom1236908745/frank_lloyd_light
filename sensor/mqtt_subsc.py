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

# ===== lux フィルタ設定 =====
LUX_MIN = 10    # これ未満は真っ暗とみなして除外
LUX_MAX = 800   # これ以上は明るすぎとみなして除外

# ===== brightness 下限設定 =====
BRIGHTNESS_MIN = 5  # センサーデータがあるときに送る最低輝度（0送信防止）

lux_buffer = []
start_time = time.time()


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
                print(f"センサーデータなし → 時刻から推定: {avg_lux} lux")

            brightness = lux_to_brightness(avg_lux)
            print("Brightness:", brightness)

            send_switchbot(brightness)  # 全デバイスに送信

        lux_buffer = []
        start_time = time.time()