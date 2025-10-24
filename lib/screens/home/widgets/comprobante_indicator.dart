import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/ComprobanteModel.dart';

/// Widget que muestra el indicador del número de comprobante actual
/// Se muestra como un contenedor naranja con un icono de recibo
class ComprobanteIndicator extends StatelessWidget {
  const ComprobanteIndicator({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ComprobanteModel>(
      builder: (context, comprobanteModel, child) {
        return Container(
          height: 36,
          width: 100,
          padding: EdgeInsets.symmetric(horizontal: 15),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(13),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 2,
                offset: Offset(0, 1),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.receipt_long,
                color: Colors.white,
                size: 20,
              ),
              SizedBox(width: 5),
              Text(
                '${comprobanteModel.comprobanteNumber}',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
