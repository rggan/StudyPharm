import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert'; // for json decoding
import 'package:flutter/services.dart';
import 'package:studypharm/firebase_options.dart'; // import for rootBundle

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(NavigatorApp());

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

final db = FirebaseFirestore.instance;

class NavigatorApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue)),
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
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('StudyPharm'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: () {
              addDrugData();
              fetchDrugList(context); // Pass the context to fetchDrugList
            },
            child: const Text('Fetch Data'),
          ),
        ),
      ),
    );
  }

  void addDrugData() async {
    final drugsCollection = db.collection("drugs");

    try {
      QuerySnapshot querySnapshot = await drugsCollection.get();
      int drugCount = querySnapshot.size;
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
          drugsCollection.add(drugData);
        });
        print('Data added success');
      } else {
        print('Collection not empty');
      }
    } catch (e) {
      print("Error loading JSON file: $e");
    }
  }

  void fetchDrugList(BuildContext context) {
    db.collection('drugs').get().then(
      (querySnapshot) {
        print("Successfully completed");
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
        title: const Text('Drug List'),
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
                  return ListTile(
                    title: Text(
                      drug.brandName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onTap: () {
                      navigateToDrugDetails(context, drug);
                    },
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


class _DrugDetailsPageState extends State<DrugDetailsPage>{
  late TextEditingController notesController;

  @override
  void initState() {
    super.initState();
    // Check if there are existing notes
    if (widget.drug.notes != null && widget.drug.notes!.isNotEmpty) {
      // If there are existing notes, set them
      notesController = TextEditingController(text: widget.drug.notes);
    } 
    else {
      // If no existing notes, set the default text
      notesController = TextEditingController(text: '');
    }
  }

  @override
    Widget build(BuildContext context) {
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
                    style: const TextStyle(
                      fontSize: 16.0,
                      color: Colors.black, // Set your desired text color
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
                    style: const TextStyle(
                      fontSize: 16.0,
                      color: Colors.black, // Set your desired text color
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
                    style: const TextStyle(
                      fontSize: 16.0,
                      color: Colors.black, // Set your desired text color
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
                    style: const TextStyle(
                      fontSize: 16.0,
                      color: Colors.black, // Set your desired text color
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
              const Center(child: Text(
                'Notes',
                style: TextStyle(
                  decoration: TextDecoration.underline,
                  fontSize: 18.0,
                  fontWeight: FontWeight.bold,
                ),
              ),),
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

  // helper function to 
  String getScheduleText(String? schedule) {
    return schedule != null && schedule.isNotEmpty ? schedule : 'N/A';
  } 

  void saveNotes() async {
    try {
      await db.collection('drugs').doc(widget.drug.id).update({
        'notes': notesController.text,
      });

      // Update the local state with the new notes
      setState(() {
        widget.drug.notes = notesController.text;
      });

      // Show a confirmation message
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
