import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

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

  // URL DE TU SERVIDOR EN RENDER
  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  Future<void> _registrar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _cargando = true);

      const String url = "$baseUrl/registrar";
      try {
        final response = await http.post(
          Uri.parse(url),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "nombre": _nombreController.text.trim(),
            "apellido": _apellidoController.text.trim(),
            "telefono": _telefonoController.text.trim(),
            "email": _correoController.text.trim(),
            "password": _claveController.text,      
            "rol": "repartidor"                     
          }),
        ).timeout(const Duration(seconds: 15));

        final data = jsonDecode(response.body);

        if (response.statusCode == 201) {
          // REGISTRO EXITOSO
          SharedPreferences prefs = await SharedPreferences.getInstance();
          
          // 🔥 MAGIA AQUÍ: Leemos los datos sin importar si responde Express o Delivery
          if (data.containsKey('userData')) {
            final userData = data['userData'];
            await prefs.setString('userId', userData['id'].toString());
            await prefs.setString('nombre', userData['nombre']);
            await prefs.setString('email', userData['correo'] ?? userData['email']);
          } else if (data.containsKey('usuario')) {
            final userData = data['usuario'];
            await prefs.setString('userId', userData['id'].toString());
            await prefs.setString('nombre', userData['nombre']);
            await prefs.setString('email', userData['email']);
          }
          // Nota: Si el servidor solo manda "mensaje" y no manda los datos del usuario, 
          // igual lo dejamos pasar porque el registro en Neon sí fue exitoso.
          
          await prefs.setBool('isLoggedIn', true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("¡Registro exitoso! Espera aprobación del administrador.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.green,
              ),
            );
            // Navegamos al Home
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // 🔥 MAGIA 2: Buscamos el error exacto ya sea en 'mensaje' o en 'error'
          if (mounted) {
            final errorReal = data['mensaje'] ?? data['error'] ?? "Error desconocido al registrar";
            _mostrarError(errorReal);
          }
        }
      } catch (e) {
        if (mounted) {
          _mostrarError("Problema de conexión con el servidor.");
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
      appBar: AppBar(
        backgroundColor: Colors.transparent, 
        elevation: 0, 
        foregroundColor: Colors.black
      ),
      body: Padding(
        padding: const EdgeInsets.all(25.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Text("Crea tu cuenta", 
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
              const Text("Únete al equipo de repartidores de Jaydi", 
                style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              
              TextFormField(
                controller: _nombreController,
                decoration: const InputDecoration(
                  labelText: "Nombre", 
                  border: OutlineInputBorder()
                ),
                validator: (value) => value!.isEmpty ? "Pon tu nombre" : null,
              ),
              const SizedBox(height: 15),
              
              TextFormField(
                controller: _apellidoController,
                decoration: const InputDecoration(
                  labelText: "Apellido", 
                  border: OutlineInputBorder()
                ),
                validator: (value) => value!.isEmpty ? "Pon tu apellido" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _telefonoController,
                decoration: const InputDecoration(
                  labelText: "Teléfono", 
                  border: OutlineInputBorder()
                ),
                keyboardType: TextInputType.phone,
                validator: (value) => value!.isEmpty ? "Pon tu teléfono" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _correoController,
                decoration: const InputDecoration(
                  labelText: "Correo Electrónico", 
                  border: OutlineInputBorder()
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => !value!.contains("@") ? "Correo inválido" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _claveController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: "Contraseña", 
                  border: OutlineInputBorder()
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Campo obligatorio";
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
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)
                      ),
                    ),
                    child: const Text("REGISTRARME", 
                      style: TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold, 
                        fontSize: 16
                      )),
                  ),
            ],
          ),
        ),
      ),
    );
  }
}