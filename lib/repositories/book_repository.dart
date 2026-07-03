import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/mock/mock_books.dart';
import '../models/book.dart';

/// Read access to the catalog of books. Search covers title, author and ISBN.
abstract class BookRepository {
  Stream<List<Book>> watchBooks();
  Future<List<Book>> getBooks();
  Future<Book?> getBook(String id);
  Future<List<Book>> search(String query);
}

/// Client-side search over an already-fetched list. The catalog is tiny (a
/// handful of books), so filtering in memory is both simplest and enough;
/// shared by the real and mock repositories.
List<Book> filterBooks(List<Book> books, String query) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final qDigits = q.replaceAll('-', '');
  return books.where((b) {
    if (b.name.toLowerCase().contains(q)) return true;
    if (b.authors.any((a) => a.toLowerCase().contains(q))) return true;
    if (b.isbn.replaceAll('-', '') == qDigits) return true;
    return false;
  }).toList();
}

class FirestoreBookRepository implements BookRepository {
  FirestoreBookRepository({FirebaseFirestore? firestore})
      : _books = (firestore ?? FirebaseFirestore.instance).collection('books');

  final CollectionReference<Map<String, dynamic>> _books;

  Book _fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) =>
      Book.fromFirestore(doc.id, doc.data());

  @override
  Stream<List<Book>> watchBooks() => _books.snapshots().map(
        (snap) => snap.docs.map(_fromDoc).toList(),
      );

  @override
  Future<List<Book>> getBooks() async {
    final snap = await _books.get();
    return snap.docs.map(_fromDoc).toList();
  }

  @override
  Future<Book?> getBook(String id) async {
    final doc = await _books.doc(id).get();
    final data = doc.data();
    if (data == null) return null;
    return Book.fromFirestore(doc.id, data);
  }

  @override
  Future<List<Book>> search(String query) async =>
      filterBooks(await getBooks(), query);
}

/// In-memory repository seeded with the three real books. Backs mock mode
/// (desktop/web, or `--dart-define=USE_MOCK=true`).
class MockBookRepository implements BookRepository {
  MockBookRepository({List<Book>? seed}) : _books = seed ?? mockBooks();

  final List<Book> _books;

  @override
  Stream<List<Book>> watchBooks() => Stream.value(List.unmodifiable(_books));

  @override
  Future<List<Book>> getBooks() async => List.unmodifiable(_books);

  @override
  Future<Book?> getBook(String id) async {
    for (final b in _books) {
      if (b.id == id) return b;
    }
    return null;
  }

  @override
  Future<List<Book>> search(String query) async => filterBooks(_books, query);
}
