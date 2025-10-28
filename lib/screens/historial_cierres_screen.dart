import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../services/sync_service.dart';

class HistorialCierresScreen extends StatefulWidget {
  const HistorialCierresScreen({Key? key}) : super(key: key);

  @override
  _HistorialCierresScreenState createState() => _HistorialCierresScreenState();
}

class _HistorialCierresScreenState extends State<HistorialCierresScreen> {
  final DatabaseService _dbService = DatabaseService();
  final SyncService _syncService = SyncService();

  List<Map<String, dynamic>> _cierres = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _cargarCierres();
  }

  Future<void> _cargarCierres() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cierres = await _dbService.getCierresCaja();
      setState(() {
        _cierres = cierres;
      });
    } catch (e) {
      _mostrarSnackBar('Error al cargar cierres: $e', Colors.red);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _sincronizarCierre(int cierreId) async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // Verificar conexión
      final hasInternet = await SyncService.hasInternetConnection();
      if (!hasInternet) {
        _mostrarSnackBar('Sin conexión a internet', Colors.orange);
        return;
      }

      final result = await _syncService.syncCierre(cierreId);

      if (result.success) {
        _mostrarSnackBar(
          '✅ Cierre #$cierreId sincronizado (Server ID: ${result.serverId})',
          Colors.green,
        );
        await _cargarCierres(); // Recargar lista
      } else {
        _mostrarSnackBar(
          '❌ Error: ${result.errorMessage}',
          Colors.red,
        );
      }
    } catch (e) {
      _mostrarSnackBar('Error al sincronizar: $e', Colors.red);
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _sincronizarTodosPendientes() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      // Verificar conexión
      final hasInternet = await SyncService.hasInternetConnection();
      if (!hasInternet) {
        _mostrarSnackBar('Sin conexión a internet', Colors.orange);
        return;
      }

      // Mostrar diálogo de progreso
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Sincronizando cierres pendientes...'),
            ],
          ),
        ),
      );

      final resultados = await _syncService.syncPendingCierres();

      Navigator.pop(context); // Cerrar diálogo de progreso

      final exitosos = resultados.where((r) => r.success).length;
      final fallidos = resultados.where((r) => !r.success).length;

      if (exitosos > 0) {
        _mostrarSnackBar(
          '✅ $exitosos cierres sincronizados, $fallidos fallidos',
          exitosos == resultados.length ? Colors.green : Colors.orange,
        );
      } else {
        _mostrarSnackBar(
          '❌ No se pudo sincronizar ningún cierre',
          Colors.red,
        );
      }

      await _cargarCierres(); // Recargar lista
    } catch (e) {
      Navigator.pop(context); // Cerrar diálogo si está abierto
      _mostrarSnackBar('Error al sincronizar: $e', Colors.red);
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Future<void> _verificarEstadoServidor() async {
    setState(() {
      _isSyncing = true;
    });

    try {
      final hasInternet = await SyncService.hasInternetConnection();
      if (!hasInternet) {
        _mostrarSnackBar('Sin conexión a internet', Colors.orange);
        return;
      }

      final estado = await _syncService.getEstadoSincronizacion();

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          icon: Icon(Icons.info_outline, color: Colors.blue, size: 48),
          title: Text('Estado de Sincronización'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildEstadoRow('Total de cierres:', '${estado['total']}'),
              _buildEstadoRow('Sincronizados:', '${estado['sincronizados']}', Colors.green),
              _buildEstadoRow('Pendientes:', '${estado['pendientes']}', Colors.orange),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cerrar'),
            ),
          ],
        ),
      );
    } catch (e) {
      _mostrarSnackBar('Error al verificar estado: $e', Colors.red);
    } finally {
      setState(() {
        _isSyncing = false;
      });
    }
  }

  Widget _buildEstadoRow(String label, String value, [Color? color]) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontWeight: FontWeight.w500)),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color ?? Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarSnackBar(String mensaje, Color color) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: color,
        duration: Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatFecha(String fecha) {
    try {
      // Intentar parsear diferentes formatos
      DateTime? dateTime;

      if (fecha.contains('/')) {
        // Formato: dd/MM/yyyy HH:mm
        dateTime = DateFormat('dd/MM/yyyy HH:mm').parse(fecha);
      } else {
        // Formato ISO
        dateTime = DateTime.parse(fecha);
      }

      return DateFormat('dd/MM/yyyy HH:mm').format(dateTime);
    } catch (e) {
      return fecha;
    }
  }

  String _formatMonto(double monto) {
    return NumberFormat("#,##0", "es_ES").format(monto);
  }

  @override
  Widget build(BuildContext context) {
    // Calcular resumen
    final sincronizados = _cierres.where((c) => (c['sincronizado'] as int? ?? 0) == 1).length;
    final pendientes = _cierres.where((c) => (c['sincronizado'] as int? ?? 0) == 0).length;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Historial de Cierres',
          style: TextStyle(
            fontFamily: 'Hemiheads',
            fontSize: 24,
            letterSpacing: 0.75,
          ),
        ),
        backgroundColor: Colors.teal[700],
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _isLoading || _isSyncing ? null : _cargarCierres,
            tooltip: 'Actualizar',
          ),
        ],
      ),
      body: Column(
        children: [
          // Botones de acción
          Container(
            color: Colors.teal[50],
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.sync, size: 18),
                    label: Text('Sincronizar\nPendientes', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    onPressed: (_isSyncing || pendientes == 0) ? null : _sincronizarTodosPendientes,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: Icon(Icons.info_outline, size: 18),
                    label: Text('Verificar\nEstado', textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
                    onPressed: _isSyncing ? null : _verificarEstadoServidor,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Resumen
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.teal[100]!, Colors.teal[50]!],
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildResumenCard('Total', _cierres.length.toString(), Colors.blue),
                _buildResumenCard('Sincronizados', sincronizados.toString(), Colors.green),
                _buildResumenCard('Pendientes', pendientes.toString(), Colors.orange),
              ],
            ),
          ),

          // Lista de cierres
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator())
                : _cierres.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No hay cierres registrados',
                              style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _cargarCierres,
                        child: ListView.builder(
                          padding: EdgeInsets.all(8),
                          itemCount: _cierres.length,
                          itemBuilder: (context, index) {
                            final cierre = _cierres[index];
                            return _buildCierreCard(cierre);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildResumenCard(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[700],
            fontWeight: FontWeight.w500,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'Hemiheads',
          ),
        ),
      ],
    );
  }

  Widget _buildCierreCard(Map<String, dynamic> cierre) {
    final id = cierre['id'] as int;
    final fechaCierre = cierre['fecha_cierre'] as String;
    final totalIngresos = (cierre['total_ingresos'] as num).toDouble();
    final totalTransacciones = cierre['total_transacciones'] as int;
    final sincronizado = (cierre['sincronizado'] as int? ?? 0) == 1;
    final serverId = cierre['server_id'] as int?;
    final errorSync = cierre['error_sync'] as String?;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      elevation: 2,
      child: ExpansionTile(
        leading: Icon(
          sincronizado ? Icons.check_circle : Icons.sync_problem,
          color: sincronizado ? Colors.green : Colors.orange,
          size: 32,
        ),
        title: Text(
          'Cierre #$id',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_formatFecha(fechaCierre)),
            Text(
              '\$${_formatMonto(totalIngresos)} ($totalTransacciones trans.)',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.teal[700],
              ),
            ),
          ],
        ),
        trailing: sincronizado
            ? Chip(
                label: Text('✓ Sync', style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Colors.green,
                padding: EdgeInsets.zero,
              )
            : Chip(
                label: Text('Pendiente', style: TextStyle(fontSize: 10, color: Colors.white)),
                backgroundColor: Colors.orange,
                padding: EdgeInsets.zero,
              ),
        children: [
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (sincronizado && serverId != null) ...[
                  _buildInfoRow('Estado', 'Sincronizado', Colors.green),
                  _buildInfoRow('ID Servidor', '#$serverId', Colors.blue),
                ] else ...[
                  _buildInfoRow('Estado', 'No sincronizado', Colors.orange),
                  if (errorSync != null)
                    _buildInfoRow('Error', errorSync, Colors.red, isError: true),
                ],
                SizedBox(height: 12),
                if (!sincronizado)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: Icon(Icons.cloud_upload),
                      label: Text('Sincronizar Ahora'),
                      onPressed: _isSyncing ? null : () => _sincronizarCierre(id),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal[700],
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, Color color, {bool isError = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: isError ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
