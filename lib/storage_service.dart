import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class InventarioStorageService {
  static final _supabase = Supabase.instance.client;
  static final ImagePicker _picker = ImagePicker();

  /// Permite tomar o seleccionar una foto y subirla a Supabase optimizada.
  static Future<String?> capturarYSubirFoto({required ImageSource origen}) async {
    try {
      final XFile? imagenSeleccionada = await _picker.pickImage(
        source: origen,
        imageQuality: 80,
      );

      if (imagenSeleccionada == null) return null;

      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';

      if (kIsWeb) {
        // En entorno Web, leemos los bytes directamente
        final bytes = await imagenSeleccionada.readAsBytes();
        await _supabase.storage
            .from('evidencias-inventario')
            .uploadBinary(fileName, bytes);
      } else {
        // En entorno Móvil / Escritorio, comprimimos el archivo local
        final File archivoOriginal = File(imagenSeleccionada.path);
        final String pathDestino = '${archivoOriginal.path}_compressed.jpg';

        final XFile? fotoComprimida = await FlutterImageCompress.compressAndGetFile(
          archivoOriginal.absolute.path,
          pathDestino,
          quality: 70,
          minWidth: 1080,
          minHeight: 1080,
        );

        final File archivoAEnviar = fotoComprimida != null
            ? File(fotoComprimida.path)
            : archivoOriginal;

        await _supabase.storage
            .from('evidencias-inventario')
            .upload(fileName, archivoAEnviar);
      }

      // Obtener la URL pública para asociarla al registro de la BD
      final String urlPublica = _supabase.storage
          .from('evidencias-inventario')
          .getPublicUrl(fileName);

      return urlPublica;
    } catch (e) {
      debugPrint('Error al procesar/subir imagen: $e');
      return null;
    }
  }
}