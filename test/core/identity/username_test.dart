import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/core/identity/username.dart';

UsernameError? errorOf(String raw) => switch (Username.validate(raw)) {
  ValidUsername() => null,
  InvalidUsername(:final error) => error,
};

String? validName(String raw) => switch (Username.validate(raw)) {
  ValidUsername(:final name) => name,
  InvalidUsername() => null,
};

void main() {
  group('Username.validate', () {
    test('accepts a normal name', () {
      expect(validName('Yusuf'), 'Yusuf');
    });

    test('trims and collapses whitespace', () {
      expect(validName('   Yusuf   Rahman  '), 'Yusuf Rahman');
      expect(validName('Yusuf\t Rahman'), isNull, reason: 'tab is a control');
    });

    test('rejects empty and whitespace-only names', () {
      expect(errorOf(''), UsernameError.empty);
      expect(errorOf('     '), UsernameError.empty);
    });

    test('enforces 2 to 30 characters', () {
      expect(errorOf('T'), UsernameError.tooShort);
      expect(validName('Ta'), 'Ta');
      expect(validName('a' * 30), 'a' * 30);
      expect(errorOf('a' * 31), UsernameError.tooLong);
    });

    test('counts graphemes, not code units', () {
      // Each family emoji is one character made of several code points.
      const family = '👨‍👩‍👧';
      expect(validName(family * 2), family * 2);
      expect(errorOf(family * 31), UsernameError.tooLong);
      // Bangla with combining vowel signs.
      expect(validName('ইউসুফ'), 'ইউসুফ');
      expect(Username.length('ইউসুফ'), 4);
    });

    test('rejects line breaks and control characters inside a name', () {
      expect(errorOf('Yus\nuf'), UsernameError.invalidCharacters);
      expect(errorOf('Yus\u0000uf'), UsernameError.invalidCharacters);
      expect(errorOf('Yus\u2028uf'), UsernameError.invalidCharacters);
    });

    test('ignores line breaks at the ends, which trimming removes', () {
      expect(validName('\nYusuf\n'), 'Yusuf');
    });
  });

  group('Username.same', () {
    test('ignores case and spacing', () {
      expect(Username.same('Yusuf', 'yusuf'), isTrue);
      expect(Username.same('Yusuf  Rahman', ' yusuf rahman'), isTrue);
    });

    test('different names differ', () {
      expect(Username.same('Yusuf', 'Rahim'), isFalse);
    });
  });
}
