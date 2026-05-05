import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/pedido_model.dart';

class ApiDeliveryService {
  // Pon aquí tu URL de Render
  static const String baseUrl = 'https://jaydi-server.onrender.com';

  Future<List<Pedido>> obtenerBolsas() async {
    final response = await http.get(Uri.parse('$baseUrl/pedidos_disponibles'));

    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((pedido) => Pedido.fromJson(pedido)).toList();
    } else {
      throw Exception('Error al cargar las bolsas de pedidos');
    }
  }
}