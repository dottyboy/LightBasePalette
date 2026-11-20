unit ta_showcase2;
{ "Trgovina Jadran 2": ista trgovina kao u prvom primjeru (ta_showcase), ali s objedinjenim dokumentima.
  Ponude, narudzbenice, otpremnice i predracuni nisu vise odvojene tablice i forme nego jedna forma "Dokument" s
  vrstama iz tablice "dokumenti" (pon, nar, otp, pred i revers rv; otpremnica i revers se medjusobno iskljucuju).
  Izbornik je bocni (skupine koje se sklapaju), a aplikacija u radu otvara forme kao kartice.
  Prvi primjer ostaje nepromijenjen, kao primjer klasicnog rjesenja s posebnom formom za svaku vrstu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ZDataset, ta_meta;

function BuildShowcaseUnified(ADb: TAppDb; ALog: TStrings): Boolean;

implementation

uses
  ta_formdef, ta_bizgen, ta_doctypes, ta_switchgen, ta_showcase, ta_blocks, ta_app;

const
  { stara tablica, nova vrsta, naziv }
  OldTypes: array[0..3] of record Tbl, Code, Name, Plural, Sing: string; end = (
    (Tbl: 'ponude'; Code: 'pon'; Name: 'Ponuda'; Plural: 'Ponude'; Sing: 'Ponuda'),
    (Tbl: 'narudzbenice'; Code: 'nar'; Name: 'Narudžbenica'; Plural: 'Narudžbenice'; Sing: 'Narudžbenica'),
    (Tbl: 'otpremnice'; Code: 'otp'; Name: 'Otpremnica'; Plural: 'Otpremnice'; Sing: 'Otpremnica'),
    (Tbl: 'predracuni'; Code: 'pred'; Name: 'Predračun'; Plural: 'Predračuni'; Sing: 'Predračun'));

procedure Exec(ADb: TAppDb; const ASql: string);
begin
  ADb.Conn.ExecuteDirect(ASql);
end;

procedure Cmd(P: TaBlockProgram; const AVerb, AArg: string);
begin
  P.Add(NewCommandBlock(AVerb, AArg));
end;

procedure Com(P: TaBlockProgram; const ATxt: string);
begin
  P.Add(NewCommentBlock(ATxt));
end;

procedure SaveMacro(ADb: TAppDb; ALog: TStrings; const AName: string; P: TaBlockProgram);
begin
  ADb.SaveObject('_sys_macros', AName, P.Text);
  ALog.Add('makro (blokovi): ' + AName);
  P.Free;
end;

procedure DropObjects(ADb: TAppDb; const ATable: string; const ANames: array of string);
var
  I: Integer;
begin
  for I := 0 to High(ANames) do
    if ADb.LoadObject(ATable, ANames[I]) <> '' then ADb.DeleteObject(ATable, ANames[I]);
end;

{ podaci iz odvojenih tablica prelaze u dokument / dokument_stavke }
procedure MigrateDocuments(ADb: TAppDb; ALog: TStrings);
var
  I, N: Integer;
  T: TaDocType;
  Q: TZQuery;
begin
  for I := 0 to High(OldTypes) do
  begin
    with OldTypes[I] do
    begin
      Exec(ADb, 'INSERT INTO dokument (vrsta, broj, datum, dospijece, partner_id, napomena) SELECT ' + ADb.QuoteLit(Code) +
        ', broj, datum, dospijece, partner_id, napomena FROM ' + Tbl + ' ORDER BY id');
      Exec(ADb, 'INSERT INTO dokument_stavke (dokument_id, artikl_id, opis, kolicina, jmj, cijena, rabat, pdv_stopa, iznos) ' +
        'SELECT d.id, s.artikl_id, s.opis, s.kolicina, s.jmj, s.cijena, s.rabat, s.pdv_stopa, s.iznos FROM ' + Tbl + '_stavke s ' +
        'JOIN ' + Tbl + ' o ON o.id = s.dokument_id JOIN dokument d ON d.vrsta = ' + ADb.QuoteLit(Code) + ' AND d.broj = o.broj');
      Q := ADb.NewQuery('SELECT COUNT(*) FROM dokument WHERE vrsta = ' + ADb.QuoteLit(Code));
      try
        Q.Open;
        N := Q.Fields[0].AsInteger;
      finally
        Q.Free;
      end;
      { brojac nastavlja od broja dokumenata: sljedeci novi dokument je N + 1 }
      if DocTypeLoad(ADb, Code, T) then
      begin
        T.Last := N;
        T.Year := DocCurrentYear;
        DocTypeSave(ADb, T);
      end;
      Exec(ADb, 'DROP TABLE ' + Tbl + '_stavke');
      Exec(ADb, 'DROP TABLE ' + Tbl);
      ALog.Add('dokumenti ' + Code + ': prenijeto ' + IntToStr(N) + ' iz tablice ' + Tbl);
    end;
  end;
end;

procedure ReplaceMacros(ADb: TAppDb; ALog: TStrings);
var
  P: TaBlockProgram;
begin
  { narudzbenica po minimumima: broj iz tablice dokumenti (makro-recept za redne brojeve) }
  P := TaBlockProgram.Create;
  Com(P, 'Narudžbenica za artikle ispod minimalne zalihe; broj se uzima iz tablice dokumenti (rednidok + 1)');
  Cmd(P, 'fetch', 'n = SELECT COUNT(*) FROM artikli a WHERE a.aktivan = 1 AND COALESCE((SELECT SUM(CASE WHEN d.tip = ''Primka'' THEN k.kolicina ELSE -k.kolicina END) FROM skl_stavke k JOIN skl_dokumenti d ON d.id = k.dokument_id WHERE k.artikl_id = a.id), 0) < a.min_zaliha');
  P.Add(NewStructBlock(bkIfBlock, '[n] = 0'));
  Cmd(P, 'msg', 'Nijedan artikl nije ispod minimalne zalihe.');
  Cmd(P, 'stop', '');
  P.Add(NewStructBlock(bkEndIf, ''));
  Cmd(P, 'sql', 'UPDATE dokumenti SET rednidok = CASE WHEN godina = CAST(strftime(''%Y'', ''now'') AS INTEGER) THEN rednidok + 1 ELSE 1 END, godina = CAST(strftime(''%Y'', ''now'') AS INTEGER) WHERE vrsta = ''nar''');
  Cmd(P, 'sql', 'INSERT INTO dokument (vrsta, broj, datum, dospijece, partner_id, napomena) SELECT vrsta, sifradok || ''-'' || godina || ''-'' || printf(''%04d'', rednidok), date(''now''), date(''now'', ''+14 days''), 1, ''Automatska narudžba po minimalnim zalihama'' FROM dokumenti WHERE vrsta = ''nar''');
  Cmd(P, 'fetch', 'nid = SELECT MAX(id) FROM dokument');
  Cmd(P, 'copyrows', 'artikli WHERE aktivan = 1 AND COALESCE((SELECT SUM(CASE WHEN d.tip = ''Primka'' THEN k.kolicina ELSE -k.kolicina END) FROM skl_stavke k JOIN skl_dokumenti d ON d.id = k.dokument_id WHERE k.artikl_id = artikli.id), 0) < min_zaliha -> dokument_stavke : dokument_id = {nid}, artikl_id = id, opis = naziv, kolicina = min_zaliha * 2, jmj = jmj, cijena = nabavna_cijena, rabat = 0, pdv_stopa = pdv_stopa, iznos = ROUND(min_zaliha * 2 * nabavna_cijena, 2)');
  Cmd(P, 'msg', 'Napravljena je narudžbenica s {kopirano} artikala (otvori je u izborniku: Narudžbenice).');
  SaveMacro(ADb, ALog, 'Narudžbenica po minimumima', P);

  P := TaBlockProgram.Create;
  Com(P, 'Račun iz ponude: ponuda (vrsta pon u objedinjenoj formi) kopira se u račun s istim stavkama');
  Cmd(P, 'input', 'Broj ponude (npr. pon-2026-0001):');
  Cmd(P, 'fetch', 'pid = SELECT id FROM dokument WHERE vrsta = ''pon'' AND broj = {unos}');
  P.Add(NewStructBlock(bkIfBlock, 'IsNull([pid])'));
  Cmd(P, 'msg', 'Nema ponude s tim brojem.');
  Cmd(P, 'stop', '');
  P.Add(NewStructBlock(bkEndIf, ''));
  Cmd(P, 'copyrows', 'dokument WHERE id = {pid} -> racuni : broj = ''R-'' || broj, datum = date(''now''), dospijece = date(''now'', ''+15 days''), partner_id = partner_id, placeno = 0, napomena = ''Po ponudi '' || broj');
  Cmd(P, 'fetch', 'rid = SELECT MAX(id) FROM racuni');
  Cmd(P, 'copyrows', 'dokument_stavke WHERE dokument_id = {pid} -> racuni_stavke : dokument_id = {rid}, artikl_id = artikl_id, opis = opis, kolicina = kolicina, jmj = jmj, cijena = cijena, rabat = rabat, pdv_stopa = pdv_stopa, iznos = iznos');
  Cmd(P, 'msg', 'Napravljen je račun s {kopirano} stavki iz ponude {unos}.');
  SaveMacro(ADb, ALog, 'Račun iz ponude', P);
end;

{ izbornik: stare stavke osim odvojenih dokumenata, koji postaju stavke objedinjene forme }
procedure RebuildMenu(ADb: TAppDb; ALog: TStrings);
var
  Old, Def: TaFormDef;
  Items: TStringList;
  I, K: Integer;
  C: TaControlDef;
  Line, Act: string;
  Skip, Added: Boolean;
begin
  Old := TaFormDef.Create;
  Items := TStringList.Create;
  try
    Old.FromJson(ADb.LoadObject('_sys_forms', 'Izbornik'));
    for I := 0 to Old.Count - 1 do
    begin
      C := Old[I];
      if (C.Kind = 'Label') and (Pos('lblGrupa', C.Name) = 1) then Items.Add('# ' + C.Caption)
      else if (C.Kind = 'Button') and (C.OnClick <> '') then
      begin
        Act := C.OnClick;
        Skip := False;
        Added := False;
        for K := 0 to High(OldTypes) do
          if (Act = 'openform:' + OldTypes[K].Plural) then
          begin
            Items.Add(OldTypes[K].Plural + '|openform:Dokument#vrsta=' + OldTypes[K].Code);
            if OldTypes[K].Code = 'otp' then Items.Add('Reversi|openform:Dokument#vrsta=rv');
            Added := True;
          end
          else if Pos(OldTypes[K].Plural + ' po razdoblju', Act) > 0 then Skip := True;
        if (not Added) and (not Skip) then Items.Add(C.Caption + '|' + Act);
      end;
    end;
    { pregled svih dokumenata po razdoblju i vrsti }
    for I := 0 to Items.Count - 1 do
      if Pos('Računi po razdoblju', Items[I]) = 1 then
      begin
        Items.Insert(I + 1, 'Dokumenti po razdoblju|openreport:Dokumenti po razdoblju');
        Break;
      end;
    Def := BuildSideBoard('Izbornik', 'Trgovina Jadran', Items);
    SaveForm(ADb, ALog, Def);
    ALog.Add('izbornik: bočni izbornik s objedinjenim dokumentima');
  finally
    Items.Free;
    Old.Free;
  end;
  Line := '';
end;

function BuildShowcaseUnified(ADb: TAppDb; ALog: TStrings): Boolean;
var
  I: Integer;
  T: TaDocType;
begin
  Result := BuildShowcase(ADb, ALog);
  if not Result then Exit;
  try
    ApplyBizTemplate(ADb, 'dokumenti_obj', '', False, ALog);
    { racuni ostaju zasebna forma (uplate, prodavac, dostava): izlaze iz vrsta objedinjene forme }
    DocTypeDelete(ADb, 'rac');
    ADb.Conn.StartTransaction;
    try
      MigrateDocuments(ADb, ALog);
      ADb.Conn.Commit;
    except
      ADb.Conn.Rollback;
      raise;
    end;
    { revers: prazna vrsta koja se isklucuje s otpremnicom (vec upisano predloskom) }
    if DocTypeLoad(ADb, 'rv', T) then ALog.Add('vrsta rv (revers) ' + T.Related);
    for I := 0 to High(OldTypes) do
    begin
      DropObjects(ADb, '_sys_forms', [OldTypes[I].Plural]);
      DropObjects(ADb, '_sys_reports', [OldTypes[I].Sing + ' - ispis', OldTypes[I].Plural + ' po razdoblju']);
      DropObjects(ADb, '_sys_queries', [OldTypes[I].Tbl + ' - ispis podaci', OldTypes[I].Plural + ' po razdoblju']);
    end;
    ReplaceMacros(ADb, ALog);
    RebuildMenu(ADb, ALog);
    ALog.Add('Trgovina Jadran 2: ponude, narudžbenice, otpremnice i predračuni su vrste objedinjene forme Dokument');
  except
    on E: Exception do
    begin
      ALog.Add('GREŠKA: ' + E.Message);
      Result := False;
    end;
  end;
end;

end.
