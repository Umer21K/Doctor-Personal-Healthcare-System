
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';

class ToastUtil {
  static void show(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: Colors.black87,
      textColor: Colors.white,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }
}
