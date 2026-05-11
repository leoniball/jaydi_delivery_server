

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
// Importamos main_menu para que el flujo sea el correcto tras verificar
import 'main_menu.dart'; 

class VerificacionDocumentosScreen extends StatefulWidget {
  const VerificacionDocumentosScreen({super.key});

  @override
  State<VerificacionDocumentosScreen> createState() => _VerificacionDocumentosScreenState();
}

class _VerificacionDocumentosScreenState extends State<VerificacionDocumentosScreen> {
  final ImagePicker _picker = ImagePicker();
  bool _estaEnviando = false;

  final List<Map<String, dynamic>> _requisitos = [
    {'id': 'selfie_cedula', 'titulo': 'Selfie con Cédula (Prueba de Vida)', 'estado': 'Pendiente', 'icon': Icons.face, 'subido': false, 'path': ''},
    {'id': 'cedula_frontal', 'titulo': 'Cédula de Identidad (Frontal)', 'estado': 'Pendiente', 'icon': Icons.badge, 'subido': false, 'path': ''},
    {'id': 'licencia', 'titulo': 'Licencia de Conducir', 'estado': 'Pendiente', 'icon': Icons.assignment_ind, 'subido': false, 'path': ''},
    {'id': 'certificado_medico', 'titulo': 'Certificado Médico', 'estado': 'Pendiente', 'icon': Icons.health_and_safety, 'subido': false, 'path': ''},
    {'id': 'titulo_circulacion', 'titulo': 'Título o Carnet de Circulación', 'estado': 'Pendiente', 'icon': Icons.description, 'subido': false, 'path': ''},
    {'id': 'seguro_rcv', 'titulo': 'Seguro RCV', 'estado': 'Pendiente', 'icon': Icons.verified_user, 'subido': false, 'path': ''},
  ];

  bool get _todoListo => _requisitos.every((req) => req['subido'] == true);

  Future<void> _capturarDocumento(int index) async {
    final ImageSource? fuente = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text("Selecciona origen"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt, color: Color(0xFFFF5722)),
              title: const Text("Cámara"),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library, color: Color(0xFFFF5722)),
              title: const Text("Galería"),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );

    if (fuente == null) return;

    final XFile? photo = await _picker.pickImage(
      source: fuente,
      imageQuality: 40, // Bajamos un poco más la calidad para subir más rápido a Render
    );

    if (photo != null) {
      setState(() {
        _requisitos[index]['estado'] = 'Listo ✅';
        _requisitos[index]['subido'] = true;
        _requisitos[index]['path'] = photo.path;
      });
    }
  }

  Future<void> _enviarAFlask() async {
    setState(() => _estaEnviando = true);

    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? userId = prefs.getString('userId');

      if (userId == null) throw Exception("No se encontró sesión activa.");

      var url = Uri.parse('https://jaydi-delivery-serverv.onrender.com/subir_documento');

      for (var req in _requisitos) {
        if (req['path'] == null || req['path'].isEmpty) continue;

        var request = http.MultipartRequest('POST', url);
        request.fields['tipo'] = req['id'];
        request.fields['user_id'] = userId;

        request.files.add(await http.MultipartFile.fromPath(
          'file',
          req['path'],
          contentType: MediaType('image', 'jpeg'),
        ));

        debugPrint("🚀 Subiendo: ${req['id']}");
        var streamedResponse = await request.send().timeout(const Duration(seconds: 45));
        var response = await http.Response.fromStream(streamedResponse);

        if (response.statusCode != 200) {
          throw Exception("Error al subir ${req['titulo']}");
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("¡Documentos en revisión! Espera la aprobación."),
          backgroundColor: Colors.green,
        ),
      );

      // 🔥 CORRECCIÓN DE FLUJO:
      // Después de subir todo, mandamos al usuario al menú principal 
      // para que vea su estatus de "En revisión" correctamente.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const MainMenu()),
        (route) => false,
      );

    } catch (e) {
      debugPrint("❌ ERROR: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _estaEnviando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Verificación de Identidad", style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Tus documentos serán revisados por el equipo administrativo en menos de 24 horas.",
              style: TextStyle(color: Colors.grey, fontSize: 14),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: _requisitos.length,
              itemBuilder: (context, index) {
                bool estaSubido = _requisitos[index]['subido'];

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 6),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(color: estaSubido ? Colors.green : Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: estaSubido ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                      child: Icon(_requisitos[index]['icon'], color: estaSubido ? Colors.green : Colors.orange),
                    ),
                    title: Text(_requisitos[index]['titulo'], style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(estaSubido ? "Listo para enviar" : "Pendiente de captura"),
                    trailing: Icon(estaSubido ? Icons.check_circle : Icons.camera_alt, color: estaSubido ? Colors.green : Colors.grey),
                    onTap: _estaEnviando ? null : () => _capturarDocumento(index),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(25.0),
            child: ElevatedButton(
              onPressed: (_todoListo && !_estaEnviando) ? _enviarAFlask : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 60),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: _estaEnviando 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("ENVIAR A REVISIÓN", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
    );
  }
}