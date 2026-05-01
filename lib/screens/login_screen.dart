import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _correoController = TextEditingController();
  final _claveController = TextEditingController();
  bool _obscureText = true;
  bool _isLoading = false; 

  // CENTRALIZAMOS TU URL DE RENDER AQUÍ
  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  Future<void> _iniciarSesion() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            // CORRECCIÓN 1: El servidor en Python espera 'email' y 'password'
            'email': _correoController.text.trim(),
            'password': _claveController.text,
          }),
        ).timeout(const Duration(seconds: 15)); 

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // CORRECCIÓN 2: El nuevo app.py devuelve los datos en la llave 'usuario'
          final userData = data['usuario'];

          SharedPreferences prefs = await SharedPreferences.getInstance();
          await prefs.setBool('isLoggedIn', true);
          
          // Guardamos los datos asegurando que el formato no rompa la app
          await prefs.setInt('repartidor_id', int.parse(userData['id'].toString()));
          await prefs.setString('nombre_repartidor', userData['nombre']);
          await prefs.setString('userId', userData['id'].toString()); 
          await prefs.setString('nombre', userData['nombre']); 
          // CORRECCIÓN 3: El servidor devuelve el correo en la llave 'email'
          await prefs.setString('correo', userData['email']); 

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          // Error de credenciales o de falta de aprobación (401 o 403)
          final errorData = jsonDecode(response.body);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              // CORRECCIÓN 4: El servidor manda la razón del error en 'mensaje'
              SnackBar(content: Text(errorData['mensaje'] ?? "Error al iniciar sesión")),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error de conexión con el servidor")),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                "Bienvenido a Jaydi",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const Text("Inicia sesión para continuar", style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              // Campo de Correo
              TextFormField(
                controller: _correoController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo Electrónico",
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                validator: (value) => !value!.contains("@") ? "Ingresa un correo válido" : null,
              ),
              const SizedBox(height: 20),

              // Campo de Clave
              TextFormField(
                controller: _claveController,
                obscureText: _obscureText,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off),
                    onPressed: () => setState(() => _obscureText = !_obscureText),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                ),
                validator: (value) => value!.length < 6 ? "Mínimo 6 caracteres" : null,
              ),
              const SizedBox(height: 30),

              // Botón de Ingreso
              ElevatedButton(
                onPressed: _isLoading ? null : _iniciarSesion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF5722),
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text("INGRESAR", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              
              const SizedBox(height: 15),
              Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.pushNamed(context, '/registro');
                  },
                  child: const Text("¿No tienes cuenta? Regístrate aquí"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}