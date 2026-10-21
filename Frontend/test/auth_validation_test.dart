import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/utils/auth_check.dart';

void main() {
  group('Auth Validation Tests', () {
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');

    test('Email validation rejects malformed emails', () {
      expect(emailRegex.hasMatch('userexample.com'), isFalse);
      expect(emailRegex.hasMatch('user@'), isFalse);
      expect(emailRegex.hasMatch('user@domain'), isFalse);
      expect(emailRegex.hasMatch('@domain.com'), isFalse);
      expect(emailRegex.hasMatch('user@.com'), isFalse);
      expect(emailRegex.hasMatch(''), isFalse);
    });

    test('Email validation accepts valid emails', () {
      expect(emailRegex.hasMatch('test@example.com'), isTrue);
      expect(emailRegex.hasMatch('user.name@sub.domain.co'), isTrue);
      expect(emailRegex.hasMatch('admin123@ad.in'), isTrue);
      expect(emailRegex.hasMatch('user+test@domain.org'), isTrue);
    });

    test('Phone number validation constraints (digits only, 10-15 digits)', () {
      final phoneRegex = RegExp(r'^[0-9]+$');
      
      bool isValidPhone(String phone) {
        final trimmed = phone.trim();
        return trimmed.isNotEmpty &&
            phoneRegex.hasMatch(trimmed) &&
            trimmed.length >= 10 &&
            trimmed.length <= 15;
      }

      // Valid
      expect(isValidPhone('9876543210'), isTrue);
      expect(isValidPhone('919876543210'), isTrue);
      expect(isValidPhone('123456789012345'), isTrue);

      // Invalid
      expect(isValidPhone(''), isFalse);
      expect(isValidPhone('12345'), isFalse); // too short
      expect(isValidPhone('123456789'), isFalse); // 9 digits
      expect(isValidPhone('1234567890123456'), isFalse); // 16 digits
      expect(isValidPhone('98765abcd0'), isFalse); // alphabetic
      expect(isValidPhone('98765-43210'), isFalse); // symbol
    });

    test('Password requirements (at least 6 characters on signup)', () {
      bool isValidSignupPassword(String pass) => pass.isNotEmpty && pass.length >= 6;

      expect(isValidSignupPassword(''), isFalse);
      expect(isValidSignupPassword('12345'), isFalse);
      expect(isValidSignupPassword('123456'), isTrue);
      expect(isValidSignupPassword('secretPass123!'), isTrue);
      expect(isValidSignupPassword('  pass'), isTrue); // whitespace preserved
    });

    test('Firebase Auth error message mapping', () {
      // Test mapping utility
      expect(
        AuthCheck.getFirebaseAuthErrorMessage(
          FirebaseAuthException(code: 'email-already-in-use'),
        ),
        equals('An account with this email already exists.'),
      );

      expect(
        AuthCheck.getFirebaseAuthErrorMessage(
          FirebaseAuthException(code: 'invalid-email'),
        ),
        equals('Please enter a valid email address.'),
      );

      expect(
        AuthCheck.getFirebaseAuthErrorMessage(
          FirebaseAuthException(code: 'weak-password'),
        ),
        equals('Password must be at least 6 characters long.'),
      );

      expect(
        AuthCheck.getFirebaseAuthErrorMessage(
          FirebaseAuthException(code: 'user-not-found'),
        ),
        equals('No account found with this email address.'),
      );

      expect(
        AuthCheck.getFirebaseAuthErrorMessage(
          FirebaseAuthException(code: 'wrong-password'),
        ),
        equals('Incorrect email or password. Please try again.'),
      );

      expect(
        AuthCheck.getFirebaseAuthErrorMessage(
          FirebaseAuthException(code: 'invalid-credential'),
        ),
        equals('Incorrect email or password. Please try again.'),
      );

      expect(
        AuthCheck.getFirebaseAuthErrorMessage(
          FirebaseAuthException(code: 'network-request-failed'),
        ),
        equals('Network connection failed. Please check your internet connection.'),
      );

      expect(
        AuthCheck.getFirebaseAuthErrorMessage(
          FirebaseAuthException(code: 'too-many-requests'),
        ),
        equals('Too many attempts. Please try again later.'),
      );
    });
  });
}
