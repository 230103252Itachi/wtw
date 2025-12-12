import 'package:flutter/material.dart';
import '../models/outfit.dart';

class OutfitCard extends StatelessWidget {
  final Outfit outfit;
  final VoidCallback onSave;

  const OutfitCard({Key? key, required this.outfit, required this.onSave})
    : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    outfit.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _shareOutfit(context),
                  icon: const Icon(Icons.share),
                ),
                IconButton(
                  onPressed: onSave,
                  icon: const Icon(Icons.bookmark_border),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 120,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: outfit.items.length,
                itemBuilder: (context, i) {
                  final it = outfit.items[i];
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: it.imageWidget,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: () => _rate(context, true),
                  icon: const Icon(Icons.thumb_up),
                  label: const Text('Нравится'),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _rate(context, false),
                  icon: const Icon(Icons.thumb_down),
                  label: const Text('Не нравится'),
                ),
                const Spacer(),
                TextButton(onPressed: () {}, child: const Text('Refine')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _rate(BuildContext context, bool like) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(like ? 'Отмечено: Нравится' : 'Отмечено: Не нравится'),
      ),
    );
  }

  void _shareOutfit(BuildContext context) async {}
}
