#include <Wire.h>
#include <WiFi.h>
#include <Adafruit_Sensor.h>
#include <Adafruit_TSL2561_U.h>
#include <PubSubClient.h>

Adafruit_TSL2561_Unified tsl = Adafruit_TSL2561_Unified(TSL2561_ADDR_FLOAT, 12345);
// TODO: WiFiの情報を入力
const char *ssid = "xxxxx";
const char *password = "xxxxx";
// TODO: Raspberry PiのIPを入力
const char *mqtt_server = "xxxxx"; // Raspberry PiのIP

WiFiClient espClient;
PubSubClient client(espClient);

void setup()
{

    Serial.begin(115200);
    delay(3000); // ←3秒待つ

    Wire.begin(21, 22);

    Serial.println("Sensor test");

    if (!tsl.begin())
    {
        Serial.println("TSL2561 not detected");
        while (1)
            ;
    }
    Serial.println("TSL2561 detected");

    WiFi.begin(ssid, password);

    while (WiFi.status() != WL_CONNECTED)
    {
        delay(500);
        Serial.println("Connecting WiFi...");
    }

    Serial.println("WiFi connected");

    client.setServer(mqtt_server, 1883);
}

void reconnect()
{
    while (!client.connected())
    {
        Serial.println("Connecting MQTT...");
        if (client.connect("ESP32Client"))
        {
            Serial.println("MQTT connected");
        }
        else
        {
            Serial.print("failed, rc=");
            Serial.println(client.state());
            delay(2000);
        }
    }
}

void loop()
{

    if (!client.connected())
    {
        reconnect();
    }

    client.loop();

    sensors_event_t event;
    tsl.getEvent(&event);

    if (!isnan(event.light))
    {
        Serial.print("Lux: ");
        Serial.println(event.light);
        char msg[20];
        sprintf(msg, "%.2f", event.light);
        client.publish("sensor/light", msg);
    }

    delay(300000); // 5分ごとに送信
}