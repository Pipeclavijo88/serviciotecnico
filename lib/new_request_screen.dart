import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NewRequestScreen extends StatefulWidget {
  const NewRequestScreen({super.key});

  @override
  State<NewRequestScreen> createState() => _NewRequestScreenState();
}

class _NewRequestScreenState extends State<NewRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  
  final _nombreCliente = TextEditingController();
  final _telefono = TextEditingController();
  final _direccion = TextEditingController();
  final _nombreEntrega = TextEditingController();
  final _diagnostico = TextEditingController();

  bool _entregaOficina = false;
  int _cantidadElementos = 1;

  List<TextEditingController> _nombreElementosControllers = [TextEditingController()];
  List<XFile?> _imagenesElementos = [null];

  String _tipoGestion = 'técnico propio';
  String _canalAtencion = 'cliente final';
  bool _isSaving = false;

  void _actualizarCantidadElementos(int nuevaCantidad) {
    setState(() {
      _cantidadElementos = nuevaCantidad;
      
      if (_nombreElementosControllers.length < nuevaCantidad) {
        for (int i = _nombreElementosControllers.length; i < nuevaCantidad; i++) {
          _nombreElementosControllers.add(TextEditingController());
          _imagenesElementos.add(null);
        }
      } else if (_nombreElementosControllers.length > nuevaCantidad) {
        _nombreElementosControllers = _nombreElementosControllers.sublist(0, nuevaCantidad);
        _imagenesElementos = _imagenesElementos.sublist(0, nuevaCantidad);
      }
    });
  }

  Future<void> _tomarFoto(int index) async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) {
      setState(() {
        _imagenesElementos[index] = image;
      });
    }
  }

  Future<void> _guardarRegistro() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final client = Supabase.instance.client;

      // Guardamos la solicitud. Supabase le inyectará la columna created_at automáticamente en el servidor
      final solicitudResponse = await client.from('solicitudes').insert({
        'cliente_nombre': _nombreCliente.text.trim(),
        'telefono': _telefono.text.trim(),
        'direccion': _entregaOficina ? null : _direccion.text.trim(),
        'entrega_oficina': _entregaOficina,
        'cantidad_elementos': _cantidadElementos,
        'tipo_gestion': _tipoGestion,
        'canal_atencion': _canalAtencion,
        'nombre_entrega': _nombreEntrega.text.trim(),
        'diagnostico_novedad': _diagnostico.text.trim(),
        'estado': 'Registrado',
        'responsable': 'Servicio técnico MYP' 
      }).select().single();

      final int solicitudId = solicitudResponse['id'];

      for (int i = 0; i < _cantidadElementos; i++) {
        String? fotoUrl;

        if (_imagenesElementos[i] != null) {
          final fileBytes = await _imagenesElementos[i]!.readAsBytes();
          final fileName = 'solicitud_${solicitudId}_elemento_$i.jpg';
          
          await client.storage.from('fotos_elementos').uploadBinary(
            fileName,
            fileBytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );

          fotoUrl = client.storage.from('fotos_elementos').getPublicUrl(fileName);
        }

        await client.from('elementos_solicitud').insert({
          'solicitud_id': solicitudId,
          'nombre_elemento': _nombreElementosControllers[i].text.trim().isEmpty 
              ? 'Elemento ${i + 1}' 
              : _nombreElementosControllers[i].text.trim(),
          'foto_url': fotoUrl,
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Registro guardado con éxito!'), backgroundColor: Colors.green),
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
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva Solicitud')),
      body: _isSaving 
        ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [CircularProgressIndicator(), SizedBox(height: 16), Text('Guardando registro e imágenes...')]))
        : Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text('DATOS DEL CLIENTE', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const Divider(),
                  TextFormField(controller: _nombreCliente, decoration: const InputDecoration(labelText: 'Nombre del Cliente'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  TextFormField(controller: _telefono, decoration: const InputDecoration(labelText: 'Teléfono'), keyboardType: TextInputType.phone, validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  Row(
                    children: [
                      Checkbox(value: _entregaOficina, onChanged: (v) => setState(() => _entregaOficina = v!)),
                      const Text('Entrega en la oficina'),
                    ],
                  ),
                  if (!_entregaOficina)
                    TextFormField(controller: _direccion, decoration: const InputDecoration(labelText: 'Dirección'), validator: (v) => !_entregaOficina && v!.isEmpty ? 'Requerido' : null),
                  
                  const SizedBox(height: 24),
                  const Text('ELEMENTOS RECIBIDOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const Divider(),
                  Row(
                    children: [
                      const Text('Cantidad de elementos: '),
                      const SizedBox(width: 16),
                      DropdownButton<int>(
                        value: _cantidadElementos,
                        items: List.generate(10, (index) => DropdownMenuItem(value: index + 1, child: Text('${index + 1}'))),
                        onChanged: (value) => _actualizarCantidadElementos(value!),
                      ),
                    ],
                  ),
                  
                  ...List.generate(_cantidadElementos, (index) {
                    return Card(
                      color: Colors.blue[50],
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('ELEMENTO ${index + 1}', style: const TextStyle(fontWeight: FontWeight.bold)),
                            TextFormField(
                              controller: _nombreElementosControllers[index],
                              decoration: const InputDecoration(labelText: 'Nombre o descripción del elemento'),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ElevatedButton.icon(
                                  onPressed: () => _tomarFoto(index),
                                  icon: const Icon(Icons.camera_alt),
                                  label: const Text('Tomar Foto'),
                                ),
                                const SizedBox(width: 16),
                                if (_imagenesElementos[index] != null)
                                  const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 4), Text('Foto capturada')])
                                else
                                  const Text('Sin foto', style: TextStyle(color: Colors.grey)),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                  const SizedBox(height: 24),
                  const Text('INFORMACIÓN DE ENTREGA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  const Divider(),
                  DropdownButtonFormField<String>(
                    initialValue: _tipoGestion,
                    decoration: const InputDecoration(labelText: 'Tipo de Gestión'),
                    items: const [DropdownMenuItem(value: 'técnico propio', child: Text('Técnico Propio')), DropdownMenuItem(value: 'instaladores', child: Text('Instaladores')), DropdownMenuItem(value: 'cliente final', child: Text('Cliente Final'))],
                    onChanged: (v) => setState(() => _tipoGestion = v!),
                  ),
                  DropdownButtonFormField<String>(
                    initialValue: _canalAtencion,
                    decoration: const InputDecoration(labelText: 'Canal de Atención'),
                    items: const [DropdownMenuItem(value: 'cliente final', child: Text('Cliente Final')), DropdownMenuItem(value: 'instaladores', child: Text('Instaladores'))],
                    onChanged: (v) => setState(() => _canalAtencion = v!),
                  ),
                  TextFormField(controller: _nombreEntrega, decoration: const InputDecoration(labelText: 'Nombre de quien entrega'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
                  TextFormField(controller: _diagnostico, decoration: const InputDecoration(labelText: 'Diagnóstico o Novedad'), maxLines: 2),
                  
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: _guardarRegistro,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('GUARDAR REGISTRO', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}