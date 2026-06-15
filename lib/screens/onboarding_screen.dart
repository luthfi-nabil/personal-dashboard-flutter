import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';

/// Server settings - configures the base URLs for login-api,
/// transaction-api, and health-api. Reachable from the login screen (before
/// signing in) and from Settings (once signed in).
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _loginBaseCtl = TextEditingController(text: ref.read(configProvider).loginBase);
  late final _apiBaseCtl = TextEditingController(text: ref.read(configProvider).apiBase);
  late final _healthBaseCtl = TextEditingController(text: ref.read(configProvider).healthBase);

  bool _saved = false;

  @override
  void dispose() {
    _loginBaseCtl.dispose();
    _apiBaseCtl.dispose();
    _healthBaseCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final cfg = ref.read(configProvider);
    final loginBase = _loginBaseCtl.text.trim();
    final apiBase = _apiBaseCtl.text.trim();
    final healthBase = _healthBaseCtl.text.trim();
    await ref.read(configProvider.notifier).update(cfg.copyWith(
          loginBase: loginBase.isEmpty ? cfg.loginBase : loginBase,
          apiBase: apiBase.isEmpty ? cfg.apiBase : apiBase,
          healthBase: healthBase.isEmpty ? cfg.healthBase : healthBase,
        ));
    if (!mounted) return;
    setState(() => _saved = true);
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configure the base URLs for login-api, transaction-api, '
                  'and health-api. These are used for authentication and to '
                  'sync your data.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _loginBaseCtl,
                  decoration: const InputDecoration(labelText: 'Login API base URL'),
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiBaseCtl,
                  decoration: const InputDecoration(labelText: 'Transaction API base URL'),
                  textInputAction: TextInputAction.next,
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _healthBaseCtl,
                  decoration: const InputDecoration(labelText: 'Health API base URL'),
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.url,
                  onSubmitted: (_) => _submit(),
                ),
                const SizedBox(height: 24),
                if (_saved)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text('Saved.', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                  ),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
