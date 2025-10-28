import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../utils/ReporteCaja.dart';

/// Widget que muestra el contador de transacciones dividido en:
/// - Lado izquierdo (azul): Total de transacciones del día
/// - Centro (verde): Transacciones netas (transacciones - anulaciones)
/// - Lado derecho (rojo): Total de anulaciones del día
class TransactionCounter extends StatelessWidget {
  const TransactionCounter({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: 150,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(13),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 2,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Fondo dividido en dos colores
          Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFF1900A2),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(13),
                      bottomLeft: Radius.circular(13),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Color(0xFFFF0C00),
                    borderRadius: BorderRadius.only(
                      topRight: Radius.circular(13),
                      bottomRight: Radius.circular(13),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Contador de transacciones (lado izquierdo)
          Positioned(
            left: 13,
            child: _buildTransactionCount(),
          ),

          // Contador de anulaciones (lado derecho)
          Positioned(
            right: 13,
            child: _buildAnulacionCount(),
          ),

          // Contador neto en el centro
          _buildNetCount(),
        ],
      ),
    );
  }

  /// Construye el contador de transacciones del día (excluyendo anulaciones)
  Widget _buildTransactionCount() {
    return Consumer<ReporteCaja>(
      builder: (context, reporteCaja, child) {
        DateTime today = DateTime.now();
        String todayDay = DateFormat('dd').format(today);
        String todayMonth = DateFormat('MM').format(today);

        var allTransactions = reporteCaja.getOrderedTransactions();
        var todayTransactions = allTransactions.where((t) =>
          t['dia'] == todayDay &&
          t['mes'] == todayMonth &&
          !t['nombre'].toString().startsWith('Anulación:')
        ).toList();

        return Text(
          '${todayTransactions.length}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 23,
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }

  /// Construye el contador de anulaciones del día
  Widget _buildAnulacionCount() {
    return Consumer<ReporteCaja>(
      builder: (context, reporteCaja, child) {
        DateTime today = DateTime.now();
        String todayDay = DateFormat('dd').format(today);
        String todayMonth = DateFormat('MM').format(today);

        var allTransactions = reporteCaja.getOrderedTransactions();
        var todayAnulaciones = allTransactions.where((t) =>
          t['dia'] == todayDay &&
          t['mes'] == todayMonth &&
          t['nombre'].toString().startsWith('Anulación:')
        ).toList();

        return Text(
          '${todayAnulaciones.length}',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 23,
          ),
          textAlign: TextAlign.center,
        );
      },
    );
  }

  /// Construye el contador neto (transacciones - anulaciones) en el centro
  Widget _buildNetCount() {
    return Consumer<ReporteCaja>(
      builder: (context, reporteCaja, child) {
        DateTime today = DateTime.now();
        String todayDay = DateFormat('dd').format(today);
        String todayMonth = DateFormat('MM').format(today);

        var allTransactions = reporteCaja.getOrderedTransactions();

        var todayTransactions = allTransactions.where((t) =>
          t['dia'] == todayDay &&
          t['mes'] == todayMonth &&
          !t['nombre'].toString().startsWith('Anulación:')
        ).toList();

        var todayAnulaciones = allTransactions.where((t) =>
          t['dia'] == todayDay &&
          t['mes'] == todayMonth &&
          t['nombre'].toString().startsWith('Anulación:')
        ).toList();

        int netCount = todayTransactions.length - todayAnulaciones.length;

        return Container(
          width: 60,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green,
            border: Border.all(color: Colors.white, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black38,
                blurRadius: 3,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '$netCount',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }
}
