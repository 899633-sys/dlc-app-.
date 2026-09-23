import 'dart:async';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(const DlcScalperApp());
}

class DlcScalperApp extends StatelessWidget {
  const DlcScalperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HKEX-SGX DLC Terminal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF0D1117),
        cardColor: const Color(0xFF161B22),
      ),
      home: const MainScalperScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// МОДЕЛИ ДАННЫХ
// ---------------------------------------------------------------------------

class StockConfig {
  final String ticker;
  final String name;
  final String qTicker; // Тикер для шлюза gtimg (например, r_hk00700)
  final List<DlcInstrument> dlcList;

  StockConfig({
    required this.ticker,
    required this.name,
    required this.qTicker,
    required this.dlcList,
  });
}

class DlcInstrument {
  final String dlcTicker;
  final String name;
  final String direction; // "LONG" или "SHORT"
  final int leverage;
  final double bid;
  final double ask;

  DlcInstrument({
    required this.dlcTicker,
    required this.name,
    required this.direction,
    required this.leverage,
    required this.bid,
    required this.ask,
  });

  double get spreadPercent => ask > 0 ? ((ask - bid) / ask) * 100 : 0.0;
}

class OrderBookEntry {
  final double price;
  final int volume;
  OrderBookEntry(this.price, this.volume);
}

// ---------------------------------------------------------------------------
// ГЛАВНЫЙ ЭКРАН
// ---------------------------------------------------------------------------

class MainScalperScreen extends StatefulWidget {
  const MainScalperScreen({super.key});

  @override
  State<MainScalperScreen> createState() => _MainScalperScreenState();
}

class _MainScalperScreenState extends State<MainScalperScreen> {
  // Список базовых активов HKEX, имеющих популярные DLC на SGX
  final List<StockConfig> supportedStocks = [
    StockConfig(
      ticker: "0700.HK",
      name: "Tencent Holdings",
      qTicker: "r_hk00700",
      dlcList: [
        DlcInstrument(dlcTicker: "WK4W", name: "Tencent 5xL SG", direction: "LONG", leverage: 5, bid: 0.420, ask: 0.425),
        DlcInstrument(dlcTicker: "JLZW", name: "Tencent 5xS SG", direction: "SHORT", leverage: 5, bid: 0.310, ask: 0.315),
      ],
    ),
    StockConfig(
      ticker: "9988.HK",
      name: "Alibaba Group",
      qTicker: "r_hk09988",
      dlcList: [
        DlcInstrument(dlcTicker: "BSIW", name: "Alibaba 5xL SG", direction: "LONG", leverage: 5, bid: 0.510, ask: 0.515),
        DlcInstrument(dlcTicker: "PZLW", name: "Alibaba 5xS SG", direction: "SHORT", leverage: 5, bid: 0.650, ask: 0.660),
      ],
    ),
    StockConfig(
      ticker: "3690.HK",
      name: "Meituan",
      qTicker: "r_hk03690",
      dlcList: [
        DlcInstrument(dlcTicker: "MBMW", name: "Meituan 5xL SG", direction: "LONG", leverage: 5, bid: 0.380, ask: 0.385),
        DlcInstrument(dlcTicker: "MBSW", name: "Meituan 5xS SG", direction: "SHORT", leverage: 5, bid: 0.440, ask: 0.445),
      ],
    ),
    StockConfig(
      ticker: "0175.HK",
      name: "Geely Automobile",
      qTicker: "r_hk00175",
      dlcList: [
        DlcInstrument(dlcTicker: "GLYW", name: "Geely 5xL SG", direction: "LONG", leverage: 5, bid: 0.280, ask: 0.285),
        DlcInstrument(dlcTicker: "GYSW", name: "Geely 5xS SG", direction: "SHORT", leverage: 5, bid: 0.350, ask: 0.360),
      ],
    ),
    StockConfig(
      ticker: "1211.HK",
      name: "BYD Company",
      qTicker: "r_hk01211",
      dlcList: [
        DlcInstrument(dlcTicker: "BYDW", name: "BYD 5xL SG", direction: "LONG", leverage: 5, bid: 0.620, ask: 0.630),
        DlcInstrument(dlcTicker: "BYEW", name: "BYD 5xS SG", direction: "SHORT", leverage: 5, bid: 0.290, ask: 0.295),
      ],
    ),
    StockConfig(
      ticker: "1810.HK",
      name: "Xiaomi Corp",
      qTicker: "r_hk01810",
      dlcList: [
        DlcInstrument(dlcTicker: "MZNW", name: "Xiaomi 5xL SG", direction: "LONG", leverage: 5, bid: 0.045, ask: 0.046),
        DlcInstrument(dlcTicker: "MZSW", name: "Xiaomi 5xS SG", direction: "SHORT", leverage: 5, bid: 0.110, ask: 0.115),
      ],
    ),
  ];

  late StockConfig currentStock;
  double livePrice = 0.0;
  double previousClose = 0.0;
  double dayHigh = 0.0;
  double dayLow = 0.0;
  String updateTimestamp = "--:--:--";
  bool isMarketConnected = false;

  // Индикаторы
  double emaFast = 0.0; // EMA 9
  double emaSlow = 0.0; // EMA 21
  final double alphaFast = 2 / (9 + 1);
  final double alphaSlow = 2 / (21 + 1);
  final List<double> priceHistory = [];
  double rsi = 50.0;

  // Стакан (Level 2)
  List<OrderBookEntry> bids = [];
  List<OrderBookEntry> asks = [];

  // Анализ тренда и потенциала
  String marketTrend = "WAIT";
  double trendStrengthPercent = 0.0;
  bool isTrendAboveOnePercent = false;
  bool canHoldOvernight = false;
  String overnightStatus = "";

  Timer? _pollingTimer;

  @override
  void initState() {
    super.initState();
    currentStock = supportedStocks.first;
    _startLiveStockFeed();
  }

  void _startLiveStockFeed() {
    _pollingTimer?.cancel();
    _fetchRealMarketQuote();
    // Опрашиваем котировки шлюза раз в 2 секунды
    _pollingTimer = Timer.periodic(const Duration(seconds: 2), (_) => _fetchRealMarketQuote());
  }

  Future<void> _fetchRealMarketQuote() async {
    try {
      final url = Uri.parse("https://qt.gtimg.cn/q=${currentStock.qTicker}");
      final response = await http.get(url).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200 && response.body.contains("~")) {
        _parseQuoteString(response.body);
      }
    } catch (_) {
      setState(() => isMarketConnected = false);
    }
  }

  void _parseQuoteString(String rawData) {
    try {
      final payload = rawData.split('"')[1];
      final parts = payload.split('~');
      if (parts.length < 35) return;

      final current = double.tryParse(parts[3]) ?? 0.0;
      final prev = double.tryParse(parts[4]) ?? 0.0;
      final high = double.tryParse(parts[33]) ?? 0.0;
      final low = double.tryParse(parts[34]) ?? 0.0;
      final timeStr = parts.length > 30 ? parts[30] : "";

      // Парсинг стакана (5 уровней)
      final List<OrderBookEntry> tempBids = [];
      final List<OrderBookEntry> tempAsks = [];

      // Ask 1..5: индексы 19, 21, 23, 25, 27 (цены) и 20, 22, 24, 26, 28 (объемы)
      for (int i = 0; i < 5; i++) {
        final p = double.tryParse(parts[19 + i * 2]) ?? 0.0;
        final v = int.tryParse(parts[20 + i * 2]) ?? 0;
        if (p > 0) tempAsks.add(OrderBookEntry(p, v));
      }

      // Bid 1..5: индексы 9, 11, 13, 15, 17 (цены) и 10, 12, 14, 16, 18 (объемы)
      for (int i = 0; i < 5; i++) {
        final p = double.tryParse(parts[9 + i * 2]) ?? 0.0;
        final v = int.tryParse(parts[10 + i * 2]) ?? 0;
        if (p > 0) tempBids.add(OrderBookEntry(p, v));
      }

      setState(() {
        isMarketConnected = true;
        livePrice = current;
        previousClose = prev;
        dayHigh = high;
        dayLow = low;
        bids = tempBids;
        asks = tempAsks;
        if (timeStr.length >= 6) {
          updateTimestamp = "${timeStr.substring(0, 2)}:${timeStr.substring(2, 4)}:${timeStr.substring(4, 6)}";
        }

        // Обновление индикаторов
        if (emaFast == 0.0) {
          emaFast = livePrice;
          emaSlow = livePrice;
        } else {
          emaFast = (livePrice * alphaFast) + (emaFast * (1 - alphaFast));
          emaSlow = (livePrice * alphaSlow) + (emaSlow * (1 - alphaSlow));
        }

        priceHistory.add(livePrice);
        if (priceHistory.length > 14) {
          priceHistory.removeAt(0);
          _calcRsi();
        }

        _evaluateTrendAndPotential();
      });
    } catch (_) {}
  }

  void _calcRsi() {
    double gains = 0;
    double losses = 0;
    for (int i = 1; i < priceHistory.length; i++) {
      final diff = priceHistory[i] - priceHistory[i - 1];
      if (diff >= 0) gains += diff;
      else losses += diff.abs();
    }
    if (losses == 0) {
      rsi = 100;
      return;
    }
    final rs = gains / losses;
    rsi = 100 - (100 / (1 + rs));
  }

  void _evaluateTrendAndPotential() {
    if (emaSlow == 0.0) return;

    // Расстояние между быстрой и медленной EMA как сила текущего импульса
    final distancePercent = ((emaFast - emaSlow).abs() / emaSlow) * 100;
    trendStrengthPercent = distancePercent;

    // Оценка тренда
    if (emaFast > emaSlow && rsi < 70) {
      marketTrend = "STRONG BUY";
    } else if (emaFast < emaSlow && rsi > 30) {
      marketTrend = "STRONG SELL";
    } else {
      marketTrend = "WAIT";
    }

    // Проверка потенциала движения:
    // Потенциал >= 1% считается выполненным, если дневной диапазон (High - Low)
    // и текущий направленный импульс дают пространство хода не менее 1.0%
    final dayRangePercent = livePrice > 0 ? ((dayHigh - dayLow) / livePrice) * 100 : 0.0;
    isTrendAboveOnePercent = (distancePercent >= 0.25) || (dayRangePercent >= 1.2 && marketTrend != "WAIT");

    // Оценка возможности переноса позиции на ночь (Overnight Hold)
    // Для переноса тренд должен быть уверенным, без перекупленности/перепроданности по RSI
    if (marketTrend == "STRONG BUY" && rsi >= 45 && rsi <= 65 && distancePercent >= 0.3) {
      canHoldOvernight = true;
      overnightStatus = "Тренд устойчивый. Допустим перенос на следующий день (Swing).";
    } else if (marketTrend == "STRONG SELL" && rsi <= 55 && rsi >= 35 && distancePercent >= 0.3) {
      canHoldOvernight = true;
      overnightStatus = "Медвежий тренд стабилен. Допустим овернайт для Short DLC.";
    } else {
      canHoldOvernight = false;
      overnightStatus = "Только внутри дня (Intraday). Высокий риск отката на открытии завтра.";
    }
  }

  List<DlcInstrument> _getRankedDlcList() {
    final list = List<DlcInstrument>.from(currentStock.dlcList);

    // Сортировка:
    // 1. По совпадению с направлением тренда (BUY -> Long DLC наверх, SELL -> Short DLC наверх)
    // 2. Внутри группы — по минимальному спреду (самые ликвидные и выгодные выше)
    list.sort((a, b) {
      final bool aMatches = (marketTrend == "STRONG BUY" && a.direction == "LONG") ||
          (marketTrend == "STRONG SELL" && a.direction == "SHORT");
      final bool bMatches = (marketTrend == "STRONG BUY" && b.direction == "LONG") ||
          (marketTrend == "STRONG SELL" && b.direction == "SHORT");

      if (aMatches && !bMatches) return -1;
      if (!aMatches && bMatches) return 1;

      return a.spreadPercent.compareTo(b.spreadPercent);
    });

    return list;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // ИНТЕРФЕЙС
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final double changePercent = previousClose > 0 ? ((livePrice - previousClose) / previousClose) * 100 : 0.0;
    final Color priceColor = changePercent >= 0 ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    final rankedDlcs = _getRankedDlcList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<StockConfig>(
            value: currentStock,
            dropdownColor: const Color(0xFF161B22),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
            items: supportedStocks.map((stock) {
              return DropdownMenuItem<StockConfig>(
                value: stock,
                child: Text(
                  "${stock.ticker} (${stock.name})",
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              );
            }).toList(),
            onChanged: (newStock) {
              if (newStock != null) {
                setState(() {
                  currentStock = newStock;
                  livePrice = 0.0;
                  emaFast = 0.0;
                  emaSlow = 0.0;
                  priceHistory.clear();
                  bids.clear();
                  asks.clear();
                });
                _startLiveStockFeed();
              }
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 10,
                  color: isMarketConnected ? Colors.greenAccent : Colors.orangeAccent,
                ),
                const SizedBox(width: 6),
                Text(
                  updateTimestamp,
                  style: const TextStyle(fontSize: 12, color: Colors.white60),
                )
              ],
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Текущая цена и диапазон дня
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      livePrice > 0 ? "HK\$ ${livePrice.toStringAsFixed(2)}" : "Загрузка...",
                      style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      "${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}% к пред. закрытию",
                      style: TextStyle(color: priceColor, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("High: ${dayHigh.toStringAsFixed(2)}", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    Text("Low:  ${dayLow.toStringAsFixed(2)}", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 14),

            // Индикаторы
            Row(
              children: [
                _buildMetricBox("EMA 9", emaFast.toStringAsFixed(2), Colors.cyanAccent),
                const SizedBox(width: 8),
                _buildMetricBox("EMA 21", emaSlow.toStringAsFixed(2), Colors.amberAccent),
                const SizedBox(width: 8),
                _buildMetricBox("RSI 14", rsi.toStringAsFixed(1), rsi > 70 ? Colors.redAccent : (rsi < 30 ? Colors.greenAccent : Colors.white)),
              ],
            ),
            const SizedBox(height: 14),

            // Карточка анализа тренда и фильтра 1%
            _buildTrendStatusCard(),
            const SizedBox(height: 12),

            // Оценка овернайта (перенос на след. день)
            _buildOvernightBanner(),
            const SizedBox(height: 18),

            // Стакан заявок (Level 2)
            const Text(
              "ГЛУБИНА РЫНКА (LEVEL 2 • СТАКАН HKEX)",
              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _buildOrderBook(),
            const SizedBox(height: 20),

            // Ранжированный список DLC
            const Text(
              "РЕКОМЕНДОВАННЫЕ DLC НА SGX (СОРТИРОВКА ПО ВЫГОДЕ И СПРЕДУ)",
              style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ...rankedDlcs.map((dlc) => _buildDlcCard(dlc)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendStatusCard() {
    Color cardColor = Colors.grey;
    if (marketTrend == "STRONG BUY") cardColor = const Color(0xFF00E676);
    if (marketTrend == "STRONG SELL") cardColor = const Color(0xFFFF5252);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardColor, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "СИГНАЛ: $marketTrend",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: cardColor),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isTrendAboveOnePercent ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isTrendAboveOnePercent ? "ПОТЕНЦИАЛ >= 1.0% ПОДТВЕРЖДЕН" : "ХОД < 1.0% (СПРЕД СЪЕСТ ПРИБЫЛЬ)",
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isTrendAboveOnePercent ? Colors.greenAccent : Colors.amberAccent,
                  ),
                ),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(
            isTrendAboveOnePercent
                ? "Запас движения базовой акции достаточен для покрытия спреда DLC с плечом."
                : "Волатильность или разрыв средних слишком малы. Вход не рекомендуется.",
            style: const TextStyle(fontSize: 12, color: Colors.white70),
          )
        ],
      ),
    );
  }

  Widget _buildOvernightBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: canHoldOvernight ? Colors.blue.withOpacity(0.12) : const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: canHoldOvernight ? Colors.blueAccent : Colors.white12),
      ),
      child: Row(
        children: [
          Icon(
            canHoldOvernight ? Icons.nightlight_round : Icons.schedule,
            color: canHoldOvernight ? Colors.lightBlueAccent : Colors.white38,
            size: 22,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  canHoldOvernight ? "ПЕРЕНОС НА СЛЕДУЮЩИЙ ДЕНЬ ДОПУСТИМ" : "ПЕРЕНОС (OVERNIGHT) НЕ РЕКОМЕНДОВАН",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: canHoldOvernight ? Colors.lightBlueAccent : Colors.white54,
                  ),
                ),
                Text(overnightStatus, style: const TextStyle(fontSize: 11, color: Colors.white70)),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildOrderBook() {
    if (bids.isEmpty && asks.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text("Ожидание пакета стакана от HKEX...", style: TextStyle(color: Colors.white38))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        children: [
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("BID (ПОКУПКА)", style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
              Text("ASK (ПРОДАЖА)", style: TextStyle(color: Colors.redAccent, fontSize: 11, fontWeight: FontWeight.bold)),
            ],
          ),
          const Divider(color: Colors.white10, height: 12),
          for (int i = 0; i < 5; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    i < bids.length ? "${bids[i].price.toStringAsFixed(2)}  (${bids[i].volume})" : "-",
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                  Text(
                    i < asks.length ? "(${asks[i].volume})  ${asks[i].price.toStringAsFixed(2)}" : "-",
                    style: const TextStyle(fontSize: 12, color: Colors.white),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDlcCard(DlcInstrument dlc) {
    final bool isPrioritized = (marketTrend == "STRONG BUY" && dlc.direction == "LONG") ||
        (marketTrend == "STRONG SELL" && dlc.direction == "SHORT");

    final Color directionColor = dlc.direction == "LONG" ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPrioritized ? const Color(0xFF1E2633) : const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrioritized ? directionColor.withOpacity(0.8) : Colors.white12,
          width: isPrioritized ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    dlc.dlcTicker,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: directionColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      "${dlc.leverage}x ${dlc.direction}",
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: directionColor),
                    ),
                  ),
                  if (isPrioritized) ...[
                    const SizedBox(width: 6),
                    const Icon(Icons.star, color: Colors.amberAccent, size: 16),
                  ]
                ],
              ),
              const SizedBox(height: 4),
              Text(dlc.name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "Ask: S\$ ${dlc.ask.toStringAsFixed(3)}",
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
              ),
              const SizedBox(height: 2),
              Text(
                "Спред: ${dlc.spreadPercent.toStringAsFixed(2)}%",
                style: TextStyle(
                  fontSize: 11,
                  color: dlc.spreadPercent <= 1.2 ? Colors.greenAccent : Colors.orangeAccent,
                ),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildMetricBox(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }
}
