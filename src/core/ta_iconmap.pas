unit ta_iconmap;
{ Pridruzivanje ikona: za polje (po nazivu i vrsti), za objekt (tablica, forma, upit, izvjesce...) i za radnju gumba.
  Vraca NAZIV ikone iz zalihe (ikone/indeks.csv); prazno = nema pogodne ikone.
  Pravila su nizovi kljucnih rijeci (dijelovi naziva bez dijakritika i velikih slova), prvo poklapanje vrijedi. }

{$mode objfpc}{$H+}

interface

uses
  ta_formdef;

{ mala slova i bez dijakritika (č ć š ž đ) i razmaka -> "_" }
function IconFold(const S: string): string;

{ AType: logicki tip polja (Text, Memo, Integer, Decimal, Currency, Date, YesNo, AutoNumber...) ili SQL tip }
function FieldIconName(const AField, AType: string): string;

{ AKind: table, form, query, report, letter, module, macro, program }
function ObjectIconName(const AKind, AName: string): string;

{ radnja gumba ili stavke izbornika: openform:X, openreport:X, macro:X, new, save, delete... i natpis }
function ActionIconName(const AAction, ACaption: string): string;

{ gumb bez ikone dobiva onu koja pristaje radnji i natpisu }
procedure AutoButtonIcon(D: TaControlDef);

{ pravila za provjeru (testovi): koliko ih je i koje ikone koriste }
function IconRuleCount: Integer;
function IconRuleTarget(AIndex: Integer): string;

implementation

uses
  SysUtils, LazUTF8;

type
  TRule = record
    Keys: string;      { kljucne rijeci odvojene zarezom; "=" ispred = cijeli naziv, "^" = pocetak, "$" = kraj }
    Icon: string;
  end;

const
  FieldRules: array[0..52] of TRule = (
    (Keys: '=oib,oib_'; Icon: 'idcard'),
    (Keys: 'iban,racun_banke,ziro'; Icon: 'bankcard'),
    (Keys: 'email,e_mail,mail'; Icon: 'f_email'),
    (Keys: 'telefon,mobitel,^tel,fax,gsm'; Icon: 'f_phone'),
    (Keys: '=web,url,www,stranica'; Icon: 'f_url'),
    (Keys: 'adresa,ulica,mjesto,=grad,postanski,drzava,lokacija,relacija'; Icon: 'location'),
    (Keys: '$_id,=id_'; Icon: ''),                       { posebno: veze, obradeno u kodu }
    (Keys: 'pdv,rabat,popust,marza,postotak,kamat,stopa,prekoracenje'; Icon: 'f_percent'),
    (Keys: 'datum,rok,dospijece,rodjen,zaposlen,^od$,=do,pocetak,zavrsetak,kraj_'; Icon: 'f_date'),
    (Keys: 'vrijeme,sat,trajanje'; Icon: 'clock'),
    (Keys: 'iznos,cijena,ukupno,osnovica,placa,trosak,dnevnica,saldo,uplata,isplata,dug,avans,vrijednost,nabavna,prodajna,zarada,dostava,vozarina,porez'; Icon: 'f_currency'),
    (Keys: 'kolicina,zaliha,stanje,komada,prodano,racuna,stavki,broj_'; Icon: 'f_quantity'),
    (Keys: '=jmj,jedinica,mjera'; Icon: 'f_unit'),
    (Keys: 'sifra,=broj,=id,^rbr,redni,barkod,kod_'; Icon: 'f_id'),
    (Keys: 'napomena,uvjeti,biljeska,komentar,opis,tekst,sadrzaj,poruka,tijelo'; Icon: 'f_memo'),
    (Keys: 'slika,logo,foto,fotografija'; Icon: 'f_image'),
    (Keys: 'boja'; Icon: 'f_color'),
    (Keys: 'sql,izraz,formula,kod,skripta'; Icon: 'f_code'),
    (Keys: 'aktivan,placeno,isporucena,potpisana,prihvacena,isplaceno,zakljucan,arhiviran,vazi,odobreno'; Icon: 'f_bool'),
    (Keys: 'status,stanje_'; Icon: 'f_status'),
    (Keys: 'nacin_placanja,placanje,nacin'; Icon: 'payment'),
    (Keys: 'prezime,ime,naziv,natpis,naslov,svrha,vrsta,tip,kontakt,osoba'; Icon: 'f_text'),
    (Keys: 'radno_mjesto,odjel,funkcija,uloga,zanimanje'; Icon: 'employee'),
    (Keys: 'kategorija'; Icon: 'category'),
    (Keys: 'faza,etapa'; Icon: 'milestone'),
    (Keys: 'km,cijena_km,vozilo,registracija'; Icon: 'car'),
    (Keys: 'rezultat,primjer,potpis'; Icon: 'f_code'),
    (Keys: 'skupina,grupa'; Icon: 'group'),
    (Keys: 'korisnik,lozinka'; Icon: 'user'),
    (Keys: 'zadnji_racun,posljednji'; Icon: 'invoice'),
    (Keys: 'razred'; Icon: 'star'),
    (Keys: 'dana_kasnjenja,kasnjenje'; Icon: 'overdue'),
    (Keys: 'arhivirano'; Icon: 'archive'),
    (Keys: 'poruka,izvor'; Icon: 'f_text'),
    (Keys: 'lbl'; Icon: 'f_text'),
    (Keys: 'tezina,masa'; Icon: 'f_number'),
    (Keys: 'visina,sirina,duzina,volumen,promjer'; Icon: 'f_number'),
    (Keys: 'godina,mjesec'; Icon: 'f_date'),
    (Keys: 'dnevnice_broj,dnevnica_iznos'; Icon: 'f_currency'),
    (Keys: 'ostali_troskovi'; Icon: 'cost'),
    (Keys: 'rb,rbr'; Icon: 'f_id'),
    (Keys: 'marza_posto'; Icon: 'f_percent'),
    (Keys: 'najvise,granica,limit'; Icon: 'f_currency'),
    (Keys: 'ugovoreno'; Icon: 'contract'),
    (Keys: 'uplaceno'; Icon: 'payment'),
    (Keys: 'najmanje,minimum,min_'; Icon: 'f_quantity'),
    (Keys: 'parent,roditelj,osnovni'; Icon: 'f_link'),
    (Keys: 'ponuda'; Icon: 'offer'),
    (Keys: 'ugovor'; Icon: 'contract'),
    (Keys: 'racun'; Icon: 'invoice'),
    (Keys: 'artikl,proizvod,roba'; Icon: 'article'),
    (Keys: 'partner,kupac'; Icon: 'customer'),
    (Keys: 'dobavlja'; Icon: 'supplier'));

  { veze (*_id): koji objekt pokazuju }
  LinkRules: array[0..14] of TRule = (
    (Keys: 'kupac,kupc,partner'; Icon: 'customer'),
    (Keys: 'dobavlja'; Icon: 'supplier'),
    (Keys: 'zaposlenik,radnik,prodavac'; Icon: 'employee'),
    (Keys: 'artikl,proizvod'; Icon: 'article'),
    (Keys: 'kategorij'; Icon: 'category'),
    (Keys: 'racun'; Icon: 'invoice'),
    (Keys: 'ponud'; Icon: 'offer'),
    (Keys: 'narudzb'; Icon: 'order'),
    (Keys: 'otpremn'; Icon: 'deliverynote'),
    (Keys: 'ugovor'; Icon: 'contract'),
    (Keys: 'faz'; Icon: 'milestone'),
    (Keys: 'korisnik'; Icon: 'user'),
    (Keys: 'skladis,skl'; Icon: 'warehouse'),
    (Keys: 'dokument'; Icon: 'list'),
    (Keys: 'putni,nalog'; Icon: 'suitcase'));

  ObjectRules: array[0..45] of TRule = (
    (Keys: 'izbornik'; Icon: 'home'),
    (Keys: 'naljepnic'; Icon: 'labels'),
    (Keys: 'cjenik'; Icon: 'pricetag'),
    (Keys: 'opomen'; Icon: 'bell'),
    (Keys: 'zahvalnic'; Icon: 'star'),
    (Keys: 'predracun'; Icon: 'proforma'),
    (Keys: 'otpremn'; Icon: 'deliverynote'),
    (Keys: 'narudzb'; Icon: 'order'),
    (Keys: 'ponud'; Icon: 'offer'),
    (Keys: 'aneks'; Icon: 'annex'),
    (Keys: 'ugovor'; Icon: 'contract'),
    (Keys: 'racun'; Icon: 'invoice'),
    (Keys: 'uplat'; Icon: 'payment'),
    (Keys: 'blagajn'; Icon: 'cashbook'),
    (Keys: 'skladis,skl_,zaliha,zalih,stanje'; Icon: 'warehouse'),
    (Keys: 'putni'; Icon: 'suitcase'),
    (Keys: 'zaposlen,placa,place,radnik'; Icon: 'employee'),
    (Keys: 'dobavlja'; Icon: 'supplier'),
    (Keys: 'kupac,kupc,partner'; Icon: 'customer'),
    (Keys: 'kontakt'; Icon: 'users'),
    (Keys: 'artik,proizvod'; Icon: 'article'),
    (Keys: 'kategorij'; Icon: 'category'),
    (Keys: 'marza'; Icon: 'percent'),
    (Keys: 'najbolj,top_,top '; Icon: 'trophy'),
    (Keys: 'prodaj'; Icon: 'linechart'),
    (Keys: 'nepla,kasnj,dug'; Icon: 'overdue'),
    (Keys: 'razdoblj'; Icon: 'calendar'),
    (Keys: 'pregled'; Icon: 'dashboard'),
    (Keys: 'trosk'; Icon: 'cost'),
    (Keys: 'faz'; Icon: 'milestone'),
    (Keys: 'dnevnik,revizij,povijest'; Icon: 'history'),
    (Keys: 'arhiv'; Icon: 'archive'),
    (Keys: 'obavijest,biljesk,napomen'; Icon: 'note'),
    (Keys: 'primjeri_funkcij,funkcij'; Icon: 'f_code'),
    (Keys: 'uvoz'; Icon: 'import'),
    (Keys: 'izvoz'; Icon: 'export'),
    (Keys: 'sigurnos,kopij,backup'; Icon: 'save'),
    (Keys: 'sazet,sazetak'; Icon: 'sigma'),
    (Keys: 'povecaj,cijen'; Icon: 'percent'),
    (Keys: 'zakljuc'; Icon: 'archive'),
    (Keys: 'provjer'; Icon: 'shield'),
    (Keys: '_stavke,^stavke'; Icon: 'list'),
    (Keys: 'ispis,pdf'; Icon: 'print'),
    (Keys: 'e-posta,=posta,mail'; Icon: 'send'),
    (Keys: 'oznaci,placen'; Icon: 'checkcircle'),
    (Keys: 'unakrsn'; Icon: 'grid'));

  ActionRules: array[0..26] of TRule = (
    (Keys: '=new,=add,novi zapis,^novi,^nova,dodaj'; Icon: 'add'),
    (Keys: '=save,spremi'; Icon: 'save'),
    (Keys: '=delete,brisi,obrisi'; Icon: 'delete'),
    (Keys: '=close,zatvori'; Icon: 'close'),
    (Keys: '=first'; Icon: 'first'),
    (Keys: '=prior,=prev'; Icon: 'prev'),
    (Keys: '=next'; Icon: 'next'),
    (Keys: '=last'; Icon: 'last'),
    (Keys: '=undo,ponisti'; Icon: 'undo'),
    (Keys: '=refresh,=requery,osvjezi'; Icon: 'refresh'),
    (Keys: '=duplicate,kopiraj,dupliciraj'; Icon: 'duplicate'),
    (Keys: 'export,izvoz'; Icon: 'export'),
    (Keys: 'import,uvoz'; Icon: 'import'),
    (Keys: 'print,ispis'; Icon: 'print'),
    (Keys: 'pdf'; Icon: 'pdf'),
    (Keys: 'word,docx'; Icon: 'word'),
    (Keys: 'html'; Icon: 'html'),
    (Keys: 'pregled,preview'; Icon: 'preview'),
    (Keys: 'trazi,pretraz,search,find'; Icon: 'search'),
    (Keys: 'filter,filtr'; Icon: 'filter'),
    (Keys: 'sort,poredak'; Icon: 'sortasc'),
    (Keys: 'pomoc,help'; Icon: 'help'),
    (Keys: 'postavke,settings'; Icon: 'settings'),
    (Keys: 'mailto,posalji,email'; Icon: 'send'),
    (Keys: 'backup,kopija baze,sigurnosn'; Icon: 'save'),
    (Keys: 'audit,povijest'; Icon: 'history'),
    (Keys: 'racun za'; Icon: 'invoice'));

function IconFold(const S: string): string;
begin
  Result := UTF8LowerCase(S);
  Result := StringReplace(Result, 'č', 'c', [rfReplaceAll]);
  Result := StringReplace(Result, 'ć', 'c', [rfReplaceAll]);
  Result := StringReplace(Result, 'š', 's', [rfReplaceAll]);
  Result := StringReplace(Result, 'ž', 'z', [rfReplaceAll]);
  Result := StringReplace(Result, 'đ', 'd', [rfReplaceAll]);
  Result := Trim(Result);
end;

{ jedan kljuc proti imenu }
function KeyMatches(const AKey, AName: string): Boolean;
var
  K: string;
begin
  K := AKey;
  if K = '' then Exit(False);
  if K[1] = '=' then Exit(AName = Copy(K, 2, MaxInt));
  if (K[1] = '^') and (K[Length(K)] = '$') then Exit(AName = Copy(K, 2, Length(K) - 2));
  if K[1] = '^' then Exit(Copy(AName, 1, Length(K) - 1) = Copy(K, 2, MaxInt));
  if K[Length(K)] = '$' then Exit((Length(AName) >= Length(K) - 1) and (Copy(AName, Length(AName) - Length(K) + 2, MaxInt) = Copy(K, 1, Length(K) - 1)));
  if K[1] = '$' then Exit((Length(AName) >= Length(K) - 1) and (Copy(AName, Length(AName) - Length(K) + 2, MaxInt) = Copy(K, 2, MaxInt)));
  Result := Pos(K, AName) > 0;
end;

function Lookup(const ARules: array of TRule; const AName: string): string;
var
  I, P: Integer;
  Keys, One: string;
begin
  Result := '';
  for I := 0 to High(ARules) do
  begin
    Keys := ARules[I].Keys;
    while Keys <> '' do
    begin
      P := Pos(',', Keys);
      if P = 0 then begin One := Keys; Keys := ''; end
      else begin One := Copy(Keys, 1, P - 1); Keys := Copy(Keys, P + 1, MaxInt); end;
      if (ARules[I].Icon <> '') and KeyMatches(One, AName) then Exit(ARules[I].Icon);
    end;
  end;
end;

function TypeIcon(const AType: string): string;
var
  T: string;
begin
  T := IconFold(AType);
  Result := '';
  if (Pos('autonumber', T) > 0) or (Pos('autoinc', T) > 0) or (Pos('serial', T) > 0) then Result := 'f_id'
  else if (Pos('currency', T) > 0) or (Pos('money', T) > 0) then Result := 'f_currency'
  else if (Pos('date', T) > 0) or (Pos('time', T) > 0) then Result := 'f_date'
  else if (Pos('yesno', T) > 0) or (Pos('bool', T) > 0) then Result := 'f_bool'
  else if (Pos('memo', T) > 0) or (Pos('blob', T) > 0) or (T = 'longtext') then Result := 'f_memo'
  else if (Pos('image', T) > 0) or (Pos('picture', T) > 0) then Result := 'f_image'
  else if (Pos('int', T) > 0) or (Pos('decimal', T) > 0) or (Pos('real', T) > 0) or (Pos('float', T) > 0) or
          (Pos('numer', T) > 0) or (Pos('double', T) > 0) then Result := 'f_number'
  else if (Pos('text', T) > 0) or (Pos('char', T) > 0) or (Pos('string', T) > 0) then Result := 'f_text';
end;

function FieldIconName(const AField, AType: string): string;
var
  N, Base: string;
begin
  N := IconFold(AField);
  N := StringReplace(N, ' ', '_', [rfReplaceAll]);
  { veza na drugu tablicu: partner_id, artikl_id... }
  if (Length(N) > 3) and (Copy(N, Length(N) - 2, 3) = '_id') then
  begin
    Base := Copy(N, 1, Length(N) - 3);
    Result := Lookup(LinkRules, Base);
    if Result = '' then Result := 'f_link';
    Exit;
  end;
  if (Length(N) > 3) and (Copy(N, 1, 3) = 'id_') then
  begin
    Result := Lookup(LinkRules, Copy(N, 4, MaxInt));
    if Result = '' then Result := 'f_link';
    Exit;
  end;
  Result := Lookup(FieldRules, N);
  { rijec iz naziva "ukupno" itd. daje valutu samo kad je polje broj; za tekst ostaje tip }
  if (Result = 'f_currency') or (Result = 'f_percent') or (Result = 'f_quantity') then
    if (TypeIcon(AType) = 'f_text') or (TypeIcon(AType) = 'f_memo') then Result := '';
  if Result = '' then Result := TypeIcon(AType);
  if Result = '' then Result := 'f_text';
end;

function ObjectIconName(const AKind, AName: string): string;
var
  N, K: string;
begin
  N := IconFold(AName);
  K := LowerCase(AKind);
  Result := Lookup(ObjectRules, N);
  if (K = 'macro') and (Result = '') then Result := 'macro'
  else if (K = 'program') and (Result = '') then Result := 'program'
  else if (K = 'module') and (Result = '') then Result := 'module'
  else if (K = 'query') and (Result = '') then Result := 'query'
  else if (K = 'report') and (Result = '') then Result := 'report'
  else if (K = 'letter') and (Result = '') then Result := 'letter'
  else if (K = 'form') and (Result = '') then Result := 'form'
  else if (K = 'table') and (Result = '') then Result := 'table';
  { objekt je upit/izvjesce nad temom: ikona teme je dobra za sve vrste osim izbornika }
  if Result = '' then Result := 'table';
end;

function ActionIconName(const AAction, ACaption: string): string;
var
  A, Arg, Cap: string;
  P: Integer;
begin
  A := IconFold(AAction);
  Cap := IconFold(ACaption);
  Arg := '';
  P := Pos(':', A);
  if P > 0 then
  begin
    Arg := Trim(Copy(A, P + 1, MaxInt));
    A := Copy(A, 1, P - 1);
  end;
  Result := '';
  if (A = 'openform') or (A = 'openreport') or (A = 'openletter') or (A = 'macro') or (A = 'openquery') then
  begin
    { forma s parametrom (Dokument#vrsta=otp): ikonu daje natpis stavke, ne naziv zajednicke forme }
    if Pos('#', Arg) > 0 then Arg := Cap;
    Result := Lookup(ObjectRules, Arg);
    if Result = '' then Result := Lookup(ActionRules, Cap);
    if Result <> '' then Exit;
    if A = 'openform' then Exit(ObjectIconName('form', Arg));
    if A = 'openreport' then Exit(ObjectIconName('report', Arg));
    if A = 'openletter' then Exit(ObjectIconName('letter', Arg));
    if A = 'macro' then Exit(ObjectIconName('macro', Arg));
    Exit(ObjectIconName('query', Arg));
  end;
  if A = 'run' then Exit('run');
  if A = 'close' then Exit('close');
  Result := Lookup(ActionRules, A);
  if Result = '' then Result := Lookup(ActionRules, Cap);
  if (Result = '') and (Cap <> '') then
  begin
    Result := Lookup(ObjectRules, Cap);
    if Result = 'table' then Result := '';
  end;
end;

procedure AutoButtonIcon(D: TaControlDef);
var
  N: string;
begin
  if (D = nil) or ((D.Kind <> 'Button') and (D.Kind <> 'ToggleButton')) then Exit;
  if D.GetX('icon') <> '' then Exit;
  N := ActionIconName(D.OnClick, D.Caption);
  if N <> '' then D.SetX('icon', N);
end;

function IconRuleCount: Integer;
begin
  Result := Length(FieldRules) + Length(LinkRules) + Length(ObjectRules) + Length(ActionRules);
end;

function IconRuleTarget(AIndex: Integer): string;
begin
  if AIndex < Length(FieldRules) then Exit(FieldRules[AIndex].Icon);
  Dec(AIndex, Length(FieldRules));
  if AIndex < Length(LinkRules) then Exit(LinkRules[AIndex].Icon);
  Dec(AIndex, Length(LinkRules));
  if AIndex < Length(ObjectRules) then Exit(ObjectRules[AIndex].Icon);
  Dec(AIndex, Length(ObjectRules));
  if AIndex < Length(ActionRules) then Exit(ActionRules[AIndex].Icon);
  Result := '';
end;

end.
