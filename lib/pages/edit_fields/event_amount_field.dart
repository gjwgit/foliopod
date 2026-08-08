/// EventAmountField — a numeric entry field used across the editors.
///
// Time-stamp: <2026-08-08>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:markdown_tooltip/markdown_tooltip.dart';

import 'package:foliopod/services/money_format.dart';

/// A number field for an amount, a quantity of units, a price or a rate.
///
/// The value must parse as a number, so a typo cannot be saved as zero.
/// An [optional] field may also be left empty.
class EventAmountField extends StatelessWidget {
  final TextEditingController controller;
  final String label;

  /// The currency prefix, or null for a units or rate field.
  final String? prefix;

  /// Markdown guidance shown on hover. No tooltip is added when null.
  final String? help;

  /// Identifies the field to the widget tests.
  final Key? fieldKey;

  /// Whether an empty field is acceptable.
  final bool optional;

  final bool autofocus;

  const EventAmountField({
    super.key,
    required this.controller,
    required this.label,
    this.prefix,
    this.help,
    this.fieldKey,
    this.optional = false,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final field = TextFormField(
      key: fieldKey,
      controller: controller,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        prefixText: prefix,
        border: const OutlineInputBorder(),
        isDense: true,
      ),
      validator: (v) =>
          (optional && (v == null || v.trim().isEmpty)) ||
              parseNum(v ?? '') != null
          ? null
          : 'Number',
    );
    return help == null ? field : MarkdownTooltip(message: help!, child: field);
  }
}
