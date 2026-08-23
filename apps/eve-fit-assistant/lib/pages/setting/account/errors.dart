import "package:efa_platform_client/efa_platform_client.dart";
import "package:eve_fit_assistant/utils/context.dart";
import "package:flutter/material.dart";

/// Maps an auth flow failure to a localized, user-facing message.
String accountErrorMessage(BuildContext context, Object error) {
  final l10n = context.l10n;
  if (error is AccountApiException) {
    return switch (error.code) {
      "invalid_credentials" => l10n.accountErrorInvalidCredentials,
      "email_taken" => l10n.accountErrorEmailTaken,
      "otp_invalid" => l10n.accountErrorOtpInvalid,
      "otp_expired" => l10n.accountErrorOtpExpired,
      "email_unverified" => l10n.accountErrorEmailUnverified,
      "rate_limited" => l10n.accountErrorRateLimited,
      null when error.statusCode == null => l10n.accountErrorNetwork,
      _ => l10n.accountErrorGeneric,
    };
  }
  return l10n.accountErrorGeneric;
}

final _emailPattern = RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$");

/// Client-side email shape check (the server validates authoritatively).
bool isValidAccountEmail(String email) => _emailPattern.hasMatch(email.trim());

/// Mirrors the server-side password policy (`min(10).max(128)`).
bool isValidAccountPassword(String password) => password.length >= 10 && password.length <= 128;

final _codePattern = RegExp(r"^[0-9]{6}$");

/// Verification codes are exactly 6 ASCII digits (the input field already restricts input
/// accordingly). `int.tryParse` would also accept signed and hexadecimal literals, so a regex
/// is used instead.
bool isValidAccountCode(String code) => _codePattern.hasMatch(code);
