import 'package:flutter/material.dart';
import '../utils/responsive.dart'; // Importamos nuestro helper de responsividad
import 'cobros_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Obtenemos el ancho de pantalla
    final screenWidth = Responsive.screenWidth(context);

    // Definimos tamaños basados en el dispositivo
    final iconSize = Responsive.isMobile(context) ? 80.0 : 120.0;
    final titleFontSize = Responsive.isMobile(context) ? 20.0 : 28.0;
    final paddingValue = Responsive.isMobile(context) ? 20.0 : 40.0;
    final buttonWidth = Responsive.isMobile(context) ? double.infinity : 400.0;
    final verticalSpacing = Responsive.isMobile(context) ? 20.0 : 30.0;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            // Ancho máximo condicional:
            // - En móvil: ocupa casi todo el ancho (95%)
            // - En tablet/desktop: ancho fijo de 600px
            width: Responsive.isMobile(context) ? screenWidth * 0.95 : 600,
            padding: EdgeInsets.all(paddingValue),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                if (!Responsive.isMobile(
                  context,
                )) // Sombra solo en pantallas grandes
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 5,
                  ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Ícono principal (tamaño responsivo)
                Icon(
                  Icons.home,
                  size: iconSize,
                  color: Theme.of(context).primaryColor,
                ),

                // Espaciado vertical responsivo
                SizedBox(height: verticalSpacing),

                // Título (tamaño de fuente responsivo)
                Text(
                  'Bienvenido a la App de Cobros',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Subtítulo (visible solo en pantallas grandes)
                if (!Responsive.isMobile(context))
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Text(
                      'Gestiona tus cobros de forma eficiente',
                      style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    ),
                  ),

                SizedBox(height: verticalSpacing * 1.5),

                // Botón principal (ancho responsivo)
                SizedBox(
                  width: buttonWidth,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CobrosScreen(),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text(
                      'Nuevo Cobro',
                      style: TextStyle(fontSize: 18),
                    ),
                  ),
                ),

                // Espacio adicional en pantallas grandes
                if (!Responsive.isMobile(context)) const SizedBox(height: 40),

                // Sección adicional para tablets/desktop
                if (Responsive.isTablet(context) ||
                    Responsive.isDesktop(context))
                  Padding(
                    padding: const EdgeInsets.only(top: 30),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildFeatureItem(
                          context,
                          Icons.show_chart,
                          'Estadísticas',
                        ),
                        _buildFeatureItem(context, Icons.history, 'Historial'),
                        _buildFeatureItem(
                          context,
                          Icons.settings,
                          'Configuración',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Widget auxiliar para construir ítems de características (solo visible en tablet/desktop)
  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 30, color: Theme.of(context).primaryColor),
        ),
        const SizedBox(height: 8),
        Text(
          text,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}
