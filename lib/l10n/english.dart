// MNE source text is the stable key. Keep user-entered data out of this catalog.
const englishMessages = <String, String>{
  "Posljednja aktivnost nije zabilježena": "Last activity not recorded",
  "Posljednja aktivnost: {p0}": "Last active: {p0}",
  "Nedostupan zbog neaktivnosti": "Unavailable due to inactivity",
  "Automatska nedostupnost": "Automatic unavailability",
  "Dani bez aktivnosti": "Days without activity",
  "Unesi cijeli broj od 1 do 365.": "Enter a whole number from 1 to 365.",
  "Podešavanja su sačuvana.": "Settings saved.",
  "Potrebno je da se prijavite.": "Authentication required.",
  "Korisnički nalog više ne postoji.": "Authenticated player no longer exists.",
  "Korisnički nalog nije aktivan.": "Player account is inactive.",
  "Nemate dozvolu za ovu radnju.":
      "You do not have permission to perform this action.",
  "Provjerite unesene podatke.": "Validation error.",
  "Identifikator nije ispravan.": "Invalid id format.",
  "Zapis već postoji.": "Resource already exists.",
  "Greška na serveru. Pokušajte ponovo.": "Internal server error.",
  "Igrač nije pronađen.": "Player not found.",
  "Turnir nije pronađen.": "Tournament not found.",
  "Meč nije pronađen.": "Match not found.",
  "Razgovor nije pronađen.": "Conversation not found.",
  "Ne možete započeti razgovor sa sobom.":
      "You cannot start a conversation with yourself.",
  "Email adresa ili lozinka nisu ispravne.": "Invalid email or password.",
  "Nedostaje kod za potvrdu email adrese.": "Verification token is required.",
  "Link za potvrdu email adrese je nevažeći ili je istekao.":
      "Verification token is invalid or expired.",
  "Email adresa je već potvrđena.": "Email is already verified.",
  "Email za potvrdu je poslat.": "Verification email sent.",
  "Nedostaje kod za promjenu lozinke.": "Reset token is required.",
  "Nalog je obrisan. Lični podaci su uklonjeni i nalog više nije moguće koristiti.":
      "Account deleted. Personal profile data has been removed and the account can no longer be used.",
  "Ovu radnju mogu izvršiti samo administratori turnira.":
      "Only tournament admins can perform this action.",
  "Datum završetka mora biti poslije datuma početka.":
      "End date must be after start date.",
  "Samo aktivni igrači mogu se prijaviti na turnir.":
      "Only active players can register for tournaments.",
  "Za učešće na privatnom turniru potreban je poziv.":
      "Private tournaments are invite-only.",
  "Prijava je moguća samo za turnire u najavi.":
      "Registration is allowed only for upcoming tournaments.",
  "Učesnike nije moguće ukloniti nakon formiranja žrijeba.":
      "Cannot remove participants after draw is generated.",
  "Igrači u meču moraju biti različiti.": "Match players must be different.",
  "Za dubl meč potrebna su četiri igrača.":
      "Doubles matches require four players.",
  "Svi igrači u meču moraju biti učesnici turnira.":
      "All match players must be tournament participants.",
  "Termin meča mora biti u okviru trajanja turnira.":
      "Match date must be inside tournament dates.",
  "Slike turnira mogu dodavati samo učesnici i administratori.":
      "Only tournament participants or admins can add tournament images.",
  "Galerija turnira može imati najviše 5 slika.":
      "Tournament gallery can contain up to 5 images.",
  "Pobjednik mora biti jedan od igrača ili timova u meču.":
      "Winner must be player1/team1 or player2/team2.",
  "Neki od izabranih igrača ne postoje.": "All match players must exist.",
  "Možete upravljati samo svojim mečevima.":
      "You can only act on your own matches.",
  "Ovaj igrač trenutno ne prima izazove za meč.":
      "This player is not receiving match challenges right now.",
  "Samo izazvani igrač može prihvatiti izazov.":
      "Only challenged player can accept this match.",
  "Moguće je prihvatiti samo izazove koji čekaju odgovor.":
      "Only pending matches can be accepted.",
  "Samo izazvani igrač može odbiti izazov.":
      "Only challenged player can reject this match.",
  "Moguće je odbiti samo izazove koji čekaju odgovor.":
      "Only pending matches can be rejected.",
  "Rezultat je moguće unijeti samo za dogovorene mečeve.":
      "Result can only be submitted for accepted matches.",
  "Moguće je potvrditi samo rezultate koji čekaju potvrdu.":
      "Only waiting confirmation matches can be confirmed.",
  "Nedostaje podatak o igraču koji je unio rezultat.":
      "Result submitter is missing.",
  "Isti igrač ne može unijeti i potvrditi rezultat.":
      "The same player cannot submit and confirm a result.",
  "Rezultat mogu potvrditi samo učesnici meča.":
      "Only match participants can confirm result.",
  "Moguće je osporiti samo rezultate poslate na potvrdu.":
      "Only submitted results can be disputed.",
  "Igrač ne može osporiti rezultat koji je sam unio.":
      "The result submitter cannot dispute their own submission.",
  "Statistika ovog meča već je uračunata u rang-listu.":
      "Ranking stats are already applied for this match.",
  "Za potvrdu meča potrebno je unijeti pobjednika i rezultate setova.":
      "Winner and sets are required to confirm a match.",
  "Potvrđeni meč mora imati pobjednika.": "Confirmed match must have a winner.",
  "Odbijeni meč ne može imati pobjednika.":
      "Rejected match cannot have a winner.",
  "Meč nije moguće mijenjati nakon obračuna statistike za rang-listu.":
      "Cannot change a match after ranking stats are applied.",
  "Galerija meča može imati najviše 5 slika.":
      "Match gallery can contain up to 5 images.",
  "Žrijeb turnira je već formiran.": "Tournament draw already exists.",
  "Za formiranje žrijeba potrebna su najmanje dva igrača.":
      "At least two players are required to generate a draw.",
  "Nijedna runda nije spremna za nastavak takmičenja.":
      "No round is ready to advance.",
  "Prije prelaska u narednu rundu potrebno je potvrditi sve mečeve tekuće runde.":
      "All current round matches must be confirmed before advancing.",
  "Poslije finala nema naredne runde.": "Final round cannot be advanced.",
  "Pobjednik mora biti učesnik turnira.":
      "Winner must be a participant in the tournament.",
  "Zahtjev za slanje slike nije ispravan.": "Multipart boundary is missing.",
  "Dozvoljene su samo slike u formatima JPG, PNG i WebP.":
      "Only jpg, png and webp images are allowed.",
  "Broj izdanja mora biti cijeli broj veći ili jednak nuli.":
      "build must be a non-negative integer.",
  "Potvrdi email prije prijave": "Verify your email before signing in.",
  "Potvrdi email prije korišćenja aplikacije":
      "Verify your email before using the app.",
  "Google Maps pretraga nije podešena na serveru.":
      "Google Maps search has not been configured on the server.",
  "Previše zahtjeva za Google Maps. Pokušajte za minut.":
      "Too many Google Maps requests. Try again in a minute.",
  "Google Maps trenutno nije dostupan. Pokušajte ponovo.":
      "Google Maps is currently unavailable. Please try again.",
  "Mjesto više nije dostupno na Google mapama.":
      "This place is no longer available on Google Maps.",
  "Kvota za Google Maps je potrošena. Pokušajte kasnije.":
      "The Google Maps quota has been reached. Try again later.",
  "Zahtjev za Google Maps nije uspio. Provjerite Places API (New), ključ i podešavanja naplate.":
      "Google Maps request failed. Check Places API (New), the API key and billing settings.",
  "Google Maps je vratio neispravan odgovor.":
      "Google Maps returned an invalid response.",
  "Izabrana lokacija više nije dostupna. Osvježite listu.":
      "The selected location is no longer available. Refresh the list.",
  "Izaberite barem jednu lokaciju.": "Select at least one location.",
  "Lokacija nije pronađena.": "Location not found.",
  "Knockout završnica je dostupna za round-robin singl turnire.":
      "Knockout playoffs are available for singles round-robin tournaments.",
  "Turnir je završen.": "The tournament has finished.",
  "Turnir već ima određenog pobjednika.":
      "The tournament already has a winner.",
  "Knockout završnica nije uključena.": "Knockout playoffs are not enabled.",
  "Nema dovoljno učesnika za izabranu završnicu.":
      "There are not enough participants for the selected playoffs.",
  "Završnica zahtijeva singl ligaške mečeve.":
      "Playoffs require singles league matches.",
  "Turnir već ima mečeve van ligaške faze.":
      "The tournament already has matches outside the league stage.",
  "Knockout parovi nisu spremni.": "Knockout pairings are not ready.",
  "Tabela ili broj učesnika su promijenjeni. Ponovo pregledajte parove.":
      "The standings or participant count have changed. Review the pairings again.",
  "Turnir je izmijenjen. Osvježite pregled.":
      "The tournament has changed. Refresh the preview.",
  "Knockout završnica nije pokrenuta.": "Knockout playoffs have not started.",
  "Runda je već promijenjena. Osvježite pregled.":
      "The round has already changed. Refresh the preview.",
  "Svi mečevi ove runde moraju imati potvrđen rezultat.":
      "All results in this round must be confirmed.",
  "Knockout mečeve formira završnica. Ručni unos je moguć samo za ligašku fazu prije završnice.":
      "Playoff matches are created automatically. Manual entry is only available during the league stage before playoffs.",
  "Učesnici i faza ligaškog/knockout meča su zaključani.":
      "The participants and stage of this league or knockout match are locked.",
  "Potvrđeni rezultati lige i završnice su zaključani.":
      "Confirmed league and playoff results are locked.",
  "Pobjede; pobjede u međusobnim mečevima igrača sa istim brojem pobjeda; razlika setova; razlika gemova; redoslijed prijave.":
      "Wins; head-to-head wins among players tied on wins; set difference; game difference; registration order.",
  "Potrebna su najmanje dva učesnika.":
      "At least two participants are required.",
  "Liga mora imati po jedan meč svakog para učesnika.":
      "Every pair of participants must have exactly one league match.",
  "Liga ima duplirane ili neispravne parove.":
      "The league has duplicate or invalid pairings.",
  "Svi ligaški mečevi moraju imati potvrđen rezultat.":
      "All league match results must be confirmed.",
  "Završnica se završava potvrdom rezultata finala.":
      "Confirm the final result to finish the playoffs.",
  "Format i disciplina se ne mijenjaju nakon početka lige. Završnicu uključite posebno.":
      "The format and discipline cannot change after the league starts. Enable playoffs separately.",
  "Bodovanje se ne mijenja nakon početka lige sa završnicom.":
      "Scoring cannot change after a league with playoffs has started.",
  "Završnica je već pokrenuta ili je turnir završen.":
      "The playoffs have started or the tournament has finished.",
  "Status i pobjednik završnice određuju se potvrdom rezultata finala.":
      "The playoff status and winner are set by confirming the final result.",
  "Učesnici lige se ne mijenjaju nakon formiranja mečeva.":
      "League participants cannot change after matches have been created.",
  "Nakon početka lige administrator se bira među postojećim učesnicima.":
      "After the league starts, administrators must be selected from existing participants.",
  "Pobjednik završnice određuje se potvrdom rezultata finala.":
      "The playoff winner is set by confirming the final result.",
  "Izaberite knockout rundu.": "Select a knockout round.",
  "Turnir nije round-robin.": "This is not a round-robin tournament.",
  "Identifikator za polje {p0} nije ispravan.":
      "The identifier for {p0} is invalid.",
  "Unos rezultata biće dostupan za {p0} min.":
      "Result entry will be available in {p0} min.",
  "Nedostaje slika u polju {p0}.": "An image is required in {p0}.",
  "Veličina slike mora biti manja od {p0} MB.":
      "The image must be smaller than {p0} MB.",
  "Nalog nije kreiran jer email za potvrdu nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen.":
      "The account was not created because the verification email could not be sent. Check RESEND_API_KEY, EMAIL_FROM and the verified domain.",
  "Email za potvrdu nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen.":
      "The verification email could not be sent. Check RESEND_API_KEY, EMAIL_FROM and the verified domain.",
  "Email za promjenu lozinke nije poslat. Provjeri RESEND_API_KEY, EMAIL_FROM i verifikovan domen.":
      "The password reset email could not be sent. Check RESEND_API_KEY, EMAIL_FROM and the verified domain.",
  "Link za promjenu lozinke je nevažeći ili je istekao.":
      "The password reset link is invalid or has expired.",
  "Lozinka je promijenjena. Možeš se prijaviti.":
      "Your password has been changed. You can sign in.",
  "Nova verzija aplikacije je obavezna. Ažuriraj COA The Matchmaker.":
      "A new version is required. Please update COA The Matchmaker.",
  "Jezik": "Language",
  "Jezik aplikacije": "App language",
  "Izbor jezika nije sačuvan. Pokušaj ponovo.":
      "Your language preference could not be saved. Please try again.",
  "Administrator": "Administrator",
  "Administrator turnira": "Tournament administrator",
  "Administratori turnira": "Tournament administrators",
  "Adresa / grad": "Address / city",
  "Ako nalog postoji, poslali smo email za promjenu lozinke.":
      "If the account exists, we sent an email to reset your password.",
  "Akrilna podloga": "Acrylic court",
  "Aktivan": "Active",
  "Aktivna lokacija": "Active location",
  "Avgust": "August",
  "Ažuriraj": "Update",
  "Ažuriraj aplikaciju": "Update app",
  "Beton": "Concrete",
  "Bez kluba": "No club",
  "Bez rezultata": "No result",
  "Bez turnira": "No tournament",
  "Brisanje naloga": "Delete account",
  "Broj učesnika spremnih za završnicu: {p0}.":
      "Players ready for the playoffs: {p0}.",
  "Broj učesnika u završnici": "Players in the playoffs",
  "Dan": "Day",
  "Datum i vrijeme": "Date and time",
  "Datum početka": "Start date",
  "Datum rođenja": "Date of birth",
  "Datum završetka": "End date",
  "Decembar": "December",
  "Detalji meča": "Match details",
  "Disciplina": "Discipline",
  "Disputed mečevi": "Disputed matches",
  "Dobro došao na svoj teniski profil.": "Welcome to your tennis profile.",
  "Dodaj administratora": "Add administrator",
  "Dodaj administratora turnira": "Add tournament administrator",
  "Dodaj igrača": "Add player",
  "Dodaj lokaciju": "Add location",
  "Dodaj set": "Add set",
  "Dodaj sliku turnira": "Add tournament photo",
  "Dogovoren": "Scheduled",
  "Dogovori meč, termin ili trening direktno sa igračima.":
      "Arrange a match, a time or a practice session with other players.",
  "Dostupan si za izazove i dogovore o terminu meča.":
      "You are available for challenges and match scheduling.",
  "Dostupan za meč": "Available to play",
  "Dostupna je nova verzija aplikacije.": "A new app version is available.",
  "Dostupna je nova verzija.": "A new version is available.",
  "Dostupni za meč": "Available to play",
  "Dostupnost za meč": "Match availability",
  "Dovrši formiranje mečeva": "Complete match creation",
  "Drugi igrači vide da trenutno ne želiš pozive za meč. Profil i nalog ostaju normalno aktivni.":
      "Other players will see that you are not accepting match invitations. Your profile and account remain active.",
  "Država": "Country",
  "Dubl": "Doubles",
  "Dvoranska tvrda": "Indoor hard court",
  "Dvostruka eliminacija": "Double elimination",
  "Eliminacija": "Elimination",
  "Eliminacioni žrijeb": "Elimination draw",
  "Email adresa": "Email address",
  "Februar": "February",
  "Filteri": "Filters",
  "Filteri igrača": "Player filters",
  "Format turnira": "Tournament format",
  "Formiraj narednu rundu": "Create next round",
  "Formiraj žrijeb": "Create draw",
  "Galerija": "Gallery",
  "Galerija ({p0}/5)": "Gallery ({p0}/5)",
  "Galerija može imati najviše 5 slika.":
      "The gallery can contain up to 5 photos.",
  "Godina": "Year",
  "Godište": "Year of birth",
  "Google Maps nije dostupan.": "Google Maps is unavailable.",
  "Grad": "City",
  "Grupe + knockout": "Groups + knockout",
  "Igrač": "Player",
  "Igrača": "Players",
  "Igrači": "Players",
  "Igrač ispada tek poslije dva poraza. Više mečeva, manje slučajnosti.":
      "Players are eliminated after two losses. More matches, less chance.",
  "Igrači nastavljaju i poslije poraza, dobro za rekreativne turnire.":
      "Players keep playing after a loss. Suitable for recreational tournaments.",
  "Ime": "First name",
  "Individualni igrač / klub": "Independent player / club",
  "Istorija lige, mečevi i turniri mogu ostati prikazani bez tvojih ličnih podataka kako bi rezultati drugih igrača ostali tačni.":
      "League history, matches and tournaments may remain without your personal details to preserve other players' results.",
  "Izaberi format žrijeba, podlogu i datume. Učesnike dodaješ na stranici turnira.":
      "Choose a draw format, surface and dates. Add participants on the tournament page.",
  "Izaberi igrača": "Select player",
  "Izaberi lokacije": "Select locations",
  "Izaberi lokaciju": "Select location",
  "Izaberi partnera": "Select partner",
  "Izaberi partnera protivnika": "Select opponent's partner",
  "Izaberi termin meča": "Select match time",
  "Izazov": "Challenge",
  "Izazov je poslat": "Challenge sent",
  "Izazovi igrača": "Challenge a player",
  "Izazovi na meč": "Challenge to a match",
  "Januar": "January",
  "Javni": "Public",
  "Javni turnir": "Public tournament",
  "Još nema dogovorenog termina.": "No match has been scheduled yet.",
  "Još nema igrača na rang-listi.": "No players on the ranking list yet.",
  "Još nema poruka.": "No messages yet.",
  "Još nema razgovora.": "No conversations yet.",
  "Još nema slika za ovaj meč.": "No photos for this match yet.",
  "Još nema slika za ovaj turnir.": "No photos for this tournament yet.",
  "Jul": "July",
  "Jun": "June",
  "Kako su izračunati poeni": "How points are calculated",
  "Kasnije": "Later",
  "Kategorija": "Category",
  "Klasičan eliminacioni žrijeb sa slobodnim prolazima kada je potrebno.":
      "A standard elimination draw with byes when needed.",
  "Klub": "Club",
  "Knockout": "Knockout",
  "Knockout završnica": "Knockout playoffs",
  "Knockout završnica: samo singl.": "Knockout playoffs: singles only.",
  "Ko smije da te zove na meč?": "Who can invite you to play?",
  "Kompas žrijeb": "Compass draw",
  "Korekcija": "Adjustment",
  "Koristiš najnoviju verziju.": "You are using the latest version.",
  "Kreator turnira": "Tournament creator",
  "Kreiraj turnir": "Create tournament",
  "Kvalifikacije": "Qualifying",
  "Liga": "League",
  "Liga danas": "League today",
  "Liga je u toku.": "The league is in progress.",
  "Lokacija": "Location",
  "Lokacija (opciono)": "Location (optional)",
  "Lokacije": "Locations",
  "Lokacije turnira": "Tournament locations",
  "Lozinka": "Password",
  "Maj": "May",
  "Mart": "March",
  "Mapu nije moguće otvoriti.": "Unable to open the map.",
  "Mapu nije moguće otvoriti. Pokušajte ponovo.":
      "Unable to open the map. Please try again.",
  "Meč nije aktivan": "Match is not active",
  "Meč prati tip izabranog turnira.":
      "The match follows the selected tournament type.",
  "Mečevi": "Matches",
  "Mečevi turnira": "Tournament matches",
  "Mečevi iz ovog turnira ne ulaze u statistiku i ne dodaju poene.":
      "Matches in this tournament do not count toward statistics or points.",
  "Mečevi ne ulaze u statistiku i ne dodaju poene.":
      "Matches do not count toward statistics or points.",
  "Mečevi {p0} · Setovi {p1}:{p2} · Gemovi {p3}:{p4}":
      "Played {p0} · Sets {p1}:{p2} · Games {p3}:{p4}",
  "Minut": "Minute",
  "Minute do unosa rezultata": "Minutes before result entry",
  "Mjesec": "Month",
  "Moj partner": "My partner",
  "Moj profil": "My profile",
  "Moja pozicija: {p0}.": "My rank: {p0}.",
  "Moji mečevi": "My matches",
  "Moji turniri": "My tournaments",
  "Najmanje 8 znakova": "At least 8 characters",
  "Najnovije": "Newest",
  "Najviše 100 znakova.": "Maximum 100 characters.",
  "Nalog je kreiran. Možeš se prijaviti.":
      "Account created. You can now sign in.",
  "Nalog je obrisan.": "Account deleted.",
  "Napiši poruku...": "Write a message...",
  "Napomena": "Note",
  "Napravi profil": "Create a profile",
  "Naziv meča": "Match name",
  "Naziv mjesta i grad": "Place name and city",
  "Naziv turnira": "Tournament name",
  "Naziv u aplikaciji": "Name in the app",
  "Ne ulazi u statistiku i ne dodaje poene.":
      "Does not count toward statistics or points.",
  "Neaktivan": "Inactive",
  "Neaktivna": "Inactive",
  "Neaktivna lokacija": "Inactive location",
  "Nedostupan": "Unavailable",
  "Neispravan broj verzije na serveru.":
      "The server returned an invalid build number.",
  "Nema dostupnih protivnika.": "No opponents available.",
  "Nema igrača za izabrane filtere.": "No players match these filters.",
  "Nema internet veze. Pokušaj ponovo.":
      "No internet connection. Please try again.",
  "Nema lokacija za ovaj izbor.": "No locations available for this selection.",
  "Nema mečeva za ovaj filter.": "No matches for this filter.",
  "Nema potvrđenih mečeva.": "No confirmed matches.",
  "Nema rezultata.": "No results.",
  "Nema rezultata. Pokušajte sa gradom ili adresom.":
      "No results. Try a city or an address.",
  "Nema sačuvanih lokacija.": "No saved locations.",
  "Nema spornih mečeva": "No disputed matches",
  "Nema takmičarskih pobjeda.": "No competitive wins.",
  "Nema takmičarskih poraza.": "No competitive losses.",
  "Nema takmičarskih titula.": "No competitive titles.",
  "Nije moguće pročitati verziju aplikacije.":
      "Unable to read the app version.",
  "Nije obavezno": "Optional",
  "Nova lokacija": "New location",
  "Nova poruka": "New message",
  "Novembar": "November",
  "Novi izazov": "New challenge",
  "Novi turnir": "New tournament",
  "Obavezno polje": "Required field",
  "Obriši nalog": "Delete account",
  "Obriši pretragu": "Clear search",
  "Odbij": "Reject",
  "Odbij rezultat": "Reject result",
  "Odbijen": "Rejected",
  "Odjavi se": "Sign out",
  "Odustani": "Cancel",
  "Oktobar": "October",
  "Ospori rezultat": "Dispute result",
  "Osvježi rezultate": "Refresh results",
  "Otkazan": "Cancelled",
  "Otvori u Google Maps": "Open in Google Maps",
  "Otvori {p0}": "Open {p0}",
  "Ova akcija uklanja lične podatke profila, email, profilnu sliku i onemogućava buduću prijavu na nalog.":
      "This removes your personal profile details, email address and profile photo, and prevents future sign-ins.",
  "Ovaj meč je prijateljski. Ne ulazi u statistiku i ne dodaje poene.":
      "This is a friendly match. It does not count toward statistics or points.",
  "Ovdje ulaze samo potvrđeni takmičarski mečevi. Prijateljski mečevi se ne računaju u statistiku.":
      "Only confirmed competitive matches are included. Friendly matches do not count toward statistics.",
  "Ovo mjesto sa Google mapa već je dodato u lokacije.":
      "This Google Maps place has already been added.",
  "Ovo nije status naloga. Nalog ostaje aktivan, a ovdje samo biraš da li želiš da te drugi igrači pozivaju na mečeve.":
      "Your account remains active. This setting only controls whether other players can invite you to matches.",
  "Parovi se određuju prema rezultatima. Dobro za mnogo igrača i ograničeno vrijeme.":
      "Pairings are based on results. Suitable for many players and limited time.",
  "Partner protivnika": "Opponent's partner",
  "Pobjede": "Wins",
  "Pobjede : porazi": "Wins : losses",
  "Pobjednici kvalifikacionih mečeva ulaze u glavni žrijeb.":
      "Winners of qualifying matches enter the main draw.",
  "Pobjednik": "Winner",
  "Pobjednik još nije postavljen.": "The winner has not been set yet.",
  "Pobjednik turnira": "Tournament winner",
  "Pobjednik: {p0}": "Winner: {p0}",
  "Podaci nisu učitani": "Unable to load data",
  "Podešavanja lige": "League settings",
  "Podešavanja nije moguće učitati.": "Unable to load settings.",
  "Podloga": "Surface",
  "Poeni": "Points",
  "Poeni za osvajanje turnira": "Points for winning a tournament",
  "Poeni za pobjedu": "Points for a win",
  "Pokreni knockout": "Start knockout",
  "Pokušaj opet": "Try again",
  "Pokušaj ponovo": "Try again",
  "Poništi": "Cancel",
  "Poništi meč": "Cancel match",
  "Porazi": "Losses",
  "Poruka": "Message",
  "Poruke": "Messages",
  "Poslali smo novi link za potvrdu naloga.":
      "We sent a new account verification link.",
  "Poslali smo ti email za potvrdu naloga. Otvori link, pa se prijavi.":
      "We sent you an account verification email. Open the link, then sign in.",
  "Potraži COA The Matchmaker i ažuriraj aplikaciju. Ako ažuriranje još nije prikazano, pokušaj ponovo kasnije.":
      "Search for COA The Matchmaker and update the app. If the update is not available yet, try again later.",
  "Potvrda": "Confirmation",
  "Potvrda rezultata": "Result confirmation",
  "Potvrdi": "Confirm",
  "Potvrdi izbor": "Confirm selection",
  "Potvrdi izbor ({p0})": "Confirm selection ({p0})",
  "Potvrdi knockout parove": "Confirm knockout pairings",
  "Potvrdi pobjednika": "Confirm winner",
  "Potvrdi rezultat": "Confirm result",
  "Povezano sa Google mapama": "Linked to Google Maps",
  "Početna": "Home",
  "Pošalji izazov": "Send challenge",
  "Pošalji izazov protivniku. Nakon prihvatanja izazova i odigranog meča, oba igrača potvrđuju rezultat.":
      "Send your opponent a challenge. After it is accepted and played, both players confirm the result.",
  "Pošalji link": "Send link",
  "Pošalji na potvrdu": "Submit for confirmation",
  "Pošalji opet": "Send again",
  "Pošalji poruku": "Send message",
  "Pravila poretka": "Ranking rules",
  "Pregledaj knockout parove": "Preview knockout pairings",
  "Prerano za unos rezultata. Preostalo oko {p0} min.":
      "Result entry is not available yet. About {p0} min remaining.",
  "Pretraži": "Search",
  "Pretraži igrača": "Search players",
  "Pretraži lokacije": "Search locations",
  "Prezime": "Last name",
  "Prihvati": "Accept",
  "Prijateljski": "Friendly",
  "Prijateljski meč": "Friendly match",
  "Prijateljski meč - bez poena za rang-listu":
      "Friendly match - no ranking points",
  "Prijateljski meč: ne ulazi u statistiku i ne dodaje poene.":
      "Friendly match: does not count toward statistics or points.",
  "Prijateljski mečevi ne ulaze u pobjede, statistiku ni poene.":
      "Friendly matches do not count toward wins, statistics or points.",
  "Prijateljski mečevi ne ulaze u poraze, statistiku ni poene.":
      "Friendly matches do not count toward losses, statistics or points.",
  "Prijateljski turnir": "Friendly tournament",
  "Prijateljski turniri ne ulaze u zvanične titule i ne daju poene.":
      "Friendly tournaments do not count toward official titles or points.",
  "Prijava": "Sign in",
  "Prijavi se": "Sign in",
  "Prijavi se na turnir": "Join tournament",
  "Prijavljen si": "You have joined",
  "Prikaz fotografija": "Photo view",
  "Prikazuje se na listi turnira. Može biti prijateljski ili takmičarski.":
      "Visible in the tournament list. Can be friendly or competitive.",
  "Prikaži cijelu fotografiju": "View full photo",
  "Prikaži igrače": "Show players",
  "Prikaži moju fotografiju": "View my photo",
  "Prikaži sve igrače": "Show all players",
  "Privatni": "Private",
  "Privatni turnir": "Private tournament",
  "Privatni turnir je uvijek prijateljski i ne utiče na rang-listu.":
      "Private tournaments are always friendly and do not affect rankings.",
  "Profil": "Profile",
  "Profil i podešavanja": "Profile and settings",
  "Profil igrača": "Player profile",
  "Profil je sačuvan": "Profile saved",
  "Profilna slika je promijenjena": "Profile photo updated",
  "Promijeni povezano mjesto": "Change linked place",
  "Promijeni sliku": "Change photo",
  "Promjena lozinke": "Reset password",
  "Pronađi igrača": "Find a player",
  "Pronađi mjesto": "Find a place",
  "Pronađi na Google mapama": "Find on Google Maps",
  "Pronađi protivnika": "Find an opponent",
  "Protivnik": "Opponent",
  "Provjera trenutno nije dostupna.": "Version check is currently unavailable.",
  "Provjeravam…": "Checking…",
  "Provjeri internet vezu i pokušaj ponovo.":
      "Check your internet connection and try again.",
  "Provjeri ponovo": "Check again",
  "Prvo grupe, zatim najbolji prolaze u eliminacionu fazu.":
      "A group stage followed by a knockout stage for the top players.",
  "Rang-lista": "Rankings",
  "Rang-lista je trenutno prazna.": "The ranking list is currently empty.",
  "Rang-lista obuhvata samo potvrđene takmičarske mečeve. Prijateljski mečevi ne ulaze u statistiku i ne donose poene.":
      "Rankings include only confirmed competitive matches. Friendly matches do not count toward statistics or points.",
  "Rang-lista turnira": "Tournament rankings",
  "Raniji unos": "Previous entry",
  "Razlika zbog ranijih pravila ili izmjene administratora":
      "Adjustment from earlier rules or an administrator's change",
  "Registracija": "Register",
  "Registracija igrača": "Player registration",
  "Registruj se": "Register",
  "Rezultat": "Result",
  "Rezultat ide drugom igraču na potvrdu prije računanja poena.":
      "The other player must confirm the result before points are awarded.",
  "Rezultat još nije unesen.": "No result has been submitted yet.",
  "Rezultat meča": "Match result",
  "Rezultat čeka potvrdu druge strane":
      "Waiting for the other player to confirm",
  "Rješavanje spora": "Resolve dispute",
  "Round-robin": "Round-robin",
  "Round-robin + knockout": "Round-robin + knockout",
  "Round-robin + knockout (opciono)": "Round-robin + knockout (optional)",
  "Samo potvrđeni takmičarski mečevi": "Confirmed competitive matches only",
  "Samo takmičarski osvojeni turniri": "Competitive tournament titles only",
  "Sat": "Hour",
  "Sačuvaj datum": "Save date",
  "Sačuvaj izmjene": "Save changes",
  "Sačuvaj lokaciju": "Save location",
  "Sačuvaj podešavanja": "Save settings",
  "Sačuvaj termin": "Save time",
  "Sačuvaj turnir": "Save tournament",
  "Sažeta lista": "Compact list",
  "Seniori": "Seniors",
  "Septembar": "September",
  "Server je vratio neispravan odgovor.":
      "The server returned an invalid response.",
  "Server ne odgovara. Pokušaj ponovo.":
      "The server is not responding. Please try again.",
  "Server trenutno nije dostupan. Pokušaj ponovo.":
      "The server is currently unavailable. Please try again.",
  "Set {p0}": "Set {p0}",
  "Setovi": "Sets",
  "Singl": "Singles",
  "Sledeći meč": "Next match",
  "Slika": "Photo",
  "Sporan rezultat": "Disputed result",
  "Sport": "Sport",
  "Spreman za sledeći meč?": "Ready for your next match?",
  "Status": "Status",
  "Status je promijenjen": "Status updated",
  "Svako igra sa svakim. Najbolje za male grupe i ligu.":
      "Everyone plays everyone. Best for small groups and leagues.",
  "Svi": "All",
  "Svi gradovi": "All cities",
  "Svi igrači": "All players",
  "Svi klubovi": "All clubs",
  "Tabela lige": "League standings",
  "Takmičarski": "Competitive",
  "Telefon": "Phone",
  "Tenis": "Tennis",
  "Tepih": "Carpet",
  "Termin": "Scheduled time",
  "Termin meča": "Match time",
  "Termin mora biti u okviru turnira: {p0} - {p1}.":
      "The match must be scheduled within the tournament dates: {p0} - {p1}.",
  "Termin: {p0}": "Scheduled: {p0}",
  "Titule": "Titles",
  "Trajno obriši nalog": "Permanently delete account",
  "Trava": "Grass",
  "Trenutno nema aktivnih turnira.":
      "No tournaments are currently in progress.",
  "Trenutno nema turnira.": "No tournaments at the moment.",
  "Turnir": "Tournament",
  "Turnir (opciono)": "Tournament (optional)",
  "Turniri": "Tournaments",
  "Turniri u toku: {p0}": "Tournaments in progress: {p0}",
  "Turnirski meč mora biti između {p0} i {p1}.":
      "The tournament match must take place between {p0} and {p1}.",
  "Tvoja teniska zajednica": "Your tennis community",
  "Tvrda podloga": "Hard court",
  "U najavi": "Upcoming",
  "U redu": "OK",
  "U toku": "In progress",
  "Ukloni": "Remove",
  "Ukloni filtere": "Clear filters",
  "Ukloni set": "Remove set",
  "Ukloni vezu sa Google mapama": "Unlink Google Maps",
  "Ukupno": "Total",
  "Unesi email adresu naloga. Poslaćemo link za promjenu lozinke.":
      "Enter your account email. We will send you a password reset link.",
  "Unesi ispravnu email adresu": "Enter a valid email address",
  "Unesi rezultat": "Enter result",
  "Unesite najmanje 3 znaka.": "Enter at least 3 characters.",
  "Unesite naziv lokacije.": "Enter a location name.",
  "Uredi lokaciju": "Edit location",
  "Uredi profil": "Edit profile",
  "Uredi turnir": "Edit tournament",
  "Učesnici": "Participants",
  "Verzija aplikacije": "App version",
  "Veza sa serverom nije dostupna.": "Unable to connect to the server.",
  "Već imaš nalog? Prijavi se": "Already have an account? Sign in",
  "Vidljiv je samo učesnicima i administratorima.":
      "Only visible to participants and administrators.",
  "Vidljiv je samo učesnicima i administratorima. Mečevi su prijateljski i ne utiču na rang-listu.":
      "Only visible to participants and administrators. Matches are friendly and do not affect rankings.",
  "Vještačka trava": "Artificial grass",
  "Vrh rang-liste": "Top players",
  "Vrijeme je za novu verziju": "Time for a new version",
  "Za dubl izaberi još dva igrača.": "Select two more players for doubles.",
  "Za potvrdu upiši DELETE": "Type DELETE to confirm",
  "Zaboravljena lozinka?": "Forgot password?",
  "Zahtjev nije uspio. Pokušaj ponovo.":
      "The request failed. Please try again.",
  "Zahtjevi koji čekaju odgovor: {p0}": "Requests awaiting a response: {p0}",
  "Započni razgovor sa igračem.": "Start a conversation with a player.",
  "Zatvori": "Close",
  "Završen": "Finished",
  "Zdravo, {p0}": "Hello, {p0}",
  "bez rezultata": "no result",
  "potvrđen": "confirmed",
  "titula": "title",
  "{p0}\nprotiv {p1}": "{p0}\nvs {p1}",
  "{p0} igrača": "Players: {p0}",
  "{p0} pobjeda": "Wins: {p0}",
  "{p0} pobjeda · {p1} mečeva": "Wins: {p0} · Played: {p1}",
  "{p0} pobjeda · {p1} poena": "Wins: {p0} · Points: {p1}",
  "{p0} pobjeda, {p1} poraza": "Wins: {p0}, losses: {p1}",
  "{p0} poena": "Points: {p0}",
  "{p0} poena  |  {p1}-{p2}  |  {p3} mečeva":
      "Points: {p0}  |  {p1}-{p2}  |  Played: {p3}",
  "{p0} u {p1}:{p2}": "{p0} at {p1}:{p2}",
  "{p0} x {p1} poena": "{p0} x {p1} points",
  "{p0}. mjesto": "Rank {p0}",
  "{p0}. na rang-listi": "Ranked #{p0}",
  "{p0}.{p1}.{p2} u {p3}:{p4}": "{p0}.{p1}.{p2} at {p3}:{p4}",
  "{p0}/5 slika": "{p0}/5 photos",
  "Čeka odgovor": "Awaiting response",
  "Čeka se odgovor protivnika": "Waiting for your opponent's response",
  "Čekaju se potvrđeni rezultati ove runde.":
      "Waiting for this round's results to be confirmed.",
  "Čuvanje...": "Saving...",
  "Šaljem...": "Sending...",
  "Šljaka": "Clay",
  "Švajcarski sistem": "Swiss system",
};
