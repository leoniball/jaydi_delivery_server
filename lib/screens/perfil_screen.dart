import 'dart:convert';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; 
import 'editar_perfil_screen.dart'; // Importación vital para que el botón funcione

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  // Variables Originales
  String nombreUsuario = "Cargando...";
  String correoUsuario = "...";
  bool esVerificado = false;
  bool cargando = true;

  // --- NUEVAS VARIABLES DE PERFIL ---
  String? userId; 
  String telefono = "Sin registrar";
  String vehiculo = "Sin registrar";
  String placa = "Sin registrar";
  int viajesCompletados = 0;
  double saldo = 0.0;
  String? fotoPerfilBase64;

  @override
  void initState() {
    super.initState();
    _cargarDatosYVerificar();
  }

  Future<void> _cargarDatosYVerificar() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    
    final String? idPersistido = prefs.getString('userId');
    final String? nombrePersistido = prefs.getString('nombre');
    final String? correoPersistido = prefs.getString('correo');

    if (mounted) {
      setState(() {
        userId = idPersistido; 
        nombreUsuario = nombrePersistido ?? "Usuario Jaydi";
        correoUsuario = correoPersistido ?? "Sin correo";
      });
    }

    if (idPersistido != null) {
      try {
        // 1. Verificar Estatus
        final urlVerificar = "https://jaydi-server.onrender.com/verificar_estatus/$idPersistido";
        final responseVerificar = await http.get(Uri.parse(urlVerificar));
        
        if (responseVerificar.statusCode == 200) {
          final data = jsonDecode(responseVerificar.body);
          if (mounted) {
            setState(() {
              esVerificado = data['verificado'] ?? false; 
            });
          }
        }

        // 2. Traer Estadísticas y Foto
        final urlPerfil = "https://jaydi-server.onrender.com/perfil/$idPersistido";
        final responsePerfil = await http.get(Uri.parse(urlPerfil));

        if (responsePerfil.statusCode == 200) {
          final dataPerfil = jsonDecode(responsePerfil.body);
          if (mounted) {
            setState(() {
              telefono = dataPerfil['telefono'] ?? "Sin registrar";
              vehiculo = (dataPerfil['vehiculo'] == null || dataPerfil['vehiculo'] == "") ? "Sin registrar" : dataPerfil['vehiculo'];
              placa = (dataPerfil['placa'] == null || dataPerfil['placa'] == "") ? "Sin registrar" : dataPerfil['placa'];
              viajesCompletados = dataPerfil['viajes_completados'] ?? 0;
              saldo = (dataPerfil['saldo'] ?? 0.0).toDouble();
              fotoPerfilBase64 = (dataPerfil['foto_perfil'] != null && dataPerfil['foto_perfil'] != "") ? dataPerfil['foto_perfil'] : null;
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

  Future<void> _cambiarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 50);

    if (image != null && userId != null) {
      if (!mounted) return; 
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722))),
      );

      try {
        Uint8List imageBytes = await image.readAsBytes();
        String base64String = base64Encode(imageBytes);

        final response = await http.put(
          Uri.parse('https://jaydi-server.onrender.com/perfil/$userId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'foto_perfil': base64String}),
        );

        if (!mounted) return;
        Navigator.pop(context); 

        if (response.statusCode == 200) {
          setState(() {
            fotoPerfilBase64 = base64String;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("¡Foto actualizada!"), backgroundColor: Colors.green),
          );
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al subir la foto"), backgroundColor: Colors.red),
        );
      }
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
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Mi Perfil Jaydi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), 
        centerTitle: true, 
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 30),
            
            Center(
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: const Color(0x1AFF5722),
                    backgroundImage: fotoPerfilBase64 != null
                        ? MemoryImage(base64Decode(fotoPerfilBase64!))
                        : null,
                    child: fotoPerfilBase64 == null
                        ? const Icon(Icons.person, size: 80, color: Color(0xFFFF5722))
                        : null,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: InkWell(
                      onTap: _cambiarFoto,
                      child: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.camera_alt, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(nombreUsuario.toUpperCase(), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
            Text(correoUsuario, style: const TextStyle(fontSize: 15, color: Colors.grey)),
            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(child: _buildEstadisticaCard("Ganancias", "\$$saldo", Icons.attach_money, Colors.green)),
                  const SizedBox(width: 15),
                  Expanded(child: _buildEstadisticaCard("Viajes", "$viajesCompletados", Icons.motorcycle, Colors.blueAccent)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSeccionInfo("Vehículo", vehiculo, Icons.two_wheeler),
            ),
            const SizedBox(height: 15),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: _buildSeccionInfo("Placa / Matrícula", placa, Icons.payment),
            ),
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
                    Icon(esVerificado ? Icons.verified : Icons.info_outline, color: colorEstado, size: 30),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(textoEstado, style: TextStyle(color: colorEstado, fontWeight: FontWeight.bold, fontSize: 16)),
                          const SizedBox(height: 5),
                          Text(esVerificado 
                            ? "Ya puedes aceptar pedidos y generar ingresos." 
                            : "Estamos revisando tus documentos. Te avisaremos pronto.",
                            style: const TextStyle(fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 40),
            
            // --- BOTÓN EDITAR PERFIL CORREGIDO ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: ElevatedButton(
                onPressed: userId != null ? () async {
                  // Abre la pantalla de edición y espera a ver si guardó (resultado == true)
                  final resultado = await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => EditarPerfilScreen(
                        userId: userId!,
                        telefonoActual: telefono,
                        vehiculoActual: vehiculo,
                        placaActual: placa,
                      ),
                    ),
                  );

                  // Si el usuario guardó cambios, recargamos los datos del servidor
                  if (resultado == true) {
                    setState(() => cargando = true);
                    _cargarDatosYVerificar();
                  }
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("EDITAR PERFIL", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
            const SizedBox(height: 15),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: OutlinedButton.icon(
                onPressed: () => _cerrarSesion(),
                icon: const Icon(Icons.logout),
                label: const Text("CERRAR SESIÓN", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red, width: 2),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
            const SizedBox(height: 40), 
          ],
        ),
      ),
    );
  }

  Widget _buildEstadisticaCard(String titulo, String valor, IconData icono, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        children: [
          Icon(icono, color: color, size: 30),
          const SizedBox(height: 10),
          Text(titulo, style: TextStyle(color: Colors.grey[600], fontSize: 13, fontWeight: FontWeight.bold)),
          const SizedBox(height: 5),
          Text(valor, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }

  Widget _buildSeccionInfo(String titulo, String valor, IconData icono) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icono, color: Colors.grey[400], size: 24),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(titulo, style: TextStyle(color: Colors.grey[500], fontSize: 12, fontWeight: FontWeight.bold)),
                Text(valor, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}