import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  String nombreUsuario = "Cargando...";
  String correoUsuario = "...";
  bool esVerificado = false;
  bool cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatosYVerificar();
  }

  Future<void> _cargarDatosYVerificar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Recuperamos los datos reales del almacenamiento local
    final String? idPersistido = prefs.getString('userId');
    final String? nombrePersistido = prefs.getString('nombre');
    final String? correoPersistido = prefs.getString('correo');

    if (mounted) {
      setState(() {
        nombreUsuario = nombrePersistido ?? "Usuario Jaydi";
        correoUsuario = correoPersistido ?? "Sin correo";
      });
    }

    if (idPersistido != null) {
      try {
        final url = "http://10.0.2.2:5000/verificar_estatus/$idPersistido";
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (mounted) {
            setState(() {
              esVerificado = data['es_verificado'] ?? false;
            });
          }
        }
      } catch (e) {
        debugPrint("Error de conexión: $e");
      }
    }
    
    if (mounted) {
      setState(() => cargando = false);
    }
  }

  Future<void> _cerrarSesion() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFFF5722))),
      );
    }

    final Color colorEstado = esVerificado ? Colors.green : Colors.red;
    final String textoEstado = esVerificado ? "🟢 Cuenta Verificada" : "🔴 Cuenta en Revisión";

    return Scaffold(
      appBar: AppBar(title: const Text("Mi Perfil Jaydi"), centerTitle: true, elevation: 0),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            const CircleAvatar(
              radius: 60,
              backgroundColor: Color(0x1AFF5722),
              child: Icon(Icons.person, size: 80, color: Color(0xFFFF5722)),
            ),
            const SizedBox(height: 20),
            Text(nombreUsuario, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(correoUsuario, style: const TextStyle(fontSize: 16, color: Colors.grey)),
            const SizedBox(height: 30),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorEstado.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: colorEstado, width: 2),
                ),
                child: Row(
                  children: [
                    Icon(esVerificado ? Icons.verified : Icons.info_outline, color: colorEstado),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(textoEstado, style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold)),
                          Text(esVerificado 
                            ? "Ya puedes aceptar pedidos y generar ingresos." 
                            : "Estamos revisando tus documentos. Te avisaremos pronto."),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ElevatedButton(
                onPressed: esVerificado ? () {} : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("EDITAR PERFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 15),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: OutlinedButton.icon(
                onPressed: () => _cerrarSesion(),
                icon: const Icon(Icons.logout),
                label: const Text("CERRAR SESIÓN", style: TextStyle(fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}