import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'main_menu.dart'; 
import '../services/location_service.dart'; // <--- IMPORTAMOS EL SERVICIO DE GPS

class PedidosPendientesScreen extends StatefulWidget {
  final String repartidorId; 

  const PedidosPendientesScreen({super.key, required this.repartidorId});

  @override
  State<PedidosPendientesScreen> createState() => _PedidosPendientesScreenState();
}

class _PedidosPendientesScreenState extends State<PedidosPendientesScreen> {
  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  List<dynamic> pedidos = [];
  bool isLoading = true;
  
  // Instanciamos el servicio de localización
  final LocationService _locationService = LocationService();

  @override
  void initState() {
    super.initState();
    _cargarPedidos(); 
  }

  Future<void> _cargarPedidos() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final url = Uri.parse('$baseUrl/pedidos_disponibles');   
      final response = await http.get(url);

      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          pedidos = json.decode(response.body);
          isLoading = false;
        });
      } else {
        _mostrarMensaje('Error al cargar pedidos', Colors.red);
        setState(() => isLoading = false);
      }
    } catch (e) {
      if (!mounted) return;
      _mostrarMensaje('Error de conexión con el servidor', Colors.red);
      setState(() => isLoading = false);
    }
  }

  Future<void> _aceptarPedido(int pedidoId) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722))),
    );

    try {
      final url = Uri.parse('$baseUrl/aceptar_pedido/$pedidoId');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'repartidor_id': int.tryParse(widget.repartidorId) ?? 0, 
        }),
      );

      if (!mounted) return;
      Navigator.of(context).pop(); // Cerramos el cargando

      if (response.statusCode == 200) {
        _mostrarMensaje('¡Pedido aceptado! Iniciando ruta...', Colors.green);
        
        // --- ACTIVACIÓN DEL GPS EN TIEMPO REAL ---
        // Iniciamos el rastreo usando el ID del pedido recién aceptado
        _locationService.iniciarRastreo(pedidoId);
        
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (context) => const MainMenu()),
              (route) => false,
            );
          }
        });
      } else {
        final jsonResponse = json.decode(response.body);
        _mostrarMensaje(jsonResponse['mensaje'] ?? 'No se pudo aceptar', Colors.red);
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      _mostrarMensaje('Error de conexión', Colors.red);
    }
  }

  void _mostrarMensaje(String texto, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Bolsa de Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFFFF5722),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarPedidos)
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)))
          : pedidos.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _cargarPedidos,
                  color: const Color(0xFFFF5722),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(15),
                    itemCount: pedidos.length,
                    itemBuilder: (context, index) => _buildPedidoCard(pedidos[index]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.motorcycle, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 15),
          const Text(
            'No hay pedidos pendientes hoy',
            style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

 Widget _buildPedidoCard(Map pedido) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        // CAMBIO AQUÍ: Usamos withValues en vez de withOpacity
        color: const Color(0xFFFF5722).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFF5722).withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.location_on, color: Color(0xFFFF5722), size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  pedido['direccion'] ?? 'Dirección no especificada',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('A cobrar:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  Text(
                    '\$${pedido['total']}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.green),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () => _aceptarPedido(pedido['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 5,
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('ACEPTAR VIAJE', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }
  }