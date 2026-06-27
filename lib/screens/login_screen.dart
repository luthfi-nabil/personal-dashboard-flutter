import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/remote_api.dart';
import '../core/config.dart';
import '../theme/app_theme.dart';
import '../providers/providers.dart';

/// Login / register screen for login-api. On success the issued JWT is
/// stored in [AppConfig] and sent as a Bearer token to transaction-api /
/// health-api's `/api/user/...` routes.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _usernameCtl = TextEditingController();
  final _passwordCtl = TextEditingController();
  final _emailCtl = TextEditingController();
  final _phoneCtl = TextEditingController();
  final _telegramCtl = TextEditingController();

  bool _registerMode = false;
  bool _loading = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _usernameCtl.dispose();
    _passwordCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _telegramCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtl.text.trim();
    final password = _passwordCtl.text;
    if (username.isEmpty || password.isEmpty) {
      setState(() => _error = 'Enter a username and password.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });

    final cfg = ref.read(configProvider);
    final api = RemoteApi(cfg);
    try {
      if (_registerMode) {
        await api.register(
          username: username,
          password: password,
          email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
          phoneNumber:
              _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
          telegramUsername: _telegramCtl.text.trim().isEmpty
              ? null
              : _telegramCtl.text.trim(),
        );
      }

      final auth = await api.login(username: username, password: password);
      await ConfigService.instance.savePassword(password);
      final expiresIn = (auth['expires_in'] as num?)?.toInt();
      final expiresAt = expiresIn == null || expiresIn <= 0
          ? ''
          : DateTime.now().add(Duration(seconds: expiresIn)).toIso8601String();

      await ref.read(configProvider.notifier).update(cfg.copyWith(
            authToken: auth['token'] as String? ?? '',
            tokenExpiresAt: expiresAt,
            username: auth['username'] as String? ?? username,
            userId: auth['user_id'] as String? ?? '',
            email: auth['email'] as String? ?? '',
            phoneNumber: auth['phone_number'] as String? ?? '',
            telegramUsername: auth['telegram_username'] as String? ?? '',
          ));

      if (mounted) context.go('/');
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleMode() {
    setState(() {
      _registerMode = !_registerMode;
      _error = null;
      _info = _registerMode ? null : _info;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = AppTheme.colorsOf(context);
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                        color: c.ink, borderRadius: BorderRadius.circular(16)),
                    child: Text('PD',
                        style: TextStyle(
                            color: c.bg,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _registerMode ? 'Create an account' : 'Welcome back',
                    style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                        color: c.ink,
                        letterSpacing: -0.02),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _registerMode
                        ? 'Register with login-api to sync your data.'
                        : 'Sign in with login-api to sync your data.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: c.muted, fontSize: 13),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _usernameCtl,
                    style: TextStyle(color: c.ink),
                    decoration: const InputDecoration(labelText: 'Username'),
                    textInputAction: TextInputAction.next,
                    autocorrect: false,
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordCtl,
                    style: TextStyle(color: c.ink),
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    textInputAction: _registerMode
                        ? TextInputAction.next
                        : TextInputAction.done,
                    onSubmitted: (_) => _registerMode ? null : _submit(),
                  ),
                  if (_registerMode) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailCtl,
                      style: TextStyle(color: c.ink),
                      decoration:
                          const InputDecoration(labelText: 'Email (optional)'),
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _phoneCtl,
                      style: TextStyle(color: c.ink),
                      decoration: const InputDecoration(
                          labelText: 'Phone number (optional)'),
                      keyboardType: TextInputType.phone,
                      textInputAction: TextInputAction.next,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _telegramCtl,
                      style: TextStyle(color: c.ink),
                      decoration: const InputDecoration(
                          labelText: 'Telegram username (optional)'),
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_error!,
                          style: TextStyle(color: c.neg),
                          textAlign: TextAlign.center),
                    ),
                  if (_info != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(_info!,
                          style: TextStyle(color: c.pos),
                          textAlign: TextAlign.center),
                    ),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    style: FilledButton.styleFrom(
                      backgroundColor: c.ink,
                      foregroundColor: c.bg,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(_loading
                        ? 'Please wait…'
                        : (_registerMode ? 'Register & sign in' : 'Sign in')),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _loading ? null : _toggleMode,
                    child: Text(
                      _registerMode
                          ? 'Already have an account? Sign in'
                          : "Don't have an account? Register",
                      style: TextStyle(color: c.accent),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => context.push('/server-settings'),
                    child: Text('Server settings',
                        style: TextStyle(color: c.muted)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
