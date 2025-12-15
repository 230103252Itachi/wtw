// lib/services/ai_stylist_service.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/openai_key_store.dart';

class AIStylistService {
  AIStylistService();

  static const String _baseUrl = 'https://api.openai.com/v1/chat/completions';

  Future<String> _getApiKey() async {
    final key = await OpenAIKeyStore.getKey();
    if (key == null || key.isEmpty) {
      throw Exception('OpenAI API key not found.');
    }
    return key;
  }

  Future<Map<String, dynamic>> describeClothes(
    File imageFile, {
    String model = 'gpt-4o-mini',
  }) async {
    final apiKey = await _getApiKey();

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final dataUri = 'data:image/jpeg;base64,$base64Image';

    final messages = [
      {
        "role": "system",
        "content":
            "You are a precise fashion-item recognizer. Return ONLY valid JSON with keys: category, colors, material, style_tags, pattern, warmth, notes.",
      },
      {
        "role": "user",
        "content": [
          {
            "type": "image_url",
            "image_url": {"url": dataUri},
          },
          {
            "type": "text",
            "text":
                "Describe this clothing item briefly and return ONLY JSON object: {category, colors, material, style_tags, pattern, warmth, notes}.",
          },
        ],
      },
    ];

    final body = {
      "model": model,
      "messages": messages,
      "temperature": 0.0,
      "max_tokens": 300,
    };

    final resp = await http.post(
      Uri.parse(_baseUrl),
      headers: {
        "Authorization": "Bearer $apiKey",
        "Content-Type": "application/json",
      },
      body: jsonEncode(body),
    );

    debugPrint('[OpenAI] describe status=${resp.statusCode}');
    debugPrint(
      '[OpenAI] describe body (prefix)=${resp.body.substring(0, resp.body.length.clamp(0, 1200))}',
    );

    if (resp.statusCode != 200) {
      return {
        'status': 'error',
        'error':
            'OpenAI describeClothes error: ${resp.statusCode} ${resp.body}',
      };
    }

    final decoded = jsonDecode(resp.body);
    final content = decoded["choices"]?[0]?["message"]?["content"] as String?;
    if (content == null)
      return {
        'status': 'error',
        'error': 'Empty content from OpenAI',
        'raw': resp.body,
      };

    String cleaned = content.replaceAll(RegExp(r'```(?:json)?'), '').trim();
    final idx = cleaned.indexOf('{');
    if (idx > 0) cleaned = cleaned.substring(idx);

    try {
      final parsed = jsonDecode(cleaned);
      if (parsed is Map<String, dynamic>) {
        return {...parsed, 'status': 'done'};
      } else {
        return {'status': 'done', 'raw_parsed': parsed};
      }
    } catch (e) {
      return {'status': 'done', 'raw': cleaned};
    }
  }

  Future<Map<String, dynamic>> generateOutfitFromDescriptions({
    required List<Map<String, dynamic>> wardrobe,
    required String weather,
    required String occasion,
  }) async {
    final apiKey = await _getApiKey();

    final system = '''
You are an expert fashion stylist. 
Create the best matching outfit using the user's wardrobe items.

Wardrobe items come with:
- AI descriptions (category, color, material, warmth, notes)
- id (must be used in output)

Weather: $weather
Occasion: $occasion

Return STRICT JSON:
{
  "outfit_items": ["id1","id2"],
  "notes": "short text",
  "alternatives": [["id3"],["id4","id2"]]
}
''';

    final body = {
      "model": "gpt-4o-mini",
      "messages": [
        {"role": "system", "content": system},
        {"role": "user", "content": jsonEncode(wardrobe)},
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
      throw Exception("AI error ${resp.statusCode}: ${resp.body}");
    }

    final raw = jsonDecode(resp.body);
    String content = raw["choices"][0]["message"]["content"];

    content = content.replaceAll("```json", "").replaceAll("```", "");

    return jsonDecode(content);
  }
}
