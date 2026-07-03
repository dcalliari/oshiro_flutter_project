import 'package:flutter_test/flutter_test.dart';
import 'package:project_oshiro/models/track.dart';

Track _track({
  String bookId = 'new-zest-1',
  String unit = 'unit-01',
  String kind = 'dialogue',
}) =>
    Track(bookId: bookId, unit: unit, kind: kind, title: 't', url: 'u');

void main() {
  group('Track', () {
    test('id encodes the (unit, kind) pair', () {
      expect(_track(unit: 'unit-03', kind: 'question').id, 'unit-03-question');
    });

    test('fileName is the id with an .mp3 extension', () {
      expect(_track(unit: 'unit-02', kind: 'dialogue').fileName,
          'unit-02-dialogue.mp3');
    });

    test('the same (unit, kind) is stable across books but scoped by book', () {
      final a = _track(bookId: 'book-a');
      final b = _track(bookId: 'book-b');
      // Same logical id...
      expect(a.id, b.id);
      expect(a.fileName, b.fileName);
      // ...but different tracks, since identity includes the book. This is what
      // prevents the historical "two books both have 01.mp3" collision.
      expect(a, isNot(equals(b)));
    });

    test('equality and hashCode use (bookId, id), not title/url', () {
      const one = Track(
        bookId: 'b',
        unit: 'unit-01',
        kind: 'dialogue',
        title: 'First',
        url: 'url-1',
      );
      const two = Track(
        bookId: 'b',
        unit: 'unit-01',
        kind: 'dialogue',
        title: 'Different title',
        url: 'url-2',
      );
      expect(one, equals(two));
      expect(one.hashCode, two.hashCode);
      expect({one, two}, hasLength(1));
    });

    test('different kinds in the same unit are distinct tracks', () {
      final dialogue = _track(kind: 'dialogue');
      final question = _track(kind: 'question');
      expect(dialogue, isNot(equals(question)));
      expect(dialogue.fileName, isNot(question.fileName));
    });
  });
}
