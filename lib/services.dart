import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class AppConstants {
  static const String apiUrl = "http://192.168.10.76:8000/remove-watermark";

  static const String appTitle = 'Watermark Remover Pro';
  static const String appSubtitle = 'Remove watermarks instantly';

  static const String successMessage = '✨ Watermark removed successfully!';
  static const String saveSuccessMessage = '✅ Saved to gallery!';
  static const String downloadSuccessMessage = '✅ Downloaded successfully!';
  static const String selectImageError = 'Please select an image first';
  static const String connectionError = 'Connection failed';
}

class ApiService {
  static Future<Uint8List?> removeWatermark(File imageFile) async {
    http.Client client = http.Client();

    try {
      print('═══════════════════════════════════════');
      print('🔗 Connecting to: ${AppConstants.apiUrl}');
      print('⏰ Timeout: 180 seconds (3 minutes)'); // ← Increased to 3 minutes

      // Get file size
      final fileSize = await imageFile.length();
      print('📦 Image size: ${(fileSize / 1024).toStringAsFixed(2)} KB');

      // Create multipart request
      var request = http.MultipartRequest(
        'POST',
        Uri.parse(AppConstants.apiUrl),
      );

      // Add file
      print('📤 Adding file to request...');
      request.files.add(
        await http.MultipartFile.fromPath(
          'image',
          imageFile.path,
        ),
      );

      print('🚀 Sending request...');
      print('⏳ Please be patient, this may take up to 3 minutes...');

      // Send with 3 minute timeout
      var streamedResponse = await client.send(request).timeout(
        Duration(seconds: 180), // ← 3 minutes
        onTimeout: () {
          print('❌ Timeout after 180 seconds');
          client.close();
          throw Exception('Request timeout after 3 minutes');
        },
      );

      print('📥 Response status: ${streamedResponse.statusCode}');

      if (streamedResponse.statusCode == 200) {
        print('✅ Got 200 response, reading body...');

        final responseBody = await streamedResponse.stream.bytesToString();
        print('📄 Response body length: ${responseBody.length} bytes');

        final jsonResponse = json.decode(responseBody);
        print('🔍 Parsed JSON, checking success...');

        if (jsonResponse['success'] == true) {
          final base64Image = jsonResponse['image'];
          print('🎨 Got base64, length: ${base64Image.length}');
          print('🔄 Decoding base64...');

          final imageBytes = base64.decode(base64Image);
          print('✅ Success! Image size: ${imageBytes.length} bytes');
          print('═══════════════════════════════════════');

          client.close();
          return imageBytes;
        } else {
          client.close();
          throw Exception('API returned success: false');
        }
      } else {
        client.close();
        throw Exception('HTTP ${streamedResponse.statusCode}');
      }

    } on SocketException catch (e) {
      client.close();
      print('═══════════════════════════════════════');
      print('❌ NETWORK ERROR:');
      print('   Type: SocketException');
      print('   Details: $e');
      print('═══════════════════════════════════════');
      print('💡 TROUBLESHOOTING:');
      print('   1. Is backend still running?');
      print('   2. Check: http://192.168.1.5:8000/health in browser');
      print('   3. Are phone & PC on same WiFi?');
      print('   4. Try disabling firewall temporarily');
      print('═══════════════════════════════════════');
      throw Exception('Network error - Cannot reach server at ${AppConstants.apiUrl}');

    } on TimeoutException catch (e) {
      client.close();
      print('❌ Timeout: $e');
      throw Exception('Connection timeout - Server not responding');

    } on http.ClientException catch (e) {
      client.close();
      print('❌ Client error: $e');
      throw Exception('Network error - Check connection');

    } catch (e) {
      client.close();
      print('❌ Unexpected error: $e');
      rethrow;
    }
  }
}

class TimeoutException implements Exception {
  final String message;
  TimeoutException(this.message);

  @override
  String toString() => message;
}