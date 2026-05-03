import 'dart:convert';
import 'dart:typed_data';

/// Determines whether the index applies to a single collection or a collection group.
enum QueryScope {
  /// Index applies only to a single collection.
  collection,

  /// Index applies to all collections with the same ID.
  collectionGroup,
}

/// The sorting order for a field in the index.
enum FieldOrder {
  /// Ascending order.
  ascending,

  /// Descending order.
  descending,
}

/// Represents a single field and its sorting order within a Firestore index.
class IndexField {
  /// The path of the field.
  final String fieldPath;

  /// The sorting direction (ascending or descending).
  final FieldOrder order;

  /// Creates a new [IndexField].
  IndexField(this.fieldPath, this.order);

  /// Converts this field to a JSON representation required by firebase.json.
  Map<String, dynamic> toJson() => {
    'fieldPath': fieldPath,
    'order': order == FieldOrder.ascending ? 'ASCENDING' : 'DESCENDING',
  };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IndexField &&
          runtimeType == other.runtimeType &&
          fieldPath == other.fieldPath &&
          order == other.order;

  @override
  int get hashCode => fieldPath.hashCode ^ order.hashCode;
}

/// Represents a complete Firestore composite index configuration.
class IndexConfig {
  /// The collection group this index applies to.
  final String collectionGroup;

  /// The list of fields and their order.
  final List<IndexField> fields;

  /// The scope of the query.
  final QueryScope queryScope;

  /// Creates a new [IndexConfig].
  IndexConfig({
    required this.collectionGroup,
    required this.fields,
    required this.queryScope,
  });

  /// Converts this index to a JSON representation required by firebase.json.
  Map<String, dynamic> toJson() => {
    'collectionGroup': collectionGroup,
    'queryScope': queryScope == QueryScope.collection
        ? 'COLLECTION'
        : 'COLLECTION_GROUP',
    'fields': fields.map((f) => f.toJson()).toList(),
  };
}

/// Parses a firestore create_composite URL parameter (base64url proto3).
IndexConfig? parseIndexUrl(String url) {
  try {
    final uri = Uri.parse(url);
    final base64String = uri.queryParameters['create_composite']?.trim();
    if (base64String == null) {
      return null;
    }

    // Pad base64url if necessary
    var normalized = base64String.replaceAll('-', '+').replaceAll('_', '/');
    while (normalized.length % 4 != 0) {
      normalized += '=';
    }

    final bytes = base64Decode(normalized);
    return _decodeProto(bytes);
  } catch (e) {
    return null;
  }
}

IndexConfig _decodeProto(Uint8List bytes) {
  String? collectionGroup;
  List<IndexField> fields = [];
  QueryScope queryScope = QueryScope.collection;

  int offset = 0;

  while (offset < bytes.length) {
    final tagResult = _readVarint(bytes, offset);
    final tag = tagResult.value;
    offset = tagResult.newOffset;

    final fieldNumber = tag >> 3;
    final wireType = tag & 0x07;

    if (fieldNumber == 1 && wireType == 2) {
      // name (v1/r schema)
      final lenResult = _readVarint(bytes, offset);
      final len = lenResult.value;
      offset = lenResult.newOffset;
      final nameStr = utf8.decode(bytes.sublist(offset, offset + len));
      offset += len;
      final match = RegExp(r'collectionGroups/([^/]+)/').firstMatch(nameStr);
      if (match != null) {
        collectionGroup = match.group(1);
      }
    } else if (fieldNumber == 2 && wireType == 2) {
      // collectionGroup (old schema)
      final lenResult = _readVarint(bytes, offset);
      final len = lenResult.value;
      offset = lenResult.newOffset;
      collectionGroup = utf8.decode(bytes.sublist(offset, offset + len));
      offset += len;
    } else if (fieldNumber == 2 && wireType == 0) {
      // queryScope (v1/r schema)
      final valResult = _readVarint(bytes, offset);
      offset = valResult.newOffset;
      queryScope = valResult.value == 2
          ? QueryScope.collectionGroup
          : QueryScope.collection;
    } else if (fieldNumber == 3 && wireType == 2) {
      // fields
      final lenResult = _readVarint(bytes, offset);
      final len = lenResult.value;
      offset = lenResult.newOffset;
      fields.add(_decodeIndexField(bytes.sublist(offset, offset + len)));
      offset += len;
    } else if (fieldNumber == 4 && wireType == 0) {
      // queryScope (old schema)
      final valResult = _readVarint(bytes, offset);
      offset = valResult.newOffset;
      queryScope = valResult.value == 2
          ? QueryScope.collectionGroup
          : QueryScope.collection;
    } else {
      // Skip unknown field
      offset = _skipField(bytes, offset, wireType);
    }
  }

  if (collectionGroup == null) {
    throw FormatException('Missing collectionGroup in proto');
  }

  return IndexConfig(
    collectionGroup: collectionGroup,
    fields: fields,
    queryScope: queryScope,
  );
}

IndexField _decodeIndexField(Uint8List bytes) {
  String? fieldPath;
  FieldOrder order = FieldOrder.ascending;

  int offset = 0;
  while (offset < bytes.length) {
    final tagResult = _readVarint(bytes, offset);
    final tag = tagResult.value;
    offset = tagResult.newOffset;

    final fieldNumber = tag >> 3;
    final wireType = tag & 0x07;

    if (fieldNumber == 1 && wireType == 2) {
      final lenResult = _readVarint(bytes, offset);
      final len = lenResult.value;
      offset = lenResult.newOffset;
      fieldPath = utf8.decode(bytes.sublist(offset, offset + len));
      offset += len;
    } else if (fieldNumber == 2 && wireType == 0) {
      final valResult = _readVarint(bytes, offset);
      offset = valResult.newOffset;
      order = valResult.value == 2
          ? FieldOrder.descending
          : FieldOrder.ascending;
    } else {
      offset = _skipField(bytes, offset, wireType);
    }
  }

  if (fieldPath == null) {
    throw FormatException('Missing fieldPath in nested proto');
  }

  return IndexField(fieldPath, order);
}

class _VarintResult {
  final int value;
  final int newOffset;
  _VarintResult(this.value, this.newOffset);
}

_VarintResult _readVarint(Uint8List bytes, int offset) {
  int result = 0;
  int shift = 0;
  while (true) {
    if (offset >= bytes.length) {
      throw FormatException('Unexpected EOF while reading varint');
    }
    final byte = bytes[offset++];
    result |= ((byte & 0x7F) << shift) & 0xFFFFFFFF;
    if ((byte & 0x80) == 0) {
      return _VarintResult(result, offset);
    }
    shift += 7;
  }
}

int _skipField(Uint8List bytes, int offset, int wireType) {
  switch (wireType) {
    case 0: // Varint
      return _readVarint(bytes, offset).newOffset;
    case 1: // 64-bit
      return offset + 8;
    case 2: // Length-delimited
      final lenResult = _readVarint(bytes, offset);
      return lenResult.newOffset + lenResult.value;
    case 5: // 32-bit
      return offset + 4;
    default:
      throw FormatException('Unsupported wireType: $wireType');
  }
}
