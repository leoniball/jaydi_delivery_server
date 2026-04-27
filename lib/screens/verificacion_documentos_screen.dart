import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'perfil_screen.dart';

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
      imageQuality: 50,
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

      if (userId == null) throw Exception("Error: No se encontró el ID de usuario.");

      var url = Uri.parse('http://192.168.1.7:5000/subir_documento');

      for (var req in _requisitos) {
        if (req['path'] == null || req['path'].isEmpty) continue;

        var request = http.MultipartRequest('POST', url);
        request.fields['tipo'] = req['id'];
        request.fields['user_id'] = userId;

        File imagenReal = File(req['path']);

        request.files.add(await http.MultipartFile.fromPath(
          'file',
          imagenReal.path,
          contentType: MediaType('image', 'jpeg'),
        ));

        debugPrint("🚀 Enviando ${req['id']}...");
        var streamedResponse = await request.send();
        var response = await http.Response.fromStream(streamedResponse);

        final Map<String, dynamic> responseData = jsonDecode(response.body);

        if (response.statusCode != 200) {
          throw Exception(responseData['error'] ?? "Error al subir ${req['titulo']}");
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("¡Documentos enviados con éxito! 🚀"), backgroundColor: Colors.green),
      );

      await Future.delayed(const Duration(seconds: 2));
      if (mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const PerfilScreen()),
          (route) => false,
        );
      }

    } catch (e) {
      debugPrint("❌ Error en el servidor: $e");
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
        title: const Text("Verificación de Identidad"),
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(20.0),
            child: Text(
              "Sube fotos nítidas para activar tu cuenta de repartidor.",
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
                  elevation: estaSubido ? 0 : 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                    side: BorderSide(
                      color: estaSubido ? Colors.green : Colors.grey.shade300,
                      width: estaSubido ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      // CORRECCIÓN AQUÍ: Usando withValues en lugar de withOpacity
                      backgroundColor: estaSubido 
                        ? Colors.green.withValues(alpha: 0.1) 
                        : Colors.orange.withValues(alpha: 0.1),
                      child: Icon(_requisitos[index]['icon'], 
                        color: estaSubido ? Colors.green : Colors.orange),
                    ),
                    title: Text(_requisitos[index]['titulo'], 
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("Estado: ${_requisitos[index]['estado']}"),
                    trailing: Icon(
                      estaSubido ? Icons.check_circle : Icons.camera_alt_outlined, 
                      color: estaSubido ? Colors.green : Colors.grey
                    ),
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
                elevation: 5,
              ),
              child: _estaEnviando 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text(
                    "ENVIAR A REVISIÓN",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
            ),
          )
        ],
      ),
    );
  }
}