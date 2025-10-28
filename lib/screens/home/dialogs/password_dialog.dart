import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Diálogo para ingresar contraseña
/// Utilizado para confirmar operaciones sensibles como reimprimir o anular tickets
class PasswordDialog {
  /// Muestra un diálogo de contraseña para anular venta
  static Future<bool> showDeletePasswordDialog({
    required BuildContext context,
    required String storedPassword,
  }) async {
    final TextEditingController passwordController = TextEditingController();
    bool isAuthenticated = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 24,
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange,
                size: 32,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Anular Última Venta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade800,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWarningBox(),
              SizedBox(height: 20),
              Text(
                'Ingrese la contraseña para confirmar:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 10),
              _buildPasswordField(passwordController),
            ],
          ),
          actions: <Widget>[
            _buildCancelButton(dialogContext),
            _buildDeleteButton(
              context: context,
              dialogContext: dialogContext,
              passwordController: passwordController,
              storedPassword: storedPassword,
              onAuthenticated: () => isAuthenticated = true,
            ),
          ],
          actionsPadding: EdgeInsets.only(right: 10),
          contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 10),
          backgroundColor: Colors.white,
        );
      },
    );

    return isAuthenticated;
  }

  /// Muestra un diálogo de contraseña para reimprimir
  static Future<bool> showReprintPasswordDialog({
    required BuildContext context,
    required String storedPassword,
  }) async {
    final TextEditingController passwordController = TextEditingController();
    bool isAuthenticated = false;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20.0),
          ),
          elevation: 24,
          title: Row(
            children: [
              Icon(Icons.print, color: Colors.yellow.shade600, size: 32),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Reimpresión de Boleta',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.yellow.shade800,
                    fontSize: 20,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildInfoBox(),
              SizedBox(height: 20),
              Text(
                'Ingrese la contraseña para continuar:',
                style: TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 10),
              _buildReprintPasswordField(passwordController),
            ],
          ),
          actions: [
            _buildCancelButton(dialogContext),
            _buildContinueButton(
              context: context,
              dialogContext: dialogContext,
              passwordController: passwordController,
              storedPassword: storedPassword,
              onAuthenticated: () => isAuthenticated = true,
            ),
          ],
          actionsPadding: EdgeInsets.only(right: 10),
          contentPadding: EdgeInsets.fromLTRB(24, 20, 24, 24),
          titlePadding: EdgeInsets.fromLTRB(24, 24, 24, 10),
          backgroundColor: Colors.white,
        );
      },
    );

    return isAuthenticated;
  }

  // Widgets auxiliares

  static Widget _buildWarningBox() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.red.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade800, size: 28),
              SizedBox(width: 8),
              Text(
                '¡ADVERTENCIA!',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.red.shade800,
                  fontSize: 18,
                ),
              ),
            ],
          ),
          SizedBox(height: 10),
          Text(
            'Esta acción no se puede deshacer y quedará registrada en el cierre de caja.',
            style: TextStyle(
              color: Colors.red.shade800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildInfoBox() {
    return AnimatedContainer(
      duration: Duration(milliseconds: 500),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.2),
            blurRadius: 10,
            spreadRadius: 1,
          )
        ],
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Colors.yellow.shade800, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Autenticación requerida para reimprimir boletas.',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.black,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static Widget _buildPasswordField(TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade300, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.red.shade500, width: 2),
        ),
        helperText: 'Máximo 6 dígitos',
        prefixIcon: Icon(Icons.password, color: Colors.red.shade500),
        filled: true,
        fillColor: Colors.red.shade50,
      ),
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: TextStyle(fontSize: 18, letterSpacing: 8),
    );
  }

  static Widget _buildReprintPasswordField(TextEditingController controller) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: 'Contraseña',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.yellow.shade300, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.yellow.shade300, width: 2),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.yellow.shade500, width: 2),
        ),
        helperText: 'Máximo 6 dígitos',
        prefixIcon: Icon(Icons.password, color: Colors.yellow.shade500),
        filled: true,
        fillColor: Colors.blue.shade50,
      ),
      obscureText: true,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      style: TextStyle(fontSize: 18, letterSpacing: 8),
    );
  }

  static Widget _buildCancelButton(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(bottom: 10, right: 10),
      child: TextButton(
        onPressed: () => Navigator.of(context).pop(),
        style: TextButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        child: Text(
          'Cancelar',
          style: TextStyle(
            fontSize: 16,
            color: Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  static Widget _buildDeleteButton({
    required BuildContext context,
    required BuildContext dialogContext,
    required TextEditingController passwordController,
    required String storedPassword,
    required VoidCallback onAuthenticated,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10, right: 10),
      child: ElevatedButton.icon(
        icon: Icon(Icons.delete_outline, color: Colors.white),
        label: Text(
          'Anular',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          String inputPassword = passwordController.text;

          if (inputPassword == storedPassword) {
            onAuthenticated();
            Navigator.of(dialogContext).pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 10),
                    Text('Contraseña incorrecta.'),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
  }

  static Widget _buildContinueButton({
    required BuildContext context,
    required BuildContext dialogContext,
    required TextEditingController passwordController,
    required String storedPassword,
    required VoidCallback onAuthenticated,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 10, right: 10),
      child: ElevatedButton.icon(
        icon: Icon(Icons.check_circle_outline, color: Colors.white),
        label: Text(
          'Continuar',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.yellow.shade600,
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        onPressed: () {
          String inputPassword = passwordController.text;

          if (inputPassword == storedPassword) {
            onAuthenticated();
            Navigator.of(dialogContext).pop();
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.white),
                    SizedBox(width: 10),
                    Text('Contraseña incorrecta'),
                  ],
                ),
                backgroundColor: Colors.red.shade700,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }
        },
      ),
    );
  }
}
