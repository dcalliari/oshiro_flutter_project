import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/providers.dart';
import '../widgets/barcode_scanner_page.dart';
import '../widgets/book_cover.dart';
import '../widgets/state_views.dart';
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

  Future<void> _scan() async {
    final code = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const BarcodeScannerPage()),
    );
    if (code == null || !mounted) return;
    _controller.text = code;
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    final query = ref.watch(searchQueryProvider).trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Search'),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: TextField(
              controller: _controller,
              autofocus: true,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Title, author, ISBN...',
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surface,
                border: const OutlineInputBorder(),
                suffixIcon: barcodeScannerSupported
                    ? IconButton(
                        tooltip: 'Scan barcode',
                        icon: const Icon(Icons.qr_code_scanner),
                        onPressed: _scan,
                      )
                    : null,
              ),
            ),
          ),
        ),
      ),
      body: results.when(
        loading: () => const LoadingView(),
        error: (e, _) => ErrorView(
          message: 'Search failed. Please try again.',
          onRetry: () => ref.invalidate(searchResultsProvider),
        ),
        data: (books) {
          if (query.isEmpty) {
            return const EmptyView(
              icon: Icons.search,
              title: 'Find your next audiobook',
              subtitle: 'Search by title, author or ISBN — '
                  'or scan a book barcode.',
            );
          }
          if (books.isEmpty) {
            return EmptyView(
              icon: Icons.menu_book_outlined,
              title: 'No results',
              subtitle: 'Nothing matched "$query".',
            );
          }
          return ListView.builder(
            itemCount: books.length,
            itemBuilder: (context, index) => _SearchTile(book: books[index]),
          );
        },
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
      subtitle: book.authors.isEmpty ? null : Text(book.authors.join(', ')),
      trailing: inLibrary
          ? Tooltip(
              message: 'In your library',
              child: Icon(Icons.check_circle,
                  color: Theme.of(context).colorScheme.primary, size: 24),
            )
          : Tooltip(
              message: 'View details',
              child: Icon(Icons.chevron_right,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  size: 26),
            ),
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
