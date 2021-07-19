import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const BACKGROUND = Color.fromARGB(255, 214, 247, 255);
const WIDGETS = Color.fromARGB(255, 10, 208, 247);
const APPBAR = Color.fromARGB(255, 10, 208, 247);
const ICONS = Color.fromARGB(255, 0, 0, 0);
const BORDER = Color.fromARGB(255, 0, 0, 0);
const INPUT_TEXT = Color.fromARGB(255, 0, 0, 0);
const TEXT = Color.fromARGB(255, 0, 0, 0);
const BUTTON = Color.fromARGB(255, 50, 247, 255);
const BUTTON_TEXT = Color.fromARGB(255, 25, 25, 25);
const PROGRESS_B_LIMIT = Color.fromARGB(255,2, 250, 118);
const PROGRESS_A_LIMIT = Color.fromARGB(255,250, 2, 56);
const PROGRESS_BACKGROUND = Color.fromARGB(255,100, 100, 100);

OutlineInputBorder outlineInputBorder = new OutlineInputBorder(
    borderSide: BorderSide(
  color: BORDER,
));

ButtonStyle loginButton = ButtonStyle(
    backgroundColor: MaterialStateProperty.all(BUTTON),
    shape: MaterialStateProperty.all(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))));

