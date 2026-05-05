import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class EditarPerfilScreen extends StatefulWidget {
  final String userId;
  final String telefonoActual;
  final String vehiculoActual;
  final String placaActual;

  const EditarPerfilScreen({
    super.key,
    required this.userId,
    required this.telefonoActual,
    required this.vehiculoActual,
    required this.placaActual,
  });

  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  late TextEditingController _telefonoController;
  late TextEditingController _vehiculoController;
  late TextEditingController _placaController;
  bool guardando = false;

  @override
  void initState() {
    super.initState();
    // Cargamos los datos actuales
    _telefonoController = TextEditingController(text: widget.telefonoActual == "Sin registrar" ? "" : widget.telefonoActual);
    _vehiculoController = TextEditingController(text: widget.vehiculoActual == "Sin registrar" ? "" : widget.vehiculoActual);
    _placaController = TextEditingController(text: widget.placaActual == "Sin registrar" ? "" : widget.placaActual);
  }

  @override
  void dispose() {
    _telefonoController.dispose();
    _vehiculoController.dispose();
    _placaController.dispose();
    super.dispose();
  }

  Future<void> _guardarCambios() async {
    if (_telefonoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("El teléfono es obligatorio"), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => guardando = true);

    try {
      final response = await http.put(
        Uri.parse('https://jaydi-server.onrender.com/perfil/${widget.userId}'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'telefono': _telefonoController.text.trim(),
          'vehiculo': _vehiculoController.text.trim(),
          'placa': _placaController.text.trim().toUpperCase(),
        }),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Perfil actualizado!"), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true); // Devuelve 'true' para recargar la pantalla anterior
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error al guardar cambios"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Error de conexión"), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Colores suaves para no cansar la vista
    final Color naranjaSuave = const Color(0xFFFF5722).withValues(alpha: 0.1);
    final Color bordeSuave = const Color(0xFFFF5722).withValues(alpha: 0.2);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Editar Perfil", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Datos de Contacto y Vehículo", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text("Mantén tu información actualizada para recibir pedidos.", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            _buildField("Teléfono Móvil", Icons.phone_android, _telefonoController, TextInputType.phone, naranjaSuave, bordeSuave),
            const SizedBox(height: 20),
            _buildField("Vehículo (Marca/Modelo)", Icons.two_wheeler, _vehiculoController, TextInputType.text, naranjaSuave, bordeSuave),
            const SizedBox(height: 20),
            _buildField("Placa / Matrícula", Icons.tag, _placaController, TextInputType.text, naranjaSuave, bordeSuave),
            
            const SizedBox(height: 40),

            ElevatedButton(
              onPressed: guardando ? null : _guardarCambios,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              ),
              child: guardando 
                ? const CircularProgressIndicator(color: Colors.white)
                : const Text("GUARDAR CAMBIOS", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildField(String label, IconData icon, TextEditingController controller, TextInputType type, Color fondo, Color borde) {
    return TextField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: const Color(0xFFFF5722)),
        filled: true,
        fillColor: fondo,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: borde),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: Color(0xFFFF5722), width: 2),
        ),
      ),
    );
  }
}