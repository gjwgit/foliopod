/// EventNoteField — the free-text note field shared by the editors.
///
// Time-stamp: <2026-08-08>
///
/// Copyright (C) 2026, Togaware Pty Ltd
///
/// Licensed under the GNU General Public License, Version 3

library;

import 'package:flutter/material.dart';

import 'package:emacs_text_field/emacs_text_field.dart';

/// A two-line growing note field, as used by every editor dialog.
class EventNoteField extends StatelessWidget {
  final TextEditingController controller;

  const EventNoteField({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => EmacsTextField(
    controller: controller,
    minLines: 2,
    decoration: const InputDecoration(
      labelText: 'Note',
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}
