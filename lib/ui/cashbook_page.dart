import 'dart:convert';

import 'package:finance/Services/database_service.dart';
import 'package:finance/ui/login_page.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CashbookPage extends StatefulWidget {
  const CashbookPage({Key? key}) : super(key: key);

  @override
  State<CashbookPage> createState() => _CashbookPageState();
}

class _CashbookPageState extends State<CashbookPage> {
  final _auth = GetIt.instance<FirebaseAuth>();
  final _db = GetIt.instance<DatabaseService>();

  String selectedFilter = "All";

  bool _isSearching = false;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  String getFormattedDay(DateTime date) => DateFormat('EEEE').format(date);
  String getFormattedDateTime(DateTime date) =>
      DateFormat('dd-MM-yyyy  hh:mm a').format(date);

  int totalCashIn = 0;
  int totalCashOut = 0;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _applyFilter(DateTime date) {
    final now = DateTime.now();
    switch (selectedFilter) {
      case "Daily":
        return date.year == now.year &&
            date.month == now.month &&
            date.day == now.day;
      case "Weekly":
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return date.isAfter(startOfWeek.subtract(const Duration(days: 1))) &&
            date.isBefore(endOfWeek.add(const Duration(days: 1)));
      case "Yearly":
        return date.year == now.year;
      case "All":
      default:
        return true;
    }
  }

  Future<void> saveUser(LocalUser user) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> users = prefs.getStringList('users') ?? [];
    users.removeWhere((u) => LocalUser.fromJson(jsonDecode(u)).uid == user.uid);
    users.add(jsonEncode(user.toJson()));
    await prefs.setStringList('users', users);
  }

  Future<List<LocalUser>> getUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> users = prefs.getStringList('users') ?? [];
    return users.map((u) => LocalUser.fromJson(jsonDecode(u))).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      drawer: _buildDrawer(),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildFilterChips(),
          _buildTransactionHeader(),
          Expanded(child: _buildTransactionList()),
          _buildActionButtons(),
          _buildSummarySection(),
        ],
      ),
    );
  }

  Drawer _buildDrawer() {
    return Drawer(
      child: Column(
        children: [
          FutureBuilder<List<LocalUser>>(
            future: getUsers(),
            builder: (context, snapshot) {
              final users = snapshot.data ?? [];
              return Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Container(
                      color: Colors.blueGrey.shade900,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 12),
                          Text(
                            _auth.currentUser?.displayName ?? 'Username',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _auth.currentUser?.email ?? '+91 0000000000',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Divider(),
                    ...users.map((user) => ListTile(
                          leading: const Icon(Icons.account_circle),
                          title: Text(user.email ?? 'No Email'),
                          onTap: () async {
                            if (_auth.currentUser?.uid != user.uid) {
                              await _auth.signOut();

                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                    builder: (context) => const LoginPage()),
                              );
                            }
                          },
                        )),
                    ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Add Account'),
                      onTap: () {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                              builder: (context) => const LoginPage()),
                        );
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          SafeArea(
            child: ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () async {
                await _auth.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushReplacementNamed('/login');
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  AppBar _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.blue.shade900,
      title: _isSearching
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Search by amount or date',
                hintStyle: TextStyle(color: Colors.white70),
                border: InputBorder.none,
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim();
                });
              },
            )
          : const Text('Cash Book'),
      leading: _isSearching
          ? BackButton(
              onPressed: () {
                setState(() {
                  _isSearching = false;
                  _searchQuery = '';
                  _searchController.clear();
                });
              },
            )
          : Builder(
              builder: (ctx) => IconButton(
                icon: const Icon(Icons.menu),
                onPressed: () => Scaffold.of(ctx).openDrawer(),
              ),
            ),
      actions: [
        IconButton(
          onPressed: () {
            setState(() => _isSearching = !_isSearching);
            if (!_isSearching) _searchController.clear();
          },
          icon: Icon(_isSearching ? Icons.close : Icons.search),
        ),
        IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert)),
      ],
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: ["All", "Daily", "Weekly", "Yearly"]
            .map((filter) => ChoiceChip(
                  label: Text(filter),
                  selected: selectedFilter == filter,
                  onSelected: (_) {
                    setState(() => selectedFilter = filter);
                  },
                  selectedColor: Colors.blue.shade800,
                  backgroundColor: Colors.grey.shade300,
                  labelStyle: TextStyle(
                    color:
                        selectedFilter == filter ? Colors.white : Colors.black,
                  ),
                ))
            .toList(),
      ),
    );
  }

  Widget _buildTransactionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: const [
          Expanded(
              flex: 2,
              child: Text("Date",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          Expanded(
              child: Text("Cash In",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.green))),
          Expanded(
              child: Text("Cash Out",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red))),
        ],
      ),
    );
  }

  Widget _buildTransactionList() {
    return StreamBuilder<QuerySnapshot>(
      stream: _auth.currentUser != null
          ? _db.streamTransactions(_auth.currentUser!.uid)
          : const Stream.empty(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("No transactions found."));
        }

        final docs = snapshot.data!.docs;

        final filteredDocs = docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final dateString = data['enteredDate'] ?? '';
          final cashIn = (data['cashIn'] ?? 0).toString();
          final cashOut = (data['cashOut'] ?? 0).toString();
          final search = _searchQuery.toLowerCase();

          DateTime? dt;
          try {
            dt = DateFormat('dd-MM-yyyy').parse(dateString);
          } catch (_) {}

          final matchesSearch = _searchQuery.isEmpty ||
              dateString.contains(search) ||
              cashIn.contains(search) ||
              cashOut.contains(search);

          return dt != null && _applyFilter(dt) && matchesSearch;
        }).toList();

        totalCashIn = 0;
        totalCashOut = 0;

        for (var doc in filteredDocs) {
          final data = doc.data() as Map<String, dynamic>;
          totalCashIn += (data['cashIn'] ?? 0) as int;
          totalCashOut += (data['cashOut'] ?? 0) as int;
        }

        if (filteredDocs.isEmpty) {
          return const Center(child: Text("No matching transactions."));
        }

        return ListView.separated(
          padding: const EdgeInsets.all(12),
          itemCount: filteredDocs.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final data = filteredDocs[index].data() as Map<String, dynamic>;
            final cashIn = data['cashIn'] ?? 0;
            final cashOut = data['cashOut'] ?? 0;

            final dateStr = data['enteredDate'] ?? '';
            DateTime dt;
            try {
              dt = DateFormat('dd-MM-yyyy').parse(dateStr);
            } catch (_) {
              dt = DateTime.now();
            }

            return _buildTransactionRow(dt, cashIn, cashOut);
          },
        );
      },
    );
  }

  Widget _buildTransactionRow(DateTime dt, int inAmt, int outAmt) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(getFormattedDay(dt),
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(getFormattedDateTime(dt),
                    style:
                        TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Expanded(
            child: Text(inAmt.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.green, fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: Text(outAmt.toString(),
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(child: _buildCashInButton()),
          const SizedBox(width: 10),
          Expanded(child: _buildCashOutButton()),
        ],
      ),
    );
  }

  Widget _buildCashInButton() {
    return ElevatedButton(
      onPressed: () => _showTransactionDialog(isCashIn: true),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text("Cash In"),
    );
  }

  Widget _buildCashOutButton() {
    return ElevatedButton(
      onPressed: () => _showTransactionDialog(isCashIn: false),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: const Text("Cash Out"),
    );
  }

  Widget _buildSummarySection() {
    return Container(
      color: Colors.blue.shade800,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        children: [
          SummaryRow(
              label: "Total Cash In", color: Colors.white, amount: totalCashIn),
          const SizedBox(height: 4),
          SummaryRow(
              label: "Total Cash Out",
              color: Colors.white,
              amount: totalCashOut),
          const SizedBox(height: 4),
          SummaryRow(
              label: "Balance",
              color: Colors.white,
              amount: totalCashIn - totalCashOut),
        ],
      ),
    );
  }

  void _showTransactionDialog({required bool isCashIn}) {
    final dateCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isCashIn ? "Add Cash In" : "Add Cash Out"),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: dateCtrl,
              decoration: const InputDecoration(labelText: "Date"),
              onTap: () async {
                FocusScope.of(context).requestFocus(FocusNode());
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime(2100),
                );
                if (picked != null) {
                  dateCtrl.text = DateFormat('dd-MM-yyyy').format(picked);
                }
              },
            ),
            TextField(
              controller: amtCtrl,
              decoration:
                  InputDecoration(labelText: isCashIn ? "Cash In" : "Cash Out"),
              keyboardType: TextInputType.number,
            ),
            TextField(
              controller: descCtrl,
              decoration: const InputDecoration(labelText: "Description"),
            ),
          ]),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final user = _auth.currentUser;
              if (user == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Not signed in.")),
                );
                return;
              }

              final date = dateCtrl.text;
              final amt = int.tryParse(amtCtrl.text) ?? 0;
              final desc = descCtrl.text;

              try {
                await _db.createTransaction(
                  uid: user.uid,
                  date: date,
                  cashIn: isCashIn ? amt : 0,
                  cashOut: isCashIn ? 0 : amt,
                  description: desc,
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Saved successfully.")),
                );
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }
}

class SummaryRow extends StatelessWidget {
  final String label;
  final Color color;
  final int amount;

  const SummaryRow({
    required this.label,
    required this.color,
    required this.amount,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(
        child: Text(label,
            style: TextStyle(
                fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ),
      Text(amount.toString(),
          style: TextStyle(color: color, fontWeight: FontWeight.bold)),
    ]);
  }
}

class LocalUser {
  final String uid;
  final String? displayName;
  final String? email;

  LocalUser({required this.uid, this.displayName, this.email});

  Map<String, dynamic> toJson() => {
        'uid': uid,
        'displayName': displayName,
        'email': email,
      };

  factory LocalUser.fromJson(Map<String, dynamic> json) => LocalUser(
        uid: json['uid'],
        displayName: json['displayName'],
        email: json['email'],
      );
}
