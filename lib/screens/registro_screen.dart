import 'dart:convert';
import 'dart:async';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _cargando = false;
  bool _obscureText = true;

  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  Future<void> _registrar() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _cargando = true);

      try {
        final response = await http.post(
          Uri.parse("$baseUrl/registrar"),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode({
            "nombre": _nombreController.text.trim(),
            "apellido": _apellidoController.text.trim(),
            "telefono": _telefonoController.text.trim(),
            "email": _emailController.text.trim().toLowerCase(), 
            "password": _passwordController.text,
            "rol": "repartidor"                    
          }),
        ).timeout(const Duration(seconds: 30));

        final data = jsonDecode(response.body);

        if (response.statusCode == 201 || response.statusCode == 200) {
          SharedPreferences prefs = await SharedPreferences.getInstance();
          final userData = data['userData'] ?? data['usuario'];
          
          if (userData != null) {
            // PERSISTENCIA COMPLETA PARA EL HOME
            await prefs.setBool('isLoggedIn', true);
            await prefs.setString('userId', userData['id'].toString());
            await prefs.setString('nombre', userData['nombre'] ?? _nombreController.text.trim());
            await prefs.setString('apellido', userData['apellido'] ?? _apellidoController.text.trim());
            await prefs.setString('email', userData['email'] ?? _emailController.text.trim());
            
            // 🔥 CLAVE: Sincronizamos el estatus inicial para que el Home sepa qué mostrar
            await prefs.setString('userStatus', 'pendiente');
            await prefs.setBool('es_verificado', false);
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("¡Registro exitoso! Sube tus documentos para activar tu cuenta."),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          if (mounted) {
            _mostrarError(data['error'] ?? "Error al registrar");
          }
        }
      } on TimeoutException {
        _mostrarError("El servidor tarda mucho. Intenta de nuevo.");
      } catch (e) {
        debugPrint("ERROR: $e");
        _mostrarError("Error de conexión con el servidor.");
      } finally {
        if (mounted) setState(() => _cargando = false);
      }
    }
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidoController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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
              const Text("Crea tu cuenta", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Color(0xFFFF5722))),
              const Text("Únete al equipo de repartidores de Jaydi", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 30),
              
              _buildField(_nombreController, "Nombre", Icons.person_outline),
              const SizedBox(height: 15),
              _buildField(_apellidoController, "Apellido", Icons.person_outline),
              const SizedBox(height: 15),
              _buildField(_telefonoController, "Teléfono", Icons.phone_android, type: TextInputType.phone),
              const SizedBox(height: 15),
              _buildField(_emailController, "Email", Icons.email_outlined, type: TextInputType.emailAddress),
              const SizedBox(height: 15),

              TextFormField(
                controller: _passwordController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: "Contraseña", 
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                ),
                validator: (value) => value!.length < 6 ? "Mínimo 6 caracteres" : null,
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
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildField(TextEditingController controller, String label, IconData icon, {TextInputType type = TextInputType.text}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), border: const OutlineInputBorder()),
      validator: (value) => value!.isEmpty ? "Obligatorio" : null,
    );
  }
}