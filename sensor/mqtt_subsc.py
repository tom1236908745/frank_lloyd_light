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

lux_buffer = []
start_time = time.time()


# lux → 照明brightness変換
def lux_to_brightness(lux):

    MAX_LUX = 1000
    STEP = 20

    normalized = min(lux / MAX_LUX, 1)
    level = int(normalized * (STEP - 1))
    brightness = int(level * (100 / (STEP - 1)))

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


# MQTT受信
def on_message(client, userdata, msg):

    global lux_buffer

    if not is_active_hour():
        return

    lux = float(msg.payload.decode())
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

        if is_active_hour() and len(lux_buffer) > 0:

            avg_lux = statistics.mean(lux_buffer)
            print("Average lux:", avg_lux)

            brightness = lux_to_brightness(avg_lux)
            print("Brightness:", brightness)

            send_switchbot(brightness)  # 全デバイスに送信

        lux_buffer = []
        start_time = time.time()