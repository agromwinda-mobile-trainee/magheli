import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'HistoriqueJourPage.dart';
import 'NewTicketPage.dart';
import 'TicketsOuvertsPage.dart';

class CashierDashboard extends StatelessWidget {
  final String activityName;
  final String cashierId;
  const CashierDashboard({super.key, required this.activityName, required this.cashierId});

  Future<String?> getActivityId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("activityId");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          "Maghali • $activityName",
          style: const TextStyle(fontWeight: FontWeight.bold,color: Colors.white),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Point de Vente",
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
                    title: "Nouveau Ticket",
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => NewTicketPage(
                            activityName: activityName,
                            cashierId: cashierId,
                          ),
                        ),
                      );
                    },
                  ),
                  _DashButton(title: "Tickets Ouverts", onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TicketsOuvertsPage(
                          activityName: activityName,
                          cashierId: cashierId,
                        ),
                      ),
                    );
                  },),
                  _DashButton(title: "Historique du Jour", onTap: ()async {
                    String? cashierActivityId = await getActivityId();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => HistoriqueJourPage(cashierActivityId: cashierActivityId ?? "", cashierId: cashierId,)
                      ),
                    );
                  }),
                  _DashButton(title: "Stock Activité", onTap: () {}),
                  _DashButton(title: "Factures", onTap: () {}),
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
  final VoidCallback onTap;
  const _DashButton({required this.title, required this.onTap});

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
        child: Center(
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
