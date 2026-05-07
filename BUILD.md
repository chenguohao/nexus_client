# Zeon 客户端打包与调试指南

> 最后更新：2026-05-07

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
