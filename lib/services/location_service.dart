import 'dart:async';
import 'dart:convert';
import 'package:location/location.dart'; 
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class LocationService {
  // Asegúrate de usar tu URL real de Render
  static const String _baseUrl = 'https://jaydi-server.onrender.com/actualizar_ubicacion';
  
  Location location = Location();
  StreamSubscription<LocationData>? _locationSubscription;

  // Paso 1: Permisos y Configuración de Segundo Plano
  Future<bool> solicitarPermisos() async {
    bool serviceEnabled;
    PermissionStatus permissionGranted;

    serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return false;
    }

    permissionGranted = await location.hasPermission();
    if (permissionGranted == PermissionStatus.denied) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return false;
    }

    // --- MEJORA JAYDI: Habilitar servicio en segundo plano ---
    try {
      await location.enableBackgroundMode(enable: true);
    } catch (e) {
      debugPrint("Aviso: No se pudo activar modo segundo plano: $e");
    }

    return true;
  }

  // Paso 2: Iniciar el rastreo con alta precisión
  void iniciarRastreo(int idPedido) async {
    bool permisosOk = await solicitarPermisos();
    if (!permisosOk) return;

    // Configuración optimizada para consumo de batería y precisión
    await location.changeSettings(
      accuracy: LocationAccuracy.high,
      interval: 5000, // Cada 5 segundos para que la ruta azul sea fluida
      distanceFilter: 10, // Solo envía si se mueve más de 10 metros
    );

    // Activar notificación persistente (Requerido por Android)
    await location.changeNotificationOptions(
      title: 'Jaydi Express en camino',
      subtitle: 'Rastreando entrega del pedido #$idPedido',
      iconName: 'ic_launcher', // Asegúrate que este icono exista en res/drawable
      onTapBringToFront: true,
    );

    _locationSubscription = location.onLocationChanged.listen((LocationData currentData) {
      if (currentData.latitude != null && currentData.longitude != null) {
        _enviarAlServidor(idPedido, currentData.latitude!, currentData.longitude!);
      }
    });
  }

  // Paso 3: Enviar a Python (Línea 120 de tu app.py)
  Future<void> _enviarAlServidor(int idPedido, double lat, double lng) async {
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'id_pedido': idPedido,
          'latitud': lat,
          'longitud': lng,
        }),
      );
      if (response.statusCode == 200) {
        debugPrint("📡 GPS Jaydi -> Servidor: $lat, $lng");
      }
    } catch (e) {
      debugPrint("❌ Error de conexión Jaydi: $e");
    }
  }

  void detenerRastreo() {
    _locationSubscription?.cancel();
    _locationSubscription = null;
    location.enableBackgroundMode(enable: false);
  }
}