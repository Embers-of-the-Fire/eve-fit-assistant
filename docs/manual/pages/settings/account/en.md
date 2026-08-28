---
title: Account
summary: Sign in or register an EFA Platform account, view the current account, sign out, or delete the account.
---

# Account

The Account page (Settings → **Account**) manages your EFA Platform account. An account is only needed for platform features such as [publishing fits](efa://manual/sharing/publishing-fits) — everything else in the app works without signing in.

## Signed Out

When no account is signed in, the page offers two entries:

- **Sign in** — sign in with an existing account using its email and password. The sign-in page also links to **Forgot password?**, which resets the password with a verification code emailed to you, and to registration.
- **Register** — create a new account with your email and a password of at least 10 characters. The app emails a 6-digit verification code to the address; enter it to finish registering. The code can be resent if it does not arrive.

Below the entries, the page shows the platform's legal and security notices: the EFA Platform is an unofficial, community-run service provided as is, and staff will never ask for your password or verification codes (report security issues to security@efa-tech.dev); your session tokens are stored only in this device's operating-system secure storage, are never sent to third parties, and are deleted when you sign out.

## Signed In

When signed in, the page shows the current account — email, user ID, and roles (Member, Moderator, or Administrator) — plus the following actions:

- **Sign out** — asks for confirmation, then signs you out and clears the local session.
- **Delete account** — asks for confirmation and your current password. This cannot be undone: the account is anonymized, all sessions are revoked immediately, and the address becomes available for re-registration.

Accounts with the Administrator role additionally see an administration placeholder area. It only validates client-side role filtering; real authorization is always enforced by the platform API.
