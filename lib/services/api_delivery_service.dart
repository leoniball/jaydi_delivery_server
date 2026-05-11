import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/pedido_model.dart';

class ApiDeliveryService {
  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  // --- FUNCIÓN CORREGIDA: getPerfil ---
  // Cambiamos el nombre para que VS Code deje de marcar el error rojo en main.dart
  Future<Map<String, dynamic>?> getPerfil() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      
      // ERROR TÉCNICO CORREGIDO: 
      // En el Login guardamos el ID con setString, así que aquí debemos usar getString.
      String? userId = prefs.getString('userId'); 

      if (userId == null) {
        debugPrint("⚠️ No se encontró userId en SharedPreferences");
        return null;
      }

      // Usamos la ruta /api/perfil que definimos en app.py
      final url = Uri.parse('$baseUrl/api/perfil/$userId');
      final response = await http.get(url).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        // Sincronizamos el estatus real de la nube (aprobado/pendiente)
        if (data['status'] != null) {
          await prefs.setString('userStatus', data['status']);
          // También actualizamos el booleano por si acaso
          await prefs.setBool('es_verificado', data['es_verificado'] ?? false);
        }
        
        return data;
      } else {
        debugPrint("❌ ERROR AL OBTENER PERFIL: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ ERROR DE RED EN PERFIL: $e");
      return null;
    }
  }

  Future<List<Pedido>> obtenerBolsas() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/api/delivery/pedidos_disponibles'));

      if (response.statusCode == 200) {
        List jsonResponse = json.decode(response.body);
        return jsonResponse.map((pedido) => Pedido.fromJson(pedido)).toList();
      } else {
        throw Exception('Error al cargar pedidos: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // --- FUNCIONES DE MENSAJERÍA ---

  static Future<List<dynamic>> obtenerMensajes(int pedidoId) async {
    final url = Uri.parse('$baseUrl/api/chat/$pedidoId');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return [];
    } catch (e) {
      debugPrint("❌ ERROR DE RED EN CHAT: $e");
      return [];
    }
  }

  static Future<bool> enviarMensaje(int pedidoId, String remitenteTipo, String texto) async {
    final url = Uri.parse('$baseUrl/api/chat/enviar');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pedido_id': pedidoId,
          'remitente_tipo': remitenteTipo,
          'texto': texto,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      debugPrint("❌ ERROR AL ENVIAR MENSAJE: $e");
      return false;
    }
  }
}