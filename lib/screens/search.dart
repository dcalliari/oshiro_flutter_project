import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/providers.dart';
import '../widgets/book_cover.dart';
import 'book_selected.dart';
import 'track_list.dart';

class Search extends ConsumerStatefulWidget {
  const Search({super.key});

  @override
  ConsumerState<Search> createState() => _SearchState();
}

class _SearchState extends ConsumerState<Search> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      ref.read(searchQueryProvider.notifier).state = _controller.text;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Busca'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Título, Autor, ISBN...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: const OutlineInputBorder(),
                // TODO(phase-2): replace with mobile_scanner barcode capture.
                suffixIcon: IconButton(
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Leitor de código de barras em breve.'),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erro: $e')),
        data: (books) => ListView.builder(
          itemCount: books.length,
          itemBuilder: (context, index) => _SearchTile(book: books[index]),
        ),
      ),
    );
  }
}

class _SearchTile extends ConsumerWidget {
  const _SearchTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inLibrary =
        ref.watch(isInLibraryProvider(book.id)).valueOrNull ?? false;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
      leading: SizedBox(width: 48, child: BookCover(url: book.coverUrl)),
      title: Text(book.name),
      trailing: inLibrary
          ? const Icon(Icons.arrow_forward_ios, color: Colors.red, size: 20)
          : const Icon(Icons.add, color: Colors.red, size: 28),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) =>
              inLibrary ? TrackList(book: book) : BookSelected(book: book),
        ),
      ),
    );
  }
}
