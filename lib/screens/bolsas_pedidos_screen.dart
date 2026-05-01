import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// --- MODELO DE DATOS ---
class Pedido {
  final int id;
  final String cliente; 
  final String direccion;
  final double total;

  Pedido({required this.id, required this.cliente, required this.direccion, required this.total});

  factory Pedido.fromJson(Map<String, dynamic> json) {
    return Pedido(
      id: json['id'],
      cliente: json['cliente'].toString(), 
      direccion: json['direccion'] ?? 'Sin dirección registrada',
      total: json['total'] != null ? double.parse(json['total'].toString()) : 0.0,
    );
  }
}

class BolsasPedidosScreen extends StatefulWidget {
  const BolsasPedidosScreen({super.key}); // <-- Soluciona el primer error

  @override
  State<BolsasPedidosScreen> createState() => _BolsasPedidosScreenState(); // <-- Soluciona el segundo error
}

class _BolsasPedidosScreenState extends State<BolsasPedidosScreen> {
  // ✅ URL de tu servidor en Render configurada
  final String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';
  
  List<Pedido> pedidos = [];
  bool isLoading = true;
  int miIdDeRepartidor = 0;

 @override
  void initState() {
    super.initState();
    cargarIdRepartidor(); // 👉 AGREGAS ESTA LÍNEA AQUÍ
    obtenerBolsas();
  }
 Future<void> cargarIdRepartidor() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      miIdDeRepartidor = prefs.getInt('repartidor_id') ?? 0;
    });
  }
 
  Future<void> obtenerBolsas() async {
    setState(() => isLoading = true);
    try {
      final response = await http.get(Uri.parse('$baseUrl/pedidos_disponibles'));

      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        setState(() {
          pedidos = data.map((item) => Pedido.fromJson(item)).toList();
          isLoading = false;
        });
      } else {
        mostrarMensaje('Servidor respondió con error');
        setState(() => isLoading = false);
      }
    } catch (e) {
      mostrarMensaje('No se pudo conectar con el servidor Jaydi');
      setState(() => isLoading = false);
    }
  }

 Future<void> aceptarPedido(int pedidoId) async {
    // 1. Validación de seguridad: si el ID es 0, no lo dejamos continuar
    if (miIdDeRepartidor == 0) {
      mostrarMensaje('Error: Sesión no detectada. Por favor, reinicia la app.');
      return;
    }

    try {
      // 2. Le mandamos el ID del pedido y TU ID REAL al backend en Render
      final response = await http.post(
        Uri.parse('$baseUrl/aceptar_pedido'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'pedido_id': pedidoId,
          'repartidor_id': miIdDeRepartidor // ✅ ¡Aquí ya usa tu ID real sacado de la memoria!
        }),
      );

      // 3. Si Render nos dice que todo salió bien (200)
      if (response.statusCode == 200) {
        mostrarMensaje('¡Bolsa asignada! El pedido ahora es tuyo.');
        obtenerBolsas(); // Recargamos la lista para que desaparezca esa bolsa
      } else {
        final error = json.decode(response.body);
        mostrarMensaje(error['error'] ?? 'No se pudo tomar el pedido');
      }
    } catch (e) {
      mostrarMensaje('Error de red al aceptar pedido');
    }
  }

  void mostrarMensaje(String mensaje) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(mensaje, style: const TextStyle(fontFamily: 'Montserrat')))
  );
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('Jaydi - Bolsas de Pedidos', 
    style: TextStyle(fontFamily: 'Montserrat', fontWeight: FontWeight.bold, color: Colors.white)),
  backgroundColor: Colors.black87,
  actions: [
    IconButton(
      icon: const Icon(Icons.refresh, color: Colors.white), 
      onPressed: obtenerBolsas
    )
  ],
),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.orange))
          : pedidos.isEmpty
              ? const Center(child: Text('No hay pedidos listos para entregar', 
                  style: TextStyle(fontFamily: 'Montserrat', color: Colors.grey)))
              : ListView.builder(
                  itemCount: pedidos.length,
                  itemBuilder: (context, index) {
                    final pedido = pedidos[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      elevation: 5,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                              Text('PEDIDO #${pedido.id}', 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Montserrat')),
                              const SizedBox(height: 5),
                              Text('Dirección: ${pedido.direccion}', 
                                style: const TextStyle(fontFamily: 'Montserrat', color: Colors.black54)),
                              const SizedBox(height: 10),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('\$${pedido.total.toStringAsFixed(2)}', 
                                    style: const TextStyle(fontSize: 20, color: Colors.green, fontWeight: FontWeight.bold)),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                                    onPressed: () => aceptarPedido(pedido.id),
                                    child: const Text('RECOGER BOLSA', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}