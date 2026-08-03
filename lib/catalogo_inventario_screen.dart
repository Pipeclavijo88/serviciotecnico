import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CatalogoInventarioScreen extends StatefulWidget {
  const CatalogoInventarioScreen({super.key});

  @override
  State<CatalogoInventarioScreen> createState() => _CatalogoInventarioScreenState();
}

class _CatalogoInventarioScreenState extends State<CatalogoInventarioScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _productos = [];
  List<Map<String, dynamic>> _productosFiltrados = [];
  bool _isLoading = true;

  String _busqueda = '';
  String? _tipoSeleccionado;
  bool _soloPendientesReponer = false;

  final List<String> _tiposDisponibles = [
    'Motores Corredizos',
    'Brazos',
    'Tarjetas',
    'Chapas',
    'Motores Cortina Centrales',
    'Motores Cortina Laterales',
    'Motores Levadizos',
    'Controles',
    'Sensores',
    'Sistemas de Apertura',
    'Insumos',
    'Accesorios'
  ];

  @override
  void initState() {
    super.initState();
    _cargarProductos();
  }

  Future<void> _cargarProductos() async {
    setState(() => _isLoading = true);
    try {
      final response = await _supabase
          .from('productos')
          .select('id, nombre, sku, condicion, stock_actual, stock_minimo, tipo')
          .order('nombre', ascending: true);

      if (mounted) {
        setState(() {
          _productos = List<Map<String, dynamic>>.from(response);
          _aplicarFiltros();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar catálogo: $e'), backgroundColor: Colors.red),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _productosFiltrados = _productos.where((p) {
        final nombre = (p['nombre'] ?? '').toString().toLowerCase();
        final sku = (p['sku'] ?? '').toString().toLowerCase();
        final query = _busqueda.toLowerCase();

        final coincideBusqueda = nombre.contains(query) || sku.contains(query);

        final tipoProd = p['tipo']?.toString();
        final coincideTipo = _tipoSeleccionado == null || tipoProd == _tipoSeleccionado;

        final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
        final minStock = (p['stock_minimo'] as num?)?.toInt() ?? 0;
        final esPendienteReponer = stock < minStock || stock < 0;

        final coincideReponer = !_soloPendientesReponer || esPendienteReponer;

        return coincideBusqueda && coincideTipo && coincideReponer;
      }).toList();
    });
  }

  void _mostrarEditarProductoModal(Map<String, dynamic> prod) {
    final nombreController = TextEditingController(text: prod['nombre']);
    final skuController = TextEditingController(text: prod['sku'] ?? '');
    final stockMinimoController = TextEditingController(text: (prod['stock_minimo'] ?? 2).toString());
    String condicion = prod['condicion'] ?? 'Nuevo';
    String tipoSeleccionado = _tiposDisponibles.contains(prod['tipo']) ? prod['tipo'] : _tiposDisponibles.last;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Editar Configuración de Producto', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre del Producto'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: skuController,
                      decoration: const InputDecoration(labelText: 'SKU / Código'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: tipoSeleccionado,
                      decoration: const InputDecoration(labelText: 'Tipo de Producto'),
                      items: _tiposDisponibles.map((t) {
                        return DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setModalState(() => tipoSeleccionado = val);
                      },
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: stockMinimoController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Stock Mínimo (Alerta de Reposición)'),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      initialValue: condicion,
                      decoration: const InputDecoration(labelText: 'Condición'),
                      items: const [
                        DropdownMenuItem(value: 'Nuevo', child: Text('Nuevo')),
                        DropdownMenuItem(value: 'Usado', child: Text('Usado / Reacondicionado')),
                      ],
                      onChanged: (val) {
                        if (val != null) setModalState(() => condicion = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueGrey[800], foregroundColor: Colors.white),
                  onPressed: () async {
                    try {
                      await _supabase.from('productos').update({
                        'nombre': nombreController.text.trim(),
                        'sku': skuController.text.trim().isEmpty ? null : skuController.text.trim(),
                        'tipo': tipoSeleccionado,
                        'stock_minimo': int.tryParse(stockMinimoController.text) ?? 2,
                        'condicion': condicion,
                      }).eq('id', prod['id']);

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        _cargarProductos();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Producto actualizado'), backgroundColor: Colors.green),
                        );
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar Cambios'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  int get _totalPendientesReponer {
    return _productos.where((p) {
      final stock = (p['stock_actual'] as num?)?.toInt() ?? 0;
      final minStock = (p['stock_minimo'] as num?)?.toInt() ?? 0;
      return stock < minStock || stock < 0;
    }).length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo y Saldos de Inventario'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _cargarProductos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Container(
                  color: Colors.blueGrey[50],
                  padding: const EdgeInsets.all(12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMetricCard(
                          titulo: 'Total Ítems',
                          valor: _productos.length.toString(),
                          color: Colors.blueGrey[700]!,
                          activo: !_soloPendientesReponer,
                          onTap: () {
                            setState(() => _soloPendientesReponer = false);
                            _aplicarFiltros();
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _buildMetricCard(
                          titulo: 'Pendientes Reponer',
                          valor: _totalPendientesReponer.toString(),
                          color: Colors.orange[800]!,
                          activo: _soloPendientesReponer,
                          onTap: () {
                            setState(() => _soloPendientesReponer = true);
                            _aplicarFiltros();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          decoration: InputDecoration(
                            hintText: 'Buscar por nombre o SKU...',
                            prefixIcon: const Icon(Icons.search),
                            isDense: true,
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onChanged: (val) {
                            _busqueda = val;
                            _aplicarFiltros();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),

                      Expanded(
                        flex: 2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey[400]!),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String?>(
                              isExpanded: true,
                              value: _tipoSeleccionado,
                              hint: const Text('Todos los Tipos', style: TextStyle(fontSize: 13)),
                              items: [
                                const DropdownMenuItem<String?>(
                                  value: null,
                                  child: Text('Todos los Tipos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                ),
                                ..._tiposDisponibles.map((t) {
                                  return DropdownMenuItem<String?>(
                                    value: t,
                                    child: Text(t, style: const TextStyle(fontSize: 13)),
                                  );
                                }),
                              ],
                              onChanged: (val) {
                                setState(() => _tipoSeleccionado = val);
                                _aplicarFiltros();
                              },
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                Expanded(
                  child: _productosFiltrados.isEmpty
                      ? Center(
                          child: Text(
                            'No se encontraron productos con los filtros aplicados.',
                            style: TextStyle(color: Colors.grey[600]),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _productosFiltrados.length,
                          itemBuilder: (ctx, index) {
                            final prod = _productosFiltrados[index];
                            final stock = (prod['stock_actual'] as num?)?.toInt() ?? 0;
                            final minStock = (prod['stock_minimo'] as num?)?.toInt() ?? 0;
                            final condicion = prod['condicion'] ?? 'Nuevo';
                            final tipoProd = prod['tipo'] ?? 'Accesorios';

                            final reponer = stock < minStock || stock < 0;

                            return Card(
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                              child: ListTile(
                                onTap: () => _mostrarEditarProductoModal(prod),
                                leading: CircleAvatar(
                                  backgroundColor: reponer ? Colors.red[50] : Colors.green[50],
                                  child: Icon(
                                    reponer ? Icons.warning_amber_rounded : Icons.inventory_2_outlined,
                                    color: reponer ? Colors.red[700] : Colors.green[700],
                                  ),
                                ),
                                title: Text(
                                  prod['nombre'] ?? 'Sin Nombre',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                subtitle: Text(
                                  'SKU: ${prod['sku'] ?? 'N/A'} | Tipo: $tipoProd\nCondición: $condicion | Mínimo: $minStock (Haz clic para editar)',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                trailing: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: stock < 0
                                        ? Colors.red[800]
                                        : (reponer ? Colors.orange[800] : Colors.green[700]),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'Stock: $stock',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildMetricCard({
    required String titulo,
    required String valor,
    required Color color,
    required bool activo,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: activo ? color : color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color, width: activo ? 2 : 1),
        ),
        child: Column(
          children: [
            Text(
              titulo,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: activo ? Colors.white : color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              valor,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: activo ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}