unit ta_i18n_hr_more;
{ GENERIRANO (tools/i18n): dodatni hrvatski prijevodi sucelja (engleski izvor -> hrvatski). }
{$mode objfpc}{$H+}

interface

implementation

uses
  ta_i18n;

initialization
  RegisterTranslations('hr', ['Dictionary: %d fields completed', 'Rječnik: dopunjeno polja %d', 'Exists, skipped: ', 'Već postoji, preskočeno: ', 'Codebook: ', 'Šifrarnik: ', 'Form with items: ', 'Forma sa stavkama: ', 'Form: ', 'Forma: ', 'List: ', 'Popis: ', 'Report: ', 'Izvješće: ', 'Main menu created', 'Glavni izbornik je izrađen', 'Main menu not created', 'Glavni izbornik nije izrađen', ' list', ' popis', ' report', ' izvješće']);
  RegisterTranslations('hr', ['There is no saved query: ', 'Nema spremljenog upita: ', 'Enter a name for the saved query.', 'Upiši naziv spremljenog upita.', 'There is no query to save: run a query first (F7, F8).', 'Nema upita za spremanje: prvo izvrši upit (F7, F8).']);
  RegisterTranslations('hr', ['Automatic colour', 'Automatska boja']);
  RegisterTranslations('hr', ['&Business', '&Poslovanje', '&Users and rights', '&Korisnici i prava', '&Tools', '&Alati', '&Look', '&Izgled', '&Light', '&Svijetlo', '&Dark', '&Tamno', '&System', '&Sustavno', '&Colour', '&Boja']);
  RegisterTranslations('hr', ['Datasheet', 'Podaci', 'Design', 'Dizajn']);
  RegisterTranslations('hr', ['The board needs the field that makes the columns.', 'Ploča treba polje po kojem se prave stupci.', 'The column field must be linked to a lookup table: ', 'Polje stupaca mora biti povezano sa šifrarnikom: ', '(none)', '(bez)']);
  RegisterTranslations('hr', ['The dashboard needs the group, name and value fields.', 'Nadzorna ploča treba polja skupine, naziva i vrijednosti.']);
  RegisterTranslations('hr', ['The schedule view needs the master list, the items table, the link, days, from and to fields.', 'Raspored treba popis rasporeda, tablicu stavki, vezu te polja dana, od i do.']);
  RegisterTranslations('hr', ['Send the command?', 'Poslati naredbu?', 'ukljuci', 'Uključi', 'iskljuci', 'Isključi']);
  RegisterTranslations('hr', ['Folder for the ESPHome configurations', 'Mapa za ESPHome konfiguracije', 'No unit has an MQTT topic.', 'Nijedan pogon nema MQTT temu.', '%d ESPHome configurations were written to %s.', 'ESPHome konfiguracija izrađeno: %d, u mapu %s.']);
  RegisterTranslations('hr', ['(dictionary)', '(rječnik)', '{ Modules contain only procedures and functions. }', '{ Moduli sadrže samo procedure i funkcije. }', '{ Trigger example: enter the procedure name in the form (OnExit, OnValidate, BeforeInsert, OnError...) or on a control. }', '{ Primjer okidača: upiši naziv procedure u formu (OnExit, OnValidate, BeforeInsert, OnError...) ili na kontrolu. }', '{ CancelEvent rejects the action; EventInfo gives eventControl, eventValue, eventKey and eventMessage. }', '{ CancelEvent odbija radnju; EventInfo daje eventControl, eventValue, eventKey i eventMessage. }', 'The value must not be negative.', 'Vrijednost ne smije biti negativna.']);
  RegisterTranslations('hr', ['Undo', 'Poništi', 'Order…', 'Poredak…', 'Page and labels…', 'Stranica i naljepnice…', 'Recipients (one letter per row)', 'Primatelji (jedan dopis po retku)', 'Filter (SQL condition; empty = all)', 'Filter (SQL uvjet; prazno = svi)', 'Table columns: field|Title|format|alignment|share', 'Stupci tablice: polje|Naslov|oblik|poravnanje|udio', 'Preview', 'Pregled', 'Each recipient (source row) gets their own letter on a new page.', 'Svaki primatelj (redak izvora) dobiva svoj dopis na novoj stranici.', 'Columns, example:', 'Stupci, primjer:', 'Run', 'Pokreni', '+ row', '+ redak', 'Up', 'Gore', 'Down', 'Dolje', 'Paper', 'Papir', 'Margins (mm)', 'Margine (mm)', 'The paper is too small (at least 30 mm).', 'Papir je premalen (najmanje 30 mm).', 'Margins and spacing must not be negative.', 'Margine i razmaci ne smiju biti negativni.', 'Change folder...', 'Promijeni mapu...', 'Restore default', 'Vrati zadano', 'Convert pictures from the database', 'Pretvori slike iz baze', 'Update', 'Ažuriraj', 'Blocks', 'Blokovi']);
  RegisterTranslations('hr', ['Check', 'Provjeri', 'Run', 'Pokreni', 'From database…', 'Iz baze…', 'To database…', 'U bazu…', 'From a skeleton', 'Od kostura', 'From data (tables)', 'Od podataka (tablice)', 'Refresh', 'Osvježi', 'Auto layout', 'Automatski raspored', 'CSV (;) - for Croatian Excel', 'CSV (;) - za hrvatski Excel', '(all tables)', '(sve tablice)']);
  RegisterTranslations('hr', ['Save', 'Spremi', 'Preview', 'Pregled', 'Undo', 'Poništi', 'Duplicate', 'Dupliciraj', 'Align', 'Poravnaj', 'Expression...', 'Izraz...', 'Field', 'Polje', 'Data type', 'Tip', 'Default', 'Zadano']);
  RegisterTranslations('hr', ['Count', 'Prebroji']);
  RegisterTranslations('hr', ['Case sensitive', 'Razlikuj velika i mala slova', 'Whole field value', 'Cijela vrijednost polja', 'Count rows', 'Prebroji retke', 'Labels / columns', 'Naljepnice / stupci', '   |   Sum ', '   |   Zbroj ', '" is already open. Close it before opening "', '" je već otvorena. Zatvori je prije otvaranja "', 'from the group "', 'iz skupine "', '" only one can be open at a time.', '" može biti otvorena samo jedna u isto vrijeme.', 'these two document types must not be open at the same time (related types).', 'te se dvije vrste dokumenata ne smiju otvarati istodobno (srodne vrste).', 'Column sum', 'Zbroj stupca', 'All', 'Sve']);
  RegisterTranslations('hr', ['Add', 'Dodaj', 'Edit', 'Uredi', 'Test (demo CIS, demo certificate)', 'Test (demo CIS, demo certifikat)', 'Production (real CIS)', 'Produkcija (pravi CIS)']);
  RegisterTranslations('hr', [
    '   |   Filter error: ', '   |   Greška filtra: ',
    '  (off)', '  (isključen)',
    '  allowed: ', '  dopušteno: ',
    ' (complete by hand or with an application description):', ' (dopuni ručno ili opisom aplikacije):',
    ' (still ', ' (još ',
    '%s.%s  ->  %s.%s (one to many)', '%s.%s  →  %s.%s (jedan prema više)',
    '(not possible)', '(nije moguće)',
    '... and ', '… i još ',
    '4GL program (*.4gl)|*.4gl|All files|*', '4GL program (*.4gl)|*.4gl|Sve datoteke|*',
    '4GL program (*.4gl)|*.4gl|All files|*.*', '4GL program (*.4gl)|*.4gl|Sve datoteke|*.*',
    'A change that a rule only writes does not trigger other rules, so a two-way entry (price <-> amount) has no loop.', 'Promjena koju pravilo samo upiše ne okida druga pravila, pa dvosmjerni unos (cijena ⇄ iznos) nema petlje.',
    'Access (*.mdb;*.accdb)|*.mdb;*.accdb|All files|*', 'Access (*.mdb;*.accdb)|*.mdb;*.accdb|Sve datoteke|*',
    'Add all fields', 'Dodaj sva polja',
    'Add fields', 'Dodaj polja',
    'All data satisfy the field rules.', 'Svi podaci zadovoljavaju pravila polja.',
    'Every field', 'Sva polja',
    'Application description (*.opis;*.txt)|*.opis;*.txt|All files|*', 'Opis aplikacije (*.opis;*.txt)|*.opis;*.txt|Sve datoteke|*',
    'Bottom (full width)', 'Dolje (cijela sirina)',
    'Calculated field...', 'Izračunato polje...',
    'Careful: files you use outside the Picture field and pictures in forms/reports (e.g. from 4GL programs) will also be on the list.', 'Pazi: datoteke koje koristiš mimo polja Picture i slika u formama/izvješćima (npr. iz 4GL programa) također će biti na popisu.',
    'Certificates (*.p12;*.pfx)|*.p12;*.pfx;*.P12;*.PFX|All files|*', 'Certifikati (*.p12;*.pfx)|*.p12;*.pfx;*.P12;*.PFX|Sve datoteke|*',
    'Choose the certificate file.', 'Odaberi datoteku certifikata.',
    'Clean up unused', 'Očisti neiskorištene',
    'Columns 1 = an ordinary report. Check the sizes of ready-made sheets against the packaging.', 'Stupaca 1 = običan izvještaj. Mjere gotovih araka provjeri prema pakiranju.',
    'Company name', 'Naziv tvrtke',
    'Complete the descriptions of fields and tables by hand. The program loads the file from the catalog/ folder next to the program (or from the folder in ', 'Opise polja i tablica dopuni ručno. Datoteku u mapi catalog/ pokraj programa (ili u mapi iz ',
    'Continuous form (header, rows, footer)', 'Neprekidna forma (zaglavlje, redovi, podnožje)',
    'Created: ', 'Izrađeno: ',
    'DISPLAY - view records in a grid (DISPLAY ARRAY)', 'DISPLAY — pregled zapisa u mreži (DISPLAY ARRAY)',
    'Data (*.csv;*.txt;*.tsv;*.xlsx;*.xls;*.ods)|*.csv;*.txt;*.tsv;*.xlsx;*.xls;*.ods|All files|*', 'Podaci (*.csv;*.txt;*.tsv;*.xlsx;*.xls;*.ods)|*.csv;*.txt;*.tsv;*.xlsx;*.xls;*.ods|Sve datoteke|*',
    'Database (*.db)|*.db|All files|*', 'Baza (*.db)|*.db|Sve datoteke|*',
    'Database backup', 'Sigurnosna kopija baze',
    'Dear Sir or Madam,', 'Poštovani,',
    'Delete item', 'Briši stavku',
    'Delete link', 'Obriši vezu',
    'Delete record', 'Briši zapis',
    'Remove row', 'Briši redak',
    'Determined: ', 'Određeno: ',
    'ERROR ', 'GREŠKA ',
    'ERROR: ', 'GREŠKA: ',
    'Enter the certificate password.', 'Upiši lozinku certifikata.',
    'Enter the label width and height.', 'Upiši širinu i visinu naljepnice.',
    'Example conditions: A* (starts with A), >5, 3:7 (from-to), a|b (or). An empty field = no condition.', 'Uvjeti po primjeru: A* (počinje s A), >5, 3:7 (od-do), a|b (ili). Prazno polje = bez uvjeta.',
    'Existing files were not moved: copy the content of the old folder into the new one.', 'Postojeće datoteke nisu premještene: kopiraj sadržaj stare mape u novu.',
    'Export to CSV', 'Izvoz u CSV',
    'Export view to CSV', 'Izvoz prikaza u CSV',
    'Font size (px)', 'Veličina slova (px)',
    'For network work set a shared folder (network drive) with the "Change folder" button.', 'Za rad u mreži postavi dijeljenu mapu (mrežni disk) gumbom "Promijeni mapu".',
    'Form + continuous subforms (e.g. an invoice with items)', 'Obrazac + neprekidne podforme (npr. račun sa stavkama)',
    'Form footer', 'Podnožje forme',
    'Help:', 'Pomoć:',
    'How do you want to compose the button action?', 'Kako želiš složiti akciju gumba?',
    'It is recommended to make a backup of the database first. Continue?', 'Preporučuje se prvo napraviti sigurnosnu kopiju baze. Nastaviti?',
    'It is started by an .sh script (or a .desktop file). On another computer you need ', 'Pokreće se skriptom .sh (ili .desktop datotekom). Na drugom računalu trebaju ',
    'Key: RSA ', 'Ključ: RSA ',
    'Letter name', 'Naziv dopisa',
    'Letter text (line start: > right, ^ center, # bold)', 'Tekst dopisa (početak retka: > desno, ^ sredina, # podebljano)',
    'Monthly report ', 'Mjesečni izvještaj ',
    'Move them to the subfolder _neiskoristeno? (Nothing is deleted; you can delete the folder later or put the files back.) ', 'Premjestiti ih u podmapu _neiskoristeno? (Ništa se ne briše; mapu možeš kasnije obrisati ili vratiti datoteke.) ',
    'N - at the payment device level', 'N – na razini naplatnog uređaja',
    'New password', 'Nova lozinka',
    'New record', 'Novi zapis',
    'New user', 'Novi korisnik',
    'Next record', 'Sljedeći zapis',
    'None (free)', 'Nema (slobodno)',
    'Only the link is kept in the database (e.g. slike/kupac/20261103-logo.png); the picture is a file in this folder.', 'U bazi se čuva samo veza (npr. slike/kupac/20261103-logo.png); slika je datoteka u ovoj mapi.',
    'Open it via Database > Connect to a server.', 'Otvori je preko Baza > Spoji na poslužitelj.',
    'Open...', 'Otvori…',
    'Order of choosing the folder: environment variable ', 'Redoslijed određivanja mape: varijabla okoline ',
    'Pictures (*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.svg)|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.svg|All files|*', 'Slike (*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.svg)|*.png;*.jpg;*.jpeg;*.bmp;*.gif;*.svg|Sve datoteke|*',
    'Pictures converted in forms and reports: ', 'Pretvoreno slika u formama i izvješćima: ',
    'Pictures|*.png;*.jpg;*.jpeg;*.bmp;*.gif|All files|*', 'Slike|*.png;*.jpg;*.jpeg;*.bmp;*.gif|Sve datoteke|*',
    'Postal code and city', 'Poštanski broj i mjesto',
    'Replace all', 'Zamijeni sve',
    'Report on what was not imported (', 'Izvještaj o neuvezenom (',
    'Report to PDF', 'Izvješće u PDF',
    'Row %d: the condition is not valid (%s).', 'Redak %d: uvjet nije ispravan (%s).',
    'Row %d: the expression is not valid (%s).', 'Redak %d: izraz nije ispravan (%s).',
    'Rule violations: ', 'Prekršaja pravila: ',
    'Run query (F8)', 'Izvrši upit (F8)',
    'SQLite database (*.db;*.sqlite)|*.db;*.sqlite|All files|*', 'SQLite baza (*.db;*.sqlite)|*.db;*.sqlite|Sve datoteke|*',
    'Save as…', 'Spremi kao…',
    'Save query', 'Spremi upit',
    'Save record', 'Spremi zapis',
    'Show SQL', 'Prikaži SQL',
    'Show whole rows (not only the summary)', 'Prikaži cijele retke (ne samo sažetak)',
    'Sum name', 'Naziv zbroja',
    'TYPHACCESS_CATALOG) at the next start.', 'TYPHACCESS_CATALOG) program učitava pri idućem pokretanju.',
    'Template: price <-> amount', 'Predložak: cijena ⇄ iznos',
    'Test ZKI (invoice 1, 1.00 EUR): ', 'Probni ZKI (račun 1, 1,00 EUR): ',
    'The DejaVu Sans font was not found.', 'Font DejaVu Sans nije pronađen.',
    'The database is not open', 'Baza nije otvorena',
    'The domain was made from a database snapshot; complete the description.', 'Domena izrađena iz snimke baze; dopuni opis.',
    'The file was not saved.', 'Datoteka nije spremljena.',
    'The form is: report > file.pdf', 'Oblik je: izvješće > datoteka.pdf',
    'The label is taller than the page.', 'Naljepnica je viša od stranice.',
    'The labels (%d x %s mm with spacing %s) do not fit the paper width.', 'Naljepnice (%d × %s mm uz razmak %s) ne stanu u širinu papira.',
    'The left and right margins leave no room for content.', 'Lijeva i desna margina ne ostavljaju mjesta za sadržaj.',
    'The rule is not satisfied: ', 'Pravilo nije ispunjeno: ',
    'The signature failed: ', 'Potpis nije uspio: '
  ]);
  RegisterTranslations('hr', [
    'The top and bottom margins leave no room for content.', 'Gornja i donja margina ne ostavljaju mjesta za sadržaj.',
    'Theme (*.json)|*.json|All files|*.*', 'Tema (*.json)|*.json|Sve datoteke|*.*',
    'There are no tasks in the queue.', 'Nema zadataka na redu.',
    'There is no 4GL program: ', 'Nema 4GL programa: ',
    'There is no domain: ', 'Nema domene: ',
    'There is no letter: ', 'Nema dopisa: ',
    'There is no printer ', 'Nema pisača ',
    'There is no program', 'Nema programa',
    'There is no report: ', 'Nema izvjesca: ',
    'Top (full width)', 'Gore (cijela sirina)',
    'WARNING: the certificate expires soon.', 'UPOZORENJE: certifikat uskoro istječe.',
    'WARNING: this is a folder in your user profile, it is not shared with other computers. ', 'UPOZORENJE: ovo je mapa u tvom korisničkom profilu, ne dijeli se s drugim računalima. ',
    'Write the text of the letter here.', 'Napišite tekst dopisa ovdje.',
    'Yours sincerely,', 'S poštovanjem,',
    'admin: everything, including design', 'admin: sve, uključujući dizajn',
    'and a list (report) for the main tables.', 'te popis (izvješće) za glavne tablice.',
    'error: ', 'greška: ',
    'other rows (they appear while running)', 'ostali redovi (pojavljuju se pri izvođenju)',
    'you can add it later in the query designer.', 'možeš kasnije dodati u dizajneru upita.',
    'you can choose the columns and the field that is summed; the sum and the item count follow the current master record.', 'možeš odabrati stupce i polje koje se zbraja; zbroj i broj stavki prate trenutni master zapis.'
  ]);
  RegisterTranslations('hr', ['will be overwritten', 'bit će prepisano', 'exists, skipped', 'već postoji, preskočeno', 'Main menu', 'Glavni izbornik', 'all forms and reports', 'sve forme i izvješća', 'Main (form, list, report)', 'Glavna (forma, popis, izvješće)', 'Items of another table', 'Stavke druge tablice', 'Codebook (grid)', 'Šifrarnik (mreža)', 'Link table (skip)', 'Tablica veze (preskoči)', 'Skip', 'Preskoči', 'This table has no foreign key to a table it could be the items of.', 'Ova tablica nema strani ključ prema tablici čije bi stavke mogla biti.', 'That table cannot be the parent.', 'Ta tablica ne može biti nadređena.', 'Preview: %d forms, %d lists, %d reports, %d codebooks, %d already exist', 'Pregled: formi %d, popisa %d, izvješća %d, šifrarnika %d, već postoji %d', 'Existing forms and reports with the same names will be replaced. Continue?', 'Postojeće forme i izvješća istog naziva bit će zamijenjeni. Nastaviti?', 'Done: %d forms, %d lists, %d reports, %d codebooks, %d skipped', 'Gotovo: formi %d, popisa %d, izvješća %d, šifrarnika %d, preskočeno %d', 'Create application from database', 'Izradi aplikaciju iz baze', 'Tables and what the application makes of them (select a table to change its role)', 'Tablice i što aplikacija od njih radi (odaberite tablicu za promjenu uloge)', 'Items of', 'Stavke od', 'Columns', 'Stupci', 'Role of the selected table:', 'Uloga odabrane tablice:', 'Items of table:', 'Stavke tablice:', 'Entry form layout:', 'Raspored forme za unos:', 'One column', 'Jedan stupac', 'Two columns', 'Dva stupca', 'Items of a document:', 'Stavke dokumenta:', 'Below the form', 'Ispod forme', 'On tabs', 'Na karticama', 'A list (with filters) for every main table', 'Popis (s filterima) za svaku glavnu tablicu', 'A report for every main table', 'Izvješće za svaku glavnu tablicu', 'Editing grids for codebooks', 'Mreže za uređivanje šifrarnika', 'Fill the data dictionary (captions, formats)', 'Popuni rječnik podataka (natpisi, formati)', 'Created and modified stamps filled in automatically', 'Oznake stvaranja i izmjene upisuju se automatski', 'Number documents automatically (no./premises/device)', 'Automatski numeriraj dokumente (br./prostor/uređaj)', 'Replace forms and reports that already exist', 'Zamijeni forme i izvješća koji već postoje', 'Generate application', 'Izradi aplikaciju', 'What was made', 'Što je izrađeno', 'Create application from &database...', 'Izradi aplikaciju iz &baze...']);
  RegisterTranslations('hr', ['generated earlier, will be refreshed', 'generirano ranije, bit će osvježeno', 'changed by hand, kept', 'ručno izmijenjeno, ostaje']);
  RegisterTranslations('hr', [' data', ' podaci']);
  RegisterTranslations('hr', ['Yes', 'Da', 'No', 'Ne']);
  RegisterTranslations('hr', ['Other', 'Ostalo', 'List', 'Popis']);
  RegisterTranslations('hr', ['January', 'siječanj', 'February', 'veljača', 'March', 'ožujak', 'April', 'travanj', 'May', 'svibanj', 'June', 'lipanj', 'July', 'srpanj', 'August', 'kolovoz', 'September', 'rujan', 'October', 'listopad', 'November', 'studeni', 'December', 'prosinac', 'Mon', 'Pon', 'Tue', 'Uto', 'Wed', 'Sri', 'Thu', 'Čet', 'Fri', 'Pet', 'Sat', 'Sub', 'Sun', 'Ned', 'Today', 'Danas']);
  RegisterTranslations('hr', ['Delete the selected records?', 'Obrisati odabrane zapise?']);

end.
