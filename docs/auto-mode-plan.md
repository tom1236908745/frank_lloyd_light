# オートモード実装計画

## 概要

現状の手動操作（マニュアルモード）に加え、センサーデータをもとに照明を自動制御するオートモードを追加する。
iOSアプリ上でモードを切り替えられるようにし、オートモード時はRaspberry Pi側の自動制御ロジックに委ねる構成とする。

---

## 現状のシステム構成

```
[iOSアプリ（手動）]
  └─ SwitchBot API → 照明

[センサーシステム（常時稼働・独立）]
  TSL2561センサー
    ↓（5分ごと）
  ESP32 → MQTT → Raspberry Pi
                    ├── luxフィルタ・バッファ蓄積
                    └── 1時間ごとに判定 → SwitchBot API → 照明
```

現在、iOSアプリとセンサーシステムは **独立して動いており連携していない**。
両方が同時にSwitchBot APIに命令を送ると競合が発生する。

---

## 目標とする構成

```
[iOSアプリ]
  ├─ マニュアルモード: 従来通り手動で操作 → SwitchBot API
  └─ オートモード:   モード切替のみ行う（操作UIを無効化）
                         ↓
                    Firebase: autoMode = true
                         ↓
  [Raspberry Pi] autoMode を監視し、true のときだけ SwitchBot API へ送信
```

**制御の調停はFirebaseのフラグで行う。**
Raspberry Pi がフラグを確認してから命令を送ることで、手動・自動の競合を防ぐ。

---

## 変更が必要なコンポーネント

### 1. Firebase Realtime Database

以下のフィールドを追加する。

| パス | 型 | 説明 |
|------|----|------|
| `/autoMode` | Boolean | true = オートモード、false = マニュアルモード |
| `/sensorData/lux` | Number | センサーの最新lux値（アプリ表示用、任意） |
| `/sensorData/brightness` | Number | センサー由来の最新輝度（アプリ表示用、任意） |
| `/sensorData/updatedAt` | String | 最終更新時刻（アプリ表示用、任意） |

`/sensorData` はオートモード画面でセンサー状況を表示するために使うが、必須ではない（Phase 2 対応可）。

---

### 2. iOSアプリ

#### 変更レイヤーと概要

| レイヤー | 変更内容 |
|----------|---------|
| Domain/Models | `LightMode` enum（manual / auto）を追加 |
| Domain/RepositoriesProtocol | `LightRepositoryProtocol` にモード取得・更新メソッドを追加 |
| Domain/UseCases | `LightControlUseCase` にモード操作のメソッドを追加 |
| Infrastructure/Firebase | `FirebaseDatabaseClient` に `/autoMode` の読み書きを追加 |
| Infrastructure/Repository | `LightRepository` に上記を実装 |
| Presentation/ViewModel | `LightViewModel` にモード状態・切替ロジックを追加 |
| Presentation/View | `ContentView` にモード切替UIを追加、オートモード時は操作コントロールを無効化 |

#### 新規追加ファイル（案）

```
Domain/Models/LightMode.swift          # enum LightMode { case manual, auto }
```

#### 既存ファイルの主な変更点

**`LightRepositoryProtocol.swift`**
```swift
func fetchMode() async throws -> LightMode
func updateMode(_ mode: LightMode) async throws
```

**`LightControlUseCase.swift`**
```swift
func executeFetchMode() async throws -> LightMode
func executeUpdateMode(_ mode: LightMode) async throws
```

**`FirebaseDatabaseClient.swift`**
```swift
static func fetchAutoMode() async -> Bool        // /autoMode を取得
static func updateAutoMode(_ value: Bool) async throws  // /autoMode を更新
```

**`LightViewModel.swift`**
```swift
@Published var lightMode: LightMode = .manual

func loadMode() async          // 起動時にFirebaseからモードを取得
func toggleMode() async        // マニュアル ⇄ オート を切り替え
```

**`ContentView.swift`**
- 画面上部にモード切替セグメント or トグルを追加
- `lightMode == .auto` のとき、明るさ・色スライダーと電源ボタンを `.disabled(true)` にする
- オートモード時はセンサー状況（任意）を表示

---

### 3. Raspberry Pi スクリプト（`sensor/mqtt_subsc.py`）

SwitchBot APIへ送信する前に `/autoMode` フラグをFirebaseから確認する処理を追加する。

```python
# 擬似コード
auto_mode = firebase_get("/autoMode")
if auto_mode:
    switchbot_set_brightness(brightness)
else:
    # マニュアルモード中は何もしない
    pass
```

また、センサーデータ（lux・brightness・updatedAt）をFirebaseへ書き込むことで、
アプリ側でセンサー状況を表示できるようにする（任意・Phase 2）。

---

## 実装フェーズ

### Phase 1: モード切替の基盤（最小構成）

- [ ] `LightMode` モデルを追加
- [ ] Firebase に `/autoMode` フィールドを追加
- [ ] `FirebaseDatabaseClient` に autoMode の読み書きを実装
- [ ] `LightRepository` → `LightControlUseCase` → `LightViewModel` まで繋ぐ
- [ ] `ContentView` にモード切替UIを追加、オートモード時に操作UIを無効化
- [ ] Raspberry Pi スクリプトが `/autoMode` を確認するように修正

### Phase 2: オートモード画面の充実（任意）

- [ ] センサーのlux・輝度・最終更新時刻をFirebaseに書き込む（Raspberry Pi側）
- [ ] アプリのオートモード画面でセンサー状況を表示する

---

## UI イメージ

```
┌─────────────────────────────┐
│  [ マニュアル | オート ]    ← セグメントコントロール
│                              │
│       💡（電球アイコン）     │
│                              │
│  ── マニュアル時 ──          │
│  明るさ  [====○==========]   │
│  色      [カラーグリッド]    │
│  [      ONにする      ]      │
│                              │
│  ── オート時 ──              │
│  センサーが自動制御中        │
│  （スライダー等は非表示/無効）│
│  lux: 320 / 輝度: 40%       │  ← Phase 2
└─────────────────────────────┘
```

---

## 考慮事項・注意点

- **競合の防止**: オートモード中にアプリが誤ってSwitchBot APIを呼ばないよう、ViewModel側でモードチェックを徹底する
- **初期値**: Firebase に `/autoMode` がない場合は `false`（マニュアル）として扱う
- **稼働時間外（17時以降）**: Raspberry Pi は9:00〜17:00のみ動作するため、オートモードでもその時間外はアプリで手動操作が必要か検討する
- **オフライン時**: Firebaseが取得できない場合はマニュアルモードにフォールバックする

---

## ファイル変更サマリ

| ファイル | 新規/変更 |
|---------|---------|
| `Domain/Models/LightMode.swift` | 新規 |
| `Domain/RepositoriesProtocol/LightRepositoryProtocol.swift` | 変更 |
| `Domain/UseCases/LightControlUseCase.swift` | 変更 |
| `Infrastructure/Firebase/FirebaseDatabaseClient.swift` | 変更 |
| `Infrastructure/Repository/LightRepository.swift` | 変更 |
| `Presentation/Features/LightFeature/ViewModels/LightViewModel.swift` | 変更 |
| `Presentation/Features/LightFeature/Views/ContentView.swift` | 変更 |
| `sensor/mqtt_subsc.py` | 変更 |
