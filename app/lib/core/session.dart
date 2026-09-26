// Sipi — estado de sesión (usuario, token y saldo) con ChangeNotifier.
import 'package:flutter/foundation.dart';
import 'api.dart';
import 'models.dart';

class Session extends ChangeNotifier {
  final SipiApi api;
  User? user;
  Balance? balance;
  bool isGuest = false;

  Session({SipiApi? api}) : api = api ?? SipiApi();

  bool get loggedIn => user != null;

  /// El invitado puede explorar, pero para interactuar necesita una cuenta.
  bool get canInteract => loggedIn;

  void enterGuestMode() {
    isGuest = true;
    user = null;
    balance = null;
    api.token = null;
    notifyListeners();
  }

  void exitGuestMode() {
    isGuest = false;
    notifyListeners();
  }

  Future<void> register(String name, String email, String password) async {
    final r = await api.register(name, email, password);
    user = r.user;
    isGuest = false;
    await refreshBalance();
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    final r = await api.login(email, password);
    user = r.user;
    isGuest = false;
    await refreshBalance();
    notifyListeners();
  }

  Future<void> refreshBalance() async {
    if (!loggedIn) return;
    balance = await api.balance();
    notifyListeners();
  }

  Future<void> updateProfile({required String name, required String email}) async {
    user = await api.updateProfile(name: name, email: email);
    notifyListeners();
  }

  void logout() {
    user = null;
    balance = null;
    isGuest = false;
    api.token = null;
    notifyListeners();
  }

  String get firstName => (user?.name ?? '').split(' ').first;
}
