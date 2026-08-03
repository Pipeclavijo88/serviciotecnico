import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EntradaInventarioScreen extends StatefulWidget {
  const EntradaInventarioScreen({super.key});

  @override
  State<EntradaInventarioScreen> createState() => _EntradaInventarioScreenState();
}

class _EntradaInventarioScreenState extends State<EntradaInventarioScreen> {
  final _supabase = Supabase.instance.client;

  String _tipoEntrada = 'Compra'; 
  final _proveedorController = TextEditingController();
  final _facturaController = TextEditingController();
  final _recibidoPorController = TextEditingController();
  final _observacionesController = TextEditingController();

  List<Map<String, dynamic>> _productosDisponibles = [];
  final List<Map<String, dynamic>> _itemsEntrada = [];

  final _busquedaProductoController = TextEditingController();
  bool _isLoading = false;
  XFile? _imagenSoporte;

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
    try {
      final data = await _supabase
          .from('productos')
          .select('id, nombre, sku, stock_actual, condicion, stock_minimo, tipo')
          .order('nombre');
      if (mounted) {
        setState(() {
          _productosDisponibles = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint('Error al cargar productos: $e');
    }
  }

  Future<void> _tomarFoto(ImageSource source) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: source, imageQuality: 70);
    if (image != null) {
      setState(() => _imagenSoporte = image);
    }
  }

  void _agregarItemABag(Map<String, dynamic> producto) {
    setState(() {
      final index = _itemsEntrada.indexWhere((item) => item['producto_id'] == producto['id']);
      if (index >= 0) {
        _itemsEntrada[index]['cantidad'] += 1;
      } else {
        _itemsEntrada.add({
          'producto_id': producto['id'],
          'nombre': producto['nombre'],
          'sku': producto['sku'],
          'cantidad': 1,
        });
      }
      _busquedaProductoController.clear();
    });
  }

  void _mostrarCrearProductoModal(String busquedaInicial) {
    final nombreController = TextEditingController(text: busquedaInicial);
    final skuController = TextEditingController();
    final stockMinimoController = TextEditingController(text: '2');
    String condicion = 'Nuevo';
    String tipoSeleccionado = _tiposDisponibles.first;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              title: const Text('Nuevo Producto', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nombreController,
                      decoration: const InputDecoration(labelText: 'Nombre del Producto *'),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: skuController,
                      decoration: const InputDecoration(labelText: 'SKU / Código (Opcional)'),
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
                      decoration: const InputDecoration(labelText: 'Stock Mínimo para Alerta'),
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
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                  onPressed: () async {
                    if (nombreController.text.trim().isEmpty) return;

                    try {
                      final newProd = await _supabase.from('productos').insert({
                        'nombre': nombreController.text.trim(),
                        'sku': skuController.text.trim().isEmpty ? null : skuController.text.trim(),
                        'condicion': condicion,
                        'tipo': tipoSeleccionado,
                        'stock_minimo': int.tryParse(stockMinimoController.text) ?? 2,
                        'stock_actual': 0,
                      }).select().single();

                      if (ctx.mounted) {
                        Navigator.pop(ctx);
                        await _cargarProductos();
                        _agregarItemABag(newProd);
                      }
                    } catch (e) {
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text('Error al crear producto: $e'), backgroundColor: Colors.red),
                        );
                      }
                    }
                  },
                  child: const Text('Guardar y Agregar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _guardarEntrada() async {
    if (_itemsEntrada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Agrega al menos un producto a la lista'), backgroundColor: Colors.orange),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String? imagenUrl;

      if (_imagenSoporte != null) {
        final bytes = await _imagenSoporte!.readAsBytes();
        final fileExt = _imagenSoporte!.path.split('.').last;
        final fileName = 'entrada_${DateTime.now().millisecondsSinceEpoch}.$fileExt';
        
        await _supabase.storage.from('soportes_bodega').uploadBinary(fileName, bytes);
        imagenUrl = _supabase.storage.from('soportes_bodega').getPublicUrl(fileName);
      }

      final resMov = await _supabase.from('movimientos_inventario').insert({
        'tipo': 'ENTRADA',
        'subtipo': _tipoEntrada,
        'proveedor_causa': _proveedorController.text.trim(),
        'factura_remision': _facturaController.text.trim(),
        'encargado_separacion': _recibidoPorController.text.trim(),
        'observaciones': _observacionesController.text.trim(),
        'imagen_url': imagenUrl,
      }).select().single();

      final movId = resMov['id'];

      for (var item in _itemsEntrada) {
        await _supabase.from('detalle_movimientos').insert({
          'movimiento_id': movId,
          'producto_id': item['producto_id'],
          'cantidad': item['cantidad'],
        });

        final prod = await _supabase
            .from('productos')
            .select('stock_actual')
            .eq('id', item['producto_id'])
            .single();

        final int stockActual = (prod['stock_actual'] as num?)?.toInt() ?? 0;
        final int nuevaCantidad = stockActual + (item['cantidad'] as int);

        await _supabase
            .from('productos')
            .update({'stock_actual': nuevaCantidad})
            .eq('id', item['producto_id']);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Entrada de inventario registrada con éxito!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrada de Mercancía (MYP)'),
        backgroundColor: Colors.teal[800],
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tipo de Entrada', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'Compra', label: Text('Compra'), icon: Icon(Icons.shopping_bag)),
                      ButtonSegment(value: 'Devolución', label: Text('Devolución'), icon: Icon(Icons.assignment_return)),
                      ButtonSegment(value: 'Ajuste', label: Text('Ajuste (+)'), icon: Icon(Icons.build)),
                    ],
                    selected: {_tipoEntrada},
                    onSelectionChanged: (set) => setState(() => _tipoEntrada = set.first),
                  ),
                  const SizedBox(height: 15),

                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _proveedorController,
                          decoration: const InputDecoration(labelText: 'Proveedor / Causa', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _facturaController,
                          decoration: const InputDecoration(labelText: 'No. Factura / Remisión', border: OutlineInputBorder()),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _recibidoPorController,
                    decoration: const InputDecoration(labelText: 'Recibido por (Técnico/Bodeguero)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),

                  const Text('Productos a Ingresar', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Autocomplete<Map<String, dynamic>>(
                    displayStringForOption: (option) => '${option['nombre']} (${option['sku'] ?? 'Sin SKU'})',
                    optionsBuilder: (textEditingValue) {
                      if (textEditingValue.text.isEmpty) return const Iterable<Map<String, dynamic>>.empty();
                      return _productosDisponibles.where((p) {
                        final nombre = (p['nombre'] ?? '').toString().toLowerCase();
                        final sku = (p['sku'] ?? '').toString().toLowerCase();
                        return nombre.contains(textEditingValue.text.toLowerCase()) || sku.contains(textEditingValue.text.toLowerCase());
                      });
                    },
                    onSelected: (selection) => _agregarItemABag(selection),
                    fieldViewBuilder: (ctx, controller, focusNode, onFieldSubmitted) {
                      _busquedaProductoController.value = controller.value;
                      return TextField(
                        controller: controller,
                        focusNode: focusNode,
                        decoration: InputDecoration(
                          hintText: 'Buscar producto o escribir para crear nuevo...',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.teal),
                            onPressed: () => _mostrarCrearProductoModal(controller.text),
                          ),
                          border: const OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 15),

                  if (_itemsEntrada.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _itemsEntrada.length,
                      itemBuilder: (ctx, index) {
                        final item = _itemsEntrada[index];
                        return Card(
                          child: ListTile(
                            title: Text(item['nombre'], style: const TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text('SKU: ${item['sku'] ?? 'N/A'}'),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline),
                                  onPressed: () {
                                    setState(() {
                                      if (item['cantidad'] > 1) {
                                        item['cantidad']--;
                                      } else {
                                        _itemsEntrada.removeAt(index);
                                      }
                                    });
                                  },
                                ),
                                Text('${item['cantidad']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => setState(() => item['cantidad']++),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),

                  const SizedBox(height: 20),

                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _tomarFoto(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt),
                        label: const Text('Tomar Foto'),
                      ),
                      const SizedBox(width: 10),
                      ElevatedButton.icon(
                        onPressed: () => _tomarFoto(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Galería'),
                      ),
                    ],
                  ),
                  if (_imagenSoporte != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text('Foto adjuntada: ${_imagenSoporte!.name}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ),

                  const SizedBox(height: 15),
                  TextField(
                    controller: _observacionesController,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Observaciones generales', border: OutlineInputBorder()),
                  ),

                  const SizedBox(height: 25),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800], foregroundColor: Colors.white),
                      onPressed: _guardarEntrada,
                      child: const Text('REGISTRAR ENTRADA A BODEGA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}