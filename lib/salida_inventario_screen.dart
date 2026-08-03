import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage_service.dart';

class SalidaInventarioScreen extends StatefulWidget {
  const SalidaInventarioScreen({super.key});

  @override
  State<SalidaInventarioScreen> createState() => _SalidaInventarioScreenState();
}

class _SalidaInventarioScreenState extends State<SalidaInventarioScreen> {
  final _supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controladores de texto para mantener los valores sin borrarse al reconstruir
  final _encargadoSeparacionCtrl = TextEditingController();
  final _entregadoACtrl = TextEditingController();
  final _detalleMedioEnvioCtrl = TextEditingController();
  final _numeroFacturaCtrl = TextEditingController();
  final _observacionesCtrl = TextEditingController();

  String _canalAtencion = 'Cliente Final';
  String _medioDespacho = 'Personal';

  List<Map<String, dynamic>> _listaClientes = [];
  List<Map<String, dynamic>> _listaProductos = [];

  Map<String, dynamic>? _clienteSeleccionado;
  String? _fotoUrl;

  bool _cargando = false;
  bool _subiendoFoto = false;

  final List<Map<String, dynamic>> _itemsSalida = [];

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  @override
  void dispose() {
    _encargadoSeparacionCtrl.dispose();
    _entregadoACtrl.dispose();
    _detalleMedioEnvioCtrl.dispose();
    _numeroFacturaCtrl.dispose();
    _observacionesCtrl.dispose();
    super.dispose();
  }

  Future<void> _cargarDatosIniciales() async {
    setState(() => _cargando = true);
    try {
      final resClientes = await _supabase.from('clientes').select();
      final resProductos = await _supabase.from('productos').select();

      if (mounted) {
        setState(() {
          _listaClientes = List<Map<String, dynamic>>.from(resClientes);
          _listaProductos = List<Map<String, dynamic>>.from(resProductos);
        });
      }
    } catch (e) {
      if (mounted) _mostrarSnackBar('Error al cargar datos iniciales: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _mostrarSnackBar(String msj) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msj)));
  }

  Future<void> _crearClienteAlVuelo(String nombreIngresado) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cliente no registrado'),
        content: Text('El cliente "$nombreIngresado" no existe. ¿Deseas registrarlo en la base de datos?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Registrar')),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final nuevo = await _supabase.from('clientes').insert({
          'nombre': nombreIngresado,
          'tipo_cliente': _canalAtencion == 'Instalador' ? 'Instalador' : 'Cliente Final',
        }).select().single();

        final resClientes = await _supabase.from('clientes').select();
        
        if (mounted) {
          setState(() {
            _listaClientes = List<Map<String, dynamic>>.from(resClientes);
            _clienteSeleccionado = nuevo;
          });
          _mostrarSnackBar('Cliente registrado con éxito.');
        }
      } catch (e) {
        if (mounted) _mostrarSnackBar('Error al registrar cliente: $e');
      }
    }
  }

  Future<void> _agregarOBuscarProducto(String termino) async {
    final coincidencias = _listaProductos.where((p) {
      final nom = (p['nombre'] ?? '').toString().toLowerCase();
      final sku = (p['sku'] ?? '').toString().toLowerCase();
      return nom.contains(termino.toLowerCase()) || sku.contains(termino.toLowerCase());
    }).toList();

    if (coincidencias.isNotEmpty) {
      _seleccionarCantidadYAgregar(coincidencias.first);
    } else {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Producto no encontrado'),
          content: Text('El producto "$termino" no está registrado en el inventario. ¿Deseas darlo de alta ahora?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Sí, registrar')),
          ],
        ),
      );

      if (confirm == true && mounted) {
        _registrarNuevoProductoAlVuelo(termino);
      }
    }
  }

  Future<void> _registrarNuevoProductoAlVuelo(String nombreInicial) async {
    String condicion = 'Nuevo';
    final controllerNombre = TextEditingController(text: nombreInicial);
    final controllerSku = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Dar de alta producto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controllerNombre,
                decoration: const InputDecoration(labelText: 'Nombre del Producto'),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: condicion,
                decoration: const InputDecoration(labelText: 'Condición del Producto'),
                items: const [
                  DropdownMenuItem(value: 'Nuevo', child: Text('Nuevo')),
                  DropdownMenuItem(value: 'Usado', child: Text('Usado (Segunda Mano)')),
                ],
                onChanged: (val) {
                  setDialogState(() {
                    condicion = val!;
                    if (condicion == 'Usado') {
                      controllerSku.text = '9${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                    } else {
                      controllerSku.clear();
                    }
                  });
                },
              ),
              const SizedBox(height: 10),
              TextField(
                controller: controllerSku,
                decoration: InputDecoration(
                  labelText: 'SKU / Código',
                  hintText: condicion == 'Usado' ? 'Generado autom. (Serie 9000)' : 'Ej: MOT-800',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
            ElevatedButton(
              onPressed: () async {
                String nombreFinal = controllerNombre.text.trim();
                String skuFinal = controllerSku.text.trim();

                if (condicion == 'Usado') {
                  if (!nombreFinal.toUpperCase().startsWith('USADO')) {
                    nombreFinal = 'USADO - $nombreFinal';
                  }
                  if (skuFinal.isEmpty) {
                    skuFinal = '9${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
                  }
                } else if (skuFinal.isEmpty) {
                  skuFinal = 'PROD-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                }

                try {
                  final nuevoProd = await _supabase.from('productos').insert({
                    'sku': skuFinal,
                    'nombre': nombreFinal,
                    'condicion': condicion,
                    'stock_actual': 0,
                  }).select().single();

                  final resProductos = await _supabase.from('productos').select();

                  if (ctx.mounted) Navigator.pop(ctx);
                  
                  if (mounted) {
                    setState(() {
                      _listaProductos = List<Map<String, dynamic>>.from(resProductos);
                    });
                    _seleccionarCantidadYAgregar(nuevoProd);
                  }
                } catch (e) {
                  if (ctx.mounted) _mostrarSnackBar('Error al crear producto: $e');
                }
              },
              child: const Text('Guardar e Ingresar'),
            ),
          ],
        ),
      ),
    );
  }

  void _seleccionarCantidadYAgregar(Map<String, dynamic> producto) {
    int cantidad = 1;
    final int stockActual = producto['stock_actual'] ?? 0;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Agregar ${producto['nombre']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stock disponible: $stockActual'),
            if (stockActual <= 0)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  '⚠️ Sin stock suficiente. El producto se registrará con saldo negativo (-1) y quedará "Pendiente por Reponer".',
                  style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold),
                ),
              ),
            TextFormField(
              initialValue: '1',
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad a entregar'),
              onChanged: (v) => cantidad = int.tryParse(v) ?? 1,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _itemsSalida.add({
                  'producto': producto,
                  'cantidad': cantidad,
                  'es_faltante': (stockActual - cantidad) < 0,
                });
              });
              Navigator.pop(ctx);
            },
            child: const Text('Agregar a Salida'),
          ),
        ],
      ),
    );
  }

  Future<void> _capturarFoto(ImageSource origen) async {
    setState(() => _subiendoFoto = true);
    final url = await InventarioStorageService.capturarYSubirFoto(origen: origen);
    if (mounted) {
      setState(() {
        _subiendoFoto = false;
        if (url != null) {
          _fotoUrl = url;
          _mostrarSnackBar('Foto cargada correctamente.');
        } else {
          _mostrarSnackBar('No se pudo subir la foto.');
        }
      });
    }
  }

  Future<void> _guardarSalida() async {
    if (!_formKey.currentState!.validate()) return;
    if (_itemsSalida.isEmpty) {
      _mostrarSnackBar('Debes agregar al menos un producto para registrar la salida.');
      return;
    }

    setState(() => _cargando = true);
    try {
      final mov = await _supabase.from('movimientos_inventario').insert({
        'tipo_movimiento': 'Salida',
        'canal_atencion': _canalAtencion,
        'numero_factura': _numeroFacturaCtrl.text.trim().isEmpty ? null : _numeroFacturaCtrl.text.trim(),
        'id_cliente': _clienteSeleccionado?['id'],
        'encargado_separacion': _encargadoSeparacionCtrl.text.trim(),
        'entregado_a': _entregadoACtrl.text.trim(),
        'medio_despacho': '$_medioDespacho: ${_detalleMedioEnvioCtrl.text.trim()}',
        'foto_url': _fotoUrl,
        'observaciones': _observacionesCtrl.text.trim(),
      }).select().single();

      final String idMov = mov['id'];

      for (final item in _itemsSalida) {
        final prod = item['producto'];
        final int cant = item['cantidad'];
        final bool esFaltante = item['es_faltante'];

        await _supabase.from('detalle_movimientos').insert({
          'id_movimiento': idMov,
          'id_producto': prod['id'],
          'cantidad': cant,
          'es_faltante': esFaltante,
        });

        final int nuevoStock = (prod['stock_actual'] ?? 0) - cant;
        await _supabase
            .from('productos')
            .update({'stock_actual': nuevoStock})
            .eq('id', prod['id']);
      }

      if (mounted) {
        _mostrarSnackBar('¡Salida de mercancía registrada con éxito!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) _mostrarSnackBar('Error al registrar salida: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Salida de Mercancía (MYP)'),
        backgroundColor: Colors.blueGrey[800],
        foregroundColor: Colors.white,
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- CANAL DE ATENCIÓN ---
                    const Text('Canal de Atención', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      child: SegmentedButton<String>(
                        segments: const [
                          ButtonSegment<String>(
                            value: 'Cliente Final',
                            label: Text('Cliente Final'),
                            icon: Icon(Icons.person),
                          ),
                          ButtonSegment<String>(
                            value: 'Instalador',
                            label: Text('Instalador'),
                            icon: Icon(Icons.build),
                          ),
                          ButtonSegment<String>(
                            value: 'Consumo Interno',
                            label: Text('Consumo Interno'),
                            icon: Icon(Icons.store),
                          ),
                        ],
                        selected: {_canalAtencion},
                        onSelectionChanged: (Set<String> newSelection) {
                          setState(() {
                            _canalAtencion = newSelection.first;
                          });
                        },
                      ),
                    ),
                    const Divider(height: 30),

                    // --- SELECCIÓN / BÚSQUEDA DE CLIENTE ---
                    if (_canalAtencion != 'Consumo Interno') ...[
                      const Text('Cliente / Instalador', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Autocomplete<Map<String, dynamic>>(
                        displayStringForOption: (option) => option['nombre'] ?? '',
                        optionsBuilder: (textEditingValue) {
                          if (textEditingValue.text.isEmpty) return const Iterable.empty();
                          return _listaClientes.where((c) => (c['nombre'] ?? '')
                              .toString()
                              .toLowerCase()
                              .contains(textEditingValue.text.toLowerCase()));
                        },
                        onSelected: (option) => setState(() => _clienteSeleccionado = option),
                        fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                          return TextFormField(
                            controller: controller,
                            focusNode: focusNode,
                            decoration: InputDecoration(
                              labelText: 'Buscar Cliente / Instalador',
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.person_add),
                                onPressed: () => _crearClienteAlVuelo(controller.text.trim()),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 15),
                    ],

                    // --- QUIÉN SEPARÓ Y ENTREGA ---
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _encargadoSeparacionCtrl,
                            decoration: const InputDecoration(labelText: 'Encargado de Separación'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _entregadoACtrl,
                            decoration: const InputDecoration(labelText: 'A quién se entrega'),
                            validator: (v) => v == null || v.trim().isEmpty ? 'Requerido' : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),

                    // --- MEDIO DE ENTREGA Y FACTURA ---
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: _medioDespacho,
                            decoration: const InputDecoration(labelText: 'Medio de Despacho'),
                            items: const [
                              DropdownMenuItem(value: 'Personal', child: Text('Entrega Personal')),
                              DropdownMenuItem(value: 'Transportadora/Envío', child: Text('Transportadora / Envíos')),
                            ],
                            onChanged: (v) => setState(() => _medioDespacho = v!),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _detalleMedioEnvioCtrl,
                            decoration: const InputDecoration(labelText: 'Detalle Medio (ej. Servientrega, Moto)'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    TextFormField(
                      controller: _numeroFacturaCtrl,
                      decoration: const InputDecoration(labelText: 'No. Factura / Remisión (Opcional)'),
                    ),
                    const Divider(height: 30),

                    // --- BÚSQUEDA Y SELECCIÓN DE PRODUCTOS ---
                    const Text('Productos a Entregar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Autocomplete<Map<String, dynamic>>(
                      displayStringForOption: (option) => '${option['sku']} - ${option['nombre']} (Stock: ${option['stock_actual']})',
                      optionsBuilder: (textEditingValue) {
                        if (textEditingValue.text.isEmpty) return const Iterable.empty();
                        return _listaProductos.where((p) {
                          final nom = (p['nombre'] ?? '').toString().toLowerCase();
                          final sku = (p['sku'] ?? '').toString().toLowerCase();
                          return nom.contains(textEditingValue.text.toLowerCase()) ||
                              sku.contains(textEditingValue.text.toLowerCase());
                        });
                      },
                      onSelected: (option) => _seleccionarCantidadYAgregar(option),
                      fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                        return TextFormField(
                          controller: controller,
                          focusNode: focusNode,
                          decoration: InputDecoration(
                            labelText: 'Buscar producto (por nombre o SKU)',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () => _agregarOBuscarProducto(controller.text.trim()),
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10),

                    // Lista de productos seleccionados
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _itemsSalida.length,
                      itemBuilder: (ctx, idx) {
                        final item = _itemsSalida[idx];
                        final prod = item['producto'];
                        return Card(
                          child: ListTile(
                            title: Text(prod['nombre']),
                            subtitle: Text('SKU: ${prod['sku']} | Cantidad: ${item['cantidad']} ${item['es_faltante'] ? '(Faltante en Bodega)' : ''}'),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () => setState(() => _itemsSalida.removeAt(idx)),
                            ),
                          ),
                        );
                      },
                    ),

                    const Divider(height: 30),

                    // --- EVIDENCIA FOTOGRÁFICA ---
                    const Text('Evidencia Fotográfica', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _subiendoFoto ? null : () => _capturarFoto(ImageSource.camera),
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Tomar Foto'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton.icon(
                          onPressed: _subiendoFoto ? null : () => _capturarFoto(ImageSource.gallery),
                          icon: const Icon(Icons.photo_library),
                          label: const Text('Galería'),
                        ),
                      ],
                    ),
                    if (_subiendoFoto)
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0),
                        child: Row(
                          children: [
                            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                            SizedBox(width: 10),
                            Text('Comprimiendo y subiendo foto...'),
                          ],
                        ),
                      ),
                    if (_fotoUrl != null) ...[
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(_fotoUrl!, height: 120, fit: BoxFit.cover),
                      ),
                    ],

                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _observacionesCtrl,
                      decoration: const InputDecoration(labelText: 'Observaciones generales'),
                      maxLines: 2,
                    ),

                    const SizedBox(height: 30),

                    // --- BOTÓN REGISTRAR SALIDA ---
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueGrey[800],
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _guardarSalida,
                        child: const Text('REGISTRAR SALIDA DE MERCANCÍA', style: TextStyle(fontSize: 16)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}