// main.dart
// Professional sample UI for Winga–Shop Owner sales tracking app
// NOTE: Uses sample (mock) data only

import 'package:flutter/material.dart';

// ---------------- LOGIN SCREEN ----------------
class LoginScreen2 extends StatelessWidget {
  const LoginScreen2({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.store, size: 80, color: Colors.indigo),
              const SizedBox(height: 16),
              const Text('Winga Sales System',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              TextField(decoration: _inputDecoration('Phone Number')),
              const SizedBox(height: 12),
              TextField(
                obscureText: true,
                decoration: _inputDecoration('Password'),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => const RoleSelectScreen()),
                    );
                  },
                  child: const Padding(
                    padding: EdgeInsets.all(12.0),
                    child: Text('LOGIN'),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------- ROLE SELECTION ----------------
class RoleSelectScreen extends StatelessWidget {
  const RoleSelectScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Role')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _roleCard(
              context,
              icon: Icons.person_outline,
              title: 'Winga',
              subtitle: 'Record your sales & commissions',
              screen: const WingaDashboard(),
            ),
            _roleCard(
              context,
              icon: Icons.admin_panel_settings_outlined,
              title: 'Shop Owner',
              subtitle: 'View sales & manage payments',
              screen: const OwnerDashboard(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- WINGA DASHBOARD ----------------
class WingaDashboard extends StatelessWidget {
  const WingaDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Winga Dashboard')),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSaleScreen()),
          );
        },
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard('Today Sales', 'TZS 450,000'),
          _summaryCard('Commission Earned', 'TZS 13,500'),
          const SizedBox(height: 16),
          const Text('Recent Sales',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _saleTile('Customer A', 'TZS 120,000'),
          _saleTile('Customer B', 'TZS 200,000'),
          _saleTile('Customer C', 'TZS 130,000'),
        ],
      ),
    );
  }
}

// ---------------- ADD SALE ----------------
class AddSaleScreen extends StatelessWidget {
  const AddSaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Record Sale')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(decoration: _inputDecoration('Sale Amount (TZS)')),
            const SizedBox(height: 12),
            TextField(decoration: _inputDecoration('Notes (optional)')),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Text('SAVE SALE'),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ---------------- OWNER DASHBOARD ----------------
class OwnerDashboard extends StatelessWidget {
  const OwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Shop Owner Dashboard')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _summaryCard('Total Sales', 'TZS 5,200,000'),
          _summaryCard('Total Commission Owed', 'TZS 156,000'),
          const SizedBox(height: 16),
          const Text('Sales per Winga',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _wingaTile('Ali Hassan', 'TZS 2,000,000', 'TZS 60,000'),
          _wingaTile('Juma Selemani', 'TZS 1,700,000', 'TZS 51,000'),
          _wingaTile('Peter John', 'TZS 1,500,000', 'TZS 45,000'),
        ],
      ),
    );
  }
}

// ---------------- UI HELPERS ----------------
InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
    filled: true,
    fillColor: Colors.white,
  );
}

Widget _summaryCard(String title, String value) {
  return Card(
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: const TextStyle(fontSize: 16)),
          Text(value,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ],
      ),
    ),
  );
}

Widget _saleTile(String customer, String amount) {
  return Card(
    child: ListTile(
      leading: const Icon(Icons.shopping_cart_outlined),
      title: Text(customer),
      trailing: Text(amount,
          style: const TextStyle(fontWeight: FontWeight.bold)),
    ),
  );
}

Widget _wingaTile(String name, String sales, String commission) {
  return Card(
    child: ListTile(
      leading: const Icon(Icons.person_outline),
      title: Text(name),
      subtitle: Text('Sales: $sales'),
      trailing: Text(commission,
          style: const TextStyle(
              color: Colors.green, fontWeight: FontWeight.bold)),
    ),
  );
}

Widget _roleCard(BuildContext context,
    {required IconData icon,
    required String title,
    required String subtitle,
    required Widget screen}) {
  return Card(
    child: ListTile(
      leading: Icon(icon, size: 40),
      title: Text(title, style: const TextStyle(fontSize: 18)),
      subtitle: Text(subtitle),
      onTap: () {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => screen),
        );
      },
    ),
  );
}
