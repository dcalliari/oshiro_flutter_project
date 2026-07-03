import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/track.dart';

typedef ProgressCallback = void Function(double progress);

/// Manages the on-disk copies of track audio. Files live under
/// `<appDocuments>/books/{bookId}/{trackId}.mp3`, so downloads are scoped per
/// book and never collide across books.
abstract class StorageRepository {
  /// Absolute path where [track] is (or would be) stored.
  Future<String> pathFor(Track track);

  Future<bool> isDownloaded(Track track);

  /// Downloads [track] and returns the local path. Reports 0..1 progress.
  Future<String> download(Track track, {ProgressCallback? onProgress});

  Future<void> delete(Track track);

  /// Removes every downloaded file for a book.
  Future<void> deleteBook(String bookId);
}

/// Shared path logic for both real and mock implementations.
mixin _ScopedPaths {
  Future<Directory> _bookDir(String bookId) async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'books', bookId));
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Future<String> pathFor(Track track) async {
    final dir = await _bookDir(track.bookId);
    return p.join(dir.path, track.fileName);
  }

  Future<bool> isDownloaded(Track track) async =>
      File(await pathFor(track)).exists();

  Future<void> delete(Track track) async {
    final file = File(await pathFor(track));
    if (await file.exists()) await file.delete();
  }

  Future<void> deleteBook(String bookId) async {
    final dir = await _bookDir(bookId);
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// Downloads real MP3s via their Firebase Storage download URLs (dio).
class FileStorageRepository with _ScopedPaths implements StorageRepository {
  FileStorageRepository({Dio? dio}) : _dio = dio ?? Dio();

  final Dio _dio;

  @override
  Future<String> download(Track track, {ProgressCallback? onProgress}) async {
    final path = await pathFor(track);
    await _dio.download(
      track.url,
      path,
      onReceiveProgress: (count, total) {
        if (total > 0) onProgress?.call(count / total);
      },
    );
    return path;
  }
}

/// Simulates downloads offline: emits fake progress then writes a small
/// placeholder file at the scoped path so existence/deletion flows behave like
/// the real repository. The bytes are not valid audio — real playable samples
/// are out of scope for the foundation phase.
class MockStorageRepository with _ScopedPaths implements StorageRepository {
  @override
  Future<String> download(Track track, {ProgressCallback? onProgress}) async {
    for (final step in const [0.25, 0.5, 0.75, 1.0]) {
      await Future<void>.delayed(const Duration(milliseconds: 120));
      onProgress?.call(step);
    }
    final path = await pathFor(track);
    await File(path).writeAsBytes(Uint8List.fromList(
      'mock-audio:${track.bookId}/${track.id}'.codeUnits,
    ));
    return path;
  }
}
