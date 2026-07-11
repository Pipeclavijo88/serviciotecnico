import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'new_request_screen.dart'; 
import 'detail_screen.dart'; 

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'Todos';

  final List<String> _filters = [
    'Todos', 
    'Registrado', 
    'En Revisión', 
    'Técnico Propio', 
    'Taller Externo', 
    'Reparado', 
    'No tiene reparación',
    'Pendiente de Pago',
    'Finalizado'
  ];

  // Función corregida: Se prioriza el área asignada sobre el responsable
  String _calcularEstadoReal(Map<String, dynamic> solicitud) {
    final estadoActual = solicitud['estado'] ?? 'Registrado';

    // 1. Si ya se encuentra en las etapas de cierre definitivo, se respeta el estado manual
    if (estadoActual == 'Finalizado' || estadoActual == 'Pendiente de Pago') {
      return estadoActual;
    }

    // 2. Si ya se definió explícitamente el resultado de la reparación
    final tieneReparacion = solicitud['tiene_reparacion'];
    if (tieneReparacion != null) {
      if (tieneReparacion == true || tieneReparacion.toString().toLowerCase() == 'si') {
        return 'Reparado';
      }
      if (tieneReparacion == false || tieneReparacion.toString().toLowerCase() == 'no') {
        return 'No tiene reparación';
      }
    }

    // 3. PRIORIDAD: Si aún no hay definición de reparación, pero ya se asignó el área en REVISIÓN TÉCNICA
    final revisionTecnica = (solicitud['revision_tecnica'] ?? '').toString().toLowerCase().trim();
    if (revisionTecnica == 'tecnico propio' || revisionTecnica == 'técnico propio') {
      return 'Técnico Propio';
    }
    if (revisionTecnica == 'taller externo') {
      return 'Taller Externo';
    }

    // 4. Si no se ha elegido área encargada, pero ya tiene un responsable asignado en proceso de diagnóstico
    final responsable = (solicitud['responsable'] ?? 'Sin Asignar').toString().toLowerCase().trim();
    if (responsable != 'sin asignar' && responsable != 'servicio técnico myp') {
      return 'En Revisión';
    }

    // 5. Por defecto, si está nuevo sin tocar
    return 'Registrado';
  }

  // Formateador simple de fecha (Extrae AAAA-MM-DD y lo vuelve DD/MM/AAAA)
  String _formatearFecha(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Sin fecha';
    try {
      final dateTime = DateTime.parse(dateStr).toLocal();
      final dia = dateTime.day.toString().padLeft(2, '0');
      final mes = dateTime.month.toString().padLeft(2, '0');
      final anio = dateTime.year;
      return '$dia/$mes/$anio';
    } catch (_) {
      return 'Sin fecha';
    }
  }

  // Paleta de colores exacta solicitada por Pipe
  Color _getEstadoColor(String estado) {
    switch (estado) {
      case 'Registrado': 
        return const Color(0xFF81C784); // Verde Claro
      case 'En Revisión': 
        return const Color(0xFFFFD54F); // Amarillo
      case 'Técnico Propio': 
        return const Color(0xFF4FC3F7); // Azul Claro
      case 'Taller Externo': 
        return const Color(0xFFBA68C8); // Lila
      case 'Reparado': 
        return const Color(0xFF4CAF50); // Verde Estándar
      case 'No tiene reparación': 
        return const Color(0xFFE57373); // Rojizo
      case 'Pendiente de Pago': 
        return const Color(0xFF8D6E63); // Marrón
      case 'Finalizado': 
        return const Color(0xFF2E7D32); // Verde más Oscuro
      default: 
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16.0),
              color: Colors.white,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'SERVICIO TÉCNICO MYP',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const NewRequestScreen()),
                          ).then((_) => setState(() {})); 
                        },
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text('Nuevo', style: TextStyle(fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _searchController,
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value.trim().toLowerCase();
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Buscar por cliente...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      fillColor: Colors.grey[50],
                      filled: true,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 35,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: _filters.length,
                      itemBuilder: (context, index) {
                        final filter = _filters[index];
                        final isSelected = _selectedFilter == filter;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8.0),
                          child: ChoiceChip(
                            label: Text(filter, style: TextStyle(color: isSelected ? Colors.white : Colors.black, fontSize: 12)),
                            selected: isSelected,
                            selectedColor: Colors.blue,
                            backgroundColor: Colors.grey[200],
                            onSelected: (selected) {
                              if (selected) {
                                setState(() {
                                  _selectedFilter = filter;
                                });
                              }
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: Supabase.instance.client.from('solicitudes').select().order('created_at', ascending: false),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error al cargar datos: ${snapshot.error}'));
                  }
                  
                  final data = snapshot.data ?? [];
                  
                  final filteredList = data.where((item) {
                    final nombre = (item['cliente_nombre'] ?? '').toString().toLowerCase();
                    
                    // Calculamos el estado en tiempo real antes de aplicar el filtro visual
                    final estadoCalculado = _calcularEstadoReal(item);
                    
                    final matchSearch = nombre.contains(_searchQuery);
                    final matchFilter = _selectedFilter == 'Todos' || estadoCalculado == _selectedFilter;
                    
                    return matchSearch && matchFilter;
                  }).toList();

                  if (filteredList.isEmpty) {
                    return const Center(child: Text('No se encontraron registros.'));
                  }

                  return ListView.builder(
                    itemCount: filteredList.length,
                    itemBuilder: (context, index) {
                      final solicitud = filteredList[index];
                      final estadoReal = _calcularEstadoReal(solicitud);
                      final fechaFormateada = _formatearFecha(solicitud['created_at']);

                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        child: ListTile(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => DetailScreen(solicitud: solicitud),
                              ),
                            ).then((_) => setState(() {})); 
                          },
                          title: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  solicitud['cliente_nombre'] ?? 'Sin Nombre',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                fechaFormateada,
                                style: TextStyle(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Teléfono: ${solicitud['telefono']}'),
                                Text('Elementos: ${solicitud['cantidad_elementos']}'),
                                Text('Responsable: ${solicitud['responsable'] ?? 'Servicio técnico MYP'}'),
                              ],
                            ),
                          ),
                          trailing: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                            decoration: BoxDecoration(
                              color: _getEstadoColor(estadoReal),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              estadoReal,
                              style: TextStyle(
                                // Letras oscuras para los colores claros para facilitar la lectura
                                color: (estadoReal == 'Registrado' || estadoReal == 'En Revisión' || estadoReal == 'Técnico Propio' || estadoReal == 'Taller Externo') 
                                    ? Colors.black87 
                                    : Colors.white, 
                                fontSize: 11, 
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}