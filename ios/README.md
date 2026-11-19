# Komari for iOS

用 SwiftUI 写的 Komari 客户端，协议来自 Android 版 `com.komari.app` 2.5.0 的反编译，
在 Komari Server 1.6.1 上端到端验证。

## 功能

- 首页四格数字卡（在线 / 下行 / 上行 / 今日流量）：**下行 / 上行 / 今日流量三格可点**，
  弹出各 VPS 占比明细（条形图 + 百分比），上行用紫色区分
- 节点卡片：在线状态、已在线时长、价格 / 计费周期 / 到期日、**处理器 / 内存 / 硬盘 / 流量**（全中文）、
  规格摘要 `2核 · 4GB · KVM`、实时上下行速率
- **线路评级**：综合三网（电信 / 联通 / 移动）平均延迟 + 丢包率算出 0–100 分，
  分六档显示在每张卡片上 —— 丝滑 / 优秀 / 良好 / 一般 / 拥塞 / 劣化
- 三网延迟：固定三栏胶囊，缺测显示 `—`；详情页另有完整延迟 / 丢包表与分段质量条
- 节点详情：CPU、内存、磁盘、负载、网络、运行时长、进程 / 连接数，6h / 24h / 7d 历史曲线（CPU / 负载 / 内存可切换）
- 实时刷新：WebSocket `/api/clients`，连上先发 `get`，每 4 秒一帧
- 管理（管理员账号自动出现入口）：
  - 编辑节点：名称、分组、隐藏、价格、货币、计费周期、到期日、流量上限
  - 远程命令：`/api/admin/task/exec`，支持 2FA（`X-2FA-Code`），轮询任务结果
  - 审计日志：`/api/admin/logs`

## 线路评级算法

与 Android 版 `LineRate.kt` **完全一致**，两端评级结果可横向对比。

```
平均延迟 → 基准分
  ≤20ms 98 · ≤30 95 · ≤45 90 · ≤65 83 · ≤90 78
  ≤120 70 · ≤160 60 · ≤220 50 · ≤300 40 · ≤450 28 · 其余 12

丢包惩罚 = 丢包率% × 3（上限 25）
最终分   = 基准分 − 丢包惩罚（0–100）

档位：≥92 丝滑 · ≥80 优秀 · ≥68 良好 · ≥54 一般 · ≥38 拥塞 · 其余 劣化
```

三网未全部配置时，卡片会标注「仅 N 网」，分数仅供参考。

## 协议要点（踩过的坑）

- 会话失效返回 **HTTP 200** + `{"status":"error","message":"Unauthorized."}`，不是 401
- `/api/me` 无 envelope，是扁平对象
- 实时 WS 必须带 `Cookie` 和 `Origin: {面板地址}`，且**先发字符串 `get`**
- 三网延迟：`GET /api/records/ping?uuid=&hours=` 返回 `tasks[{name,avg,min,max,loss}]`
- 管理接口都是 `{status,data,message}`；写操作用 `POST`

## 构建（无需 Mac）

GitHub Actions 的 macOS runner 自动编出**未签名 IPA**：

1. push 到 main，或手动跑 `build-ipa` workflow
2. 下载 artifact `KomariGo-unsigned-ipa`

本地构建（需要 macOS + Xcode）：

```bash
brew install xcodegen
xcodegen generate
open KomariGo.xcodeproj
```

## 安装

未签名 IPA 需要签名：Sideloadly / AltStore / SideStore（免费 Apple ID 7 天），
或自签证书 / TrollStore（限特定系统版本）。要求 iOS 16+。

## 注意

- `Info.plist` 开了 `NSAllowsArbitraryLoads`，兼容 http 面板；只用 https 可以删掉
- 会话 token 存 UserDefaults，密码不落地
- 三网延迟依赖面板里已配置 Ping 任务；没有任务时卡片自动隐藏该区域
