import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ServeoTextBox extends StatelessWidget{
  final String hint;
  final IconData icon;
  final bool obscure;
  final TextInputType keyboard;
  final TextEditingController cont;
  final List<TextInputFormatter>? inputFormatters;

  const ServeoTextBox({
    super.key,
    required this.hint,
    required this.icon,
    required this.cont,
    this.obscure = false,
    this.keyboard = TextInputType.text,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      obscureText: obscure,
      keyboardType: keyboard,
      controller: cont,
      inputFormatters: inputFormatters,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color:Colors.brown),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.brown,),
        hintText: hint,
        filled: true,
        fillColor: Colors.white70,
        contentPadding: const EdgeInsets.all(15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

typedef BreakBiteTextBox = ServeoTextBox;