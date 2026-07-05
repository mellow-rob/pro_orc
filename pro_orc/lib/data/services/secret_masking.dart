// Pure secret-masking helpers used by the harness reader so that env values,
// MCP URLs and command args that look like credentials are never surfaced in
// plain text in the UI.
//
// No Flutter imports — pure Dart, unit-testable.

/// Case-insensitive fragments that mark a key/flag/query-param as sensitive.
final RegExp _secretPattern = RegExp(
  r'KEY|TOKEN|SECRET|PASSWORD|CREDENTIAL|AUTH',
  caseSensitive: false,
);

/// True if [name] looks like it names a secret (contains any secret fragment).
bool looksLikeSecretName(String name) => _secretPattern.hasMatch(name);

/// Masks a secret [value]: reveals only the last 4 characters, replacing the
/// rest with `••••`. Values shorter than 8 characters are fully masked so a
/// short secret is never mostly revealed. Empty input stays empty.
String maskValue(String value) {
  if (value.isEmpty) return value;
  if (value.length < 8) return '••••';
  return '••••${value.substring(value.length - 4)}';
}

/// Masks an env var value: returns [value] unchanged unless [key] looks like a
/// secret name, in which case the value is masked via [maskValue].
String maskEnvValue(String key, String value) {
  return looksLikeSecretName(key) ? maskValue(value) : value;
}

/// Masks any secret-looking material inside a display string that may be a URL
/// or a `command args...` line:
///   - URL userinfo (`user:pass@host`) → the password is masked,
///   - query parameters whose name looks like a secret → value masked,
///   - a token/args segment immediately following a secret-looking flag
///     (e.g. `--api-key VALUE`, `--token=VALUE`) → value masked.
///
/// Pure and never throws — an unparseable URL falls back to the args-based
/// scan on the raw string.
String maskSecrets(String detail) {
  if (detail.isEmpty) return detail;

  var result = detail;

  // 1) URL query params + userinfo. Try each whitespace-separated token as a
  //    URI so both a bare URL and a `command --url https://...` line work.
  final tokens = result.split(RegExp(r'\s+'));
  for (final token in tokens) {
    final masked = _maskUrlToken(token);
    if (masked != token) {
      result = result.replaceFirst(token, masked);
    }
  }

  // 2) Flag-based args: `--api-key VALUE`, `-token=VALUE`, `--secret VALUE`.
  result = _maskFlagArgs(result);

  return result;
}

/// Masks query-param values and userinfo passwords inside a single URL-ish
/// token. Returns the token unchanged when it is not a parseable http(s) URL.
String _maskUrlToken(String token) {
  final uri = Uri.tryParse(token);
  if (uri == null || !uri.hasScheme) return token;
  if (uri.scheme != 'http' && uri.scheme != 'https') return token;

  var changed = false;

  // Userinfo: mask the password half of `user:pass`.
  String? userInfo = uri.userInfo.isEmpty ? null : uri.userInfo;
  if (userInfo != null && userInfo.contains(':')) {
    final parts = userInfo.split(':');
    final user = parts.first;
    userInfo = '$user:${maskValue(parts.sublist(1).join(':'))}';
    changed = true;
  }

  // Query params with secret-looking names.
  final newParams = <String, String>{};
  uri.queryParameters.forEach((name, value) {
    if (looksLikeSecretName(name)) {
      newParams[name] = maskValue(value);
      changed = true;
    } else {
      newParams[name] = value;
    }
  });

  if (!changed) return token;

  final rebuilt = uri.replace(
    userInfo: userInfo,
    queryParameters: newParams.isEmpty ? null : newParams,
  );
  return rebuilt.toString();
}

/// Scans a space-separated args string and masks the value that follows any
/// secret-looking flag, in both `--flag value` and `--flag=value` forms.
String _maskFlagArgs(String input) {
  final tokens = input.split(' ');
  final out = <String>[];

  for (var i = 0; i < tokens.length; i++) {
    final token = tokens[i];

    // `--flag=value` form.
    final eq = token.indexOf('=');
    if (token.startsWith('-') && eq > 0) {
      final flag = token.substring(0, eq);
      if (looksLikeSecretName(flag)) {
        out.add('$flag=${maskValue(token.substring(eq + 1))}');
        continue;
      }
    }

    // `--flag value` form: mask the *next* token.
    if (token.startsWith('-') && looksLikeSecretName(token)) {
      out.add(token);
      if (i + 1 < tokens.length) {
        out.add(maskValue(tokens[i + 1]));
        i++;
      }
      continue;
    }

    out.add(token);
  }

  return out.join(' ');
}
