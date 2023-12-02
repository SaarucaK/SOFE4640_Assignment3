import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mask_text_input_formatter/mask_text_input_formatter.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

//text input controller: access input in onChange functions across components
TextEditingController controllerDate = TextEditingController();
TextEditingController controllerSearchDate = TextEditingController();
TextEditingController controllerOldDate = TextEditingController();
TextEditingController controllerOldCal = TextEditingController();
TextEditingController controllerOldItems = TextEditingController();
TextEditingController controllerNewCal = TextEditingController();
TextEditingController controllerNewItems = TextEditingController();
TextEditingController controllerNewDate = TextEditingController();

//lists to store db values
List<String> items = [];
List<int> calories = [];
List<String> mealPlan = [];
List<String> dates = [];
List<String> totalMealPlanCals = [];

//calories tracking
var totalCal=0;
var targetCal=0;

//run app
void main() {
  runApp(const MyApp());
}

//open application
class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      home: const MyHomePage(title: 'Calorie Calculator'),
    );
  }
}

//create Calorie Calculator Screen for Stateful Widgets
class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

//Calorie Calculator - main page class
class _MyHomePageState extends State<MyHomePage> {
  List<bool> isChecked = List<bool>.filled(20, false); //store state of each check box
  String selectedMealPlan=''; //store food items
  bool exceedMaxCal = false; //compare targetCal and totalCal
  DatabaseHelper db = DatabaseHelper();

  //clear input in all input fields
  void clearCalculator() {
    controllerDate.clear();
    totalCal=0;
    targetCal=0;
  }

  //stateful widgets
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //top app bar, display Calorie Calculator
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text(widget.title),
      ),
      //contain all widgets, sets general layout margins
      body: Container(
        margin: EdgeInsets.all(20.0),
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            //label: Target Calorie Input
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Total Calories Per Day',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
            //User Input: Target Calories
            TextField(
              decoration: new InputDecoration(labelText: "Enter Calories"),
              //numbers only
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  targetCal = int.tryParse(value) ?? 0; //store value when changed
                });
              },
              //enforce 4 digit
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(4),
              ],
            ),
            //label: Date
            Align(
              alignment: Alignment.centerLeft,
              child:Text(
                '\nDate',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
            //Input: Date
            TextFormField(
              controller: controllerDate, //retrieve date, user in other widgets
              decoration: new InputDecoration(
                  labelText: "MM/DD/YYYY" //format
              ),
              inputFormatters: [
                MaskTextInputFormatter(
                  mask: "##/##/####", //only numbers
                  filter: {
                    "#": RegExp(r'\d+|-|/'),//stop unwanted input values
                  },
                )
              ]
            ),
            //Display Calories Calculated from selected checkbox items
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '\nCalculated Calories: ${totalCal}',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
            //View All Items and Calories from table
            Expanded(
              //adjust size and make scrollable
              child: ListView.separated(
                shrinkWrap: true,
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 10, left: 10, right: 10),
                //generate Tiles for each check box item
                itemCount: items.length,
                itemBuilder: (BuildContext context, int index) {
                  return CheckboxListTile(
                    title: Text("${items[index]}"), //item name
                    subtitle: Text("${calories[index]} calories"), //calories for item
                    value: isChecked[index],
                    //every time item is checked or unchecked
                    onChanged: (bool? value) {
                      setState(() {
                        isChecked[index] = value!;
                        //item is checked = add calories to total and add item to meal plan
                        if (isChecked[index]==true){
                          totalCal=totalCal+calories[index];
                          selectedMealPlan += '${items[index]}, ';
                        }
                        //item is unchecked = subtract calories from total and remove from meal plan
                        else if(isChecked[index]==false){
                          totalCal=totalCal-calories[index];
                          selectedMealPlan = selectedMealPlan.replaceFirst('${items[index]}, ', '');
                        }
                      });
                    },
                  );
                },
                //tile formatting: provide dividers
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(
                    height: 20,
                    thickness: 5,
                    indent: 20,
                    endIndent: 0,
                    color: Colors.white,
                  );
                },
              ),
            ),
              //submit meal plan button
              ElevatedButton(
                child: Text('Submit'),
                onPressed: targetCal>totalCal?(){
                  //add to meals table
                  mealPlan.add(selectedMealPlan);
                  dates.add(controllerDate.text);
                  totalMealPlanCals.add(totalCal.toString());
                  db.addMeal(controllerDate.text, totalCal, selectedMealPlan);
                  //clear input fields
                  clearCalculator();
                    //navigate to View Meal Plans Screen
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                MealPlanViewer()));
                }:null //button disabled if total exceeds target

              ),
          ],
        ),
      ),
      ),
    );
  }
}

//View All Meal Plans screen
class MealPlanViewer extends StatefulWidget {
  @override
  _State createState() => _State();
}
class _State extends State<MealPlanViewer> {
  //lists to store meals from meal plan table to display in screen
  List<String> searchMealPlan = [];
  List<String> searchDates = [];
  List<String> searchTotalMealPlanCals = [];
  String combinedText=''; //combine lists at columns to format display
  DatabaseHelper db = DatabaseHelper();

  //compresses strings at columns
  String combineLists(List<String> list1, List<String> list2, List<String> list3) {
    List<RowItems> rows = [];
    for (int i = 0; i < list1.length; i++) {
      rows.add(RowItems(list1[i], list2[i], list3[i]));
    }
    return rows.map((row) => 'Date: ${row.column1}\t\t Meal: ${row.column2}\t\t Calories: ${row.column3}').join('\n');
  }

  //stateful widgets
  @override
  Widget build(BuildContext context) {
   return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text('View Your Meal Plans'),
      ),

      body: Container(
        margin: EdgeInsets.all(20.0),
        child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            //label: Date Search Option
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  'Search Date',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),

            ),
            //Input: Date Request
            TextFormField(
              controller: controllerSearchDate,
              decoration: new InputDecoration(
                hintText: 'MM/DD/YYYY', //input format
                hintStyle: TextStyle(fontSize: 18),
              ),
              //as input date typed/changed, search Meals for matching date
              onChanged: (value) {
                searchTotalMealPlanCals = [];
                searchMealPlan=[];
                searchDates=[];
                combinedText='';
                setState(() {
                  //retrieve all indexes of instances of dates found
                  List<int> searchDatesLoc = dates
                      .asMap()
                      .entries
                      .where((entry) => entry.value==controllerSearchDate.text)
                      .map((entry) => entry.key)
                      .toList();
                  // when date found retrieve entry from meals table
                  searchDatesLoc.forEach((int eachLoc) {
                    searchDates.add(dates[eachLoc]);
                    searchMealPlan.add(mealPlan[eachLoc]);
                    searchTotalMealPlanCals.add(totalMealPlanCals[eachLoc]);
                    //format database entry to string, will be used to display on screen
                    combinedText = combineLists(searchDates, searchMealPlan, searchTotalMealPlanCals);
                  });
                });
              },
            ),
            //display search result, shows formatted result
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  '\n'+combinedText,
                style: TextStyle(
                  fontSize: 16,
                ),
              ),
            ),
            //Label: List of All Views
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  '\nLIST OF ALL MEALS',
                style: TextStyle(
                  fontSize: 18,
                ),
              ),
            ),
            //retrieve all entries from meals tables
            Expanded(
              //create scrollable list view to display meals, format margins
              child: ListView.separated(
                shrinkWrap: true,
                physics: AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.only(top: 10, left: 10, right: 10),
                //create ListTile for each entry
                itemCount: dates.length,
                itemBuilder: (BuildContext context, int index) {
                  return ListTile(
                    leading: const Icon(Icons.restaurant_menu, size: 50), //show spoon+knife icon
                    title: Text("${dates[index]}: ${totalMealPlanCals[index]} total calories"), //display date and total calories
                    subtitle: Text("${mealPlan[index]}"), //display meal items
                  );
                },
                //divider for each listtile item
                separatorBuilder: (BuildContext context, int index) {
                  return Divider(
                    height: 20,
                    thickness: 5,
                    indent: 20,
                    endIndent: 0,
                    color: Colors.white,
                  );
                },
              ),
            ),
            Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    margin: EdgeInsets.all(24),
                    child:
                    //Back button
                    ElevatedButton(
                      child: Text('Back'),
                      //when pressed navigate back to Calorie Calculator screen
                      onPressed: (){
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    MyApp()));
                      },
                    ),
                  ),
                  Container(
                    margin: EdgeInsets.all(24),
                    child:
                    //Go to Updates Button
                    ElevatedButton(
                      child: Text('Go to Update'),
                      //when pressed navigate to Meal Plan Update Screen
                      onPressed: (){
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) =>
                                    UpdateMealPlan()));
                      },
                    ),
                  ),
                ],
            ),
          ],
        ),
      ),
      ),
   );
  }
}

//Update Meal Plan Screen Stateful
class UpdateMealPlan extends StatefulWidget {
  const UpdateMealPlan({ super.key });
  @override
  State<UpdateMealPlan> createState() => _UpdateMealPlan();
}

//Update Meal Plan Screen Application Widgets
class _UpdateMealPlan extends State<UpdateMealPlan> {
  DatabaseHelper db = DatabaseHelper();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      //display page title in appbar
      appBar: AppBar(
        backgroundColor: Colors.teal,
        title: Text('Update Your Meal Plans'),
      ),
      body: Container(
        margin: EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: <Widget>[
            //label: Update Meal Plan ie Old Information
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  '\nUPDATE MEAL-PLANS'
              ),
            ),
            //Text Input Old Date
            Padding(
              //format padding
              padding: EdgeInsets.all(5),
              child: TextField(
                controller: controllerOldDate,
                decoration: InputDecoration(
                  //hint prompts
                  labelText: 'Date',
                  hintText: 'Enter Date',
                  //format color
                  alignLabelWithHint: true,
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
            ),
            //Text Input Old Total Calories
            Padding(
              //format padding
              padding: EdgeInsets.all(5),
              child: TextField(
                controller: controllerOldCal,
                decoration: InputDecoration(
                  labelText: 'Total Calories',
                  hintText: 'Enter Calories',
                  //format color
                  alignLabelWithHint: true,
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
            ),
            //Text Input Old Items
            Padding(
              //format padding
              padding: EdgeInsets.all(5),
              child: TextField(
                controller: controllerOldItems,
                decoration: InputDecoration(
                  //hint prompt
                  labelText: 'Items',
                  hintText: 'Enter Items',
                  //format colors
                  alignLabelWithHint: true,
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
            ),
            //label: New or Delete Entry
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                  '\nNew'
              ),
            ),
            //Text Input New Date
             Padding(
              //format padding
              padding: EdgeInsets.all(5),
              child: TextField(
                controller: controllerNewDate,
                decoration: InputDecoration(
                  //hint prompt
                  labelText: 'Date',
                  hintText: 'Enter Date',
                  //fill color
                  alignLabelWithHint: true,
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
            ),
            //Text Input New Total Calories
            Padding(
              //format padding
              padding: EdgeInsets.all(5),
              child: TextField(
                controller: controllerNewCal,
                decoration: InputDecoration(
                  //hint prompt
                  labelText: 'Total Calories',
                  hintText: 'Enter Calories',
                  //format color
                  alignLabelWithHint: true,
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
            ),
            //Text Input New Items
            Padding(
              padding: EdgeInsets.all(5),
              child: TextField(
                controller: controllerNewItems,
                decoration: InputDecoration(
                  //hint prompt
                  labelText: 'Items',
                  hintText: 'Enter Items',
                  //format color
                  alignLabelWithHint: true,
                  fillColor: Colors.white,
                  filled: true,
                ),
              ),
            ),
            Row(
              children: <Widget>[
                //update button: replace old entry with new entry
                Container(
                  margin: EdgeInsets.all(15),
                  child:
                  ElevatedButton(
                    child: Text('Update'),
                    onPressed: (){
                      //update meals table with input
                      db.updateMeal(controllerDate.text, int.parse(controllerOldCal.text), controllerOldItems.text,
                          controllerNewDate.text, int.parse(controllerNewCal.text), controllerNewItems.text);
                      //go back to view meal plan page
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  MealPlanViewer()));
                    },
                  ),
                ),
                //add button: add new entry
                Container(
                  margin: EdgeInsets.all(15),
                  child:
                  ElevatedButton(
                    child: Text('Add'),
                    onPressed: (){
                      //add new entry to meals table
                      db.addMeal(controllerNewDate.text, int.parse(controllerNewCal.text), controllerNewItems.text);
                      //go back to view meal plan page
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  MealPlanViewer()));
                    },
                  ),
                ),
                //delete: delete an entry
                Container(
                  margin: EdgeInsets.all(15),
                  child:
                  ElevatedButton(
                    child: Text('Delete'),
                    onPressed: (){
                      //delete existing entry in meals table
                      db.deleteMeal(controllerNewDate.text, int.parse(controllerNewCal.text), controllerNewItems.text);
                      //go back to view meal plan page
                      Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) =>
                                  MealPlanViewer()));
                    },
                  ),
                ),
              ],
            ),
            //back button: go back to View Your Meal Plan screen
            ElevatedButton(
              child: Text('Go Back Home'),
              onPressed: (){
                Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) =>
                            MealPlanViewer()));
              },
            ),
          ],
        ),
      ),
    );
  }
}
//get string to list rows
class RowItems extends Equatable {
  final String column1;
  final String column2;
  final String column3;

  RowItems(this.column1, this.column2, this.column3);

  @override
  List<Object?> get props => [column1, column2, column3];
}

//sqflite database for items and meals tables
class DatabaseHelper {
  static Database? _database;

  //database setup
  Future<Database> get database async {
    if (_database != null) {
      return _database!;
    }
    //create database
    _database = await openDatabase(
      join(await getDatabasesPath(), 'caloriecalculator.db'),
      //create items table
      onCreate: (db, version) async {
        await db.execute(
          'CREATE TABLE items(id INTEGER PRIMARY KEY, item TEXT, calorie INTEGER)',
        );
        //populate items table
        await db.execute(
          "INSERT INTO items('id','item','calorie') values(?,?,?)",
          [1,'apple',59]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [2,'banana',151]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [3,'grapes',100]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [4,'orange',53]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [5,'pear',82]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [6,'broccoli',45]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [7,'carrot',50]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [8,'cucumber',17]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [9,'eggplant',35]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [10,'tomato',22]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [11,'beef',142]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [12,'chicken',136]
        );await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [13,'tofu',86]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [14,'egg',78]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [15,'fish',136]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [16,'bread',75]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [17,'butter',102]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [18,'potato',130]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [19,'rice',206]
        );
        await db.execute(
            "INSERT INTO items('id','item','calorie') values(?,?,?)",
            [20,'sandwich',200]
        );

        //create meals table
        await db.execute(
          'CREATE TABLE meals(id INTEGER PRIMARY KEY, date TEXT, totalCalories INTEGER, items TEXT)',
        );
      },
      version: 1,
    );
    return _database!;
  }

  //add to meals table given date, total calories and items
  Future<void> addMeal(String date, int totalCalories, String items) async {
    final Database db = await database; //db connection
    //add to table
    await db.rawInsert(
      'INSERT INTO meals(date, totalCalories, items) VALUES(?, ?, ?)',
      [date, totalCalories, items],
    );
  }

  //delete meal entry given date, total calories and items
  Future<void> deleteMeal(String date, int totalCalories, String items) async {
    final Database db = await database; //db connection
    //delete from table
    await db.rawDelete(
      'DELETE FROM meals WHERE date = ? AND totalCalories = ? AND items = ?',
      [date, totalCalories, items],
    );
  }

  Future<void> updateMeal(String oldDate, int oldTotalCalories, String oldItems,
      String newDate, int newTotalCalories, String newItems) async {
    final Database db = await database; //db connection

    // Update the meal in the database
    await db.rawUpdate(
      'UPDATE meals SET date = ?, totalCalories = ?, items = ? WHERE date = ? AND totalCalories = ? AND items = ?',
      [newDate, newTotalCalories, newItems, oldDate, oldTotalCalories, oldItems],
    );
  }

  //get meals table date column to list
  Future<List<String>> getMealDates() async {
    final Database db = await database; //db connections
    //query for column
    List<Map<String, dynamic>> result = await db.query('meals', columns: ['date']);
    return result.map<String>((item) => item['date'].toString()).toList();
  }

  //get meals table total calories column to list
  Future<List<int>> getMealTotalCalories() async {
    final Database db = await database;//db connection
    //query for column
    List<Map<String, dynamic>> result = await db.query('meals', columns: ['totalCalories']);
    return result.map<int>((item) => item['totalCalories'] as int).toList();
  }

  //get meals table items column to list
  Future<List<String>> getMealItems() async {
    final Database db = await database;//db connection
    //query for column
    List<Map<String, dynamic>> result = await db.query('meals', columns: ['items']);
    return result.map<String>((item) => item['items'].toString()).toList();
  }

  //get item table item column to list
  Future<List<String>> getItem() async {
    final Database db = await database; //db connection
    //query for column
    List<Map<String, dynamic>> result = await db.query('items', columns: ['item']);
    return result.map<String>((item) => item['items'].toString()).toList();
  }

  //get item table item column to list
  Future<List<String>> getCalorie() async {
    final Database db = await database; //db connection
    //query for column
    List<Map<String, dynamic>> result = await db.query('items', columns: ['calorie']);
    return result.map<String>((item) => item['calorie'].toString()).toList();
  }

}