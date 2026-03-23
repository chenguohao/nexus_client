import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:fluffychat/config/app_config.dart';
import 'package:fluffychat/config/app_constants.dart';
import 'package:fluffychat/generated/l10n/app_localizations.dart';
import 'package:fluffychat/pages/sign_up/signup_view.dart';
import 'package:fluffychat/utils/platform_infos.dart';
import 'package:fluffychat/widgets/matrix.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';
import '../../utils/localized_exception_extension.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  SignupPageController createState() => SignupPageController();
}

class SignupPageController extends State<SignupPage> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController password2Controller = TextEditingController();
  String? error;
  bool loading = false;
  bool showPassword = false;
  bool displaySecondPasswordField = false;

  static const int minPassLength = 8;

  void toggleShowPassword() => setState(() => showPassword = !showPassword);

  String? get domain => GoRouterState.of(context).pathParameters['domain'];

  final GlobalKey<FormState> formKey = GlobalKey<FormState>();

  void onPasswordType(String text) {
    if (text.length >= minPassLength && !displaySecondPasswordField) {
      setState(() {
        displaySecondPasswordField = true;
      });
    }
  }

  String? password1TextFieldValidator(String? value) {
    if (value!.isEmpty) {
      return L10n.of(context)!.chooseAStrongPassword;
    }
    if (value.length < minPassLength) {
      return L10n.of(
        context,
      )!.pleaseChooseAtLeastChars(minPassLength.toString());
    }
    return null;
  }

  String? password2TextFieldValidator(String? value) {
    if (value!.isEmpty) {
      return L10n.of(context)!.repeatPassword;
    }
    if (value != passwordController.text) {
      return L10n.of(context)!.passwordsDoNotMatch;
    }
    return null;
  }

  String? usernameTextFieldValidator(String? value) {
    if (value == null || value.trim().isEmpty) {
      return L10n.of(context)!.pleaseEnterYourUsername;
    }
    if (_toLocalpart(value).isEmpty) {
      return L10n.of(context)!.invalidUsername;
    }
    return null;
  }

  String _toLocalpart(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-z0-9._=\-/+]'), '');
  }

  /// 先调 nexus_server 的 /quick-register 创建 Matrix 账号，
  /// 成功后再用 Matrix SDK 标准密码登录建立会话。
  void signup([_]) async {
    setState(() => error = null);
    if (!formKey.currentState!.validate()) return;
    setState(() => loading = true);

    try {
      final localPart = _toLocalpart(usernameController.text.trim());
      final password = passwordController.text;

      // Step 1: 通过 nexus_server 注册（nexus 内部用 shared_secret 调 Dendrite）
      final resp = await http
          .post(
            Uri.parse('${AppConstants.nexusServerUrl}/quick-register'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'username': localPart, 'password': password}),
          )
          .timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        final body = jsonDecode(resp.body) as Map<String, dynamic>;
        throw Exception(body['error'] ?? 'Registration failed (${resp.statusCode})');
      }

      // Step 2: 用标准密码登录让 Matrix SDK 建立会话（获取 access_token、启动 sync）
      final client = await Matrix.of(context).getLoginClient();
      // 确保 homeserver 已配置：若尚未设置（如真机首次启动），显式用默认地址初始化。
      // 若不做此步，Matrix SDK 会从 user ID 域名（localhost）推导 homeserver，
      // 在真机上访问 https://localhost/ 必然失败。
      if (client.homeserver == null) {
        await client.checkHomeserver(Uri.parse(AppConfig.defaultHomeserver));
      }
      Matrix.of(context).loginType = LoginType.mLoginPassword;
      await client.login(
        LoginType.mLoginPassword,
        identifier: AuthenticationUserIdentifier(user: localPart),
        user: localPart,
        password: password,
        initialDeviceDisplayName: PlatformInfos.clientName,
      );
    } catch (e) {
      if (e is MatrixException) {
        error = e.toLocalizedString(context);
      } else {
        error = e.toString();
      }
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => SignupPageView(this);

  @override
  void dispose() {
    usernameController.dispose();
    passwordController.dispose();
    password2Controller.dispose();
    super.dispose();
  }
}
