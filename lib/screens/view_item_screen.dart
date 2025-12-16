// lib/screens/view_item_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:wtw/models/wardrobe_item.dart';
import 'package:wtw/models/wardrobe_model.dart';

class ViewItemScreen extends StatefulWidget {
  final String? imagePathArg;
  final WardrobeItem? itemArg;

  const ViewItemScreen({Key? key, this.imagePathArg, this.itemArg})
    : super(key: key);

  @override
  State<ViewItemScreen> createState() => _ViewItemScreenState();
}

class _ViewItemScreenState extends State<ViewItemScreen> {
  @override
  Widget build(BuildContext context) {
    final routeArg = ModalRoute.of(context)?.settings.arguments;
    WardrobeItem? item = widget.itemArg;
    String? imagePath = widget.imagePathArg;

    if (routeArg != null) {
      if (routeArg is WardrobeItem) {
        item = routeArg;
        imagePath = routeArg.imagePath;
      } else if (routeArg is String) {
        imagePath = routeArg;
      }
    }

    imagePath ??= '';

    final wardrobe = Provider.of<WardrobeModel?>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (wardrobe != null && item != null)
            IconButton(
              icon: const Icon(Icons.delete_forever, color: Colors.white),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Delete Item?'),
                    content: const Text('This will delete the item from your wardrobe, Firebase Storage, and Firestore.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(ctx).pop(true),
                        child: Text(
                          'Delete',
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                );
                if (ok == true) {
                  try {
                    await wardrobe.removeItem(item!);
                    if (mounted && Navigator.canPop(context)) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Item deleted')),
                      );
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Error: $e')),
                      );
                    }
                  }
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: imagePath.isEmpty
              ? _buildNotFound()
              : Hero(
                  tag: imagePath,
                  child: InteractiveViewer(
                    panEnabled: true,
                    minScale: 0.5,
                    maxScale: 4.0,
                    child: FutureBuilder<bool>(
                      future: File(imagePath).exists(),
                      builder: (ctx, snap) {
                        if (snap.connectionState != ConnectionState.done) {
                          return const SizedBox(
                            width: 80,
                            height: 80,
                            child: CircularProgressIndicator(),
                          );
                        }
                        final exists = snap.data == true;
                        if (exists) {
                          return Image.file(
                            File(imagePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (c, e, st) => _buildNotFound(),
                          );
                        }
                        return _buildNotFound(
                          message: 'Image not found\nPath: $imagePath',
                        );
                      },
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildNotFound({String? message}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image, size: 80, color: Colors.white24),
          const SizedBox(height: 12),
          Text(
            message ?? 'Image not found',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
}
