# Komari App

Komari 面板的 iOS / Android 原生客户端，同一套设计与协议，两个平台各自实现。

```
ios/       SwiftUI 客户端（xcodegen + xcodebuild，产出未签名 IPA）
android/   Kotlin + Compose 客户端（Gradle，产出签名 APK）
```

## 功能

- 登录（面板地址 / 账号 / 密码 / 2FA）
- 顶部状态带：在线数、实时 ↓/↑、今日流量
- 节点卡片：状态、地区·虚拟化·核心数·在线时长、价格与到期、速率与流量、CPU/MEM/DISK/TRAFFIC 四色指标、三网延迟+丢包表
- 节点详情：2×3 指标、三网表、历史曲线（CPU/LOAD/MEM × 6H/24H/7D）、规格表
- iOS 额外：节点编辑、远程命令（2FA）、审计日志

## 构建

iOS（需 macOS，或直接用 GitHub Actions）：

```bash
cd ios
brew install xcodegen && xcodegen generate
xcodebuild -project KomariGo.xcodeproj -scheme KomariGo -configuration Release -sdk iphoneos CODE_SIGNING_ALLOWED=NO build
```

Android：

```bash
cd android
gradle :app:assembleRelease
```

签名读取 `ANDROID_KEYSTORE_PATH` / `ANDROID_KEYSTORE_PASSWORD` / `ANDROID_KEY_ALIAS` / `ANDROID_KEY_PASSWORD` 四个环境变量。

## CI / 发布

- `ios.yml` / `android.yml`：改到对应目录时才构建，产物在 Actions artifacts
- `release.yml`：打 tag 自动构建两端并创建 GitHub Release

```bash
git tag v1.0.1 && git push --tags
```

## 协议

Komari 面板私有 API：`POST /api/login`（返回 `session_token` cookie）、`GET /api/nodes`、`GET /api/records/load`、`GET /api/records/ping`、`WS /api/clients`（连上先发 `get`）。会话失效时返回 200 + `{"status":"error","message":"Unauthorized."}`，需自行重登。
