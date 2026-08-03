import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class HistorialMovimientosScreen extends StatefulWidget {
  const HistorialMovimientosScreen({super.key});

  @override
  State<HistorialMovimientosScreen> createState() => _HistorialMovimientosScreenState();
}

class _HistorialMovimientosScreenState extends State<HistorialMovimientosScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _clientes = [];
  List<Map<String, dynamic>> _movimientos = [];
  
  String? _clienteSeleccionadoId;
  bool _isLoading = true;
  bool _isLoadingMovimientos = false;

  @override
  void initState() {
    super.initState();
    _cargarClientes();
    _cargarMovimientos();
  }

  Future<void> _cargarClientes() async {
    try {
      final response = await _supabase
          .from('clientes')
          .select('id, nombre, documento')
          .order('nombre', ascending: true);

      if (mounted) {
        setState(() {
          _clientes = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      debugPrint('Error al cargar clientes: $e');
    }
  }

  Future<void> _cargarMovimientos() async {
  setState(() => _isLoadingMovimientos = true);
  try {
    var query = _supabase
        .from('movimientos_inventario')
        .select('''
          id,
          created_at,
          tipo,
          encargado_separacion,
          medio_envio,
          observaciones,
          imagen_url,
          clientes (id, nombre),
          detalle_movimientos (
            cantidad,
            productos (nombre, sku, condicion)
          )
        ''')
        .eq('tipo', 'SALIDA');

    if (_clienteSeleccionadoId != null) {
      query = query.eq('cliente_id', _clienteSeleccionadoId!);
    }

    final response = await query.order('created_at', ascending: false);

    if (mounted) {
      setState(() {
        _movimientos = List<Map<String, dynamic>>.from(response);
        _isLoading = false;
        _isLoadingMovimientos = false;
      });
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al cargar historial: $e'), backgroundColor: Colors.red),
      );
      setState(() {
        _isLoading = false;
        _isLoadingMovimientos = false;
      });
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial y Despachos por Cliente'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _cargarMovimientos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- FILTRO POR CLIENTE ---
                Container(
                  color: Colors.blueGrey[50],
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Filtrar por Cliente / Destinatario:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String?>(
                            isExpanded: true,
                            value: _clienteSeleccionadoId,
                            hint: const Text('Ver todos los clientes'),
                            items: [
                              const DropdownMenuItem<String?>(
                                value: null,
                                child: Text('Todos los Clientes / Despachos', style: TextStyle(fontWeight: FontWeight.bold)),
                              ),
                              ..._clientes.map((c) {
                                return DropdownMenuItem<String?>(
                                  value: c['id'].toString(),
                                  child: Text('${c['nombre']} (${c['documento'] ?? 'Sin doc'})'),
                                );
                              }),
                            ],
                            onChanged: (val) {
                              setState(() => _clienteSeleccionadoId = val);
                              _cargarMovimientos();
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // --- LISTADO DE MOVIMIENTOS / DESPACHOS ---
                Expanded(
                  child: _isLoadingMovimientos
                      ? const Center(child: CircularProgressIndicator())
                      : _movimientos.isEmpty
                          ? Center(
                              child: Text(
                                'No se encontraron despachos registrados.',
                                style: TextStyle(color: Colors.grey[600], fontSize: 15),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _movimientos.length,
                              itemBuilder: (ctx, index) {
                                final mov = _movimientos[index];
                                final clienteData = mov['clientes'] as Map<String, dynamic>?;
                                final nombreCliente = clienteData?['nombre'] ?? 'Cliente General / Consumo Interno';
                                final fecha = DateTime.parse(mov['created_at']).toLocal();
                                final fechaStr = "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}";
                                final detalles = (mov['detalle_movimientos'] as List<dynamic>?) ?? [];

                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  elevation: 2,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                  child: ExpansionTile(
                                    leading: CircleAvatar(
                                      backgroundColor: Colors.blueGrey[100],
                                      child: const Icon(Icons.local_shipping, color: Colors.blueGrey),
                                    ),
                                    title: Text(
                                      nombreCliente,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                    ),
                                    subtitle: Text(
                                      'Fecha: $fechaStr\nItems: ${detalles.length} producto(s)',
                                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                    ),
                                    children: [
                                      Padding(
                                        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const Divider(),
                                            if (mov['encargado_separacion'] != null)
                                              Text('Despachado por: ${mov['encargado_separacion']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                            if (mov['medio_envio'] != null)
                                              Text('Medio de Envío: ${mov['medio_envio']}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
                                            if (mov['observaciones'] != null && (mov['observaciones'] as String).isNotEmpty)
                                              Text(
                                                'Notas: ${mov['observaciones']}',
                                                style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[800]),
                                              ),
                                            const SizedBox(height: 10),
                                            const Text('Detalle de Productos:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                            const SizedBox(height: 5),
                                            
                                            // Lista de productos entregados
                                            ...detalles.map((d) {
                                              final prod = d['productos'] as Map<String, dynamic>?;
                                              return Container(
                                                margin: const EdgeInsets.symmetric(vertical: 2),
                                                padding: const EdgeInsets.all(8),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey[100],
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '• ${prod?['nombre'] ?? 'Producto'} (${prod?['sku'] ?? 'Sin SKU'})',
                                                        style: const TextStyle(fontSize: 13),
                                                      ),
                                                    ),
                                                    Text(
                                                      'Cant: ${d['cantidad']}',
                                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            }),

                                            const SizedBox(height: 10),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                ),
              ],
            ),
    );
  }
}