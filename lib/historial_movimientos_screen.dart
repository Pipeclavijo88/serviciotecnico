import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

class HistorialMovimientosScreen extends StatefulWidget {
  const HistorialMovimientosScreen({super.key});

  @override
  State<HistorialMovimientosScreen> createState() => _HistorialMovimientosScreenState();
}

class _HistorialMovimientosScreenState extends State<HistorialMovimientosScreen> {
  final _supabase = Supabase.instance.client;

  List<Map<String, dynamic>> _movimientos = [];
  List<Map<String, dynamic>> _movimientosFiltrados = [];

  // Listas para desplegables de filtro
  List<String> _listaClientes = ['Todos los Clientes / Destinatarios'];
  List<String> _listaEncargados = ['Todos los Encargados'];

  // Estados de Filtros
  String _clienteSeleccionado = 'Todos los Clientes / Destinatarios';
  String _encargadoSeleccionado = 'Todos los Encargados';
  final _productoFiltroController = TextEditingController();
  DateTime? _fechaInicio;
  DateTime? _fechaFin;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarMovimientos();
  }

  Future<void> _cargarMovimientos() async {
    setState(() => _isLoading = true);
    try {
      // Cargar movimientos con sus detalles e información del producto
      final response = await _supabase
          .from('movimientos_inventario')
          .select('''
            *,
            detalle_movimientos (
              cantidad,
              productos (nombre, sku, condicion)
            )
          ''')
          .order('id', ascending: false);

      final list = List<Map<String, dynamic>>.from(response);

      // Extraer lista única de Clientes/Destinatarios
      final setClientes = <String>{'Todos los Clientes / Destinatarios'};
      final setEncargados = <String>{'Todos los Encargados'};

      for (var m in list) {
        final dest = (m['entregado_a'] ?? m['proveedor_causa'] ?? m['proveedor'] ?? m['cliente'] ?? '').toString().trim();
        if (dest.isNotEmpty) setClientes.add(dest);

        final enc = (m['recibido_por'] ?? m['encargado_separacion'] ?? m['tecnico_bodeguero'] ?? '').toString().trim();
        if (enc.isNotEmpty) setEncargados.add(enc);
      }

      if (mounted) {
        setState(() {
          _movimientos = list;
          _listaClientes = setClientes.toList();
          _listaEncargados = setEncargados.toList();
          _aplicarFiltros();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar historial: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _aplicarFiltros() {
    setState(() {
      _movimientosFiltrados = _movimientos.where((m) {
        // 1. Filtro por Cliente / Destinatario
        final destinatario = (m['entregado_a'] ?? m['proveedor_causa'] ?? m['proveedor'] ?? m['cliente'] ?? '').toString().trim();
        if (_clienteSeleccionado != 'Todos los Clientes / Destinatarios' && destinatario != _clienteSeleccionado) {
          return false;
        }

        // 2. Filtro por Encargado / Separado por
        final encargado = (m['recibido_por'] ?? m['encargado_separacion'] ?? m['tecnico_bodeguero'] ?? '').toString().trim();
        if (_encargadoSeleccionado != 'Todos los Encargados' && encargado != _encargadoSeleccionado) {
          return false;
        }

        // 3. Filtro por Producto (Nombre o SKU)
        final queryProd = _productoFiltroController.text.trim().toLowerCase();
        if (queryProd.isNotEmpty) {
          final detalles = (m['detalle_movimientos'] as List<dynamic>?) ?? [];
          final coincideProducto = detalles.any((d) {
            final prod = d['productos'] as Map<String, dynamic>?;
            if (prod == null) return false;
            final nombre = (prod['nombre'] ?? '').toString().toLowerCase();
            final sku = (prod['sku'] ?? '').toString().toLowerCase();
            return nombre.contains(queryProd) || sku.contains(queryProd);
          });
          if (!coincideProducto) return false;
        }

        // 4. Filtro por Rango de Fechas
        final fechaRaw = m['created_at'] ?? m['fecha'] ?? m['fecha_movimiento'];
        if (fechaRaw != null) {
          final fechaMov = DateTime.tryParse(fechaRaw.toString());
          if (fechaMov != null) {
            if (_fechaInicio != null && fechaMov.isBefore(_fechaInicio!)) return false;
            if (_fechaFin != null && fechaMov.isAfter(_fechaFin!.add(const Duration(days: 1)))) return false;
          }
        }
        return true;
      }).toList();
    });
  }

  void _limpiarFiltros() {
    setState(() {
      _clienteSeleccionado = 'Todos los Clientes / Destinatarios';
      _encargadoSeleccionado = 'Todos los Encargados';
      _productoFiltroController.clear();
      _fechaInicio = null;
      _fechaFin = null;
      _aplicarFiltros();
    });
  }

  void _exportarAExcel() {
    if (_movimientosFiltrados.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No hay registros para exportar'), backgroundColor: Colors.orange),
      );
      return;
    }

    StringBuffer csv = StringBuffer();
    csv.writeln('ID,Tipo Movimiento,Canal/Subtipo,Cliente/Proveedor,Recibido/Encargado,Factura/Remision,Observaciones,Productos,Fecha');

    for (var m in _movimientosFiltrados) {
      final id = m['id'] ?? '';
      final tipo = m['tipo_movimiento'] ?? m['tipo'] ?? '';
      final canal = m['canal_atencion'] ?? m['subtipo'] ?? '';
      final dest = (m['entregado_a'] ?? m['proveedor_causa'] ?? m['proveedor'] ?? '').toString().replaceAll(',', ' ');
      final encargado = (m['recibido_por'] ?? m['encargado_separacion'] ?? '').toString().replaceAll(',', ' ');
      final factura = (m['numero_factura'] ?? m['factura_remision'] ?? '').toString().replaceAll(',', ' ');
      final obs = (m['observaciones'] ?? '').toString().replaceAll('\n', ' ').replaceAll(',', ' ');
      final fecha = m['created_at'] ?? m['fecha'] ?? '';

      final detalles = (m['detalle_movimientos'] as List<dynamic>?) ?? [];
      final prodStr = detalles.map((d) {
        final prod = d['productos'] as Map<String, dynamic>?;
        return '${prod?['nombre'] ?? 'Prod'} (x${d['cantidad']})';
      }).join('; ').replaceAll(',', ' ');

      csv.writeln('"$id","$tipo","$canal","$dest","$encargado","$factura","$obs","$prodStr","$fecha"');
    }

    final bytes = utf8.encode(csv.toString());
    final blob = html.Blob([bytes], 'text/csv;charset=utf-8');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..setAttribute('download', 'reporte_movimientos_myp_${DateTime.now().millisecondsSinceEpoch}.csv')
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Historial y Despachos de Inventario'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Exportar Reporte a Excel (CSV)',
            onPressed: _exportarAExcel,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar Lista',
            onPressed: _cargarMovimientos,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // PANEL DE FILTROS MULTIPLE
                Container(
                  color: Colors.blueGrey[50],
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          // Filtro por Cliente / Destinatario
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _clienteSeleccionado,
                              decoration: const InputDecoration(
                                labelText: 'Cliente / Destinatario',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              items: _listaClientes.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _clienteSeleccionado = val);
                                  _aplicarFiltros();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Filtro por Encargado
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              value: _encargadoSeleccionado,
                              decoration: const InputDecoration(
                                labelText: 'Separado / Recibido por',
                                border: OutlineInputBorder(),
                                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                fillColor: Colors.white,
                                filled: true,
                              ),
                              items: _listaEncargados.map((e) => DropdownMenuItem(value: e, child: Text(e, style: const TextStyle(fontSize: 13)))).toList(),
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _encargadoSeleccionado = val);
                                  _aplicarFiltros();
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          // Buscar por Producto (Nombre o SKU)
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _productoFiltroController,
                              decoration: InputDecoration(
                                labelText: 'Buscar por Producto o SKU',
                                prefixIcon: const Icon(Icons.search, size: 20),
                                border: const OutlineInputBorder(),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                                fillColor: Colors.white,
                                filled: true,
                                suffixIcon: _productoFiltroController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.clear, size: 18),
                                        onPressed: () {
                                          _productoFiltroController.clear();
                                          _aplicarFiltros();
                                        },
                                      )
                                    : null,
                              ),
                              onChanged: (_) => _aplicarFiltros(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botón Fecha Desde
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                              icon: const Icon(Icons.date_range, size: 16),
                              label: Text(
                                _fechaInicio == null
                                    ? 'Desde'
                                    : '${_fechaInicio!.day}/${_fechaInicio!.month}/${_fechaInicio!.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  _fechaInicio = picked;
                                  _aplicarFiltros();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Botón Fecha Hasta
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(backgroundColor: Colors.white),
                              icon: const Icon(Icons.date_range, size: 16),
                              label: Text(
                                _fechaFin == null
                                    ? 'Hasta'
                                    : '${_fechaFin!.day}/${_fechaFin!.month}/${_fechaFin!.year}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: DateTime.now(),
                                  firstDate: DateTime(2024),
                                  lastDate: DateTime(2030),
                                );
                                if (picked != null) {
                                  _fechaFin = picked;
                                  _aplicarFiltros();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.filter_alt_off, color: Colors.red),
                            tooltip: 'Limpiar Todos los Filtros',
                            onPressed: _limpiarFiltros,
                          )
                        ],
                      ),
                    ],
                  ),
                ),

                // LISTA DE RESULTADOS
                Expanded(
                  child: _movimientosFiltrados.isEmpty
                      ? Center(
                          child: Text(
                            'No se encontraron movimientos con los filtros seleccionados.',
                            style: TextStyle(color: Colors.grey[600], fontSize: 15),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _movimientosFiltrados.length,
                          itemBuilder: (ctx, index) {
                            final mov = _movimientosFiltrados[index];
                            final tipoMov = (mov['tipo_movimiento'] ?? mov['tipo'] ?? 'Movimiento').toString();
                            final esEntrada = tipoMov.toLowerCase().contains('entrada');

                            final destinatario = (mov['entregado_a'] ?? mov['proveedor_causa'] ?? mov['proveedor'] ?? 'Cliente General').toString();
                            final factura = (mov['numero_factura'] ?? mov['factura_remision'] ?? 'N/A').toString();
                            final encargado = mov['recibido_por'] ?? mov['encargado_separacion'] ?? mov['tecnico_bodeguero'];

                            DateTime? fecha;
                            final fechaRaw = mov['created_at'] ?? mov['fecha'] ?? mov['fecha_movimiento'];
                            if (fechaRaw != null) {
                              fecha = DateTime.tryParse(fechaRaw.toString())?.toLocal();
                            }
                            final fechaStr = fecha != null
                                ? "${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}/${fecha.year} ${fecha.hour}:${fecha.minute.toString().padLeft(2, '0')}"
                                : 'Fecha no especificada';

                            final detalles = (mov['detalle_movimientos'] as List<dynamic>?) ?? [];

                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              child: ExpansionTile(
                                leading: CircleAvatar(
                                  backgroundColor: esEntrada ? Colors.green[100] : Colors.orange[100],
                                  child: Icon(
                                    esEntrada ? Icons.arrow_downward : Icons.local_shipping,
                                    color: esEntrada ? Colors.green[800] : Colors.orange[800],
                                  ),
                                ),
                                title: Text(
                                  '$tipoMov - $destinatario',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Text(
                                  'Fecha: $fechaStr\nFactura/Remisión: $factura',
                                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                                ),
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Divider(),
                                        if (encargado != null && encargado.toString().isNotEmpty)
                                          Text(
                                            'Encargado / Recibido por: $encargado',
                                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                          ),
                                        if (mov['observaciones'] != null && (mov['observaciones'] as String).isNotEmpty)
                                          Text(
                                            'Observaciones: ${mov['observaciones']}',
                                            style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic, color: Colors.grey[800]),
                                          ),
                                        const SizedBox(height: 10),
                                        const Text('Productos Registrados:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                        const SizedBox(height: 5),
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