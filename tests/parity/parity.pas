program parity;
{ Osnovni snimak ponasanja TaFormRunner-a PRIJE izdvajanja TaBindingEngine (E10, poglavlje 14 plana).
  20 definicija formi prolazi kroz isti scenarij (otvaranje, kretanje, izmjene, spremanje, pogreske, brisanje);
  nakon svakog koraka zapisuje se stanje: vrijednosti, vidljivost, omogucenost, boje kontrola, polozaj zapisa,
  poruke korisniku, a na kraju stanje tablica u bazi i snimka zaslona (offscreen).
    parity record   upisuje golden/NN_naziv.txt i .png
    parity check    uspoređuje s golden (izlaz 0 = isto, 1 = razlike; razlike su u out/)
  Nakon preinake stroja (TaBindingEngine) ova usporedba mora ostati zelena: "stare forme rade isto". }

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Controls, StdCtrls, ExtCtrls, DBGrids, DB, ZDataset, Classes, SysUtils, Graphics, Variants,
  qt6, qt6widgets, FileUtil, Math,
  ta_meta, ta_types, ta_tokens, ta_theme, ta_formdef, ta_formrun, ta_contform, ta_rowhost, ta_edit, ta_components, ta_binder, ta_family, ta_label, ta_check;

var
  Mode: string;
  Dir, GoldenDir, OutDir: string;
  Msgs, Log: TStringList;
  Failed, Total: Integer;

{ ---------------- pomocne ---------------- }

procedure OnMsg(const AMsg: string);
begin
  Msgs.Add(AMsg);
end;

type
  TExcCatcher = class
    procedure Catch(Sender: TObject; E: Exception);
  end;

procedure TExcCatcher.Catch(Sender: TObject; E: Exception);
begin
  Msgs.Add('IZNIMKA: ' + E.ClassName + ': ' + E.Message);
  WriteLn('IZNIMKA u dogadaju: ', E.ClassName, ': ', E.Message);
  DumpExceptionBackTrace(StdErr);
  Inc(Failed);
end;

var
  Catcher: TExcCatcher;

function OnConfirm(const AMsg: string): Boolean;
begin
  Msgs.Add('POTVRDA: ' + AMsg + ' -> da');
  Result := True;
end;

procedure P(const S: string);
begin
  Log.Add(S);
end;

function B(V: Boolean): string;
begin
  if V then Result := '1' else Result := '0';
end;

function GrabPng(AForm: TForm; const AFile: string): Boolean;
var
  Pix: QPixmapH;
  WS: WideString;
  R: TRect;
begin
  Pix := QPixmap_Create();
  try
    R := Rect(0, 0, AForm.Width, AForm.Height);
    QWidget_grab(TQtWidget(AForm.Handle).Widget, Pix, @R);
    WS := UTF8Decode(AFile);
    Result := QPixmap_save(Pix, @WS, 'PNG');
  finally
    QPixmap_Destroy(Pix);
  end;
end;

function Fresh(const AName: string): TAppDb;
var
  F: string;
begin
  F := OutDir + '/' + AName + '.db';
  if FileExists(F) then DeleteFile(F);
  Result := TAppDb.Create;
  Result.Open(F);
end;

procedure X(Db: TAppDb; const ASql: string);
begin
  Db.Conn.ExecuteDirect(ASql);
end;

function Ctl(D: TaFormDef; const AKind, AName, ASrc: string; L, T: Integer; W: Integer = 150; H: Integer = 24): TaControlDef;
begin
  Result := TaControlDef.Create;
  Result.Kind := AKind;
  Result.Name := AName;
  Result.ControlSource := ASrc;
  Result.Caption := AName;
  Result.Left := L; Result.Top := T; Result.Width := W; Result.Height := H;
  D.Add(Result);
end;

function Lbl(D: TaFormDef; const AName, ACaption: string; L, T: Integer): TaControlDef;
begin
  Result := Ctl(D, 'Label', AName, '', L, T, 120, 20);
  Result.Caption := ACaption;
end;

function ColorStr(C: TColor): string;
begin
  Result := IntToHex(Integer(ColorToRGB(C)), 6);
end;

{ stanje svih kontrola definicije }
procedure DumpControls(R: TaFormRunner; const ATag: string);
var
  I: Integer;
  Cd: TaControlDef;
  C, W: TControl;
  S: string;
begin
  P('-- ' + ATag + ' | caption=' + R.Caption);
  for I := 0 to R.Def.Count - 1 do
  begin
    Cd := R.Def[I];
    C := R.ControlByName(Cd.Name);
    if C = nil then begin P('  ' + Cd.Name + ' (nema kontrole)'); Continue; end;
    W := C;
    if C is TaFamilyHost then
      if TaFamilyHost(C).Engine <> nil then W := TaFamilyHost(C).Engine.Inner;
    S := '  ' + Cd.Name + ' ' + Cd.Kind + ' v=' + B(C.Visible) + ' e=' + B(C.Enabled);
    if W is TCustomEdit then S := S + ' text=[' + TCustomEdit(W).Text + '] ro=' + B(TCustomEdit(W).ReadOnly)
    else if W is TComboBox then S := S + ' text=[' + TComboBox(W).Text + ']'
    else if W is TCheckBox then S := S + ' chk=' + B(TCheckBox(W).Checked)
    else if W is TLabel then S := S + ' cap=[' + TLabel(W).Caption + ']'
    else if (C is TaLabel) then S := S + ' cap=[' + TaLabel(C).Caption + ']'
    else if (C is TaCheck) then S := S + ' chk=' + B(TaCheck(C).Checked)
    else if W is TCustomListBox then S := S + ' items=' + IntToStr(TCustomListBox(W).Items.Count) + ' sel=' + IntToStr(TCustomListBox(W).ItemIndex);
    if (W is TWinControl) and not (C is TaLabel) then S := S + ' bg=' + ColorStr(TWinControl(W).Color);
    if (W is TCustomEdit) or (W is TLabel) or (C is TaLabel) then S := S + ' fg=' + ColorStr(W.Font.Color) + ' b=' + B(fsBold in W.Font.Style);
    P(S);
  end;
end;

procedure DumpQuery(R: TaFormRunner);
const
  St: array[TDataSetState] of string = ('inactive', 'browse', 'edit', 'insert', 'setkey', 'calc', 'filter', 'newvalue', 'oldvalue', 'curvalue', 'block', 'internal', 'opened', 'refresh');
begin
  if (R.Query <> nil) and R.Query.Active then
    P('  query: rec=' + IntToStr(R.Query.RecNo) + '/' + IntToStr(R.Query.RecordCount) + ' state=' + St[R.Query.State])
  else P('  query: nema');
end;

procedure DumpGrid(R: TaFormRunner; AMax: Integer);
var
  G: TDBGrid;
  I, N: Integer;
  S: string;
  Bm: TBookmark;
begin
  G := R.MainGrid;
  if G = nil then begin P('  grid: nema'); Exit; end;
  S := '  grid cols:';
  for I := 0 to G.Columns.Count - 1 do S := S + ' ' + G.Columns[I].Title.Caption;
  P(S);
  P('  footer=[' + R.FooterText + '] filterErr=[' + R.FilterError + ']');
  if (R.Query = nil) or not R.Query.Active then Exit;
  R.Query.DisableControls;
  Bm := R.Query.GetBookmark;
  try
    R.Query.First;
    N := 0;
    while (not R.Query.EOF) and (N < AMax) do
    begin
      S := '  row';
      for I := 0 to R.Query.FieldCount - 1 do S := S + ' | ' + R.Query.Fields[I].AsString;
      P(S);
      R.Query.Next;
      Inc(N);
    end;
    if R.Query.BookmarkValid(Bm) then R.Query.GotoBookmark(Bm);
  finally
    R.Query.FreeBookmark(Bm);
    R.Query.EnableControls;
  end;
end;

procedure DumpMsgs;
var
  I: Integer;
begin
  for I := 0 to Msgs.Count - 1 do P('  MSG: ' + Msgs[I]);
  Msgs.Clear;
end;

procedure Step(R: TaFormRunner; const ATag: string; AGrid: Boolean = False);
begin
  if GetEnvironmentVariable('PARITY_TRACE') <> '' then WriteLn(StdErr, 'step ', ATag);
  Application.ProcessMessages;
  DumpControls(R, ATag);
  DumpQuery(R);
  if AGrid then DumpGrid(R, 8);
  DumpMsgs;
end;

procedure DumpTable(Db: TAppDb; const ATable, AOrder: string);
var
  Q: TZQuery;
  I: Integer;
  S: string;
begin
  P('-- tablica ' + ATable);
  Q := Db.NewQuery('SELECT * FROM ' + ATable + ' ORDER BY ' + AOrder);
  try
    Q.Open;
    while not Q.EOF do
    begin
      S := '  ';
      for I := 0 to Q.FieldCount - 1 do S := S + ' | ' + Q.Fields[I].AsString;
      P(S);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

procedure Edit(R: TaFormRunner; const AName, AText: string);
var
  C: TControl;
begin
  C := R.ControlByName(AName);
  if C is TaFamilyHost then C := TaFamilyHost(C).Engine.Inner;
  if C is TCustomEdit then TCustomEdit(C).Text := AText
  else if C is TComboBox then TComboBox(C).Text := AText
  else if C is TCheckBox then TCheckBox(C).Checked := AText = '1';
  Application.ProcessMessages;
end;

function Open(Db: TAppDb; D: TaFormDef; AW, AH: Integer): TaFormRunner;
begin
  Result := TaFormRunner.CreateRunner(nil, Db, D);
  Result.Show;
  if AW > 0 then Result.SetBounds(0, 0, AW, AH);
  Application.ProcessMessages;
end;

procedure Finish(const ACase: string; R: TaFormRunner);
var
  Png, G: string;
begin
  if GetEnvironmentVariable('PARITY_TRACE') <> '' then WriteLn(StdErr, 'finish: prije grab');
  Application.ProcessMessages;
  if GetEnvironmentVariable('PARITY_TRACE') <> '' then WriteLn(StdErr, 'finish: poslije ProcessMessages');
  Png := OutDir + '/' + ACase + '.png';
  GrabPng(R, Png);
  if GetEnvironmentVariable('PARITY_TRACE') <> '' then WriteLn(StdErr, 'finish: poslije grab');
  P('-- snimka ' + ACase + '.png');
end;

procedure FinishWrite(const ACase: string);
var
  Gold, GoldPng, NewPng: string;
  A: TStringList;
  I: Integer;
  Same: Boolean;
  F1, F2: TFileStream;
begin
  if GetEnvironmentVariable('PARITY_TRACE') <> '' then WriteLn(StdErr, 'FinishWrite (forma je oslobodena)');
  Inc(Total);
  Log.SaveToFile(OutDir + '/' + ACase + '.txt');
  Gold := GoldenDir + '/' + ACase + '.txt';
  GoldPng := GoldenDir + '/' + ACase + '.png';
  NewPng := OutDir + '/' + ACase + '.png';
  if Mode = 'record' then
  begin
    Log.SaveToFile(Gold);
    if FileExists(NewPng) then CopyFile(NewPng, GoldPng);
    WriteLn('snimljeno ', ACase);
    Exit;
  end;
  if not FileExists(Gold) then begin WriteLn('NEMA golden: ', ACase); Inc(Failed); Exit; end;
  Same := True;
  A := TStringList.Create;
  try
    A.LoadFromFile(Gold);
    for I := 0 to Min(A.Count, Log.Count) - 1 do
      if A[I] <> Log[I] then
      begin
        WriteLn('RAZLIKA ', ACase, ' redak ', I + 1, ':');
        WriteLn('  golden: ', A[I]);
        WriteLn('  sada:   ', Log[I]);
        Same := False;
        Break;
      end;
    if A.Count <> Log.Count then
    begin
      WriteLn('RAZLIKA ', ACase, ': broj redaka ', A.Count, ' prema ', Log.Count);
      Same := False;
    end;
  finally
    A.Free;
  end;
  { snimka zaslona: bajt po bajt (isti Qt, isti font, ista tema) }
  if FileExists(GoldPng) and FileExists(NewPng) then
  begin
    F1 := TFileStream.Create(GoldPng, fmOpenRead);
    F2 := TFileStream.Create(NewPng, fmOpenRead);
    try
      if (F1.Size <> F2.Size) then Same := False
      else
      begin
        SetLength(GoldPng, 0);
        I := 0;
        { usporedba sadrzaja }
        F1.Position := 0; F2.Position := 0;
        while (I = 0) and (F1.Position < F1.Size) do
          if F1.ReadByte <> F2.ReadByte then I := 1;
        if I = 1 then Same := False;
      end;
      if not Same then WriteLn('RAZLIKA snimka ', ACase, '.png');
    finally
      F1.Free;
      F2.Free;
    end;
  end;
  if Same then WriteLn('ok   ', ACase) else Inc(Failed);
end;

procedure BeginCase(const ACase: string);
begin
  Log.Clear;
  Msgs.Clear;
  P('== ' + ACase);
end;

{ ============================ 20 slucajeva ============================ }

procedure PartneriDb(Db: TAppDb);
begin
  X(Db, 'CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), aktivan INTEGER DEFAULT 0, iznos DECIMAL(12,2))');
  X(Db, 'INSERT INTO partneri (naziv, grad, aktivan, iznos) VALUES (''Alfa'', ''Zagreb'', 1, 150), (''Beta'', ''Split'', 0, 50), (''Gama'', ''Rijeka'', 1, 300), (''Delta'', ''Zagreb'', 0, 10), (''Epsilon'', ''Pula'', 1, 99.5)');
end;

function PartneriForm(const AName: string): TaFormDef;
begin
  Result := TaFormDef.Create;
  Result.Name := AName; Result.RecordSource := 'partneri'; Result.Caption := AName;
  Result.AllowEdits := True; Result.AllowAdds := True; Result.AllowDeletes := True; Result.NavButtons := True;
  Result.Width := 420; Result.Height := 220;
  Lbl(Result, 'l1', 'Naziv', 10, 12); Ctl(Result, 'TextBox', 'txtNaziv', 'naziv', 140, 10);
  Lbl(Result, 'l2', 'Grad', 10, 44); Ctl(Result, 'TextBox', 'txtGrad', 'grad', 140, 42);
  Lbl(Result, 'l3', 'Aktivan', 10, 76); Ctl(Result, 'CheckBox', 'chkAkt', 'aktivan', 140, 74, 24, 24);
  Lbl(Result, 'l4', 'Iznos', 10, 108); Ctl(Result, 'TextBox', 'txtIznos', 'iznos', 140, 106);
end;

{ 01 osnovna forma: kretanje, izmjena, spremanje, novi, brisanje }
procedure Case01;
var
  Db: TAppDb; R: TaFormRunner;
begin
  BeginCase('01_osnovna');
  Db := Fresh('c01'); PartneriDb(Db);
  R := Open(Db, PartneriForm('F01'), 440, 280);
  Step(R, 'otvoreno');
  R.DoAction('next'); R.DoAction('next'); Step(R, 'dva naprijed');
  Edit(R, 'txtNaziv', 'Gama izmijenjena'); Edit(R, 'chkAkt', '0');
  Step(R, 'izmijenjeno, nespremljeno');
  R.DoAction('save'); Step(R, 'spremljeno');
  R.DoAction('prior'); Step(R, 'nazad');
  R.DoAction('new'); Step(R, 'novi');
  Edit(R, 'txtNaziv', 'Novi partner'); Edit(R, 'txtIznos', '12.5');
  R.DoAction('save'); Step(R, 'novi spremljen');
  R.DoAction('last'); Step(R, 'zadnji');
  R.DoAction('delete'); Step(R, 'obrisan');
  R.DoAction('first'); Step(R, 'prvi');
  Finish('01_osnovna', R);
  DumpTable(Db, 'partneri', 'id');
  R.Free; Db.Close; Db.Free;
  FinishWrite('01_osnovna');
end;

{ 02 izracunata polja }
procedure Case02;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('02_izracun');
  Db := Fresh('c02');
  X(Db, 'CREATE TABLE stavke (id INTEGER PRIMARY KEY, opis VARCHAR(30), kolicina INTEGER, cijena DECIMAL(12,2))');
  X(Db, 'INSERT INTO stavke (opis, kolicina, cijena) VALUES (''a'', 2, 10.5), (''b'', 5, 3), (''c'', 1, 99)');
  D := TaFormDef.Create; D.Name := 'F02'; D.RecordSource := 'stavke'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 420; D.Height := 220;
  Ctl(D, 'TextBox', 'txtOpis', 'opis', 10, 10); Ctl(D, 'TextBox', 'txtKol', 'kolicina', 10, 40); Ctl(D, 'TextBox', 'txtCij', 'cijena', 10, 70);
  Ctl(D, 'TextBox', 'txtIzn', '=[kolicina] * [cijena]', 10, 100).Format := '#,##0.00';
  Ctl(D, 'Label', 'lblNaz', '="Stavka: " & UCase([opis])', 10, 130, 300, 20);
  R := Open(Db, D, 440, 280);
  Step(R, 'otvoreno');
  R.DoAction('next'); Step(R, 'sljedeci');
  Edit(R, 'txtKol', '10'); Step(R, 'kolicina 10');
  Edit(R, 'txtCij', '2.5'); Step(R, 'cijena 2,5');
  Finish('02_izracun', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('02_izracun');
end;

{ 03 vidljivost i omogucenost po uvjetu }
procedure Case03;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('03_vidljivost');
  Db := Fresh('c03'); PartneriDb(Db);
  D := PartneriForm('F03');
  Ctl(D, 'TextBox', 'txtTajni', 'grad', 10, 140).SetX('visibleIf', '[aktivan] = 1');
  D[D.IndexOfName('txtIznos')].SetX('enabledIf', '[aktivan] = 1');
  D[D.IndexOfName('txtGrad')].SetX('visibleIf', '[aktivan] = 0');
  R := Open(Db, D, 440, 280);
  Step(R, 'aktivan (Alfa)');
  R.DoAction('next'); Step(R, 'neaktivan (Beta)');
  R.DoAction('next'); Step(R, 'aktivan (Gama)');
  Edit(R, 'chkAkt', '0'); Step(R, 'gasim aktivan');
  Finish('03_vidljivost', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('03_vidljivost');
end;

{ 04 uvjetno oblikovanje }
procedure Case04;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('04_uvjetno_oblikovanje');
  Db := Fresh('c04'); PartneriDb(Db);
  D := PartneriForm('F04');
  D[D.IndexOfName('txtIznos')].SetX('condFormat', '[iznos] > 100 => #C00000 #FFE9E9 bold ;; [iznos] < 20 => #006000 #E9FFE9');
  R := Open(Db, D, 440, 280);
  Step(R, 'Alfa 150');
  R.DoAction('next'); Step(R, 'Beta 50');
  R.DoAction('next'); Step(R, 'Gama 300');
  R.DoAction('next'); Step(R, 'Delta 10');
  Edit(R, 'txtIznos', '500'); Step(R, 'Delta 500');
  Finish('04_uvjetno_oblikovanje', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('04_uvjetno_oblikovanje');
end;

{ 05 combo s izvorom redaka (strani kljuc) }
procedure Case05;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef; C: TaControlDef;
begin
  BeginCase('05_combo_izvor');
  Db := Fresh('c05'); PartneriDb(Db);
  X(Db, 'CREATE TABLE racuni (id INTEGER PRIMARY KEY, broj VARCHAR(20), partner_id INTEGER, FOREIGN KEY (partner_id) REFERENCES partneri(id))');
  X(Db, 'INSERT INTO racuni (broj, partner_id) VALUES (''R-1'', 1), (''R-2'', 3), (''R-3'', 2)');
  D := TaFormDef.Create; D.Name := 'F05'; D.RecordSource := 'racuni'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 420; D.Height := 200;
  Ctl(D, 'TextBox', 'txtBroj', 'broj', 10, 10);
  C := Ctl(D, 'ComboBox', 'cmbPartner', 'partner_id', 10, 44, 200, 24); C.RowSource := 'SELECT id, naziv FROM partneri ORDER BY naziv';
  R := Open(Db, D, 440, 260);
  Step(R, 'R-1');
  R.DoAction('next'); Step(R, 'R-2');
  Edit(R, 'cmbPartner', 'Beta'); Step(R, 'odabir Beta');
  R.DoAction('save'); Step(R, 'spremljeno');
  Finish('05_combo_izvor', R);
  DumpTable(Db, 'racuni', 'id');
  R.Free; Db.Close; Db.Free;
  FinishWrite('05_combo_izvor');
end;

{ 06 zadane vrijednosti i pravila provjere }
procedure Case06;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef; M: TaFieldMeta;
begin
  BeginCase('06_zadano_provjera');
  Db := Fresh('c06'); PartneriDb(Db);
  M := TaFieldMeta.Create; M.TableName := 'partneri'; M.FieldName := 'grad'; M.LType := ltText; M.DefaultExpr := '"NepoznatGrad"'; Db.SaveFieldMeta(M); M.Free;
  M := TaFieldMeta.Create; M.TableName := 'partneri'; M.FieldName := 'iznos'; M.LType := ltDecimal; M.Decimals := 2;
  M.Validation := '[iznos] >= 0'; M.ValidationMsg := 'Iznos ne smije biti negativan'; Db.SaveFieldMeta(M); M.Free;
  D := PartneriForm('F06');
  R := Open(Db, D, 440, 280);
  R.DoAction('new'); Step(R, 'novi (zadane vrijednosti)');
  Edit(R, 'txtNaziv', 'Probni'); Edit(R, 'txtIznos', '-5'); Step(R, 'negativan iznos');
  R.DoAction('save'); Step(R, 'spremanje odbijeno');
  Edit(R, 'txtIznos', '5'); R.DoAction('save'); Step(R, 'ispravljeno i spremljeno');
  Finish('06_zadano_provjera', R);
  DumpTable(Db, 'partneri', 'id');
  R.Free; Db.Close; Db.Free;
  FinishWrite('06_zadano_provjera');
end;

{ 07 CalcRules }
procedure Case07;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('07_calcrules');
  Db := Fresh('c07');
  X(Db, 'CREATE TABLE st (id INTEGER PRIMARY KEY, kolicina INTEGER, cijena DECIMAL(12,2), iznos DECIMAL(12,2), pdv DECIMAL(12,2))');
  X(Db, 'INSERT INTO st (kolicina, cijena, iznos, pdv) VALUES (2, 5, 10, 2.5), (3, 4, 12, 3)');
  D := TaFormDef.Create; D.Name := 'F07'; D.RecordSource := 'st'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 420; D.Height := 220;
  D.CalcRules := 'kolicina,cijena -> iznos = Zaokruzi([kolicina] * [cijena], 2) ;; iznos -> pdv = Zaokruzi([iznos] * 0.25, 2)';
  Ctl(D, 'TextBox', 'txtKol', 'kolicina', 10, 10); Ctl(D, 'TextBox', 'txtCij', 'cijena', 10, 40);
  Ctl(D, 'TextBox', 'txtIzn', 'iznos', 10, 70); Ctl(D, 'TextBox', 'txtPdv', 'pdv', 10, 100);
  R := Open(Db, D, 440, 260);
  Step(R, 'otvoreno');
  Edit(R, 'txtKol', '7'); Step(R, 'kolicina 7');
  Edit(R, 'txtCij', '1.5'); Step(R, 'cijena 1,5');
  R.DoAction('save'); R.DoAction('next'); Step(R, 'sljedeci');
  Finish('07_calcrules', R);
  DumpTable(Db, 'st', 'id');
  R.Free; Db.Close; Db.Free;
  FinishWrite('07_calcrules');
end;

{ 08 AutoFill }
procedure Case08;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('08_autofill');
  Db := Fresh('c08');
  X(Db, 'CREATE TABLE artikli (id INTEGER PRIMARY KEY, naziv VARCHAR(30), cijena DECIMAL(12,2))');
  X(Db, 'INSERT INTO artikli (naziv, cijena) VALUES (''Vijak'', 0.5), (''Matica'', 0.25), (''Podloska'', 0.1)');
  X(Db, 'CREATE TABLE stavke (id INTEGER PRIMARY KEY, artikl_id INTEGER, opis VARCHAR(30), cijena DECIMAL(12,2))');
  X(Db, 'INSERT INTO stavke (artikl_id, opis, cijena) VALUES (1, ''Vijak'', 0.5)');
  D := TaFormDef.Create; D.Name := 'F08'; D.RecordSource := 'stavke'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 420; D.Height := 200;
  D.AutoFill := 'artikl_id>artikli.id:cijena=cijena,opis=naziv';
  Ctl(D, 'TextBox', 'txtArt', 'artikl_id', 10, 10); Ctl(D, 'TextBox', 'txtOpis', 'opis', 10, 40); Ctl(D, 'TextBox', 'txtCij', 'cijena', 10, 70);
  R := Open(Db, D, 440, 260);
  Step(R, 'otvoreno');
  Edit(R, 'txtArt', '2'); Step(R, 'artikl 2');
  R.DoAction('save'); Step(R, 'spremljeno');
  R.DoAction('new'); Edit(R, 'txtArt', '3'); Step(R, 'novi s artiklom 3');
  R.DoAction('save');
  Finish('08_autofill', R);
  DumpTable(Db, 'stavke', 'id');
  R.Free; Db.Close; Db.Free;
  FinishWrite('08_autofill');
end;

{ 09 tablicni prikaz: sortiranje, filtar stupca, podnozje }
procedure Case09;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('09_datasheet');
  Db := Fresh('c09'); PartneriDb(Db);
  D := TaFormDef.Create; D.Name := 'F09'; D.RecordSource := 'partneri'; D.ViewMode := 'datasheet'; D.AllowEdits := True; D.AllowAdds := True; D.Width := 560; D.Height := 300;
  R := Open(Db, D, 580, 360);
  Step(R, 'otvoreno', True);
  R.SortBy('iznos', True); Step(R, 'sortirano po iznosu silazno', True);
  R.SetColumnFilter('grad', 'Zagreb'); Step(R, 'filtar grad=Zagreb', True);
  R.ClearColumnFilters; R.SetColumnFilter('iznos', '>100'); Step(R, 'filtar iznos>100', True);
  R.ClearColumnFilters; Step(R, 'filtri ocisceni', True);
  Finish('09_datasheet', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('09_datasheet');
end;

{ 10 obrazac + mreza }
procedure Case10;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('10_split');
  Db := Fresh('c10'); PartneriDb(Db);
  D := PartneriForm('F10'); D.ViewMode := 'split';
  R := Open(Db, D, 460, 520);
  Step(R, 'otvoreno', True);
  R.DoAction('next'); R.DoAction('next'); Step(R, 'dva naprijed', True);
  Edit(R, 'txtGrad', 'Osijek'); R.DoAction('save'); Step(R, 'izmjena grada', True);
  Finish('10_split', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('10_split');
end;

{ 11 podforma kao mreza }
procedure Case11;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef; C: TaControlDef;
begin
  BeginCase('11_podforma_mreza');
  Db := Fresh('c11'); PartneriDb(Db);
  X(Db, 'CREATE TABLE racuni (id INTEGER PRIMARY KEY, partner_id INTEGER NOT NULL, broj VARCHAR(20), iznos DECIMAL(12,2), FOREIGN KEY (partner_id) REFERENCES partneri(id))');
  X(Db, 'INSERT INTO racuni (partner_id, broj, iznos) VALUES (1, ''R-1'', 10), (1, ''R-2'', 20), (3, ''R-3'', 5)');
  D := PartneriForm('F11');
  C := Ctl(D, 'Subform', 'subRacuni', '', 10, 140, 400, 120); C.RowSource := 'racuni'; C.LinkMaster := 'id'; C.LinkChild := 'partner_id';
  Ctl(D, 'TextBox', 'txtUk', '=DSum("iznos", "racuni", "partner_id = " & [id])', 280, 10);
  R := Open(Db, D, 440, 300);
  Step(R, 'partner 1'); P('  sub=' + IntToStr(R.SubCount('subRacuni')));
  R.DoAction('next'); Step(R, 'partner 2'); P('  sub=' + IntToStr(R.SubCount('subRacuni')));
  R.DoAction('next'); Step(R, 'partner 3'); P('  sub=' + IntToStr(R.SubCount('subRacuni')));
  Finish('11_podforma_mreza', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('11_podforma_mreza');
end;

{ 12 podforma kao ugradena forma }
procedure Case12;
var
  Db: TAppDb; R: TaFormRunner; D, Sub: TaFormDef; C: TaControlDef;
begin
  BeginCase('12_podforma_forma');
  Db := Fresh('c12'); PartneriDb(Db);
  X(Db, 'CREATE TABLE racuni (id INTEGER PRIMARY KEY, partner_id INTEGER NOT NULL, broj VARCHAR(20), iznos DECIMAL(12,2), FOREIGN KEY (partner_id) REFERENCES partneri(id))');
  X(Db, 'INSERT INTO racuni (partner_id, broj, iznos) VALUES (1, ''R-1'', 10), (1, ''R-2'', 20), (3, ''R-3'', 5)');
  Sub := TaFormDef.Create; Sub.Name := 'RacunForma'; Sub.RecordSource := 'racuni'; Sub.AllowEdits := True; Sub.NavButtons := True; Sub.Width := 300; Sub.Height := 120;
  Ctl(Sub, 'TextBox', 'txtBroj', 'broj', 10, 10); Ctl(Sub, 'TextBox', 'txtIzn', 'iznos', 10, 40);
  Db.SaveObject('_sys_forms', 'RacunForma', Sub.ToJson); Sub.Free;
  D := PartneriForm('F12');
  C := Ctl(D, 'Subform', 'subR', '', 10, 140, 400, 120); C.RowSource := 'RacunForma'; C.LinkMaster := 'id'; C.LinkChild := 'partner_id';
  R := Open(Db, D, 440, 300);
  Step(R, 'partner 1');
  if R.SubRunner('subR') <> nil then P('  sub broj=' + VarToStr(R.SubRunner('subR').ValueOf('txtBroj')));
  R.DoAction('next'); R.DoAction('next'); Step(R, 'partner 3');
  if R.SubRunner('subR') <> nil then P('  sub broj=' + VarToStr(R.SubRunner('subR').ValueOf('txtBroj')));
  Finish('12_podforma_forma', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('12_podforma_forma');
end;

procedure ContDump(R: TaFormRunner; const ATag: string);
var
  CB: TaContinuousBody;
begin
  CB := R.ContinuousForm;
  P('-- ' + ATag);
  if CB = nil then begin P('  nema neprekidne forme'); Exit; end;
  P('  zapisa=' + IntToStr(CB.Host.Model.RecordCount) + ' sort=' + CB.SortField + ' desc=' + B(CB.SortDescending) +
    ' tekuci=' + IntToStr(CB.Host.Model.Current) + ' prljav=' + B(CB.Host.Model.Dirty));
  P('  prvi=[' + CB.Source.Value(0, 'naziv') + ']');
  DumpMsgs;
end;

{ 13 neprekidna forma }
procedure Case13;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef; C: TaControlDef; CB: TaContinuousBody;
begin
  BeginCase('13_neprekidna');
  Db := Fresh('c13'); PartneriDb(Db);
  D := TaFormDef.Create; D.Name := 'F13'; D.RecordSource := 'partneri'; D.ViewMode := 'continuous'; D.AllowEdits := True; D.AllowAdds := True; D.AllowDeletes := True;
  D.HeaderHeight := 56; D.RowHeight := 34; D.FooterHeight := 36; D.Width := 480; D.Height := 300;
  C := Ctl(D, 'Label', 'hNaziv', '', 4, 4, 140, 20); C.Caption := 'Naziv'; C.Section := 'header'; C.SetX('sort', 'naziv');
  C := Ctl(D, 'TextBox', 'fGrad', '', 150, 26, 100, 24); C.Section := 'header'; C.SetX('filter', 'grad');
  C := Ctl(D, 'TextBox', 'tNaziv', 'naziv', 4, 4, 140, 26); C.Section := 'detail';
  C := Ctl(D, 'TextBox', 'tGrad', 'grad', 150, 4, 100, 26); C.Section := 'detail';
  C := Ctl(D, 'TextBox', 'tIznos', 'iznos', 256, 4, 90, 26); C.Section := 'detail'; C.Format := '#,##0.00';
  C := Ctl(D, 'TextBox', 'zBroj', '=Count()', 150, 4, 100, 24); C.Section := 'footer';
  C := Ctl(D, 'TextBox', 'zZbroj', '=Sum(iznos)', 256, 4, 90, 24); C.Section := 'footer'; C.Format := '#,##0.00';
  R := Open(Db, D, 500, 340);
  CB := R.ContinuousForm;
  ContDump(R, 'otvoreno'); P('  podnozje ' + CB.FooterText('zBroj') + ' / ' + CB.FooterText('zZbroj'));
  CB.ClickHeader('hNaziv'); CB.ClickHeader('hNaziv'); ContDump(R, 'sortirano silazno');
  CB.TypeFilter('fGrad', 'Zagreb'); ContDump(R, 'filtar Zagreb'); P('  podnozje ' + CB.FooterText('zBroj') + ' / ' + CB.FooterText('zZbroj'));
  CB.TypeFilter('fGrad', '');
  CB.Host.GoToRow(CB.Host.Model.NewRow); CB.Host.SimulateEdit(0, 'Zeta'); CB.Host.SimulateEdit(2, '1000');
  P('  spremanje novog: ' + B(CB.Host.CommitRow)); ContDump(R, 'dodan zapis'); P('  podnozje ' + CB.FooterText('zBroj') + ' / ' + CB.FooterText('zZbroj'));
  CB.Host.GoToRow(0); CB.Host.SimulateEdit(0, ''); P('  prazan obavezni naziv: spremanje=' + B(CB.Host.CommitRow) + ' greska=' + B(CB.Host.Error <> ''));
  CB.Host.CancelRow; ContDump(R, 'nakon Cancel');
  Finish('13_neprekidna', R);
  DumpTable(Db, 'partneri', 'id');
  R.Free; Db.Close; Db.Free;
  FinishWrite('13_neprekidna');
end;

{ 14 racun s neprekidnom podformom i SubSum }
procedure Case14;
var
  Db: TAppDb; R: TaFormRunner; D, Sub: TaFormDef; C: TaControlDef; H: TaRowsView;
begin
  BeginCase('14_racun_subsum');
  Db := Fresh('c14');
  X(Db, 'CREATE TABLE racuni (id INTEGER PRIMARY KEY, broj VARCHAR(20))');
  X(Db, 'CREATE TABLE stavke (id INTEGER PRIMARY KEY, racun_id INTEGER NOT NULL, opis VARCHAR(30), iznos DECIMAL(12,2), FOREIGN KEY (racun_id) REFERENCES racuni(id))');
  X(Db, 'INSERT INTO racuni (broj) VALUES (''R-1''), (''R-2'')');
  X(Db, 'INSERT INTO stavke (racun_id, opis, iznos) VALUES (1, ''a'', 10), (1, ''b'', 20), (2, ''c'', 5)');
  Sub := TaFormDef.Create; Sub.Name := 'StavkeF'; Sub.RecordSource := 'stavke'; Sub.ViewMode := 'continuous'; Sub.AllowEdits := True; Sub.AllowAdds := True; Sub.AllowDeletes := True;
  Sub.HeaderHeight := 30; Sub.RowHeight := 34; Sub.FooterHeight := 34; Sub.Width := 400; Sub.Height := 200;
  C := Ctl(Sub, 'Label', 'hOpis', '', 4, 4, 140, 20); C.Caption := 'Opis'; C.Section := 'header';
  C := Ctl(Sub, 'TextBox', 'tOpis', 'opis', 4, 4, 160, 26); C.Section := 'detail';
  C := Ctl(Sub, 'TextBox', 'tIzn', 'iznos', 170, 4, 100, 26); C.Section := 'detail'; C.Format := '#,##0.00';
  C := Ctl(Sub, 'TextBox', 'zIzn', '=Sum(iznos)', 170, 4, 100, 24); C.Section := 'footer'; C.Format := '#,##0.00';
  Db.SaveObject('_sys_forms', 'StavkeF', Sub.ToJson); Sub.Free;
  D := TaFormDef.Create; D.Name := 'F14'; D.RecordSource := 'racuni'; D.AllowEdits := True; D.NavButtons := True; D.Width := 460; D.Height := 320;
  Ctl(D, 'TextBox', 'txtBroj', 'broj', 10, 10);
  Ctl(D, 'TextBox', 'txtUk', '=SubSum("Stavke", "iznos")', 10, 40).Format := '#,##0.00';
  Ctl(D, 'TextBox', 'txtBr', '=SubCount("Stavke")', 200, 40);
  C := Ctl(D, 'Subform', 'Stavke', '', 10, 74, 430, 220); C.RowSource := 'StavkeF'; C.LinkMaster := 'id'; C.LinkChild := 'racun_id';
  R := Open(Db, D, 470, 360);
  Step(R, 'racun 1');
  H := R.SubRunner('Stavke').ContinuousForm.Host;
  H.GoToRow(H.Model.NewRow); H.SimulateEdit(0, 'd'); H.SimulateEdit(1, '12.5'); P('  nova stavka: ' + B(H.CommitRow));
  Step(R, 'nakon nove stavke');
  R.DoAction('next'); Step(R, 'racun 2');
  Finish('14_racun_subsum', R);
  DumpTable(Db, 'stavke', 'id');
  R.Free; Db.Close; Db.Free;
  FinishWrite('14_racun_subsum');
end;

{ 15 filtar i redoslijed forme, pretraga }
procedure Case15;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('15_filter_pretraga');
  Db := Fresh('c15'); PartneriDb(Db);
  D := PartneriForm('F15'); D.Filter := 'iznos > 20'; D.OrderBy := 'naziv DESC';
  R := Open(Db, D, 440, 280);
  Step(R, 'otvoreno s filtrom iznos>20, naziv silazno');
  R.DoAction('next'); Step(R, 'sljedeci');
  R.Search('Alfa'); Step(R, 'pretraga Alfa');
  R.Search(''); Step(R, 'pretraga ociscena');
  Finish('15_filter_pretraga', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('15_filter_pretraga');
end;

{ 16 samo za citanje }
procedure Case16;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('16_samo_citanje');
  Db := Fresh('c16'); PartneriDb(Db);
  D := PartneriForm('F16'); D.AllowEdits := False; D.AllowAdds := False; D.AllowDeletes := False;
  D[D.IndexOfName('txtGrad')].SetX('locked', '1');
  R := Open(Db, D, 440, 280);
  Step(R, 'otvoreno');
  Edit(R, 'txtNaziv', 'Pokusaj'); R.DoAction('save'); Step(R, 'pokusaj izmjene');
  R.DoAction('new'); Step(R, 'pokusaj novog');
  R.DoAction('delete'); Step(R, 'pokusaj brisanja');
  Finish('16_samo_citanje', R);
  DumpTable(Db, 'partneri', 'id');
  R.Free; Db.Close; Db.Free;
  FinishWrite('16_samo_citanje');
end;

{ 17 grupa izbora i popis }
procedure Case17;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef; C: TaControlDef;
begin
  BeginCase('17_grupa_popis');
  Db := Fresh('c17'); PartneriDb(Db);
  X(Db, 'ALTER TABLE partneri ADD COLUMN velicina INTEGER');
  X(Db, 'UPDATE partneri SET velicina = 1 + (id % 2)');
  D := PartneriForm('F17');
  C := Ctl(D, 'OptionGroup', 'grpVel', 'velicina', 250, 10, 150, 60); C.RowSource := '1=Mala;2=Velika';
  C := Ctl(D, 'ListBox', 'lstGradovi', '', 250, 80, 150, 90); C.RowSource := 'SELECT DISTINCT grad FROM partneri ORDER BY grad';
  R := Open(Db, D, 440, 280);
  Step(R, 'otvoreno'); P('  grupa=' + VarToStr(R.ValueOf('grpVel')));
  R.DoAction('next'); Step(R, 'sljedeci'); P('  grupa=' + VarToStr(R.ValueOf('grpVel')));
  Finish('17_grupa_popis', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('17_grupa_popis');
end;

{ 18 izrazi u oznakama }
procedure Case18;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('18_izrazi_oznake');
  Db := Fresh('c18'); PartneriDb(Db);
  D := PartneriForm('F18');
  Ctl(D, 'Label', 'lblA', '=Upper([naziv]) & " / " & Nz([grad], "?")', 10, 140, 300, 20);
  Ctl(D, 'Label', 'lblB', '=Iif([iznos] > 100, "velik", "malen") & " " & Format([iznos], "#,##0.00")', 10, 164, 300, 20);
  Ctl(D, 'Label', 'lblC', '="Zapisa: " & DCount("*", "partneri", "aktivan = 1")', 10, 188, 300, 20);
  Ctl(D, 'Label', 'lblD', '=UCase([naziv]) & " / " & Nz([grad], "?")', 10, 212, 300, 20);
  R := Open(Db, D, 440, 300);
  Step(R, 'otvoreno');
  R.DoAction('next'); Step(R, 'sljedeci');
  Edit(R, 'txtIznos', '1234.5'); Step(R, 'iznos 1234,5');
  Edit(R, 'chkAkt', '1'); Step(R, 'aktivan');
  Finish('18_izrazi_oznake', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('18_izrazi_oznake');
end;

{ 19 mreza s uvjetnim oblikovanjem redaka }
procedure Case19;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef;
begin
  BeginCase('19_gridformat');
  Db := Fresh('c19'); PartneriDb(Db);
  D := TaFormDef.Create; D.Name := 'F19'; D.RecordSource := 'partneri'; D.ViewMode := 'datasheet'; D.AllowEdits := True; D.Width := 560; D.Height := 300;
  D.GridFormat := '[iznos] > 100 => #C00000 #FFE9E9 bold ;; [aktivan] = 0 => #808080';
  R := Open(Db, D, 580, 360);
  Step(R, 'otvoreno', True);
  R.SortBy('naziv', False); Step(R, 'sortirano po nazivu', True);
  Finish('19_gridformat', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('19_gridformat');
end;

{ 20 glavni zapis s ukupnim iznosom stavki (DSum) i unos stavki kroz mrezu }
procedure Case20;
var
  Db: TAppDb; R: TaFormRunner; D: TaFormDef; C: TaControlDef; Sq: TZQuery;
begin
  BeginCase('20_ukupno_stavki');
  Db := Fresh('c20');
  X(Db, 'CREATE TABLE racuni (id INTEGER PRIMARY KEY, broj VARCHAR(20))');
  X(Db, 'CREATE TABLE stavke (id INTEGER PRIMARY KEY, racun_id INTEGER NOT NULL, opis VARCHAR(30), iznos DECIMAL(12,2), FOREIGN KEY (racun_id) REFERENCES racuni(id))');
  X(Db, 'INSERT INTO racuni (broj) VALUES (''R-1''), (''R-2'')');
  X(Db, 'INSERT INTO stavke (racun_id, opis, iznos) VALUES (1, ''a'', 10), (1, ''b'', 20)');
  D := TaFormDef.Create; D.Name := 'F20'; D.RecordSource := 'racuni'; D.AllowEdits := True; D.AllowAdds := True; D.NavButtons := True; D.Width := 460; D.Height := 320;
  Ctl(D, 'TextBox', 'txtBroj', 'broj', 10, 10);
  Ctl(D, 'TextBox', 'txtUk', '=Nz(DSum("iznos", "stavke", "racun_id = " & [id]), 0)', 10, 40).Format := '#,##0.00';
  C := Ctl(D, 'Subform', 'subSt', '', 10, 74, 430, 200); C.RowSource := 'stavke'; C.LinkMaster := 'id'; C.LinkChild := 'racun_id';
  R := Open(Db, D, 470, 340);
  Step(R, 'racun 1');
  Sq := R.SubQuery('subSt');
  if Sq <> nil then
  begin
    Sq.Append; Sq.FieldByName('opis').AsString := 'c'; Sq.FieldByName('iznos').AsFloat := 7.5; Sq.Post;
  end;
  Step(R, 'nakon unosa stavke u mrezu');
  R.DoAction('next'); Step(R, 'racun 2 (prazan)');
  R.DoAction('prior'); Step(R, 'natrag na racun 1');
  Finish('20_ukupno_stavki', R);
  DumpTable(Db, 'stavke', 'id');
  R.Free; Db.Close; Db.Free;
  FinishWrite('20_ukupno_stavki');
end;


{ 21 stanje zapisa i upit po formi }
procedure Case21;
var
  Db: TAppDb; R: TaFormRunner;
  procedure St(const ATag: string);
  begin
    Step(R, ATag);
    P('  stanje=' + R.StateText + ' upit=' + B(R.QueryMode));
  end;
begin
  BeginCase('21_upit_po_formi');
  Db := Fresh('c21'); PartneriDb(Db);
  R := Open(Db, PartneriForm('F21'), 540, 280);
  St('otvoreno');
  Edit(R, 'txtNaziv', 'Alfa 2'); St('izmijenjeno (promijenjen)');
  R.DoAction('undo'); St('poniteno (spremljen)');
  R.DoAction('new'); St('novi zapis');
  R.DoAction('undo');
  R.DoAction('query'); St('upit: polja prazna');
  Edit(R, 'txtGrad', 'Zagreb'); R.DoAction('execquery'); St('upit grad=Zagreb');
  R.DoAction('query'); Edit(R, 'txtIznos', '>100'); R.DoAction('execquery'); St('upit iznos>100');
  R.DoAction('next'); St('sljedeci unutar rezultata');
  R.DoAction('query'); Edit(R, 'txtGrad', 'Nepostojeci*'); R.DoAction('execquery'); St('upit bez rezultata, vraceno prethodno');
  R.DoAction('query'); Edit(R, 'txtIznos', 'abc'); R.DoAction('execquery'); St('neispravan uzorak, ostaje upit');
  R.DoAction('cancelquery'); St('poniten upit');
  R.DoAction('query'); Edit(R, 'txtNaziv', 'Ga*'); R.DoAction('execquery'); St('upit naziv=Ga*');
  R.DoAction('clearquery'); St('upit ocisten, svi zapisi');
  R.DoAction('first'); R.DoAction('query'); R.DoAction('next'); St('kretanje u upitu je zabranjeno');
  R.DoAction('cancelquery');
  Finish('21_upit_po_formi', R);
  R.Free; Db.Close; Db.Free;
  FinishWrite('21_upit_po_formi');
end;

{ ============ ista definicija kroz TaFormBinder, usporedba s golden snimkama runnera ============ }

type
  TBCtl = record
    C: TControl;
    Name: string;
    Bg, Fg: TColor;
  end;

var
  BCtls: array of TBCtl;
  BOut: TStringList;

procedure BAdd(C: TControl; const AName: string);
begin
  SetLength(BCtls, Length(BCtls) + 1);
  BCtls[High(BCtls)].C := C;
  BCtls[High(BCtls)].Name := AName;
  BCtls[High(BCtls)].Bg := C.Color;
  BCtls[High(BCtls)].Fg := C.Font.Color;
end;

{ stanje u istom zapisu kao DumpControls (razred se izostavlja pri usporedbi; boje bez promjene su 000000) }
procedure BDump(const ATag: string);
var
  I: Integer;
  C: TControl;
  S, Bg, Fg: string;
begin
  BOut.Add('-- ' + ATag);
  for I := 0 to High(BCtls) do
  begin
    C := BCtls[I].C;
    S := '  ' + BCtls[I].Name + ' v=' + B(C.Visible) + ' e=' + B(C.Enabled);
    if C is TCustomEdit then S := S + ' text=[' + TCustomEdit(C).Text + '] ro=' + B(TCustomEdit(C).ReadOnly)
    else if C is TCheckBox then S := S + ' chk=' + B(TCheckBox(C).Checked)
    else if C is TLabel then S := S + ' cap=[' + TLabel(C).Caption + ']';
    if C.Color = BCtls[I].Bg then Bg := '000000' else Bg := ColorStr(C.Color);
    if C.Font.Color = BCtls[I].Fg then Fg := '000000' else Fg := ColorStr(C.Font.Color);
    if C is TWinControl then S := S + ' bg=' + Bg;
    if (C is TCustomEdit) or (C is TLabel) then S := S + ' fg=' + Fg + ' b=' + B(fsBold in C.Font.Style);
    BOut.Add(S);
  end;
end;

{ iz retka runnera makne razred: "  ime Razred v=.." -> "ime v=.." }
function NormRunnerLine(const L: string): string;
var
  P: Integer;
  Name, Rest: string;
begin
  Rest := Trim(L);
  P := Pos(' ', Rest);
  Name := Copy(Rest, 1, P - 1);
  Rest := Copy(Rest, P + 1, MaxInt);
  P := Pos(' ', Rest);
  Result := Name + ' ' + Copy(Rest, P + 1, MaxInt);
end;

function NormBinderLine(const L: string): string;
begin
  Result := Trim(L);
end;

{ trazi odjeljak "-- tag" u golden tekstu i vraca njegove retke }
function GoldenSection(AGolden: TStrings; const ATag: string; AOut: TStrings): Boolean;
var
  I: Integer;
begin
  AOut.Clear;
  Result := False;
  I := 0;
  while I < AGolden.Count do
  begin
    if Copy(AGolden[I], 1, 3 + Length(ATag)) = '-- ' + ATag then
    begin
      Result := True;
      Inc(I);
      while (I < AGolden.Count) and (Copy(AGolden[I], 1, 2) = '  ') do
      begin
        if (Pos('query:', AGolden[I]) = 0) and (Pos('MSG:', AGolden[I]) = 0) and (Pos('sub', Trim(AGolden[I])) <> 1) then AOut.Add(AGolden[I]);
        Inc(I);
      end;
      Exit;
    end;
    Inc(I);
  end;
end;

{ usporedi binderov ispis s golden snimkom runnera po kontrolama koje binder ima }
procedure BCompare(const ACase, AGoldenFile: string);
var
  G, Sec, Bn: TStringList;
  I, J, K: Integer;
  Tag, Line, Nm, Want: string;
  Diffs: Integer;
begin
  Inc(Total);
  G := TStringList.Create;
  Sec := TStringList.Create;
  Bn := TStringList.Create;
  Diffs := 0;
  try
    G.LoadFromFile(AGoldenFile);
    BOut.SaveToFile(OutDir + '/binder_' + ACase + '.txt');
    I := 0;
    while I < BOut.Count do
    begin
      if Copy(BOut[I], 1, 3) = '-- ' then
      begin
        Tag := Copy(BOut[I], 4, MaxInt);
        if not GoldenSection(G, Tag, Sec) then begin WriteLn('  NEMA oznake u golden: ', Tag); Inc(Diffs); Inc(I); Continue; end;
        J := I + 1;
        while (J < BOut.Count) and (Copy(BOut[J], 1, 3) <> '-- ') do
        begin
          Line := NormBinderLine(BOut[J]);
          Nm := Copy(Line, 1, Pos(' ', Line) - 1);
          Want := '';
          for K := 0 to Sec.Count - 1 do
            if Copy(Trim(Sec[K]), 1, Length(Nm) + 1) = Nm + ' ' then Want := NormRunnerLine(Sec[K]);
          if Want = '' then WriteLn('  nema kontrole ', Nm, ' u golden (', Tag, ')')
          else if Want <> Line then
          begin
            WriteLn('RAZLIKA binder/runner ', ACase, ' [', Tag, ']:');
            WriteLn('  runner: ', Want);
            WriteLn('  binder: ', Line);
            Inc(Diffs);
          end;
          Inc(J);
        end;
        I := J;
      end
      else Inc(I);
    end;
  finally
    G.Free; Sec.Free; Bn.Free;
  end;
  if Diffs = 0 then WriteLn('ok   binder ', ACase) else Inc(Failed);
end;

function BSetup(const AName: string; out Fm: TForm; out Owner: TComponent; out Dbc: TaDatabase): TZQuery;
begin
  Fm := TForm.CreateNew(nil);
  Fm.SetBounds(0, 0, 440, 300);
  Owner := TComponent.Create(nil);
  Dbc := TaDatabase.Create(Owner);
  if FileExists(OutDir + '/b_' + AName + '.db') then DeleteFile(OutDir + '/b_' + AName + '.db');
  Dbc.FileName := OutDir + '/b_' + AName + '.db';
  Dbc.Active := True;
  SetLength(BCtls, 0);
  BOut.Clear;
  Result := nil;
end;

function BEdit(Fm: TForm; const AName: string; const ASrc: string = ''): TEdit;
begin
  Result := TEdit.Create(Fm); Result.Parent := Fm; Result.Name := AName; BAdd(Result, AName);
end;

{ B03: vidljivost i omogucenost (runner slucaj 03) }
procedure BCase03;
var
  Fm: TForm; Ow: TComponent; Dbc: TaDatabase; Q: TZQuery; Ds: TaDataSource; Bd: TaFormBinder;
  EdIznos, EdTajni, EdGrad: TEdit; Ck: TCheckBox;
begin
  BeginCase('b03');
  Q := BSetup('03', Fm, Ow, Dbc);
  Dbc.ExecSQL('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), aktivan INTEGER DEFAULT 0, iznos DECIMAL(12,2))');
  Dbc.ExecSQL('INSERT INTO partneri (naziv, grad, aktivan, iznos) VALUES (''Alfa'', ''Zagreb'', 1, 150), (''Beta'', ''Split'', 0, 50), (''Gama'', ''Rijeka'', 1, 300), (''Delta'', ''Zagreb'', 0, 10), (''Epsilon'', ''Pula'', 1, 99.5)');
  Q := Dbc.NewQuery('SELECT * FROM partneri ORDER BY id'); Q.Open;
  Ds := TaDataSource.Create(Ow); Ds.DataSet := Q;
  EdGrad := BEdit(Fm, 'txtGrad'); Ck := TCheckBox.Create(Fm); Ck.Parent := Fm; Ck.Name := 'chkAkt'; BAdd(Ck, 'chkAkt');
  EdIznos := BEdit(Fm, 'txtIznos'); EdTajni := BEdit(Fm, 'txtTajni');
  Bd := TaFormBinder.Create(Ow); Bd.Database := Dbc; Bd.DataSource := Ds; Bd.Locale := blSystem;
  with Bd.Bindings.Add do begin Control := EdGrad; FieldName := 'grad'; VisibleIf := '[aktivan] = 0'; end;
  with Bd.Bindings.Add do begin Control := Ck; FieldName := 'aktivan'; end;
  with Bd.Bindings.Add do begin Control := EdIznos; FieldName := 'iznos'; EnabledIf := '[aktivan] = 1'; end;
  with Bd.Bindings.Add do begin Control := EdTajni; FieldName := 'grad'; VisibleIf := '[aktivan] = 1'; end;
  Bd.Activate;
  BDump('aktivan (Alfa)');
  Q.Next; BDump('neaktivan (Beta)');
  Q.Next; BDump('aktivan (Gama)');
  Q.Edit; Q.FieldByName('aktivan').AsInteger := 0; BDump('gasim aktivan');
  Q.Cancel;
  BCompare('03_vidljivost', GoldenDir + '/03_vidljivost.txt');
  Fm.Free; Ow.Free;
end;

{ B04: uvjetno oblikovanje (runner slucaj 04) }
procedure BCase04;
var
  Fm: TForm; Ow: TComponent; Dbc: TaDatabase; Q: TZQuery; Ds: TaDataSource; Bd: TaFormBinder;
  EdIznos: TEdit;
begin
  BeginCase('b04');
  Q := BSetup('04', Fm, Ow, Dbc);
  Dbc.ExecSQL('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), aktivan INTEGER DEFAULT 0, iznos DECIMAL(12,2))');
  Dbc.ExecSQL('INSERT INTO partneri (naziv, grad, aktivan, iznos) VALUES (''Alfa'', ''Zagreb'', 1, 150), (''Beta'', ''Split'', 0, 50), (''Gama'', ''Rijeka'', 1, 300), (''Delta'', ''Zagreb'', 0, 10), (''Epsilon'', ''Pula'', 1, 99.5)');
  Q := Dbc.NewQuery('SELECT * FROM partneri ORDER BY id'); Q.Open;
  Ds := TaDataSource.Create(Ow); Ds.DataSet := Q;
  EdIznos := BEdit(Fm, 'txtIznos');
  Bd := TaFormBinder.Create(Ow); Bd.Database := Dbc; Bd.DataSource := Ds; Bd.Locale := blSystem;
  with Bd.Bindings.Add do
  begin
    Control := EdIznos; FieldName := 'iznos';
    CondFormat := '[iznos] > 100 => #C00000 #FFE9E9 bold ;; [iznos] < 20 => #006000 #E9FFE9';
  end;
  Bd.Activate;
  BDump('Alfa 150');
  Q.Next; BDump('Beta 50');
  Q.Next; BDump('Gama 300');
  Q.Next; BDump('Delta 10');
  Q.Edit; Q.FieldByName('iznos').AsFloat := 500; BDump('Delta 500');
  Q.Cancel;
  BCompare('04_uvjetno_oblikovanje', GoldenDir + '/04_uvjetno_oblikovanje.txt');
  Fm.Free; Ow.Free;
end;

{ B18: izrazi u oznakama (runner slucaj 18) }
procedure BCase18;
var
  Fm: TForm; Ow: TComponent; Dbc: TaDatabase; Q: TZQuery; Ds: TaDataSource; Bd: TaFormBinder;
  LA, LB, LC, LD: TLabel;
begin
  BeginCase('b18');
  Q := BSetup('18', Fm, Ow, Dbc);
  Dbc.ExecSQL('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), aktivan INTEGER DEFAULT 0, iznos DECIMAL(12,2))');
  Dbc.ExecSQL('INSERT INTO partneri (naziv, grad, aktivan, iznos) VALUES (''Alfa'', ''Zagreb'', 1, 150), (''Beta'', ''Split'', 0, 50), (''Gama'', ''Rijeka'', 1, 300), (''Delta'', ''Zagreb'', 0, 10), (''Epsilon'', ''Pula'', 1, 99.5)');
  Q := Dbc.NewQuery('SELECT * FROM partneri ORDER BY id'); Q.Open;
  Ds := TaDataSource.Create(Ow); Ds.DataSet := Q;
  LA := TLabel.Create(Fm); LA.Parent := Fm; LA.Name := 'lblA'; BAdd(LA, 'lblA');
  LB := TLabel.Create(Fm); LB.Parent := Fm; LB.Name := 'lblB'; BAdd(LB, 'lblB');
  LC := TLabel.Create(Fm); LC.Parent := Fm; LC.Name := 'lblC'; BAdd(LC, 'lblC');
  LD := TLabel.Create(Fm); LD.Parent := Fm; LD.Name := 'lblD'; BAdd(LD, 'lblD');
  Bd := TaFormBinder.Create(Ow); Bd.Database := Dbc; Bd.DataSource := Ds; Bd.Locale := blSystem;
  with Bd.Bindings.Add do begin Control := LA; Expression := 'Upper([naziv]) & " / " & Nz([grad], "?")'; end;
  with Bd.Bindings.Add do begin Control := LB; Expression := 'Iif([iznos] > 100, "velik", "malen") & " " & Format([iznos], "#,##0.00")'; end;
  with Bd.Bindings.Add do begin Control := LC; Expression := '"Zapisa: " & DCount("*", "partneri", "aktivan = 1")'; end;
  with Bd.Bindings.Add do begin Control := LD; Expression := 'UCase([naziv]) & " / " & Nz([grad], "?")'; end;
  Bd.Activate;
  BDump('otvoreno');
  Q.Next; BDump('sljedeci');
  Q.Edit; Q.FieldByName('iznos').AsFloat := 1234.5; BDump('iznos 1234,5');
  Q.FieldByName('aktivan').AsInteger := 1; BDump('aktivan');
  Q.Cancel;
  BCompare('18_izrazi_oznake', GoldenDir + '/18_izrazi_oznake.txt');
  Fm.Free; Ow.Free;
end;


{ B02: izracunata polja (runner slucaj 02) }
procedure BCase02;
var
  Fm: TForm; Ow: TComponent; Dbc: TaDatabase; Q: TZQuery; Ds: TaDataSource; Bd: TaFormBinder;
  EOpis, EKol, ECij, EIzn: TEdit; LN: TLabel;
begin
  BeginCase('b02');
  Q := BSetup('02', Fm, Ow, Dbc);
  Dbc.ExecSQL('CREATE TABLE stavke (id INTEGER PRIMARY KEY, opis VARCHAR(30), kolicina INTEGER, cijena DECIMAL(12,2))');
  Dbc.ExecSQL('INSERT INTO stavke (opis, kolicina, cijena) VALUES (''a'', 2, 10.5), (''b'', 5, 3), (''c'', 1, 99)');
  Q := Dbc.NewQuery('SELECT * FROM stavke ORDER BY id'); Q.Open;
  Ds := TaDataSource.Create(Ow); Ds.DataSet := Q;
  EOpis := BEdit(Fm, 'txtOpis'); EKol := BEdit(Fm, 'txtKol'); ECij := BEdit(Fm, 'txtCij'); EIzn := BEdit(Fm, 'txtIzn');
  LN := TLabel.Create(Fm); LN.Parent := Fm; LN.Name := 'lblNaz'; BAdd(LN, 'lblNaz');
  Bd := TaFormBinder.Create(Ow); Bd.Database := Dbc; Bd.DataSource := Ds; Bd.Locale := blSystem;
  with Bd.Bindings.Add do begin Control := EOpis; FieldName := 'opis'; end;
  with Bd.Bindings.Add do begin Control := EKol; FieldName := 'kolicina'; end;
  with Bd.Bindings.Add do begin Control := ECij; FieldName := 'cijena'; end;
  with Bd.Bindings.Add do begin Control := EIzn; Expression := '[kolicina] * [cijena]'; Format := '#,##0.00'; end;
  with Bd.Bindings.Add do begin Control := LN; Expression := '"Stavka: " & UCase([opis])'; end;
  Bd.Activate;
  BDump('otvoreno');
  Q.Next; BDump('sljedeci');
  Q.Edit; Q.FieldByName('kolicina').AsInteger := 10; BDump('kolicina 10');
  Q.FieldByName('cijena').AsFloat := 2.5; BDump('cijena 2,5');
  Q.Cancel;
  BCompare('02_izracun', GoldenDir + '/02_izracun.txt');
  Fm.Free; Ow.Free;
end;


{ B06: zadane vrijednosti pri novom zapisu (runner slucaj 06) }
procedure BCase06;
var
  Fm: TForm; Ow: TComponent; Dbc: TaDatabase; Q: TZQuery; Ds: TaDataSource; Bd: TaFormBinder;
  EN, EG, EI: TEdit; Ck: TCheckBox;
begin
  BeginCase('b06');
  Q := BSetup('06', Fm, Ow, Dbc);
  Dbc.ExecSQL('CREATE TABLE partneri (id INTEGER PRIMARY KEY, naziv VARCHAR(50) NOT NULL, grad VARCHAR(30), aktivan INTEGER DEFAULT 0, iznos DECIMAL(12,2))');
  Dbc.ExecSQL('INSERT INTO partneri (naziv, grad, aktivan, iznos) VALUES (''Alfa'', ''Zagreb'', 1, 150)');
  Q := Dbc.NewQuery('SELECT * FROM partneri ORDER BY id'); Q.Open;
  Ds := TaDataSource.Create(Ow); Ds.DataSet := Q;
  EN := BEdit(Fm, 'txtNaziv'); EG := BEdit(Fm, 'txtGrad');
  Ck := TCheckBox.Create(Fm); Ck.Parent := Fm; Ck.Name := 'chkAkt'; BAdd(Ck, 'chkAkt');
  EI := BEdit(Fm, 'txtIznos');
  Bd := TaFormBinder.Create(Ow); Bd.Database := Dbc; Bd.DataSource := Ds; Bd.Locale := blSystem;
  with Bd.Bindings.Add do begin Control := EN; FieldName := 'naziv'; end;
  with Bd.Bindings.Add do begin Control := EG; FieldName := 'grad'; DefaultValue := '"NepoznatGrad"'; end;
  with Bd.Bindings.Add do begin Control := Ck; FieldName := 'aktivan'; end;
  with Bd.Bindings.Add do begin Control := EI; FieldName := 'iznos'; Rule := '[iznos] >= 0'; RuleMessage := 'Iznos ne smije biti negativan'; end;
  Bd.Activate;
  Q.Append; BDump('novi (zadane vrijednosti)');
  Q.FieldByName('naziv').AsString := 'Probni'; Q.FieldByName('iznos').AsFloat := -5; BDump('negativan iznos');
  P('  valid=' + B(Bd.Validate) + ' poruka=' + Bd.Errors.Text);
  Q.Cancel;
  BCompare('06_zadano_provjera', GoldenDir + '/06_zadano_provjera.txt');
  Fm.Free; Ow.Free;
end;

var
  Cases: array[1..21] of procedure;
  I: Integer;
  Only: Integer;
begin
  Application.Initialize;
  Application.Scaled := False;
  WindowFrames := False;
  ApplySavedTheme;
  Mode := 'check';
  if ParamCount >= 1 then Mode := ParamStr(1);
  Only := 0;
  if ParamCount >= 2 then Only := StrToIntDef(ParamStr(2), 0);
  Dir := ExtractFilePath(ParamStr(0));
  GoldenDir := Dir + 'golden';
  OutDir := Dir + 'out';
  ForceDirectories(GoldenDir);
  ForceDirectories(OutDir);
  Msgs := TStringList.Create;
  Log := TStringList.Create;
  Catcher := TExcCatcher.Create;
  Application.OnException := @Catcher.Catch;
  OnRunnerMessage := @OnMsg;
  OnRunnerConfirm := @OnConfirm;
  BOut := TStringList.Create;
  if Mode = 'binder' then
  begin
    BCase02; BCase03; BCase04; BCase06; BCase18;
    WriteLn('slucajeva=', Total, ' razlika=', Failed);
    if Failed > 0 then Halt(1);
    Halt(0);
  end;
  Cases[1] := @Case01; Cases[2] := @Case02; Cases[3] := @Case03; Cases[4] := @Case04; Cases[5] := @Case05;
  Cases[6] := @Case06; Cases[7] := @Case07; Cases[8] := @Case08; Cases[9] := @Case09; Cases[10] := @Case10;
  Cases[11] := @Case11; Cases[12] := @Case12; Cases[13] := @Case13; Cases[14] := @Case14; Cases[15] := @Case15;
  Cases[21] := @Case21; Cases[16] := @Case16; Cases[17] := @Case17; Cases[18] := @Case18; Cases[19] := @Case19; Cases[20] := @Case20;
  for I := 1 to 21 do
    if (Only = 0) or (Only = I) then
      try
        Cases[I]();
        Flush(Output);
      except
        on E: Exception do
        begin
          WriteLn('IZNIMKA u slucaju ', I, ': ', E.Message);
          Inc(Failed);
        end;
      end;
  WriteLn('slucajeva=', Total, ' razlika=', Failed);
  if Failed > 0 then Halt(1);
end.
