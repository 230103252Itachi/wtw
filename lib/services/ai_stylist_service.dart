import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../services/openai_key_store.dart';

class AIStylistService {
  AIStylistService();

  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> _getApiKey() async {
    final key = await OpenAIKeyStore.getKey();
    if (key == null || key.isEmpty) {
      throw Exception('API key tapylmadi');
    }
    return key;
  }

  Future<Map<String, dynamic>> describeClothes(
    File imageFile, {
    String model = 'gpt-4o-mini',
  }) async {
    final key = await _getApiKey();

    final imgBytes = await imageFile.readAsBytes();
    final base64Img = base64Encode(imgBytes);
    final imgUri = 'data:image/jpeg;base64,$base64Img';

    final msgs = [
      {
        "role": "system",
        "content": "Sen fashion tanycasy. Kiyim-kynamasy talday JSON qayt: category, colors, material, style_tags, pattern, warmth, notes.",
      },
      {
        "role": "user",
        "content": [
          {
            "type": "image_url",
            "image_url": {"url": imgUri},
          },
          {
            "type": "text",
            "text": "Bu kiyim-kynamasyndy talday JSON: {category, colors, material, style_tags, pattern, warmth, notes}.",
          },
        ],
      },
    ];

    final payload = {
      "model": model,
      "messages": msgs,
      "temperature": 0.0,
      "max_tokens": 300,
    };

    http.Response result;
    try {
      final connection = http.Client();
      result = await connection.post(
        Uri.parse(_baseUrl),
        headers: {
          "Authorization": "Bearer $key",
          "Content-Type": "application/json",
        },
        body: jsonEncode(payload),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw TimeoutException('API timeout');
        },
      );
      connection.close();
    } on TimeoutException catch (_) {
      return {
        'category': 'Unknown',
        'colors': ['neutral'],
        'material': 'Unknown',
        'style_tags': [],
        'pattern': 'Unknown',
        'warmth': 'Unknown',
        'notes': 'timeout',
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
      };
    }

    if (result.statusCode != 200) {
      return {
        'category': 'Unknown',
        'colors': ['neutral'],
        'material': 'Unknown',
        'style_tags': [],
        'pattern': 'Unknown',
        'warmth': 'Unknown',
        'notes': 'HTTP ${result.statusCode}',
      };
    }

    try {
      final resp = jsonDecode(result.body);
      final text = resp["choices"]?[0]?["message"]?["content"] as String?;
      
      if (text == null || text.isEmpty) {
        return {
          'category': 'Unknown',
          'colors': ['neutral'],
          'material': 'Unknown',
          'style_tags': [],
          'pattern': 'Unknown',
          'warmth': 'Unknown',
          'notes': 'empty',
        };
      }

      var clean = text.replaceAll(RegExp(r'```(?:json)?'), '').trim();
      final start = clean.indexOf('{');
      if (start > 0) clean = clean.substring(start);

      try {
        final data = jsonDecode(clean);
        if (data is Map<String, dynamic>) {
          return data;
        } else {
          return {
            'category': 'Unknown',
            'colors': ['neutral'],
            'material': 'Unknown',
            'style_tags': [],
            'pattern': 'Unknown',
            'warmth': 'Unknown',
            'notes': 'invalid format',
          };
        }
      } catch (e) {
        return {
          'category': 'Unknown',
          'colors': ['neutral'],
          'material': 'Unknown',
          'style_tags': [],
          'pattern': 'Unknown',
          'warmth': 'Unknown',
          'notes': 'json error',
        };
      }
    } catch (e) {
      return {
        'category': 'Unknown',
        'colors': ['neutral'],
        'material': 'Unknown',
        'style_tags': [],
        'pattern': 'Unknown',
        'warmth': 'Unknown',
        'notes': 'parse error',
      };
    }
  }

  Future<Map<String, dynamic>> generateOutfitFromDescriptions({
    required List<Map<String, dynamic>> garments,
    required String clima,
    required String event,
  }) async {
    final apiKey = await _getApiKey();

    final sys = '''
Sen kostumer stylisti. 
User kiyim-kynamalary ushyn eng jaqsy komplektty zhasay.

Kiyim-kynamalary:
- AI ta'rifly (category, color, material, warmth, notes)
- id (natyjese barylyryluy kerek)

Aua-raiyy: $clima
Shara: $event

JSON qayt:
{
  "outfit_items": ["id1","id2"],
  "notes": "text",
  "alternatives": [["id3"],["id4","id2"]]
}
''';

    final body = {
      "model": "gpt-4o-mini",
      "messages": [
        {"role": "system", "content": sys},
        {"role": "user", "content": jsonEncode(garments)},
      ],
      "temperature": 0.4,
      "max_tokens": 450,
    };

    final resp = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    if (resp.statusCode != 200) {
      throw Exception("API error: ${resp.statusCode}");
    }

    final rawData = jsonDecode(resp.body);
    var output = rawData["choices"][0]["message"]["content"];
    output = output.replaceAll("```json", "").replaceAll("```", "");

    return jsonDecode(output);
  }
}
