import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:fluffychat/zeon/pages/mining/zeon_mining_logic.dart'
    show ZeonMiningLogic, StepStatus;
import 'package:fluffychat/zeon/pages/mining/zeon_mining_phases.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:matrix/matrix.dart';

import '../../services/api_service.dart';
import '../../services/key_service.dart';
import '../../services/mining_service.dart';
import '../../../widgets/matrix.dart';

// ── Phase enum ────────────────────────────────────────────────────────────────

enum _Phase { idle, mining, success }

class MiningStep {
  final String label;
  StepStatus status;
  String? detail;
  MiningStep(this.label) : status = StepStatus.idle;
}

// ── Page ──────────────────────────────────────────────────────────────────────

class ZeonMiningPage extends StatefulWidget {
  const ZeonMiningPage({super.key});

  @override
  State<ZeonMiningPage> createState() => ZeonMiningPageState();
}

class ZeonMiningPageState extends State<ZeonMiningPage>
    with SingleTickerProviderStateMixin {
  // Phase
  _Phase _phase = _Phase.idle;

  // Orb charge state
  bool _isCharging = false;
  double _chargeP = 0.0;
  DateTime? _chargeStart;
  Timer? _chargeTimer;
  static const _chargeDuration = Duration(seconds: 3);

  // Mining state
  final List<MiningStep> steps = [
    MiningStep('Key Preparation'),
    MiningStep('Fetch Challenge'),
    MiningStep('Proof of Work'),
    MiningStep('ECDSA Sign'),
    MiningStep('Submit Registration'),
    MiningStep('Save Key Card'),
  ];
  int _hashAttempts = 0;
  final List<String> _hashRows = [];
  Timer? _hashScrollTimer;
  Timer? _hashScrambleTimer;
  bool _miningComplete = false;

  // Success state
  String _matrixId = '';
  String _walletAddress = '';
  String _registrationDate = '';
  bool _savingKeyCard = false;

  // Services
  final _keyService = KeyService();
  final _miningService = MiningService();
  final _apiService = ApiService();

  // Logic helper
  late ZeonMiningLogic _logic;

  @override
  void initState() {
    super.initState();
    _logic = ZeonMiningLogic(
      keyService: _keyService,
      miningService: _miningService,
      apiService: _apiService,
    );
  }

  @override
  void dispose() {
    _chargeTimer?.cancel();
    _hashScrollTimer?.cancel();
    _hashScrambleTimer?.cancel();
    super.dispose();
  }

  // ── Orb charge ──────────────────────────────────────────────────────────────

  void _onOrbDown() {
    if (_phase != _Phase.idle || _isCharging) return;
    setState(() {
      _isCharging = true;
      _chargeStart = DateTime.now();
      _chargeP = 0.0;
    });
    _chargeTimer = Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(_chargeStart!);
      final p = (elapsed.inMilliseconds / _chargeDuration.inMilliseconds).clamp(0.0, 1.0);
      setState(() => _chargeP = p);
      if (p >= 1.0) {
        t.cancel();
        _onChargeComplete();
      }
    });
  }

  void _onOrbUp() {
    if (!_isCharging || _chargeP >= 1.0) return;
    _chargeTimer?.cancel();
    // Animate back to 0
    final fromP = _chargeP;
    final start = DateTime.now();
    Timer.periodic(const Duration(milliseconds: 16), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final progress = (elapsed / 380).clamp(0.0, 1.0);
      final p = fromP * (1 - progress * (2 - progress));
      setState(() => _chargeP = p);
      if (progress >= 1.0) {
        t.cancel();
        setState(() => _isCharging = false);
      }
    });
  }

  void _onChargeComplete() {
    // DEBUG: skip mining, jump straight to success phase for key card debugging
    setState(() {
      _isCharging = false;
      _matrixId = '@debug_user:localhost';
      _walletAddress = '0xDEBUG1234567890abcdef1234567890abcdef';
      final now = DateTime.now();
      _registrationDate =
          '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
      _phase = _Phase.success;
    });
    // Ensure we have a key for saveKeyCard
    _keyService.getOrCreatePrivateKey().then((key) {
      _logic = ZeonMiningLogic(
        keyService: _keyService,
        miningService: _miningService,
        apiService: _apiService,
      );
    });
  }

  // ── Mining simulation (visual) ──────────────────────────────────────────────

  void _startMiningSimulation() {
    setState(() {
      _hashRows.clear();
      _hashAttempts = 0;
      for (final s in steps) {
        s.status = StepStatus.idle;
        s.detail = null;
      }
    });
    _hashScrollTimer = Timer.periodic(const Duration(milliseconds: 280), (_) {
      if (!mounted || _miningComplete) return;
      setState(() {
        _hashRows.insert(0, _randomHash());
        if (_hashRows.length > 22) _hashRows.removeLast();
      });
    });
    _hashScrambleTimer = Timer.periodic(const Duration(milliseconds: 80), (_) {
      if (!mounted) return;
      setState(() {
        if (!_miningComplete) _hashAttempts += 80 + Random().nextInt(520);
      });
    });
  }

  // ── Real mining ─────────────────────────────────────────────────────────────

  Future<void> _startRealMining() async {
    try {
      await _logic.runRegistration(
        onStepUpdate: (i, status, detail) {
          if (!mounted) return;
          setState(() {
            steps[i].status = status;
            steps[i].detail = detail;
          });
        },
        onMiningProgress: (attempts) {
          if (!mounted) return;
          setState(() => _hashAttempts = attempts);
        },
        onComplete: (matrixId, walletAddress, accessToken, deviceId) async {
          _stopMiningVisuals(matrixId, walletAddress);
          // Log into Matrix client
          await _loginMatrixClient(matrixId, accessToken, deviceId);
        },
        onError: (error) {
          if (!mounted) return;
          _showError(error);
        },
      );
    } catch (e) {
      _showError(e.toString());
    }
  }

  Future<void> _loginMatrixClient(
    String matrixUserId,
    String accessToken,
    String deviceId,
  ) async {
    try {
      final client = Matrix.of(context).client;

      // Discover homeserver via .well-known from the Zeon API server
      final wellKnownUri = Uri.parse('${_apiService.baseUrl}/.well-known/matrix/client');
      final wkResponse = await http.get(wellKnownUri).timeout(const Duration(seconds: 10));
      Uri homeserverUri;
      if (wkResponse.statusCode == 200) {
        final wkJson = jsonDecode(wkResponse.body) as Map<String, dynamic>;
        final hs = wkJson['m.homeserver']?['base_url'] as String?;
        homeserverUri = Uri.parse(hs ?? _apiService.baseUrl.replaceFirst(':8080', ':8008'));
      } else {
        homeserverUri = Uri.parse(_apiService.baseUrl.replaceFirst(':8080', ':8008'));
      }
      Logs().i('ZeonMiningPage: discovered homeserver=$homeserverUri');

      await client.checkHomeserver(homeserverUri);
      await client.init(
        newToken: accessToken,
        newUserID: matrixUserId,
        newHomeserver: homeserverUri,
        newDeviceID: deviceId.isNotEmpty ? deviceId : null,
        newDeviceName: 'Zeon Android',
      );
    } catch (e) {
      Logs().w('ZeonMiningPage: Matrix login error: $e');
    }
  }

  void _stopMiningVisuals(String matrixId, String walletAddress) {
    _hashScrollTimer?.cancel();
    _hashScrambleTimer?.cancel();
    setState(() {
      _miningComplete = true;
      _matrixId = matrixId;
      _walletAddress = walletAddress;
      final now = DateTime.now();
      _registrationDate =
          '${now.year}.${now.month.toString().padLeft(2, '0')}.${now.day.toString().padLeft(2, '0')}';
      // Freeze last hash with winning suffix
      if (_hashRows.isNotEmpty) {
        _hashRows[0] = '${_randomHash().substring(0, 60)}0000';
      }
    });
    // Transition to success after short delay
    Future.delayed(const Duration(milliseconds: 1200), () {
      if (mounted) setState(() => _phase = _Phase.success);
    });
  }

  void _showError(String error) {
    _hashScrollTimer?.cancel();
    _hashScrambleTimer?.cancel();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF1C1B1C),
        title: const Text('Registration Failed', style: TextStyle(color: Colors.white)),
        content: Text(error, style: const TextStyle(color: Color(0xFF919191))),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) setState(() => _phase = _Phase.idle);
            },
            child: const Text('OK', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // ── Key card save ───────────────────────────────────────────────────────────

  Future<void> _saveKeyCard() async {
    // Show password dialog first
    final password = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      builder: (dialogContext) => const _SecureKeyDialog(),
    );
    if (password == null || !mounted) return; // user cancelled

    setState(() => _savingKeyCard = true);
    try {
      await _logic.saveKeyCard(
        matrixUserId: _matrixId,
        walletAddress: _walletAddress,
        password: password,
      );
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1C1B1C),
            title: const Text('Success',
                style: TextStyle(color: Color(0xFF4FFFB0), fontSize: 16)),
            content: const Text('Key card saved to gallery!',
                style: TextStyle(color: Color(0xFFCCCCCC))),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } catch (e, stackTrace) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: const Color(0xFF1C1B1C),
            title: const Text('Save Key Card Error',
                style: TextStyle(color: Colors.redAccent, fontSize: 16)),
            content: SingleChildScrollView(
              child: SelectableText(
                'Error: $e\n\nStackTrace:\n$stackTrace',
                style: const TextStyle(
                    color: Color(0xFFCCCCCC), fontSize: 11, fontFamily: 'monospace'),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('OK', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingKeyCard = false);
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  String _randomHash() {
    const hex = '0123456789abcdef';
    final rand = Random();
    return List.generate(64, (_) => hex[rand.nextInt(16)]).join();
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        child: switch (_phase) {
          _Phase.idle => IdlePhaseView(
              key: const ValueKey('idle'),
              chargeP: _chargeP,
              isCharging: _isCharging,
              onOrbDown: _onOrbDown,
              onOrbUp: _onOrbUp,
              onBack: () => context.go('/home'),
            ),
          _Phase.mining => MiningPhaseView(
              key: const ValueKey('mining'),
              steps: steps,
              hashAttempts: _hashAttempts,
              hashRows: _hashRows,
              miningComplete: _miningComplete,
              onBack: () {
                _hashScrollTimer?.cancel();
                _hashScrambleTimer?.cancel();
                setState(() => _phase = _Phase.idle);
              },
            ),
          _Phase.success => SuccessPhaseView(
              key: const ValueKey('success'),
              matrixId: _matrixId,
              walletAddress: _walletAddress,
              registrationDate: _registrationDate,
              saving: _savingKeyCard,
              onSave: _saveKeyCard,
              onBack: () => context.go('/home'),
            ),
        },
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SECURE YOUR KEY dialog (design/key_security_dialog)
// ══════════════════════════════════════════════════════════════════════════════

class _SecureKeyDialog extends StatefulWidget {
  const _SecureKeyDialog();

  @override
  State<_SecureKeyDialog> createState() => _SecureKeyDialogState();
}

class _SecureKeyDialogState extends State<_SecureKeyDialog> {
  final _pwCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  String? _error;
  bool _obscurePw = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _pwCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final pw = _pwCtrl.text;
    final confirm = _confirmCtrl.text;
    if (pw.isEmpty) {
      setState(() => _error = 'Please enter a password');
      return;
    }
    if (pw.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (pw != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    Navigator.pop(context, pw);
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 320,
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0E0E0F),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: const Color(0x4D474747),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Title
              const Text(
                'SECURE YOUR KEY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3.5,
                ),
              ),
              const SizedBox(height: 24),
              // Password field
              _buildInput(
                controller: _pwCtrl,
                placeholder: 'PASSWORD',
                obscure: _obscurePw,
                onToggle: () => setState(() => _obscurePw = !_obscurePw),
              ),
              const SizedBox(height: 16),
              // Confirm password field
              _buildInput(
                controller: _confirmCtrl,
                placeholder: 'CONFIRM PASSWORD',
                obscure: _obscureConfirm,
                onToggle: () =>
                    setState(() => _obscureConfirm = !_obscureConfirm),
              ),
              // Error text
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: const TextStyle(
                    color: Color(0xFFFFB4AB),
                    fontSize: 11,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
              const SizedBox(height: 24),
              // Buttons
              Row(
                children: [
                  // Cancel
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: const Color(0x33474747),
                          ),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'CANCEL',
                          style: TextStyle(
                            color: Color(0xFFC6C6C6),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Confirm
                  Expanded(
                    child: GestureDetector(
                      onTap: _onConfirm,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          'CONFIRM',
                          style: TextStyle(
                            color: Color(0xFF131314),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required String placeholder,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1C1B1C),
        borderRadius: BorderRadius.circular(4),
        border: const Border(
          bottom: BorderSide(color: Color(0x80474747)),
        ),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        decoration: InputDecoration(
          hintText: placeholder,
          hintStyle: const TextStyle(
            color: Color(0xFFC6C6C6),
            fontSize: 10,
            letterSpacing: 1.5,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          border: InputBorder.none,
          suffixIcon: GestureDetector(
            onTap: onToggle,
            child: Icon(
              obscure ? Icons.visibility_off : Icons.visibility,
              color: const Color(0xFF919191),
              size: 18,
            ),
          ),
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
    );
  }
}
