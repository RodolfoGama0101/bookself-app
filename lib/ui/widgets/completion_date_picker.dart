import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Conclusão é uma data do calendário local, até hoje, sem hora.
Future<DateTime?> showCompletionDatePicker(
  BuildContext context, {
  DateTime? initialDate,
  String helpText = 'Quando você terminou a leitura?',
  String fieldLabelText = 'Data de conclusão',
}) {
  final today = DateUtils.dateOnly(DateTime.now());
  final firstDate = DateTime(1);
  final previous = initialDate == null
      ? today
      : DateUtils.dateOnly(initialDate);
  final initial = previous.isBefore(firstDate) || previous.isAfter(today)
      ? today
      : previous;

  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: firstDate,
    lastDate: today,
    helpText: helpText,
    cancelText: 'Cancelar',
    confirmText: 'Confirmar',
    fieldLabelText: fieldLabelText,
    fieldHintText: 'dd/mm/aaaa',
    errorFormatText: 'Use o formato dd/mm/aaaa.',
    errorInvalidText: 'Informe uma data válida até hoje.',
    builder: (context, child) => Localizations.override(
      context: context,
      locale: const Locale('pt', 'BR'),
      delegates: GlobalMaterialLocalizations.delegates,
      child: child!,
    ),
  );
}
