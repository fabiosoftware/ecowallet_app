import 'package:flutter/material.dart';

class DashboardPage extends StatelessWidget {
  // Correção aplicada usando super.key em vez de repetir o parâmetro no construtor tradicional
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('EcoWallet Dashboard'),
        backgroundColor: Colors.green,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet, size: 80, color: Colors.green),
            SizedBox(height: 16),
            Text(
              'Bem-vindo ao EcoWallet',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text('Seu impacto financeiro e ecológico sob controle.'),
          ],
        ),
      ),
    );
  }
}
