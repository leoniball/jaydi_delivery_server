import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http; 
import 'dart:convert'; 
import 'dart:async';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  bool _obscureText = true;
  bool _isLoading = false; 

  static const String baseUrl = 'https://jaydi-delivery-serverv.onrender.com';

  Future<void> _iniciarSesion() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final response = await http.post(
          Uri.parse('$baseUrl/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            // Corregido: Enviamos el email siempre en minúsculas al servidor
            'email': _emailController.text.trim().toLowerCase(),
            'password': _passwordController.text,
          }),
        ).timeout(const Duration(seconds: 30)); 

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final userData = data['userData'];

          SharedPreferences prefs = await SharedPreferences.getInstance();
          
          // --- PERSISTENCIA CRÍTICA ---
          await prefs.setBool('isLoggedIn', true);
          await prefs.setString('userId', userData['id'].toString()); 
          await prefs.setString('nombre', userData['nombre']); 
          await prefs.setString('apellido', userData['apellido'] ?? ''); 
          await prefs.setString('email', userData['email']); 
          
          // 🔥 CLAVE: Guardamos el estatus que viene del nuevo app.py
          // Esto elimina "la mierda" del aviso naranja de inmediato si ya está aprobado
          await prefs.setString('userStatus', userData['status'] ?? 'pendiente');
          
          // También guardamos el booleano por si lo usas en otros widgets
          await prefs.setBool('es_verificado', userData['es_verificado'] ?? false);

          if (mounted) {
            Navigator.pushReplacementNamed(context, '/home');
          }
        } else {
          final errorData = jsonDecode(response.body);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(errorData['error'] ?? "Credenciales incorrectas"),
                backgroundColor: Colors.redAccent,
              ),
            );
          }
        }
      } on TimeoutException {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Servidor lento, intenta de nuevo"), backgroundColor: Colors.orange),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Error de conexión"), backgroundColor: Colors.red),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30),
        child: Form(
          key: _formKey,
          child: Center(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Bienvenido a Jaydi",
                    style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFFFF5722)),
                  ),
                  const Text("Inicia sesión para continuar", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 40),

                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: "Email",
                      prefixIcon: const Icon(Icons.email_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) return "Ingresa tu correo";
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  TextFormField(
                    controller: _passwordController,
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
                    validator: (value) => value!.isEmpty ? "Ingresa tu contraseña" : null,
                  ),
                  const SizedBox(height: 30),

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
                      onPressed: () => Navigator.pushNamed(context, '/registro'),
                      child: const Text("¿No tienes cuenta? Regístrate aquí", style: TextStyle(color: Color(0xFFFF5722))),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}