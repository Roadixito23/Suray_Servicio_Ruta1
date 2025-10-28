import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/ComprobanteModel.dart';
import '../utils/ReporteCaja.dart';
import '../utils/generateCargo_Ticket.dart';

class CargoScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onTransactionComplete;
  CargoScreen({this.onTransactionComplete});

  @override
  _CargoScreenState createState() => _CargoScreenState();
}

class _CargoScreenState extends State<CargoScreen> {
  final TextEditingController _articuloController = TextEditingController();
  final TextEditingController _precioController   = TextEditingController();
  final TextEditingController _destController     = TextEditingController();
  final TextEditingController _phoneController    = TextEditingController();

  bool _isLoading = false;
  String _destinoSeleccionado = "Aysén";

  final FocusNode _articuloFocus = FocusNode();
  final FocusNode _precioFocus   = FocusNode();
  final FocusNode _destFocus     = FocusNode();
  final FocusNode _phoneFocus    = FocusNode();

  @override
  void dispose() {
    _articuloController.dispose();
    _precioController.dispose();
    _destController.dispose();
    _phoneController.dispose();
    _articuloFocus.dispose();
    _precioFocus.dispose();
    _destFocus.dispose();
    _phoneFocus.dispose();
    super.dispose();
  }

  void _toggleDestino() {
    setState(() {
      _destinoSeleccionado =
      _destinoSeleccionado == "Aysén" ? "Coyhaique" : "Aysén";
    });
  }

  bool _validateFields() {
    if (_articuloController.text.isEmpty ||
        _precioController.text.isEmpty   ||
        _destController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Completa los campos obligatorios'))
      );
      return false;
    }
    double precio = double.tryParse(_precioController.text) ?? 0.0;
    if (precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El precio debe ser mayor a cero'))
      );
      return false;
    }
    // teléfono es opcional; gracias al inputFormatter, nunca supera 9 dígitos
    return true;
  }

  Future<void> _handlePrint() async {
    if (!_validateFields()) return;
    setState(() => _isLoading = true);

    try {
      final comprobanteModel =
      Provider.of<ComprobanteModel>(context, listen: false);
      final reporteCaja =
      Provider.of<ReporteCaja>(context, listen: false);

      final generator =
      CargoTicketGenerator(comprobanteModel, reporteCaja);

      String articulo     = _articuloController.text;
      double precio       = double.parse(_precioController.text);
      String destinatario = _destController.text;
      String telefono     = _phoneController.text; // opcional, hasta 9 dígitos

      await generator.generateNewCargoPdf(
        destinatario,
        articulo,
        precio,
        _destinoSeleccionado,
        telefono,
      );

      if (widget.onTransactionComplete != null) {
        widget.onTransactionComplete!({
          'destino': _destinoSeleccionado,
          'articulo': articulo,
          'precio': precio,
          'destinatario': destinatario,
          'telefono': telefono,
        });
      }

      _articuloController.clear();
      _precioController.clear();
      _destController.clear();
      _phoneController.clear();

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cargo generado correctamente'))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'))
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Cargo Express'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Selector de destino
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Destino: $_destinoSeleccionado',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: Icon(Icons.swap_horiz),
                      onPressed: _toggleDestino,
                    )
                  ],
                ),
              ),
            ),
            SizedBox(height: 16),

            // Artículo
            TextField(
              controller: _articuloController,
              focusNode: _articuloFocus,
              decoration: InputDecoration(
                labelText: 'Descripción del Artículo *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.shopping_bag),
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_precioFocus),
            ),
            SizedBox(height: 16),

            // Precio
            TextField(
              controller: _precioController,
              focusNode: _precioFocus,
              decoration: InputDecoration(
                labelText: 'Precio *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_destFocus),
            ),
            SizedBox(height: 16),

            // Destinatario
            TextField(
              controller: _destController,
              focusNode: _destFocus,
              decoration: InputDecoration(
                labelText: 'Nombre del Destinatario *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              textInputAction: TextInputAction.next,
              onSubmitted: (_) =>
                  FocusScope.of(context).requestFocus(_phoneFocus),
            ),
            SizedBox(height: 16),

            // Teléfono (opcional) hasta 9 dígitos, con pista "(Incluir el 9)"
            TextField(
              controller: _phoneController,
              focusNode: _phoneFocus,
              decoration: InputDecoration(
                labelText: 'Teléfono (opcional)',
                hintText: '(Incluir el 9)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(9),
              ],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _handlePrint(),
            ),
            SizedBox(height: 24),

            ElevatedButton.icon(
              icon: Icon(Icons.mail),
              label: Text('Imprimir Ticket de Cargo'),
              onPressed: _handlePrint,
            ),
          ],
        ),
      ),
    );
  }
}
