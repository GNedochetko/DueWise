class ActivityAddress {
  const ActivityAddress({
    this.cep = '',
    this.street = '',
    this.neighborhood = '',
    this.city = '',
    this.state = '',
    this.number = '',
    this.complement = '',
  });
  factory ActivityAddress.fromMap(Map<String, Object?> map) => ActivityAddress(
    cep: map['cep'] as String? ?? '',
    street: map['street'] as String? ?? '',
    neighborhood: map['neighborhood'] as String? ?? '',
    city: map['city'] as String? ?? '',
    state: map['state'] as String? ?? '',
    number: map['number'] as String? ?? '',
    complement: map['complement'] as String? ?? '',
  );
  final String cep;
  final String street;
  final String neighborhood;
  final String city;
  final String state;
  final String number;
  final String complement;
  bool get isEmpty => [
    cep,
    street,
    neighborhood,
    city,
    state,
    number,
    complement,
  ].every((value) => value.isEmpty);
  Map<String, Object?> toMap() => {
    'cep': cep,
    'street': street,
    'neighborhood': neighborhood,
    'city': city,
    'state': state,
    'number': number,
    'complement': complement,
  };
  String get formatted => [
    [street, number].where((value) => value.isNotEmpty).join(', '),
    complement,
    neighborhood,
    [city, state].where((value) => value.isNotEmpty).join(' - '),
    if (cep.isNotEmpty)
      'CEP ${cep.length == 8 ? '${cep.substring(0, 5)}-${cep.substring(5)}' : cep}',
  ].where((value) => value.isNotEmpty).join('\n');
}
