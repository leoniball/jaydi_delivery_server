import 'dart:convert';
import 'dart:typed_data'; 
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart'; 
import 'editar_perfil_screen.dart'; 

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  String nombreUsuario = "Cargando...";
  String emailUsuario = "..."; 
  bool esVerificado = false;
  bool cargando = true;

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

  // MEJORA: Centralizamos la URL para evitar errores de tipeo
  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  Future<void> _cargarDatosYVerificar() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    final String? idPersistido = prefs.getString('userId');
    final String? nombrePersistido = prefs.getString('nombre');
    final String? apellidoPersistido = prefs.getString('apellido'); 
    final String? emailPersistido = prefs.getString('email'); 

    String nombreCompletoCalculado = "Usuario Jaydi";
    if (nombrePersistido != null) {
      nombreCompletoCalculado = "$nombrePersistido ${apellidoPersistido ?? ""}".trim();
    }

    if (mounted) {
      setState(() {
        userId = idPersistido; 
        nombreUsuario = nombreCompletoCalculado;
        emailUsuario = emailPersistido ?? "Sin email";
      });
    }

    if (idPersistido != null) {
      try {
        // 1. Verificar Estatus (Consistencia con app.py)
        final responseVerificar = await http.get(
          Uri.parse("$baseUrl/verificar_estatus/$idPersistido")
        ).timeout(const Duration(seconds: 10));
        
        if (responseVerificar.statusCode == 200) {
          final data = jsonDecode(responseVerificar.body);
          if (mounted) {
            setState(() {
              esVerificado = data['es_verificado'] ?? false; 
            });
            // Guardamos localmente por si otras pantallas lo necesitan
            await prefs.setBool('es_verificado', esVerificado);
          }
        }

        // 2. Traer Estadísticas (URL Unificada /api/perfil/)
        final responsePerfil = await http.get(
          Uri.parse("$baseUrl/api/perfil/$idPersistido")
        ).timeout(const Duration(seconds: 10));

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
        debugPrint("Error de conexión al cargar perfil: $e");
      }
    }
    
    if (mounted) {
      setState(() => cargando = false);
    }
  }

  Future<void> _cambiarFoto() async {
    final ImagePicker picker = ImagePicker();
    // Calidad al 40% para que el plan de Render maneje el Base64 más rápido
    final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 40);

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

        // Usamos la ruta /api/perfil que es la que tiene el PUT optimizado
        final response = await http.put(
          Uri.parse('$baseUrl/api/perfil/$userId'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'foto_perfil': base64String}),
        ).timeout(const Duration(seconds: 20));

        if (!mounted) return;
        Navigator.pop(context); 

        if (response.statusCode == 200) {
          setState(() => fotoPerfilBase64 = base64String);
          _mostrarSnackBar("¡Foto de perfil actualizada!", Colors.green);
        } else {
          throw Exception("Error del servidor");
        }
      } catch (e) {
        if (!mounted) return;
        Navigator.pop(context);
        _mostrarSnackBar("Error al subir la foto", Colors.red);
      }
    }
  }

  void _mostrarSnackBar(String msj, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msj), backgroundColor: color, behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _cerrarSesion() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
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

    final Color colorEstado = esVerificado ? Colors.green : Colors.orange;
    final String textoEstado = esVerificado ? "🟢 Cuenta Verificada" : "🟠 Cuenta en Revisión";

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      appBar: AppBar(
        title: const Text("Mi Perfil Jaydi", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)), 
        centerTitle: true, 
        elevation: 0,
        backgroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.black87),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarDatosYVerificar,
        color: const Color(0xFFFF5722),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            children: [
              const SizedBox(height: 30),
              _buildFotoHeader(),
              const SizedBox(height: 20),
              Text(nombreUsuario.toUpperCase(), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: 1)),
              Text(emailUsuario, style: const TextStyle(fontSize: 14, color: Colors.grey)), 
              const SizedBox(height: 30),
              _buildStatsRow(),
              const SizedBox(height: 25),
              _buildInfoSection(),
              const SizedBox(height: 25),
              _buildStatusBanner(colorEstado, textoEstado),
              const SizedBox(height: 40),
              _buildActionButtons(),
              const SizedBox(height: 40), 
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFotoHeader() {
    return Center(
      child: Stack(
        children: [
          CircleAvatar(
            radius: 65,
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
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF5722),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: _buildStatCard("Ganancias", "\$${saldo.toStringAsFixed(2)}", Icons.account_balance_wallet, Colors.green)),
          const SizedBox(width: 15),
          Expanded(child: _buildStatCard("Viajes", "$viajesCompletados", Icons.directions_bike, Colors.blue)),
        ],
      ),
    );
  }

  Widget _buildInfoSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          _buildInfoTile("Vehículo", vehiculo, Icons.motorcycle),
          const SizedBox(height: 12),
          _buildInfoTile("Placa / Matrícula", placa, Icons.vignette),
          const SizedBox(height: 12),
          _buildInfoTile("Teléfono", telefono, Icons.phone_iphone),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(Color color, String texto) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(esVerificado ? Icons.verified_user : Icons.hourglass_top, color: color),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(texto, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
                  Text(
                    esVerificado ? "¡Estás listo para trabajar!" : "Tus documentos están en validación.",
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 25),
      child: Column(
        children: [
          ElevatedButton(
            onPressed: userId == null ? null : () async {
              final res = await Navigator.push(context, MaterialPageRoute(
                builder: (context) => EditarPerfilScreen(
                  userId: userId!,
                  telefonoActual: telefono,
                  vehiculoActual: vehiculo,
                  placaActual: placa,
                )
              ));
              if (res == true) _cargarDatosYVerificar();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("EDITAR DATOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 15),
          TextButton.icon(
            onPressed: _cerrarSesion,
            icon: const Icon(Icons.exit_to_app, color: Colors.red),
            label: const Text("CERRAR SESIÓN", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
       boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        children: [
          Icon(icon, color: color),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoTile(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey, size: 20),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey, fontWeight: FontWeight.bold)),
              Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }
}