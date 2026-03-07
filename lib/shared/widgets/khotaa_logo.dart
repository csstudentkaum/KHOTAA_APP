import 'package:flutter/material.dart';

class KhotaaLogo extends StatelessWidget {
  final double size;
  final double padding;

  const KhotaaLogo({super.key, this.size = 90, this.padding = 12});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Padding(
        padding: EdgeInsets.all(padding),
        child: Image.asset(
          'assets/images/khotaa_logo.png',
          fit: BoxFit.contain,
        ),
      ),
    );
  }
}
