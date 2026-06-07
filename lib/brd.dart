import 'package:flutter/services.dart';

enum SquareType {
  go,
  property,
  communityChest,
  incomeTax,
  chance,
  jail,
  freeParking,
  goToJail,
  luxuryTax,
}

class Square {
  final int id;
  final SquareType type;
  // -1 if not property
  final int propertyID;

  Square(this.id, this.type, this.propertyID);

  factory Square.parse(int id, String squareStr) {
    SquareType type;
    int propertyID = -1;
    switch (squareStr) {
      case 'GO':
        type = SquareType.go;
      case 'CC':
        type = SquareType.communityChest;
      case 'IT':
        type = SquareType.incomeTax;
      case 'CH':
        type = SquareType.chance;
      case 'JA':
        type = SquareType.jail;
      case 'FP':
        type = SquareType.freeParking;
      case 'GJ':
        type = SquareType.goToJail;
      case 'LT':
        type = SquareType.luxuryTax;
      default:
        type = SquareType.property;
        propertyID = int.parse(squareStr);
    }
    return Square(id, type, propertyID);
  }

  @override
  String toString() {
    return switch (type) {
      SquareType.go => 'Go',
      SquareType.property => 'Property $propertyID',
      SquareType.communityChest => 'Community Chest',
      SquareType.incomeTax => 'Income Tax',
      SquareType.chance => 'Chance',
      SquareType.jail => 'Jail',
      SquareType.freeParking => 'Free Parking',
      SquareType.goToJail => 'Go To Jail',
      SquareType.luxuryTax => 'Luxury Tax',
    };
  }
}

enum PropertyType {
  red,
  orange,
  yellow,
  green,
  lightBlue,
  darkBlue,
  purple,
  pink,
  railroad,
  utility,
}

class BoardProperty {
  final int id;
  final String name;
  final PropertyType type;

  BoardProperty(this.id, this.name, this.type);

  factory BoardProperty.parse(int id, String propertyStr) {
    List<String> parts = propertyStr.split('/');
    PropertyType type;
    switch (parts[1]) {
       case 'Red': type = .red;
       case 'Orange': type = .orange;
       case 'Yellow': type = .yellow;
       case 'Green': type = .green;
       case 'Light Blue': type = .lightBlue;
       case 'Dark Blue': type = .darkBlue;
       case 'Purple': type = .purple;
       case 'Pink': type = .pink;
       case 'Railroad': type = .railroad;
       case 'Utility': type = .utility;
       default:
       throw FormatException('invalid property type ${propertyStr[1]}');
    }
    return BoardProperty(id, parts[0], type);
  }
}

class Board {
  final List<Square> squares;
  final List<BoardProperty> properties;

  String getName(int squareID) {
    Square square = squares[squareID];
    if (square.type == .property) {
      return properties[square.propertyID].name;
    } else {
      return '$square';
    }
  }

  Board(this.squares, this.properties);
}

Future<Board> getBoard(int boardID) async {
  String rawBoard = await rootBundle.loadString('$boardID.brd');
  List<String> parts = rawBoard.split('\n\n');
  int squareCounter = 0;
  int propertyCounter = 0;
  return Board(
    parts[0].split('\n').map((e) => Square.parse(squareCounter++, e)).toList(),
    parts[1].split('\n').map((e) => BoardProperty.parse(propertyCounter++, e)).toList(),
  );
}
