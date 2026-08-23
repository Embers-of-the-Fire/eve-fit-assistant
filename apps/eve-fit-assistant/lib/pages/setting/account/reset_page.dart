import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/account/providers.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/setting/account/errors.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class AccountResetPasswordPage extends ConsumerStatefulWidget {
  const AccountResetPasswordPage({super.key});

  @override
  ConsumerState<AccountResetPasswordPage> createState() => _AccountResetPasswordPageState();
}

class _AccountResetPasswordPageState extends ConsumerState<AccountResetPasswordPage> {
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _codeStep = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    final email = _emailController.text.trim();
    if (!isValidAccountEmail(email)) {
      setState(() => _error = context.l10n.accountInvalidEmail);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref.read(platformSessionProvider.future);
      await session.requestPasswordReset(email: email);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _codeStep = true;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = accountErrorMessage(context, e);
      });
    }
  }

  Future<void> _confirm() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    final newPassword = _passwordController.text;
    if (!isValidAccountPassword(newPassword)) {
      setState(() => _error = context.l10n.accountPasswordTooShort);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final session = await ref.read(platformSessionProvider.future);
      await session.confirmPasswordReset(email: email, code: code, newPassword: newPassword);
      if (!mounted) return;
      unawaited(context.router.popToRootAndPush(const AccountRoute()));
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = accountErrorMessage(context, e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Layout(
      title: l10n.accountResetPasswordPageTitle,
      child: ListView(
        padding: const .symmetric(horizontal: 20, vertical: 24),
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enableSuggestions: false,
            enabled: !_codeStep,
            decoration: InputDecoration(
              labelText: l10n.accountEmailLabel,
              border: const OutlineInputBorder(),
            ),
          ),
          if (_codeStep) ...[
            const SizedBox(height: 16),
            Text(l10n.accountResetCodeSent),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: InputDecoration(
                labelText: l10n.accountVerificationCodeLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.accountNewPasswordLabel,
                helperText: l10n.accountPasswordHint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => unawaited(_confirm()),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : () => unawaited(_codeStep ? _confirm() : _requestCode()),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_codeStep ? l10n.accountResetPasswordButton : l10n.accountSendCodeButton),
          ),
          if (_codeStep)
            TextButton(
              onPressed: _busy ? null : () => unawaited(_requestCode()),
              child: Text(l10n.accountResendCodeButton),
            ),
        ],
      ),
    );
  }
}
