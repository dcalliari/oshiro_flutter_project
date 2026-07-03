import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/providers.dart';
import '../widgets/book_cover.dart';
import '../widgets/mini_player.dart';
import '../widgets/state_views.dart';
import 'search.dart';
import 'track_list.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tab = TabController(length: 2, vsync: this);

  /// When true the "All" list turns into a multi-select removal surface.
  bool _selectionMode = false;
  final Set<String> _selected = {};

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  void _enterSelection() {
    setState(() {
      _selectionMode = true;
      _selected.clear();
      _tab.index = 0;
    });
  }

  /// Long-pressing a book jumps straight into selection mode with it selected.
  void _enterSelectionWith(String bookId) {
    setState(() {
      _selectionMode = true;
      _selected
        ..clear()
        ..add(bookId);
      _tab.index = 0;
    });
  }

  void _exitSelection() {
    setState(() {
      _selectionMode = false;
      _selected.clear();
    });
  }

  void _toggleSelected(String bookId) {
    setState(() {
      if (!_selected.remove(bookId)) _selected.add(bookId);
    });
  }

  void _openSearch() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const Search()));
  }

  Future<bool> _confirm(String title, String message, String confirmLabel) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _removeSelected() async {
    final count = _selected.length;
    if (count == 0) return;
    final ok = await _confirm(
      'Remove ${count == 1 ? 'book' : 'books'}?',
      'This removes $count ${count == 1 ? 'book' : 'books'} from your library '
          'and deletes any downloaded audio.',
      'Remove',
    );
    if (!ok) return;
    final library = ref.read(libraryControllerProvider);
    final downloads = ref.read(downloadControllerProvider);
    for (final id in _selected) {
      await downloads.deleteBook(id);
      await library.remove(id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed $count '
          '${count == 1 ? 'book' : 'books'} from your library.')),
    );
    _exitSelection();
  }

  Future<void> _clearDownloadsSelected() async {
    final count = _selected.length;
    if (count == 0) return;
    final ok = await _confirm(
      'Delete downloads?',
      'This deletes downloaded audio for $count '
          '${count == 1 ? 'book' : 'books'} but keeps them in your library.',
      'Delete',
    );
    if (!ok) return;
    final downloads = ref.read(downloadControllerProvider);
    for (final id in _selected) {
      await downloads.deleteBook(id);
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Downloads deleted.')),
    );
    _exitSelection();
  }

  @override
  Widget build(BuildContext context) {
    if (_selectionMode) return _buildSelectionScaffold();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search),
            onPressed: _openSearch,
          ),
        ],
        bottom: TabBar(
          controller: _tab,
          tabs: const [
            Tab(text: 'All'),
            Tab(icon: Icon(Icons.bookmark), text: 'Favorites'),
          ],
        ),
      ),
      drawer: _HomeDrawer(onManage: _enterSelection),
      bottomNavigationBar: const MiniPlayer(),
      body: TabBarView(
        controller: _tab,
        children: [
          _AllBooksTab(
            onSearch: _openSearch,
            onLongPress: _enterSelectionWith,
          ),
          _FavoritesTab(onSearch: _openSearch),
        ],
      ),
    );
  }

  Widget _buildSelectionScaffold() {
    final count = _selected.length;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: 'Done',
          icon: const Icon(Icons.close),
          onPressed: _exitSelection,
        ),
        title: Text(count == 0 ? 'Select books' : '$count selected'),
        actions: [
          IconButton(
            tooltip: 'Delete downloads',
            icon: const Icon(Icons.download_done),
            onPressed: count == 0 ? null : _clearDownloadsSelected,
          ),
          IconButton(
            tooltip: 'Remove from library',
            icon: const Icon(Icons.delete_outline),
            onPressed: count == 0 ? null : _removeSelected,
          ),
        ],
      ),
      bottomNavigationBar: const MiniPlayer(),
      body: _SelectableLibrary(
        selected: _selected,
        onToggle: _toggleSelected,
      ),
    );
  }
}

// --------------------------------------------------------------- all books tab

class _AllBooksTab extends ConsumerWidget {
  const _AllBooksTab({required this.onSearch, required this.onLongPress});

  final VoidCallback onSearch;
  final void Function(String bookId) onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final asGrid = ref.watch(libraryAsGridProvider).valueOrNull ?? false;

    return library.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: 'Could not load your library.',
        onRetry: () => ref.invalidate(libraryProvider),
      ),
      data: (books) {
        if (books.isEmpty) {
          return EmptyView(
            icon: Icons.library_books_outlined,
            title: 'Your library is empty',
            subtitle: 'Search for audiobooks and add them to get started.',
            actionLabel: 'Search books',
            onAction: onSearch,
          );
        }
        if (asGrid) return _BookGrid(books: books, onLongPress: onLongPress);
        return _ReorderableBookList(books: books, onLongPress: onLongPress);
      },
    );
  }
}

/// List view with drag-and-drop reordering, persisted through the controller.
class _ReorderableBookList extends ConsumerWidget {
  const _ReorderableBookList({required this.books, required this.onLongPress});

  final List<Book> books;
  final void Function(String bookId) onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ReorderableListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: books.length,
      onReorder: (oldIndex, newIndex) {
        final ordered = [...books];
        if (newIndex > oldIndex) newIndex -= 1;
        final moved = ordered.removeAt(oldIndex);
        ordered.insert(newIndex, moved);
        ref
            .read(libraryControllerProvider)
            .reorder(ordered.map((b) => b.id).toList());
      },
      itemBuilder: (context, index) {
        final book = books[index];
        return ListTile(
          key: ValueKey(book.id),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
          leading: SizedBox(
            width: 48,
            child: BookCover(url: book.coverUrl),
          ),
          title: Text(book.name),
          subtitle: book.authors.isEmpty ? null : Text(book.authors.join(', ')),
          trailing: ReorderableDragStartListener(
            index: index,
            child: const Icon(Icons.drag_handle, color: Colors.grey),
          ),
          onTap: () => _openBook(context, book),
          onLongPress: () => onLongPress(book.id),
        );
      },
    );
  }
}

class _BookGrid extends StatelessWidget {
  const _BookGrid({required this.books, this.onLongPress});

  final List<Book> books;
  final void Function(String bookId)? onLongPress;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 180,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: books.length,
      itemBuilder: (context, index) {
        final book = books[index];
        return InkWell(
          onTap: () => _openBook(context, book),
          onLongPress:
              onLongPress == null ? null : () => onLongPress!(book.id),
          borderRadius: BorderRadius.circular(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: BookCover(url: book.coverUrl),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                book.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------- favorites tab

class _FavoritesTab extends ConsumerWidget {
  const _FavoritesTab({required this.onSearch});

  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favorites = ref.watch(favoritesProvider);
    final asGrid = ref.watch(libraryAsGridProvider).valueOrNull ?? false;

    return favorites.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: 'Could not load your favorites.',
        onRetry: () => ref.invalidate(favoritesProvider),
      ),
      data: (books) {
        if (books.isEmpty) {
          return const EmptyView(
            icon: Icons.bookmark_border,
            title: 'No favorites yet',
            subtitle: 'Bookmark a book from its track list to see it here.',
          );
        }
        if (asGrid) return _BookGrid(books: books);
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              leading: SizedBox(width: 48, child: BookCover(url: book.coverUrl)),
              title: Text(book.name),
              subtitle:
                  book.authors.isEmpty ? null : Text(book.authors.join(', ')),
              trailing: Icon(Icons.bookmark,
                  color: Theme.of(context).colorScheme.primary),
              onTap: () => _openBook(context, book),
            );
          },
        );
      },
    );
  }
}

// ------------------------------------------------------------ selectable library

class _SelectableLibrary extends ConsumerWidget {
  const _SelectableLibrary({required this.selected, required this.onToggle});

  final Set<String> selected;
  final void Function(String bookId) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    return library.when(
      loading: () => const LoadingView(),
      error: (e, _) => ErrorView(
        message: 'Could not load your library.',
        onRetry: () => ref.invalidate(libraryProvider),
      ),
      data: (books) {
        if (books.isEmpty) {
          return const EmptyView(
            icon: Icons.library_books_outlined,
            title: 'Your library is empty',
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: books.length,
          itemBuilder: (context, index) {
            final book = books[index];
            return CheckboxListTile(
              value: selected.contains(book.id),
              onChanged: (_) => onToggle(book.id),
              secondary: SizedBox(width: 48, child: BookCover(url: book.coverUrl)),
              title: Text(book.name),
              subtitle:
                  book.authors.isEmpty ? null : Text(book.authors.join(', ')),
            );
          },
        );
      },
    );
  }
}

void _openBook(BuildContext context, Book book) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => TrackList(book: book)),
  );
}

// ----------------------------------------------------------------------- drawer

class _HomeDrawer extends ConsumerWidget {
  const _HomeDrawer({required this.onManage});

  final VoidCallback onManage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asGrid = ref.watch(libraryAsGridProvider).valueOrNull ?? false;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
            ),
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Text(
                'Oshiro',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ),
          ListTile(
            leading: Icon(asGrid ? Icons.view_list : Icons.grid_view),
            title: Text(asGrid ? 'Show as list' : 'Show as grid'),
            onTap: () {
              ref.read(localStoreProvider).setLibraryAsGrid(!asGrid);
              Navigator.pop(context);
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('Manage / remove books'),
            onTap: () {
              Navigator.pop(context);
              onManage();
            },
          ),
        ],
      ),
    );
  }
}
