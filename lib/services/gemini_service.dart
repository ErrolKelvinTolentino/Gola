import 'dart:convert';
import 'package:http/http.dart' as http;

class GeminiService {
  // TODO: Replace with your NEW, SECURE API Key
  static const String apiKey = 'AIzaSyDswsyFeURmFBgHLhkPMQubaEfgND8ZXpE';

  // The model we are trying to use
  static const String model = 'gemini-2.5-flash';

  // Base URL
  static const String baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// --------------------------------------------------------------------------
  /// HELPER: Fetch and print available models to the console
  /// --------------------------------------------------------------------------
  Future<void> printAvailableModels() async {
    print("\n--- DIAGNOSTIC: CHECKING AVAILABLE MODELS ---");
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/models?key=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = data['models'] as List;

        print("Your API Key has access to these models:");
        for (var m in models) {
          // Only show models that can generate content
          if (m['supportedGenerationMethods'].contains('generateContent')) {
            print(" - ${m['name'].toString().replaceAll('models/', '')}");
          }
        }
      } else {
        print("❌ Could not list models. API Error: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Connection error while listing models: $e");
    }
    print("---------------------------------------------\n");
  }

  /// --------------------------------------------------------------------------
  /// MAIN FUNCTION: Generate Tasks
  /// --------------------------------------------------------------------------
  Future<List<String>> generateTasks({
    required String goalTitle,
    String? description,
  }) async {
    final endpoint = '$baseUrl/models/$model:generateContent';

    final prompt = '''
Break this goal into up to 10 short, clear, actionable tasks. Tasks must be a one time task only.
Each task must be something that can be checked off in a todo list.

Return ONLY a valid JSON array of strings. Do NOT use Markdown code blocks.

Goal: "$goalTitle"
Description: "${description ?? ''}"
''';

    try {
      final response = await http.post(
        Uri.parse('$endpoint?key=$apiKey'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "contents": [
            {
              "parts": [
                {"text": prompt}
              ]
            }
          ]
        }),
      );

      if (response.statusCode != 200) {
        // ERROR HAPPENED! Throw exception to trigger catch block
        throw Exception('API Error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body);

      if (data['candidates'] == null || (data['candidates'] as List).isEmpty) {
        throw Exception("AI returned no candidates.");
      }

      final content = data['candidates'][0]['content'];
      if (content == null ||
          content['parts'] == null ||
          (content['parts'] as List).isEmpty) {
        throw Exception("AI returned empty content.");
      }

      final rawText = content['parts'][0]['text'] as String;

      // Clean up Markdown
      final cleaned =
          rawText.replaceAll('```json', '').replaceAll('```', '').trim();

      final start = cleaned.indexOf('[');
      final end = cleaned.lastIndexOf(']');

      if (start == -1 || end == -1) {
        throw Exception("AI did not return valid JSON: $rawText");
      }

      final jsonString = cleaned.substring(start, end + 1);
      final List decoded = jsonDecode(jsonString);

      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      // -----------------------------------------------------------------------
      // AUTO-DIAGNOSE: If we fail, print the models immediately
      // -----------------------------------------------------------------------
      print("❌ GENERATION FAILED: $e");

      // Call the list function so you can see if the model exists
      await printAvailableModels();

      // Return the error message to the UI
      return ["Error: $e"];
    }
  }
}
