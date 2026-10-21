# Google Play: Antrag auf Produktionszugriff

Entwürfe für die Fragen im Antrag auf Produktionszugriff (Play Console →
Dashboard → *Produktionszugriff beantragen*). Grundlage sind
`docs/android-release.md` (Releases im geschlossenen Test), die GitHub-Issues
#66–#81 und die Git-Historie ab 2026-10-07.

**Vor dem Absenden:**

- Jede `[eckige Klammer]` durch echte Angaben ersetzen oder den Satz streichen.
  Was nicht stimmt, kommt nicht rein: keine erfundene Aktivität, kein
  erfundenes Feedback.
- Die Zeichenbegrenzung prüft das Formular selbst. Ist ein Text zu lang,
  zuerst die Aufzählungen kürzen, nicht die Fakten.
- Google prüft auf Englisch, nimmt aber auch Deutsch an. Pro Frage steht unten
  eine deutsche und eine englische Fassung. Im ganzen Antrag nur eine Sprache
  verwenden.
- Am Tag des Antrags in der Play Console prüfen, dass mindestens 12 Tester die
  letzten 14 Tage ohne Unterbrechung dabei waren.
- Die Abschnitte nacheinander speichern, bevor du sie verlässt.

## Offene Fakten, die nur du kennst

| Fakt | Wo nachsehen | Wert |
|---|---|---|
| Datum, an dem 12 Tester eingetragen waren (Start der 14 Tage) | Play Console → Geschlossener Test → Tester | [Datum] |
| Anzahl der eingetragenen Tester | ebenda | [Anzahl] |
| Datum des PrimeTestLab-Berichts Nº 8446 und getesteter Build | PDF | [Datum], 1.0.1+2 |
| Alle Punkte im PDF (M- und S-Nummern) und ob umgesetzt | PDF | siehe Tabelle unten |
| Anzahl und Art der eigenen echten Fahrten | Verlauf in der App | [z. B. 15 Fahrten, Longboard + Spaziergänge] |
| Ob 1.1.1+4 und 1.1.2+5 im Test veröffentlicht wurden | Play Console → Release-Übersicht | [ja/nein] |

### Punkte aus dem PrimeTestLab-Bericht

Die ersten vier Zeilen sind im Repo belegt. Weitere Punkte aus dem PDF bitte
ergänzen und ehrlich angeben, ob und warum sie umgesetzt wurden oder nicht.

| Punkt | Inhalt | Umsetzung |
|---|---|---|
| M-01 | „Fahrt verwerfen“ in der Zusammenfassung nach der Fahrt löschte ohne Rückfrage | Bestätigungsdialog, 1.1.0+3 (#73) |
| M-02 | Verlauf zeigte „Noch keine Fahrten“, wenn ein Filter nichts fand | eigene Meldung für leere Filterergebnisse, 1.1.0+3 (#74) |
| S-01 | Stopp über die Benachrichtigung speicherte ohne Rückmeldung | Hinweis „Fahrt gespeichert“ mit Sprung zur Fahrt, 1.1.0+3 (#75) |
| S-02 | Favorit nur über das Herz auf der Karte setzbar | Favoriten-Schalter im Bearbeiten-Dialog, 1.1.0+3 (#76) |
| [weitere] | [Inhalt] | [umgesetzt in … / nicht umgesetzt, weil …] |

### Eigene Funde aus echten Fahrten und Gerätetests

| Fund | Wie entdeckt | Behoben |
|---|---|---|
| Nach langem Stillstand oder in Gebäuden lief die Strecke nicht weiter, bis man pausierte und fortsetzte | Spaziergang mit gesperrtem Bildschirm, Pixel 7 | 1.0.1+2 (#70, #72) |
| Fahrt, die während des Countdowns im Hintergrund startete, bekam keinen Vordergrunddienst, sodass Android sie beenden konnte | Test der QA-Fixes, Pixel 7 / Android 16 | 1.1.0+3 (#77) |
| Statusleisten-Icons auf den dunklen Fahrt-Bildschirmen im hellen Design kaum sichtbar | Store-Screenshots | 1.1.1+4 (#66) |
| Countdown zeigte immer „GPS-Signal bereit“, ohne das Signal zu prüfen | eigene Fahrten (Start drinnen) | 1.1.1+4 (#69), 1.3.0+7 (#78 Punkt 2) |
| Akkuoptimierung mancher Hersteller kann die Aufzeichnung beenden | Gerätetests | Hinweis vor dem Countdown, 1.1.2+5 (#68) |
| Wiederholte Fahrten wurden mit der ganzen Fahrzeit verglichen, inklusive Anfahrt zur Strecke | eigene Wiederholungsfahrten | Vergleich nur der Zeit auf der Strecke, 1.2.0+6 (#79) |
| Wer das Handy schon eingesteckt hat, merkt nicht, wann die Aufzeichnung beginnt | eigene Fahrten | gesprochener Countdown 5…1 und Vibration, Countdown 10 s, 1.3.0+7 (#81) |

Noch offen: iOS-Flackern der GPS-Anzeige im Countdown (#78, nur Anzeige,
betrifft Android nicht), Store-Screenshot des Verlaufs neu aufnehmen (#80),
Impressum vor dem öffentlichen Start (#67).

---

## Über deinen geschlossenen Test

### 1. Wie hast du Tester gewonnen?

**DE:**
Ich habe die Tester über den bezahlten Testdienst PrimeTestLab gewonnen und
über eine E-Mail-Liste in den geschlossenen Test eingeladen. [Zusätzlich habe
ich … eingeladen. Nur angeben, wenn das passiert ist.] Außerdem habe ich die
App während des gesamten Tests selbst mit echten Fahrten auf meinem eigenen
Gerät getestet.

**EN:**
I recruited testers through the paid testing service PrimeTestLab and invited
them to the closed test via an email list. [I also invited … — only if this
happened.] In addition, I tested the app myself throughout the test with real
rides on my own device.

### 2. Wie einfach war es, Tester zu gewinnen?

Die Option wählen, die deiner Erfahrung entspricht. Da du für die Tester
bezahlt hast, passt eher **„Schwierig“**. Nicht die Antwort wählen, die
vermeintlich weniger auffällt.

### 3. Wie haben die Tester die App genutzt?

**DE:**
Vom [Startdatum] bis [Enddatum] waren [Anzahl] Tester im geschlossenen Test.
PrimeTestLab hat Version 1.0.1+2 auf einem Sharp AQUOS R8 (Android 13)
strukturiert getestet: Fahrt aufzeichnen und stoppen, Zusammenfassung nach der
Fahrt, Verlauf mit Filter und Suche, Favoriten, Stopp über die
Benachrichtigung. Die Ergebnisse kamen als schriftlicher Bericht. [Angaben zur
Aktivität der übrigen Tester aus der Play Console, nur wenn belegt.] Parallel
habe ich die App selbst bei echten Fahrten genutzt ([Anzahl] Fahrten,
[Longboard/Skateboard/Spaziergänge]) und auf einem Pixel 7 (Android 16) sowie
auf einem iPhone getestet, vor allem Hintergrundaufzeichnung bei gesperrtem
Bildschirm, lange Stopps und schwachen GPS-Empfang. [Lücke ehrlich nennen,
z. B.: Die meisten Tester haben die App nicht täglich auf echten Fahrten
genutzt. Das habe ich mit meinen eigenen Fahrten ausgeglichen.]

**EN:**
From [start date] to [end date], [number] testers were enrolled in the closed
test. PrimeTestLab ran a structured test of version 1.0.1+2 on a Sharp AQUOS R8
(Android 13): recording and stopping a ride, the post-ride summary, history
with filters and search, favorites, and stopping from the notification. The
results came as a written report. [Activity of the other testers from Play
Console — only if supported.] Alongside this I used the app myself on real
rides ([number] rides, [longboard/skateboard/walks]) and tested it on a Pixel 7
(Android 16) and an iPhone, focusing on background recording with the screen
locked, long stops and weak GPS reception. [State the gap honestly, e.g.: most
testers did not use the app daily on real rides; I covered this with my own
rides.]

### 4. Welches Feedback hast du bekommen?

**DE:**
Feedback kam über einen schriftlichen Testbericht von PrimeTestLab (PDF,
Nº 8446) mit Fehlern und Verbesserungsvorschlägen, über die Feedback-Adresse
in den Release-Notes [und …]. Gemeldet wurden unter anderem: Eine Fahrt wurde
in der Zusammenfassung ohne Rückfrage verworfen. Der Verlauf zeigte „Noch keine
Fahrten“, wenn ein Filter nichts fand. Ein Stopp über die Benachrichtigung
speicherte ohne Rückmeldung. Favoriten ließen sich in den Fahrtdetails nicht
setzen. [weitere Punkte aus dem PDF] Jeden Punkt habe ich auf meinem Gerät
nachgestellt, als GitHub-Issue erfasst und priorisiert. Bei meinen eigenen
Fahrten fielen mir weitere Probleme auf, vor allem bei der Aufzeichnung nach
langen Stopps und im Hintergrund. Die habe ich ebenfalls erfasst und direkt
behoben.

**EN:**
Feedback came through a written test report from PrimeTestLab (PDF, No. 8446)
listing bugs and suggestions, through the feedback address in the release
notes [and …]. Reported issues included: a ride was discarded from the
post-ride summary without confirmation; history showed "No rides yet" when a
filter had no matches; stopping from the notification saved without any
feedback; favorites could not be set from the ride details. [further items
from the PDF] I reproduced each item on my device, logged it as a GitHub issue
and prioritised it. My own real rides surfaced further problems, mainly with
recording after long stops and in the background. I logged and fixed those
right away as well.

---

## Über deine App

### 5. Wer ist die Zielgruppe?

**DE:**
Retrail ist für Leute, die mit Longboard, Skateboard, Mountainboard,
Inline-Skates, Rollschuhen oder Scooter unterwegs sind und ihre Fahrten
festhalten wollen. Sie sehen Strecke, Tempo und Distanz einer Fahrt, finden
frühere Fahrten wieder und können eine Lieblingsstrecke erneut fahren und mit
ihren bisherigen Zeiten vergleichen. Die App funktioniert auch für
Spaziergänge, Wanderungen und Radfahrten, ist aber auf Rollsport ausgerichtet,
für den die großen Fitness-Apps keine eigenen Aktivitäten haben.

**EN:**
Retrail is for people who ride longboards, skateboards, mountainboards, inline
skates, roller skates or scooters and want to keep a record of their rides. It
shows the route, speed and distance of each ride, keeps past rides easy to
find, and lets riders follow a favourite route again and compare it with
earlier runs. It also works for walks, hikes and bike rides, but it is built
for wheeled sports that the big fitness apps don't cover as their own
activities.

### 6. Wie bietet die App einen Mehrwert?

**DE:**
Retrail zeichnet Fahrten per GPS auch bei gesperrtem Bildschirm zuverlässig
auf, mit Benachrichtigung zum Pausieren und Stoppen. Fahrten bleiben nur auf
dem Gerät, ohne Konto und ohne Werbung. Nutzer können zum Beispiel eine
Fahrt mit einem 10-Sekunden-Countdown samt Ansage starten, das Handy
einstecken und nach der Fahrt Strecke, Distanz, Durchschnitts- und
Höchstgeschwindigkeit auf der Karte ansehen. Sie können den Verlauf nach
Aktivität, Zeitraum und Favoriten filtern oder eine frühere Strecke erneut
fahren, wobei die App den Weg auf der Karte zeigt und die neue Zeit mit den
bisherigen vergleicht.

**EN:**
Retrail records rides by GPS reliably even with the screen locked, with a
notification to pause and stop. Rides stay on the device, with no account and
no ads. For example, users can start a ride with a spoken 10-second
countdown, pocket the phone, and afterwards see the route, distance, average
and top speed on a map. They can filter their history by activity, period and
favourites, or ride an earlier route again, with the app showing the way on
the map and comparing the new time with previous runs.

### 7. Wie viele Installationen erwartest du im ersten Jahr?

Eine realistische Schätzung für eine Nischen-App ohne Werbebudget wählen,
etwa die Spanne bis 1.000 oder bis 10.000, je nachdem, wie du den Start
bewerben willst (Communitys, Social Media). Die Angabe ist eine Schätzung,
keine Zusage.

---

## Bereitschaft für die Produktion

### 8. Was hast du aufgrund der Tests geändert?

**DE:**
Alle vier Punkte aus dem PrimeTestLab-Bericht habe ich in Version 1.1.0+3
umgesetzt: eine Rückfrage vor dem Verwerfen einer Fahrt, eine eigene Meldung,
wenn ein Filter nichts findet, ein Hinweis „Fahrt gespeichert“ nach dem Stopp
über die Benachrichtigung und einen Favoriten-Schalter in den Fahrtdetails.
[Weitere umgesetzte Punkte. Nicht umgesetzte mit Begründung nennen.] Bei
eigenen Fahrten habe ich zusätzlich gefunden und behoben: Aufzeichnung, die
nach langem Stillstand hängen blieb (1.0.1+2), eine Fahrt, die beim Start im
Hintergrund beendet werden konnte (1.1.0+3), eine echte GPS-Anzeige im
Countdown statt einer festen Anzeige, einen Hinweis zur Akkuoptimierung, einen
fairen Zeitvergleich bei wiederholten Strecken und einen gesprochenen
Countdown (1.1.1 bis 1.3.0). Im Test habe ich [Anzahl] Updates veröffentlicht,
zuletzt 1.3.1+8. Jede Änderung habe ich mit automatischen Tests sowie auf
einem Pixel 7 und einem iPhone geprüft, Aufzeichnungsfixes zusätzlich mit
echten Fahrten.

**EN:**
I implemented all four items from the PrimeTestLab report in version 1.1.0+3:
a confirmation before discarding a ride, a separate message when a filter has
no matches, a "Ride saved" notice after stopping from the notification, and a
favourite toggle in the ride details. [Further items implemented; name the
ones not implemented and why.] From my own rides I additionally found and
fixed: recording that stalled after a long stop (1.0.1+2), a ride that Android
could stop when it started in the background (1.1.0+3), a live GPS status in
the countdown instead of a fixed label, a battery-optimisation hint, a fair
time comparison for repeated routes, and a spoken countdown (1.1.1 to 1.3.0).
I shipped [number] updates during the test, the latest being 1.3.1+8. I
checked every change with automated tests and on a Pixel 7 and an iPhone, and
the recording fixes also with real rides.

### 9. Wie hast du entschieden, dass die App bereit ist?

**DE:**
Ich habe die Bereitschaft anhand des PrimeTestLab-Berichts, meiner
GitHub-Issues, der automatischen Tests (jede Version erst bei bestandener
Testsuite und sauberer statischer Analyse) und eigener echter Fahrten mit der
aktuellen Version bewertet. Alle Fehler aus dem Bericht und alle bei eigenen
Fahrten gefundenen Aufzeichnungsfehler sind behoben. In den letzten
[Zeitraum] sind bei meinen Fahrten keine neuen Aufzeichnungsfehler
aufgetreten. Offen sind nur Punkte ohne Einfluss auf die Android-App: eine
mögliche Flacker-Anzeige im Countdown unter iOS und ein Store-Screenshot, den
ich vor dem Start neu aufnehme. Die Berechtigung habe ich am [Datum] in der
Play Console geprüft.

**EN:**
I assessed readiness using the PrimeTestLab report, my GitHub issues,
automated tests (every version shipped only with the test suite passing and a
clean static analysis), and my own real rides with the current version. All
bugs from the report and all recording bugs found on my own rides are fixed.
In the last [period], my rides showed no new recording problems. The only
open items don't affect the Android app: a possible flicker of the countdown's
GPS status on iOS, and a store screenshot I will retake before launch. I
checked eligibility in Play Console on [date].

### 10. Was hast du diesmal anders gemacht?

Nur bei einer erneuten Bewerbung nach einer Ablehnung. Beim ersten Antrag
überspringen.

---

## Schlusskontrolle

- [ ] Keine eckigen Klammern mehr im Text.
- [ ] Punkt 9 ist wahr: #80 (Screenshot) vor dem Antrag erledigt oder als offen
      genannt.
- [ ] Alle Punkte aus dem PDF in der Tabelle oben, jeweils umgesetzt oder mit
      Begründung.
- [ ] Testzeitraum und Testerzahl aus der Play Console übernommen, Berechtigung
      am Antragstag geprüft.
- [ ] Zielgruppe (5), Funktionen (6) und Änderungen (8) beschreiben dieselbe
      App wie der Store-Eintrag (`docs/play-store.md`).
