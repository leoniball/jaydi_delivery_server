import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class RutaScreen extends StatefulWidget {
  const RutaScreen({super.key});

  @override
  State<RutaScreen> createState() => _RutaScreenState();
}

class _RutaScreenState extends State<RutaScreen> {
  List viajes = [];
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _obtenerHistorial();
  }

  Future<void> _obtenerHistorial() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');

    if (userId != null) {
      try {
        // Llamamos a la nueva ruta que pusiste en app.py
        final response = await http.get(
          Uri.parse('https://jaydi-delivery-serverv.onrender.com/historial_viajes/$userId')
        );

        if (response.statusCode == 200) {
          if (mounted) {
            setState(() {
              viajes = json.decode(response.body);
              cargando = false;
            });
          }
        }
      } catch (e) {
        debugPrint("Error: $e");
        if (mounted) setState(() => cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Mi Ruta e Historial", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Banner de historial suave
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: const Color(0xFFFF5722).withValues(alpha: 0.05),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("HISTORIAL DE VIAJES", style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                Text("Repasa tus entregas completadas con éxito.", style: TextStyle(color: Colors.grey, fontSize: 13)),
              ],
            ),
          ),
          
          Expanded(
            child: cargando 
              ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)))
              : viajes.isEmpty 
                ? _buildEmptyState()
                : RefreshIndicator(
                    onRefresh: _obtenerHistorial,
                    color: const Color(0xFFFF5722),
                    child: ListView.builder(
                      padding: const EdgeInsets.all(15),
                      itemCount: viajes.length,
                      itemBuilder: (context, index) => _buildViajeCard(viajes[index]),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.motorcycle_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text("Aún no tienes viajes registrados.", style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildViajeCard(Map viaje) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(viaje['direccion'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(viaje['fecha'], style: const TextStyle(color: Colors.grey, fontSize: 12)),
              ],
            ),
          ),
          Text("\$${viaje['total']}", style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Color(0xFFFF5722))),
        ],
      ),
    );
  }
}