import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../utils/ReporteCaja.dart';

/// AppBar personalizado para la pantalla Home con botones de acción
class CustomHomeAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String currentDay;
  final Map<String, dynamic>? lastTransaction;
  final bool hasReprinted;
  final bool isReprinting;
  final bool hasAnulado;
  final VoidCallback onReportPressed;
  final VoidCallback onReprintPressed;
  final VoidCallback onDeletePressed;
  final VoidCallback onSettingsPressed;

  const CustomHomeAppBar({
    Key? key,
    required this.currentDay,
    required this.lastTransaction,
    required this.hasReprinted,
    required this.isReprinting,
    required this.hasAnulado,
    required this.onReportPressed,
    required this.onReprintPressed,
    required this.onDeletePressed,
    required this.onSettingsPressed,
  }) : super(key: key);

  @override
  Size get preferredSize => Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    double buttonMargin = 9.0;
    double reportButtonLeftMargin = 15;

    return AppBar(
      backgroundColor: Colors.amber[800],
      automaticallyImplyLeading: false,
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Grupo izquierdo - 3 botones
          Row(
            children: [
              _buildReportButton(reportButtonLeftMargin, buttonMargin),
              _buildReprintButton(buttonMargin),
              _buildDeleteButton(buttonMargin),
            ],
          ),

          // Espacio flexible en el medio
          Spacer(),

          // Grupo derecho - Ajustes + Fecha/Día
          Row(
            children: [
              _buildSettingsButton(),
              _buildDateDisplay(),
            ],
          ),
        ],
      ),
      titleSpacing: 0,
    );
  }

  /// Botón de Reportes
  Widget _buildReportButton(double leftMargin, double rightMargin) {
    return Container(
      width: 35,
      height: 35,
      margin: EdgeInsets.only(left: leftMargin, right: rightMargin),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF1900A2),
      ),
      child: IconButton(
        icon: Icon(
          Icons.receipt,
          color: Colors.white,
          size: 24,
        ),
        padding: EdgeInsets.zero,
        tooltip: 'Reportes',
        onPressed: onReportPressed,
      ),
    );
  }

  /// Botón de Reimprimir
  Widget _buildReprintButton(double horizontalMargin) {
    bool isCargo = lastTransaction != null &&
        lastTransaction!['nombre'].toString().toLowerCase().contains('cargo');
    bool canReprint = lastTransaction != null &&
        !isReprinting &&
        (isCargo || !hasReprinted);

    return Container(
      width: 35,
      height: 35,
      margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: canReprint ? Color(0xFFFFD71F) : Colors.white,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: canReprint ? onReprintPressed : null,
          child: Center(
            child: Image.asset(
              'assets/reprint.png',
              width: 32,
              height: 32,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }

  /// Botón de Anular
  Widget _buildDeleteButton(double horizontalMargin) {
    return Consumer<ReporteCaja>(
      builder: (context, reporteCaja, child) {
        bool canAnular = reporteCaja.hasActiveTransactions() && !hasAnulado;
        return Container(
          width: 35,
          height: 35,
          margin: EdgeInsets.symmetric(horizontal: horizontalMargin),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: canAnular ? Color(0xFFFF0C00) : Colors.white,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(21),
              onTap: canAnular ? onDeletePressed : null,
              child: Center(
                child: Icon(
                  Icons.delete,
                  color: Colors.black,
                  size: 24,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Botón de Ajustes
  Widget _buildSettingsButton() {
    return Container(
      width: 35,
      height: 35,
      margin: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0xFF00910B),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(21),
          onTap: onSettingsPressed,
          child: Center(
            child: Icon(
              Icons.settings,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }

  /// Display de Fecha y Día
  Widget _buildDateDisplay() {
    return Container(
      margin: EdgeInsets.only(left: 0, right: 5),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _getCurrentDate(),
            style: TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
          Text(
            currentDay,
            style: TextStyle(
              color: Colors.black,
              fontSize: 15,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  String _getCurrentDate() {
    return DateFormat('dd/MM/yyyy').format(DateTime.now());
  }
}
