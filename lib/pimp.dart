import 'dart:async';
import 'dart:convert';
import 'network_stub.dart'
    if (dart.library.io) 'network_io.dart'
    if (dart.library.js_interop) 'network_web.dart';
import 'dart:typed_data';

import 'package:tree_pimp/packetbuffer.dart';

abstract class PIMPMessageValue {
  Iterable<int> serialize();
}

class IntegerPIMPMessageValue extends PIMPMessageValue {
  final int value;
  final int length;

  @override
  Iterable<int> serialize() {
    ByteData data = ByteData(8);
    data.setUint64(0, value, Endian.big);
    return data.buffer.asUint8List().skip(8 - length);
  }

  IntegerPIMPMessageValue(this.value, this.length);
}

class BooleanPIMPMessageValue extends PIMPMessageValue {
  final bool value;

  BooleanPIMPMessageValue(this.value);

  @override
  Iterable<int> serialize() {
    return [value ? 1 : 0];
  }
}

class StringPIMPMessageValue extends PIMPMessageValue {
  final String value;

  StringPIMPMessageValue(this.value);

  @override
  Iterable<int> serialize() {
    Uint8List utf8String = utf8.encode(value);
    return [utf8String.length, ...utf8String];
  }
}

// uint8
typedef PIMPMessageType = int;

sealed class PIMPMessage {
  PIMPMessageType get type;
  Iterable<PIMPMessageValue> get values;
  // if false, this is a response to another message
  bool get isNotification;

  String formalToString() =>
      'message type 0x${type.toRadixString(16).padLeft(2, '0')}';

  static const Set<int> unimplementedMessageTypes = {
    0xfd,
    0xfc,
    0x0f,
    0xf1,
    0xf3,
    0xd0,
    0xd2,
    0xec,
    0xee,
    0x39,
    0x91,
    0x92,
    0x94,
    0x95,
    0x98,
    0x9a,
    0x9b, // not used by server
    0x41, // not used by server
    0xe5,
    0xe6,
    0xe9,
    0xeb,
  };

  PIMPMessage();

  factory PIMPMessage.parse(
    PIMPMessageType messageType,
    int messageLength,
    PacketBuffer buffer,
  ) {
    if (unimplementedMessageTypes.contains(messageType)) {
      throw UnimplementedError(
        'message type ${messageType.toRadixString(16).padLeft(2, '0')}',
      );
    }
    switch (messageType) {
      case 0xfe:
        return PIMPErrorUnexpectedMessageMessage(buffer.readUint8());
      case 0x01:
        return PIMPHandshakeAcknowledgeMessage(buffer.readUint32());
      case 0xf0:
        return PIMPErrorUnknownProtocolMessage();
      case 0xf2:
        return PIMPErrorNameInUseMessage();
      case 0x10:
        return PIMPJoinPendingMessage();
      case 0x0b:
        return PIMPWelcomeBackMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readString(),
          buffer.readBoolean(),
        );
      case 0x12:
        return PIMPStateBoardMessage(buffer.readUint8());
      case 0x13:
        return PIMPStatePlayerMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readString(),
          buffer.readUint8(),
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0x14:
        return PIMPStateObserverMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readString(),
        );
      case 0x15:
        return PIMPStatePropertyMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readBoolean(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x16:
        return PIMPStateCardMessage(buffer.readUint8(), buffer.readUint8());
      case 0x1f:
        return PIMPStatePotMessage(buffer.readUint32());
      case 0xc4:
        return PIMPDeltaBankMessage(buffer.readUint8(), buffer.readUint8());
      case 0x0c:
        return PIMPPlayerTakeoverMessage(
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x20:
        return PIMPStartOfTurnMessage(buffer.readUint8(), buffer.readBoolean());
      case 0x22:
        return PIMPDiceRolledMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x24:
        return PIMPDiceMovedPlayerMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x2f:
        return PIMPRollAgainMessage(buffer.readUint8());
      case 0x27:
        return PIMPPassingBySquareMessage(
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x28:
        return PIMPLandingOnSquareMessage(
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x30:
        return PIMPPropertySaleMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x81:
        return PIMPSquareTakesCashMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x2e:
        return PIMPRentCollectionMoratoriumMessage();
      case 0xc0:
        return PIMPDeltaCashMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0xc1:
        return PIMPDeltaPropertyMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x86:
        return PIMPPlayerClaimedRentMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x52:
        return PIMPTransactionRentRequestedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x61:
        return PIMPTransactionCashSetMessage(
          buffer.readUint32(),
          buffer.readUint32(),
        );
      case 0x71:
        return PIMPTransactionFinishedMessage(buffer.readUint32());
      case 0x62:
        return PIMPTransactionOtherCashSetMessage(
          buffer.readUint32(),
          buffer.readUint32(),
        );
      case 0x72:
        return PIMPTransactionOtherFinishedMessage(buffer.readUint32());
      case 0x77:
        return PIMPTransactionAgreedMessage(buffer.readUint32());
      case 0x78:
        return PIMPTransactionOtherAgreedMessage(buffer.readUint32());
      case 0x79:
        return PIMPTransactionFinalizedMessage(buffer.readUint32());
      case 0x40:
        return PIMPGotCardMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x25:
        return PIMPCardMovedPlayerMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x80:
        return PIMPSquareGivesCashMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x4a:
        return PIMPJailPayOrRollMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readBoolean(),
        );
      case 0x4d:
        return PIMPJailFreeMessage(buffer.readUint8());
      case 0x33:
        return PIMPPropertyAuctionMessage(buffer.readUint8());
      case 0x35:
        return PIMPPropertyAuctionBidMessage(
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x37:
        return PIMPPropertyAuctionNoBidMessage(buffer.readUint8());
      case 0x38:
        return PIMPPropertyAuctionWonMessage(buffer.readUint8());
      case 0x87:
        return PIMPPlayerClaimedGoMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0xe4:
        return PIMPTransactionTooExpensiveMessage(
          buffer.readUint32(),
          buffer.readUint32(),
        );
      case 0x7d:
        return PIMPTransactionUnusualMessage(buffer.readUint32());
      case 0xc5:
        return PIMPDeltaPropertyMortgagedMessage(buffer.readUint8());
      case 0xc6:
        return PIMPDeltaPropertyUnmortgagedMessage(buffer.readUint8());
      case 0xe3:
        return PIMPMortgageTooExpensiveMessage(
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x65:
        return PIMPTransactionPropertyAddedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0x66:
        return PIMPTransactionPropertyRemovedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0x55:
        return PIMPTransactionBankRequestedMessage(
          buffer.readUint32(),
          buffer.readUint32(),
        );
      case 0x67:
        return PIMPTransactionOtherPropertyAddedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0x2a:
        return PIMPWaitingForTransactionMessage(
          buffer.readUint8(),
          buffer.readUint32(),
        );

      case 0x51:
        return PIMPTransactionTradeRequestedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0x82:
        return PIMPSquareGivesCardMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x54:
        return PIMPTransactionSquareRequestedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0xc2:
        return PIMPDeltaPropertyMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x6b:
        return PIMPTransactionCardAddedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0xe1:
        return PIMPInvalidGoClaimMessage();
      case 0x26:
        return PIMPSquareMovedPlayerMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x56:
        return PIMPTransactionJailRequestedMessage(
          buffer.readUint32(),
          buffer.readUint32(),
        );
      case 0xed:
        return PIMPMoneyBeingHeldInEscrowMessage(
          buffer.readUint8(),
          buffer.readUint32(),
          buffer.readUint32(),
        );
      case 0xe0:
        return PIMPInvalidRentClaimMessage();
      case 0x29:
        return PIMPGoingToJailMessage(buffer.readUint8(), buffer.readUint8());
      case 0xc3:
        return PIMPDeltaHousesPurchasedMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x84:
        return PIMPConstructionTakesCashMessage(
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x45:
        return PIMPTaxSelectOptionMessage(
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x53:
        return PIMPTransactionCardRequestedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x83:
        return PIMPSquareTakesCardMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x06:
        return PIMPQueryJoinPlayMessage(
          buffer.readUint32(),
          buffer.readString(),
        );
      case 0x74:
        return PIMPTransactionReopenedMessage(buffer.readUint32());
      case 0x7f:
        return PIMPTransactionCancelledMessage(buffer.readUint32());
      case 0x75:
        return PIMPTransactionOtherReopenedMessage(buffer.readUint32());
      case 0xdb:
        return PIMPPlayerBecameObserverBankruptMessage(buffer.readUint8());
      case 0xdf:
        return PIMPPlayerWonMessage(buffer.readUint8());
      case 0xf4:
        return PIMPWrongPasswordMessage();
      case 0x03:
        return PIMPWelcomeDetailsMessage(
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x04:
        return PIMPWelcomePlayerMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readString(),
        );
      case 0xcf:
        return PIMPDeltaPotMessage(buffer.readUint32());
      case 0x23:
        return PIMPThreeDoublesMessage(buffer.readUint8());
      case 0x85:
        return PIMPDestructionGivesCashMessage(
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0xda:
        return PIMPPlayerBecameObserverTransferMessage(buffer.readUint8());
      case 0x0e:
        return PIMPObserverBecamePlayerMessage(buffer.readUint8());
      case 0x68:
        return PIMPTransactionOtherPropertyRemovedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0x07:
        return PIMPQueryJoinObserveMessage(
          buffer.readUint32(),
          buffer.readString(),
        );
      case 0x05:
        return PIMPWelcomeObserverMessage(
          buffer.readUint8(),
          buffer.readUint8(),
          buffer.readString(),
        );
      case 0xdc:
        return PIMPPlayerBecameObserverKickedMessage(buffer.readUint8());
      case 0xe2:
        return PIMPErrorPropertyTooExpensiveMessage(
          buffer.readUint8(),
          buffer.readUint32(),
        );
      case 0x93:
        return PIMPErrorHousesMortgagedMessage(buffer.readUint8());
      case 0x96:
        return PIMPErrorHousesTooExpensiveMessage(buffer.readUint32());
      case 0x97:
        return PIMPErrorHousesNoHousePiecesLeftMessage(
          buffer.readUint8(),
          buffer.readUint8(),
        );
      case 0x99:
        return PIMPErrorHousesUnbalancedMessage(buffer.readUint8());
      case 0x6c:
        return PIMPTransactionCardRemovedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0x6d:
        return PIMPTransactionOtherCardAddedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0x6e:
        return PIMPTransactionOtherCardRemovedMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      case 0xe7:
        return PIMPTransactionTooExpensiveMessage(
          buffer.readUint32(),
          buffer.readUint32(),
        );
      case 0xe8:
        return PIMPErrorTransactionPropertyHasHouseMessage(
          buffer.readUint32(),
          buffer.readUint8(),
        );
      default:
        return UndocumentedPIMPMessage(
          messageType,
          buffer
              .readUint8List(messageLength)
              .map<PIMPMessageValue>((e) => IntegerPIMPMessageValue(e, 1))
              .toList(),
        );
    }
  }
}

class UndocumentedPIMPMessage extends PIMPMessage {
  @override
  final PIMPMessageType type;

  @override
  final List<PIMPMessageValue> values;

  UndocumentedPIMPMessage(this.type, this.values);
  @override
  bool get isNotification => false;
}

class PIMPErrorUnexpectedMessageMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xfe;

  final PIMPMessageType message;

  @override
  String toString() =>
      'E<unexpected message ${message.toRadixString(16).padLeft(2, '0')}>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(message, 1)];

  PIMPErrorUnexpectedMessageMessage(this.message);
  @override
  bool get isNotification => false;
}

class PIMPRequestStateMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x11;

  @override
  List<PIMPMessageValue> get values => [];

  PIMPRequestStateMessage();
  @override
  bool get isNotification => true;
}

class PIMPAFKMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xd5;

  @override
  List<PIMPMessageValue> get values => [];

  PIMPAFKMessage();
  @override
  bool get isNotification => true;
}

class PIMPSwitchPlayMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x0d;

  @override
  List<PIMPMessageValue> get values => [];

  PIMPSwitchPlayMessage();
  @override
  bool get isNotification => true;
}

class PIMPJoinMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x02;

  final int piece;
  final bool wantsToPlay;
  final String name;

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(piece, 1),
    BooleanPIMPMessageValue(wantsToPlay),
    StringPIMPMessageValue(name),
  ];

  PIMPJoinMessage(this.piece, this.wantsToPlay, this.name);
  @override
  bool get isNotification => true;
}

class PIMPWelcomeDetailsMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x03;

  final int player;
  final int password;

  @override
  String toString() => 'welcome<player $player, password $password>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(password, 4),
  ];

  PIMPWelcomeDetailsMessage(this.player, this.password);
  @override
  bool get isNotification => true;
}

class PIMPHandshakeMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x00;

  final int version;

  @override
  String formalToString() => 'PIMP_HANDSHAKE';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(version, 1)];

  PIMPHandshakeMessage(this.version);
  @override
  bool get isNotification => true;
}

class PIMPErrorUnknownProtocolMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xf0;

  @override
  String toString() => 'E<unknown protocol>';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPErrorUnknownProtocolMessage();
  @override
  bool get isNotification => false;
}

class PIMPErrorNameInUseMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xf2;

  @override
  String toString() => 'E<name in use/not valid>';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPErrorNameInUseMessage();
  @override
  bool get isNotification => false;
}

class PIMPJoinPendingMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x10;

  @override
  String toString() => 'join pending';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPJoinPendingMessage();
  @override
  bool get isNotification => false;
}

class PIMPHandshakeAcknowledgeMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x01;

  final int gameID;

  @override
  String toString() => 'acknowledge<game id $gameID>';
  @override
  String formalToString() =>
      'PIMP_HANDSHAKE_ACKNOWLEDGE 0x${gameID.toRadixString(16).padLeft(8, '0')}';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(gameID, 4)];

  PIMPHandshakeAcknowledgeMessage(this.gameID);
  @override
  bool get isNotification => false;
}

class PIMPRejoinMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x0a;

  final int playerID;
  final int password;

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(password, 4),
  ];

  PIMPRejoinMessage(this.playerID, this.password);
  @override
  bool get isNotification => true;
}

class PIMPWelcomeBackMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x0b;

  final int playerID;
  final int piece;
  final String name;
  final bool isPlaying;

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(piece, 1),
    StringPIMPMessageValue(name),
    BooleanPIMPMessageValue(isPlaying),
  ];

  @override
  String toString() =>
      'welcome back<player $playerID, piece $piece, name $name, is playing $isPlaying>';

  PIMPWelcomeBackMessage(this.playerID, this.piece, this.name, this.isPlaying);
  @override
  bool get isNotification => false;
}

class PIMPStateBoardMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x12;

  final int boardID;

  @override
  String toString() => 'board id $boardID';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(boardID, 1)];

  PIMPStateBoardMessage(this.boardID);
  @override
  bool get isNotification => true;
}

class PIMPStatePlayerMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x13;

  final int playerID;
  final int pieceID;
  final String name;
  final int location;
  final int cash;
  final int jailTurn;

  @override
  String toString() =>
      'player<id $playerID, piece $pieceID, name $name, square $location, cash $cash, jail turn #$jailTurn>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(pieceID, 1),
    StringPIMPMessageValue(name),
    IntegerPIMPMessageValue(location, 1),
    IntegerPIMPMessageValue(cash, 4),
    IntegerPIMPMessageValue(jailTurn, 1),
  ];

  PIMPStatePlayerMessage(
    this.playerID,
    this.pieceID,
    this.name,
    this.location,
    this.cash,
    this.jailTurn,
  );
  @override
  bool get isNotification => true;
}

class PIMPStateObserverMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x14;

  final int playerID;
  final int pieceID;
  final String name;

  @override
  String toString() => 'observer<id $playerID, piece $pieceID, name $name>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(pieceID, 1),
    StringPIMPMessageValue(name),
  ];

  PIMPStateObserverMessage(this.playerID, this.pieceID, this.name);
  @override
  bool get isNotification => true;
}

class PIMPStatePropertyMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x15;

  final int propertyID;
  final int ownerID;
  final bool mortgaged;
  final int houses;
  final int hotels;

  @override
  String toString() =>
      'property<id $propertyID, owner $ownerID, mortgaged $mortgaged, houses $houses, hotels $hotels>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(propertyID, 1),
    IntegerPIMPMessageValue(ownerID, 1),
    BooleanPIMPMessageValue(mortgaged),
    IntegerPIMPMessageValue(houses, 1),
    IntegerPIMPMessageValue(hotels, 1),
  ];

  PIMPStatePropertyMessage(
    this.propertyID,
    this.ownerID,
    this.mortgaged,
    this.houses,
    this.hotels,
  );
  @override
  bool get isNotification => true;
}

class PIMPStateCardMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x16;

  final int cardID;
  final int ownerID;

  @override
  String toString() => 'card<id $cardID, owner $ownerID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(cardID, 1),
    IntegerPIMPMessageValue(ownerID, 1),
  ];

  PIMPStateCardMessage(this.cardID, this.ownerID);
  @override
  bool get isNotification => true;
}

class PIMPStatePotMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x1f;

  final int pot;

  @override
  String toString() => 'pot $pot';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(pot, 4)];

  PIMPStatePotMessage(this.pot);
  @override
  bool get isNotification => true;
}

class PIMPDeltaBankMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xc4;

  final int houses;
  final int hotels;

  @override
  String toString() => 'bank<houses $houses, hotels $hotels>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(houses, 1),
    IntegerPIMPMessageValue(hotels, 1),
  ];

  PIMPDeltaBankMessage(this.houses, this.hotels);
  @override
  bool get isNotification => true;
}

class PIMPTransferMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xd4;

  final int playerID;

  @override
  String toString() => 'transfer<$playerID>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(playerID, 1)];

  PIMPTransferMessage(this.playerID);
  @override
  bool get isNotification => true;
}

class PIMPPlayerTakeoverMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x0c;

  final int oldPlayer;
  final int newPlayer;

  @override
  String toString() => 'takeover<$oldPlayer -> $newPlayer>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(oldPlayer, 1),
    IntegerPIMPMessageValue(newPlayer, 1),
  ];

  PIMPPlayerTakeoverMessage(this.oldPlayer, this.newPlayer);
  @override
  bool get isNotification => true;
}

class PIMPDeltaCashMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xc0;

  final int oldPlayer;
  final int newPlayer;
  final int cash;

  @override
  String toString() => 'deltacash<$oldPlayer -> $newPlayer - cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(oldPlayer, 1),
    IntegerPIMPMessageValue(newPlayer, 1),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPDeltaCashMessage(this.oldPlayer, this.newPlayer, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPStartOfTurnMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x20;

  final int player;
  final bool throwDice;

  @override
  String toString() => 'start of turn<player $player, throw dice $throwDice>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    BooleanPIMPMessageValue(throwDice),
  ];

  PIMPStartOfTurnMessage(this.player, this.throwDice);
  @override
  bool get isNotification => true;
}

class PIMPThrowDiceMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x21;

  @override
  String toString() => 'throw dice';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPThrowDiceMessage();
  @override
  bool get isNotification => true;
}

class PIMPDiceRolledMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x22;

  final int playerID;
  final int die1;
  final int die2;

  @override
  String toString() => 'dice rolled<player $playerID: $die1, $die2>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(die1, 1),
    IntegerPIMPMessageValue(die2, 1),
  ];

  PIMPDiceRolledMessage(this.playerID, this.die1, this.die2);
  @override
  bool get isNotification => true;
}

class PIMPDiceMovedPlayerMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x24;

  final int playerID;
  final int location;
  final int diceRoll;

  @override
  String toString() =>
      'dice moved player<player $playerID, location $location, diceRoll $diceRoll>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(location, 1),
    IntegerPIMPMessageValue(diceRoll, 1),
  ];

  PIMPDiceMovedPlayerMessage(this.playerID, this.location, this.diceRoll);
  @override
  bool get isNotification => true;
}

class PIMPRollAgainMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x24;

  final int playerID;

  @override
  String toString() => 'roll again<player $playerID>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(playerID, 1)];

  PIMPRollAgainMessage(this.playerID);
  @override
  bool get isNotification => true;
}

class PIMPPassingBySquareMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x27;

  final int playerID;
  final int square;

  @override
  String toString() => 'passing<player $playerID, square $square>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(square, 1),
  ];

  PIMPPassingBySquareMessage(this.playerID, this.square);
  @override
  bool get isNotification => true;
}

class PIMPLandingOnSquareMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x28;

  final int playerID;
  final int square;

  @override
  String toString() => 'landing<player $playerID, square $square>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(square, 1),
  ];

  PIMPLandingOnSquareMessage(this.playerID, this.square);
  @override
  bool get isNotification => true;
}

class PIMPPropertySaleMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x30;

  final int playerID;
  final int propertyID;
  final int cost;

  @override
  String toString() =>
      'property for sale<player $playerID, property $propertyID, cost $cost>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(propertyID, 1),
    IntegerPIMPMessageValue(cost, 4),
  ];

  PIMPPropertySaleMessage(this.playerID, this.propertyID, this.cost);
  @override
  bool get isNotification => true;
}

class PIMPBuyPropertyMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x31;

  @override
  String toString() => 'buy property';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPBuyPropertyMessage();
  @override
  bool get isNotification => true;
}

class PIMPAuctionPropertyMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x32;

  @override
  String toString() => 'buy property';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPAuctionPropertyMessage();
  @override
  bool get isNotification => true;
}

class PIMPSquareTakesCashMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x81;

  final int playerID;
  final int squareID;
  final int cash;

  @override
  String toString() =>
      'square takes cash<player $playerID, square $squareID, cost $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(squareID, 1),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPSquareTakesCashMessage(this.playerID, this.squareID, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPRentCollectionMoratoriumMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x2e;

  @override
  String toString() => 'rent collection moratorium';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPRentCollectionMoratoriumMessage();
  @override
  bool get isNotification => true;
}

class PIMPDeltaPropertyMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xc1;

  final int oldPlayer;
  final int newPlayer;
  final int property;

  @override
  String toString() => 'deltaproperty<$oldPlayer -> $newPlayer - $property>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(oldPlayer, 1),
    IntegerPIMPMessageValue(newPlayer, 1),
    IntegerPIMPMessageValue(property, 1),
  ];

  PIMPDeltaPropertyMessage(this.oldPlayer, this.newPlayer, this.property);
  @override
  bool get isNotification => true;
}

class PIMPPlayerClaimedRentMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x86;

  final int claimer;
  final int claimee;
  final int propertyID;
  final int cost;

  @override
  String toString() =>
      'player claims rent<claimer $claimer, claimee $claimee, property $propertyID, cost $cost>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(claimer, 1),
    IntegerPIMPMessageValue(claimee, 1),
    IntegerPIMPMessageValue(propertyID, 1),
    IntegerPIMPMessageValue(cost, 4),
  ];

  PIMPPlayerClaimedRentMessage(
    this.claimer,
    this.claimee,
    this.propertyID,
    this.cost,
  );
  @override
  bool get isNotification => true;
}

class PIMPTransactionRentRequestedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x52;

  final int transactionID;
  final int claimee;
  final int propertyID;
  final int claimer;
  final int cost;

  @override
  String toString() =>
      'rent requested<transaction ID $transactionID, claimer $claimer, claimee $claimee, property $propertyID, cost $cost>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(claimee, 1),
    IntegerPIMPMessageValue(propertyID, 1),
    IntegerPIMPMessageValue(claimer, 1),
    IntegerPIMPMessageValue(cost, 4),
  ];

  PIMPTransactionRentRequestedMessage(
    this.transactionID,
    this.claimee,
    this.propertyID,
    this.claimer,
    this.cost,
  );
  @override
  bool get isNotification => true;
}

class PIMPTransactionCashSetMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x61;

  final int transactionID;
  final int cost;

  @override
  String toString() => 'cash set<transaction ID $transactionID, cost $cost>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(cost, 4),
  ];

  PIMPTransactionCashSetMessage(this.transactionID, this.cost);
  @override
  bool get isNotification => true;
}

class PIMPTransactionFinishMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x70;

  final int transactionID;

  @override
  String toString() => 'finish<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionFinishMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionFinishedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x71;

  final int transactionID;

  @override
  String toString() => 'finished<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionFinishedMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionOtherCashSetMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x62;

  final int transactionID;
  final int cash;

  @override
  String toString() =>
      'other cash set<transaction ID $transactionID, cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPTransactionOtherCashSetMessage(this.transactionID, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPTransactionOtherFinishedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x72;

  final int transactionID;

  @override
  String toString() => 'other finished<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionOtherFinishedMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionOtherAgreedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x78;

  final int transactionID;

  @override
  String toString() => 'other agreed<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionOtherAgreedMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionAgreeMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x76;

  final int transactionID;

  @override
  String toString() => 'agree<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionAgreeMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionAgreedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x77;

  final int transactionID;

  @override
  String toString() => 'agreed<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionAgreedMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionFinalizedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x79;

  final int transactionID;

  @override
  String toString() => 'finalized<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionFinalizedMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPGotCardMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x40;

  final int player;
  final int square;
  final int card;

  @override
  String toString() => 'got card<player $player, square $square, card $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(square, 1),
    IntegerPIMPMessageValue(card, 1),
  ];

  PIMPGotCardMessage(this.player, this.square, this.card);
  @override
  bool get isNotification => true;
}

class PIMPCardMovedPlayerMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x25;

  final int player;
  final int card;
  final int square;

  @override
  String toString() =>
      'card moved player<player $player, square $square, card $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(card, 1),
    IntegerPIMPMessageValue(square, 1),
  ];

  PIMPCardMovedPlayerMessage(this.player, this.card, this.square);
  @override
  bool get isNotification => true;
}

class PIMPSquareGivesCashMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x80;

  final int playerID;
  final int squareID;
  final int cash;

  @override
  String toString() =>
      'square gives cash<player $playerID, square $squareID, cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(squareID, 1),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPSquareGivesCashMessage(this.playerID, this.squareID, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPJailPayOrRollMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x4a;

  final int playerID;
  final int rollsLeft;
  final bool canBuyHouses;

  @override
  String toString() =>
      'jail pay or roll<player $playerID, rolls left $rollsLeft, can buy houses $canBuyHouses>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(rollsLeft, 1),
    BooleanPIMPMessageValue(canBuyHouses),
  ];

  PIMPJailPayOrRollMessage(this.playerID, this.rollsLeft, this.canBuyHouses);
  @override
  bool get isNotification => true;
}

class PIMPJailFreeMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x4d;

  final int playerID;

  @override
  String toString() => 'leaving jail<player $playerID>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(playerID, 1)];

  PIMPJailFreeMessage(this.playerID);
  @override
  bool get isNotification => true;
}

class PIMPPropertyAuctionMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x33;

  final int propertyID;

  @override
  String toString() => 'property auction<property $propertyID>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(propertyID, 1)];

  PIMPPropertyAuctionMessage(this.propertyID);
  @override
  bool get isNotification => true;
}

class PIMPPropertyAuctionBidMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x35;

  final int playerID;
  final int cash;

  @override
  String toString() => 'property auction bid<player $playerID, cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPPropertyAuctionBidMessage(this.playerID, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPBidMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x34;

  final int cash;

  @override
  String toString() => 'bid<cash $cash>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(cash, 4)];

  PIMPBidMessage(this.cash);
  @override
  bool get isNotification => true;
}

class PIMPNoBidMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x36;

  @override
  String toString() => 'no bid';

  @override
  List<PIMPMessageValue> get values => [];

  @override
  bool get isNotification => true;
}

class PIMPPropertyAuctionNoBidMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x37;

  final int playerID;

  @override
  String toString() => 'property auction no bid<player $playerID>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(playerID, 1)];

  PIMPPropertyAuctionNoBidMessage(this.playerID);
  @override
  bool get isNotification => true;
}

class PIMPPropertyAuctionWonMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x38;

  final int playerID;

  @override
  String toString() => 'property auction won<player $playerID>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(playerID, 1)];

  PIMPPropertyAuctionWonMessage(this.playerID);
  @override
  bool get isNotification => true;
}

class PIMPPlayerClaimedGoMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x87;

  final int claimer;
  final int square;
  final int cash;

  @override
  String toString() =>
      'player claims go<claimer $claimer, square $square, cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(claimer, 1),
    IntegerPIMPMessageValue(square, 1),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPPlayerClaimedGoMessage(this.claimer, this.square, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPTransactionTooExpensiveMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xe4;

  final int transactionID;
  final int cash;

  @override
  String toString() =>
      'transaction too expensive<transaction $transactionID, cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPTransactionTooExpensiveMessage(this.transactionID, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPTransactionUnusualMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x7d;

  final int transactionID;

  @override
  String toString() => 'transaction unusual<transaction $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionUnusualMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPMortgagePropertyMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x3b;

  final int property;

  @override
  String toString() => 'mortgage property<transaction $property>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(property, 1)];

  PIMPMortgagePropertyMessage(this.property);
  @override
  bool get isNotification => true;
}

class PIMPDeltaPropertyMortgagedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xc5;

  final int property;

  @override
  String toString() => 'property mortgaged<transaction $property>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(property, 1)];

  PIMPDeltaPropertyMortgagedMessage(this.property);
  @override
  bool get isNotification => true;
}

class PIMPTransactionSetCashMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x60;

  final int transactionID;
  final int cost;

  @override
  String toString() => 'set cash<transaction ID $transactionID, cost $cost>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(cost, 4),
  ];

  PIMPTransactionSetCashMessage(this.transactionID, this.cost);
  @override
  bool get isNotification => true;
}

class PIMPTransactionReopenedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x74;

  final int transactionID;

  @override
  String toString() => 'reopened<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionReopenedMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPUnmortgagePropertyMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x3c;

  final int property;

  @override
  String toString() => 'unmortgage property<transaction $property>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(property, 1)];

  PIMPUnmortgagePropertyMessage(this.property);
  @override
  bool get isNotification => true;
}

class PIMPDeltaPropertyUnmortgagedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xc6;

  final int property;

  @override
  String toString() => 'property unmortgaged<transaction $property>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(property, 1)];

  PIMPDeltaPropertyUnmortgagedMessage(this.property);
  @override
  bool get isNotification => true;
}

class PIMPMortgageTooExpensiveMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xe3;

  final int propertyID;
  final int cash;

  @override
  String toString() =>
      'mortgage too expensive<property $propertyID, cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(propertyID, 1),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPMortgageTooExpensiveMessage(this.propertyID, this.cash);
  @override
  bool get isNotification => false;
}

class PIMPTransactionAddPropertyMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x63;

  final int transactionID;
  final int property;

  @override
  String toString() =>
      'add property<transaction $transactionID, property $property>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(property, 1),
  ];

  PIMPTransactionAddPropertyMessage(this.transactionID, this.property);
  @override
  bool get isNotification => true;
}

class PIMPTransactionPropertyAddedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x65;

  final int transactionID;
  final int property;

  @override
  String toString() =>
      'property added<transaction $transactionID, property $property>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(property, 1),
  ];

  PIMPTransactionPropertyAddedMessage(this.transactionID, this.property);
  @override
  bool get isNotification => true;
}

class PIMPTransactionRemovePropertyMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x64;

  final int transactionID;
  final int property;

  @override
  String toString() =>
      'remove property<transaction $transactionID, property $property>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(property, 1),
  ];

  PIMPTransactionRemovePropertyMessage(this.transactionID, this.property);
  @override
  bool get isNotification => true;
}

class PIMPTransactionPropertyRemovedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x66;

  final int transactionID;
  final int property;

  @override
  String toString() =>
      'property removed<transaction $transactionID, property $property>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(property, 1),
  ];

  PIMPTransactionPropertyRemovedMessage(this.transactionID, this.property);
  @override
  bool get isNotification => true;
}

class PIMPTransactionBankRequestedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x55;

  final int transactionID;
  final int cost;

  @override
  String toString() =>
      'bank requested<transaction ID $transactionID, cost $cost>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(cost, 4),
  ];

  PIMPTransactionBankRequestedMessage(this.transactionID, this.cost);
  @override
  bool get isNotification => true;
}

class PIMPTransactionOtherPropertyAddedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x67;

  final int transactionID;
  final int property;

  @override
  String toString() =>
      'other property added<transaction $transactionID, property $property>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(property, 1),
  ];

  PIMPTransactionOtherPropertyAddedMessage(this.transactionID, this.property);
  @override
  bool get isNotification => true;
}

class PIMPWaitingForTransactionMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x2a;

  final int player;
  final int transactionID;

  @override
  String toString() =>
      'waiting for transaction<player $player, transaction $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPWaitingForTransactionMessage(this.player, this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionTradeRequestedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x51;

  final int transactionID;
  final int otherPlayer;

  @override
  String toString() =>
      'trade requested<transaction ID $transactionID, other player $otherPlayer>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(otherPlayer, 1),
  ];

  PIMPTransactionTradeRequestedMessage(this.transactionID, this.otherPlayer);
  @override
  bool get isNotification => true;
}

class PIMPTransactionRequestTradeMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x50;

  final int otherPlayer;

  @override
  String toString() => 'request trade<other player $otherPlayer>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(otherPlayer, 1),
  ];

  PIMPTransactionRequestTradeMessage(this.otherPlayer);
  @override
  bool get isNotification => true;
}

class PIMPClaimGoMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x2c;

  final int square;

  @override
  String toString() => 'claim go<$square>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(square, 1)];

  PIMPClaimGoMessage(this.square);
  @override
  bool get isNotification => true;
}

class PIMPSquareGivesCardMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x82;

  final int playerID;
  final int squareID;
  final int card;

  @override
  String toString() =>
      'square gives card<player $playerID, square $squareID, card $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(squareID, 1),
    IntegerPIMPMessageValue(card, 1),
  ];

  PIMPSquareGivesCardMessage(this.playerID, this.squareID, this.card);
  @override
  bool get isNotification => true;
}

class PIMPTransactionSquareRequestedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x54;

  final int transactionID;
  final int square;
  final int cost;

  @override
  String toString() =>
      'square requested<transaction ID $transactionID, square $square, cost $cost>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(square, 1),
    IntegerPIMPMessageValue(cost, 4),
  ];

  PIMPTransactionSquareRequestedMessage(
    this.transactionID,
    this.square,
    this.cost,
  );
  @override
  bool get isNotification => true;
}

class PIMPTransactionAddCardMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x69;

  final int transactionID;
  final int card;

  @override
  String toString() => 'add card<transaction $transactionID, card $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(card, 1),
  ];

  PIMPTransactionAddCardMessage(this.transactionID, this.card);
  @override
  bool get isNotification => true;
}

class PIMPTransactionCardAddedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x6b;

  final int transactionID;
  final int card;

  @override
  String toString() => 'card added<transaction $transactionID, card $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(card, 1),
  ];

  PIMPTransactionCardAddedMessage(this.transactionID, this.card);
  @override
  bool get isNotification => true;
}

class PIMPDeltaCardMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xc2;

  final int oldPlayer;
  final int newPlayer;
  final int card;

  @override
  String toString() => 'deltacard<$oldPlayer -> $newPlayer - $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(oldPlayer, 1),
    IntegerPIMPMessageValue(newPlayer, 1),
    IntegerPIMPMessageValue(card, 1),
  ];

  PIMPDeltaCardMessage(this.oldPlayer, this.newPlayer, this.card);
  @override
  bool get isNotification => true;
}

class PIMPInvalidGoClaimMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xe1;

  @override
  String toString() => 'invalid go claim';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPInvalidGoClaimMessage();
  @override
  bool get isNotification => false;
}

class PIMPSquareMovedPlayerMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x26;

  final int player;
  final int mover;
  final int square;

  @override
  String toString() =>
      'square moved player<player $player, mover $square, square $square>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(mover, 1),
    IntegerPIMPMessageValue(square, 1),
  ];

  PIMPSquareMovedPlayerMessage(this.player, this.mover, this.square);
  @override
  bool get isNotification => true;
}

class PIMPJailRollDiceMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x4c;

  @override
  String toString() => 'jail roll dice';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPJailRollDiceMessage();
  @override
  bool get isNotification => true;
}

class PIMPClaimRentMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x2b;

  final int player;
  final int property;

  @override
  String toString() => 'claim rent<player $player, property $property>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(property, 1),
  ];

  PIMPClaimRentMessage(this.player, this.property);
  @override
  bool get isNotification => true;
}

class PIMPTransactionJailRequestedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x56;

  final int transactionID;
  final int cost;

  @override
  String toString() =>
      'jail requested<transaction ID $transactionID, cost $cost>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(cost, 4),
  ];

  PIMPTransactionJailRequestedMessage(this.transactionID, this.cost);
  @override
  bool get isNotification => true;
}

class PIMPMoneyBeingHeldInEscrowMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xed;

  final int player;
  final int transactionID;
  final int cash;

  @override
  String toString() =>
      'money being held in escrow<transaction ID $transactionID, player $player, cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPMoneyBeingHeldInEscrowMessage(this.player, this.transactionID, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPInvalidRentClaimMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xe0;

  @override
  String toString() => 'invalid rent claim';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPInvalidRentClaimMessage();
  @override
  bool get isNotification => false;
}

class PIMPGoingToJailMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x29;

  final int player;
  final int square;

  @override
  String toString() => 'going to jail<player $player, square $square>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(square, 1),
  ];

  PIMPGoingToJailMessage(this.player, this.square);
  @override
  bool get isNotification => true;
}

class PIMPDeltaHousesPurchasedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xc3;

  final int player;
  final int property;
  final int houses;
  final int hotels;

  @override
  String toString() =>
      'delta houses purchased<player $player, property $property, houses $houses, hotels $hotels>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(property, 1),
    IntegerPIMPMessageValue(houses, 1),
    IntegerPIMPMessageValue(hotels, 1),
  ];

  PIMPDeltaHousesPurchasedMessage(
    this.player,
    this.property,
    this.houses,
    this.hotels,
  );
  @override
  bool get isNotification => true;
}

class PIMPConstructionTakesCashMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x84;

  final int playerID;
  final int cash;

  @override
  String toString() => 'construction takes cash<player $playerID, cost $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPConstructionTakesCashMessage(this.playerID, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPTaxSelectOptionMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x45;

  final int playerID;
  final int square;

  @override
  String toString() => 'tax select option<player $playerID, square $square>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(square, 4),
  ];

  PIMPTaxSelectOptionMessage(this.playerID, this.square);
  @override
  bool get isNotification => true;
}

class PIMPTransactionCardRequestedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x53;

  final int transactionID;
  final int player;
  final int card;
  final int cost;
  final int recipient;

  @override
  String toString() =>
      'card requested<transaction ID $transactionID, player $player, card $card, cost $cost, recipient $recipient>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(player, 1),
    IntegerPIMPMessageValue(card, 1),
    IntegerPIMPMessageValue(recipient, 1),
    IntegerPIMPMessageValue(cost, 4),
  ];

  PIMPTransactionCardRequestedMessage(
    this.transactionID,
    this.player,
    this.card,
    this.recipient,
    this.cost,
  );
  @override
  bool get isNotification => true;
}

class PIMPSquareTakesCardMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x83;

  final int playerID;
  final int squareID;
  final int card;

  @override
  String toString() =>
      'square takes card<player $playerID, square $squareID, card $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(squareID, 1),
    IntegerPIMPMessageValue(card, 1),
  ];

  PIMPSquareTakesCardMessage(this.playerID, this.squareID, this.card);
  @override
  bool get isNotification => true;
}

class PIMPTransactionCancelMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x7e;

  final int transactionID;

  @override
  String toString() => 'cancel<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionCancelMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionCancelledMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x7f;

  final int transactionID;

  @override
  String toString() => 'cancelled<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionCancelledMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionOtherReopenedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x75;

  final int transactionID;

  @override
  String toString() => 'other reopened<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionOtherReopenedMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPTransactionReopenMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x73;

  final int transactionID;

  @override
  String toString() => 'reopen<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPTransactionReopenMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPBankruptTransactionMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x7a;

  final int transactionID;

  @override
  String toString() => 'bankrupt<transaction ID $transactionID>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
  ];

  PIMPBankruptTransactionMessage(this.transactionID);
  @override
  bool get isNotification => true;
}

class PIMPPlayerBecameObserverBankruptMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xdb;

  final int player;

  @override
  String toString() => 'player became observer (bankrupt)<player $player>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(player, 1)];

  PIMPPlayerBecameObserverBankruptMessage(this.player);
  @override
  bool get isNotification => true;
}

class PIMPPlayerWonMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xdf;

  final int player;

  @override
  String toString() => 'player won<player $player>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(player, 1)];

  PIMPPlayerWonMessage(this.player);
  @override
  bool get isNotification => true;
}

class PIMPWrongPasswordMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xf4;

  @override
  String toString() => 'wrong password';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPWrongPasswordMessage();
  @override
  bool get isNotification => false;
}

class PIMPQueryJoinPlayMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x06;

  final int candidateID;
  final String name;

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(candidateID, 4),
    StringPIMPMessageValue(name),
  ];

  PIMPQueryJoinPlayMessage(this.candidateID, this.name);
  @override
  bool get isNotification => true;
}

class PIMPAcceptJoinMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x08;

  final int candidateID;

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(candidateID, 4),
  ];

  PIMPAcceptJoinMessage(this.candidateID);
  @override
  bool get isNotification => false;
}

class PIMPRefuseJoinMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x09;

  final int candidateID;

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(candidateID, 4),
  ];

  PIMPRefuseJoinMessage(this.candidateID);
  @override
  bool get isNotification => false;
}

class PIMPWelcomePlayerMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x04;

  final int playerID;
  final int pieceID;
  final String name;

  @override
  String toString() =>
      'welcome player<id $playerID, piece $pieceID, name $name>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(pieceID, 1),
    StringPIMPMessageValue(name),
  ];

  PIMPWelcomePlayerMessage(this.playerID, this.pieceID, this.name);
  @override
  bool get isNotification => true;
}

class PIMPDeltaPotMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xcf;

  final int pot;

  @override
  String toString() => 'delta pot $pot';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(pot, 4)];

  PIMPDeltaPotMessage(this.pot);
  @override
  bool get isNotification => true;
}

class PIMPTaxPayFlatFeeMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x47;

  @override
  String toString() => 'pay \$200';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPTaxPayFlatFeeMessage();
  @override
  bool get isNotification => false;
}

class PIMPTaxPayTenPercentMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x46;

  @override
  String toString() => 'pay 10%';

  @override
  List<PIMPMessageValue> get values => [];

  PIMPTaxPayTenPercentMessage();
  @override
  bool get isNotification => false;
}

class PIMPPurchaseHousesMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x90;
  final Iterable<({int property, int houses, int hotels})> properties;

  @override
  String toString() => 'purchase houses';

  @override
  Iterable<PIMPMessageValue> get values =>
      [IntegerPIMPMessageValue(properties.length, 1)].followedBy(
        properties.expand(
          (e) => [
            IntegerPIMPMessageValue(e.property, 1),
            IntegerPIMPMessageValue(e.houses, 1),
            IntegerPIMPMessageValue(e.hotels, 1),
          ],
        ),
      );

  PIMPPurchaseHousesMessage(this.properties);
  @override
  bool get isNotification => true;
}

class PIMPThreeDoublesMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x23;
  final int player;

  @override
  String toString() => 'three doubles<player $player>';

  @override
  Iterable<PIMPMessageValue> get values => [IntegerPIMPMessageValue(player, 1)];

  PIMPThreeDoublesMessage(this.player);
  @override
  bool get isNotification => true;
}

class PIMPDestructionGivesCashMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x85;

  final int playerID;
  final int cash;

  @override
  String toString() => 'destruction gives cash<player $playerID, cost $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPDestructionGivesCashMessage(this.playerID, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPPlayerBecameObserverTransferMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xda;

  final int player;

  @override
  String toString() => 'player became observer (transfer)<player $player>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(player, 1)];

  PIMPPlayerBecameObserverTransferMessage(this.player);
  @override
  bool get isNotification => true;
}

class PIMPObserverBecamePlayerMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x0e;

  final int player;

  @override
  String toString() => 'observer became player<player $player>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(player, 1)];

  PIMPObserverBecamePlayerMessage(this.player);
  @override
  bool get isNotification => true;
}

class PIMPTransactionOtherPropertyRemovedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x68;

  final int transactionID;
  final int property;

  @override
  String toString() =>
      'other property removed<transaction $transactionID, property $property>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(property, 1),
  ];

  PIMPTransactionOtherPropertyRemovedMessage(this.transactionID, this.property);
  @override
  bool get isNotification => true;
}

class PIMPQueryJoinObserveMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x07;

  final int candidateID;
  final String name;

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(candidateID, 4),
    StringPIMPMessageValue(name),
  ];

  PIMPQueryJoinObserveMessage(this.candidateID, this.name);
  @override
  bool get isNotification => true;
}

class PIMPWelcomeObserverMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x05;

  final int playerID;
  final int pieceID;
  final String name;

  @override
  String toString() =>
      'welcome observer<id $playerID, piece $pieceID, name $name>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(playerID, 1),
    IntegerPIMPMessageValue(pieceID, 1),
    StringPIMPMessageValue(name),
  ];

  PIMPWelcomeObserverMessage(this.playerID, this.pieceID, this.name);
  @override
  bool get isNotification => true;
}

class PIMPPlayerBecameObserverKickedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xdc;

  final int player;

  @override
  String toString() => 'player became observer (kicked)<player $player>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(player, 1)];

  PIMPPlayerBecameObserverKickedMessage(this.player);
  @override
  bool get isNotification => true;
}

class PIMPErrorPropertyTooExpensiveMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xe2;

  final int property;
  final int cash;

  @override
  String toString() =>
      'error property too expensive<property $property, cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(property, 1),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPErrorPropertyTooExpensiveMessage(this.property, this.cash);
  @override
  bool get isNotification => false;
}

class PIMPErrorHousesMortgagedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x93;

  final int property;

  @override
  String toString() => 'error houses mortgaged<property $property>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(property, 1)];

  PIMPErrorHousesMortgagedMessage(this.property);
  @override
  bool get isNotification => false;
}

class PIMPErrorHousesTooExpensiveMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x96;

  final int cash;

  @override
  String toString() => 'error houses too expensive<cash $cash>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(cash, 4)];

  PIMPErrorHousesTooExpensiveMessage(this.cash);
  @override
  bool get isNotification => false;
}

class PIMPErrorHousesNoHousePiecesLeftMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x97;

  final int houses;
  final int hotels;

  @override
  String toString() =>
      'error houses no house pieces left<houses $houses, hotels $hotels>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(houses, 1),
    IntegerPIMPMessageValue(hotels, 1),
  ];

  PIMPErrorHousesNoHousePiecesLeftMessage(this.houses, this.hotels);
  @override
  bool get isNotification => false;
}

class PIMPErrorHousesUnbalancedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x99;

  final int property;

  @override
  String toString() => 'error houses unbalanced<property $property>';

  @override
  List<PIMPMessageValue> get values => [IntegerPIMPMessageValue(property, 1)];

  PIMPErrorHousesUnbalancedMessage(this.property);
  @override
  bool get isNotification => false;
}

class PIMPTransactionCardRemovedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x6c;

  final int transactionID;
  final int card;

  @override
  String toString() => 'card removed<transaction $transactionID, card $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(card, 1),
  ];

  PIMPTransactionCardRemovedMessage(this.transactionID, this.card);
  @override
  bool get isNotification => true;
}

class PIMPTransactionOtherCardRemovedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x6e;

  final int transactionID;
  final int card;

  @override
  String toString() =>
      'other card removed<transaction $transactionID, card $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(card, 1),
  ];

  PIMPTransactionOtherCardRemovedMessage(this.transactionID, this.card);
  @override
  bool get isNotification => true;
}

class PIMPTransactionOtherCardAddedMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0x6d;

  final int transactionID;
  final int card;

  @override
  String toString() =>
      'other card added<transaction $transactionID, card $card>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(card, 1),
  ];

  PIMPTransactionOtherCardAddedMessage(this.transactionID, this.card);
  @override
  bool get isNotification => true;
}

class PIMPTransactionNotSuitableMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xe7;

  final int transactionID;
  final int cash;

  @override
  String toString() =>
      'transaction not suitable<transaction $transactionID, cash $cash>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(cash, 4),
  ];

  PIMPTransactionNotSuitableMessage(this.transactionID, this.cash);
  @override
  bool get isNotification => true;
}

class PIMPErrorTransactionPropertyHasHouseMessage extends PIMPMessage {
  @override
  PIMPMessageType get type => 0xe8;

  final int transactionID;
  final int property;

  @override
  String toString() =>
      'error property has house<transaction $transactionID, property $property>';

  @override
  List<PIMPMessageValue> get values => [
    IntegerPIMPMessageValue(transactionID, 4),
    IntegerPIMPMessageValue(property, 1),
  ];

  PIMPErrorTransactionPropertyHasHouseMessage(
    this.transactionID,
    this.property,
  );
  @override
  bool get isNotification => true;
}

const bool verbose = false;

class PIMPClient {
  final Socket socket;
  final PacketBuffer buffer = PacketBuffer();
  int? gameID;

  Completer<PIMPMessage>? responseMessage;
  PIMPMessageType? messageType;
  int? messageLength;
  PIMPClient._(this.socket) {
    socket.listen((x) async {
      buffer.add(x);
      while (messageLength == null && buffer.available >= 2 ||
          messageLength != null && buffer.available >= messageLength!) {
        if (messageLength == null && buffer.available >= 2) {
          messageType = buffer.readUint8();
          messageLength = buffer.readUint8();
        }
        if (messageLength != null && buffer.available >= messageLength!) {
          PIMPMessage message = PIMPMessage.parse(
            messageType!,
            messageLength!,
            buffer,
          );
          messageType = null;
          messageLength = null;
          if (verbose) print('S -> C: ${message.formalToString()}');
          if (message.isNotification) {
            _notifyListeners(message);
          } else {
            if (responseMessage == null) {
              print(
                'unexpected response (type 0x${message.type.toRadixString(16).padLeft(2, '0')})',
              );
              print(
                'response: ${await sendMessage(PIMPErrorUnexpectedMessageMessage(message.type), [0xfe])}',
              );
              sendMessage(PIMPErrorUnexpectedMessageMessage(message.type), [
                0xfe,
              ]);
            } else {
              responseMessage!.complete(message);
            }
          }
        }
      }
    });
  }

  bool expectingResponse = false;

  Future<PIMPMessage> sendMessage(
    PIMPMessage message,
    List<PIMPMessageType> possibleResponses, [
    bool canHaveNoResponse = false,
  ]) async {
    if (verbose) print('C -> S: ${message.formalToString()}');
    List<int> values = [
      for (PIMPMessageValue value in message.values) ...value.serialize(),
    ];
    socket.add([message.type, values.length, ...values]);
    if (responseMessage != null && expectingResponse) {
      throw StateError('two concurrent messages being expected');
    }
    expectingResponse = !canHaveNoResponse;
    responseMessage = Completer();
    PIMPMessage response = await responseMessage!.future;
    responseMessage = null;
    if (!possibleResponses.contains(response.type)) {
      print(
        'unexpected response (type ${response.type.toRadixString(16).padLeft(2, '0')})',
      );
      print(
        'response: ${await sendMessage(PIMPErrorUnexpectedMessageMessage(response.type), [0xfe])}',
      );
    }
    return response;
  }

  static Future<PIMPClient> connect(String url) async {
    Socket socket = await Socket.connect(url);
    PIMPClient client = PIMPClient._(socket);
    PIMPMessage response = await client.sendMessage(PIMPHandshakeMessage(1), [
      0xfc,
      0xf0,
      0x01,
    ]);
    if (response.type != 0x01) {
      throw UnimplementedError('unsuccessful handshake: $response');
    }
    client.gameID = (response as PIMPHandshakeAcknowledgeMessage).gameID;
    return client;
  }

  List<void Function(PIMPMessage)> listeners = [];

  void addListener(void Function(PIMPMessage) listener) {
    listeners.add(listener);
  }

  void removeListener(void Function(PIMPMessage) listener) {
    listeners.remove(listener);
  }

  void _notifyListeners(PIMPMessage notification) {
    for (void Function(PIMPMessage) listener in listeners) {
      listener(notification);
    }
  }
}
