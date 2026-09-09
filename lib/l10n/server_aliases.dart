// Compatibility with messages returned by backend builds before localization.
const serverMessageAliases = <String, String>{
  "Invalid email or password": "Email adresa ili lozinka nisu ispravne.",
  "Player account is inactive": "Korisnički nalog nije aktivan.",
  "Verification token is required": "Nedostaje kod za potvrdu email adrese.",
  "Verification token is invalid or expired":
      "Link za potvrdu email adrese je nevažeći ili je istekao.",
  "Player not found": "Igrač nije pronađen.",
  "Email is already verified": "Email adresa je već potvrđena.",
  "Verification email nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen.":
      "Email za potvrdu nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen.",
  "Verification email sent": "Email za potvrdu je poslat.",
  "Ako nalog postoji, poslali smo email za reset lozinke.":
      "Ako nalog postoji, poslali smo email za promjenu lozinke.",
  "Reset email nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen.":
      "Email za promjenu lozinke nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen.",
  "Reset link je nevažeći ili je istekao":
      "Link za promjenu lozinke je nevažeći ili je istekao.",
  "Password je promijenjen. Možeš se prijaviti.":
      "Lozinka je promijenjena. Možeš se prijaviti.",
  "Reset token is required": "Nedostaje kod za promjenu lozinke.",
  "Account deleted. Personal profile data has been removed and the account can no longer be used.":
      "Nalog je obrisan. Lični podaci su uklonjeni i nalog više nije moguće koristiti.",
  "Winner must be player1/team1 or player2/team2":
      "Pobjednik mora biti jedan od igrača ili timova u meču.",
  "Match players must be different": "Igrači u meču moraju biti različiti.",
  "All match players must exist": "Neki od izabranih igrača ne postoje.",
  "Tournament not found": "Turnir nije pronađen.",
  "All match players must be tournament participants":
      "Svi igrači u meču moraju biti učesnici turnira.",
  "Match date must be inside tournament dates":
      "Termin meča mora biti u okviru trajanja turnira.",
  "You can only act on your own matches":
      "Možete upravljati samo svojim mečevima.",
  "Match not found": "Meč nije pronađen.",
  "Doubles matches require four players":
      "Za dubl meč potrebna su četiri igrača.",
  "This player is not receiving match challenges right now":
      "Ovaj igrač trenutno ne prima izazove za meč.",
  "Only challenged player can accept this match":
      "Samo izazvani igrač može prihvatiti izazov.",
  "Only pending matches can be accepted":
      "Moguće je prihvatiti samo izazove koji čekaju odgovor.",
  "Only challenged player can reject this match":
      "Samo izazvani igrač može odbiti izazov.",
  "Only pending matches can be rejected":
      "Moguće je odbiti samo izazove koji čekaju odgovor.",
  "Result can only be submitted for accepted matches":
      "Rezultat je moguće unijeti samo za dogovorene mečeve.",
  "Only waiting confirmation matches can be confirmed":
      "Moguće je potvrditi samo rezultate koji čekaju potvrdu.",
  "Result submitter is missing":
      "Nedostaje podatak o igraču koji je unio rezultat.",
  "The same player cannot submit and confirm a result":
      "Isti igrač ne može unijeti i potvrditi rezultat.",
  "Only match participants can confirm result":
      "Rezultat mogu potvrditi samo učesnici meča.",
  "Only submitted results can be disputed":
      "Moguće je osporiti samo rezultate poslate na potvrdu.",
  "The result submitter cannot dispute their own submission":
      "Igrač ne može osporiti rezultat koji je sam unio.",
  "Ranking stats are already applied for this match":
      "Statistika ovog meča već je uračunata u rang-listu.",
  "Winner and sets are required to confirm a match":
      "Za potvrdu meča potrebno je unijeti pobjednika i rezultate setova.",
  "Confirmed match must have a winner": "Potvrđeni meč mora imati pobjednika.",
  "Rejected match cannot have a winner":
      "Odbijeni meč ne može imati pobjednika.",
  "Cannot change a match after ranking stats are applied":
      "Meč nije moguće mijenjati nakon obračuna statistike za rang-listu.",
  "Match gallery can contain up to 5 images":
      "Galerija meča može imati najviše 5 slika.",
  "Conversation not found": "Razgovor nije pronađen.",
  "You cannot start a conversation with yourself":
      "Ne možete započeti razgovor sa sobom.",
  "Only tournament admins can perform this action":
      "Ovu radnju mogu izvršiti samo administratori turnira.",
  "End date must be after start date":
      "Datum završetka mora biti poslije datuma početka.",
  "Zavrsnica se zavrsava potvrdom finala.":
      "Završnica se završava potvrdom rezultata finala.",
  "Format i disciplina se ne mijenjaju nakon pocetka lige. Zavrsnicu ukljucite posebno.":
      "Format i disciplina se ne mijenjaju nakon početka lige. Završnicu uključite posebno.",
  "Bodovanje se ne mijenja nakon pocetka lige sa zavrsnicom.":
      "Bodovanje se ne mijenja nakon početka lige sa završnicom.",
  "Zavrsnica je vec pokrenuta ili je turnir zavrsen.":
      "Završnica je već pokrenuta ili je turnir završen.",
  "Status i pobjednik zavrsnice odredjuju se potvrdjenim finalom.":
      "Status i pobjednik završnice određuju se potvrdom rezultata finala.",
  "Turnir je izmijenjen. Osvjezite pregled.":
      "Turnir je izmijenjen. Osvježite pregled.",
  "Only active players can register for tournaments":
      "Samo aktivni igrači mogu se prijaviti na turnir.",
  "Private tournaments are invite-only":
      "Za učešće na privatnom turniru potreban je poziv.",
  "Registration is allowed only for upcoming tournaments":
      "Prijava je moguća samo za turnire u najavi.",
  "Ucesnici lige se ne mijenjaju nakon formiranja meceva.":
      "Učesnici lige se ne mijenjaju nakon formiranja mečeva.",
  "Cannot remove participants after draw is generated":
      "Učesnike nije moguće ukloniti nakon formiranja žrijeba.",
  "Nakon pocetka lige admin se bira medju postojecim ucesnicima.":
      "Nakon početka lige administrator se bira među postojećim učesnicima.",
  "Pobjednik zavrsnice odredjuje se potvrdjenim finalom.":
      "Pobjednik završnice određuje se potvrdom rezultata finala.",
  "Only tournament participants or admins can add tournament images":
      "Slike turnira mogu dodavati samo učesnici i administratori.",
  "Tournament gallery can contain up to 5 images":
      "Galerija turnira može imati najviše 5 slika.",
  "Authorization token is required": "Potrebno je da se prijavite.",
  "Authenticated player no longer exists": "Korisnički nalog više ne postoji.",
  "Authentication required": "Potrebno je da se prijavite.",
  "You do not have permission to perform this action":
      "Nemate dozvolu za ovu radnju.",
  "Validation error": "Provjerite unesene podatke.",
  "Invalid id format": "Identifikator nije ispravan.",
  "Resource already exists": "Zapis već postoji.",
  "Internal server error": "Greška na serveru. Pokušajte ponovo.",
  "build must be a non-negative integer":
      "Broj izdanja mora biti cijeli broj veći ili jednak nuli.",
  "Lokacija nije pronadjena.": "Lokacija nije pronađena.",
  "Tournament draw already exists": "Žrijeb turnira je već formiran.",
  "At least two players are required to generate a draw":
      "Za formiranje žrijeba potrebna su najmanje dva igrača.",
  "No round is ready to advance":
      "Nijedna runda nije spremna za nastavak takmičenja.",
  "All current round matches must be confirmed before advancing":
      "Prije prelaska u narednu rundu potrebno je potvrditi sve mečeve tekuće runde.",
  "Final round cannot be advanced": "Poslije finala nema naredne runde.",
  "Google Maps pretraga nije podesena na serveru.":
      "Google Maps pretraga nije podešena na serveru.",
  "Previse Maps zahtjeva. Pokusajte za minut.":
      "Previše zahtjeva za Google Maps. Pokušajte za minut.",
  "Google Maps trenutno nije dostupan. Pokusajte ponovo.":
      "Google Maps trenutno nije dostupan. Pokušajte ponovo.",
  "Mjesto vise nije dostupno na Google Maps.":
      "Mjesto više nije dostupno na Google mapama.",
  "Google Maps kvota je potrosena. Pokusajte kasnije.":
      "Kvota za Google Maps je potrošena. Pokušajte kasnije.",
  "Google Maps zahtjev nije uspio. Provjerite Places API (New), kljuc i billing.":
      "Zahtjev za Google Maps nije uspio. Provjerite Places API (New), ključ i podešavanja naplate.",
  "Izabrana lokacija vise nije dostupna. Osvjezite listu.":
      "Izabrana lokacija više nije dostupna. Osvježite listu.",
  "Winner must be a participant in the tournament":
      "Pobjednik mora biti učesnik turnira.",
  "Pobjede; pobjede u medjusobnim mecevima igraca sa istim brojem pobjeda; razlika setova; razlika gemova; redosljed prijave.":
      "Pobjede; pobjede u međusobnim mečevima igrača sa istim brojem pobjeda; razlika setova; razlika gemova; redoslijed prijave.",
  "Potrebna su najmanje dva ucesnika.": "Potrebna su najmanje dva učesnika.",
  "Liga mora imati po jedan mec svakog para ucesnika.":
      "Liga mora imati po jedan meč svakog para učesnika.",
  "Svi ligaski mecevi moraju imati potvrdjen rezultat.":
      "Svi ligaški mečevi moraju imati potvrđen rezultat.",
  "Knockout zavrsnica je dostupna za round-robin singl turnire.":
      "Knockout završnica je dostupna za round-robin singl turnire.",
  "Turnir je zavrsen.": "Turnir je završen.",
  "Turnir vec ima odredjenog pobjednika.":
      "Turnir već ima određenog pobjednika.",
  "Knockout zavrsnica nije ukljucena.": "Knockout završnica nije uključena.",
  "Nema dovoljno ucesnika za izabranu zavrsnicu.":
      "Nema dovoljno učesnika za izabranu završnicu.",
  "Zavrsnica zahtijeva singl ligaske meceve.":
      "Završnica zahtijeva singl ligaške mečeve.",
  "Turnir vec ima meceve van ligaske faze.":
      "Turnir već ima mečeve van ligaške faze.",
  "Knockout parovi nijesu spremni.": "Knockout parovi nisu spremni.",
  "Tabela ili broj ucesnika su promijenjeni. Ponovo pregledajte parove.":
      "Tabela ili broj učesnika su promijenjeni. Ponovo pregledajte parove.",
  "Knockout zavrsnica nije pokrenuta.": "Knockout završnica nije pokrenuta.",
  "Runda je vec promijenjena. Osvjezite pregled.":
      "Runda je već promijenjena. Osvježite pregled.",
  "Svi mecevi ove runde moraju imati potvrdjen rezultat.":
      "Svi mečevi ove runde moraju imati potvrđen rezultat.",
  "Knockout meceve formira zavrsnica. Rucni unos je moguc samo za ligasku fazu prije zavrsnice.":
      "Knockout mečeve formira završnica. Ručni unos je moguć samo za ligašku fazu prije završnice.",
  "Ucesnici i faza ligaskog/knockout meca su zakljucani.":
      "Učesnici i faza ligaškog/knockout meča su zaključani.",
  "Potvrdjeni rezultati lige i zavrsnice su zakljucani.":
      "Potvrđeni rezultati lige i završnice su zaključani.",
  "Multipart boundary is missing": "Zahtjev za slanje slike nije ispravan.",
  "Only jpg, png and webp images are allowed":
      "Dozvoljene su samo slike u formatima JPG, PNG i WebP.",
};
