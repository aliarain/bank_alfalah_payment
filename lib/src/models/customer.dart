import 'package:meta/meta.dart';

/// Optional customer details attached to a [CheckoutRequest].
@immutable
class Customer {
  /// Creates customer details. All fields are optional.
  const Customer({this.name, this.email, this.phone});

  /// Customer full name.
  final String? name;

  /// Customer email address.
  final String? email;

  /// Customer phone number, e.g. `03001234567`.
  final String? phone;

  /// Serializes the non-null fields for transmission to a backend.
  Map<String, String> toJson() => {
        if (name != null) 'name': name!,
        if (email != null) 'email': email!,
        if (phone != null) 'phone': phone!,
      };

  @override
  bool operator ==(Object other) =>
      other is Customer &&
      other.name == name &&
      other.email == email &&
      other.phone == phone;

  @override
  int get hashCode => Object.hash(name, email, phone);
}
