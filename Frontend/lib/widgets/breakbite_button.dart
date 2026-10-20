import 'package:flutter/material.dart';

class ServeoButton extends StatelessWidget{
  final String child;
  final VoidCallback onPressed;

  const ServeoButton({super.key, required this.child, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
        onPressed: onPressed,
        child: Text(
            child,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: Colors.black
            ),
        ),
    );
  }
}

typedef BreakBiteButton = ServeoButton;