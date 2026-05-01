import 'package:flutter/material.dart';
import 'package:jaydi_delivery/screens/home_repartidor.dart';
import 'package:jaydi_delivery/screens/perfil_screen.dart'; 
import 'package:jaydi_delivery/screens/ruta_screen.dart'; // Importamos la nueva pantalla

class MainMenu extends StatefulWidget {
  const MainMenu({super.key});

  @override
  State<MainMenu> createState() => _MainMenuState();
}

class _MainMenuState extends State<MainMenu> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Definimos las pantallas dinámicas
    final List<Widget> screens = [
      const HomeRepartidor(), 
      const RutaScreen(), // Mejora aplicada: Ahora carga el historial de viajes real
      const Center(child: Text("Pantalla: Mensajería (Jaydi Express)")),
      const Center(child: Text("Pantalla: Billetera")),
      // REQUERIMIENTO REAL: Ya no le pasamos 'true' ni 'false'. 
      // El Perfil ahora cargará solo los datos del usuario logueado.
      const PerfilScreen(), 
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: const Color(0xFFFF5722),
        unselectedItemColor: Colors.grey,
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore), label: 'Pedidos'),
          BottomNavigationBarItem(icon: Icon(Icons.map), label: 'Ruta'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Mensajes'),
          BottomNavigationBarItem(icon: Icon(Icons.payments), label: 'Pagos'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Perfil'),
        ],
      ),
    );
  }
}