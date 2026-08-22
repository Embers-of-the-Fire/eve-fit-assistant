import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/account/account_controller.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/setting/account/errors.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class AccountRegisterPage extends ConsumerStatefulWidget {
  const AccountRegisterPage({super.key, this.initialEmail, this.startAtVerification = false});

  /// Pre-fills the email field (e.g. when arriving from the login flow's
  /// `email_unverified` redirect).
  final String? initialEmail;

  /// Starts directly at the verification step; used when the server has
  /// already (re-)sent the code for a pending account.
  final bool startAtVerification;

  @override
  ConsumerState<AccountRegisterPage> createState() => _AccountRegisterPageState();
}

class _AccountRegisterPageState extends ConsumerState<AccountRegisterPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _codeController = TextEditingController();
  late bool _verificationStep = widget.startAtVerification;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.initialEmail ?? "";
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!isValidAccountEmail(email)) {
      setState(() => _error = context.l10n.accountInvalidEmail);
      return;
    }
    if (!isValidAccountPassword(password)) {
      setState(() => _error = context.l10n.accountPasswordTooShort);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountControllerProvider.notifier).signup(email, password);
      if (!mounted) return;
      setState(() {
        _busy = false;
        _verificationStep = true;
      });
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = accountErrorMessage(context, e);
      });
    }
  }

  Future<void> _resend() async {
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
      // Dedicated resend endpoint: the verification step may have been
      // reached from the login redirect, where no password was collected.
      await ref.read(accountControllerProvider.notifier).resendSignupCode(email);
      if (!mounted) return;
      setState(() => _busy = false);
    } on Object catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = accountErrorMessage(context, e);
      });
    }
  }

  Future<void> _verify() async {
    final email = _emailController.text.trim();
    final code = _codeController.text.trim();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountControllerProvider.notifier).verifyEmail(email, code);
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
      title: l10n.accountRegisterPageTitle,
      child: ListView(
        padding: const .symmetric(horizontal: 20, vertical: 24),
        children: [
          if (_verificationStep) ...[
            Text(l10n.accountVerificationCodeSent(email: _emailController.text.trim())),
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
              onSubmitted: (_) => unawaited(_verify()),
            ),
          ] else ...[
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l10n.accountEmailLabel,
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
                labelText: l10n.accountPasswordLabel,
                helperText: l10n.accountPasswordHint,
                border: const OutlineInputBorder(),
              ),
              onSubmitted: (_) => unawaited(_signup()),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : () => unawaited(_verificationStep ? _verify() : _signup()),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(_verificationStep ? l10n.accountVerifyButton : l10n.accountRegisterButton),
          ),
          if (_verificationStep)
            TextButton(
              onPressed: _busy ? null : () => unawaited(_resend()),
              child: Text(l10n.accountResendCodeButton),
            )
          else
            TextButton(
              onPressed: () => context.nav.pop(),
              child: Text(l10n.accountHaveAccountAction),
            ),
        ],
      ),
    );
  }
}
