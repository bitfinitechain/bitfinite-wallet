/*
 * This file is part of Stack Wallet.
 *
 * Copyright (c) 2025 Cypher Stack
 * All Rights Reserved.
 * The code is distributed under GPLv3 license, see LICENSE file for details.
 *
 */

import 'package:isar_community/isar.dart';
import '../contract.dart';

part 'spl_token.g.dart';

@collection
class SplToken extends Contract {
  SplToken({
    required this.address,
    required this.name,
    required this.symbol,
    required this.decimals,
    this.logoUri,
    this.metadataAddress,
  });

  Id id = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late final String address; // Mint address.

  late final String name;

  late final String symbol;

  late final int decimals;

  late final String? logoUri;

  late final String? metadataAddress;

  SplToken copyWith({
    Id? id,
    String? address,
    String? name,
    String? symbol,
    int? decimals,
    String? logoUri,
    String? metadataAddress,
  }) =>
      SplToken(
        address: address ?? this.address,
        name: name ?? this.name,
        symbol: symbol ?? this.symbol,
        decimals: decimals ?? this.decimals,
        logoUri: logoUri ?? this.logoUri,
        metadataAddress: metadataAddress ?? this.metadataAddress,
      )..id = id ?? this.id;
}
