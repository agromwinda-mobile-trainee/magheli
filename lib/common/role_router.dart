import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../Screens/cashier/CashierDashboard.dart';
import '../Screens/cashier/ProfileCompletionPage.dart';
import '../Screens/MainCashier/MainCashierDashboard.dart';
import '../Screens/StockManagerDashboard.dart';
import '../Screens/manager/ManagerDashboard.dart';
import '../Screens/admin/AdminDashboard.dart';

/// Routeur basé sur les rôles pour rediriger vers le bon dashboard
class RoleRouter {
  static Future<void> routeAfterLogin(BuildContext context, String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final role = prefs.getString("role");
    final activityName = prefs.getString("activityName") ?? '';
    final profileCompleted = prefs.getBool("profileCompleted") ?? false;

    // Si le profil n'est pas complété, rediriger vers ProfileCompletionPage
    if (!profileCompleted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ProfileCompletionPage(uid: uid)),
      );
      return;
    }

    // Router selon le rôle
    switch (role) {
      case 'cashier':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CashierDashboard(
              activityName: activityName,
              cashierId: uid,
            ),
          ),
        );
        break;

      case 'mainCashier':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const MainCashierDashboard(),
          ),
        );
        break;

      case 'stockManager':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const StockManagerDashboard(),
          ),
        );
        break;

      case 'manager':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const ManagerDashboard(),
          ),
        );
        break;

      case 'admin':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const AdminDashboard(),
          ),
        );
        break;

      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Rôle non reconnu. Veuillez contacter un administrateur."),
          ),
        );
    }
  }
}

