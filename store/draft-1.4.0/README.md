# Store texts for 1.4.0 (draft)

Prepared texts for the release that ships snowboard and ski (#94). Not live: the files in
`store/ios/text` and `store/play/text` stay unchanged until that release, because `store.sdd`
allows snow words in the store texts only once the types ship. At release time copy them over
(Play: `play/*_short|full.txt`; iOS: `ios/*`) and delete this folder.
`play/*_whatsnew.txt` are the Play release notes, `ios/*_whatsnew.txt` the App Store version notes.
Limits checked: iOS name 25, subtitle ≤ 22, keywords ≤ 100, promo ≤ 147, description ≤ 2446;
Play short ≤ 73, full ≤ 2489.
