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
  final _emailController = TextEditingController(); // ESTRICTAMENTE EMAIL
  final _passwordController = TextEditingController(); // ESTRICTAMENTE PASSWORD

  bool _cargando = false;
  bool _obscureText = true; // Para mostrar/ocultar el password

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
            "email": _emailController.text.trim(), // Se envía como email
            "password": _passwordController.text,  // Se envía como password
            "rol": "repartidor"                     
          }),
        ).timeout(const Duration(seconds: 15));

        final data = jsonDecode(response.body);

        if (response.statusCode == 201) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          
          if (data.containsKey('userData')) {
            final userData = data['userData'];
            await prefs.setString('userId', userData['id'].toString());
            await prefs.setString('nombre', userData['nombre']);
            // GUARDADO ESTRICTAMENTE COMO EMAIL
            await prefs.setString('email', userData['email'] ?? userData['correo'] ?? "");
          } else if (data.containsKey('usuario')) {
            final userData = data['usuario'];
            await prefs.setString('userId', userData['id'].toString());
            await prefs.setString('nombre', userData['nombre']);
            // GUARDADO ESTRICTAMENTE COMO EMAIL
            await prefs.setString('email', userData['email'] ?? userData['correo'] ?? "");
          }
          
          await prefs.setBool('isLoggedIn', true);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("¡Registro exitoso! Espera aprobación del administrador.",
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                backgroundColor: Colors.green,
              ),
            );
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
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
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: "Email", 
                  border: OutlineInputBorder()
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) => !value!.contains("@") ? "Email inválido" : null,
              ),
              const SizedBox(height: 15),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: "Password", 
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
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