import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:wtw/models/wardrobe_model.dart';
import 'package:wtw/services/weather_service.dart';
import 'package:wtw/services/location_service.dart';
import 'package:wtw/utils/clothes_recommendation.dart';
import 'package:wtw/screens/saved_screen.dart';
import 'package:wtw/services/ai_stylist_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  double? temperature;
  String? recommendation;
  String? weatherDescription;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    loadWeather();
  }

  Future<void> loadWeather() async {
    setState(() {
      isLoading = true;
      error = null;
    });

    try {
      final locationService = LocationService();
      final position = await locationService.getCurrentLocation();

      if (position == null) {
        setState(() {
          error = "Unable to get location";
          isLoading = false;
        });
        return;
      }

      final weatherService = WeatherService();
      double? temp = await weatherService.getTemperatureByCoords(
        position.latitude,
        position.longitude,
      );

      String? condition;
      try {
        condition = await weatherService.getWeatherDescription(
          position.latitude,
          position.longitude,
        );
      } catch (_) {
        try {
          condition = await weatherService.currentSummary();
        } catch (_) {
          condition = null;
        }
      }

      if (temp != null) {
        setState(() {
          temperature = temp;
          recommendation = getClothesRecommendation(temp!);
          weatherDescription = condition;
          isLoading = false;
        });
      } else {
        // Try to parse from currentSummary fallback
        try {
          final summary = await weatherService.currentSummary();
          final parts = summary.split(',');
          if (parts.isNotEmpty) {
            condition = parts[0].trim();
            if (parts.length > 1) {
              final t = parts[1].trim().replaceAll('°C', '').trim();
              temp = double.tryParse(t);
            }
          }
        } catch (_) {}

        if (temp != null) {
          setState(() {
            temperature = temp;
            recommendation = getClothesRecommendation(temp!);
            weatherDescription = condition;
            isLoading = false;
          });
        } else {
          setState(() {
            error = "Unable to get temperature";
            isLoading = false;
          });
        }
      }
    } catch (e) {
      setState(() {
        error = "Error: $e";
        isLoading = false;
      });
    }
  }

  Widget _buildWeatherCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7B8CFF), Color(0xFFB9C7FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.25),
              shape: BoxShape.circle,
            ),
            padding: const EdgeInsets.all(14),
            child: const Icon(Icons.cloud, size: 40, color: Colors.white),
          ),
          const SizedBox(width: 18),
          Flexible(
            child: isLoading
                ? const Text(
                    "Loading weather...",
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  )
                : error != null
                ? Text(
                    error!,
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${temperature?.toStringAsFixed(1) ?? '--'}°C',
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(
                              Icons.refresh,
                              color: Colors.white,
                              size: 28,
                            ),
                            onPressed: () async {
                              setState(() {
                                isLoading = true;
                              });
                              await loadWeather();
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        weatherDescription ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        recommendation ?? '',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildStyleSelector(BuildContext context, WardrobeModel wardrobe) {
    final styles = ['Casual', 'Sporty', 'Formal', 'Party'];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: styles.map((style) {
        final isSelected = wardrobe.selectedStyle == style;
        return GestureDetector(
          onTap: () => wardrobe.selectStyle(style),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF4B4CFF) : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF4B4CFF)
                    : Colors.grey.shade300,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(
                    color: Colors.indigo.withOpacity(0.25),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
              ],
            ),
            child: Text(
              style,
              style: TextStyle(
                fontFamily: 'Poppins',
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _roundedButton({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    bool filled = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          color: filled ? const Color(0xFF4B4CFF) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: filled ? Colors.transparent : const Color(0xFF4B4CFF),
          ),
          boxShadow: [
            if (filled)
              BoxShadow(
                color: Colors.black12.withOpacity(0.05),
                blurRadius: 6,
                offset: const Offset(0, 3),
              ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: filled ? Colors.white : const Color(0xFF4B4CFF)),
            const SizedBox(width: 8),
            Text(
              text,
              style: TextStyle(
                color: filled ? Colors.white : const Color(0xFF4B4CFF),
                fontWeight: FontWeight.w600,
                fontFamily: 'Poppins',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Column(
      children: [
        _roundedButton(
          icon: Icons.auto_awesome,
          text: 'Generate Outfits',
          onTap: () async {
            final wardrobe = Provider.of<WardrobeModel>(context, listen: false);
            final ai = AIStylistService();

            debugPrint('[Home] Generate Outfit button tapped');
            debugPrint('[Home] Wardrobe items count: ${wardrobe.items.length}');

            if (wardrobe.items.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Wardrobe is empty. Add items!')),
              );
              return;
            }

            setState(() => isLoading = true);

            try {
              List<Map<String, dynamic>> itemsForAI = [];

              for (var item in wardrobe.items) {
                // Use metadata from Firestore
                final metadata = item.metadata ?? {};
                
                debugPrint('[Home] Adding item to outfit generation: id=${item.id}, title=${item.title}');
                
                itemsForAI.add({
                  'id': item.id ?? 'unknown',
                  'path': item.imagePath,
                  'category': metadata['category'] ?? 'unknown',
                  'colors': metadata['colors'] ?? ['neutral'],
                  'material': metadata['material'] ?? 'fabric',
                  'style_tags': metadata['style_tags'] ?? [],
                  'pattern': metadata['pattern'] ?? 'solid',
                  'warmth': metadata['warmth'] ?? 'moderate',
                  'notes': metadata['notes'] ?? item.title,
                });
              }

              debugPrint('[Home] Total items prepared for AI: ${itemsForAI.length}');

              if (itemsForAI.isEmpty) {
                setState(() => isLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('No items in wardrobe. Add some items first.'),
                  ),
                );
                return;
              }

              final style = wardrobe.selectedStyle.toLowerCase() ?? 'casual';

              final w = await WeatherService().getWeatherSummary();
              final weatherString = w ?? 'clear';

              final suggestion = await ai.generateOutfitFromDescriptions(
                wardrobe: itemsForAI,
                weather: weatherString,
                occasion: style,
              );

              debugPrint('[Home] AI suggestion: $suggestion');

              final List<String> selectedIds =
                  (suggestion['outfit_items'] as List?)
                      ?.map((e) => e.toString())
                      .toList() ??
                  [];
              
              debugPrint('[Home] Selected IDs from AI: $selectedIds');

              final selectedItems = wardrobe.items.where((item) {
                return selectedIds.contains(item.id ?? '');
              }).toList();

              debugPrint('[Home] Matched items from wardrobe: ${selectedItems.length}');

              final notes = suggestion['notes'] ?? 'No explanation';

              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('AI Stylist Recommendation'),
                  content: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(notes ?? 'No explanation'),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: selectedItems
                              .map(
                                (it) => SizedBox(
                                  width: 72,
                                  height: 96,
                                  child: it.imageWidget,
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    TextButton(
                      onPressed: () async {
                        try {
                          final wardrobeModel = Provider.of<WardrobeModel>(
                            context,
                            listen: false,
                          );
                          final itemKeys = selectedItems
                              .map((i) => i.id ?? '')
                              .toList();

                          await wardrobeModel.saveOutfit(
                            title:
                                'AI suggestion • ${DateTime.now().toLocal().toString().split('.')[0]}',
                            itemKeys: itemKeys,
                            notes: notes ?? '',
                          );

                          if (mounted) {
                            Navigator.of(context).pop();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Outfit saved')),
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
                      child: const Text('Save'),
                    ),
                  ],
                ),
              );
            } catch (e) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('Error: $e')));
            } finally {
              if (mounted) setState(() => isLoading = false);
            }
          },
          filled: true,
        ),
        const SizedBox(height: 12),
        _roundedButton(
          icon: Icons.bookmark_border,
          text: 'Saved',
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SavedScreen()),
            );
          },
          filled: false,
        ),
      ],
    );
  }

  Widget _buildRecommendationSection(
    BuildContext context,
    WardrobeModel wardrobe,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black12.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommendations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              fontFamily: 'Poppins',
              color: Color(0xFF4B4CFF),
            ),
          ),
          const SizedBox(height: 12),
          if (wardrobe.items.isEmpty)
            const Text(
              'Add items to your wardrobe and select a style.',
              style: TextStyle(
                fontSize: 15,
                color: Colors.black54,
                fontFamily: 'Poppins',
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: wardrobe.items.length,
              itemBuilder: (context, index) {
                final item = wardrobe.items[index];
                return Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 1.5,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  child: ListTile(
                    leading: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 50,
                        height: 50,
                        child: item.imageWidget,
                      ),
                    ),
                    title: Text(
                      item.title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontFamily: 'Poppins',
                      ),
                    ),
                    subtitle: const Text(
                      'Perfect for your weather!',
                      style: TextStyle(fontFamily: 'Poppins'),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final wardrobe = Provider.of<WardrobeModel>(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        elevation: 2,
        centerTitle: true,
        title: const Text(
          'WhatToWear',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontWeight: FontWeight.w600,
            color: Color(0xFF4B4CFF),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _buildWeatherCard(),
              const SizedBox(height: 24),
              _buildStyleSelector(context, wardrobe),
              const SizedBox(height: 24),
              _buildActionButtons(context),
              const SizedBox(height: 32),
              _buildRecommendationSection(context, wardrobe),
            ],
          ),
        ),
      ),
    );
  }
}
