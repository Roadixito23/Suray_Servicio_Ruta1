import 'package:flutter/material.dart';

/// Grid de botones para diferentes tipos de pasajes
/// Incluye botones para Público General, Escolar, Adulto Mayor, Intermedios,
/// Oferta en Ruta y Cargo
class TicketButtonsGrid extends StatelessWidget {
  final List<Map<String, dynamic>> pasajes;
  final bool switchValue;
  final bool isButtonDisabled;
  final Function(String tipo, double valor, bool isCorrespondencia) onGenerateTicket;
  final VoidCallback onShowMultiOfferDialog;
  final VoidCallback onShowOfferDialog;
  final bool showIcons;
  final double textSizeMultiplier;
  final Map<String, IconData> buttonIcons;

  const TicketButtonsGrid({
    Key? key,
    required this.pasajes,
    required this.switchValue,
    required this.isButtonDisabled,
    required this.onGenerateTicket,
    required this.onShowMultiOfferDialog,
    required this.onShowOfferDialog,
    this.showIcons = true,
    this.textSizeMultiplier = 0.8,
    this.buttonIcons = const {},
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    double screenWidth = MediaQuery.of(context).size.width;
    double marginSize = screenWidth * 0.05;
    double buttonWidth = screenWidth - (marginSize * 2);
    double buttonHeight = 60;

    return Column(
      children: [
        // Primera fila: Público General | Intermedio hasta 50kms
        _buildButtonRow(
          buttonWidth: buttonWidth,
          buttonHeight: buttonHeight,
          leftButton: _buildButton(
            context: context,
            text: pasajes[0]['nombre'],
            icon: Icons.people,
            backgroundColor: switchValue ? Colors.grey : Colors.red,
            borderColor: switchValue ? Colors.blueAccent : Colors.black,
            onPressed: () => onGenerateTicket(
              pasajes[0]['nombre'],
              pasajes[0]['precio'],
              false,
            ),
            buttonWidth: buttonWidth,
          ),
          rightButton: _buildButton(
            context: context,
            text: pasajes[4]['nombre'],
            icon: Icons.map,
            backgroundColor: switchValue ? Colors.red : Colors.green,
            borderColor: switchValue ? Colors.pinkAccent : Colors.black,
            onPressed: () => onGenerateTicket(
              pasajes[4]['nombre'],
              pasajes[4]['precio'],
              false,
            ),
            buttonWidth: buttonWidth,
          ),
        ),
        SizedBox(height: 5),

        // Segunda fila: Escolar | Intermedio hasta 15 km
        _buildButtonRow(
          buttonWidth: buttonWidth,
          buttonHeight: buttonHeight,
          leftButton: _buildButton(
            context: context,
            text: pasajes[1]['nombre'],
            icon: Icons.school,
            backgroundColor: switchValue ? Colors.red : Colors.green,
            borderColor: switchValue ? Colors.pinkAccent : Colors.black,
            onPressed: () => onGenerateTicket(
              pasajes[1]['nombre'],
              pasajes[1]['precio'],
              false,
            ),
            buttonWidth: buttonWidth,
          ),
          rightButton: _buildButton(
            context: context,
            text: pasajes[3]['nombre'],
            icon: Icons.directions_bus,
            backgroundColor: switchValue ? Colors.red : Colors.blue,
            borderColor: switchValue ? Colors.pinkAccent : Colors.black,
            onPressed: () => onGenerateTicket(
              pasajes[3]['nombre'],
              pasajes[3]['precio'],
              false,
            ),
            buttonWidth: buttonWidth,
          ),
        ),
        SizedBox(height: 5),

        // Tercera fila: Adulto Mayor | Escolar Intermedio
        _buildButtonRow(
          buttonWidth: buttonWidth,
          buttonHeight: buttonHeight,
          leftButton: _buildButton(
            context: context,
            text: pasajes[2]['nombre'],
            icon: Icons.elderly,
            backgroundColor: switchValue ? Colors.green : Colors.blue,
            borderColor: switchValue ? Colors.yellowAccent : Colors.black,
            onPressed: () => onGenerateTicket(
              pasajes[2]['nombre'],
              pasajes[2]['precio'],
              false,
            ),
            buttonWidth: buttonWidth,
          ),
          rightButton: _buildButton(
            context: context,
            text: pasajes.length > 5 ? pasajes[5]['nombre'] : 'Escolar Intermedio',
            icon: Icons.school_outlined,
            backgroundColor: Colors.white,
            borderColor: Colors.black,
            textColor: Colors.black,
            onPressed: () {
              if (pasajes.length > 5) {
                onGenerateTicket(
                  pasajes[5]['nombre'],
                  pasajes[5]['precio'],
                  false,
                );
              } else {
                double defaultPrice = switchValue ? 1300.0 : 1000.0;
                onGenerateTicket('Escolar Intermedio', defaultPrice, false);
              }
            },
            buttonWidth: buttonWidth,
          ),
        ),
        SizedBox(height: 5),

        // Cuarta fila: Oferta en Ruta | Cargo
        _buildButtonRow(
          buttonWidth: buttonWidth,
          buttonHeight: buttonHeight,
          leftButton: _buildButton(
            context: context,
            text: 'Oferta en Ruta',
            icon: Icons.local_offer,
            backgroundColor: Colors.red,
            borderColor: Colors.black,
            textColor: Colors.yellow,
            onPressed: onShowMultiOfferDialog,
            buttonWidth: buttonWidth,
          ),
          rightButton: _buildButton(
            context: context,
            text: 'Cargo',
            icon: Icons.inventory,
            backgroundColor: isButtonDisabled ? Colors.grey : Colors.orange,
            borderColor: Colors.black,
            onPressed: onShowOfferDialog,
            buttonWidth: buttonWidth,
          ),
        ),
        SizedBox(height: 10),
      ],
    );
  }

  /// Construye una fila con dos botones
  Widget _buildButtonRow({
    required double buttonWidth,
    required double buttonHeight,
    required Widget leftButton,
    required Widget rightButton,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        SizedBox(
          width: (buttonWidth / 2) - 10,
          height: buttonHeight,
          child: leftButton,
        ),
        SizedBox(
          width: (buttonWidth / 2) - 10,
          height: buttonHeight,
          child: rightButton,
        ),
      ],
    );
  }

  /// Construye un botón configurable
  Widget _buildButton({
    required BuildContext context,
    required String text,
    required IconData icon,
    required Color backgroundColor,
    required Color borderColor,
    required Function() onPressed,
    required double buttonWidth,
    Color textColor = Colors.white,
  }) {
    double textSize = buttonWidth * 0.056;
    IconData buttonIcon = _getButtonIcon(text, icon);

    return Container(
      constraints: BoxConstraints(minHeight: 60),
      child: ElevatedButton(
        onPressed: isButtonDisabled ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(
            color: borderColor,
            width: 3,
          ),
          foregroundColor: textColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          disabledBackgroundColor: Colors.grey,
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        ),
        child: showIcons
            ? Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    buttonIcon,
                    size: textSize * textSizeMultiplier * 0.9,
                  ),
                  SizedBox(width: 0),
                  Flexible(
                    child: Text(
                      text,
                      style: TextStyle(
                        fontSize: textSize * textSizeMultiplier,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.visible,
                    ),
                  ),
                ],
              )
            : Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  text,
                  style: TextStyle(
                    fontSize: textSize * textSizeMultiplier,
                    height: 1.2,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.visible,
                ),
              ),
      ),
    );
  }

  /// Obtiene el icono personalizado para un botón específico
  IconData _getButtonIcon(String buttonName, IconData defaultIcon) {
    return buttonIcons[buttonName] ?? defaultIcon;
  }
}
