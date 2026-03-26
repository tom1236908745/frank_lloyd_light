import time
import statistics
import requests
import paho.mqtt.client as mqtt

# ===== SwitchBot設定 =====
// TODO: SwitchBot設定追加
TOKEN = ""
DEVICE_ID = ""

url = f"https://api.switch-bot.com/v1.1/devices/{DEVICE_ID}/commands"

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

    # luxを0〜1に正規化
    normalized = min(lux / MAX_LUX, 1)

    # 20段階
    level = int(normalized * (STEP - 1))

    # brightness 0〜100
    brightness = int(level * (100 / (STEP - 1)))

    return brightness

# SwitchBot API送信
def send_switchbot(brightness):

    data = {
        "command": "setBrightness",
        "parameter": str(brightness),
        "commandType": "command"
    }

    response = requests.post(url, json=data, headers=headers)
    print("SwitchBot response:", response.text)


# MQTT受信
def on_message(client, userdata, msg):

    global lux_buffer

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

    # 1分経過
    if current_time - start_time >= 10:

        if len(lux_buffer) > 0:

            avg_lux = statistics.mean(lux_buffer)

            print("Average lux:", avg_lux)

            brightness = lux_to_brightness(avg_lux)

            print("Brightness:", brightness)

            send_switchbot(brightness)

        lux_buffer = []
        start_time = time.time()

    time.sleep(1)