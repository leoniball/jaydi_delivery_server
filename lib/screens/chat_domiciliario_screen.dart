import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_delivery_service.dart'; // Importamos tu API actualizada

class ChatDomiciliarioScreen extends StatefulWidget {
  final int pedidoId;
  final String estadoPedido; // Para saber si ya se entregó y bloquearlo

  const ChatDomiciliarioScreen({
    super.key, 
    required this.pedidoId, 
    required this.estadoPedido
  });

  @override
  State<ChatDomiciliarioScreen> createState() => _ChatDomiciliarioScreenState();
}

class _ChatDomiciliarioScreenState extends State<ChatDomiciliarioScreen> {
  List<dynamic> _mensajesReales = [];
  Timer? _timer;

  // ESTAS SON LAS RESPUESTAS EXACTAS QUE PEDISTE, OJO AHÍ:
  final List<String> _respuestasRapidas = [
    "Sí", 
    "No", 
    "Buenos días", 
    "Buenas tardes", 
    "Buenas noches",
    "Ok, está bien", 
    "¿Cómo está?", 
    "Por favor ubicación más específica",
    "Comunicarse con soporte técnico", 
    "Gracias", 
    "Hasta luego"
  ];

  @override
  void initState() {
    super.initState();
    // Solo inicia el radar de mensajes si el pedido no ha sido entregado
    if (widget.estadoPedido != 'entregado') {
      _cargarMensajes();
      _timer = Timer.periodic(const Duration(seconds: 3), (timer) => _cargarMensajes());
    } else {
      // Si ya se entregó, cargamos el historial una sola vez
      _cargarMensajes();
    }
  }

  @override
  void dispose() {
    _timer?.cancel(); // Apagamos el radar al salir de la pantalla
    super.dispose();
  }

  Future<void> _cargarMensajes() async {
    final mensajes = await ApiDeliveryService.obtenerMensajes(widget.pedidoId);
    if (mounted) {
      setState(() {
        _mensajesReales = mensajes;
      });
    }
  }

  Future<void> _enviarRespuesta(String texto) async {
    // El repartidor envía el mensaje con un solo toque
    bool exito = await ApiDeliveryService.enviarMensaje(
      widget.pedidoId, 
      'domiciliario', // El remitente siempre es el domiciliario aquí
      texto
    );

    if (exito) {
      _cargarMensajes(); // Refrescamos la pantalla para ver el mensaje enviado
    } else {
      debugPrint("Error al enviar la respuesta rápida");
    }
  }

  @override
  Widget build(BuildContext context) {
    bool chatCerrado = widget.estadoPedido == 'entregado';

    return Scaffold(
      appBar: AppBar(
        title: const Text("Chat con el Cliente"),
        backgroundColor: Colors.blue[800], // Color distinto para diferenciar del cliente (Naranja)
      ),
      body: Column(
        children: [
          // ZONA DE MENSAJES (HISTORIAL)
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(10),
              itemCount: _mensajesReales.length,
              itemBuilder: (context, index) {
                final msg = _mensajesReales[index];
                final soyYo = msg['remitente_tipo'] == 'domiciliario';
                
                return Align(
                  alignment: soyYo ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: soyYo ? Colors.blue[100] : Colors.grey[200],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(
                      msg['texto'] ?? '',
                      style: const TextStyle(fontSize: 15),
                    ),
                  ),
                );
              },
            ),
          ),
          
          // ZONA DE BOTONES (SIN TECLADO)
          if (chatCerrado)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Colors.red[100],
              child: const Text(
                "Pedido entregado. El chat está cerrado.",
                style: TextStyle(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
  color: Colors.white,
  boxShadow: [
    BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))
  ]
),
              height: 200, // Altura fija para el panel de botones
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, // Dos botones por fila
                  childAspectRatio: 3.5, // Botones alargados
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _respuestasRapidas.length,
                itemBuilder: (context, index) {
                  return ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[50],
                      foregroundColor: Colors.blue[900],
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    onPressed: () => _enviarRespuesta(_respuestasRapidas[index]),
                    child: Text(
                      _respuestasRapidas[index], 
                      textAlign: TextAlign.center, 
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                    ),
                  );
                },
              ),
            )
        ],
      ),
    );
  }
}