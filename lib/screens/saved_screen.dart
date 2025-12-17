// lib/screens/saved_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wtw/models/wardrobe_model.dart';
import 'package:wtw/models/outfit.dart';
import 'package:wtw/models/wardrobe_item.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  static const int maxThumbs = 4;

  @override
  Widget build(BuildContext context) {
    final wardrobe = Provider.of<WardrobeModel>(context);
    final saved = wardrobe.saved;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'Saved Outfits',
          style: TextStyle(
            color: Color(0xFF4B4CFF),
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 1,
      ),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: saved.isEmpty
            ? Center(
                child: Text(
                  'No saved outfits',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              )
            : ListView.separated(
                itemCount: saved.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (ctx, idx) {
                  final outfit = saved[idx];
                  // Resolve real WardrobeItem objects by keys (this uses your provider helper)
                  debugPrint('[SavedScreen] Loading outfit: ${outfit.title}');
                  debugPrint('[SavedScreen] outfit.itemKeys: ${outfit.itemKeys}');
                  final items = wardrobe.getItemsByKeys(outfit.itemKeys);
                  debugPrint('[SavedScreen] Resolved ${items.length} items for outfit');

                  return GestureDetector(
                    onTap: () => _openOutfitDetails(context, outfit, items),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black12.withOpacity(0.04),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          _StackedThumbs(items: items),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  outfit.title,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _formatDate(outfit.createdAtIso),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(fontSize: 13),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  outfit.notes.isNotEmpty
                                      ? outfit.notes
                                      : 'No notes',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style:
                                      Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () async {
                              await wardrobe.removeSavedById(outfit.id);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Outfit deleted')),
                              );
                            },
                            icon: Icon(
                              Icons.delete_outline,
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }

  static String _formatDate(String iso) {
    try {
      final dt = DateTime.parse(iso).toLocal();
      return "${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return iso;
    }
  }

  static void _openOutfitDetails(
    BuildContext context,
    Outfit outfit,
    List<WardrobeItem> items,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          maxChildSize: 0.95,
          initialChildSize: 0.7,
          minChildSize: 0.4,
          builder: (_, controller) {
            return SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    outfit.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatDate(outfit.createdAtIso),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  if (outfit.notes.isNotEmpty) ...[
                    Text(outfit.notes),
                    const SizedBox(height: 12),
                  ],
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: items.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.85,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                        ),
                    itemBuilder: (c, i) {
                      final it = items[i];
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: it.imagePath.isNotEmpty
                                  ? it.isNetworkImage
                                    ? Image.network(
                                        it.imagePath,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(color: Theme.of(context).dividerColor);
                                        },
                                      )
                                    : Image.file(
                                        File(it.imagePath),
                                        fit: BoxFit.cover,
                                      )
                                  : Container(color: Theme.of(context).dividerColor),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              it.title ?? 'Item',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _StackedThumbs extends StatelessWidget {
  final List<WardrobeItem> items;
  const _StackedThumbs({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    debugPrint('[StackedThumbs] Building with ${items.length} items');
    final maxShow = SavedScreen.maxThumbs;
    final show = items.length < maxShow ? items.length : maxShow;
    final thumbs = items.take(show).toList();

    const double thumbWidth = 56;
    const double thumbHeight = 72;
    const double overlap = 18;

    return SizedBox(
      width: thumbWidth + (thumbs.length - 1) * (thumbWidth - overlap),
      height: thumbHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: List.generate(thumbs.length, (i) {
          final left = i * (thumbWidth - overlap);
          final item = thumbs[thumbs.length - 1 - i];
          return Positioned(
            left: left,
            child: Material(
              elevation: 4 - i.toDouble(),
              borderRadius: BorderRadius.circular(10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                    width: thumbWidth,
                    height: thumbHeight,
                    child: item.imagePath.isNotEmpty
                      ? item.isNetworkImage
                        ? Image.network(
                            item.imagePath,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(color: Theme.of(context).dividerColor);
                            },
                          )
                        : Image.file(File(item.imagePath), fit: BoxFit.cover)
                      : Container(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
