# In-Class 09 / Local Storage Part 2
Omar Lodin / Mobile App Development / Undergrad
Flutter 3.47.3 - Dart 3.13.3 - Android 36.1 
Setup/run commands:
- Open android studio and select emulation device. 
- Download and run APK on emulator
- Interact with app.


## Actual tests
| Test | Action/input | Expected | Observed IDs/ages/count | Pass/fail |
| --- | --- | --- | --- | --- |
| T1 |T1a: open the existing version-1 install with the new helper. T1b: launch version 2 on a separate disposable fresh target. | T1a retains all original IDs/values and creates the new tables/index. T1b creates both the original and catalogue tables; an empty folder can be opened without a schema error. Record both results and targets. | Pass |
| T2 |On the upgraded target, create “Atlas” and “Harbor.” Add two cards titled “Compass” in Atlas and one card titled “Signal” in Harbor. Choose valid suits; leave Signal's image_ref null.| Three distinct card IDs; Atlas count 2, Harbor count 1; each card appears only under its folder. Record actual folder/card IDs.| | Pass |
| T3 | Edit only one Compass by ID to “Compass revised” with notes, and Save. Edit the other Compass, then Cancel. | Save returns 1 affected row; only the selected card changes. Cancel writes nothing; folder counts remain 2 and 1. | | Pass |
| T4 | Capture the card IDs/counts, force-stop the app without clearing data, and relaunch. | Same folders, IDs, cards, values, and counts appear; no duplicate seed records. | | Pass |
| T5 | Cancel deleting one Atlas card, then confirm that card deletion. Cancel deleting Atlas, then confirm the folder deletion. | Each Cancel changes nothing. Card delete returns 1; Atlas count becomes 1. Folder delete returns 1 parent row, removes the remaining Atlas card, and leaves Harbor/Signal intact. Confirm no card still references Atlas's ID. | | Pass |
| T6 | Open Signal with null image_ref. Try an Add with a whitespace-only title, a blank folder name, then duplicate folder name “Harbor,” separately.| Suit fallback displays for Signal. All invalid attempts give visible feedback and leave rows/counts unchanged. A forced read failure or network fault is not required.| | Pass |
T4 stop/relaunch method:
Evidence: listed screenshots in \evidence
Analyzer command/result; known limitations:
Analyzing inc08...                                              
No issues found! (ran in 1.5s)


