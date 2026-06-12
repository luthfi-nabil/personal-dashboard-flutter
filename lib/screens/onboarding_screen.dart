import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/providers.dart';

/// First-run setup. transaction-api / health-api don't require auth on the
/// `/api/user/{created_by}/...` routes - `created_by` is just a path
/// segment, so we only need a username plus the server base URLs.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  late final _usernameCtl = TextEditingController(text: ref.read(configProvider).username);
  late final _apiBaseCtl = TextEditingController(text: ref.read(configProvider).apiBase);
  late final _healthBaseCtl = TextEditingController(text: ref.read(configProvider).healthBase);

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _usernameCtl.dispose();
    _apiBaseCtl.dispose();
    _healthBaseCtl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _usernameCtl.text.trim();
    if (username.isEmpty) {
      setState(() => _error = 'Please enter a username.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    final cfg = ref.read(configProvider);
    final apiBase = _apiBaseCtl.text.trim();
    final healthBase = _healthBaseCtl.text.trim();
    await ref.read(configProvider.notifier).update(cfg.copyWith(
          username: username,
          apiBase: apiBase.isEmpty ? cfg.apiBase : apiBase,
          healthBase: healthBase.isEmpty ? cfg.healthBase : healthBase,
        ));

    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
                  'Welcome',
                  style: Theme.of(context).textTheme.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Enter the username configured on your transaction-api / '
                  'health-api server. It identifies your data - no password needed.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    hintText: 'e.g. luthfi',
                  ),
                  textInputAction: TextInputAction.next,
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
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(_error!, style: const TextStyle(color: Colors.red)),
                  ),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_loading ? 'Please wait...' : 'Get Started'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
