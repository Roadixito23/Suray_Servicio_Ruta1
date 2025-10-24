import 'package:flutter/material.dart';

/// Widget que permite alternar entre precios de días normales (Lunes a Sábado)
/// y precios de días especiales (Domingo/Feriado)
class DaySwitch extends StatelessWidget {
  final bool switchValue;
  final ValueChanged<bool> onChanged;
  final double textSize;

  const DaySwitch({
    Key? key,
    required this.switchValue,
    required this.onChanged,
    this.textSize = 24.0,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildText(),
          SizedBox(height: 5),
          _buildSwitch(),
        ],
      ),
    );
  }

  /// Construye el texto con efecto de borde
  Widget _buildText() {
    String displayText = switchValue ? 'Domingo/Feriado' : 'Lunes a Sábado';

    return Stack(
      children: [
        // Texto con borde negro
        Text(
          displayText,
          style: TextStyle(
            fontFamily: 'Hemiheads',
            fontSize: textSize,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2
              ..color = Colors.black,
          ),
        ),
        // Texto de relleno
        Text(
          displayText,
          style: TextStyle(
            fontFamily: 'Hemiheads',
            fontSize: textSize,
            color: switchValue ? Colors.red : Colors.white,
          ),
        ),
      ],
    );
  }

  /// Construye el switch
  Widget _buildSwitch() {
    return Switch(
      value: switchValue,
      onChanged: onChanged,
      activeColor: Colors.red,
      activeTrackColor: Colors.red.withOpacity(0.5),
    );
  }
}
