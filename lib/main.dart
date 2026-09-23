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
      home: const RootNavigationContainer(),
    );
  }
}

// ---------------------------------------------------------------------------
// МОДЕЛИ
// ---------------------------------------------------------------------------

class StockConfig {
  final String ticker;
  final String name;
  final String qTicker;
  final String market; // "HK" или "US"
  final List<DlcInstrument> dlcList;

  StockConfig({
    required this.ticker,
    required this.name,
    required this.qTicker,
    this.market = "HK",
    this.dlcList = const [],
  });
}

class DlcInstrument {
  final String dlcTicker;
  final String name;
  final String direction;
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

class WatchlistQuote {
  final String ticker;
  final String name;
  final String market;
  final double price;
  final double changePercent;
  final String sessionType;
  final String time;

  WatchlistQuote({
    required this.ticker,
    required this.name,
    required this.market,
    required this.price,
    required this.changePercent,
    required this.sessionType,
    required this.time,
  });
}

// ---------------------------------------------------------------------------
// НАВИГАЦИОННЫЙ КОНТЕЙНЕР
// ---------------------------------------------------------------------------

class RootNavigationContainer extends StatefulWidget {
  const RootNavigationContainer({super.key});

  @override
  State<RootNavigationContainer> createState() => _RootNavigationContainerState();
}

class _RootNavigationContainerState extends State<RootNavigationContainer> {
  int _currentIndex = 0;

  final List<StockConfig> masterStockDirectory = [
    // HKEX с DLC на SGX
    StockConfig(
      ticker: "0700.HK",
      name: "Tencent",
      qTicker: "r_hk00700",
      market: "HK",
      dlcList: [
        DlcInstrument(dlcTicker: "WK4W", name: "Tencent 5xL SG", direction: "LONG", leverage: 5, bid: 0.420, ask: 0.425),
        DlcInstrument(dlcTicker: "JLZW", name: "Tencent 5xS SG", direction: "SHORT", leverage: 5, bid: 0.310, ask: 0.315),
      ],
    ),
    StockConfig(
      ticker: "9988.HK",
      name: "Alibaba HK",
      qTicker: "r_hk09988",
      market: "HK",
      dlcList: [
        DlcInstrument(dlcTicker: "BSIW", name: "Alibaba 5xL SG", direction: "LONG", leverage: 5, bid: 0.510, ask: 0.515),
        DlcInstrument(dlcTicker: "PZLW", name: "Alibaba 5xS SG", direction: "SHORT", leverage: 5, bid: 0.650, ask: 0.660),
      ],
    ),
    StockConfig(
      ticker: "3690.HK",
      name: "Meituan",
      qTicker: "r_hk03690",
      market: "HK",
      dlcList: [
        DlcInstrument(dlcTicker: "MBMW", name: "Meituan 5xL SG", direction: "LONG", leverage: 5, bid: 0.380, ask: 0.385),
        DlcInstrument(dlcTicker: "MBSW", name: "Meituan 5xS SG", direction: "SHORT", leverage: 5, bid: 0.440, ask: 0.445),
      ],
    ),
    StockConfig(
      ticker: "0175.HK",
      name: "Geely Auto",
      qTicker: "r_hk00175",
      market: "HK",
      dlcList: [
        DlcInstrument(dlcTicker: "GLYW", name: "Geely 5xL SG", direction: "LONG", leverage: 5, bid: 0.280, ask: 0.285),
        DlcInstrument(dlcTicker: "GYSW", name: "Geely 5xS SG", direction: "SHORT", leverage: 5, bid: 0.350, ask: 0.360),
      ],
    ),
    StockConfig(
      ticker: "1211.HK",
      name: "BYD Company",
      qTicker: "r_hk01211",
      market: "HK",
      dlcList: [
        DlcInstrument(dlcTicker: "BYDW", name: "BYD 5xL SG", direction: "LONG", leverage: 5, bid: 0.620, ask: 0.630),
        DlcInstrument(dlcTicker: "BYEW", name: "BYD 5xS SG", direction: "SHORT", leverage: 5, bid: 0.290, ask: 0.295),
      ],
    ),
    StockConfig(
      ticker: "1810.HK",
      name: "Xiaomi",
      qTicker: "r_hk01810",
      market: "HK",
      dlcList: [
        DlcInstrument(dlcTicker: "MZNW", name: "Xiaomi 5xL SG", direction: "LONG", leverage: 5, bid: 0.045, ask: 0.046),
        DlcInstrument(dlcTicker: "MZSW", name: "Xiaomi 5xS SG", direction: "SHORT", leverage: 5, bid: 0.110, ask: 0.115),
      ],
    ),
    // US Stocks
    StockConfig(ticker: "TSLA", name: "Tesla Inc", qTicker: "s_usTSLA", market: "US"),
    StockConfig(ticker: "NVDA", name: "Nvidia", qTicker: "s_usNVDA", market: "US"),
    StockConfig(ticker: "AAPL", name: "Apple Inc", qTicker: "s_usAAPL", market: "US"),
    StockConfig(ticker: "BABA", name: "Alibaba US ADR", qTicker: "s_usBABA", market: "US"),
  ];

  late List<StockConfig> userFavorites;

  @override
  void initState() {
    super.initState();
    userFavorites = [
      masterStockDirectory[0],
      masterStockDirectory[1],
      masterStockDirectory[6],
      masterStockDirectory[7],
    ];
  }

  void _toggleFavorite(StockConfig stock) {
    setState(() {
      if (userFavorites.any((s) => s.ticker == stock.ticker)) {
        userFavorites.removeWhere((s) => s.ticker == stock.ticker);
      } else {
        userFavorites.add(stock);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DlcScalperScreen(stocks: masterStockDirectory.where((s) => s.market == "HK").toList()),
      WatchlistScreen(
        favorites: userFavorites,
        allDirectory: masterStockDirectory,
        onToggleFavorite: _toggleFavorite,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        backgroundColor: const Color(0xFF161B22),
        selectedItemColor: Colors.cyanAccent,
        unselectedItemColor: Colors.white38,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.show_chart_rounded),
            label: "Скальпер DLC",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.star_rounded),
            label: "Избранное (Live)",
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ЭКРАН 1: СКАЛЬПЕР DLC
// ---------------------------------------------------------------------------

class DlcScalperScreen extends StatefulWidget {
  final List<StockConfig> stocks;
  const DlcScalperScreen({super.key, required this.stocks});

  @override
  State<DlcScalperScreen> createState() => _DlcScalperScreenState();
}

class _DlcScalperScreenState extends State<DlcScalperScreen> {
  late StockConfig currentStock;
  double livePrice = 0.0;
  double previousClose = 0.0;
  double dayHigh = 0.0;
  double dayLow = 0.0;
  String updateTimestamp = "--:--:--";
  bool isMarketConnected = false;

  double emaFast = 0.0;
  double emaSlow = 0.0;
  final double alphaFast = 2 / (9 + 1);
  final double alphaSlow = 2 / (21 + 1);
  final List<double> priceHistory = [];
  double rsi = 50.0;

  List<OrderBookEntry> bids = [];
  List<OrderBookEntry> asks = [];

  String marketTrend = "WAIT";
  bool isTrendAboveOnePercent = false;
  bool canHoldOvernight = false;
  String overnightStatus = "";

  Timer? _pollingTimer;

  // Браузерные заголовки для обхода фильтров CDN Tencent
  final Map<String, String> requestHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://finance.qq.com/',
    'Accept': '*/*',
  };

  @override
  void initState() {
    super.initState();
    currentStock = widget.stocks.first;
    _startFeed();
  }

  void _startFeed() {
    _pollingTimer?.cancel();
    _fetchQuote();
    // Опрос каждые 800 мс для высокой точности
    _pollingTimer = Timer.periodic(const Duration(milliseconds: 800), (_) => _fetchQuote());
  }

  Future<void> _fetchQuote() async {
    try {
      final url = Uri.parse("https://qt.gtimg.cn/q=${currentStock.qTicker}");
      final res = await http.get(url, headers: requestHeaders).timeout(const Duration(seconds: 3));

      if (res.statusCode == 200 && res.body.contains("~")) {
        _parseQuote(res.body);
      }
    } catch (_) {
      // Запасной протокол http в случае сбоя SSL рукопожатия
      try {
        final fallbackUrl = Uri.parse("http://qt.gtimg.cn/q=${currentStock.qTicker}");
        final res = await http.get(fallbackUrl, headers: requestHeaders).timeout(const Duration(seconds: 3));
        if (res.statusCode == 200 && res.body.contains("~")) {
          _parseQuote(res.body);
        }
      } catch (_) {
        if (mounted) setState(() => isMarketConnected = false);
      }
    }
  }

  void _parseQuote(String raw) {
    try {
      if (!raw.contains('"')) return;
      final payload = raw.split('"')[1];
      final parts = payload.split('~');
      if (parts.length < 35) return;

      final current = double.tryParse(parts[3]) ?? 0.0;
      final prev = double.tryParse(parts[4]) ?? 0.0;
      final high = double.tryParse(parts[33]) ?? 0.0;
      final low = double.tryParse(parts[34]) ?? 0.0;
      final timeStr = parts.length > 30 ? parts[30] : "";

      final List<OrderBookEntry> tempBids = [];
      final List<OrderBookEntry> tempAsks = [];

      for (int i = 0; i < 5; i++) {
        final p = double.tryParse(parts[19 + i * 2]) ?? 0.0;
        final v = int.tryParse(parts[20 + i * 2]) ?? 0;
        if (p > 0) tempAsks.add(OrderBookEntry(p, v));
      }
      for (int i = 0; i < 5; i++) {
        final p = double.tryParse(parts[9 + i * 2]) ?? 0.0;
        final v = int.tryParse(parts[10 + i * 2]) ?? 0;
        if (p > 0) tempBids.add(OrderBookEntry(p, v));
      }

      if (!mounted) return;

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

        _evalTrend();
      });
    } catch (_) {}
  }

  void _calcRsi() {
    double gains = 0, losses = 0;
    for (int i = 1; i < priceHistory.length; i++) {
      final diff = priceHistory[i] - priceHistory[i - 1];
      if (diff >= 0) gains += diff; else losses += diff.abs();
    }
    if (losses == 0) { rsi = 100; return; }
    rsi = 100 - (100 / (1 + (gains / losses)));
  }

  void _evalTrend() {
    if (emaSlow == 0.0) return;
    final distPercent = ((emaFast - emaSlow).abs() / emaSlow) * 100;

    if (emaFast > emaSlow && rsi < 70) {
      marketTrend = "STRONG BUY";
    } else if (emaFast < emaSlow && rsi > 30) {
      marketTrend = "STRONG SELL";
    } else {
      marketTrend = "WAIT";
    }

    final dayRangePercent = livePrice > 0 ? ((dayHigh - dayLow) / livePrice) * 100 : 0.0;
    isTrendAboveOnePercent = (distPercent >= 0.25) || (dayRangePercent >= 1.2 && marketTrend != "WAIT");

    if (marketTrend == "STRONG BUY" && rsi >= 45 && rsi <= 65 && distPercent >= 0.3) {
      canHoldOvernight = true;
      overnightStatus = "Тренд устойчивый. Допустим перенос на следующий день (Swing).";
    } else if (marketTrend == "STRONG SELL" && rsi <= 55 && rsi >= 35 && distPercent >= 0.3) {
      canHoldOvernight = true;
      overnightStatus = "Медвежий тренд стабилен. Допустим овернайт для Short DLC.";
    } else {
      canHoldOvernight = false;
      overnightStatus = "Только внутри дня (Intraday). Риск гэпа/отката завтра.";
    }
  }

  List<DlcInstrument> _getRankedDlcs() {
    final list = List<DlcInstrument>.from(currentStock.dlcList);
    list.sort((a, b) {
      final aM = (marketTrend == "STRONG BUY" && a.direction == "LONG") || (marketTrend == "STRONG SELL" && a.direction == "SHORT");
      final bM = (marketTrend == "STRONG BUY" && b.direction == "LONG") || (marketTrend == "STRONG SELL" && b.direction == "SHORT");
      if (aM && !bM) return -1;
      if (!aM && bM) return 1;
      return a.spreadPercent.compareTo(b.spreadPercent);
    });
    return list;
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final double changePercent = previousClose > 0 ? ((livePrice - previousClose) / previousClose) * 100 : 0.0;
    final Color priceColor = changePercent >= 0 ? const Color(0xFF00E676) : const Color(0xFFFF5252);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        title: DropdownButtonHideUnderline(
          child: DropdownButton<StockConfig>(
            value: currentStock,
            dropdownColor: const Color(0xFF161B22),
            icon: const Icon(Icons.arrow_drop_down, color: Colors.cyanAccent),
            items: widget.stocks.map((s) => DropdownMenuItem(value: s, child: Text("${s.ticker} (${s.name})", style: const TextStyle(fontWeight: FontWeight.bold)))).toList(),
            onChanged: (val) {
              if (val != null) {
                setState(() {
                  currentStock = val;
                  livePrice = 0.0;
                  emaFast = 0.0;
                  emaSlow = 0.0;
                  priceHistory.clear();
                  bids.clear();
                  asks.clear();
                });
                _startFeed();
              }
            },
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Row(
              children: [
                Icon(Icons.circle, size: 10, color: isMarketConnected ? Colors.greenAccent : Colors.orangeAccent),
                const SizedBox(width: 6),
                Text(updateTimestamp, style: const TextStyle(fontSize: 12, color: Colors.white60)),
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(livePrice > 0 ? "HK\$ ${livePrice.toStringAsFixed(2)}" : "Загрузка...", style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    Text("${changePercent >= 0 ? '+' : ''}${changePercent.toStringAsFixed(2)}% к закрытию", style: TextStyle(color: priceColor, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text("High: ${dayHigh > 0 ? dayHigh.toStringAsFixed(2) : '--'}", style: const TextStyle(color: Colors.greenAccent, fontSize: 12)),
                    Text("Low:  ${dayLow > 0 ? dayLow.toStringAsFixed(2) : '--'}", style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ],
                )
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildBox("EMA 9", emaFast.toStringAsFixed(2), Colors.cyanAccent),
                const SizedBox(width: 8),
                _buildBox("EMA 21", emaSlow.toStringAsFixed(2), Colors.amberAccent),
                const SizedBox(width: 8),
                _buildBox("RSI 14", rsi.toStringAsFixed(1), rsi > 70 ? Colors.redAccent : (rsi < 30 ? Colors.greenAccent : Colors.white)),
              ],
            ),
            const SizedBox(height: 14),
            _buildTrendCard(),
            const SizedBox(height: 12),
            _buildOvernightCard(),
            const SizedBox(height: 18),
            const Text("ГЛУБИНА РЫНКА (LEVEL 2 • СТАКАН HKEX)", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildOrderBook(),
            const SizedBox(height: 20),
            const Text("РЕКОМЕНДОВАННЫЕ DLC НА SGX (СОРТИРОВКА ПО ВЫГОДЕ)", style: TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            ..._getRankedDlcs().map((d) => _buildDlcTile(d)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendCard() {
    Color c = marketTrend == "STRONG BUY" ? const Color(0xFF00E676) : (marketTrend == "STRONG SELL" ? const Color(0xFFFF5252) : Colors.grey);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: c, width: 1.5)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("СИГНАЛ: $marketTrend", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: c)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(color: isTrendAboveOnePercent ? Colors.green.withOpacity(0.2) : Colors.amber.withOpacity(0.2), borderRadius: BorderRadius.circular(6)),
                child: Text(isTrendAboveOnePercent ? "ПОТЕНЦИАЛ >= 1.0%" : "ХОД < 1.0%", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isTrendAboveOnePercent ? Colors.greenAccent : Colors.amberAccent)),
              )
            ],
          ),
          const SizedBox(height: 4),
          Text(isTrendAboveOnePercent ? "Запас движения базовой акции достаточен для покрытия спреда DLC." : "Волатильность мала. Вход не рекомендуется.", style: const TextStyle(fontSize: 12, color: Colors.white70)),
        ],
      ),
    );
  }

  Widget _buildOvernightCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: canHoldOvernight ? Colors.blue.withOpacity(0.12) : const Color(0xFF161B22), borderRadius: BorderRadius.circular(10), border: Border.all(color: canHoldOvernight ? Colors.blueAccent : Colors.white12)),
      child: Row(
        children: [
          Icon(canHoldOvernight ? Icons.nightlight_round : Icons.schedule, color: canHoldOvernight ? Colors.lightBlueAccent : Colors.white38, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(canHoldOvernight ? "ПЕРЕНОС (OVERNIGHT) ДОПУСТИМ" : "ПЕРЕНОС НЕ РЕКОМЕНДОВАН", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: canHoldOvernight ? Colors.lightBlueAccent : Colors.white54)),
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
        child: const Center(
          child: Text("Ожидание пакета стакана от HKEX...", style: TextStyle(color: Colors.white38)),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white10)),
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

  Widget _buildDlcTile(DlcInstrument dlc) {
    final bool isPri = (marketTrend == "STRONG BUY" && dlc.direction == "LONG") || (marketTrend == "STRONG SELL" && dlc.direction == "SHORT");
    final Color c = dlc.direction == "LONG" ? const Color(0xFF00E676) : const Color(0xFFFF5252);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isPri ? const Color(0xFF1E2633) : const Color(0xFF161B22),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isPri ? c.withOpacity(0.8) : Colors.white12, width: isPri ? 1.5 : 1.0),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(dlc.dlcTicker, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(color: c.withOpacity(0.2), borderRadius: BorderRadius.circular(4)),
                    child: Text("${dlc.leverage}x ${dlc.direction}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: c)),
                  ),
                  if (isPri) ...[const SizedBox(width: 6), const Icon(Icons.star, color: Colors.amberAccent, size: 16)]
                ],
              ),
              const SizedBox(height: 4),
              Text(dlc.name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text("Ask: S\$ ${dlc.ask.toStringAsFixed(3)}", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 2),
              Text("Спред: ${dlc.spreadPercent.toStringAsFixed(2)}%", style: TextStyle(fontSize: 11, color: dlc.spreadPercent <= 1.2 ? Colors.greenAccent : Colors.orangeAccent)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildBox(String l, String v, Color c) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(color: const Color(0xFF161B22), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white10)),
        child: Column(
          children: [
            Text(l, style: const TextStyle(fontSize: 11, color: Colors.white54)),
            const SizedBox(height: 4),
            Text(v, style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: c)),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ЭКРАН 2: ИЗБРАННОЕ
// ---------------------------------------------------------------------------

class WatchlistScreen extends StatefulWidget {
  final List<StockConfig> favorites;
  final List<StockConfig> allDirectory;
  final Function(StockConfig) onToggleFavorite;

  const WatchlistScreen({
    super.key,
    required this.favorites,
    required this.allDirectory,
    required this.onToggleFavorite,
  });

  @override
  State<WatchlistScreen> createState() => _WatchlistScreenState();
}

class _WatchlistScreenState extends State<WatchlistScreen> {
  Map<String, WatchlistQuote> liveQuotes = {};
  Timer? _timer;

  final Map<String, String> requestHeaders = {
    'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
    'Referer': 'https://finance.qq.com/',
    'Accept': '*/*',
  };

  @override
  void initState() {
    super.initState();
    _fetchWatchlistData();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchWatchlistData());
  }

  Future<void> _fetchWatchlistData() async {
    if (widget.favorites.isEmpty) return;
    try {
      final queryParam = widget.favorites.map((e) => e.qTicker).join(',');
      final url = Uri.parse("https://qt.gtimg.cn/q=$queryParam");
      final res = await http.get(url, headers: requestHeaders).timeout(const Duration(seconds: 4));

      if (res.statusCode == 200) {
        _parseWatchlistBatch(res.body);
      }
    } catch (_) {
      try {
        final fallback = Uri.parse("http://qt.gtimg.cn/q=${widget.favorites.map((e) => e.qTicker).join(',')}");
        final res = await http.get(fallback, headers: requestHeaders).timeout(const Duration(seconds: 4));
        if (res.statusCode == 200) {
          _parseWatchlistBatch(res.body);
        }
      } catch (_) {}
    }
  }

  void _parseWatchlistBatch(String body) {
    final lines = body.split(';');
    final Map<String, WatchlistQuote> newQuotes = {};

    for (final line in lines) {
      if (!line.contains('="') || !line.contains('~')) continue;
      final payload = line.split('="')[1];
      final parts = payload.split('~');
      if (parts.length < 5) continue;

      final isUs = line.contains('us');
      final ticker = parts[2];
      final price = double.tryParse(parts[3]) ?? 0.0;
      final changePercent = double.tryParse(parts[5]) ?? 0.0;
      final timeStr = parts.length > 30 ? parts[30] : "";

      String sessionType = "Regular";
      if (!isUs) {
        if (timeStr.length >= 4) {
          final hhmm = int.tryParse(timeStr.substring(0, 4)) ?? 0;
          if (hhmm >= 900 && hhmm < 930) {
            sessionType = "HK Pre-Auction";
          } else if (hhmm >= 1600 && hhmm <= 1610) {
            sessionType = "HK Close-Auction";
          }
        }
      } else {
        final nowUtc = DateTime.now().toUtc();
        final estHour = (nowUtc.hour - 4) % 24;
        if (estHour >= 4 && estHour < 9 || (estHour == 9 && nowUtc.minute < 30)) {
          sessionType = "US Pre-Market";
        } else if (estHour >= 16 && estHour < 20) {
          sessionType = "US After-Hours";
        }
      }

      newQuotes[ticker] = WatchlistQuote(
        ticker: ticker,
        name: parts[1],
        market: isUs ? "US" : "HK",
        price: price,
        changePercent: changePercent,
        sessionType: sessionType,
        time: timeStr.length >= 6 ? "${timeStr.substring(0, 2)}:${timeStr.substring(2, 4)}:${timeStr.substring(4, 6)}" : "--:--",
      );
    }

    if (mounted) {
      setState(() => liveQuotes = newQuotes);
    }
  }

  void _showAddStockDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF161B22),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Настройка Избранного", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text("Выберите акции HKEX и US для отслеживания:", style: TextStyle(color: Colors.white54, fontSize: 12)),
                  const Divider(color: Colors.white10, height: 20),
                  Expanded(
                    child: ListView.builder(
                      itemCount: widget.allDirectory.length,
                      itemBuilder: (context, index) {
                        final item = widget.allDirectory[index];
                        final isFav = widget.favorites.any((s) => s.ticker == item.ticker);
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text("${item.ticker} • ${item.name}", style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item.market == "HK" ? "Гонконг (HKEX + SGX DLC)" : "США (NASDAQ/NYSE)", style: const TextStyle(fontSize: 12, color: Colors.white38)),
                          trailing: IconButton(
                            icon: Icon(isFav ? Icons.check_circle : Icons.add_circle_outline, color: isFav ? Colors.cyanAccent : Colors.white30),
                            onPressed: () {
                              widget.onToggleFavorite(item);
                              setModalState(() {});
                              setState(() {});
                              _fetchWatchlistData();
                            },
                          ),
                        );
                      },
                    ),
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Избранное (Watchlist)", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF161B22),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.playlist_add, color: Colors.cyanAccent),
            tooltip: "Добавить тикеры",
            onPressed: _showAddStockDialog,
          )
        ],
      ),
      body: widget.favorites.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star_border, size: 48, color: Colors.white24),
                  const SizedBox(height: 12),
                  const Text("Список избранного пуст", style: TextStyle(color: Colors.white54)),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: _showAddStockDialog,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.cyanAccent, foregroundColor: Colors.black),
                    child: const Text("Выбрать акции"),
                  )
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: widget.favorites.length,
              itemBuilder: (context, index) {
                final stock = widget.favorites[index];
                final cleanTicker = stock.ticker.replaceAll(".HK", "");
                final quote = liveQuotes[cleanTicker] ?? liveQuotes[stock.ticker];

                final hasData = quote != null && quote.price > 0;
                final color = (quote?.changePercent ?? 0) >= 0 ? const Color(0xFF00E676) : const Color(0xFFFF5252);

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF161B22),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(stock.ticker, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 8),
                              _buildMarketBadge(stock.market),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(stock.name, style: const TextStyle(color: Colors.white54, fontSize: 12)),
                          const SizedBox(height: 6),
                          if (hasData) _buildSessionTag(quote.sessionType),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            hasData ? "${stock.market == 'HK' ? 'HK\$' : '\$'} ${quote.price.toStringAsFixed(2)}" : "Загрузка...",
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                          ),
                          const SizedBox(height: 4),
                          if (hasData)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                "${quote.changePercent >= 0 ? '+' : ''}${quote.changePercent.toStringAsFixed(2)}%",
                                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ),
                          const SizedBox(height: 4),
                          Text(hasData ? quote.time : "", style: const TextStyle(color: Colors.white24, fontSize: 10)),
                        ],
                      )
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildMarketBadge(String market) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: market == "HK" ? Colors.orange.withOpacity(0.2) : Colors.blue.withOpacity(0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        market,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: market == "HK" ? Colors.orangeAccent : Colors.lightBlueAccent,
        ),
      ),
    );
  }

  Widget _buildSessionTag(String sessionType) {
    Color tagColor = Colors.white24;
    if (sessionType.contains("Auction")) tagColor = Colors.amberAccent;
    if (sessionType.contains("Pre-Market")) tagColor = Colors.purpleAccent;
    if (sessionType.contains("After-Hours")) tagColor = Colors.indigoAccent;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: tagColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: tagColor.withOpacity(0.5), width: 0.8),
      ),
      child: Text(
        sessionType.toUpperCase(),
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: tagColor),
      ),
    );
  }
}
