import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wtw/models/wardrobe_item.dart';
import 'package:wtw/models/wardrobe_model.dart';
import 'package:wtw/screens/view_item_screen.dart';

class WardrobeScreen extends StatefulWidget {
  const WardrobeScreen({super.key});

  @override
  State<WardrobeScreen> createState() => _WardrobeScreenState();
}

class _WardrobeScreenState extends State<WardrobeScreen> {
  String _search = '';
  String? _filterCategory;

  @override
  Widget build(BuildContext context) {
    final wardrobe = Provider.of<WardrobeModel>(context);
    final items = wardrobe.items.where((item) {
      final matchesSearch =
          _search.isEmpty ||
          item.title.toLowerCase().contains(_search.toLowerCase()) ||
          (item.imagePath.toLowerCase().contains(_search.toLowerCase()));
      final matchesCategory =
          _filterCategory == null ||
          _filterCategory == 'All' ||
          item.title == _filterCategory;
      return matchesSearch && matchesCategory;
    }).toList();

    final categories = <String>{'All'};
    categories.addAll(wardrobe.items.map((e) => e.title).toSet());

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Wardrobe',
          style: TextStyle(
            color: Color(0xFF4B4CFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 1,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {
              _showSearchDialog();
            },
          ),
          IconButton(
            icon: const Icon(Icons.bug_report),
            tooltip: 'Diagnostic',
            onPressed: () {
              final wardrobe = Provider.of<WardrobeModel>(context, listen: false);
              wardrobe.diagnosticCheckFirestore();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Check logs for diagnostic output')),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4B4CFF),
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.of(context).pushNamed('/addItem');
        },
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildFilterChips(categories.toList()),
            const SizedBox(height: 12),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.checkroom,
                            size: 56,
                            color: Color(0xFF4B4CFF),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'No items in wardrobe',
                            style: TextStyle(color: Color(0xFF4B4CFF)),
                          ),
                        ],
                      ),
                    )
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 0.72,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                          ),
                      itemCount: items.length,
                      itemBuilder: (ctx, index) {
                        final item = items[index];
                        return _buildItemCard(item, wardrobe);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips(List<String> categories) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: categories.map((c) {
          final selected =
              _filterCategory == c || (_filterCategory == null && c == 'All');
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: ChoiceChip(
              label: Text(
                c,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.black87,
                ),
              ),
              selected: selected,
              selectedColor: const Color(0xFF4B4CFF),
              backgroundColor: Colors.white,
              elevation: 2,
              onSelected: (_) {
                setState(() {
                  _filterCategory = c == 'All' ? null : c;
                });
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildItemCard(WardrobeItem item, WardrobeModel wardrobe) {
    String previewText() {
      try {
        // Try to get AI description from wardrobe item metadata
        if (item.metadata != null && item.metadata is Map) {
          final meta = Map<String, dynamic>.from(item.metadata);
          if (meta['notes'] != null && meta['notes'].toString().isNotEmpty) {
            final s = meta['notes'].toString();
            return s.length > 60 ? '${s.substring(0, 60)}…' : s;
          }
          if (meta['category'] != null) return 'Category: ${meta['category']}';
          if (meta['colors'] != null) return 'Colors: ${meta['colors']}';
          if (meta['style_tags'] != null && meta['style_tags'] is List) {
            return 'Style: ${(meta['style_tags'] as List).join(', ')}';
          }
          return 'AI processed';
        }
        return 'Pending AI analysis...';
      } catch (e) {
        return 'No description';
      }
    }

    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
          ),
          builder: (ctx) {
            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.6,
              minChildSize: 0.3,
              maxChildSize: 0.95,
              builder: (_, controller) {
                final metadata = item.metadata;
                return SingleChildScrollView(
                  controller: controller,
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Text(
                        'AI Information',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: SizedBox(
                          height: 220,
                          width: double.infinity,
                          child: item.imageWidget,
                        ),
                      ),
                      const SizedBox(height: 12),
                      if (metadata == null) ...[
                        const Text(
                          'AI analysis pending or not available yet.',
                        ),
                      ] else ...[
                        _buildDescriptionWidget(metadata),
                      ],
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          ElevatedButton.icon(
                            onPressed: () => Navigator.of(ctx).pop(),
                            icon: const Icon(Icons.close),
                            label: const Text('Close'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () {
                              Navigator.of(ctx).push(
                                MaterialPageRoute(
                                  builder: (_) => ViewItemScreen(itemArg: item),
                                ),
                              );
                            },
                            icon: const Icon(Icons.open_in_full),
                            label: const Text('Full Screen'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[200],
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
      onLongPress: () {
        _showItemOptions(item, wardrobe);
      },
      child: Card(
        color: Theme.of(context).cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: Colors.black12,
        child: Column(
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
                child: item.imageWidget,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Expanded(
                      child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          previewText(),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () async {
                      // Show confirmation dialog
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Delete Item?'),
                          content: const Text('This will delete the item from your wardrobe and Firebase.'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(ctx);
                                try {
                                  await wardrobe.removeItem(item);
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Item deleted')),
                                    );
                                  }
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Error: $e')),
                                    );
                                  }
                                }
                              },
                              child: const Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDescriptionWidget(dynamic cached) {
    try {
      if (cached == null) return const Text('No data');

      if (cached is String) {
        return Text(cached);
      }

      if (cached is Map) {
        final map = Map<String, dynamic>.from(cached);
        final rows = <Widget>[];

        void addRow(String title, dynamic value) {
          if (value == null) return;
          final text = value is List ? value.join(', ') : value.toString();
          if (text.trim().isEmpty) return;
          rows.add(
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 110,
                    child: Text(
                      '$title:',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Expanded(child: Text(text)),
                ],
              ),
            ),
          );
        }

        addRow('Category', map['category']);
        addRow('Colors', map['colors']);
        addRow('Material', map['material']);
        addRow('Style tags', map['style_tags']);
        addRow('Pattern', map['pattern']);
        addRow('Warmth', map['warmth']);
        addRow('Notes', map['notes'] ?? map['description']);

        if (rows.isEmpty) return Text(map.toString());
        return Column(children: rows);
      }

      return Text(cached.toString());
    } catch (e) {
      return Text('Error displaying description: $e');
    }
  }

  void _showItemOptions(WardrobeItem item, WardrobeModel wardrobe) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.open_in_full),
                  title: const Text('Open'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ViewItemScreen(itemArg: item),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete, color: Colors.redAccent),
                  title: const Text(
                    'Delete',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    // Show confirmation
                    showDialog(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        title: const Text('Delete Item?'),
                        content: const Text('This will delete the item from your wardrobe and Firebase.'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.pop(dialogCtx);
                              try {
                                await wardrobe.removeItem(item);
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Item deleted')),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Error: $e')),
                                  );
                                }
                              }
                            },
                            child: const Text(
                              'Delete',
                              style: TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        String temp = _search;
        return AlertDialog(
          title: const Text('Search Wardrobe'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Search by category or path',
            ),
            onChanged: (v) => temp = v,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() => _search = temp);
                Navigator.of(ctx).pop();
              },
              child: const Text('Search'),
            ),
          ],
        );
      },
    );
  }
}
