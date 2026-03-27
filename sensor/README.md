# sensor

照度センサーのデータを取得し、SwitchBot照明を自動調光するシステムです。

## ファイル構成

```
sensor/
├── esp32_to_mqtt_broker.ino   # ESP32（センサー側）
├── mqtt_subsc.py              # Raspberry Pi（制御側）
└── README.md
```

---

## esp32_to_mqtt_broker.ino

### 概要

ESP32に接続した照度センサー（TSL2561）でlux値を計測し、MQTTブローカー（Raspberry Pi）へ送信するArduinoスケッチです。

### 動作

- 起動時にWiFi接続 → MQTTブローカーへ接続
- 5分ごとにlux値を取得し、トピック `sensor/light` へパブリッシュ
- MQTT接続が切れた場合は自動で再接続

### 使用ライブラリ

| ライブラリ | 用途 |
|-----------|------|
| Wire | I2C通信 |
| WiFi | WiFi接続 |
| Adafruit_Sensor | センサー基底ライブラリ |
| Adafruit_TSL2561_U | TSL2561照度センサー制御 |
| PubSubClient | MQTT通信 |

### 設定（TODO）

```cpp
const char *ssid = "xxxxx";        // WiFi名
const char *password = "xxxxx";    // WiFiパスワード
const char *mqtt_server = "xxxxx"; // Raspberry PiのIPアドレス
```

### ピン配置

| ピン | 用途 |
|------|------|
| GPIO21 | I2C SDA |
| GPIO22 | I2C SCL |

---

## mqtt_subsc.py

### 概要

Raspberry Pi上で動作するMQTTサブスクライバーです。ESP32から受信した照度データを蓄積・平均化し、SwitchBot APIで照明の明るさを自動制御します。

### 動作

1. **起動時** — IPアドレスから現在地（緯度・経度）を自動取得
2. **常時** — MQTTトピック `sensor/light` を購読し、lux値をバッファに蓄積
3. **1時間ごと** — バッファの平均を計算し、SwitchBot APIへ送信

### 稼働時間

9:00〜17:00 のみ動作。それ以外の時間帯はデータを無視します。

### luxフィルタ

範囲外の値はバッファに追加しません。

| 設定 | 値 | 意味 |
|------|----|------|
| `LUX_MIN` | 10 | これ未満は真っ暗とみなして除外 |
| `LUX_MAX` | 800 | これ以上は明るすぎとみなして除外 |

### lux → brightness 変換

0〜1000 luxを0〜100%の20段階に変換します。最低輝度は `BRIGHTNESS_MIN = 5`（0送信防止）。

---

## フォールバック（センサーデータなし時）

センサー故障・通信断などで1時間のバッファが空だった場合、以下の手順で推定値を使用します。

### ① 時刻ベースの推定

時刻ごとの屋内到達光量テーブルを元に、分単位で線形補間します。

| 時刻 | 推定 lux |
|------|---------|
| 9:00 | 150 |
| 10:00 | 320 |
| 11:00 | 530 |
| 12:00 | 700 |
| 13:00 | 800（ピーク） |
| 14:00 | 730 |
| 15:00 | 560 |
| 16:00 | 340 |
| 17:00 | 80 |

例）10:30 → 320 と 530 の中間 = **425 lux**

### ② 天候補正

OpenWeatherMap APIで現在の天候・雲量を取得し、推定luxに補正倍率を掛けます。

| 天候 | 雲量 | 補正倍率 |
|------|------|---------|
| 晴れ | — | 1.0 |
| 薄曇り | 〜30% | 0.85 |
| 曇り | 〜60% | 0.60 |
| 厚曇り | 〜90% | 0.40 |
| ほぼ曇天 | 〜100% | 0.25 |
| 雨・霧雨 | — | 0.20 |
| 雷雨 | — | 0.10 |

例）10:30 に曇り（雲量50%）→ 425 × 0.6 = **255 lux**

### フォールバックの多重保護

| 状況 | 動作 |
|------|------|
| 位置取得失敗 | 天候補正なし・時刻推定のみで続行 |
| 天候API失敗 | 補正倍率 1.0（補正なし）で続行 |
| 両方失敗 | 時刻テーブルの推定値をそのまま使用 |

どの段階で失敗してもスクリプトは停止しません。

---

## 設定（TODO）

```python
TOKEN = "xxxxx"              # SwitchBot APIトークン
DEVICES = [
    {"id": "xxxxx", "name": "xxxxx"},  # SwitchBotデバイスID・名前
]
OWM_API_KEY = "xxxxx"        # OpenWeatherMap APIキー
```

## システム全体の流れ

```
TSL2561センサー
  ↓（5分ごと）
ESP32 → MQTT → Raspberry Pi
                  ├── luxフィルタ（10〜800）
                  ├── バッファ蓄積（最大12個/時間）
                  └── 1時間ごとに判定
                        ├── 正常時：平均lux → brightness
                        └── 異常時：時刻推定 × 天候補正 → brightness
                                          ↑
                                   OpenWeatherMap API
                              ↓
                        SwitchBot API → 照明の明るさ調整
```

## 依存パッケージ

```bash
pip install paho-mqtt requests
```
