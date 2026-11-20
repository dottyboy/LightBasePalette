unit ta_blocksdemo;
{ Primjer aplikacije slozene blokovima: mali obrt s racunima. Tablice, forme i izvjesca dolaze iz
  poslovnog predloska (Dokument sa stavkama), a makroi su slozeni kao blokovi (TaBlockProgram)
  i spremljeni kao obican makro-tekst, pa se mogu otvoriti i u uredjivacu blokova i kao tekst. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta, ta_blocks;

{ Izgradi primjer u otvorenoj bazi. False + poruke u ALog ako nesto ne uspije. }
function BuildBlocksDemo(ADb: TAppDb; ALog: TStrings): Boolean;
{ nazivi makroa primjera }
function BlocksDemoMacros: TStringList;

implementation

uses
  ta_formdef, ta_iconmap, ta_bizgen, ta_switchgen, ta_app, ta_letter, ta_offers;

{ kratice za slaganje blokova }
procedure Com(P: TaBlockProgram; const ATxt: string);
begin
  P.Add(NewCommentBlock(ATxt));
end;

procedure Cmd(P: TaBlockProgram; const AVerb, AArg: string);
begin
  P.Add(NewCommandBlock(AVerb, AArg));
end;

procedure IfB(P: TaBlockProgram; const ACond: string);
begin
  P.Add(NewStructBlock(bkIfBlock, ACond));
end;

procedure ElseB(P: TaBlockProgram);
begin
  P.Add(NewStructBlock(bkElse, ''));
end;

procedure EndIf(P: TaBlockProgram);
begin
  P.Add(NewStructBlock(bkEndIf, ''));
end;

const
  MacroNames: array[0..5] of string = ('Oznaci placenim', 'Sazetak neplacenih', 'Povecaj cijene', 'Cjenik u PDF', 'Kopija baze', 'Opomene u Word');

function BlocksDemoMacros: TStringList;
var
  I: Integer;
begin
  Result := TStringList.Create;
  for I := Low(MacroNames) to High(MacroNames) do Result.Add(MacroNames[I]);
end;

function MacroText(AIndex: Integer): string;
var
  P: TaBlockProgram;
begin
  P := TaBlockProgram.Create;
  try
    case AIndex of
      0:
        begin
          Com(P, 'Gumb na formi Računi: pita pa označi račun plaćenim');
          Cmd(P, 'ask', 'Označiti račun kao plaćen?');
          IfB(P, '[odgovor] = 1');
          Cmd(P, 'set', 'placeno = 1');
          Cmd(P, 'save', '');
          Cmd(P, 'msg', 'Račun je označen kao plaćen.');
          ElseB(P);
          Cmd(P, 'msg', 'Ništa nije promijenjeno.');
          EndIf(P);
        end;
      1:
        begin
          Com(P, 'Koliko je neplaćenih računa i koliki je dug');
          Cmd(P, 'fetch', 'broj = SELECT COUNT(*) FROM racuni WHERE placeno = 0');
          Cmd(P, 'fetch', 'dug = SELECT COALESCE(SUM(s.iznos), 0) FROM racuni_stavke s JOIN racuni r ON r.id = s.dokument_id WHERE r.placeno = 0');
          IfB(P, '[broj] = 0');
          Cmd(P, 'msg', 'Nema neplaćenih računa.');
          ElseB(P);
          Cmd(P, 'msg', 'Neplaćenih računa: {broj}, osnovica ukupno {dug} EUR.');
          EndIf(P);
        end;
      2:
        begin
          Com(P, 'Poskupljenje cjenika za unesen postotak (1 do 50)');
          Cmd(P, 'input', 'Za koliko posto povećati cijene?');
          P.Add(NewLetBlock('p', 'Val([unos])'));
          IfB(P, '[p] >= 1 And [p] <= 50');
          Cmd(P, 'sql', 'UPDATE artikli SET cijena = ROUND(cijena * (1 + {p} / 100.0), 2)');
          Cmd(P, 'msg', 'Cijene su povećane za {p} %.');
          ElseB(P);
          Cmd(P, 'msg', 'Upiši broj od 1 do 50.');
          EndIf(P);
        end;
      3:
        begin
          Com(P, 'Cjenik u PDF, u datoteku koju korisnik upiše');
          Cmd(P, 'input', 'Puna putanja PDF datoteke (npr. /home/ana/cjenik.pdf):');
          IfB(P, '[unos] = ""');
          Cmd(P, 'msg', 'Odustali ste.');
          ElseB(P);
          Cmd(P, 'exportpdf', 'Cjenik > {unos}');
          Cmd(P, 'msg', 'Cjenik je spremljen.');
          EndIf(P);
        end;
      4:
        begin
          Com(P, 'Sigurnosna kopija cijele baze');
          Cmd(P, 'input', 'Puna putanja datoteke za kopiju (npr. /home/ana/obrt-kopija.db):');
          IfB(P, '[unos] = ""');
          Cmd(P, 'msg', 'Odustali ste.');
          ElseB(P);
          Cmd(P, 'backup', '{unos}');
          Cmd(P, 'msg', 'Kopija je spremljena.');
          EndIf(P);
        end;
      5:
        begin
          Com(P, 'Opomene dužnicima u Word dokument (svaki dužnik na novoj stranici)');
          Cmd(P, 'input', 'Puna putanja Word datoteke (npr. /home/ana/opomene.docx):');
          IfB(P, '[unos] = ""');
          Cmd(P, 'msg', 'Odustali ste.');
          ElseB(P);
          Cmd(P, 'exportletter', 'Opomena > {unos}');
          Cmd(P, 'msg', 'Opomene su spremljene.');
          EndIf(P);
        end;
    end;
    Result := P.Text;
  finally
    P.Free;
  end;
end;

{ jos nekoliko neplacenih racuna i dopis "Opomena": za svakog duznika tablica racuna i ukupan dug }
procedure AddDunningSample(ADb: TAppDb; ALog: TStrings);
var
  Lt: TaLetterDef;
  I: Integer;
  Amt: array[0..3] of string;
  Dt: array[0..3] of string;
begin
  Amt[0] := '50'; Amt[1] := '75.5'; Amt[2] := '120'; Amt[3] := '30';
  Dt[0] := '2026-01-12'; Dt[1] := '2026-02-03'; Dt[2] := '2026-02-20'; Dt[3] := '2026-03-08';
  for I := 0 to 3 do
  begin
    Exec(ADb, 'INSERT INTO racuni (broj, datum, dospijece, partner_id, placeno, napomena) VALUES (''2026-10' + IntToStr(I + 1) + ''', ''' + Dt[I] +
      ''', date(''' + Dt[I] + ''', ''+15 days''), 2, 0, ''Primjer'')');
    Exec(ADb, 'INSERT INTO racuni_stavke (dokument_id, artikl_id, opis, kolicina, jmj, cijena, rabat, pdv_stopa, iznos) VALUES ' +
      '((SELECT MAX(id) FROM racuni), 3, ''Usluga'', 1, ''kom'', ' + Amt[I] + ', 0, 25, ' + Amt[I] + ')');
  end;
  Lt := TaLetterDef.Create;
  try
    Lt.Name := 'Opomena';
    Lt.Source := 'partneri';
    Lt.Filter := 'id IN (SELECT partner_id FROM racuni WHERE placeno = 0)';
    Lt.DetailSql := 'SELECT r.broj, r.datum, r.dospijece, ROUND(SUM(s.iznos * (1 + s.pdv_stopa / 100.0)), 2) AS iznos ' +
      'FROM racuni r JOIN racuni_stavke s ON s.dokument_id = r.id WHERE r.partner_id = {id} AND r.placeno = 0 GROUP BY r.id ORDER BY r.datum, r.id';
    Lt.Columns := 'broj|Broj računa||left|2' + LineEnding + 'datum|Datum||left|2' + LineEnding + 'dospijece|Dospijeće||left|2' + LineEnding + 'iznos|Iznos s PDV-om (EUR)|0.00|right|3';
    Lt.TotalField := 'iznos';
    Lt.TotalLabel := 'Ukupno';
    Lt.Body := '#>[firma_naziv]' + LineEnding + '>[firma_adresa], [firma_mjesto]' + LineEnding + '>IBAN: [firma_iban]' + LineEnding + LineEnding +
      '>[firma_mjesto], [datum]' + LineEnding + LineEnding +
      '#[naziv]' + LineEnding + '[adresa]' + LineEnding + '[postanski] [grad]' + LineEnding + LineEnding +
      '#Predmet: opomena za neplaćene račune' + LineEnding + LineEnding +
      'Poštovani,' + LineEnding + LineEnding +
      'uvidom u našu evidenciju utvrdili smo da na dan [datum] imate [stavki] neplaćenih računa koji su navedeni u tablici.' + LineEnding + LineEnding +
      '[tablica]' + LineEnding +
      'Ukupan dug iznosi [ukupno] EUR.' + LineEnding + LineEnding +
      'Molimo da navedeni iznos uplatite na naš IBAN [firma_iban] u roku od osam dana od primitka ovog dopisa. Ako ste uplatu već izvršili, molimo da ovaj dopis smatrate bezpredmetnim.' + LineEnding + LineEnding +
      'S poštovanjem,' + LineEnding + '[firma_naziv]';
    ADb.SaveObject('_sys_letters', Lt.Name, Lt.ToJson);
    ALog.Add('dopis: Opomena');
  finally
    Lt.Free;
  end;
end;

{ gumb "Oznaci placenim" na formi racuna }
procedure AddPaidButton(ADb: TAppDb; ALog: TStrings);
var
  Js: string;
  F: TaFormDef;
  B: TaControlDef;
begin
  Js := ADb.LoadObject('_sys_forms', 'Računi');
  if Js = '' then Exit;
  F := TaFormDef.Create;
  try
    F.FromJson(Js);
    F.Name := 'Računi';
    B := TaControlDef.Create;
    B.Kind := 'Button';
    B.Name := F.UniqueName('btnPlaceno');
    B.Caption := 'Označi plaćenim';
    B.OnClick := 'macro:Oznaci placenim';
    AutoButtonIcon(B);
    B.Left := 10;
    B.Top := F.Height + 6;
    B.Width := 160;
    B.Height := 32;
    F.Add(B);
    F.Height := F.Height + 48;
    SaveForm(ADb, ALog, F);    { SaveForm oslobada definiciju }
    F := nil;
  finally
    F.Free;
  end;
end;

function BuildBlocksDemo(ADb: TAppDb; ALog: TStrings): Boolean;
var
  I: Integer;
  Items: TStringList;
  Def: TaFormDef;
  S: TaAppSettings;
begin
  Result := False;
  if not ApplyBizTemplate(ADb, 'dokument', 'Račun', True, ALog) then Exit;
  for I := Low(MacroNames) to High(MacroNames) do
  begin
    ADb.SaveObject('_sys_macros', MacroNames[I], MacroText(I));
    ALog.Add('makro (blokovi): ' + MacroNames[I]);
  end;
  AddPaidButton(ADb, ALog);
  AddDunningSample(ADb, ALog);
  if not ApplyBizTemplate(ADb, 'ponude_ugovori', '', True, ALog) then Exit;
  Items := TStringList.Create;
  try
    Items.Add('Računi|openform:Računi');
    Items.Add('Ponude poslova|openform:Ponude poslova');
    Items.Add('Ugovori i aneksi|openform:Ugovori');
    Items.Add('Partneri|openform:Partneri');
    Items.Add('Artikli i usluge|openform:Artikli');
    Items.Add('Sažetak neplaćenih računa|macro:Sazetak neplacenih');
    Items.Add('Povećaj cijene|macro:Povecaj cijene');
    Items.Add('Opomene dužnicima (pregled)|openletter:Opomena');
    Items.Add('Opomene u Word|macro:Opomene u Word');
    Items.Add('Cjenik u PDF|macro:Cjenik u PDF');
    Items.Add('Sigurnosna kopija|macro:Kopija baze');
    Items.Add('Zatvori|close');
    Def := BuildSwitchboard('Izbornik', 'Mali obrt', Items);
    SaveForm(ADb, ALog, Def);    { SaveForm oslobada definiciju }
  finally
    Items.Free;
  end;
  S := LoadAppSettings(ADb);
  S.StartupForm := 'Izbornik';
  SaveAppSettings(ADb, S);
  ALog.Add('Izbornik je početna forma');
  Result := True;
end;

end.
