import "dart:async";

import "package:auto_route/auto_route.dart";
import "package:eve_fit_assistant/components/layout.dart";
import "package:eve_fit_assistant/features/account/account_api.dart";
import "package:eve_fit_assistant/features/account/account_controller.dart";
import "package:eve_fit_assistant/pages/router.dart";
import "package:eve_fit_assistant/pages/setting/account/errors.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

@RoutePage()
class AccountLoginPage extends ConsumerStatefulWidget {
  const AccountLoginPage({super.key});

  @override
  ConsumerState<AccountLoginPage> createState() => _AccountLoginPageState();
}

class _AccountLoginPageState extends ConsumerState<AccountLoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (!isValidAccountEmail(email)) {
      setState(() => _error = context.l10n.accountInvalidEmail);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(accountControllerProvider.notifier).login(email, password);
      if (!mounted) return;
      // Drop the whole auth flow from the stack and land on the account page.
      unawaited(context.router.popToRootAndPush(const AccountRoute()));
    } on AccountApiException catch (e) {
      if (!mounted) return;
      if (e.isEmailUnverified) {
        // The server re-sent the verification code best-effort; jump
        // straight into the verification step of the register flow.
        unawaited(
          context.router.push(AccountRegisterRoute(initialEmail: email, startAtVerification: true)),
        );
      }
      setState(() {
        _busy = false;
        _error = accountErrorMessage(context, e);
      });
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
      title: l10n.accountLoginPageTitle,
      child: ListView(
        padding: const .symmetric(horizontal: 20, vertical: 24),
        children: [
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
              border: const OutlineInputBorder(),
            ),
            onSubmitted: (_) => unawaited(_submit()),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: TextStyle(color: context.theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : () => unawaited(_submit()),
            child: _busy
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.accountSignInButton),
          ),
          TextButton(
            onPressed: () => unawaited(context.router.push(const AccountResetPasswordRoute())),
            child: Text(l10n.accountForgotPasswordAction),
          ),
          TextButton(
            onPressed: () => unawaited(context.router.push(AccountRegisterRoute())),
            child: Text(l10n.accountNoAccountAction),
          ),
        ],
      ),
    );
  }
}
