import 'dart:math';

class PinAuthService {
  String? _currentPin;
  DateTime? _pinGeneratedAt;
  static const _pinValidityDuration = Duration(minutes: 5);

  String generatePin() {
    _currentPin = (Random().nextInt(900000) + 100000).toString();
    _pinGeneratedAt = DateTime.now();
    return _currentPin!;
  }

  bool verifyPin(String enteredPin) {
    if (_currentPin == null || _pinGeneratedAt == null) return false;

    if (DateTime.now().difference(_pinGeneratedAt!) > _pinValidityDuration) {
      clearPin();
      return false;
    }

    return _currentPin == enteredPin;
  }

  void clearPin() {
    _currentPin = null;
    _pinGeneratedAt = null;
  }

  String? get currentPin => _currentPin;

  bool get isPinValid {
    if (_currentPin == null || _pinGeneratedAt == null) return false;
    return DateTime.now().difference(_pinGeneratedAt!) <= _pinValidityDuration;
  }
}
