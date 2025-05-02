import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ComprobanteModel.dart';
import 'ReporteCaja.dart';  // ← Import necesario para chequear transacciones

class ComprobanteModelSettings extends StatefulWidget {
  @override
  _ComprobanteModelSettingsState createState() => _ComprobanteModelSettingsState();
}

class _ComprobanteModelSettingsState extends State<ComprobanteModelSettings> {
  final TextEditingController _pwdCtrl = TextEditingController();
  String _currentPwd = '';

  @override
  void initState() {
    super.initState();
    _loadPwd();
  }

  Future<void> _loadPwd() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _currentPwd = prefs.getString('comprobanteSettingsPassword') ?? '';
    });
  }

  Future<void> _savePwd() async {
    final newPwd = _pwdCtrl.text.trim();
    if (newPwd.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('La contraseña debe tener 6 dígitos'))
      );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('comprobanteSettingsPassword', newPwd);
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contraseña guardada'))
    );
    _pwdCtrl.clear();
    _loadPwd();
  }

  /// Sólo reinicia el contador si NO hay transacciones activas en la caja
  Future<void> _resetCounter() async {
    final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);
    if (reporteCaja.hasActiveTransactions()) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(
              'Para reiniciar el comprobante, cierre la caja primero; no debe haber transacciones activas.'
          ))
      );
      return;
    }
    final model = Provider.of<ComprobanteModel>(context, listen: false);
    await model.resetComprobante();  // reinicia a 0 :contentReference[oaicite:0]{index=0}&#8203;:contentReference[oaicite:1]{index=1}
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Contador reiniciado a 0'))
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Configuración N° Comprobante')),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: Icon(Icons.refresh),
                title: Text('Reiniciar contador'),
                subtitle: Text('Vuelve el número de comprobante a 0'),
                trailing: ElevatedButton(
                  onPressed: _resetCounter,
                  child: Text('Reiniciar'),
                ),
              ),
            ),
            SizedBox(height: 20),
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Contraseña de acceso (6 dígitos)',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    TextField(
                      controller: _pwdCtrl,
                      decoration: InputDecoration(
                        labelText: 'Nueva contraseña',
                        border: OutlineInputBorder(),
                      ),
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                    ),
                    SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: _savePwd,
                      icon: Icon(Icons.save),
                      label: Text('Guardar Contraseña'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
