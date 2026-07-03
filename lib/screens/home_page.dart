import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/book.dart';
import '../providers/providers.dart';
import '../widgets/book_cover.dart';
import 'search.dart';
import 'track_list.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final favorites = ref.watch(favoritesProvider);

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Biblioteca'),
          centerTitle: true,
          actions: [
            IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const Search()),
              ),
            ),
          ],
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Todos'),
              Tab(icon: Icon(Icons.bookmark), text: 'Favoritos'),
            ],
          ),
        ),
        drawer: const _HomeDrawer(),
        body: TabBarView(
          children: [
            _BookList(
              books: library,
              emptyLabel: 'Sem livros na biblioteca.',
            ),
            _BookList(
              books: favorites,
              emptyLabel: 'Sem favoritos marcados.',
            ),
          ],
        ),
      ),
    );
  }
}

class _BookList extends StatelessWidget {
  const _BookList({required this.books, required this.emptyLabel});

  final AsyncValue<List<Book>> books;
  final String emptyLabel;

  @override
  Widget build(BuildContext context) {
    return books.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Erro ao carregar: $e')),
      data: (list) {
        if (list.isEmpty) return _Empty(label: emptyLabel);
        return ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final book = list[index];
            return ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
              leading: SizedBox(
                width: 48,
                child: BookCover(url: book.coverUrl),
              ),
              title: Text(book.name),
              trailing: const Icon(Icons.arrow_forward_ios,
                  color: Colors.red, size: 20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => TrackList(book: book)),
              ),
            );
          },
        );
      },
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          FilledButton.tonal(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const Search()),
            ),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
  }
}

class _HomeDrawer extends StatelessWidget {
  const _HomeDrawer();

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(child: Text('Conteúdo')),
          // TODO(phase-4): wire list/grid toggle and book removal.
          ListTile(
            leading: const Icon(Icons.list),
            title: const Text('Exibir em Lista'),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Excluir Livros'),
            onTap: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
