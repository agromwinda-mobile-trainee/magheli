import 'package:flutter/material.dart';
import '../../common/auth_utils.dart';
import 'AdminOverviewPage.dart';
import 'AdminDailyReportPage.dart';
import 'AdminWeeklyReportPage.dart';
import 'AdminMonthlyReportPage.dart';
import 'AdminUsersPage.dart';
import '../manager/AllClientsPage.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          "Maghali • Admin",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => AuthUtils.logout(context),
            tooltip: 'Déconnexion',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Tableau de Bord",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _DashButton(
                    title: "Vue Globale",
                    icon: Icons.dashboard,
                    color: Colors.blue,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminOverviewPage(),
                        ),
                      );
                    },
                  ),
                  _DashButton(
                    title: "Gestion Utilisateurs",
                    icon: Icons.people,
                    color: Colors.teal,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminUsersPage(),
                        ),
                      );
                    },
                  ),
                  _DashButton(
                    title: "Résumé Journalier",
                    icon: Icons.today,
                    color: Colors.green,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminDailyReportPage(),
                        ),
                      );
                    },
                  ),
                  _DashButton(
                    title: "Résumé Hebdomadaire",
                    icon: Icons.date_range,
                    color: Colors.orange,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminWeeklyReportPage(),
                        ),
                      );
                    },
                  ),
                  _DashButton(
                    title: "Résumé Mensuel",
                    icon: Icons.calendar_month,
                    color: Colors.purple,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AdminMonthlyReportPage(),
                        ),
                      );
                    },
                  ),
                  _DashButton(
                    title: "Clients",
                    icon: Icons.people,
                    color: Colors.indigo,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AllClientsPage(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashButton extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color? color;
  final VoidCallback onTap;
  const _DashButton({
    required this.title,
    required this.icon,
    this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            )
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 40, color: color ?? Colors.black),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

