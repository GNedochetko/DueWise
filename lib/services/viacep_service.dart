import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/activity_address.dart';
import '../repositories/device_features.dart';

class ViaCepService implements AddressLookup {
  ViaCepService(this.client, {this.timeout = const Duration(seconds: 10)});
  final http.Client client;
  final Duration timeout;
  @override
  Future<ActivityAddress> lookup(String cep) async {
    final digits = cep.trim().replaceAll(RegExp(r'[-\s]'), '');
    if (!RegExp(r'^\d{8}$').hasMatch(digits)) {
      throw const AddressFailure('Informe um CEP com 8 dígitos.');
    }
    try {
      final response = await client
          .get(Uri.https('viacep.com.br', '/ws/$digits/json/'))
          .timeout(timeout);
      if (response.statusCode != 200) {
        throw const AddressFailure(
          'Não foi possível consultar o CEP. Preencha o endereço manualmente ou tente novamente.',
        );
      }
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Resposta inválida');
      }
      if (decoded['erro'] == true || decoded['erro'] == 'true') {
        throw const AddressFailure(
          'CEP não encontrado. Confira o número ou preencha o endereço manualmente.',
        );
      }
      String field(String key) {
        final value = decoded[key];
        if (value == null) return '';
        if (value is! String) throw const FormatException('Campo inválido');
        return value.trim();
      }

      final city = field('localidade');
      final state = field('uf').toUpperCase();
      if (city.isEmpty || !RegExp(r'^[A-Z]{2}$').hasMatch(state)) {
        throw const FormatException('Endereço inválido');
      }
      return ActivityAddress(
        cep: digits,
        street: field('logradouro'),
        neighborhood: field('bairro'),
        city: city,
        state: state,
      );
    } on AddressFailure {
      rethrow;
    } on TimeoutException {
      throw const AddressFailure(
        'A consulta demorou para responder. Você pode preencher o endereço manualmente.',
      );
    } on FormatException {
      throw const AddressFailure(
        'O serviço retornou um endereço inválido. Você pode preenchê-lo manualmente.',
      );
    } catch (_) {
      throw const AddressFailure(
        'Não foi possível consultar o CEP. Verifique a conexão ou preencha o endereço manualmente.',
      );
    }
  }
}
