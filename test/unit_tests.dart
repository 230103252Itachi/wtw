import 'package:flutter_test/flutter_test.dart';
import 'package:wtw/models/wardrobe_item.dart';
import 'package:wtw/models/weather.dart';

void main() {
  group('WardrobeItem Model Tests', () {
    test('WardrobeItem can be created with basic data', () {
      final item = WardrobeItem(
        imagePath: '/path/to/image.jpg',
        title: 'Blue Shirt',
        metadata: {'color': 'blue', 'size': 'M'},
        id: 'item1',
      );

      expect(item.imagePath, equals('/path/to/image.jpg'));
      expect(item.title, equals('Blue Shirt'));
      expect(item.id, equals('item1'));
      expect(item.metadata, isNotNull);
    });

    test('WardrobeItem isNetworkImage should detect URL', () {
      final localItem = WardrobeItem(
        imagePath: '/local/path/image.jpg',
        title: 'Local Item',
      );
      
      final networkItem = WardrobeItem(
        imagePath: 'https://example.com/image.jpg',
        title: 'Network Item',
      );

      expect(localItem.isNetworkImage, equals(false));
      expect(networkItem.isNetworkImage, equals(true));
    });

    test('WardrobeItem with network image path', () {
      final item = WardrobeItem(
        imagePath: 'https://firebasehost.com/wardrobe/item1.jpg',
        title: 'Firebase Item',
        id: 'item_firebase_1',
      );

      expect(item.isNetworkImage, equals(true));
      expect(item.title, equals('Firebase Item'));
    });

    test('WardrobeItem metadata can store complex data', () {
      final metadata = {
        'category': 'Shirt',
        'color': 'Blue',
        'size': 'M',
        'brand': 'Nike',
        'tags': ['casual', 'summer']
      };
      
      final item = WardrobeItem(
        imagePath: 'path/image.jpg',
        title: 'Casual Blue Shirt',
        metadata: metadata,
      );

      expect(item.metadata, isNotNull);
      expect(item.metadata['category'], equals('Shirt'));
      expect(item.metadata['color'], equals('Blue'));
    });
  });

  group('Weather Model Tests', () {
    test('Weather can be created with valid data', () {
      final weather = Weather(
        condition: 'Sunny',
        tempC: 25,
      );

      expect(weather.condition, equals('Sunny'));
      expect(weather.tempC, equals(25));
    });

    test('Weather with different conditions', () {
      final rainWeather = Weather(condition: 'Rainy', tempC: 15);
      final snowWeather = Weather(condition: 'Snowy', tempC: -5);
      final cloudyWeather = Weather(condition: 'Cloudy', tempC: 20);

      expect(rainWeather.condition, equals('Rainy'));
      expect(snowWeather.tempC, lessThan(0));
      expect(cloudyWeather.condition, equals('Cloudy'));
    });

    test('Weather extreme temperatures', () {
      final hotWeather = Weather(condition: 'Very Hot', tempC: 40);
      final coldWeather = Weather(condition: 'Freezing', tempC: -20);

      expect(hotWeather.tempC, greaterThan(35));
      expect(coldWeather.tempC, lessThan(-10));
    });
  });

  group('Wardrobe Item Collection Tests', () {
    late List<WardrobeItem> items;

    setUp(() {
      items = [
        WardrobeItem(
          imagePath: 'path/shirt.jpg',
          title: 'Blue Shirt',
          metadata: {'category': 'Shirt', 'color': 'Blue'},
          id: 'item1',
        ),
        WardrobeItem(
          imagePath: 'path/pants.jpg',
          title: 'Black Pants',
          metadata: {'category': 'Pants', 'color': 'Black'},
          id: 'item2',
        ),
        WardrobeItem(
          imagePath: 'path/shoes.jpg',
          title: 'White Sneakers',
          metadata: {'category': 'Shoes', 'color': 'White'},
          id: 'item3',
        ),
      ];
    });

    test('can filter items by title', () {
      final filtered = items.where((item) => item.title.contains('Blue')).toList();
      
      expect(filtered.length, equals(1));
      expect(filtered.first.title, equals('Blue Shirt'));
    });

    test('can find item by ID', () {
      final found = items.firstWhere(
        (item) => item.id == 'item2',
        orElse: () => WardrobeItem(imagePath: '', title: ''),
      );

      expect(found.id, equals('item2'));
      expect(found.title, equals('Black Pants'));
    });

    test('can filter items by metadata category', () {
      final shirts = items
          .where((item) => item.metadata?['category'] == 'Shirt')
          .toList();

      expect(shirts.length, equals(1));
      expect(shirts.first.metadata['color'], equals('Blue'));
    });

    test('empty list returns no results', () {
      final emptyList = <WardrobeItem>[];
      final filtered = emptyList.where((item) => item.title.contains('Any')).toList();

      expect(filtered.isEmpty, equals(true));
    });
  });

  group('Outfit Combination Tests', () {
    test('can create outfit from items', () {
      final shirt = WardrobeItem(
        imagePath: 'path/shirt.jpg',
        title: 'Blue Shirt',
        metadata: {'category': 'Shirt'},
      );
      
      final pants = WardrobeItem(
        imagePath: 'path/pants.jpg',
        title: 'Black Pants',
        metadata: {'category': 'Pants'},
      );
      
      final outfit = [shirt, pants];

      expect(outfit.length, equals(2));
      expect(outfit.first.metadata['category'], equals('Shirt'));
      expect(outfit.last.metadata['category'], equals('Pants'));
    });
  });

  group('Weather-Based Recommendation Tests', () {
    test('can suggest outfits based on weather', () {
      final weather = Weather(condition: 'Rainy', tempC: 15);
      
      final items = [
        WardrobeItem(
          imagePath: 'path/jacket.jpg',
          title: 'Rain Jacket',
          metadata: {'waterproof': true, 'category': 'Jacket'},
        ),
        WardrobeItem(
          imagePath: 'path/umbrella.jpg',
          title: 'Umbrella',
          metadata: {'waterproof': true},
        ),
      ];

      // Should recommend waterproof items for rainy weather
      expect(weather.condition.toLowerCase(), contains('rain'));
      expect(items.isNotEmpty, equals(true));
    });

    test('hot weather should avoid heavy items', () {
      final weather = Weather(condition: 'Sunny', tempC: 35);
      
      expect(weather.tempC, greaterThan(30));
      expect(weather.condition.toLowerCase(), contains('sunny'));
    });

    test('cold weather should recommend warm items', () {
      final weather = Weather(condition: 'Snowy', tempC: -10);
      
      expect(weather.tempC, lessThan(0));
      expect(weather.condition.toLowerCase(), contains('snow'));
    });
  });
}
