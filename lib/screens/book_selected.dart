import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/providers.dart';
import '../widgets/book_cover.dart';
import 'track_list.dart';

/// Book detail shown for a book not yet in the library, with an "add" action.
class BookSelected extends ConsumerWidget {
  const BookSelected({super.key, required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: 'Close',
            icon: const Icon(Icons.close, size: 28),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: SizedBox(
              width: 140,
              height: 190,
              child: BookCover(url: book.coverUrl),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            book.name,
            textAlign: TextAlign.center,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          if (book.authors.isNotEmpty)
            _MetaRow(label: 'Authors', value: book.authors.join('\n')),
          if (book.publisher != null)
            _MetaRow(label: 'Publisher', value: book.publisher!),
          if (book.published != null)
            _MetaRow(label: 'Published', value: book.published!),
          if (book.isbn.isNotEmpty) _MetaRow(label: 'ISBN', value: book.isbn),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add to library'),
            onPressed: () async {
              await ref.read(libraryControllerProvider).add(book.id);
              if (!context.mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Added "${book.name}" to your library.')),
              );
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => TrackList(book: book)),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text('$label:', textAlign: TextAlign.right),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
