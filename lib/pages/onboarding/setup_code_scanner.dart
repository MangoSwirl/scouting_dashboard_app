import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:scouting_dashboard_app/constants.dart';
import 'package:scouting_dashboard_app/reusable/scanner_body.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetupCodeScannerPage extends StatefulWidget {
  const SetupCodeScannerPage({super.key});

  @override
  State<SetupCodeScannerPage> createState() => _SetupCodeScannerPageState();
}

class _SetupCodeScannerPageState extends State<SetupCodeScannerPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup with QR Code")),
      body: ScannerBody(
        onDetect: ((barcodeCapture) async {
          Barcode? barcode;
          if (barcodeCapture.barcodes.isEmpty) {
            barcode = null;
          } else {
            barcode = barcodeCapture.barcodes.first;
          }

          if (barcode == null) {
            const snackBar = SnackBar(
              content: Text("Failed to scan code"),
              behavior: SnackBarBehavior.floating,
            );

            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
            return;
          }

          final String code = barcode.rawValue!;

          final String serverAuthority = code;

          debugPrint("serverAuthority: $serverAuthority");

          // Validation

          if (!validServerAuthority.hasMatch(serverAuthority)) {
            const snackBar = SnackBar(
              content: Text("Invalid server authority"),
              behavior: SnackBarBehavior.floating,
            );

            // ignore: use_build_context_synchronously
            ScaffoldMessenger.of(context).showSnackBar(snackBar);
            return;
          }

          // Update preferences
          final SharedPreferences prefs = await SharedPreferences.getInstance();

          await prefs.setString("serverAuthority", serverAuthority);

          var snackBar = SnackBar(
            content: Text("Set server authority to $serverAuthority"),
            behavior: SnackBarBehavior.floating,
          );

          // ignore: use_build_context_synchronously
          ScaffoldMessenger.of(context).showSnackBar(snackBar);

          // ignore: use_build_context_synchronously
          Navigator.of(context).pushNamedAndRemoveUntil(
              "/tournament_selector", (route) => false);
        }),
        childBelow: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            SizedBox(height: 23),
            Text("Ask your server manager for a setup code."),
          ],
        ),
      ),
    );
  }
}
