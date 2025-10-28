import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import '../services/database_service.dart';
import '../utils/ReporteCaja.dart';
import 'package:provider/provider.dart';

class RecoveryReport extends StatefulWidget {
  @override
  _RecoveryReportState createState() => _RecoveryReportState();
}

class _RecoveryReportState extends State<RecoveryReport> with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  List<Map<String, dynamic>> _cierres = [];
  bool isLoading = true;
  String _searchQuery = '';
  String _filterPeriod = 'all'; // all, week, month, custom
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES', null);

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 800),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0)
        .animate(CurvedAnimation(parent: _animationController, curve: Curves.easeIn));

    _loadCierresCaja();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadCierresCaja() async {
    setState(() {
      isLoading = true;
    });

    try {
      final cierres = await _dbService.getCierresCaja();
      setState(() {
        _cierres = cierres;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al cargar cierres de caja: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  List<Map<String, dynamic>> _getFilteredCierres() {
    var filtered = _cierres;

    // Filtrar por período
    if (_filterPeriod == 'week') {
      final weekAgo = DateTime.now().subtract(Duration(days: 7));
      filtered = filtered.where((cierre) {
        final fecha = _parseFecha(cierre['fecha_cierre']);
        return fecha.isAfter(weekAgo);
      }).toList();
    } else if (_filterPeriod == 'month') {
      final monthAgo = DateTime.now().subtract(Duration(days: 30));
      filtered = filtered.where((cierre) {
        final fecha = _parseFecha(cierre['fecha_cierre']);
        return fecha.isAfter(monthAgo);
      }).toList();
    }

    // Filtrar por búsqueda
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((cierre) {
        final fecha = cierre['fecha_cierre'].toString().toLowerCase();
        return fecha.contains(_searchQuery.toLowerCase());
      }).toList();
    }

    return filtered;
  }

  DateTime _parseFecha(String fechaStr) {
    try {
      return DateFormat('dd/MM/yyyy HH:mm').parse(fechaStr);
    } catch (e) {
      return DateTime.now();
    }
  }

  String _getDayOfWeekInSpanish(int weekday) {
    switch (weekday) {
      case 1: return "Lunes";
      case 2: return "Martes";
      case 3: return "Miércoles";
      case 4: return "Jueves";
      case 5: return "Viernes";
      case 6: return "Sábado";
      case 7: return "Domingo";
      default: return "";
    }
  }

  Color _getColorByDay(int weekday) {
    if (weekday == 7) return Colors.red.shade700; // Domingo
    if (weekday == 6) return Colors.orange.shade700; // Sábado
    return Colors.teal.shade700; // Días de semana
  }

  Future<void> _showCierreDetails(Map<String, dynamic> cierre) async {
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    final transacciones = await reporteCaja.getTransaccionesByCierre(cierre['id']);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, controller) => Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Header
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detalles del Cierre',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.teal.shade800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      cierre['fecha_cierre'],
                      style: TextStyle(fontSize: 16, color: Colors.grey.shade600),
                    ),
                    SizedBox(height: 16),
                    // Resumen cards
                    Row(
                      children: [
                        Expanded(
                          child: _buildSummaryCard(
                            'Total',
                            NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0)
                                .format(cierre['total_ingresos']),
                            Icons.attach_money,
                            Colors.green,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildSummaryCard(
                            'Transacciones',
                            cierre['total_transacciones'].toString(),
                            Icons.receipt_long,
                            Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 16),
                    Divider(),
                    SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Transacciones (${transacciones.length})',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              // Lista de transacciones
              Expanded(
                child: transacciones.isEmpty
                    ? Center(
                        child: Text(
                          'No hay transacciones',
                          style: TextStyle(color: Colors.grey),
                        ),
                      )
                    : ListView.builder(
                        controller: controller,
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        itemCount: transacciones.length,
                        itemBuilder: (context, index) {
                          final t = transacciones[index];
                          final isNegative = (t['valor'] as num) < 0;
                          return Card(
                            margin: EdgeInsets.only(bottom: 8),
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isNegative ? Colors.red.shade100 : Colors.grey.shade200,
                              ),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: isNegative
                                      ? Colors.red.shade50
                                      : Colors.teal.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isNegative ? Icons.remove_circle : Icons.add_circle,
                                  color: isNegative ? Colors.red : Colors.teal,
                                  size: 24,
                                ),
                              ),
                              title: Text(
                                t['nombre'],
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: isNegative ? Colors.red.shade800 : Colors.black87,
                                ),
                              ),
                              subtitle: Text(
                                '${t['hora']} • ${t['comprobante']}',
                                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                              ),
                              trailing: Text(
                                NumberFormat.currency(
                                  locale: 'es_CL',
                                  symbol: '\$',
                                  decimalDigits: 0,
                                ).format(t['valor']),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: isNegative ? Colors.red.shade700 : Colors.green.shade700,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCierres = _getFilteredCierres();

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          'Historial de Cierres',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 22),
        ),
        backgroundColor: Colors.teal.shade700,
        elevation: 0,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Actualizar',
            onPressed: _loadCierresCaja,
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.filter_list),
            tooltip: 'Filtrar',
            onSelected: (value) {
              setState(() {
                _filterPeriod = value;
              });
            },
            itemBuilder: (context) => [
              PopupMenuItem(value: 'all', child: Text('Todos')),
              PopupMenuItem(value: 'week', child: Text('Última semana')),
              PopupMenuItem(value: 'month', child: Text('Último mes')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Barra de búsqueda
          Container(
            color: Colors.teal.shade700,
            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar por fecha...',
                prefixIcon: Icon(Icons.search, color: Colors.teal),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              ),
            ),
          ),
          // Stats summary
          if (!isLoading && _cierres.isNotEmpty)
            Container(
              margin: EdgeInsets.all(16),
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.teal.shade600, Colors.teal.shade400],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.teal.shade200,
                    blurRadius: 8,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem(
                    'Total Cierres',
                    filteredCierres.length.toString(),
                    Icons.library_books,
                  ),
                  Container(height: 40, width: 1, color: Colors.white.withOpacity(0.3)),
                  _buildStatItem(
                    'Ingresos Totales',
                    NumberFormat.compactCurrency(
                      locale: 'es_CL',
                      symbol: '\$',
                      decimalDigits: 0,
                    ).format(_cierres.fold<double>(
                      0,
                      (sum, c) => sum + (c['total_ingresos'] as num).toDouble(),
                    )),
                    Icons.monetization_on,
                  ),
                ],
              ),
            ),
          // Lista de cierres
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.teal),
                          ),
                          SizedBox(height: 20),
                          Text(
                            'Cargando cierres...',
                            style: TextStyle(fontSize: 16, color: Colors.teal.shade700),
                          ),
                        ],
                      ),
                    )
                  : filteredCierres.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.inbox_outlined,
                                size: 80,
                                color: Colors.grey.shade400,
                              ),
                              SizedBox(height: 16),
                              Text(
                                _searchQuery.isNotEmpty || _filterPeriod != 'all'
                                    ? 'No se encontraron cierres'
                                    : 'No hay cierres de caja registrados',
                                style: TextStyle(
                                  fontSize: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Los cierres se guardarán automáticamente',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredCierres.length,
                          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          itemBuilder: (context, index) {
                            final cierre = filteredCierres[index];
                            final fecha = _parseFecha(cierre['fecha_cierre']);
                            final dayOfWeek = _getDayOfWeekInSpanish(fecha.weekday);
                            final dayColor = _getColorByDay(fecha.weekday);

                            return Card(
                              margin: EdgeInsets.only(bottom: 12),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: () => _showCierreDetails(cierre),
                                child: Padding(
                                  padding: EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      // Día de la semana indicator
                                      Container(
                                        width: 60,
                                        height: 60,
                                        decoration: BoxDecoration(
                                          color: dayColor.withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              DateFormat('dd').format(fecha),
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.bold,
                                                color: dayColor,
                                              ),
                                            ),
                                            Text(
                                              DateFormat('MMM', 'es_ES')
                                                  .format(fecha)
                                                  .toUpperCase(),
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: dayColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      SizedBox(width: 16),
                                      // Información del cierre
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              dayOfWeek,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.grey.shade800,
                                              ),
                                            ),
                                            SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(Icons.access_time, size: 14, color: Colors.grey),
                                                SizedBox(width: 4),
                                                Text(
                                                  DateFormat('HH:mm').format(fecha),
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                                SizedBox(width: 16),
                                                Icon(Icons.receipt, size: 14, color: Colors.grey),
                                                SizedBox(width: 4),
                                                Text(
                                                  '${cierre['total_transacciones']} trans.',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            SizedBox(height: 8),
                                            Text(
                                              NumberFormat.currency(
                                                locale: 'es_CL',
                                                symbol: '\$',
                                                decimalDigits: 0,
                                              ).format(cierre['total_ingresos']),
                                              style: TextStyle(
                                                fontSize: 20,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.green.shade700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Ícono de detalles
                                      Icon(
                                        Icons.chevron_right,
                                        color: Colors.grey.shade400,
                                        size: 28,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withOpacity(0.9),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
