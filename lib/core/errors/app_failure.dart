import 'package:supabase_flutter/supabase_flutter.dart';

/// A user-presentable failure. Repositories throw this; screens show [message].
class AppFailure implements Exception {
  const AppFailure(this.message);
  final String message;

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    if (error is AuthException) {
      final m = error.message.toLowerCase();
      if (m.contains('invalid login')) return const AppFailure('Incorrect email or password.');
      if (m.contains('not confirmed')) return const AppFailure('This account is not activated yet. Contact your administrator.');
      return AppFailure(error.message);
    }
    if (error is PostgrestException) {
      if (error.code == '42501') return const AppFailure('You do not have permission for this action.');
      if (error.code == '23505') return const AppFailure('A record with the same code or number already exists.');
      return AppFailure(error.message);
    }
    if (error is FunctionException) {
      final details = error.details;
      if (details is Map && details['error'] is String) return AppFailure(details['error'] as String);
      return AppFailure('Server function failed (${error.status}).');
    }
    final text = error.toString();
    if (text.contains('SocketException') || text.contains('Failed host lookup') ||
        text.contains('XMLHttpRequest') || text.contains('ClientException')) {
      return const AppFailure('No connection to the server. Check your network.');
    }
    return AppFailure(text);
  }

  @override
  String toString() => message;
}
