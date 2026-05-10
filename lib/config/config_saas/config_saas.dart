// ─────────────────────────────────────────────────────────────────────────────
// 上游 Twake on Matrix 遗留的 SaaS 平台配置
// ─────────────────────────────────────────────────────────────────────────────
// Zeon **不使用** Twake 的 SaaS 注册路径（OIDC 跳转 / 工作区登录），
// 我们用挖矿注册（/submit-mining）+ 自有 Matrix 同盟服务器（zeon-im.com）。
//
// 这里的字段仅作为 `String.fromEnvironment(...)` 的 defaultValue：
// 当 `flutter run --dart-define-from-file=config/*.json` 没传对应 key 时
// 会回退到这里的值。
//
// 字段使用情况（当前代码库中 grep 验证）：
//   - homeserver               ✅ 真的被读取（auto_homeserver_picker / connect_page_mixin
//                                 / twake_welcome / on_auth_redirect），所以必须给一个
//                                 健全的可达 URL，不能写空字符串或 127.0.0.1
//   - twakeWorkplaceHomeserver ⚠️  仅在 platform == 'saas' 时被读取（_isSaasPlatform
//                                 分支）。Zeon platform == 'localDebug'，永不触发，
//                                 但保持合法 URL 让日志干净
//   - registrationUrl          ⚠️  同上，仅 SaaS 模式下用于 OIDC 跳转 URL 拼接
//   - platform                 ✅ 必须保持 'localDebug'。改成 'saas' 会启用 Twake
//                                 的 SaaS 自动连接逻辑，整套 Zeon 注册流就废了
//
// 不要把这些字段当成 Zeon 的"主配置"。Zeon 的实际配置在
// `Client/twake-on-matrix/config/{debug,debug_release,release,debug_emulator}.json`，
// 通过 `--dart-define-from-file` 注入，覆盖这里的默认值。
// ─────────────────────────────────────────────────────────────────────────────

class ConfigurationSaas {
  static const String registrationUrl = 'https://zeon-im.com/';

  static const String twakeWorkplaceHomeserver = 'https://zeon-im.com';

  static const String homeserver = 'https://zeon-im.com';

  static const String platform = 'localDebug';
}
