import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'ComprobanteModel.dart';
import 'ReporteCaja.dart';
import 'generateCargo_Ticket.dart';

class CargoScreen extends StatefulWidget {
  final Function(Map<String, dynamic>)? onTransactionComplete;

  CargoScreen({this.onTransactionComplete});

  @override
  _CargoScreenState createState() => _CargoScreenState();
}

class _CargoScreenState extends State<CargoScreen> {
  final TextEditingController _destinatarioController = TextEditingController();
  final TextEditingController _remitenteController = TextEditingController();
  final TextEditingController _articuloController = TextEditingController();
  final TextEditingController _precioController = TextEditingController();
  final TextEditingController _telefonoDestController = TextEditingController();
  final TextEditingController _telefonoRemitController = TextEditingController();
  final TextEditingController _ticketNumController = TextEditingController(); // Controlador para número de ticket

  bool _isLoading = false;
  // Variable para almacenar el destino seleccionado (Aysen o Coyhaique)
  String _destinoSeleccionado = "Aysén";

  // Focus nodes para manejo de tabulación entre campos
  final FocusNode _destinatarioFocus = FocusNode();
  final FocusNode _remitenteFocus = FocusNode();
  final FocusNode _articuloFocus = FocusNode();
  final FocusNode _precioFocus = FocusNode();
  final FocusNode _telefonoDestFocus = FocusNode();
  final FocusNode _telefonoRemitFocus = FocusNode();
  final FocusNode _ticketNumFocus = FocusNode(); // Focus node para número de ticket

  @override
  void dispose() {
    // Liberar controladores
    _destinatarioController.dispose();
    _remitenteController.dispose();
    _articuloController.dispose();
    _precioController.dispose();
    _telefonoDestController.dispose();
    _telefonoRemitController.dispose();
    _ticketNumController.dispose(); // Liberar controlador de número de ticket

    // Liberar focus nodes
    _destinatarioFocus.dispose();
    _remitenteFocus.dispose();
    _articuloFocus.dispose();
    _precioFocus.dispose();
    _telefonoDestFocus.dispose();
    _telefonoRemitFocus.dispose();
    _ticketNumFocus.dispose(); // Liberar focus node de número de ticket

    super.dispose();
  }

  // Método para cambiar entre Aysen y Coyhaique
  void _toggleDestino() {
    setState(() {
      _destinoSeleccionado = _destinoSeleccionado == "Aysén" ? "Coyhaique" : "Aysén";
    });
  }

  void _handlePrint() async {
    if (_validateFields()) {
      setState(() {
        _isLoading = true;
      });

      try {
        // Obtener modelos necesarios
        final comprobanteModel = Provider.of<ComprobanteModel>(context, listen: false);
        final reporteCaja = Provider.of<ReporteCaja>(context, listen: false);

        // Crear instancia del generador de tickets
        CargoTicketGenerator cargoTicketGenerator = CargoTicketGenerator(comprobanteModel, reporteCaja);

        // Obtener valores de los campos
        String destinatario = _destinatarioController.text;
        String remitente = _remitenteController.text;
        String articulo = _articuloController.text;
        double precio = double.tryParse(_precioController.text) ?? 0.0;
        String telefonoDest = _formatTelefono(_telefonoDestController.text);
        String telefonoRemit = _formatTelefono(_telefonoRemitController.text);
        String ticketNum = _ticketNumController.text; // Obtener número de ticket

        // Generar ticket de cargo con los nuevos campos y el destino seleccionado
        await cargoTicketGenerator.generateNewCargoPdf(
            destinatario,
            remitente,
            articulo,
            precio,
            telefonoDest,
            telefonoRemit,
            true, // Siempre opcional para destinatario
            true,  // Siempre opcional para remitente
            ticketNum, // Pasar número de ticket
            _destinoSeleccionado // Pasar el destino seleccionado
        );

        // Crear un mapa con los datos de la transacción
        Map<String, dynamic> transactionData = {
          'nombre': 'Cargo: $destinatario',
          'valor': precio,
          'articulo': articulo,
          'destinatario': destinatario,
          'remitente': remitente,
          'telefonoDest': telefonoDest,
          'telefonoRemit': telefonoRemit,
          'ticketNum': ticketNum,
          'destino': _destinoSeleccionado, // Incluir el destino en los datos de la transacción
          'comprobante': comprobanteModel.formattedComprobante,
          'tipo': 'cargoNuevo',
        };

        // Llamar al callback si existe
        if (widget.onTransactionComplete != null) {
          widget.onTransactionComplete!(transactionData);
        }

        // Limpiar los campos después de imprimir
        _clearFields();

        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ticket de cargo generado correctamente'))
        );
      } catch (e) {
        print('Error al generar ticket de cargo: $e');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al generar el ticket: $e'))
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validateFields() {
    // Validar que los campos requeridos no estén vacíos
    if (_destinatarioController.text.isEmpty ||
        _remitenteController.text.isEmpty ||
        _articuloController.text.isEmpty ||
        _precioController.text.isEmpty ||
        _ticketNumController.text.isEmpty) { // Validar que número de ticket no esté vacío

      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Complete todos los campos requeridos'))
      );
      return false;
    }

    // Validar el precio
    double precio = double.tryParse(_precioController.text) ?? 0.0;
    if (precio <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('El precio debe ser mayor a cero'))
      );
      return false;
    }

    return true;
  }

  void _clearFields() {
    _destinatarioController.clear();
    _remitenteController.clear();
    _articuloController.clear();
    _precioController.clear();
    _telefonoDestController.clear();
    _telefonoRemitController.clear();
    _ticketNumController.clear(); // Limpiar número de ticket
  }

  String _formatTelefono(String telefono) {
    // Si el teléfono está vacío, devolver cadena vacía
    if (telefono.isEmpty) return '';

    // Si el teléfono tiene 8 dígitos (formato chileno), agregar formato
    if (telefono.length == 8) {
      return '9${telefono.substring(0, 4)} ${telefono.substring(4)}';
    }

    // Devolver el teléfono sin formato
    return telefono;
  }

  // Mostrar diálogo de ayuda para el número de ticket
  void _showTicketHelpDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Ayuda - Número de Boleto',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ingrese el número del Boleto (Ejemplo: N°000002) y cuyo valor sea igual al valor del artículo a enviar.',
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 20),
                Image.asset(
                  'assets/tutorialTicketCargo.png',
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text('Entendido'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Registro de Cargo'),
        backgroundColor: Colors.orange,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Encabezado
            Center(
              child: Text(
                'Datos de Carga',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: 20),

            // NUEVO: Sección de selección de destino
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Destino: $_destinoSeleccionado',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.swap_horiz, size: 32, color: Colors.blue),
                      onPressed: _toggleDestino,
                      tooltip: 'Cambiar destino',
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // Campo Artículo y Precio (PRIMERO)
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del Artículo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _articuloController,
                      focusNode: _articuloFocus,
                      decoration: InputDecoration(
                        labelText: 'Descripción del Artículo *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.shopping_bag),
                      ),
                      textCapitalization: TextCapitalization.sentences,
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_precioFocus),
                    ),
                    SizedBox(height: 10),
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
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_destinatarioFocus),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // Campo Destinatario (SEGUNDO)
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del Destinatario',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _destinatarioController,
                      focusNode: _destinatarioFocus,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Destinatario *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person),
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_telefonoDestFocus),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _telefonoDestController,
                      focusNode: _telefonoDestFocus,
                      decoration: InputDecoration(
                        labelText: 'Teléfono Destinatario (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        prefixText: '+569 ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_remitenteFocus),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // Campo Remitente (TERCERO)
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Datos del Remitente',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _remitenteController,
                      focusNode: _remitenteFocus,
                      decoration: InputDecoration(
                        labelText: 'Nombre del Remitente *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      textCapitalization: TextCapitalization.words,
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_telefonoRemitFocus),
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _telefonoRemitController,
                      focusNode: _telefonoRemitFocus,
                      decoration: InputDecoration(
                        labelText: 'Teléfono Remitente (Opcional)',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.phone),
                        prefixText: '+569 ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(8),
                      ],
                      onSubmitted: (_) => FocusScope.of(context).requestFocus(_ticketNumFocus),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10),

            // NUEVO: Campo Datos del Ticket (CUARTO)
            Card(
              elevation: 3,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Datos del Boleto',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(width: 10),
                        // Ícono de ayuda clickeable
                        InkWell(
                          onTap: _showTicketHelpDialog,
                          child: Icon(
                            Icons.help_outline,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    TextField(
                      controller: _ticketNumController,
                      focusNode: _ticketNumFocus,
                      decoration: InputDecoration(
                        labelText: 'Número de Boleto *',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.confirmation_number),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.help_outline, color: Colors.blue),
                          onPressed: _showTicketHelpDialog,
                        ),
                        helperText: 'Máximo 6 dígitos',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(6), // Limitar a máximo 6 caracteres
                      ],
                      onSubmitted: (_) => _handlePrint(),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),

            // Botones
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                // Botón Cancelar
                ElevatedButton.icon(
                  icon: Icon(Icons.cancel),
                  label: Text('Cancelar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),

                // Botón Imprimir
                ElevatedButton.icon(
                  icon: Icon(Icons.print),
                  label: Text('Imprimir Ticket'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                  ),
                  onPressed: _handlePrint,
                ),
              ],
            ),

            SizedBox(height: 10),
            // Nota: campos obligatorios
            Center(
              child: Text(
                '* Campos obligatorios',
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}