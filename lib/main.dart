import 'dart:io';

import 'package:flutter/material.dart' hide Card;
import 'package:path_provider/path_provider.dart';

import 'pimp.dart';
import 'brd.dart';

void main() {
  runApp(MonopolyApp());
}

class MonopolyApp extends StatefulWidget {
  const MonopolyApp({super.key});

  @override
  State<MonopolyApp> createState() => _MonopolyAppState();
}

enum GameState {
  rollDice,
  rollDiceJail,
  buyProperty,
  propertyAuction,
  transaction,
  taxSelectOption,
  won,
}

const Map<PropertyType, Color> propertyColors = {
  .red: Colors.red,
  .orange: Colors.orange,
  .yellow: Colors.yellow,
  .green: Colors.green,
  .lightBlue: Colors.lightBlue,
  .darkBlue: Colors.blueAccent,
  .purple: Colors.purple,
  .pink: Colors.pink,
  .railroad: Colors.blueGrey,
  .utility: Colors.brown,
};

class _MonopolyAppState extends State<MonopolyApp> {
  PIMPClient? client;
  Board? board;
  Map<int, Transaction> transactions = {};
  Map<int, Observer> observers = {};
  Map<int, Player> players = {};
  Map<int, Property> ownedProperties = {};
  Map<int, Card> cards = {};
  int? turn;
  GameState? state;
  int? jailRolls;
  int? player;
  bool? loggedIn;
  bool joinPending = false;
  String? candidateName;
  int? candidateID;
  int? propertyForSale;
  int? propertyCost;
  int? lastBidder;
  int? lastBid;
  int? blockingTransaction;
  int? pot;
  bool? candidateWantsToPlay;

  @override
  void initState() {
    super.initState();
    PIMPClient.connect('hixie.ch:13220').then((PIMPClient client) async {
      setState(() {
        this.client = client;
      });
      client.addListener((message) {
        setState(() {
          switch (message) {
            case PIMPWelcomeDetailsMessage(
              player: int player,
              password: int password,
            ):
              () async {
                File storageFile = File(
                  '${(await getApplicationDocumentsDirectory()).path}user.txt',
                );
                storageFile.writeAsStringSync('$player\n$password');
              }();
            case PIMPQueryJoinObserveMessage(
              candidateID: int candidateID,
              name: String name,
            ):
              candidateWantsToPlay = false;
              this.candidateID = candidateID;
              candidateName = name;

            case PIMPQueryJoinPlayMessage(
              candidateID: int candidateID,
              name: String name,
            ):
              candidateWantsToPlay = true;
              this.candidateID = candidateID;
              candidateName = name;
            case PIMPStateBoardMessage(boardID: int boardID):
              getBoard(boardID).then((Board parsedBoard) {
                setState(() {
                  board = parsedBoard;
                });
              });
            case PIMPStatePotMessage(pot: int pot):
              this.pot = pot;
            case PIMPStartOfTurnMessage(
              player: int player,
              throwDice: bool throwDice,
            ):
              turn = player;
              if (throwDice) {
                state = .rollDice;
              } else {
                state = null;
              }
            case PIMPPropertySaleMessage(
              playerID: int playerID,
              propertyID: int propertyID,
              cost: int cost,
            ):
              turn = playerID;
              propertyForSale = propertyID;
              propertyCost = cost;
              state = .buyProperty;
            case PIMPPropertyAuctionMessage(propertyID: int propertyID):
              propertyForSale = propertyID;
              lastBid = null;
              lastBidder = null;
              state = .propertyAuction;
            case PIMPPropertyAuctionBidMessage(
              playerID: int playerID,
              cash: int cash,
            ):
              lastBidder = playerID;
              lastBid = cash;
            case PIMPWaitingForTransactionMessage(
              player: int player,
              transactionID: int transactionID,
            ):
              turn = player;
              state = .transaction;
              blockingTransaction = transactionID;
            case PIMPTransactionTradeRequestedMessage(
              transactionID: int transactionID,
              otherPlayer: int otherPlayer,
            ):
              transactions[transactionID] = Transaction(
                transactionID,
                TransactionReasonTrade(),
                otherPlayer,
                true,
              );
            case PIMPTransactionRentRequestedMessage(
              transactionID: int transactionID,
              cost: int cost,
              propertyID: int propertyID,
              claimer: int claimer,
              claimee: int claimee,
            ):
              transactions[transactionID] = Transaction(
                transactionID,
                TransactionReasonRent(cost, propertyID),
                claimer == player ? claimee : claimer,
                claimer == player,
              );
            case PIMPTransactionCardRequestedMessage(
              transactionID: int transactionID,
              player: int player,
              card: int card,
              cost: int cost,
              recipient: int recipient,
            ):
              transactions[transactionID] = Transaction(
                transactionID,
                TransactionReasonCard(cost, card),
                player == this.player ? recipient : player,
                recipient == this.player,
              );
            case PIMPTransactionSquareRequestedMessage(
              transactionID: int transactionID,
              square: int square,
              cost: int cost,
            ):
              transactions[transactionID] = Transaction(
                transactionID,
                TransactionReasonSquare(cost, square),
                0,
                false,
              );
            case PIMPTransactionBankRequestedMessage(
              transactionID: int transactionID,
              cost: int cost,
            ):
              transactions[transactionID] = Transaction(
                transactionID,
                TransactionReasonBank(cost),
                0,
                false,
              );
            case PIMPTransactionJailRequestedMessage(
              transactionID: int transactionID,
              cost: int cost,
            ):
              transactions[transactionID] = Transaction(
                transactionID,
                TransactionReasonJail(cost),
                0,
                false,
              );
            case PIMPTransactionCashSetMessage(
              transactionID: int transactionID,
              cost: int cost,
            ):
              transactions[transactionID]!.cash = cost;
            case PIMPTransactionOtherCashSetMessage(
              transactionID: int transactionID,
              cash: int cash,
            ):
              transactions[transactionID]!.otherCash = cash;
            case PIMPTransactionPropertyAddedMessage(
              transactionID: int transactionID,
              property: int property,
            ):
              transactions[transactionID]!.properties.add(property);
            case PIMPTransactionOtherPropertyAddedMessage(
              transactionID: int transactionID,
              property: int property,
            ):
              transactions[transactionID]!.otherProperties.add(property);
            case PIMPTransactionPropertyRemovedMessage(
              transactionID: int transactionID,
              property: int property,
            ):
              transactions[transactionID]!.properties.remove(property);
            case PIMPTransactionCardRemovedMessage(
              transactionID: int transactionID,
              card: int card,
            ):
              transactions[transactionID]!.cards.remove(card);
            case PIMPTransactionCardAddedMessage(
              transactionID: int transactionID,
              card: int card,
            ):
              transactions[transactionID]!.cards.add(card);
            case PIMPTransactionOtherCardAddedMessage(
              transactionID: int transactionID,
              card: int card,
            ):
              transactions[transactionID]!.otherCards.add(card);
            case PIMPTransactionOtherCardRemovedMessage(
              transactionID: int transactionID,
              card: int card,
            ):
              transactions[transactionID]!.otherCards.remove(card);
            case PIMPTransactionUnusualMessage(
              transactionID: int transactionID,
            ):
              transactions[transactionID]!.unusual = true;
            case PIMPTransactionFinishedMessage(
              transactionID: int transactionID,
            ):
              transactions[transactionID]!.finished = true;
            case PIMPTransactionOtherFinishedMessage(
              transactionID: int transactionID,
            ):
              transactions[transactionID]!.otherFinished = true;
            case PIMPTransactionAgreedMessage(transactionID: int transactionID):
              transactions[transactionID]!.agreed = true;
            case PIMPTransactionOtherAgreedMessage(
              transactionID: int transactionID,
            ):
              transactions[transactionID]!.otherAgreed = true;
            case PIMPTransactionFinalizedMessage(
              transactionID: int transactionID,
            ):
            case PIMPTransactionCancelledMessage(
              transactionID: int transactionID,
            ):
              transactions.remove(transactionID);

            case PIMPStatePropertyMessage(
              propertyID: int propertyID,
              ownerID: int ownerID,
              mortgaged: bool mortgaged,
              houses: int houses,
              hotels: int hotels,
            ):
              ownedProperties[propertyID] = Property(
                propertyID,
                ownerID,
                mortgaged,
                houses,
                hotels,
              );
            case PIMPDeltaPropertyMessage(
              newPlayer: int newPlayer,
              property: int property,
            ):
              ownedProperties[property] ??= Property(property, 0, false, 0, 0);
              ownedProperties[property]!.owner = newPlayer;
            case PIMPDeltaPropertyMortgagedMessage(property: int property):
              ownedProperties[property]!.mortgaged = true;
            case PIMPDeltaPropertyUnmortgagedMessage(property: int property):
              ownedProperties[property]!.mortgaged = false;
            case PIMPStateObserverMessage(
              playerID: int playerID,
              pieceID: int pieceID,
              name: String name,
            ):
              observers[playerID] = Observer(playerID, pieceID, name);
            case PIMPStatePlayerMessage(
              playerID: int playerID,
              pieceID: int pieceID,
              name: String name,
              location: int location,
              cash: int cash,
            ):
              players[playerID] = Player(
                playerID,
                pieceID,
                name,
                location,
                cash,
              );
            case PIMPWelcomePlayerMessage(
              playerID: int playerID,
              pieceID: int pieceID,
              name: String name,
            ):
              players[playerID] = Player(playerID, pieceID, name, 0, 0);
              candidateID = null;
              candidateName = null;
            case PIMPWelcomeObserverMessage(
              playerID: int playerID,
              pieceID: int pieceID,
              name: String name,
            ):
              observers[playerID] = Observer(playerID, pieceID, name);
              candidateID = null;
              candidateName = null;
            case PIMPStateCardMessage(cardID: int cardID, ownerID: int ownerID):
              cards[cardID] = Card(cardID, ownerID);
            case PIMPDeltaCashMessage(
              oldPlayer: int oldPlayer,
              newPlayer: int newPlayer,
              cash: int cash,
            ):
              if (oldPlayer != 0) players[oldPlayer]?.cash -= cash;
              if (newPlayer != 0) players[newPlayer]?.cash += cash;
            case PIMPDeltaCardMessage(newPlayer: int newPlayer, card: int card):
              cards[card] ??= Card(card, 0);
              cards[card]!.owner = newPlayer;
            case PIMPLandingOnSquareMessage(
              playerID: int playerID,
              square: int square,
            ):
              players[playerID]!.square = square;
            case PIMPJailPayOrRollMessage(
              playerID: int playerID,
              rollsLeft: int rollsLeft,
            ):
              jailRolls = rollsLeft;
              turn = playerID;

              state = GameState.rollDiceJail;
            case PIMPRollAgainMessage(playerID: int playerID):
              turn = playerID;
              state = .rollDice;
            case PIMPTaxSelectOptionMessage():
              state = .taxSelectOption;
            case PIMPPlayerTakeoverMessage(
              oldPlayer: int oldPlayer,
              newPlayer: int newPlayer,
            ):
              players[newPlayer] = Player(
                newPlayer,
                players[oldPlayer]!.piece,
                observers[newPlayer]!.name,
                players[oldPlayer]!.square,
                0,
              );
              observers.remove(newPlayer);
            case PIMPTransactionReopenedMessage(
              transactionID: int transactionID,
            ):
              transactions[transactionID]!.finished = false;
              transactions[transactionID]!.agreed = false;
              transactions[transactionID]!.otherAgreed = false;
            case PIMPTransactionOtherReopenedMessage(
              transactionID: int transactionID,
            ):
              transactions[transactionID]!.otherFinished = false;
              transactions[transactionID]!.agreed = false;
              transactions[transactionID]!.otherAgreed = false;
            case PIMPDeltaHousesPurchasedMessage(
              property: int property,
              houses: int houses,
              hotels: int hotels,
            ):
              ownedProperties[property]!.houses = houses;
              ownedProperties[property]!.hotels = hotels;
            case PIMPPlayerBecameObserverBankruptMessage(player: int player):
            case PIMPPlayerBecameObserverTransferMessage(player: int player):
            case PIMPPlayerBecameObserverKickedMessage(player: int player):
              observers[player] = Observer(
                players[player]!.id,
                players[player]!.piece,
                players[player]!.name,
              );
              players.remove(player);
            case PIMPObserverBecamePlayerMessage(player: int player):
              if (observers[player] == null) {
                print(
                  'got PIMPObserverBecamePlayerMessage with non-observer $player',
                );
                break;
              }
              players[player] = Player(
                observers[player]!.id,
                observers[player]!.piece,
                observers[player]!.name,
                0,
                0,
              );
              observers.remove(player);
            case PIMPPlayerWonMessage(player: int player):
              state = .won;
              turn = player;
            case PIMPDeltaPotMessage(pot: int pot):
              this.pot = pot;
            default:
              print(message);
          }
        });
      });
      print('connected ${client.gameID}!');
      File storageFile = File(
        '${(await getApplicationDocumentsDirectory()).path}user.txt',
      );
      if (storageFile.existsSync()) {
        List<String> lines = storageFile.readAsLinesSync();
        int playerID = int.parse(lines.first);
        int password = int.parse(lines.last);
        PIMPMessage response = await client.sendMessage(
          PIMPRejoinMessage(playerID, password),
          [0xfe, 0x0b, 0xf4],
        );
        if (response.type == 0xfe) {
          throw StateError('0xfe rejoining');
        }
        if (response.type == 0xf4) {
          setState(() {
            loggedIn = false;
          });
        } else {
          assert(response is PIMPWelcomeBackMessage);
          player = playerID;
          loggedIn = true;
        }
      } else {
        loggedIn = false;
      }
    });
  }

  String? name;
  int? piece;

  String propertyName(int property) {
    if (board == null) {
      return 'property $property';
    }
    return '${board!.properties[property].name} (property $property)';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: loggedIn == null
            ? CircularProgressIndicator()
            : loggedIn!
            ? Builder(
                builder: (context) {
                  return ListView(
                    children: [
                      if (!players.containsKey(player))
                        OutlinedButton(
                          onPressed: () async {
                            print(
                              await client!.sendMessage(
                                PIMPSwitchPlayMessage(),
                                [0xfe, 0x10],
                              ),
                            );
                          },
                          child: Text('Join game'),
                        ),
                      if (candidateID != null) ...[
                        Center(
                          child: Text(
                            '$candidateName is requesting to ${candidateWantsToPlay! ? 'play' : 'observe'}',
                          ),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            print(
                              await client!.sendMessage(
                                PIMPAcceptJoinMessage(candidateID!),
                                [0xfe, 0xfc],
                                true,
                              ),
                            );
                            candidateName = null;
                            candidateID = null;
                          },
                          child: Text('Accept'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            print(
                              await client!.sendMessage(
                                PIMPRefuseJoinMessage(candidateID!),
                                [0xfe],
                                true,
                              ),
                            );
                            candidateName = null;
                            candidateID = null;
                          },
                          child: Text('Refuse'),
                        ),
                      ],

                      if (turn == player)
                        ...switch (state) {
                          null => [CircularProgressIndicator()],
                          .rollDice => [
                            OutlinedButton(
                              onPressed: () async {
                                print(
                                  await client!.sendMessage(
                                    PIMPThrowDiceMessage(),
                                    [0xfe],
                                    true,
                                  ),
                                );
                              },
                              child: Text('Roll dice'),
                            ),
                            if (board != null)
                              BuyHousesButton(
                                board: board,
                                ownedProperties: ownedProperties,
                                player: player,
                                players: players,
                                client: client,
                              ),
                          ],
                          .buyProperty => [
                            Center(
                              child: Text(
                                'You can buy or auction ${propertyName(propertyForSale!)} for \$$propertyCost',
                              ),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                print(
                                  await client!.sendMessage(
                                    PIMPBuyPropertyMessage(),
                                    [0xfe, 0xe2, 0xee],
                                    true,
                                  ),
                                );
                              },
                              child: Text('Buy property'),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                print(
                                  await client!.sendMessage(
                                    PIMPAuctionPropertyMessage(),
                                    [0xfe],
                                    true,
                                  ),
                                );
                              },
                              child: Text('Auction property'),
                            ),
                          ],
                          .rollDiceJail => [
                            Center(
                              child: Column(
                                children: [
                                  Text('It is your turn, but you are in jail'),
                                  if (jailRolls != 0)
                                    OutlinedButton(
                                      onPressed: () async {
                                        print(
                                          await client!.sendMessage(
                                            PIMPJailRollDiceMessage(),
                                            [0xfe],
                                            true,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        'Roll dice ($jailRolls rolls left)',
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                          .transaction => [
                            Center(
                              child: Column(
                                children: [
                                  Text(
                                    'You have to complete transaction $blockingTransaction.',
                                  ),
                                ],
                              ),
                            ),
                          ],
                          .taxSelectOption => [
                            Text('You must pay income tax, select an option:'),
                            OutlinedButton(
                              onPressed: () async {
                                print(
                                  await client!.sendMessage(
                                    PIMPTaxPayTenPercentMessage(),
                                    [0xfe],
                                    true,
                                  ),
                                );
                              },
                              child: Text('Pay 10% of your net worth'),
                            ),
                            OutlinedButton(
                              onPressed: () async {
                                print(
                                  await client!.sendMessage(
                                    PIMPTaxPayFlatFeeMessage(),
                                    [0xfe],
                                    true,
                                  ),
                                );
                              },
                              child: Text('Pay \$200'),
                            ),
                          ],
                          .won => [Text('You have won.')],
                          .propertyAuction => [],
                        }
                      else if (turn != null)
                        Center(
                          child: Text(
                            'It is ${players[turn]?.name}\'s turn to ${stateVerb()}.',
                          ),
                        ),
                      if (state == .propertyAuction)
                        Center(
                          child: Text(
                            'Bidding for ${propertyName(propertyForSale!)} ${lastBid != null ? '(last bid: ${players[lastBidder]!.name} bid \$$lastBid)' : ''}',
                          ),
                        ),

                      if (state == .propertyAuction) ...[
                        OutlinedButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (context) {
                                return Dialog(
                                  child: Column(
                                    children: [
                                      OutlinedButton(
                                        onPressed: () {
                                          Navigator.pop(context);
                                        },
                                        child: Text('Close dialog'),
                                      ),
                                      Text('Bid:'),
                                      TextField(
                                        onSubmitted: (value) async {
                                          print(
                                            await client!.sendMessage(
                                              PIMPBidMessage(int.parse(value)),
                                              [0xfe],
                                              true,
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                          child: Text('Bid'),
                        ),
                        OutlinedButton(
                          onPressed: () async {
                            print(
                              await client!.sendMessage(PIMPNoBidMessage(), [
                                0xfe,
                                0xfc,
                              ], true),
                            );
                          },
                          child: Text('No Bid'),
                        ),
                      ],
                      if (board != null)
                        Wrap(
                          children: [
                            for (Square square in board!.squares)
                              SquareWidget(
                                square: square,
                                board: board!,
                                ownedProperties: ownedProperties,
                                players: players,
                                player: player,
                                pot: pot,
                                client: client!,
                              ),
                          ],
                        ),

                      for (Transaction transaction in transactions.values)
                        TransactionWidget(
                          player: player,
                          players: players,
                          transaction: transaction,
                          ownedProperties: ownedProperties,
                          cards: cards,
                          client: client!,
                          board: board,
                        ),
                      SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (Player player in players.values)
                              Expanded(
                                child: Column(
                                  children: [
                                    if (board == null)
                                      Text(
                                        'Player ${player.name} uses piece ${player.piece}, and has cash ${player.cash}.',
                                      )
                                    else
                                      Text(
                                        'Player ${player.name} uses piece ${player.piece}, and has cash ${player.cash}.',
                                      ),
                                    if (player.id != this.player)
                                      OutlinedButton(
                                        onPressed: () async {
                                          print(
                                            await client!.sendMessage(
                                              PIMPTransactionRequestTradeMessage(
                                                player.id,
                                              ),
                                              [0xfe, 0xfc],
                                              true,
                                            ),
                                          );
                                        },
                                        child: Text('Request trade'),
                                      ),
                                    Wrap(
                                      children: [
                                        for (Property property
                                            in ownedProperties.values)
                                          if (property.owner == player.id)
                                            SizedBox(
                                              width: 150,
                                              height: 150,
                                              child: PropertyWidget(
                                                propertyID: property.id,
                                                property: property,
                                                player: this.player,
                                                players: players,
                                                board: board,
                                                client: client!,
                                              ),
                                            ),
                                      ],
                                    ),
                                    for (Card card in cards.values)
                                      if (card.owner == player.id)
                                        CardWidget(
                                          card: card,
                                          players: players,
                                          client: client,
                                        ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      SingleChildScrollView(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (Observer observer in observers.values)
                              Expanded(
                                child: Column(
                                  children: [
                                    Text(
                                      'Observer ${observer.name} uses piece ${observer.piece}.',
                                    ),
                                    OutlinedButton(
                                      onPressed: players[player] != null
                                          ? () async {
                                              print(
                                                await client!.sendMessage(
                                                  PIMPTransferMessage(
                                                    observer.id,
                                                  ),
                                                  [0xfe, 0xfc, 0xec],
                                                  true,
                                                ),
                                              );
                                            }
                                          : null,
                                      child: Text('Transfer to observer'),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              )
            : joinPending
            ? Text('Waiting for players to accept you...')
            : Column(
                children: [
                  Text('Name'),
                  TextField(onChanged: (value) => setState(() => name = value)),
                  Text('Piece'),
                  TextField(
                    onChanged: (value) => piece = int.tryParse(value) ?? 0,
                  ),
                  OutlinedButton(
                    onPressed: name != null && name != ''
                        ? () async {
                            PIMPMessage message = await client!.sendMessage(
                              PIMPJoinMessage(piece ?? 0, true, name!),
                              [0xfe, 0x10, 0xfc],
                              true,
                            );

                            if (message.type == 0x10) {
                              setState(() {
                                joinPending = true;
                              });
                            } else {
                              print('error when joining: $message');
                            }
                          }
                        : null,
                    child: Text('Join game'),
                  ),
                ],
              ),
      ),
    );
  }

  String stateVerb() {
    switch (state) {
      case .rollDice:
        return 'roll dice';
      case .rollDiceJail:
        return 'roll dice (in jail)';
      case .buyProperty:
        return 'buy or auction ${propertyName(propertyForSale!)}';
      case .propertyAuction:
        return 'participate in a property auction';
      case .transaction:
        return 'finish a transaction with the bank';
      case .taxSelectOption:
        return 'choose to pay \$200 or 10% of their net worth for income tax';
      case .won:
        return 'do nothing, they have won';
      case null:
        return '<unknown>';
    }
  }
}

class BuyHousesButton extends StatelessWidget {
  const BuyHousesButton({
    super.key,
    required this.board,
    required this.ownedProperties,
    required this.player,
    required this.players,
    required this.client,
  });

  final Board? board;
  final Map<int, Property> ownedProperties;
  final int? player;
  final Map<int, Player> players;
  final PIMPClient? client;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: () {
        showDialog(
          context: context,
          builder: (context) {
            return Dialog(
              child: Column(
                children: [
                  OutlinedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text('Close dialog'),
                  ),
                  Text('Buy houses:'),
                  ...PropertyType.values
                      .where((PropertyType type) {
                        if (type == .railroad || type == .utility) {
                          return false;
                        }
                        Iterable<int> properties = board!.properties
                            .where(
                              (BoardProperty property) => property.type == type,
                            )
                            .map((e) => e.id);
                        return properties.every(
                          (e) => ownedProperties[e]?.owner == player,
                        );
                      })
                      .map((PropertyType type) {
                        return BuyHousesColorWidget(
                          ownedProperties: ownedProperties,
                          board: board,
                          players: players,
                          player: player,
                          client: client,
                          type: type,
                        );
                      }),
                ],
              ),
            );
          },
        );
      },
      child: Text('Buy houses'),
    );
  }
}

class BuyHousesColorWidget extends StatefulWidget {
  const BuyHousesColorWidget({
    super.key,
    required this.ownedProperties,
    required this.board,
    required this.players,
    required this.player,
    required this.client,
    required this.type,
  });
  final Map<int, Property> ownedProperties;
  final Board? board;
  final Map<int, Player> players;
  final int? player;
  final PIMPClient? client;
  final PropertyType type;

  @override
  State<BuyHousesColorWidget> createState() => _BuyHousesColorWidgetState();
}

class _BuyHousesColorWidgetState extends State<BuyHousesColorWidget> {
  Map<int, int> houses = {};

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: widget.ownedProperties.values
              .where((e) => widget.board!.properties[e.id].type == widget.type)
              .map((Property property) {
                houses[property.id] ??= property.hotels == 0
                    ? property.houses
                    : property.hotels + 4;
                return Column(
                  children: [
                    PropertyWidget(
                      board: widget.board,
                      propertyID: property.id,
                      property: property,
                      players: widget.players,
                      player: widget.player,
                      client: widget.client!,
                    ),
                    Row(
                      children: [
                        IconButton(
                          onPressed: () {
                            if (houses[property.id]! > 0) {
                              setState(() {
                                houses[property.id] = houses[property.id]! - 1;
                              });
                            }
                          },
                          icon: Icon(Icons.remove),
                        ),
                        Text(houses[property.id].toString()),
                        IconButton(
                          onPressed: () {
                            if (houses[property.id]! < 5) {
                              setState(() {
                                houses[property.id] = houses[property.id]! + 1;
                              });
                            }
                          },
                          icon: Icon(Icons.add),
                        ),
                      ],
                    ),
                  ],
                );
              })
              .toList(),
        ),
        OutlinedButton(
          onPressed: () async {
            Navigator.pop(context);
            print(
              await widget.client!.sendMessage(
                PIMPPurchaseHousesMessage(
                  houses.entries.map((MapEntry<int, int> propertyEntry) {
                    int newHouseTotal = propertyEntry.value;
                    int oldHouses =
                        widget.ownedProperties[propertyEntry.key]!.hotels > 0
                        ? 4
                        : widget.ownedProperties[propertyEntry.key]!.houses;
                    int oldHotels =
                        widget.ownedProperties[propertyEntry.key]!.hotels;
                    int newHouses;
                    int newHotels;
                    if (newHouseTotal <= 4) {
                      newHouses = newHouseTotal;
                      newHotels = 0;
                    } else {
                      newHouses = 4;
                      newHotels = newHouseTotal - 4;
                    }
                    return (
                      property: propertyEntry.key,
                      houses: newHouses - oldHouses,
                      hotels: newHotels - oldHotels,
                    );
                  }),
                ),
                [
                  0xfe,
                  0xfc,
                  0x91,
                  0x92,
                  0x93,
                  0x94,
                  0x95,
                  0x96,
                  0x97,
                  0x98,
                  0x99,
                  0x9a,
                  0x9b,
                ],
                true,
              ),
            );
          },
          child: Text('Buy houses'),
        ),
      ],
    );
  }
}

class SquareWidget extends StatelessWidget {
  const SquareWidget({
    super.key,
    required this.square,
    required this.board,
    required this.ownedProperties,
    required this.players,
    required this.player,
    required this.pot,
    required this.client,
  });

  final Square square;
  final Board board;
  final Map<int, Property> ownedProperties;
  final Map<int, Player> players;
  final int? player;
  final int? pot;
  final PIMPClient client;

  @override
  Widget build(BuildContext context) {
    double size = 150;
    if (square.type == .property) {
      Property? property = ownedProperties[square.propertyID];
      return SizedBox(
        width: size,
        height: size,
        child: PropertyWidget(
          board: board,
          propertyID: square.propertyID,
          property: property,
          players: players,
          player: player,
          client: client,
        ),
      );
    } else {
      return Container(
        width: size,
        color: Colors.grey,
        height: size,
        child: Column(
          children: [
            square.type == .freeParking
                ? Text('$square (pot \$$pot)')
                : square.type == .go
                ? Column(
                    children: [
                      Text('Go'),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: OutlinedButton(
                          onPressed: () async {
                            print(
                              await client.sendMessage(
                                PIMPClaimGoMessage(square.id),
                                [0xfe, 0xfc, 0xe1],
                                true,
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.black,
                          ),

                          child: Text(
                            'Claim go',
                            style: TextStyle(color: Colors.black),
                          ),
                        ),
                      ),
                    ],
                  )
                : Text(square.toString()),

            for (Player player in players.values)
              if (player.square == square.id) PlayerWidget(player: player),
          ],
        ),
      );
    }
  }
}

class PropertyWidget extends StatelessWidget {
  const PropertyWidget({
    super.key,
    required this.board,
    required this.propertyID,
    required this.property,
    required this.players,
    required this.player,
    required this.client,
  });

  final Board? board;
  final int propertyID;
  final Property? property;
  final Map<int, Player> players;
  final int? player;
  final PIMPClient client;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: propertyColors[board?.properties[propertyID].type] ?? Colors.white,

      child: Column(
        children: [
          Text(
            '${board?.properties[propertyID].name ?? 'Property $propertyID'} (${property == null ? 'Unowned' : players[property!.owner]?.name ?? 'ERROR'})',
            style: TextStyle(color: Colors.black),
          ),
          if ((property?.houses ?? 0) > 0)
            Row(
              children: List.filled(
                property!.houses,
                Icon(Icons.house, size: 20),
              ),
            ),
          if ((property?.hotels ?? 0) > 0)
            Row(
              children: List.filled(
                property!.hotels,
                Icon(Icons.hotel, size: 20),
              ),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (Player player in players.values)
                if (board?.squares[player.square].propertyID == propertyID)
                  PlayerWidget(player: player),
            ],
          ),
          if (player != null && property?.owner == player) ...[
            if (!property!.mortgaged)
              OutlinedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return Dialog(
                        child: Column(
                          children: [
                            OutlinedButton(
                              onPressed: () {
                                Navigator.pop(context);
                              },
                              child: Text('Close dialog'),
                            ),
                            Text('Claim rent:'),
                            for (Player player in players.values)
                              if (player.id != this.player)
                                OutlinedButton(
                                  onPressed: () async {
                                    print(
                                      await client.sendMessage(
                                        PIMPClaimRentMessage(
                                          player.id,
                                          propertyID,
                                        ),
                                        [0xfe, 0xfc, 0xe0],
                                        true,
                                      ),
                                    );
                                  },
                                  child: Text(
                                    'Claim rent from player ${player.name}',
                                  ),
                                ),
                          ],
                        ),
                      );
                    },
                  );
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
                child: Text(
                  'Claim rent',
                  style: TextStyle(color: Colors.black),
                ),
              ),
            if (property!.mortgaged)
              OutlinedButton(
                onPressed: () async {
                  print(
                    await client.sendMessage(
                      PIMPUnmortgagePropertyMessage(propertyID),
                      [0xfe, 0xfc, 0xe3],
                      true,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
                child: Text(
                  'Unmortgage',
                  style: TextStyle(color: Colors.black),
                ),
              )
            else
              OutlinedButton(
                onPressed: () async {
                  print(
                    await client.sendMessage(
                      PIMPMortgagePropertyMessage(propertyID),
                      [0xfe, 0xfc],
                      true,
                    ),
                  );
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.black),
                child: Text('Mortgage', style: TextStyle(color: Colors.black)),
              ),
          ] else if (property?.mortgaged ?? false)
            Text('Mortgaged.', style: TextStyle(color: Colors.black)),
        ],
      ),
    );
  }
}

class PlayerWidget extends StatelessWidget {
  const PlayerWidget({super.key, required this.player});

  final Player player;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: BoxBorder.all(color: Colors.white),
        color: Colors.black,
      ),
      width: 50,
      child: Center(
        child: Text(player.name, style: TextStyle(color: Colors.white)),
      ),
    );
  }
}

class TransactionWidget extends StatelessWidget {
  const TransactionWidget({
    super.key,
    required this.player,
    required this.players,
    required this.transaction,
    required this.ownedProperties,
    required this.cards,
    required this.client,
    required this.board,
  });

  final int? player;
  final Map<int, Player> players;
  final Transaction transaction;
  final Map<int, Property> ownedProperties;
  final Map<int, Card> cards;
  final PIMPClient client;
  final Board? board;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Transaction ${transaction.transactionID} with ${players[transaction.otherPlayer]?.name ?? (transaction.otherPlayer == 0 ? 'Bank' : 'ERROR: Unknown player')}: ${transaction.reason}',
        ),
        if (transaction.cash != null)
          Text('You are offering \$${transaction.cash}.'),
        for (int property in transaction.properties)
          Text(
            'You are offering ${board == null ? 'property $property' : board!.properties[property].name}.',
          ),
        for (int card in transaction.cards)
          Text('You are offering card $card.'),
        if (transaction.otherCash != null)
          Text('They are offering \$${transaction.otherCash}.'),
        for (int property in transaction.otherProperties)
          Text('They are offering property $property.'),
        for (int card in transaction.otherCards)
          Text('They are offering card $card.'),
        if (transaction.unusual) Text('This is an unusual transaction.'),
        if (transaction.otherAgreed)
          Text('Other player has agreed.')
        else if (transaction.otherFinished)
          Text('Other player has finished but not agreed.')
        else
          Text('Other player has not finished.'),
        if (!transaction.finished) ...[
          OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          OutlinedButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text('Close dialog'),
                          ),
                          Text('Offer property:'),
                          for (Property property
                              in ownedProperties.values.where(
                                (e) => e.owner == player,
                              )) ...[
                            SizedBox(
                              width: 150,
                              child: PropertyWidget(
                                propertyID: property.id,
                                property: property,
                                player: player,
                                players: players,
                                board: board,
                                client: client,
                              ),
                            ),
                            transaction.properties.contains(property.id)
                                ? OutlinedButton(
                                    onPressed: () async {
                                      print(
                                        await client.sendMessage(
                                          PIMPTransactionRemovePropertyMessage(
                                            transaction.transactionID,
                                            property.id,
                                          ),
                                          [0xfe, 0xfc],
                                          true,
                                        ),
                                      );
                                    },
                                    child: Text('Do not offer'),
                                  )
                                : OutlinedButton(
                                    onPressed: () async {
                                      print(
                                        await client.sendMessage(
                                          PIMPTransactionAddPropertyMessage(
                                            transaction.transactionID,
                                            property.id,
                                          ),
                                          [0xfe, 0xe5, 0xfc],
                                          true,
                                        ),
                                      );
                                    },
                                    child: Text('Offer'),
                                  ),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              );
            },
            child: Text('Offer property'),
          ),
          OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    child: Column(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Close dialog'),
                        ),
                        Text('Offer card:'),
                        for (Card card in cards.values.where(
                          (e) => e.owner == player,
                        )) ...[
                          CardWidget(
                            card: card,
                            players: players,
                            client: client,
                          ),
                          OutlinedButton(
                            onPressed: () async {
                              print(
                                await client.sendMessage(
                                  PIMPTransactionAddCardMessage(
                                    transaction.transactionID,
                                    card.id,
                                  ),
                                  [0xfe, 0xe5, 0xfc],
                                  true,
                                ),
                              );
                            },
                            child: Text('Offer'),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
            child: Text('Offer card'),
          ),
          OutlinedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (context) {
                  return Dialog(
                    child: Column(
                      children: [
                        OutlinedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          child: Text('Close dialog'),
                        ),
                        Text('Offer cash:'),

                        TextField(
                          onSubmitted: (value) async {
                            print(
                              await client.sendMessage(
                                PIMPTransactionSetCashMessage(
                                  transaction.transactionID,
                                  int.parse(value),
                                ),
                                [0xfe, 0xfc],
                                true,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            child: Text('Offer cash'),
          ),
        ],
        if (!transaction.finished)
          OutlinedButton(
            onPressed: () async {
              print(
                await client.sendMessage(
                  PIMPTransactionFinishMessage(transaction.transactionID),
                  [0xfe, 0xe7, 0xfc],
                  true,
                ),
              );
            },
            child: Text('Finish transaction'),
          )
        else if (!transaction.agreed)
          OutlinedButton(
            onPressed: () async {
              print(
                await client.sendMessage(
                  PIMPTransactionAgreeMessage(transaction.transactionID),
                  [0xfe, 0xfc, 0xe8, 0xe9],
                  true,
                ),
              );
            },
            child: Text('Agree to transaction'),
          )
        else
          Text('You have agreed.'),
        if (transaction.cancellable)
          OutlinedButton(
            onPressed: () async {
              print(
                await client.sendMessage(
                  PIMPTransactionCancelMessage(transaction.transactionID),
                  [0xfe, 0xeb, 0xfc],
                  true,
                ),
              );
            },
            child: Text('Cancel transaction'),
          ),
        if (transaction.finished)
          OutlinedButton(
            onPressed: () async {
              print(
                await client.sendMessage(
                  PIMPTransactionReopenMessage(transaction.transactionID),
                  [0xfe, 0xeb, 0xfc],
                  true,
                ),
              );
            },
            child: Text('Reopen transaction'),
          ),
        OutlinedButton(
          onPressed: () async {
            print(
              await client.sendMessage(
                PIMPBankruptTransactionMessage(transaction.transactionID),
                [0xfe, 0xea, 0xfc],
                true,
              ),
            );
          },
          child: Text('Declare bankruptcy'),
        ),
      ],
    );
  }
}

class CardWidget extends StatelessWidget {
  const CardWidget({
    super.key,
    required this.card,
    required this.players,
    required this.client,
  });

  final Card card;
  final Map<int, Player> players;
  final PIMPClient? client;

  @override
  Widget build(BuildContext context) {
    return Center(child: Text('Card ${card.id}'));
  }
}

class Transaction {
  final int transactionID;
  final TransactionReason reason;
  final int otherPlayer;
  final bool cancellable;
  int? cash;
  int? otherCash;
  bool finished = false;
  bool otherFinished = false;
  bool agreed = false;
  bool otherAgreed = false;
  bool unusual = false;
  Set<int> properties = {};
  Set<int> otherProperties = {};
  Set<int> cards = {};
  Set<int> otherCards = {};

  Transaction(
    this.transactionID,
    this.reason,
    this.otherPlayer,
    this.cancellable,
  );
}

abstract class TransactionReason {}

class TransactionReasonTrade extends TransactionReason {
  @override
  String toString() => 'Trade requested';
}

class TransactionReasonRent extends TransactionReason {
  final int cost;
  final int property;

  @override
  String toString() =>
      'Rent for property $property (\$$cost) has been requested';

  TransactionReasonRent(this.cost, this.property);
}

class TransactionReasonCard extends TransactionReason {
  final int cost;
  final int card;

  @override
  String toString() => 'Card $card requested \$$cost';

  TransactionReasonCard(this.cost, this.card);
}

class TransactionReasonSquare extends TransactionReason {
  final int cost;
  final int square;

  @override
  String toString() => 'Square $square requested \$$cost';

  TransactionReasonSquare(this.cost, this.square);
}

class TransactionReasonBank extends TransactionReason {
  final int cost;
  @override
  String toString() => 'Bank wants \$$cost';

  TransactionReasonBank(this.cost);
}

class TransactionReasonJail extends TransactionReason {
  final int cost;
  @override
  String toString() => 'Jail wants \$$cost';

  TransactionReasonJail(this.cost);
}

class Player {
  final int id;
  final int piece;
  final String name;
  int square;
  int cash;
  Player(this.id, this.piece, this.name, this.square, this.cash);
}

class Observer {
  final int id;
  final int piece;
  final String name;
  Observer(this.id, this.piece, this.name);
}

class Property {
  final int id;
  int owner;
  bool mortgaged;
  int houses;
  int hotels;
  Property(this.id, this.owner, this.mortgaged, this.houses, this.hotels);
}

class Card {
  final int id;
  int owner;
  Card(this.id, this.owner);
}
