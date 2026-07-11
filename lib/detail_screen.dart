import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DetailScreen extends StatefulWidget {
  final Map<String, dynamic> solicitud;
  const DetailScreen({super.key, required this.solicitud});

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  List<Map<String, dynamic>> _elementos = [];

  String? _areaEncargada;
  bool? _tieneReparacion;
  final _resultadoRevision = TextEditingController();
  final _valorReparacion = TextEditingController();
  final _valorInstalacion = TextEditingController();

  final _entregadoA = TextEditingController();
  bool _pagoRealizado = false;
  final _valorPagado = TextEditingController();
  XFile? _fotoEntrega;
  String? _fotoEntregaUrl;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
    _cargarElementos();
  }

  void _cargarDatosIniciales() {
    final s = widget.solicitud;
    _areaEncargada = s['area_encargada'];
    _tieneReparacion = s['tiene_reparacion'];
    _resultadoRevision.text = s['resultado_revision'] ?? '';
    _valorReparacion.text = (s['valor_reparacion'] ?? 0).toString();
    _valorInstalacion.text = (s['valor_instalacion'] ?? 0).toString();
    _entregadoA.text = s['entregado_a'] ?? '';
    _pagoRealizado = s['pago_realizado'] ?? false;
    _valorPagado.text = (s['valor_pagado'] ?? 0).toString();
    _fotoEntregaUrl = s['foto_entrega_url'];
  }

  Future<void> _cargarElementos() async {
    try {
      final res = await Supabase.instance.client
          .from('elementos_solicitud')
          .select()
          .eq('solicitud_id', widget.solicitud['id']);
      setState(() {
        _elementos = List<Map<String, dynamic>>.from(res);
      });
    } catch (_) {}
  }

  Future<void> _tomarFotoEntrega() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.camera, imageQuality: 70);
    if (image != null) {
      setState(() {
        _fotoEntrega = image;
      });
    }
  }

  Map<String, String> _calcularEstadoYResponsable() {
    String nuevoEstado = widget.solicitud['estado'] ?? 'Registrado';
    String nuevoResponsable = widget.solicitud['responsable'] ?? 'Servicio técnico MYP';
    final canal = widget.solicitud['canal_atencion'] ?? 'cliente final';

    if (_areaEncargada == null && _tieneReparacion == null && _entregadoA.text.trim().isEmpty && !_pagoRealizado) {
      return {'estado': 'Registrado', 'responsable': 'Servicio técnico MYP'};
    }

    if (_areaEncargada != null) {
      nuevoEstado = 'En Revisión';
      if (_areaEncargada == 'técnico propio') {
        nuevoResponsable = 'Tecnico MYP';
      } else if (_areaEncargada == 'Taller externo') {
        nuevoResponsable = 'Taller Externo';
      }
    }

    if (_tieneReparacion == false) {
      nuevoEstado = 'No tiene reparación';
      nuevoResponsable = (canal == 'instaladores') ? 'instaladores' : 'Cliente final';
    }

    if (_entregadoA.text.trim().isNotEmpty) {
      nuevoEstado = 'Pendiente de Pago';
      nuevoResponsable = (canal == 'instaladores') ? 'instaladores' : 'Cliente final';
    }

    if (_pagoRealizado) {
      nuevoEstado = 'Finalizado';
      nuevoResponsable = 'No aplica';
    }

    return {'estado': nuevoEstado, 'responsable': nuevoResponsable};
  }

  Future<void> _guardarCambios() async {
    setState(() => _isLoading = true);

    try {
      final client = Supabase.instance.client;
      final calculos = _calcularEstadoYResponsable();

      if (_fotoEntrega != null) {
        final fileBytes = await _fotoEntrega!.readAsBytes();
        final fileName = 'entrega_${widget.solicitud['id']}.jpg';
        
        // Uso de uploadBinary para manejar correctamente los bytes de la imagen
        await client.storage.from('fotos_elementos').uploadBinary(
              fileName,
              fileBytes,
              fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
            );
        _fotoEntregaUrl = client.storage.from('fotos_elementos').getPublicUrl(fileName);
      }

      await client.from('solicitudes').update({
        'area_encargada': _areaEncargada,
        'tiene_reparacion': _tieneReparacion,
        'resultado_revision': _resultadoRevision.text.trim(),
        'valor_reparacion': double.tryParse(_valorReparacion.text) ?? 0,
        'valor_instalacion': double.tryParse(_valorInstalacion.text) ?? 0,
        'entregado_a': _entregadoA.text.trim(),
        'foto_entrega_url': _fotoEntregaUrl,
        'pago_realizado': _pagoRealizado,
        'valor_pagado': double.tryParse(_valorPagado.text) ?? 0,
        'estado': calculos['estado'],
        'responsable': calculos['responsable'],
      }).eq('id', widget.solicitud['id']);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('¡Seguimiento actualizado con éxito!'), backgroundColor: Colors.green),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seguimiento de Servicio')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    const Text('DATOS DEL REGISTRO', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                    const Divider(),
                    ListTile(title: const Text('Nombre del cliente'), subtitle: Text('${widget.solicitud['cliente_nombre']}')),
                    ListTile(title: const Text('Teléfono'), subtitle: Text('${widget.solicitud['telefono']}')),
                    ListTile(
                      title: const Text('Dirección de entrega'),
                      subtitle: Text(widget.solicitud['entrega_oficina'] == true ? 'Entrega en la oficina' : '${widget.solicitud['direccion'] ?? "No registra"}'),
                    ),
                    ListTile(title: const Text('Tipo de gestión'), subtitle: Text('${widget.solicitud['tipo_gestion']}')),
                    ListTile(title: const Text('Canal de atención'), subtitle: Text('${widget.solicitud['canal_atencion']}')),
                    ListTile(title: const Text('Entregado por'), subtitle: Text('${widget.solicitud['nombre_entrega']}')),
                    ListTile(title: const Text('Diagnóstico inicial'), subtitle: Text('${widget.solicitud['diagnostico_novedad'] ?? "Sin diagnóstico"}')),
                    
                    const SizedBox(height: 16),
                    
                    const Text('ELEMENTOS RECIBIDOS', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                    const Divider(),
                    if (_elementos.isEmpty) const Text('Cargando elementos adjuntos...'),
                    ..._elementos.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final ele = entry.value;
                      return Card(
                        color: Colors.grey[50],
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        child: ListTile(
                          title: Text('ELEMENTO ${idx + 1}: ${ele['nombre_elemento']}'),
                          subtitle: ele['foto_url'] != null
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 8.0),
                                  child: Image.network(ele['foto_url'], height: 150, fit: BoxFit.cover),
                                )
                              : const Text('Sin foto adjunta.'),
                        ),
                      );
                    }),

                    const SizedBox(height: 24),

                    const Text('REVISIÓN TÉCNICA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                    const Divider(),
                    DropdownButtonFormField<String>(
                      initialValue: _areaEncargada, // Uso de initialValue
                      decoration: const InputDecoration(labelText: 'Área encargada del servicio'),
                      items: const [
                        DropdownMenuItem(value: 'técnico propio', child: Text('Técnico Propio')),
                        DropdownMenuItem(value: 'Taller externo', child: Text('Taller Externo')),
                      ],
                      onChanged: (v) => setState(() => _areaEncargada = v),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('¿Tiene reparación? '),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text('Sí'),
                          selected: _tieneReparacion == true,
                          onSelected: (val) => setState(() => _tieneReparacion = val ? true : null),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('No'),
                          selected: _tieneReparacion == false,
                          onSelected: (val) => setState(() => _tieneReparacion = val ? false : null),
                        ),
                      ],
                    ),
                    TextFormField(controller: _resultadoRevision, decoration: const InputDecoration(labelText: 'Resultado de la revisión')),
                    TextFormField(controller: _valorReparacion, decoration: const InputDecoration(labelText: 'Valor de la reparación'), keyboardType: TextInputType.number),
                    TextFormField(controller: _valorInstalacion, decoration: const InputDecoration(labelText: 'Valor de la instalación (Si aplica)'), keyboardType: TextInputType.number),

                    const SizedBox(height: 24),

                    const Text('DATOS DE ENTREGA', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 16)),
                    const Divider(),
                    TextFormField(controller: _entregadoA, decoration: const InputDecoration(labelText: '¿A quién se entregó?')),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton.icon(
                          onPressed: _tomarFotoEntrega,
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Foto de la entrega'),
                        ),
                        const SizedBox(width: 12),
                        if (_fotoEntrega != null || _fotoEntregaUrl != null)
                          const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 4), Text('Foto lista')])
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Text('Pago realizado: '),
                        const SizedBox(width: 16),
                        ChoiceChip(
                          label: const Text('Sí'),
                          selected: _pagoRealizado == true,
                          onSelected: (val) => setState(() => _pagoRealizado = val),
                        ),
                        const SizedBox(width: 8),
                        ChoiceChip(
                          label: const Text('No'),
                          selected: _pagoRealizado == false,
                          onSelected: (val) => setState(() => _pagoRealizado = !val),
                        ),
                      ],
                    ),
                    TextFormField(controller: _valorPagado, decoration: const InputDecoration(labelText: 'Valor pagado'), keyboardType: TextInputType.number),

                    const SizedBox(height: 32),
                    ElevatedButton(
                      onPressed: _guardarCambios,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('GUARDAR CAMBIOS', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}