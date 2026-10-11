import 'package:flutter_test/flutter_test.dart';
import 'package:resqmesh/features/chat/domain/mentions.dart';

void main() {
  test('the @word being typed is found only at the cursor', () {
    expect(mentionQuery('Hi @Ra', 6), 'Ra');
    expect(mentionQuery('@', 1), '');
    expect(mentionQuery('Hi @Rahim and', 13), isNull);
    expect(mentionQuery('mail@home', 9), isNull, reason: 'not after a space');
    expect(mentionQuery('Hi @Ra', 99), isNull);
  });

  test('picking a name replaces the @word and moves the cursor', () {
    final (text, cursor) = insertMention('Hi @Ra, ok', 6, 'Rahim Uddin');
    expect(text, 'Hi @Rahim Uddin , ok');
    expect(cursor, 'Hi @Rahim Uddin '.length);
  });

  test('mentions are split out, longest name first, any case', () {
    expect(
      mentionParts('Hi @Rahim Uddin and @karim!', [
        'Rahim',
        'Rahim Uddin',
        'Karim',
      ]),
      [
        ('Hi ', false),
        ('@Rahim Uddin', true),
        (' and ', false),
        ('@karim', true),
        ('!', false),
      ],
    );
    expect(mentionParts('no mentions', ['Rahim']), [('no mentions', false)]);
    expect(mentionParts('@Rahim', const []), [('@Rahim', false)]);
  });
}
