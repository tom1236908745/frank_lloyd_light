# Frank Lloyd Light

## 概要

SwiftとIoTの接続の理解を深めるために作成したiOSアプリ。
SwitchBot APIを通じてスマート電球を手動制御する。

---

## 機能

- **電源のオン・オフ**
- **明るさ調整**（スライダー）
- **色の調整**
  - 色相スライダー
  - 彩度スライダー
  - プリセットカラーグリッド（12色）

---

## アーキテクチャ

クリーンアーキテクチャを採用。

```
Presentation
  └── LightViewModel       # UI状態管理・UIイベント処理
  └── ContentView          # SwiftUI View

Domain
  └── LightControlUseCase  # ビジネスロジック
  └── LightRepositoryProtocol
  └── DeviceStatus         # デバイス状態モデル

Infrastructure
  └── LightRepository      # リポジトリ実装
  └── SwitchBotClient      # SwitchBot API クライアント
  └── FirebaseDatabaseClient  # Firebase Realtime Database クライアント

Shared
  └── DIContainer          # 依存性注入
```

---

## 技術スタック

| 項目 | 内容 |
|------|------|
| UI | SwiftUI |
| 状態管理 | ObservableObject / @Published |
| 照明制御 | SwitchBot API v1.1 |
| 認証 | HMAC-SHA256署名（CryptoKit） |
| DB | Firebase Realtime Database |

---

## セットアップ

`Config.xcconfig`（gitignore対象）を作成し、以下を記入する。

```
SWITCHBOT_TOKEN = <SwitchBot APIトークン>
SWITCHBOT_SECRET = <SwitchBot クライアントシークレット>
SWITCHBOT_DEVICE_ID = <制御対象のデバイスID>
```

---

## 関連ドキュメント

- [センサーシステム（Raspberry Pi）](./sensor/README.md)
- [オートモード実装計画](./docs/auto-mode-plan.md)
