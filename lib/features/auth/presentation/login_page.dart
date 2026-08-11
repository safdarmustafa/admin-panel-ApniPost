import 'package:apnipost_admin/core/config/app_config.dart';
import 'package:apnipost_admin/features/auth/presentation/auth_providers.dart';
import 'package:apnipost_admin/features/auth/presentation/login_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final controller = ref.read(loginControllerProvider.notifier);
    await controller.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailController.text.trim();
    final entered = await showDialog<String>(
      context: context,
      builder: (context) => _ForgotPasswordDialog(initialEmail: email),
    );
    if (entered == null || !mounted) return;
    await ref.read(loginControllerProvider.notifier).sendPasswordReset(entered);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formState = ref.watch(loginControllerProvider);
    final access = ref.watch(adminAccessProvider);
    final accessMessage = access.asData?.value.message;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        AppConfig.appName,
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.primary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to manage ApniPost content',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 28),
                      if (!AppConfig.isSupabaseConfigured) ...[
                        _Banner(
                          tone: _BannerTone.error,
                          message:
                              'Supabase is not configured. Provide SUPABASE_URL '
                              'and SUPABASE_ANON_KEY via --dart-define.',
                        ),
                        const SizedBox(height: 20),
                      ],
                      if (formState.errorMessage != null) ...[
                        _Banner(
                          tone: _BannerTone.error,
                          message: formState.errorMessage!,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (formState.infoMessage != null) ...[
                        _Banner(
                          tone: _BannerTone.info,
                          message: formState.infoMessage!,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (accessMessage != null &&
                          formState.errorMessage == null) ...[
                        _Banner(
                          tone: _BannerTone.warning,
                          message: accessMessage,
                        ),
                        const SizedBox(height: 16),
                      ],
                      TextFormField(
                        controller: _emailController,
                        enabled: !formState.isBusy &&
                            AppConfig.isSupabaseConfigured,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        textInputAction: TextInputAction.next,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          hintText: 'admin@example.com',
                        ),
                        validator: (value) {
                          final text = value?.trim() ?? '';
                          if (text.isEmpty) return 'Email is required';
                          if (!text.contains('@')) {
                            return 'Enter a valid email address';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _passwordController,
                        enabled: !formState.isBusy &&
                            AppConfig.isSupabaseConfigured,
                        obscureText: formState.obscurePassword,
                        autofillHints: const [AutofillHints.password],
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) {
                          if (_formKey.currentState?.validate() ?? false) {
                            _submit();
                          }
                        },
                        decoration: InputDecoration(
                          labelText: 'Password',
                          hintText: '••••••••',
                          suffixIcon: IconButton(
                            onPressed: formState.isBusy
                                ? null
                                : () => ref
                                    .read(loginControllerProvider.notifier)
                                    .togglePasswordVisibility(),
                            icon: Icon(
                              formState.obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Password is required';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: formState.isBusy ||
                                  !AppConfig.isSupabaseConfigured
                              ? null
                              : _forgotPassword,
                          child: const Text('Forgot password?'),
                        ),
                      ),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: formState.isBusy ||
                                !AppConfig.isSupabaseConfigured
                            ? null
                            : () {
                                if (_formKey.currentState?.validate() ??
                                    false) {
                                  _submit();
                                }
                              },
                        child: formState.status == LoginFormStatus.submitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('Sign in'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _BannerTone { error, warning, info }

class _Banner extends StatelessWidget {
  const _Banner({
    required this.tone,
    required this.message,
  });

  final _BannerTone tone;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final Color background;
    final Color foreground;

    switch (tone) {
      case _BannerTone.error:
        background = theme.colorScheme.errorContainer;
        foreground = theme.colorScheme.onErrorContainer;
      case _BannerTone.warning:
        background = theme.colorScheme.tertiaryContainer;
        foreground = theme.colorScheme.onTertiaryContainer;
      case _BannerTone.info:
        background = theme.colorScheme.secondaryContainer;
        foreground = theme.colorScheme.onSecondaryContainer;
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(color: foreground),
        ),
      ),
    );
  }
}

class _ForgotPasswordDialog extends StatefulWidget {
  const _ForgotPasswordDialog({required this.initialEmail});

  final String initialEmail;

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset password'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.emailAddress,
        decoration: const InputDecoration(
          labelText: 'Email',
          hintText: 'admin@example.com',
        ),
        onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: const Text('Send reset link'),
        ),
      ],
    );
  }
}
