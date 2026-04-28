import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class PedidosPendientesScreen extends StatefulWidget {
  final String repartidorId; 

  // SOLUCIÓN 1: Uso de 'super.key'
  const PedidosPendientesScreen({super.key, required this.repartidorId});

  @override
  // SOLUCIÓN 2: Tipo de retorno público 'State<T>'
  State<PedidosPendientesScreen> createState() => _PedidosPendientesScreenState();
}

class _PedidosPendientesScreenState extends State<PedidosPendientesScreen> {
  // CENTRALIZAMOS TU URL DE RENDER AQUÍ
  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  List<dynamic> pedidos = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarPedidos(); 
  }

  Future<void> _cargarPedidos() async {
    setState(() {
      isLoading = true;
    });

    try {
      final url = Uri.parse('$baseUrl/pedidos_pendientes');   
      final response = await http.get(url);

      // SOLUCIÓN 3: Verificar que la pantalla sigue existiendo después del await
      if (!mounted) return;

      if (response.statusCode == 200) {
        setState(() {
          pedidos = json.decode(response.body);
          isLoading = false;
        });
      } else {
        _mostrarMensaje('Error al cargar pedidos: ${response.statusCode}', Colors.red);
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
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final url = Uri.parse('$baseUrl/aceptar_pedido');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'pedido_id': pedidoId,
          'repartidor_id': int.tryParse(widget.repartidorId) ?? 0, 
        }),
      );

      // SOLUCIÓN 3: Verificar montado antes de usar el context para cerrar el diálogo
      if (!mounted) return;
      Navigator.of(context).pop();

      final jsonResponse = json.decode(response.body);

      if (response.statusCode == 200) {
        _mostrarMensaje(jsonResponse['message'] ?? '¡Pedido aceptado!', Colors.green);
        _cargarPedidos(); 
      } else {
        _mostrarMensaje(jsonResponse['error'] ?? 'No se pudo aceptar', Colors.red);
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
        content: Text(texto, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: color,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Bolsa de Pedidos', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarPedidos,
          )
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
          : pedidos.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.motorcycle, size: 80, color: Colors.grey),
                      SizedBox(height: 15),
                      Text(
                        'No hay pedidos pendientes',
                        style: TextStyle(fontSize: 18, color: Colors.grey, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: pedidos.length,
                  itemBuilder: (context, index) {
                    final pedido = pedidos[index];
                    
                    return Card(
                      elevation: 4,
                      margin: const EdgeInsets.only(bottom: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(15),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.location_on, color: Colors.redAccent, size: 28),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    pedido['direccion_entrega'] ?? 'Dirección no especificada',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ],
                            ),
                            const Padding(
                              padding: EdgeInsets.symmetric(vertical: 10),
                              child: Divider(thickness: 1.5),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('A cobrar:', style: TextStyle(color: Colors.grey, fontSize: 14)),
                                    Text(
                                      '\$${pedido['total']}',
                                      style: const TextStyle(
                                        fontSize: 22, 
                                        fontWeight: FontWeight.w900, 
                                        color: Colors.green
                                      ),
                                    ),
                                  ],
                                ),
                                ElevatedButton.icon(
                                  onPressed: () => _aceptarPedido(pedido['id']),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueAccent,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                  icon: const Icon(Icons.check_circle, size: 22),
                                  label: const Text('ACEPTAR VIAJE', style: TextStyle(fontWeight: FontWeight.bold)),
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