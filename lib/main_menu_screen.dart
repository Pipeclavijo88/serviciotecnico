import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'home_screen.dart';
import 'entrada_inventario_screen.dart';
import 'salida_inventario_screen.dart';
import 'catalogo_inventario_screen.dart';
import 'historial_movimientos_screen.dart';
import 'login_screen.dart';

class MainMenuScreen extends StatelessWidget {
  const MainMenuScreen({super.key});

  Future<void> _cerrarSesion(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final usuario = Supabase.instance.client.auth.currentUser;
    final emailUsuario = usuario?.email ?? 'Usuario MYP';

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Panel de Control - MYP', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.blueGrey[900],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _cerrarSesion(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- SALUDO E INFORMACIÓN DEL USUARIO ---
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 26,
                        backgroundColor: Colors.blue[800],
                        child: const Icon(Icons.person, color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              '¡Bienvenido!',
                              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              emailUsuario,
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 25),

              const Text(
                'Módulos del Sistema',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              ),
              const SizedBox(height: 15),

              // --- OPCIÓN 1: SERVICIO TÉCNICO ---
              _buildMenuCard(
                context: context,
                titulo: 'Servicio Técnico',
                subtitulo: 'Recepción, diagnósticos y control de estados de reparación',
                icono: Icons.build_circle_outlined,
                colorIcono: Colors.blue[700]!,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HomeScreen()),
                  );
                },
              ),
              const SizedBox(height: 15),

              // --- OPCIÓN 2: CONTROL DE INVENTARIO / BODEGA ---
              _buildMenuCard(
                context: context,
                titulo: 'Gestión de Inventario y Bodega',
                subtitulo: 'Entradas, salidas, catálogo de stock e historial de despachos',
                icono: Icons.inventory_2_outlined,
                colorIcono: Colors.teal[700]!,
                onTap: () {
                  _mostrarOpcionesBodega(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required BuildContext context,
    required String titulo,
    required String subtitulo,
    required IconData icono,
    required Color colorIcono,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorIcono.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icono, color: colorIcono, size: 36),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitulo,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _mostrarOpcionesBodega(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gestión de Bodega',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              
              // 1. Ver Catálogo y Saldos de Inventario
              ListTile(
                leading: const Icon(Icons.grid_view_rounded, color: Colors.indigo, size: 30),
                title: const Text('Catálogo y Saldos en Tiempo Real', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Consulta existencia física, saldos negativos y repuestos'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const CatalogoInventarioScreen()),
                  );
                },
              ),
              const Divider(),

              // 2. Historial y Despachos por Cliente
              ListTile(
                leading: const Icon(Icons.history_edu, color: Colors.amber, size: 30),
                title: const Text('Historial y Despachos por Cliente', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Consulta salidas por cliente, fecha o encargado'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const HistorialMovimientosScreen()),
                  );
                },
              ),
              const Divider(),

              // 3. Entrada de Mercancía
              ListTile(
                leading: const Icon(Icons.move_to_inbox, color: Colors.teal, size: 30),
                title: const Text('Entrada de Mercancía', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Recepción de compras, devoluciones y repuestos'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const EntradaInventarioScreen()),
                  );
                },
              ),
              const Divider(),

              // 4. Salida de Mercancía
              ListTile(
                leading: const Icon(Icons.outbox, color: Colors.blueGrey, size: 30),
                title: const Text('Salida de Mercancía', style: TextStyle(fontWeight: FontWeight.bold)),
                subtitle: const Text('Despacho a clientes, instaladores y consumo interno'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const SalidaInventarioScreen()),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}