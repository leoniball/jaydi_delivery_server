import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; // IMPORTANTE: Agrega http al pubspec.yaml

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _apellidoController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _correoController = TextEditingController();
  final _claveController = TextEditingController();

  bool _cargando = false;

  Future<void> _registrar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _cargando = true);

      // URL de tu servidor Flask (Usa tu IP local si pruebas en físico o 10.0.2.2 en emulador)
      const String url = "http://10.0.2.2:5000/registro"; 

      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "nombre": "${_nombreController.text} ${_apellidoController.text}",
            "correo": _correoController.text.trim(),
            "clave": _claveController.text,
          }),
        );

        final data = jsonDecode(response.body);

        if (response.statusCode == 201) {
          // REGISTRO EXITOSO EN NEON
          SharedPreferences prefs = await SharedPreferences.getInstance();
          
          // Guardamos los datos REALES que devolvió el servidor
          await prefs.setString('userId', data['userData']['id'].toString());
          await prefs.setString('nombre', data['userData']['nombre']);
          await prefs.setString('correo', data['userData']['correo']);
          await prefs.setBool('isLoggedIn', true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("¡Registro exitoso!"), backgroundColor: Colors.green),
            );
            // Navegamos al Home (Asegúrate de tener esta ruta o usa MaterialPageRoute)
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // ERROR DEL SERVIDOR (Ej: Correo ya registrado)
          if (mounted) {
            _mostrarError(data['error'] ?? "Error al registrar");
          }
        }
      } catch (e) {
        if (mounted) {
          _mostrarError("No se pudo conectar con el servidor. Verifica tu conexión.");
        }
      } finally {
        if (mounted) setState(() => _cargando = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Colors.black),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text("Crea tu cuenta", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text("Únete al equipo de repartidores de Jaydi", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(labelText: "Nombre", border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? "Pon tu nombre" : null,
              ),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _apellidoController,
                decoration: const InputDecoration(labelText: "Apellido", border: OutlineInputBorder()),
                validator: (value) => value!.isEmpty ? "Pon tu apellido" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(labelText: "Teléfono", border: OutlineInputBorder()),
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _correoController,
                decoration: const InputDecoration(labelText: "Correo Electrónico", border: OutlineInputBorder()),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => !value!.contains("@") ? "Correo inválido" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _claveController,
                obscureText: true,
                decoration: const InputDecoration(labelText: "Contraseña", border: OutlineInputBorder()),
                validator: (value) {
                  if (value!.length < 6 || value.length > 12) {
                    return "La clave debe tener entre 6 y 12 dígitos";
                  }
                  return null;
                },
              ),

              const SizedBox(height: 40),
              
              _cargando 
                ? const Center(child: CircularProgressIndicator(color: Color(0xFFFF5722)))
                : ElevatedButton(
                    onPressed: _registrar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF5722),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: const Text("REGISTRARME", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}