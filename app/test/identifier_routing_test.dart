// Which of the three sign-ins a typed identifier belongs to.
//
// This replaced a four-card role picker on the login screen. It has to be
// right for the same reason the picker was removable: a parent's phone and a
// director's email go to *different servers*, so a wrong guess is not a
// cosmetic mistake -- it sends the credentials somewhere that has never
// heard of them.
//
// The cases below are the ways people actually type their own number.

import 'package:flutter_test/flutter_test.dart';
import 'package:smartschool_app/screens/login_screen.dart';

void main() {
  group('a phone number, however it is written', () {
    for (final input in [
      '987644002',
      '98 764 40 02',
      '+992987644002',
      '+992 98 764 40 02',
      '992987644002',
      '0987644002',
      '(98) 764-40-02',
    ]) {
      test(input, () {
        expect(classifyIdentifier(input), IdentifierKind.phone);
      });
    }
  });

  group('an email address', () {
    for (final input in [
      'director@smartschool.com',
      'nilufar.s@maktab.tj',
      ' teacher@school.com ',
    ]) {
      test(input, () {
        expect(classifyIdentifier(input), IdentifierKind.email);
      });
    }
  });

  group("a pupil's login", () {
    for (final input in ['komron75', 'abdulloeva_k', 'student1']) {
      test(input, () {
        expect(classifyIdentifier(input), IdentifierKind.username);
      });
    }
  });

  test('a username that is only digits is read as a phone', () {
    // Accepted consequence, and the reason directors are told to give pupils
    // a login with letters in it: a bare "12345" is indistinguishable from
    // someone starting to type their number.
    expect(classifyIdentifier('12345'), IdentifierKind.phone);
  });

  test('empty input is not a phone', () {
    // Otherwise the empty field looks like a parent to the submit handler.
    expect(classifyIdentifier(''), IdentifierKind.username);
    expect(classifyIdentifier('   '), IdentifierKind.username);
  });
}
