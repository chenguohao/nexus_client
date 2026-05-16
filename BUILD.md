# Zeon 客户端打包与调试指南

> 最后更新：2026-05-15

---

## 环境配置文件说明

所有服务器地址在编译时通过 `config/` 下的 JSON 注入，**代码里不写死任何地址**。

| 文件 | 用途 | 连接地址 |
|---|---|---|
| `config/debug_emulator.json` | Android 模拟器调试 | 自动（10.0.2.2 / 127.0.0.1）|
| `config/debug.json` | 真实手机局域网调试 | 192.168.31.212 |
| `config/debug_release.json` | Debug 模式连正式服（查日志用）| zeon-im.com |
| `config/release.json` | 正式打包 | zeon-im.com |

> **局域网 IP 变了怎么办**：只改 `config/debug.json` 里的 IP，不需要动代码。

---

## 为什么需要配置文件（原理说明）

发现服务（`/.well-known/matrix/client`）需要一个**引导地址**才能工作：

```
App 启动 → 读取 ZEON_SERVER_URL（编译时注入）
  ↓
请求 {ZEON_SERVER_URL}/.well-known/matrix/client
  ↓
拿到 Dendrite 和 Zeon Server 的完整地址
  ↓
正常使用
```

没有引导地址，App 不知道第一步去哪里请求。

---

## 一、IntelliJ 运行配置（推荐）

重启 IntelliJ 后右上角下拉框会出现以下配置，直接点运行即可：

| 配置名 | 对应 config 文件 | 适用场景 |
|---|---|---|
| `Debug (Android)` | debug_emulator.json | 模拟器开发（最常用）|
| `Debug (真机局域网)` | debug.json | 真实手机连 Mac 本机服务 |
| `Debug (zeon-im.com)` | debug_release.json | Debug 模式测正式服，可看日志 |
| `Release (zeon-im.com)` | release.json | 正式打包，不可调试 |

---

## 二、命令行运行

```bash
# 模拟器调试
flutter run --dart-define-from-file=config/debug_emulator.json

# 真机局域网调试
flutter run --dart-define-from-file=config/debug.json

# Debug 模式连正式服
flutter run --dart-define-from-file=config/debug_release.json

# 查看已连接设备
flutter devices
```

---

## 三、打正式包

```bash
# Android APK
flutter build apk --release --dart-define-from-file=config/release.json
# 产物：build/app/outputs/flutter-apk/app-release.apk

# Android AAB（上架 Google Play）
flutter build appbundle --release --dart-define-from-file=config/release.json
# 产物：build/app/outputs/bundle/release/app-release.aab

# iOS（需要 Mac + Xcode）
flutter build ios --release --dart-define-from-file=config/release.json
# 打完后用 Xcode 归档上传 App Store Connect
```

---

## 四、安装 APK 到手机

```bash
# 安装到默认设备
adb install build/app/outputs/flutter-apk/app-release.apk

# 多设备时指定设备
adb devices                          # 查看设备 ID
adb -s <设备ID> install build/app/outputs/flutter-apk/app-release.apk
```

---

## 五、常见问题

**Q：换了新局域网，真机连不上服务器？**
改 `config/debug.json` 里的 IP，重新运行。

**Q：正式环境连接失败？**
检查 `config/release.json` 里的 `ZEON_SERVER_URL` 不能带端口号，必须是 `https://zeon-im.com`。

**Q：改了 config 文件但没生效？**
热重载（`r`）不会重新读编译时配置，需要完全重启：先 `q` 退出，再重新运行。

**Q：Debug (zeon-im.com) 和 Release (zeon-im.com) 有什么区别？**
- Debug：可以在 IntelliJ 里看日志、打断点，方便排查问题
- Release：性能更好，但完全没有调试信息

---

## 六、案例备忘：联系人预览页头像误报「已过期」（2026-05）

本节记录一次**端到端排查的真实路径**，方便后人不要被表象带偏（TLS / 证书 / 服务器）。

### 6.1 现象

- 流程：通讯录 → 添加联系人 → 输入 Zeon ID → 确认 → 进入「资料预览」页（`ZeonContactPreviewPage`）。
- UI：大图头像区域显示 **「已过期」**（文案来自 `lib/widgets/mxc_image.dart` 的占位），昵称 / UID 正常。
- 日志（打开 `debugPrint` 后）：  
  `Could not find the correct Provider<MatrixState> above this MxcImage Widget`

### 6.2 为什么「之前都没出现过」？

1. **这条 UI 路径是后来加的**：预览页 + 共用 `ZeonProfileHeader` → `MxcImage` 的组合，等于给 **特定路由 + Overlay 层级** 暴露了一个老问题。
2. **`MxcImage` 历来依赖 `Matrix.of(context)`** 取 `Client`，大部分聊天时间线、房间内头像仍在「常规」子树下，`Provider<MatrixState>` 一定能读到，所以历史页面不易触发。
3. **误判链路**：当 `_load` 抛错时，旧的 `_tryLoad` 重试逻辑有 bug（先置 `isLoadDone` 再递归），**任意异常**第二次都会被标成「已过期」，与「媒体真过期」无关。

### 6.3 排查过程中踩过的弯路（按时间顺序）

| 阶段 | 推测 | 实际情况 |
|------|------|----------|
| 1 | 线上 TLS / 证书坏了 | Mac `openssl` / `curl` 握手正常，Let's Encrypt 链完整。 |
| 2 | Android 模拟器 + VPN | `HandshakeException` 确是环境问题；关掉 VPN 后仍有个案失败，说明还有第二层原因。 |
| 3 | `http.get` 没用自定义 HttpClient | `package:http` 默认 Client 在 Android 上不走 `CustomHttpClient`，可能 TLS 失败；已改为走 SDK / `client.httpClient`。 |
| 4 | MSC3916 / Bearer | 媒体下载需要正确 endpoint + token；已改为 `Client.getContent` 等与 SDK 一致的路径。 |
| 5 | **根因** | `FlutterEasyLoading` 在 `MaterialApp.router` 的 `builder` 里包了**双层 `Overlay` 入口**；部分子树里 **`Matrix.of(context)` 找不到 `Provider<MatrixState>`**，与 TLS 无关。 |

### 6.4 技术根因（一句话）

**`Matrix` 通过 `Provider<MatrixState>` 注入全局客户端上下文；`MxcImage` 若在某些 Overlay / 路由子树里用 `Matrix.of(context)`，会拿不到 Provider，`_load` 抛错 → UI 误显示「已过期」。**

`FlutterEasyLoading` 的结构大致为：`Overlay` 下挂多个 `OverlayEntry`，其中一层承载 `Matrix(child: navigator)`，Loading 层单独占一条 Entry。具体哪条子树在何种导航序列下会断开 InheritedWidget 的传播，与 Flutter / 插件版本组合有关；**显式传入 `Client` 比依赖「就近查找 Provider」更稳。**

### 6.5 最终修复（代码层面摘要）

1. **`MxcImage`**：增加可选参数 **`matrixClient`**；若传入则 **禁止再调用 `Matrix.of(context)`**。
2. **`ZeonProfileHeader`**：增加 **`matrixClient`**，透传给 `MxcImage`。
3. **`add_contact_dialog.dart`**：在 **`Navigator.pop` 关闭 bottom sheet 之前**，用当前可靠的 context 执行  
   `matrixClient = Matrix.of(context).client`，  
   再 `push ZeonContactPreviewPage(matrixClient: matrixClient)`。
4. **其它 `ZeonProfileHeader` 调用方**（个人页、联系人详情、聊天侧栏）：同样传入 `matrixClient`，避免以后再踩 Overlay 边界。
5. **`_tryLoad`**：重写重试逻辑，避免「第一次异常 → 第二次必标过期」的误杀。

### 6.6 后人自查清单

1. 头像 / MXC 相关先看日志是否有 **`Provider<MatrixState>`** 或 **`[MxcImage]`**。
2. 任意 **`Matrix.of(context)`** 出现在 **Dialog / BottomSheet / 独立 Route / Overlay** 里都要警惕；优先 **由上层捕获 `Client` 再往下传**。
3. 安卓 TLS 玄学优先关宿主 VPN，再看 `CustomHttpClient` 与是否误用裸 `http.get`。
4. 服务器媒体与 Matrix 1.11 / MSC3916 对齐时，优先走 **`Client.getContent` / `getContentThumbnail`**，不要手写半套 HTTP。

### 6.7 涉及文件（便于 code review）

- `lib/widgets/mxc_image.dart` — `matrixClient`、SDK 下载、`debugPrint`、`_tryLoad`
- `lib/widgets/zeon/zeon_profile_header.dart` — 透传 `matrixClient`
- `lib/zeon/pages/contact_preview/zeon_contact_preview_page.dart` — 接收并使用 `matrixClient`
- `lib/pages/contacts_tab/widgets/add_contact/add_contact_dialog.dart` — **pop 前捕获 Client**
- `lib/widgets/twake_app.dart` — `FlutterEasyLoading` + `Matrix` 包裹顺序（理解 InheritedWidget 边界时可对照）
