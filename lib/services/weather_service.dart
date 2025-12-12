import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';

class WeatherService {
  final String apiKey = "89f5b788a0eaa39414f41f5145a9442c";

  Future<double?> getTemperatureByCoords(double lat, double lon) async {
    final url = Uri.parse(
      "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=$apiKey&lang=ru",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['main']['temp']?.toDouble();
    } else {
      return null;
    }
  }

  Future<String?> getWeatherDescription(double lat, double lon) async {
    final url = Uri.parse(
      "https://api.openweathermap.org/data/2.5/weather?lat=$lat&lon=$lon&units=metric&appid=$apiKey&lang=ru",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['weather'][0]['description'];
    } else {
      return null;
    }
  }

  /// 🔥 Новый метод — теперь HomeScreen НЕ сломается
  Future<String> currentSummary() async {
    // Проверка разрешений
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return "clear";

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return "clear";
    }
    if (permission == LocationPermission.deniedForever) return "clear";

    // Получаем текущие координаты
    final pos = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    final temp = await getTemperatureByCoords(pos.latitude, pos.longitude);
    final desc = await getWeatherDescription(pos.latitude, pos.longitude);

    if (temp == null || desc == null) return "clear";

    return "$desc, ${temp.toStringAsFixed(0)}°C";
  }

  Future<String?> getWeatherSummary() async {
    try {
      return await currentSummary();
    } catch (_) {
      return "clear";
    }
  }
}
