import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // for json decoding
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:studypharm/firebase_options.dart'; // import for rootBundle

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    ChangeNotifierProvider( // Provide ThemeNotifier to the widget tree
      create: (context) => ThemeNotifier(),
      child: NavigatorApp(),
    ),
  );
} 

class Drug {
  final String id;
  final String brandName;
  final String genericName;
  final String drugClass;
  final String? indication;
  final String? schedule;
  String? notes;    // makes it mutable

  Drug({
    required this.id,
    required this.brandName,
    required this.genericName,
    required this.drugClass,
    required this.indication,
    required this.schedule,
    this.notes,
  });
}

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  void setTheme(ThemeMode themeMode) {
    _themeMode = themeMode;
    notifyListeners();
  }
}

final db = FirebaseFirestore.instance;

class NavigatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: Colors.white,
        hintColor: Colors.blue,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: Colors.grey[900],
        hintColor: Colors.white,
      ),
      themeMode: Provider.of<ThemeNotifier>(context).themeMode,
      home: Navigator(
        onGenerateRoute: (settings) {
          return MaterialPageRoute(
            builder: (context) => const MyApp(),
          );
        },
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StudyPharm'),
      ),
      body: Center(
        child: Column(
          children:[
            IconButton(
              onPressed: () {
                // Toggle between light and dark modes
                ThemeMode currentMode = Theme.of(context).brightness == Brightness.light
                    ? ThemeMode.dark
                    : ThemeMode.light;
                Provider.of<ThemeNotifier>(context, listen: false).setTheme(currentMode);
              },
              icon: const Icon(Icons.lightbulb_outline),
            ),
            const Text('Toggle Theme'),
            ElevatedButton(
              onPressed: () {
                addDrugData(context);
              },
              child: const Text('Fetch Data'),
            ),
          ]
        )
      ),
    );
  }

  void addDrugData(BuildContext context) async {
    final drugsCollection = db.collection("drugs");

    try {
      QuerySnapshot querySnapshot = await drugsCollection.get();
      int drugCount = querySnapshot.size;
      print(drugCount); // error checking

      if (drugCount != 200){
        // Delete the entire collection
        await drugsCollection.get().then((snapshot) {
          for (DocumentSnapshot doc in snapshot.docs) {
            doc.reference.delete();
          }
          print('Collection deleted successfully');
        });
      }
      if (drugCount == 0) {
        final drugsString =
            await rootBundle.loadString('lib/top_200_drugs.json');
        final Map<String, dynamic> jsonData = json.decode(drugsString);
        final Map<String, dynamic> drugsData = jsonData['drugs'];

        drugsData.forEach((key, drug) {
          final Map<String, dynamic> drugData = {
            "brandName": drug['brandName'],
            "genericName": drug['genericName'],
            "drugClass": drug['drugClass'] ?? '',
            "indication": drug['indication'] ?? '',
            "schedule": drug['schedule'] ?? '',
            "notes": drug['notes'] ?? '',
          };
          final String brandName = drugData['brandName'];
          // to set brandName as document ID and set drug data to it
          drugsCollection.doc(brandName).set(drugData);
          print('Data added success');
        });
      }        
      print(drugCount); // error checking
      fetchDrugList(context);
    } catch (e) {
      print("Error loading JSON file: $e");
    }
  }

  void fetchDrugList(BuildContext context) {
    db.collection('drugs').get().then(
      (querySnapshot) {
        print("Fetching Drug List Successfully completed");
        List<Drug> drugsList = [];

        for (var docSnapshot in querySnapshot.docs) {
          Map<String, dynamic> data =
              docSnapshot.data();
          Drug drug = Drug(
            id: docSnapshot.id,
            brandName: data['brandName'] ,
            genericName: data['genericName'],
            drugClass: data['drugClass'],
            indication: data['indication'],
            schedule: data['schedule'],
            notes: data['notes'],
          );
          drugsList.add(drug);
        }

        // Display the list of drugs
        displayDrugList(drugsList, context); // Pass the context
      },
      onError: (e) => print("Error completing: $e"),
    );
  }

  void displayDrugList(List<Drug> drugsList, BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrugListPage(drugsList: drugsList),
      ),
    );
  }
}

class DrugListPage extends StatefulWidget {
  final List<Drug> drugsList;

  DrugListPage({required this.drugsList});

  @override
  DrugListPageState createState() => DrugListPageState();
}

class DrugListPageState extends State <DrugListPage> {
  final ScrollController _scrollController = ScrollController();  
  TextEditingController searchController = TextEditingController();
  List<Drug> filteredDrugs = [];

  @override
  void initState() {
    super.initState();
    filteredDrugs = widget.drugsList;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Drug List', 
          style: TextStyle(fontWeight: FontWeight.bold),
          ),

      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: searchController,
              onChanged: onSearchTextChanged,
              decoration: InputDecoration(
                labelText: 'Search Drug',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          // Drug List
          Expanded(
            child: Scrollbar(
              controller: _scrollController,
              trackVisibility: true,
              thumbVisibility: true,
              thickness: 20,
              radius: const Radius.circular(20),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: filteredDrugs.length,
                itemBuilder: (context, index) {
                  Drug drug = filteredDrugs[index];
                  return Container(
                    margin: const EdgeInsets.all(2.0),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: Colors.blue, 
                        width: 2.0),
                      borderRadius: BorderRadius.circular(8.0)
                      ),
                    child: ListTile(
                      title: Text(
                        drug.brandName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onTap: () {
                        navigateToDrugDetails(context, drug);
                      },
                    )
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void onSearchTextChanged(String query) {
    query = query.toLowerCase();
    setState(() {
      filteredDrugs = widget.drugsList
          .where((drug) =>
              drug.brandName.toLowerCase().contains(query) ||
              drug.genericName.toLowerCase().contains(query))
          .toList();
    });
  }

  void navigateToDrugDetails(BuildContext context, Drug drug) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DrugDetailsPage(drug: drug),
      ),
    );
  }
}

class DrugDetailsPage extends StatefulWidget {
  final Drug drug;

  DrugDetailsPage({required this.drug});
  
  @override
  _DrugDetailsPageState createState() => _DrugDetailsPageState();
}


class _DrugDetailsPageState extends State<DrugDetailsPage> {
  late TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    if (widget.drug.notes != null && widget.drug.notes!.isNotEmpty) {
      notesController = TextEditingController(text: widget.drug.notes);
    } else {
      notesController = TextEditingController(text: '');
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    Color textColor = isDarkMode ? Colors.white : Colors.black;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.drug.brandName,
          style: const TextStyle(
            fontSize: 30.0,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16.0,
                  color: textColor,
                ),
                children: <TextSpan>[
                  const TextSpan(
                    text: 'Generic Name: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: '${widget.drug.genericName}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16.0,
                  color: textColor,
                ),
                children: <TextSpan>[
                  const TextSpan(
                    text: 'Drug Class: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: '${widget.drug.drugClass}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16.0,
                  color: textColor,
                ),
                children: <TextSpan>[
                  const TextSpan(
                    text: 'Indication: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: '${widget.drug.indication}'),
                ],
              ),
            ),
            const SizedBox(height: 16),
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 16.0,
                  color: textColor,
                ),
                children: <TextSpan>[
                  const TextSpan(
                    text: 'Schedule: ',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  TextSpan(text: getScheduleText(widget.drug.schedule)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // NOTES SECTION
            const Center(
              child: Text(
                'Notes',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8.0),
            Container(
              padding: const EdgeInsets.all(10.0),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.blue,
                  width: 3.0,
                ),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: TextField(
                controller: notesController,
                decoration: const InputDecoration(
                  hintText: "Enter your notes here:",
                  // border: InputBorder.none,
                ),
              ),
            ),
            const SizedBox(height: 16.0),
            Center(
              child: ElevatedButton(
                onPressed: saveNotes,
                style: ElevatedButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 18.0),
                ),
                child: const Text('Save Notes'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String getScheduleText(String? schedule) {
    return schedule != null && schedule.isNotEmpty ? schedule : 'N/A';
  }

  void saveNotes() async {
    try {
      await db.collection('drugs').doc(widget.drug.id).update({
        'notes': notesController.text,
      });

      setState(() {
        widget.drug.notes = notesController.text;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Notes saved successfully'),
        ),
      );
    } catch (e) {
      print('Error saving notes: $e');
    }
  }
}
