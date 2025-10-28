import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/backup_service.dart';

class BackupScreen extends StatefulWidget {
  @override
  _BackupScreenState createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = false;
  String _statusMessage = '';
  List<FileSystemEntity> _backups = [];
  final TextEditingController _backupNameController = TextEditingController();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    _loadBackups();
    _animationController.forward();
  }

  @override
  void dispose() {
    _backupNameController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadBackups() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cargando copias de seguridad...';
    });

    try {
      final backups = await BackupService.getAvailableBackups();

      setState(() {
        _backups = backups;
        _isLoading = false;
        _statusMessage = backups.isEmpty ? 'No hay copias de seguridad disponibles' : '';
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al cargar las copias de seguridad: $e';
      });
    }
  }

  Future<void> _createBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Creando copia de seguridad...';
    });

    try {
      final backupName = _backupNameController.text.trim();
      final backupFile = await BackupService.createBackup(
          customName: backupName.isNotEmpty ? backupName : 'backup'
      );

      setState(() {
        _isLoading = false;
        _statusMessage = 'Copia de seguridad creada exitosamente';
      });

      // Recargar la lista de respaldos
      await _loadBackups();

      // Mostrar diálogo de éxito
      _showSuccessDialog('Copia de seguridad creada', '¿Desea exportar la copia de seguridad?', () async {
        await _exportBackup(backupFile);
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al crear la copia de seguridad: $e';
      });
    }
  }

  Future<void> _exportBackup(File backupFile) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Exportando copia de seguridad...';
    });

    try {
      final success = await BackupService.exportBackup(backupFile);

      setState(() {
        _isLoading = false;
        _statusMessage = success
            ? 'Copia de seguridad exportada a Descargas'
            : 'Error al exportar la copia de seguridad';
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Copia de seguridad guardada en la carpeta de Descargas'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al exportar la copia de seguridad: $e';
      });
    }
  }

  Future<void> _importBackup() async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Seleccionando archivo de copia de seguridad...';
    });

    try {
      final backupFile = await BackupService.importBackup();

      if (backupFile != null) {
        setState(() {
          _statusMessage = 'Archivo seleccionado. ¿Desea restaurar este archivo?';
        });

        // Mostrar diálogo de confirmación
        final shouldRestore = await _showConfirmationDialog(
            'Restaurar copia de seguridad',
            '¿Está seguro que desea restaurar la aplicación con esta copia de seguridad? '
                'Esto reemplazará todos los datos actuales.'
        );

        if (shouldRestore) {
          await _restoreBackup(backupFile);
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _isLoading = false;
          _statusMessage = 'No se seleccionó un archivo válido. Asegúrese de seleccionar un archivo con extensión .suray';
        });

        // Mostrar una alerta más descriptiva
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('El archivo seleccionado no es un respaldo válido. Debe tener extensión .suray'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: Duration(seconds: 5),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al importar la copia de seguridad: $e';
      });

      // Mostrar error detallado
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: 5),
        ),
      );
    }
  }

  Future<void> _restoreBackup(File backupFile) async {
    setState(() {
      _isLoading = true;
      _statusMessage = 'Restaurando copia de seguridad...';
    });

    try {
      final success = await BackupService.restoreBackup(backupFile);

      setState(() {
        _isLoading = false;
        _statusMessage = success
            ? 'Copia de seguridad restaurada exitosamente'
            : 'Error al restaurar la copia de seguridad';
      });

      if (success) {
        await _showSuccessDialog(
            'Restauración completada',
            'La aplicación se ha restaurado exitosamente. '
                'Reinicie la aplicación para aplicar todos los cambios.',
            null
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = 'Error al restaurar la copia de seguridad: $e';
      });
    }
  }

  Future<void> _showBackupDetails(FileSystemEntity backup) async {
    final file = File(backup.path);
    final fileName = backup.path.split('/').last;
    final fileStats = await file.stat();
    final fileSize = _formatFileSize(fileStats.size);
    final fileDate = DateFormat('dd/MM/yyyy - HH:mm').format(fileStats.modified);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.backup, color: Colors.blue),
            SizedBox(width: 10),
            Expanded(child: Text('Detalles de la copia')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('Nombre:', fileName),
            _buildDetailRow('Tamaño:', fileSize),
            _buildDetailRow('Fecha:', fileDate),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cerrar'),
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.share),
            label: Text('Compartir'),
            onPressed: () {
              Navigator.pop(context);
              BackupService.shareBackup(file);
            },
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.save_alt),
            label: Text('Exportar'),
            onPressed: () {
              Navigator.pop(context);
              _exportBackup(file);
            },
          ),
          ElevatedButton.icon(
            icon: Icon(Icons.restore),
            label: Text('Restaurar'),
            onPressed: () async {
              Navigator.pop(context);
              final shouldRestore = await _showConfirmationDialog(
                  'Restaurar copia de seguridad',
                  '¿Está seguro que desea restaurar la aplicación con esta copia de seguridad? '
                      'Esto reemplazará todos los datos actuales.'
              );

              if (shouldRestore) {
                await _restoreBackup(file);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey.shade700,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  String _formatFileSize(int sizeInBytes) {
    if (sizeInBytes < 1024) {
      return '${sizeInBytes} B';
    } else if (sizeInBytes < 1024 * 1024) {
      return '${(sizeInBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(sizeInBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: Text('Restaurar'),
          ),
        ],
      ),
    ) ?? false;
  }

  Future<void> _showSuccessDialog(String title, String message, Function? onContinue) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        title: Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 10),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cerrar'),
          ),
          if (onContinue != null)
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                onContinue();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
              ),
              child: Text('Continuar'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Respaldo y Recuperación',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.amber.shade800,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(15)),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadBackups,
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.amber.shade50, Colors.white],
          ),
        ),
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              // Contenido principal
              SingleChildScrollView(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encabezado
                    Center(
                      child: Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black12,
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.backup,
                              size: 60,
                              color: Colors.amber.shade800,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Sistema de Respaldo y Recuperación',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            SizedBox(height: 10),
                            Text(
                              'Cree copias de seguridad de sus datos para poder restaurarlos en caso de actualización o cambio de dispositivo.',
                              style: TextStyle(
                                color: Colors.grey.shade700,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Sección crear respaldo
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Crear Copia de Seguridad',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            SizedBox(height: 16),
                            TextField(
                              controller: _backupNameController,
                              decoration: InputDecoration(
                                labelText: 'Nombre de la copia (opcional)',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                prefixIcon: Icon(Icons.create),
                                helperText: 'Deje en blanco para un nombre automático',
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.backup),
                                    label: Text('Crear Copia de Seguridad'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.amber.shade800,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: _isLoading ? null : _createBackup,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Sección restaurar respaldo
                    Card(
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restaurar Copia de Seguridad',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    icon: Icon(Icons.upload_file),
                                    label: Text('Importar Copia Externa'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                      padding: EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    onPressed: _isLoading ? null : _importBackup,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 24),

                    // Respaldos disponibles
                    if (_backups.isNotEmpty) ...[
                      Text(
                        'Copias de Seguridad Disponibles',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade800,
                        ),
                      ),
                      SizedBox(height: 8),
                      ListView.builder(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _backups.length,
                        itemBuilder: (context, index) {
                          final backup = _backups[index];
                          final fileName = backup.path.split('/').last;

                          return Card(
                            elevation: 2,
                            margin: EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: ListTile(
                              leading: CircleAvatar(
                                backgroundColor: Colors.amber.shade100,
                                child: Icon(
                                  Icons.backup,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                              title: Text(
                                fileName,
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              subtitle: FutureBuilder<FileStat>(
                                future: File(backup.path).stat(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData) {
                                    return Text('Cargando...');
                                  }

                                  final modified = DateFormat('dd/MM/yyyy - HH:mm')
                                      .format(snapshot.data!.modified);
                                  return Text(modified);
                                },
                              ),
                              trailing: IconButton(
                                icon: Icon(Icons.more_vert),
                                onPressed: () => _showBackupDetails(backup),
                              ),
                              onTap: () => _showBackupDetails(backup),
                            ),
                          );
                        },
                      ),
                    ],

                    SizedBox(height: 24),

                    // Tarjeta de información de respaldo
                    Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.blue),
                                SizedBox(width: 8),
                                Text(
                                  'Información',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '• Las copias de seguridad incluyen todos los datos de la aplicación.\n'
                                  '• Puede exportar las copias a la carpeta de Descargas para guardarlas en otro dispositivo.\n'
                                  '• Al restaurar, se reemplazarán todos los datos actuales.\n'
                                  '• Se recomienda crear una copia de seguridad antes de actualizar la aplicación.',
                              style: TextStyle(
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    SizedBox(height: 40),
                  ],
                ),
              ),

              // Indicador de carga
              if (_isLoading)
                Container(
                  color: Colors.black54,
                  child: Center(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.amber.shade800),
                            ),
                            SizedBox(height: 20),
                            Text(
                              _statusMessage,
                              style: TextStyle(fontSize: 16),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}