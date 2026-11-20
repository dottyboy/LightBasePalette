unit ta_offers;
{ Poslovni predlozak "Ponude i ugovori": ponuda za posao (usluge i materijal po fazama, avans, dopusteno prekoracenje,
  rokovi, uvjeti), ugovor izveden iz ponude (faze placanja i rokovi se prepisuju iz ponude), dodatna ponuda vezana uz prvu
  i aneks ugovora. Dokumente slaze makroi (blokovi) i dopisi (Ugovor, Aneks ugovora); sve je obican sadrzaj baze. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta;

{ Izgradi predlozak u otvorenoj bazi (ASample: primjer ponude, ugovora i aneksa). }
function BuildOffersTemplate(ADb: TAppDb; ASample: Boolean; ALog: TStrings): Boolean;
{ Tekst makroa s id-om umjesto [id]: za izvodenje bez forme (testovi, skripte). }
function OffersMacroText(const AName: string; AId: Integer): string;

implementation

uses
  ta_formdef, ta_iconmap, ta_controls, ta_wizardgen, ta_bizgen, ta_blocks, ta_script, ta_letter, ta_types;

const
  MacroContract = 'Napravi ugovor';
  MacroAddendumOffer = 'Napravi dodatnu ponudu';
  MacroAnnex = 'Napravi aneks';
  MacroPrint = 'Ispis ugovora';
  MacroWord = 'Ugovor u Word';
  MacroInvoice = 'Napravi račun za fazu';
  MacroOverrun = 'Provjeri prekoračenje';

{ ---------------- makroi (blokovi) ---------------- }

procedure Com(P: TaBlockProgram; const T: string);
begin
  P.Add(NewCommentBlock(T));
end;

procedure Cmd(P: TaBlockProgram; const V, A: string);
begin
  P.Add(NewCommandBlock(V, A));
end;

procedure IfB(P: TaBlockProgram; const C: string);
begin
  P.Add(NewStructBlock(bkIfBlock, C));
end;

procedure ElseB(P: TaBlockProgram);
begin
  P.Add(NewStructBlock(bkElse, ''));
end;

procedure EndIf(P: TaBlockProgram);
begin
  P.Add(NewStructBlock(bkEndIf, ''));
end;

procedure Let(P: TaBlockProgram; const N, E: string);
begin
  P.Add(NewLetBlock(N, E));
end;

function ifthen_annex(A: Boolean): string;
begin
  if A then Result := '(SELECT id FROM ugovori WHERE ponuda_id = o.parent_id AND vrsta = ''Ugovor'')' else Result := 'NULL';
end;

{ ugovor ili aneks iz ponude pid: zaglavlje, faze (avans pa po jedna faza za svaku fazu stavki), ispravak zaokruzivanja }
procedure ContractBlocks(P: TaBlockProgram; AAnnex: Boolean);
var
  Vrsta, Prefix: string;
begin
  if AAnnex then begin Vrsta := 'Aneks'; Prefix := 'AN-'; end else begin Vrsta := 'Ugovor'; Prefix := 'UG-'; end;
  Let(P, 'pid', '[id]');
  if AAnnex then
  begin
    Com(P, 'Aneks ugovora iz dodatne ponude: ponuda mora imati osnovnu ponudu koja ima ugovor');
    Cmd(P, 'fetch', 'osn = SELECT parent_id FROM ponude_posla WHERE id = {pid}');
    IfB(P, 'IsNull([osn])');
    Cmd(P, 'msg', 'Ovo nije dodatna ponuda (nema vezu na osnovnu ponudu).');
    Cmd(P, 'stop', '');
    EndIf(P);
    Cmd(P, 'fetch', 'ug = SELECT id FROM ugovori WHERE ponuda_id = {osn} AND vrsta = ''Ugovor''');
    IfB(P, 'IsNull([ug])');
    Cmd(P, 'msg', 'Osnovna ponuda još nema ugovor. Prvo napravi ugovor.');
    Cmd(P, 'stop', '');
    EndIf(P);
  end
  else
    Com(P, 'Ugovor iz prihvaćene ponude: cijena, avans, rokovi i uvjeti prepisuju se iz ponude');
  Cmd(P, 'fetch', 'ima = SELECT COUNT(*) FROM ugovori WHERE ponuda_id = {pid}');
  IfB(P, '[ima] > 0');
  Cmd(P, 'msg', 'Za ovu ponudu već postoji ' + LowerCase(Vrsta) + '.');
  Cmd(P, 'stop', '');
  EndIf(P);
  Cmd(P, 'fetch', 'ukupno = SELECT COALESCE(ROUND(SUM(iznos), 2), 0) FROM ponude_posla_stavke WHERE ponuda_id = {pid}');
  IfB(P, '[ukupno] <= 0');
  Cmd(P, 'msg', 'Ponuda nema stavki, pa nema što ugovoriti.');
  Cmd(P, 'stop', '');
  EndIf(P);
  Cmd(P, 'sql', 'INSERT INTO ugovori (broj, datum, ponuda_id, partner_id, vrsta, naziv, ukupno, avans_postotak, prekoracenje_postotak, rok_pocetka, rok_zavrsetka, uvjeti, parent_id, status) ' +
    'SELECT ''' + Prefix + ''' || strftime(''%Y'', ''now'') || ''-'' || printf(''%03d'', (SELECT COALESCE(MAX(id), 0) + 1 FROM ugovori)), date(''now''), o.id, o.partner_id, ''' + Vrsta + ''', o.naziv, {ukupno}, ' +
    'o.avans_postotak, o.prekoracenje_postotak, o.rok_pocetka, o.rok_zavrsetka, o.uvjeti, ' + 
    ifthen_annex(AAnnex) + ', ''na snazi'' FROM ponude_posla o WHERE o.id = {pid}');
  Cmd(P, 'fetch', 'uid = SELECT MAX(id) FROM ugovori');
  Cmd(P, 'sql', 'INSERT INTO ugovor_faze (ugovor_id, redni, naziv, iznos, rok) ' +
    'SELECT u.id, 0, ''Avans'', ROUND(u.ukupno * u.avans_postotak / 100.0, 2), u.datum FROM ugovori u WHERE u.id = {uid} AND u.avans_postotak > 0');
  Cmd(P, 'sql', 'INSERT INTO ugovor_faze (ugovor_id, redni, naziv, iznos, rok) ' +
    'SELECT u.id, COALESCE(s.faza, 1), COALESCE((SELECT f.naziv FROM ponude_posla_faze f WHERE f.ponuda_id = {pid} AND f.redni = COALESCE(s.faza, 1)), ''Faza '' || COALESCE(s.faza, 1)), ' +
    'ROUND(SUM(s.iznos) * (1 - u.avans_postotak / 100.0), 2), (SELECT f.rok FROM ponude_posla_faze f WHERE f.ponuda_id = {pid} AND f.redni = COALESCE(s.faza, 1)) ' +
    'FROM ponude_posla_stavke s JOIN ugovori u ON u.id = {uid} WHERE s.ponuda_id = {pid} GROUP BY COALESCE(s.faza, 1) ORDER BY COALESCE(s.faza, 1)');
  Com(P, 'zaokruživanje: razlika do ugovorene cijene ide na zadnju fazu, da zbroj faza točno odgovara ukupnoj cijeni');
  Cmd(P, 'sql', 'UPDATE ugovor_faze SET iznos = ROUND(iznos + (SELECT u.ukupno FROM ugovori u WHERE u.id = {uid}) - (SELECT SUM(f.iznos) FROM ugovor_faze f WHERE f.ugovor_id = {uid}), 2) ' +
    'WHERE id = (SELECT MAX(id) FROM ugovor_faze WHERE ugovor_id = {uid})');
  Cmd(P, 'sql', 'UPDATE ponude_posla SET status = ''prihvaćena'' WHERE id = {pid}');
  Cmd(P, 'fetch', 'broj = SELECT broj FROM ugovori WHERE id = {uid}');
  Cmd(P, 'msg', Vrsta + ' {broj} je napravljen. Ukupno {ukupno} EUR. Otvori ga na formi Ugovori.');
end;


function MacroText(const AName: string): string;
var
  P: TaBlockProgram;
begin
  P := TaBlockProgram.Create;
  try
    if AName = MacroContract then ContractBlocks(P, False)
    else if AName = MacroAnnex then ContractBlocks(P, True)
    else if AName = MacroAddendumOffer then
    begin
      Com(P, 'Dodatna ponuda: nova ponuda s vezom na ovu (osnovnu); stavke se upisuju naknadno');
      Let(P, 'pid', '[id]');
      Cmd(P, 'fetch', 'v = SELECT vrsta FROM ponude_posla WHERE id = {pid}');
      IfB(P, '[v] = "Dodatna"');
      Cmd(P, 'msg', 'Dodatna ponuda se veže uz osnovnu ponudu, ne uz drugu dodatnu.');
      Cmd(P, 'stop', '');
      EndIf(P);
      Com(P, 'dokument iz dokumenta: nova ponuda se kopira iz osnovne, polje po polje');
      Cmd(P, 'copyrows', 'ponude_posla WHERE id = {pid} -> ponude_posla : broj = broj || ''-D'' || (SELECT COUNT(*) + 1 FROM ponude_posla x WHERE x.parent_id = ponude_posla.id), ' +
        'datum = date(''now''), partner_id = partner_id, naziv = ''Dodatni radovi: '' || naziv, parent_id = id, vrsta = ''Dodatna'', status = ''nacrt'', ' +
        'avans_postotak = 0, prekoracenje_postotak = prekoracenje_postotak, uvjeti = uvjeti');
      Cmd(P, 'fetch', 'nova = SELECT broj FROM ponude_posla WHERE id = (SELECT MAX(id) FROM ponude_posla)');
      Cmd(P, 'requery', '');
      Cmd(P, 'msg', 'Napravljena je dodatna ponuda {nova}. Pronađi je na popisu ponuda i upiši stavke.');
    end
    else if AName = MacroInvoice then
    begin
      Com(P, 'Račun za sljedeću fazu plaćanja ugovora (prvo avans, zatim faze po redu); faza se označi računom da se ne naplati dvaput');
      Let(P, 'uid', '[id]');
      Cmd(P, 'fetch', 'fid = SELECT id FROM ugovor_faze WHERE ugovor_id = {uid} AND racun_id IS NULL ORDER BY redni, id LIMIT 1');
      IfB(P, 'IsNull([fid])');
      Cmd(P, 'msg', 'Sve faze ovog ugovora već imaju račun.');
      Cmd(P, 'stop', '');
      EndIf(P);
      Cmd(P, 'fetch', 'opis = SELECT ''Ugovor '' || u.broj || '' - '' || f.naziv FROM ugovor_faze f JOIN ugovori u ON u.id = f.ugovor_id WHERE f.id = {fid}');
      Cmd(P, 'fetch', 'iznos = SELECT iznos FROM ugovor_faze WHERE id = {fid}');
      Com(P, 'stavka računa je usluga po ugovoru: artikl UGOVOR se napravi kad ne postoji');
      Cmd(P, 'sql', 'INSERT INTO artikli (sifra, naziv, jmj, cijena, pdv_stopa, min_zaliha, aktivan) SELECT ''UGOVOR'', ''Radovi po ugovoru'', ''kom'', 0, 25, 0, 1 ' +
        'WHERE NOT EXISTS (SELECT 1 FROM artikli WHERE sifra = ''UGOVOR'')');
      Cmd(P, 'fetch', 'aid = SELECT id FROM artikli WHERE sifra = ''UGOVOR''');
      Cmd(P, 'sql', 'INSERT INTO racuni (broj, datum, dospijece, partner_id, placeno, napomena) SELECT strftime(''%Y'', ''now'') || ''-'' || printf(''%03d'', (SELECT COALESCE(MAX(id), 0) + 1 FROM racuni)), ' +
        'date(''now''), date(''now'', ''+15 days''), u.partner_id, 0, {opis} FROM ugovori u WHERE u.id = {uid}');
      Cmd(P, 'fetch', 'rid = SELECT MAX(id) FROM racuni');
      Cmd(P, 'sql', 'INSERT INTO racuni_stavke (dokument_id, artikl_id, opis, kolicina, jmj, cijena, rabat, pdv_stopa, iznos) VALUES ({rid}, {aid}, {opis}, 1, ''kom'', {iznos}, 0, 25, {iznos})');
      Cmd(P, 'sql', 'UPDATE ugovor_faze SET racun_id = {rid} WHERE id = {fid}');
      Cmd(P, 'fetch', 'rbroj = SELECT broj FROM racuni WHERE id = {rid}');
      Cmd(P, 'msg', 'Napravljen je račun {rbroj}: {opis}, osnovica {iznos} EUR (PDV se dodaje na računu). Otvori ga na formi Računi.');
    end
    else if AName = MacroOverrun then
    begin
      Com(P, 'Stvarni troškovi prema ugovorenoj cijeni: upozorenje tek kad pređu dopušteni postotak prekoračenja');
      Let(P, 'uid', '[id]');
      Cmd(P, 'fetch', 'cijena = SELECT ukupno FROM ugovori WHERE id = {uid}');
      Cmd(P, 'fetch', 'najvise = SELECT ROUND(ukupno * (1 + prekoracenje_postotak / 100.0), 2) FROM ugovori WHERE id = {uid}');
      Cmd(P, 'fetch', 'postotak = SELECT prekoracenje_postotak FROM ugovori WHERE id = {uid}');
      Cmd(P, 'fetch', 'troskovi = SELECT ROUND(COALESCE(SUM(iznos), 0), 2) FROM ugovor_troskovi WHERE ugovor_id = {uid}');
      IfB(P, '[troskovi] > [najvise]');
      Cmd(P, 'msg', 'UPOZORENJE: stvarni troškovi {troskovi} EUR prelaze dopuštenu granicu {najvise} EUR (ugovoreno {cijena} EUR + {postotak} %). Za veće prekoračenje treba pisana suglasnost Naručitelja.');
      ElseB(P);
      IfB(P, '[troskovi] > [cijena]');
      Cmd(P, 'msg', 'Troškovi {troskovi} EUR su iznad ugovorenih {cijena} EUR, ali unutar dopuštenog prekoračenja do {najvise} EUR. Upozorenje nije potrebno.');
      ElseB(P);
      Cmd(P, 'msg', 'Troškovi {troskovi} EUR su unutar ugovorene cijene {cijena} EUR.');
      EndIf(P);
      EndIf(P);
    end
    else if AName = MacroPrint then
    begin
      Com(P, 'Ispis ugovora ili aneksa za odabrani zapis (letak se bira po vrsti)');
      Let(P, 'cid', '[id]');
      Let(P, 'vrsta', '[vrsta]');
      IfB(P, '[vrsta] = "Aneks"');
      Cmd(P, 'openletter', 'Aneks ugovora@{cid}');
      ElseB(P);
      Cmd(P, 'openletter', 'Ugovor@{cid}');
      EndIf(P);
    end
    else if AName = MacroWord then
    begin
      Com(P, 'Ugovor ili aneks u Word dokument');
      Let(P, 'cid', '[id]');
      Let(P, 'vrsta', '[vrsta]');
      Cmd(P, 'input', 'Puna putanja Word datoteke (npr. /home/ana/ugovor.docx):');
      IfB(P, '[unos] = ""');
      Cmd(P, 'msg', 'Odustali ste.');
      ElseB(P);
      IfB(P, '[vrsta] = "Aneks"');
      Cmd(P, 'exportletter', 'Aneks ugovora@{cid} > {unos}');
      ElseB(P);
      Cmd(P, 'exportletter', 'Ugovor@{cid} > {unos}');
      EndIf(P);
      Cmd(P, 'msg', 'Dokument je spremljen.');
      EndIf(P);
    end;
    Result := P.Text;
  finally
    P.Free;
  end;
end;

function OffersMacroText(const AName: string; AId: Integer): string;
begin
  Result := StringReplace(MacroText(AName), '[id]', IntToStr(AId), [rfReplaceAll]);
  Result := StringReplace(Result, '[vrsta]', '"Ugovor"', [rfReplaceAll]);
end;

{ ---------------- dopisi ---------------- }

procedure SaveLetters(ADb: TAppDb; ALog: TStrings);
var
  L: TaLetterDef;
  Cl: string;
begin
  { zajednicki upit: sve sto ugovor i aneks trebaju iz ugovora, ponude, partnera i osnovnog ugovora }
  SaveQuery(ADb, ALog, 'ugovori podaci',
    'SELECT u.id, u.broj, u.datum, u.vrsta, u.naziv, u.ukupno, u.avans_postotak,' + LineEnding +
    '       ROUND(u.ukupno * u.avans_postotak / 100.0, 2) AS avans_iznos, u.prekoracenje_postotak,' + LineEnding +
    '       ROUND(u.ukupno * u.prekoracenje_postotak / 100.0, 2) AS prekoracenje_iznos,' + LineEnding +
    '       ROUND(u.ukupno * (1 + u.prekoracenje_postotak / 100.0), 2) AS najvise,' + LineEnding +
    '       COALESCE((SELECT ROUND(SUM(s.iznos), 2) FROM ponude_posla_stavke s WHERE s.ponuda_id = u.ponuda_id AND s.vrsta = ''Usluga''), 0) AS usluge,' + LineEnding +
    '       COALESCE((SELECT ROUND(SUM(s.iznos), 2) FROM ponude_posla_stavke s WHERE s.ponuda_id = u.ponuda_id AND s.vrsta = ''Materijal''), 0) AS materijal,' + LineEnding +
    '       u.rok_pocetka, u.rok_zavrsetka, u.uvjeti,' + LineEnding +
    '       o.broj AS ponuda_broj, o.datum AS ponuda_datum,' + LineEnding +
    '       p.naziv AS kupac, p.adresa, p.postanski, p.grad, p.oib,' + LineEnding +
    '       b.broj AS osnovni_broj, b.datum AS osnovni_datum, b.ukupno AS osnovni_ukupno,' + LineEnding +
    '       COALESCE(b.ukupno, 0) + COALESCE((SELECT SUM(a.ukupno) FROM ugovori a WHERE a.parent_id = b.id), 0) AS ukupno_sa_aneksima' + LineEnding +
    'FROM ugovori u' + LineEnding +
    'JOIN partneri p ON p.id = u.partner_id' + LineEnding +
    'LEFT JOIN ponude_posla o ON o.id = u.ponuda_id' + LineEnding +
    'LEFT JOIN ugovori b ON b.id = u.parent_id');

  Cl := '#>[firma_naziv]' + LineEnding + '>[firma_adresa], [firma_mjesto]' + LineEnding + '>OIB / IBAN: [firma_iban]' + LineEnding + LineEnding;
  L := TaLetterDef.Create;
  try
    L.Name := 'Ugovor';
    L.Source := 'ugovori podaci';
    L.Filter := 'vrsta = ''Ugovor''';
    L.DetailSql := 'SELECT redni, naziv, rok, iznos FROM ugovor_faze WHERE ugovor_id = {id} ORDER BY redni';
    L.Columns := 'naziv|Plaćanje / faza||left|4' + LineEnding + 'rok|Rok||left|2' + LineEnding + 'iznos|Iznos (EUR)|0.00|right|2';
    L.TotalField := 'iznos';
    L.TotalLabel := 'Ukupno';
    L.Body := Cl +
      '^#UGOVOR br. [broj]' + LineEnding + '^o izvođenju radova: [naziv]' + LineEnding + LineEnding +
      'Sklopljen u [firma_mjesto] dana [datum] između:' + LineEnding +
      '1. [firma_naziv], [firma_adresa], [firma_mjesto] (dalje: Izvođač) i' + LineEnding +
      '2. [kupac], [adresa], [postanski] [grad], OIB [oib] (dalje: Naručitelj).' + LineEnding + LineEnding +
      '#Članak 1. Predmet ugovora' + LineEnding +
      'Izvođač se obvezuje izvesti radove: [naziv], prema ponudi br. [ponuda_broj] od [ponuda_datum], koja je sastavni dio ovog ugovora.' + LineEnding + LineEnding +
      '#Članak 2. Cijena' + LineEnding +
      'Ugovorna cijena iznosi [ukupno|0.00] EUR, od čega se na usluge odnosi [usluge|0.00] EUR, a na materijal [materijal|0.00] EUR. Iznosi su prema ponudi.' + LineEnding + LineEnding +
      '#Članak 3. Plaćanje' + LineEnding +
      'Naručitelj plaća avans u iznosu od [avans_postotak|0.##] % ugovorne cijene, odnosno [avans_iznos|0.00] EUR, a ostatak po fazama prema tablici:' + LineEnding +
      '[tablica]' + LineEnding +
      '#Članak 4. Rokovi' + LineEnding +
      'Izvođač započinje radove dana [rok_pocetka], a završava ih najkasnije do [rok_zavrsetka].' + LineEnding + LineEnding +
      '#Članak 5. Prekoračenje cijene' + LineEnding +
      'Izvođač smije bez prethodnog upozorenja prekoračiti ugovorenu cijenu do [prekoracenje_postotak|0.##] % ([prekoracenje_iznos|0.00] EUR), odnosno do ukupno [najvise|0.00] EUR. Za veće prekoračenje potrebna je pisana suglasnost Naručitelja.' + LineEnding + LineEnding +
      '#Članak 6. Dodatni troškovi i dodatni radovi' + LineEnding +
      '[uvjeti]' + LineEnding +
      'Radovi koji nisu obuhvaćeni ponudom ugovaraju se dodatnom ponudom i aneksom ovog ugovora.' + LineEnding + LineEnding +
      '#Članak 7. Završne odredbe' + LineEnding +
      'Ugovor je sastavljen u dva istovjetna primjerka, po jedan za svaku ugovornu stranu.' + LineEnding + LineEnding + LineEnding +
      'Za Izvođača: ________________________          Za Naručitelja: ________________________';
    ADb.SaveObject('_sys_letters', L.Name, L.ToJson);
    ALog.Add('dopis: Ugovor');
  finally
    L.Free;
  end;
  L := TaLetterDef.Create;
  try
    L.Name := 'Aneks ugovora';
    L.Source := 'ugovori podaci';
    L.Filter := 'vrsta = ''Aneks''';
    L.DetailSql := 'SELECT redni, naziv, rok, iznos FROM ugovor_faze WHERE ugovor_id = {id} ORDER BY redni';
    L.Columns := 'naziv|Plaćanje / faza||left|4' + LineEnding + 'rok|Rok||left|2' + LineEnding + 'iznos|Iznos (EUR)|0.00|right|2';
    L.TotalField := 'iznos';
    L.Body := Cl +
      '^#ANEKS br. [broj]' + LineEnding + '^uz ugovor br. [osnovni_broj] od [osnovni_datum]' + LineEnding + LineEnding +
      'Ugovorne strane: [firma_naziv] (Izvođač) i [kupac], [adresa], [postanski] [grad], OIB [oib] (Naručitelj), dogovorile su sljedeće:' + LineEnding + LineEnding +
      '#Članak 1.' + LineEnding +
      'Uz ugovor br. [osnovni_broj] ugovaraju se dodatni radovi: [naziv], prema dodatnoj ponudi br. [ponuda_broj] od [ponuda_datum], koja je sastavni dio ovog aneksa.' + LineEnding + LineEnding +
      '#Članak 2.' + LineEnding +
      'Cijena dodatnih radova iznosi [ukupno|0.00] EUR (usluge [usluge|0.00] EUR, materijal [materijal|0.00] EUR). Ukupna ugovorna cijena iznosi [ukupno_sa_aneksima|0.00] EUR (osnovni ugovor [osnovni_ukupno|0.00] EUR).' + LineEnding + LineEnding +
      '#Članak 3.' + LineEnding +
      'Plaćanje dodatnih radova:' + LineEnding + '[tablica]' + LineEnding +
      '#Članak 4.' + LineEnding +
      'Dodatni radovi završavaju najkasnije do [rok_zavrsetka]. Ostale odredbe ugovora br. [osnovni_broj] ostaju na snazi.' + LineEnding + LineEnding + LineEnding +
      'Za Izvođača: ________________________          Za Naručitelja: ________________________';
    ADb.SaveObject('_sys_letters', L.Name, L.ToJson);
    ALog.Add('dopis: Aneks ugovora');
  finally
    L.Free;
  end;
end;

{ ---------------- forme ---------------- }

function Btn(const ACaption, AAction: string; X, Y, W: Integer): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := 'Button';
  Result.Caption := ACaption;
  Result.OnClick := AAction;
  AutoButtonIcon(Result);
  Result.Left := X; Result.Top := Y; Result.Width := W; Result.Height := 30;
end;

function Lab(const ACaption: string; X, Y, W: Integer): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := 'Label';
  Result.Caption := ACaption;
  Result.Left := X; Result.Top := Y; Result.Width := W; Result.Height := 18;
end;

function Calc(const AName, AExpr, AFmt: string; X, Y, W: Integer; ABold: Boolean): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := 'TextBox';
  Result.Name := AName;
  Result.ControlSource := AExpr;
  Result.Format := AFmt;
  Result.Left := X; Result.Top := Y; Result.Width := W; Result.Height := 22;
  Result.Bold := ABold;
  Result.SetX('locked', '1');
end;

{ zaglavlje u dva stupca (generator slaze polja jedno ispod drugog, forma bi bila previsoka): polja u AFields idu redom,
  memo polje AMemo (ako ga ima) preko cijele sirine ispod njih; podforme se pomicaju ispod. Vraca visinu do prve podforme. }
function Compact(F: TaFormDef; AFields: TStrings; const AMemo: string; const ACaptions: array of string): Integer;
const
  ColX: array[0..1] of Integer = (16, 480);
  W = 960;
var
  I, K, Row, Y, Idx: Integer;
  Lb, Ct: TaControlDef;
  Cap: string;
begin
  F.Width := W;
  Idx := F.IndexOfName('lblNaslov');
  if Idx >= 0 then F[Idx].Width := W - 32;
  Idx := F.IndexOfName('lnNaslov');
  if Idx >= 0 then F[Idx].Width := W - 32;
  for I := 0 to AFields.Count - 1 do
  begin
    Idx := F.IndexOfName('lbl' + AFields[I] + '_1');
    if Idx < 0 then Continue;
    Lb := F[Idx];
    Ct := nil;
    for K := 0 to F.Count - 1 do
      if (F[K].ControlSource = AFields[I]) and (F[K].Kind <> 'Label') then Ct := F[K];
    if Ct = nil then Continue;
    Row := I div 2;
    Lb.Left := ColX[I mod 2]; Lb.Top := 58 + Row * 34; Lb.Width := 170;
    Ct.Left := ColX[I mod 2] + 176; Ct.Top := Lb.Top - 2;
    if Ct.Width > 270 then Ct.Width := 270;
    { opisi polja: parovi "polje=Opis" }
    for K := 0 to High(ACaptions) do
    begin
      Cap := ACaptions[K];
      if Copy(Cap, 1, Length(AFields[I]) + 1) = AFields[I] + '=' then Lb.Caption := Copy(Cap, Length(AFields[I]) + 2, MaxInt);
    end;
  end;
  Y := 58 + ((AFields.Count + 1) div 2) * 34;
  if AMemo <> '' then
  begin
    Idx := F.IndexOfName('lbl' + AMemo + '_1');
    if Idx >= 0 then begin F[Idx].Left := 16; F[Idx].Top := Y; F[Idx].Width := 170; end;
    for K := 0 to F.Count - 1 do
      if (F[K].ControlSource = AMemo) and (F[K].Kind <> 'Label') then
      begin
        F[K].Left := 192; F[K].Top := Y - 2; F[K].Width := W - 192 - 16; F[K].Height := 60;
      end;
    Inc(Y, 72);
  end;
  Result := Y;
end;

{ makne sve sto je generator stavio ispod podformi (zbroj stupca...): ispod ide vlastiti sklop }
procedure DropBelowSubforms(F: TaFormDef);
var
  K, Idx, Top1: Integer;
begin
  Idx := F.IndexOfName('subDetalji1');
  if Idx < 0 then Exit;
  Top1 := F[Idx].Top;
  for K := F.Count - 1 downto 0 do
    if ((F[K].Kind = 'Label') or (F[K].Kind = 'TextBox')) and (F[K].Top > Top1) and (Copy(F[K].Name, 1, 10) <> 'lblDetalji') then F.Delete(F[K]);
end;

procedure PlaceSubforms(F: TaFormDef; const ACaptions: array of string; const AHeights: array of Integer; AStartY: Integer);
var
  N, Idx, Y: Integer;
begin
  { podforme jedna ispod druge, redom subDetalji1, subDetalji2... }
  Y := AStartY;
  for N := 1 to Length(AHeights) do
  begin
    Idx := F.IndexOfName('lblDetalji' + IntToStr(N));
    if Idx >= 0 then
    begin
      F[Idx].Left := 16; F[Idx].Top := Y; F[Idx].Width := 600;
      if N - 1 <= High(ACaptions) then F[Idx].Caption := ACaptions[N - 1];
    end;
    Idx := F.IndexOfName('subDetalji' + IntToStr(N));
    if Idx >= 0 then
    begin
      F[Idx].Left := 16; F[Idx].Top := Y + 22; F[Idx].Width := F.Width - 32; F[Idx].Height := AHeights[N - 1];
    end;
    Inc(Y, 22 + AHeights[N - 1] + 14);
  end;
end;

function BottomOf(F: TaFormDef): Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to F.Count - 1 do
    if F[I].Top + F[I].Height > Result then Result := F[I].Top + F[I].Height;
end;

procedure BuildForms(ADb: TAppDb; ALog: TStrings);
var
  MM: TaMDMulti;
  MR: TaMDMultiResult;
  Mf: TaFormDef;
  Master: TStringList;
  I, Y, StartY: Integer;
  Sub: TaControlDef;

  procedure Finish(AForm: TaFormDef);
  var
    J: Integer;
  begin
    SaveForm(ADb, ALog, AForm);
    for J := 0 to High(MR.Items) do MR.Items[J].Form.Free;
  end;

begin
  { Ponude: zaglavlje + stavke + faze }
  Master := TStringList.Create;
  try
    Master.CommaText := 'broj,datum,partner_id,naziv,vrsta,parent_id,status,avans_postotak,prekoracenje_postotak,rok_pocetka,rok_zavrsetka,uvjeti';
    MM.Master := 'ponude_posla'; MM.Name := 'Ponude poslova'; MM.Title := 'Ponude poslova'; MM.MasterFields := Master;
    MM.DetailAsForm := False; MM.UseTabs := False;
    SetLength(MM.Details, 2);
    MM.Details[0].Table := 'ponude_posla_stavke'; MM.Details[0].Fields := nil; MM.Details[0].SumField := '';
    MM.Details[0].ShowCount := False; MM.Details[0].FkCol := 'ponuda_id'; MM.Details[0].ParentCol := 'id';
    MM.Details[1].Table := 'ponude_posla_faze'; MM.Details[1].Fields := nil; MM.Details[1].SumField := '';
    MM.Details[1].ShowCount := False; MM.Details[1].FkCol := 'ponuda_id'; MM.Details[1].ParentCol := 'id';
    MR := BuildMasterDetailMulti(ADb, MM);
    if MR.Error <> '' then raise Exception.Create(MR.Error);
    Mf := MR.MasterForm;
    Master.CommaText := 'broj,datum,partner_id,naziv,vrsta,parent_id,status,avans_postotak,prekoracenje_postotak,rok_pocetka,rok_zavrsetka';
    StartY := Compact(Mf, Master, 'uvjeti', ['partner_id=Naručitelj', 'parent_id=Osnovna ponuda', 'avans_postotak=Avans (%)',
      'prekoracenje_postotak=Dopušteno prekoračenje (%)', 'rok_pocetka=Rok početka', 'rok_zavrsetka=Rok završetka', 'uvjeti=Uvjeti i dodatni troškovi',
      'naziv=Posao', 'vrsta=Vrsta']);
    DropBelowSubforms(Mf);
    PlaceSubforms(Mf, ['Stavke ponude (usluge i materijal po fazama)', 'Faze i rokovi'], [170, 100], StartY);
  finally
    Master.Free;
  end;
  for I := 0 to Mf.Count - 1 do
    if (Mf[I].Kind = 'Subform') and SameText(Mf[I].RowSource, 'ponude_posla_stavke') then
    begin
      Sub := Mf[I];
      Sub.SetX('calcrules', 'kolicina,cijena -> iznos = Zaokruzi([kolicina] * [cijena], 2) ;; iznos -> cijena = Zaokruzi([iznos] / [kolicina], 4)');
      Sub.Width := Mf.Width - 32;
    end;
  Y := BottomOf(Mf) + 8;
  Mf.Add(Lab('Usluge:', Mf.Width - 330, Y, 70));
  Mf.Add(Calc('txtUsluge', '=Nz(DSum("iznos", "ponude_posla_stavke", "ponuda_id = " & [id] & " And vrsta = ''Usluga''"), 0)', '#,##0.00 "€"', Mf.Width - 250, Y, 120, False));
  Mf.Add(Lab('Materijal:', Mf.Width - 330, Y + 26, 70));
  Mf.Add(Calc('txtMaterijal', '=Nz(DSum("iznos", "ponude_posla_stavke", "ponuda_id = " & [id] & " And vrsta = ''Materijal''"), 0)', '#,##0.00 "€"', Mf.Width - 250, Y + 26, 120, False));
  Mf.Add(Lab('UKUPNO:', Mf.Width - 330, Y + 52, 70));
  Mf.Add(Calc('txtUkupno', '=[txtUsluge] + [txtMaterijal]', '#,##0.00 "€"', Mf.Width - 250, Y + 52, 120, True));
  Mf.Add(Lab('Avans:', Mf.Width - 330, Y + 78, 70));
  Mf.Add(Calc('txtAvans', '=Zaokruzi([txtUkupno] * [avans_postotak] / 100, 2)', '#,##0.00 "€"', Mf.Width - 250, Y + 78, 120, False));
  Mf.Add(Btn('Napravi ugovor', 'macro:' + MacroContract, 16, Y, 260));
  Mf.Add(Btn('Napravi dodatnu ponudu', 'macro:' + MacroAddendumOffer, 16, Y + 36, 260));
  Mf.Add(Btn('Napravi aneks (iz dodatne ponude)', 'macro:' + MacroAnnex, 16, Y + 72, 260));
  Mf.Height := Y + 112;
  Finish(Mf);

  { Ugovori: zaglavlje + faze placanja }
  Master := TStringList.Create;
  try
    Master.CommaText := 'broj,datum,vrsta,partner_id,ponuda_id,parent_id,naziv,ukupno,avans_postotak,prekoracenje_postotak,rok_pocetka,rok_zavrsetka,status,uvjeti';
    MM.Master := 'ugovori'; MM.Name := 'Ugovori'; MM.Title := 'Ugovori i aneksi'; MM.MasterFields := Master;
    MM.DetailAsForm := False; MM.UseTabs := False;
    SetLength(MM.Details, 2);
    MM.Details[0].Table := 'ugovor_faze'; MM.Details[0].Fields := nil; MM.Details[0].SumField := 'iznos';
    MM.Details[0].ShowCount := False; MM.Details[0].FkCol := 'ugovor_id'; MM.Details[0].ParentCol := 'id';
    MM.Details[1].Table := 'ugovor_troskovi'; MM.Details[1].Fields := nil; MM.Details[1].SumField := '';
    MM.Details[1].ShowCount := False; MM.Details[1].FkCol := 'ugovor_id'; MM.Details[1].ParentCol := 'id';
    MR := BuildMasterDetailMulti(ADb, MM);
    if MR.Error <> '' then raise Exception.Create(MR.Error);
    Mf := MR.MasterForm;
    Master.CommaText := 'broj,datum,vrsta,partner_id,ponuda_id,parent_id,naziv,ukupno,avans_postotak,prekoracenje_postotak,rok_pocetka,rok_zavrsetka,status';
    StartY := Compact(Mf, Master, 'uvjeti', ['partner_id=Naručitelj', 'ponuda_id=Ponuda', 'parent_id=Osnovni ugovor', 'naziv=Posao', 'ukupno=Ugovorena cijena',
      'avans_postotak=Avans (%)', 'prekoracenje_postotak=Dopušteno prekoračenje (%)', 'rok_pocetka=Rok početka', 'rok_zavrsetka=Rok završetka',
      'vrsta=Vrsta', 'uvjeti=Uvjeti i dodatni troškovi']);
    DropBelowSubforms(Mf);
    PlaceSubforms(Mf, ['Plaćanje po fazama (avans i rokovi)', 'Stvarni troškovi (za provjeru prekoračenja)'], [150, 110], StartY);
  finally
    Master.Free;
  end;
  Y := BottomOf(Mf) + 8;
  Mf.Add(Lab('Zbroj faza:', Mf.Width - 330, Y, 90));
  Mf.Add(Calc('txtFaze', '=Nz(DSum("iznos", "ugovor_faze", "ugovor_id = " & [id]), 0)', '#,##0.00 "€"', Mf.Width - 230, Y, 120, False));
  Mf.Add(Lab('Dopušteno do:', Mf.Width - 330, Y + 26, 100));
  Mf.Add(Calc('txtNajvise', '=Zaokruzi([ukupno] * (1 + [prekoracenje_postotak] / 100), 2)', '#,##0.00 "€"', Mf.Width - 230, Y + 26, 120, True));
  Mf.Add(Btn('Pregled ugovora / aneksa', 'macro:' + MacroPrint, 16, Y, 260));
  Mf.Add(Btn('U Word…', 'macro:' + MacroWord, 16, Y + 36, 260));
  Mf.Add(Btn('Napravi račun za sljedeću fazu', 'macro:' + MacroInvoice, 16, Y + 72, 260));
  Mf.Add(Lab('Stvarni troškovi:', Mf.Width - 330, Y + 52, 100));
  Mf.Add(Calc('txtTroskovi', '=Nz(DSum("iznos", "ugovor_troskovi", "ugovor_id = " & [id]), 0)', '#,##0.00 "€"', Mf.Width - 230, Y + 52, 120, False));
  Mf.Add(Btn('Provjeri prekoračenje', 'macro:' + MacroOverrun, Mf.Width - 330, Y + 82, 310));
  Mf.Height := Y + 122;
  Finish(Mf);
end;

{ ---------------- tablice i primjer ---------------- }

{ poruke makroa pri izradi primjera ne smiju otvarati dijaloge }
procedure QuietMessage(const AMsg: string);
begin
end;

procedure Sample(ADb: TAppDb; ALog: TStrings);
var
  Ctx: TaScriptContext;
  Old: procedure(const AMsg: string);
begin
  Old := OnScriptMessage;
  OnScriptMessage := @QuietMessage;
  Exec(ADb, 'INSERT INTO ponude_posla (broj, datum, partner_id, naziv, vrsta, status, avans_postotak, prekoracenje_postotak, rok_pocetka, rok_zavrsetka, uvjeti) VALUES ' +
    '(''P-2026-001'', ''2026-03-10'', 1, ''Adaptacija kupaonice'', ''Osnovna'', ''poslana'', 30, 10, ''2026-04-01'', ''2026-05-15'', ' +
    '''Dodatni troškovi (odvoz šute, parkiranje, struja i voda na gradilištu) padaju na Naručitelja i obračunavaju se po stvarnom trošku uz račun.'')');
  Exec(ADb, 'INSERT INTO ponude_posla_faze (ponuda_id, redni, naziv, rok) VALUES (1, 1, ''Priprema i rušenje'', ''2026-04-10''), (1, 2, ''Instalacije i keramika'', ''2026-04-30''), (1, 3, ''Završni radovi'', ''2026-05-15'')');
  Exec(ADb, 'INSERT INTO ponude_posla_stavke (ponuda_id, vrsta, faza, opis, kolicina, jmj, cijena, iznos) VALUES ' +
    '(1, ''Usluga'', 1, ''Rušenje i priprema podloge'', 1, ''kom'', 600, 600), ' +
    '(1, ''Usluga'', 2, ''Keramičarski radovi'', 18, ''m2'', 28, 504), ' +
    '(1, ''Usluga'', 2, ''Vodoinstalaterski radovi'', 1, ''kom'', 450, 450), ' +
    '(1, ''Materijal'', 2, ''Keramičke pločice'', 18, ''m2'', 22, 396), ' +
    '(1, ''Materijal'', 3, ''Sanitarije (komplet)'', 1, ''kom'', 780, 780), ' +
    '(1, ''Usluga'', 3, ''Montaža i završni radovi'', 1, ''kom'', 350, 350)');
  Exec(ADb, 'INSERT INTO ponude_posla (broj, datum, partner_id, naziv, parent_id, vrsta, status, avans_postotak, prekoracenje_postotak, rok_pocetka, rok_zavrsetka, uvjeti) VALUES ' +
    '(''P-2026-001-D1'', ''2026-04-20'', 1, ''Dodatni radovi: podno grijanje'', 1, ''Dodatna'', ''poslana'', 0, 5, ''2026-04-25'', ''2026-05-20'', ''Isti uvjeti kao u osnovnoj ponudi.'')');
  Exec(ADb, 'INSERT INTO ponude_posla_stavke (ponuda_id, vrsta, faza, opis, kolicina, jmj, cijena, iznos) VALUES ' +
    '(2, ''Usluga'', 1, ''Polaganje podnog grijanja'', 1, ''kom'', 420, 420), (2, ''Materijal'', 1, ''Grijaće cijevi i razdjelnik'', 1, ''kom'', 380, 380)');
  { ugovor i aneks nastaju istim makroima kao i pritiskom na gumb }
  Ctx := TaScriptContext.Create(ADb);
  try
    RunMacro(Ctx, OffersMacroText(MacroContract, 1));
    RunMacro(Ctx, OffersMacroText(MacroAnnex, 2));
  finally
    OnScriptMessage := Old;
    Ctx.Free;
  end;
  ALog.Add('upisani primjeri: ponuda, dodatna ponuda, ugovor i aneks');
end;

function BuildOffersTemplate(ADb: TAppDb; ASample: Boolean; ALog: TStrings): Boolean;
var
  Fresh, NeedDoc: Boolean;
  Tb: TStringList;
begin
  Result := False;
  { partneri, artikli i racuni (iz predloska Dokument sa stavkama): primatelji ugovora i racuni za faze }
  Tb := ADb.UserTables;
  try
    NeedDoc := (Tb.IndexOf('racuni') < 0) or (Tb.IndexOf('racuni_stavke') < 0) or (Tb.IndexOf('artikli') < 0) or (Tb.IndexOf('partneri') < 0);
  finally
    Tb.Free;
  end;
  { postojeci racuni i njihova forma se ne diraju (mogu imati vlastite gumbe) }
  if NeedDoc and not ApplyBizTemplate(ADb, 'dokument', 'Račun', ASample, ALog) then Exit;
  Fresh := EnsureTable(ADb, ALog, 'ponude_posla', [
    'id|AutoNumber', 'broj|Text|||R', 'datum|Date|Today()||R', 'partner_id|Integer||partneri.id|R', 'naziv|Text|||R',
    'vrsta|Text|''Osnovna''', 'parent_id|Integer||ponude_posla.id|', 'status|Text|''nacrt''',
    'avans_postotak|Decimal/0|30', 'prekoracenje_postotak|Decimal/0|5', 'rok_pocetka|Date', 'rok_zavrsetka|Date', 'uvjeti|Memo']);
  EnsureTable(ADb, ALog, 'ponude_posla_stavke', [
    'id|AutoNumber', 'ponuda_id|Integer||ponude_posla.id|RC', 'vrsta|Text|''Usluga''', 'faza|Integer|1', 'opis|Text|||R',
    'kolicina|Decimal|1|', 'jmj|Text', 'cijena|Decimal/4|0', 'iznos|Currency|0']);
  EnsureTable(ADb, ALog, 'ponude_posla_faze', [
    'id|AutoNumber', 'ponuda_id|Integer||ponude_posla.id|RC', 'redni|Integer|1', 'naziv|Text', 'rok|Date']);
  EnsureTable(ADb, ALog, 'ugovori', [
    'id|AutoNumber', 'broj|Text|||R', 'datum|Date|Today()||R', 'vrsta|Text|''Ugovor''', 'partner_id|Integer||partneri.id|R',
    'ponuda_id|Integer||ponude_posla.id|', 'parent_id|Integer||ugovori.id|', 'naziv|Text', 'ukupno|Currency|0',
    'avans_postotak|Decimal/0|30', 'prekoracenje_postotak|Decimal/0|5', 'rok_pocetka|Date', 'rok_zavrsetka|Date', 'status|Text|''na snazi''', 'uvjeti|Memo']);
  EnsureTable(ADb, ALog, 'ugovor_faze', [
    'id|AutoNumber', 'ugovor_id|Integer||ugovori.id|RC', 'redni|Integer|1', 'naziv|Text', 'rok|Date', 'iznos|Currency|0', 'racun_id|Integer||racuni.id|']);
  EnsureTable(ADb, ALog, 'ugovor_troskovi', [
    'id|AutoNumber', 'ugovor_id|Integer||ugovori.id|RC', 'datum|Date|Today()', 'opis|Text|||R', 'iznos|Currency|0']);
  SetRule(ADb, 'ponude_posla', 'avans_postotak', '[avans_postotak] >= 0 And [avans_postotak] <= 100', 'Avans je između 0 i 100 %.');
  SetRule(ADb, 'ponude_posla', 'prekoracenje_postotak', '[prekoracenje_postotak] >= 0 And [prekoracenje_postotak] <= 100', 'Dopušteno prekoračenje je između 0 i 100 %.');
  SetRule(ADb, 'ponude_posla_stavke', 'kolicina', '[kolicina] > 0', 'Količina mora biti veća od nule.');
  BuildForms(ADb, ALog);
  ADb.SaveObject('_sys_macros', MacroContract, MacroText(MacroContract));
  ADb.SaveObject('_sys_macros', MacroAddendumOffer, MacroText(MacroAddendumOffer));
  ADb.SaveObject('_sys_macros', MacroAnnex, MacroText(MacroAnnex));
  ADb.SaveObject('_sys_macros', MacroPrint, MacroText(MacroPrint));
  ADb.SaveObject('_sys_macros', MacroWord, MacroText(MacroWord));
  ADb.SaveObject('_sys_macros', MacroInvoice, MacroText(MacroInvoice));
  ADb.SaveObject('_sys_macros', MacroOverrun, MacroText(MacroOverrun));
  ALog.Add('makroi (blokovi): ' + MacroContract + ', ' + MacroAddendumOffer + ', ' + MacroAnnex + ', ' + MacroPrint + ', ' + MacroWord + ', ' + MacroInvoice + ', ' + MacroOverrun);
  SaveLetters(ADb, ALog);
  if Fresh and ASample then Sample(ADb, ALog);
  Result := True;
end;

initialization
  BizOffersHook := @BuildOffersTemplate;

end.
