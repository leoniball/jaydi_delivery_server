import 'dart:convert'; // Para jsonDecode
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'verificacion_documentos_screen.dart';
import 'pedidos_pendientes.dart'; // Importamos tu nueva pantalla real

class HomeRepartidor extends StatefulWidget {
  const HomeRepartidor({super.key});

  @override
  State<HomeRepartidor> createState() => _HomeRepartidorState();
}

class _HomeRepartidorState extends State<HomeRepartidor> {
  bool isOnline = false;
  bool esVerificado = false; 
  String nombreUsuario = "Leandro"; 
  String? userId; // ID dinámico recuperado de la sesión
  bool cargandoEstatus = true;

  @override
  void initState() {
    super.initState();
    _inicializarDatos();
  }

  // Carga datos de sesión y luego pregunta al servidor el estatus
  Future<void> _inicializarDatos() async {
    await _cargarDatosUsuario();
    await _verificarEstatusServidor();
  }

  Future<void> _cargarDatosUsuario() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      nombreUsuario = prefs.getString('nombre') ?? "Leandro";
      userId = prefs.getString('userId') ?? "1"; // Ajustado para pruebas
    });
  }

  // --- FUNCIÓN: CONSULTA A NEON VÍA FLASK CON NOTIFICACIÓN ---
  Future<void> _verificarEstatusServidor() async {
    if (userId == null) await _cargarDatosUsuario();
    
    // AQUÍ ESTÁ LA MAGIA: Conectado a tu servidor real en la nube
    final String url = "https://jaydi-delivery-serverv.onrender.com/verificar_estatus/$userId";

    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        bool nuevoEstatus = data['es_verificado'] ?? false;

        if (nuevoEstatus == true && esVerificado == false && !cargandoEstatus) {
          _mostrarNotificacionExito();
        }

        setState(() {
          esVerificado = nuevoEstatus;
          cargandoEstatus = false;
        });
      }
    } catch (e) {
      debugPrint("Error de conexión: $e");
      setState(() => cargandoEstatus = false);
    }
  }

  // --- FUNCIÓN DE CIERRE DE SESIÓN ---
  Future<void> _cerrarSesion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear(); // Borra la sesión
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  // --- WIDGET: SNACKBAR DE ÉXITO ---
  void _mostrarNotificacionExito() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                "¡Felicidades! Tu cuenta ha sido verificada.",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _mostrarAvisoVerificacion() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Color(0xFFFF5722)),
            SizedBox(width: 10),
            Text("Cuenta en Revisión"),
          ],
        ),
        content: const Text(
          "Para activar tu cuenta en Jaydi Express, primero debes subir tus documentos de identidad y de tránsito.",
          style: TextStyle(fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const VerificacionDocumentosScreen(),
                ),
              );
            },
            child: const Text(
              "SUBIR AHORA", 
              style: TextStyle(color: Color(0xFFFF5722), fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("LUEGO", style: TextStyle(color: Colors.grey)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text(
          'JAYDI DELIVERY',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.logout, color: Colors.redAccent),
          onPressed: _cerrarSesion,
          tooltip: "Cerrar Sesión",
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.orange),
            onPressed: _verificarEstatusServidor,
          )
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _verificarEstatusServidor,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 25),
              
              Text(
                "¡Hola, $nombreUsuario!",
                style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 5),
              
              cargandoEstatus 
              ? const LinearProgressIndicator() 
              : Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 12,
                    color: !esVerificado ? Colors.orange : (isOnline ? Colors.green : Colors.red),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    !esVerificado 
                      ? "Esperando verificación de documentos" 
                      : (isOnline ? "Conectado y buscando pedidos" : "Desconectado"),
                    style: TextStyle(
                      fontSize: 16,
                      color: !esVerificado ? Colors.orange[800] : (isOnline ? Colors.green[700] : Colors.red[700]),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 35),

              if (!esVerificado) _buildAvisoPendiente(),

              // --- SECCIÓN ACTUALIZADA A LA PANTALLA REAL ---
              if (isOnline && esVerificado) ...[
                const Text(
                  "Zona de Trabajo Activa",
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 15),
                _buildBolsaPedidosButton(),
              ] else if (esVerificado)
                _buildOfflineState()
              else
                const SizedBox.shrink(), 
              
              const SizedBox(height: 100), // Espacio para que el FloatingActionButton no tape contenido
            ],
          ),
        ),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          if (esVerificado) {
            setState(() {
              isOnline = !isOnline;
            });
          } else {
            _mostrarAvisoVerificacion();
          }
        },
        label: Text(!esVerificado ? "VERIFICAR CUENTA" : (isOnline ? "SALIR DE LÍNEA" : "PONERSE EN LÍNEA")),
        icon: Icon(!esVerificado ? Icons.upload_file : (isOnline ? Icons.power_off : Icons.power_settings_new)),
        backgroundColor: !esVerificado ? Colors.orange : (isOnline ? Colors.redAccent : const Color(0xFFFF5722)),
        foregroundColor: Colors.white,
      ),
    );
  }

  Widget _buildAvisoPendiente() {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const VerificacionDocumentosScreen()),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
        ),
        child: const Column(
          children: [
            Icon(Icons.hourglass_empty, color: Colors.orange, size: 40),
            SizedBox(height: 10),
            Text(
              "Tu documentación está pendiente. Toca aquí para subir tus archivos o desliza hacia abajo para actualizar.",
              textAlign: TextAlign.center,
              style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
            )
          ],
        ),
      ),
    );
  }

  // --- BOTÓN REAL QUE LLEVA A LA BOLSA DE PEDIDOS ---
  Widget _buildBolsaPedidosButton() {
    return InkWell(
      onTap: () {
        // Navega a la pantalla real pasando el ID del repartidor
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PedidosPendientesScreen(repartidorId: userId ?? "0"),
          ),
        );
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFF5722), Color(0xFFFF8A65)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF5722).withValues(alpha: 0.3),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: const Column(
          children: [
            Icon(Icons.map_rounded, color: Colors.white, size: 50),
            SizedBox(height: 10),
            Text(
              "VER BOLSA DE PEDIDOS",
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: 1,
              ),
            ),
            SizedBox(height: 5),
            Text(
              "Toca aquí para ver pedidos cercanos",
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),
          Icon(Icons.location_off_rounded, size: 100, color: Colors.grey[300]),
          const SizedBox(height: 20),
          const Text(
            "No estás recibiendo pedidos",
            style: TextStyle(color: Colors.grey, fontSize: 16),
          ),
        ],
      ),
    );
  }
}