# In-Class 08 / Fall Festival Roster
Omar Lodin / Mobile App Development / Undergrad
Flutter 3.47.3 - Dart 3.13.3 - Android 36.1 
Setup/run commands:
- Open android studio and select emulation device. 
- Open project folder directory in VS code's terminal.
- Enter "flutter run" command
- Interact with app.

## Storage notes
- Schema and initialization:
SQLite stores records in 'MyDatabase.db'. The 'my_table' table has attributes _id as INT primary key, 'name' TEXT not null, and 'age' INT not null. Main method of main.dart waits for helper.init() to be called to open the database if already exists and creates the table on first use. 
- Input policy, IDs, CRUD source locations:
Names are trimmed and can not be empty, ages must be integers from 0 to 130. Invalid input displays error messages and prevents insertion. IDs are assigned by SQLite; IDs targeted by update and delete method rather than list position. CRUD operations are located in 'insert()', 'queryRowCount()', 'queryAllRows()', 'update()', and 'delete()'. 
- Memory example / preference example / SQLite example:
Names, ages, and record count are stored in SQLite and remain available after restarting the app. 
## Actual tests
| Test | Action/input | Expected | Observed IDs/ages/count | Pass/fail |
| --- | --- | --- | --- | --- |
| T1 |Refresh lab roster after confirming it has no rows |Count 0; Successful empty state message | No entries available | Pass |
| T2 |Add both River records | Count 2; distinct generated IDs A and B| Entry count is 2, IDs are distinct for each, A has age 21, B has age 34| Pass |
| T3 |Edit B to 99, then Cancel; verify no change. Edit B again and Save age 35. | Cancel leaves B at 34. Save returns 1; count 2; A stays 21, B becomes 35.| Age for B unchanged after cancellation, changes to 35 after save, A unchanged.| Pass|
| T4 |Stop the app process and relaunch the same installation without clearing data. | Same IDs, names, ages, and count; no reseeding.| Data unchanged after relaunch with same ages, count, names.| Pass |
| T5 |Cancel deletion of A, then confirm it; Refresh| Cancel leaves count 2; confirm returns 1; after Refresh only B remains, count 1. A second restart is not required.| Cancelling deletion of A keeps record intact; confirming deletion of A leaves only B, count is 1 before and after refresh| Pass |
| T6 | List every invalid/boundary input | Each invalid attempt shows feedback and leaves count 1/B unchanged. Acorn and Oak are accepted with distinct IDs; final count 3. These use five rejected attempts and two accepted inserts.| Invalid inputs for "Maple" with ages "abc", 1.5, -1, 131 not added, ID 3 added with name = Acorn and age = 0, ID 4 added with name = Oak and age = 130; count is 3| Pass |
T4 stop/relaunch method:
Evidence: evidence/T4_before.png, evidence/T4_after.png,
          evidence/T6_invalid.png, evidence/analysis_output.txt
Analyzer command/result; known limitations:
Analyzing inc08...                                              
No issues found! (ran in 1.1s)


## Short reflections
1. Before performing the force stop and relaunch of the app, I think that the data previously entered will persist through force stopping the app, resulting in all of the records being kept. Essentially, the 2 entries that follow the schema "ID, Name, Age" containing "1, River, 21" and "2, River, 35" will be displayed exactly as they were prior. I think this is due to SQLite storing the records on disk rather than in memory. As specified in the instructions, I closed the flutter debug session in VS code while the emulator was still running, then opened the settings app on the emulated android device, opened the Apps tab, and selected my app named "inc08" where I was able to tap on the force stop button. After that I opened the apps list on the emulated device and launched "inc08" and saw that the data from before was still present. Screenshots in README also display before and after results being identical. If something could disprove that SQLite restored the data, I would assume that if an entry made into the app doesn't reappear when relaunching the app, that could disprove the claim if we consider a query that displays different data than what was there prior to relaunch. 

2. Given the results of T2-T3, we can see that two entries with ID 1 and 2 both have the name "River" but with different ages: 21 and 34. With this example, the name by itself isn't reliable as we can display multiple records that contain the same name in a situation where we only want one record. The app uses ID to save records in order to make the data more reliable. In the .dart file, we have a _save method that saving records. When there is a new record being made, there is a condition that checks if the current ID is null, shown by selectedId == null. If so the entry is given a new ID instead of replacing an existing entry, shown by "result = await widget.helper.insert().". What occurs in T3 is different however because it is not a new record being given a new ID. Since the _save method takes into account the current ID, it will update the record for the specified ID by calling "widget.helper.update()". Selecting by list position after a sort may cause a guest to receive an unintended update. For instance, If this list containing both of these entries was sorted by age descending, the list would have ID = 2, Name = River, Age = 35 in the 0 position, and the other River with ID = 1 in position 1 of the list. Updating using the stored position 0 would then change ID 2 River rather than ID 1 River. 

3. During the add and update process, I noticed that there is no indication to the user that there has been an update besides a new record box being added to the list, the list count updating, or searching for the specific record that includes the updated name/age. Something that can be improved in this regard is briefly highlighting or flashing the added/updated record box in green so the user can easily see what record was affected. The trade off for this would be adding an extra state and logic to display the visual effect to the user. While performing T6, the input validation message appears when trying to add the name "Maple" with age "abc" along with "1.5", "-1", and "131". After clicking the refresh button or by relaunching the app, the count retains the valid entries already added to the list, so we know that the invalid entries that were attempted during T6 did not save. 

## Attribution
Starter source / references / AI assistance used: