import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart'; // Añadido para poder usar debugPrint
import '../models/pedido_model.dart';

class ApiDeliveryService {
  // Pon aquí tu URL de Render
  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  Future<List<Pedido>> obtenerBolsas() async {
    final response = await http.get(Uri.parse('$baseUrl/pedidos_disponibles'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((pedido) => Pedido.fromJson(pedido)).toList();
    } else {
      throw Exception('Error al cargar las bolsas de pedidos');
    }
  }

  // ---> NUEVAS FUNCIONES DE MENSAJERÍA PARA EL DOMICILIARIO <---

  // 1. Obtener el historial de mensajes de un pedido
  static Future<List<dynamic>> obtenerMensajes(int pedidoId) async {
    final url = Uri.parse('$baseUrl/api/chat/$pedidoId');

    try {
      final response = await http.get(url);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("❌ ERROR AL CARGAR MENSAJES (Delivery): ${response.statusCode}");
        return [];
      }
    } catch (e) {
      debugPrint("❌ ERROR DE RED EN CHAT (Delivery): $e");
      return [];
    }
  }

  // 2. Enviar un mensaje rápido
  static Future<bool> enviarMensaje(int pedidoId, String remitenteTipo, String texto) async {
    final url = Uri.parse('$baseUrl/api/chat/enviar');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'pedido_id': pedidoId,
          'remitente_tipo': remitenteTipo, // Desde esta app siempre será 'domiciliario'
          'texto': texto,
        }),
      );

      if (response.statusCode == 200) {
        return true;
      } else {
        debugPrint("❌ ERROR AL ENVIAR MENSAJE (Delivery): ${response.body}");
        return false;
      }
    } catch (e) {
      debugPrint("❌ ERROR DE RED AL ENVIAR MENSAJE (Delivery): $e");
      return false;
    }
  }
}