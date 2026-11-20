program ownshots;
{ Zlatne snimke vlastitih kontrola (pruzatelj 'own'): svaka kontrola se nacrta u malu formu i snimka se usporedi bajt po bajt
  sa snimkom u golden/. Kontrole crtaju same sebe, pa se isti skup moze pokrenuti na bilo kojem sucelju (uz zasebne snimke).
    ownshots           usporedi s golden/ (izlaz 0 = isto)
    ownshots record    ponovno snimi golden/ (samo kad je promjena izgleda namjerna i pregledana) }
{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, Controls, Graphics, SysUtils, Classes, DB, ZDataset, LCLType, FileUtil,
  ta_meta, ta_tokens, ta_theme, ta_family, ta_edit, ta_memo, ta_list, ta_calendar, ta_grid, ta_ownedit, ta_owncombo, ta_owndate,
  ta_ownspin, ta_ownlov, ta_ownmemo, ta_ownrich, ta_richbase, ta_ownlist, ta_owntree, ta_ownboard, ta_owndash, ta_owntimeline, ta_owncalendar, ta_owngrid, ta_gridview, Process;

var
  Mode, GoldenDir, OutDir: string;
  Total, Failed: Integer;

type
  TCrack = class(TaOwnEdit)
  public
    procedure Press(const S: string);
  end;

  TGCrack = class(TaOwnGrid)
  public
    procedure Key(K: Word);
  end;

  TSubHost = class
  public
    Db: TAppDb;
    Qs, Ss: TList;
    constructor Create;
    procedure Open(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
    procedure Close(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
  end;

procedure TGCrack.Key(K: Word);
begin
  KeyDown(K, []);
end;

procedure TCrack.Press(const S: string);
var
  U: TUTF8Char;
begin
  U := S;
  UTF8KeyPress(U);
end;

constructor TSubHost.Create;
begin
  Qs := TList.Create;
  Ss := TList.Create;
end;

procedure TSubHost.Open(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
var
  Q: TZQuery;
  S: TDataSource;
begin
  Q := Db.NewQuery('SELECT id, kupac_id, tekst FROM napomena WHERE kupac_id = ' + AKey);
  Q.Open;
  S := TDataSource.Create(nil);
  S.DataSet := Q;
  Qs.Add(Q);
  Ss.Add(S);
  AChild.DataSource := S;
end;

procedure TSubHost.Close(Sender: TObject; const AKey: string; AChild: TaOwnGrid);
begin
end;

function NewForm(AW, AH: Integer): TForm;
begin
  Result := TForm.CreateNew(nil);
  Result.SetBounds(0, 0, AW, AH);
  Result.Color := TokenColor(ActiveTokens.Bg);
end;

procedure Finish(const AName: string; F: TForm);
var
  Png, Gold: string;
  Same: Boolean;
  F1, F2: TFileStream;
  Pic: TPortableNetworkGraphic;
  Pic_Out: string;
begin
  F.Left := 0;
  F.Top := 0;
  F.Show;
  Application.ProcessMessages;
  Png := OutDir + '/' + AName + '.png';
  if GetEnvironmentVariable('OWN_XSHOT') <> '' then
  begin
    { GTK3: GetFormImage vraca crnu sliku, pa se snima zaslon (Xvfb) vanjskim alatom }
    Sleep(400);
    Application.ProcessMessages;
    Sleep(200);
    RunCommand('import', ['-window', 'root', '-crop', IntToStr(F.Width) + 'x' + IntToStr(F.Height) + '+0+0', Png], Pic_Out);
  end
  else
  begin
    Pic := TPortableNetworkGraphic.Create;
    try
      Pic.Assign(F.GetFormImage);
      Pic.SaveToFile(Png);
    finally
      Pic.Free;
    end;
  end;
  Inc(Total);
  Gold := GoldenDir + '/' + AName + '.png';
  if Mode = 'record' then
  begin
    CopyFile(Png, Gold);
    WriteLn('snimljeno ', AName);
    Exit;
  end;
  if not FileExists(Gold) then begin WriteLn('NEMA golden: ', AName); Inc(Failed); Exit; end;
  F1 := TFileStream.Create(Gold, fmOpenRead);
  F2 := TFileStream.Create(Png, fmOpenRead);
  try
    Same := F1.Size = F2.Size;
    if Same then
      while Same and (F1.Position < F1.Size) do
        if F1.ReadByte <> F2.ReadByte then Same := False;
  finally
    F1.Free;
    F2.Free;
  end;
  if Same then WriteLn('ok   ', AName) else begin WriteLn('RAZLIKA snimka ', AName, '.png'); Inc(Failed); end;
end;

function MakeEdit(F: TForm; V: TaEditVariant; Y: Integer; const AText: string): TaEdit;
begin
  Result := TaEdit.Create(F);
  Result.Parent := F;
  Result.SetBounds(12, Y, 240, 28);
  Result.Variant := V;
  if AText <> '' then Result.Text := AText;
end;

procedure SceneEdits;
var
  F: TForm;
  E: TaEdit;
  Cb: TaEdit;
begin
  F := NewForm(280, 360);
  try
    E := MakeEdit(F, evText, 10, 'Zagreb');
    E.Engine.Inner.SetFocus;
    MakeEdit(F, evPassword, 44, 'tajna');
    E := MakeEdit(F, evCurrency, 78, '');
    E.SetValue(1234.5);
    E := MakeEdit(F, evText, 112, 'samo za citanje');
    E.ReadOnly := True;
    E := MakeEdit(F, evSpin, 146, '');
    E.SetValue(12.5);
    MakeEdit(F, evDate, 180, '14.03.2025');
    MakeEdit(F, evLov, 214, 'Sifra A12');
    Cb := MakeEdit(F, evCombo, 248, '');
    Cb.Items.Text := 'Crvena'#10'Zelena'#10'Plava';
    Cb.Text := 'Plava';
    Cb := MakeEdit(F, evDroplist, 282, '');
    Cb.Items.Text := 'Crvena'#10'Zelena'#10'Plava';
    Cb.Text := 'Zelena';
    Finish('01_polja', F);
  finally
    F.Free;
  end;
end;

procedure ScenePopups;
var
  F: TForm;
  Cb, Dt: TaEdit;
begin
  F := NewForm(300, 330);
  try
    Cb := MakeEdit(F, evCombo, 10, '');
    Cb.Items.Text := 'Crvena'#10'Zelena'#10'Plava'#10'Zuta'#10'Ljubicasta';
    Cb.Text := 'Zelena';
    Dt := MakeEdit(F, evDate, 160, '14.03.2025');
    F.Left := 0;
    F.Top := 0;
    F.Show;
    Application.ProcessMessages;
    TaOwnCombo(Cb.Engine.Inner).OpenPopup;
    Finish('02_combo_popis', F);
  finally
    F.Free;
  end;
  F := NewForm(300, 330);
  try
    Dt := MakeEdit(F, evDate, 10, '14.03.2025');
    F.Left := 0;
    F.Top := 0;
    F.Show;
    Application.ProcessMessages;
    TaOwnDateEdit(Dt.Engine.Inner).OpenPopup;
    Finish('03_datum_kalendar', F);
  finally
    F.Free;
  end;
end;

procedure SceneMemoList;
var
  F: TForm;
  M: TaMemo;
  L: TaList;
  I: Integer;
  S: string;
begin
  F := NewForm(460, 220);
  try
    M := TaMemo.Create(F);
    M.Parent := F;
    M.SetBounds(10, 10, 200, 190);
    S := '';
    for I := 1 to 14 do S := S + 'Redak broj ' + IntToStr(I) + LineEnding;
    M.Text := S + 'Zadnji redak je malo duzi nego sirina polja pa se prelama';
    L := TaList.Create(F);
    L.Parent := F;
    L.SetBounds(225, 10, 100, 190);
    L.Items.Text := 'a=Prvi'#10'b=Drugi'#10'c=Treci'#10'd=Cetvrti';
    L.Select('b');
    L := TaList.Create(F);
    L.Parent := F;
    L.SetBounds(340, 10, 110, 190);
    L.Variant := lsChecklist;
    L.Items.Text := 'a=Prvi'#10'b=Drugi'#10'c=Treci'#10'd=Cetvrti';
    L.Select('a,c');
    Finish('04_memo_popisi', F);
  finally
    F.Free;
  end;
end;

procedure SceneRich;
var
  F: TForm;
  E: TaOwnRichEdit;
  Ro: TaOwnRichEdit;
begin
  F := NewForm(460, 260);
  try
    E := TaOwnRichEdit.Create(F);
    E.Parent := F;
    E.SetBounds(10, 10, 440, 160);
    E.Html := '<p align="center"><b>Naslov dopisa</b></p><p>Obicni tekst, <b>podebljano</b>, <i>kurziv</i>, <u>podcrtano</u> i <font color="#c00000">crveno</font>.</p>' +
      '<p list="1">Prva natuknica</p><p list="1" align="right">Druga, desno</p><p><font size="16">Veliko slovo</font> pa malo</p>';
    E.Surface.SelectFlat(14, 9);
    Ro := TaOwnRichEdit.Create(F);
    Ro.Parent := F;
    Ro.SetBounds(10, 180, 440, 70);
    Ro.Html := '<p>Samo za citanje: traka se skriva, tekst je <b>formatiran</b> i prelama se u vise redaka kad ne stane u sirinu polja.</p>';
    Ro.ReadOnly := True;
    Finish('10_formatirani_tekst', F);
  finally
    F.Free;
  end;
end;

procedure SceneTree;
var
  F: TForm;
  L: TaList;
begin
  F := NewForm(300, 200);
  try
    L := TaList.Create(F);
    L.Parent := F;
    L.SetBounds(10, 10, 280, 180);
    L.Variant := lsTree;
    L.Items.Text := 'a=Europa'#10'  b=Hrvatska'#10'    c=Zagreb'#10'    d=Split'#10'  e=Italija'#10'f=Azija'#10'  g=Japan'#10'h=Afrika';
    L.Select('c');
    TaOwnTree(L.Engine.Inner).Expanded[5] := False;
    Finish('11_stablo', F);
  finally
    F.Free;
  end;
end;

procedure SceneIcons;
var
  F: TForm;
  L: TaList;
  I: Integer;
begin
  F := NewForm(300, 200);
  try
    L := TaList.Create(F);
    L.Parent := F;
    L.SetBounds(10, 10, 280, 180);
    L.Variant := lsIconlist;
    for I := 1 to 9 do L.Items.Add('k' + IntToStr(I) + '=Stavka ' + IntToStr(I));
    L.Items.Add('k10=Vrlo dugacak natpis stavke');
    L.Select('k2');
    Finish('12_ikone', F);
  finally
    F.Free;
  end;
end;

procedure SceneBoard;
var
  F: TForm;
  B: TaOwnBoard;
begin
  F := NewForm(640, 300);
  try
    B := TaOwnBoard.Create(F);
    B.Parent := F;
    B.SetBounds(0, 0, 640, 300);
    B.AddColumn('1', 'Sjetva');
    B.AddColumn('2', 'Rast');
    B.AddColumn('3', 'Cvatnja');
    B.AddColumn('', '(bez)');
    B.AddCard('1', '1', 'Paprika 1', 'Paprika'#10'Gredica 3'#10'01.04.2026');
    B.AddCard('2', '2', 'Rajcica A', 'Rajcica'#10'Staklenik 1'#10'01.03.2026');
    B.AddCard('3', '2', 'Rajcica B', 'Rajcica'#10'Staklenik 1'#10'20.03.2026');
    B.AddCard('4', '3', 'Bosiljak X', 'Bosiljak'#10'Gredica 3'#10'10.02.2026');
    B.AddCard('5', '', 'Paprika 2', 'Paprika'#10'Staklenik 1'#10'05.04.2026');
    B.EndUpdate;
    B.SelectedId := '3';
    Finish('13_ploca', F);
  finally
    F.Free;
  end;
end;

procedure SceneDash;
var
  F: TForm;
  D: TaOwnDash;
  I: Integer;
  S: array of Double;
begin
  F := NewForm(660, 300);
  try
    D := TaOwnDash.Create(F);
    D.Parent := F;
    D.SetBounds(0, 0, 660, 300);
    SetLength(S, 24);
    for I := 0 to 23 do S[I] := 6 + Sin(I / 3) * 0.4 + I * 0.02;
    D.AddItem('1', 'Pogon 1', 'zadnji signal: 15:49', 'Temperatura zraka', '24,9', '°C', 0, S);
    D.AddItem('2', 'Pogon 1', 'zadnji signal: 15:49', 'Vlaga zraka', '61,5', '%', 0, S);
    D.AddItem('3', 'Pogon 1', 'zadnji signal: 15:49', 'pH', '7,39', 'pH', 1, S);
    D.AddItem('4', 'Pogon 2', 'zadnji signal: 15:49', 'Vlaga tla', '53,5', '%', 0, S);
    D.AddItem('5', 'Pogon 2', 'zadnji signal: 15:49', 'Temperatura tla', '20,4', '°C', 2, S);
    D.AddItem('6', 'Pogon 1', 'zadnji signal: 15:49', 'Rasvjeta', '', '', 0, S).Kind := 1;
    D.ItemAt(D.ItemCount - 1).On := True;
    D.AddItem('7', 'Pogon 2', 'zadnji signal: 15:49', 'Pumpa', '', '', 0, S).Kind := 1;
    D.ItemAt(D.ItemCount - 1).Pending := True;
    D.ItemAt(2).Alerts := 2;
    D.EndUpdate;
    Finish('14_nadzorna_ploca', F);
  finally
    F.Free;
  end;
end;

procedure SceneTimeline;
var
  F: TForm;
  T: TaOwnTimeline;
  It: TaTimeItem;
begin
  F := NewForm(760, 330);
  try
    T := TaOwnTimeline.Create(F);
    T.Parent := F;
    T.SetBounds(0, 0, 760, 330);
    T.AddItem('1', '12345', 360, 1320, 0, 0);
    T.AddItem('2', '67', 480, 1260, 0, 0);
    T.AddItem('3', '1234567', 0, 0, 240, 120);
    It := T.AddItem('4', '35', 1380, 120, 0, 0);
    T.EndUpdate;
    T.Selected := It;
    Finish('15_raspored', F);
  finally
    F.Free;
  end;
end;

procedure SceneCalendars;
var
  F: TForm;
  K: TaCalendar;
begin
  F := NewForm(600, 290);
  try
    K := TaCalendar.Create(F);
    K.Parent := F;
    K.SetBounds(10, 10, 280, 260);
    K.Text := '2025-03-14';
    K := TaCalendar.Create(F);
    K.Parent := F;
    K.Variant := cmRange;
    K.SetBounds(305, 10, 280, 260);
    K.Text := '2025-03-10..2025-03-20';
    Finish('05_kalendari', F);
  finally
    F.Free;
  end;
end;

function Fixture(const AFile: string): TAppDb;
var
  I: Integer;
begin
  if FileExists(AFile) then DeleteFile(AFile);
  Result := TAppDb.Create;
  Result.Open(AFile);
  Result.Conn.ExecuteDirect('CREATE TABLE kupac (id INTEGER PRIMARY KEY, naziv VARCHAR(40), grad VARCHAR(30), iznos DECIMAL(10,2), aktivan BOOLEAN)');
  Result.Conn.ExecuteDirect('CREATE TABLE napomena (id INTEGER PRIMARY KEY, kupac_id INTEGER, tekst VARCHAR(40))');
  for I := 1 to 30 do
    Result.Conn.ExecuteDirect('INSERT INTO kupac (naziv, grad, iznos, aktivan) VALUES (''Kupac ' + IntToStr(I) + ''', ''Grad ' + IntToStr(I mod 7) + ''', ' + IntToStr(I * 13 mod 200) + '.5, ' + IntToStr(I mod 2) + ')');
  Result.Conn.ExecuteDirect('INSERT INTO napomena (kupac_id, tekst) VALUES (1, ''prva napomena''), (1, ''druga napomena''), (3, ''treca'')');
end;

procedure SceneGrids;
var
  Db: TAppDb;
  Q: TZQuery;
  Ds: TDataSource;
  F: TForm;
  G: TaOwnGrid;
  Gr: TaGrid;
  Sub: TSubHost;
  I: Integer;
begin
  Db := Fixture('/tmp/ta_ownshots.db');
  Ds := TDataSource.Create(nil);
  Sub := TSubHost.Create;
  Sub.Db := Db;
  try
    Q := Db.NewQuery('SELECT * FROM kupac ORDER BY id');
    Ds.DataSet := Q;
    { pregled: zebra, oznaka, strelica sortiranja, podnozje }
    F := NewForm(520, 300);
    try
      Gr := TaGrid.Create(F);
      Gr.Parent := F;
      Gr.SetBounds(10, 10, 495, 275);
      Gr.DataSource := Ds;
      Q.Open;
      G := TaOwnGridEngine(Gr.Engine).Grid;
      G.Zebra := True;
      G.SortField := 'naziv';
      G.FooterText := 'iznos: 3.115,50';
      Q.RecNo := 3;
      G.SelectAllRecords;
      G.ClearSelection;
      Finish('06_tablica_pregled', F);
    finally
      F.Free;
    end;
    { uredjivanje: otvoren uredjivac u celiji }
    F := NewForm(520, 300);
    try
      Gr := TaGrid.Create(F);
      Gr.Parent := F;
      Gr.Variant := gvEditable;
      Gr.SetBounds(10, 10, 495, 275);
      Gr.DataSource := Ds;
      G := TaOwnGridEngine(Gr.Engine).Grid;
      Q.Close;
      Q.Open;
      Q.RecNo := 2;
      F.Show;
      Application.ProcessMessages;
      TGCrack(G).Key(VK_RIGHT);
      TGCrack(G).Key(VK_F2);
      Finish('07_tablica_uredjivanje', F);
    finally
      F.Free;
    end;
    { potkartica }
    F := NewForm(520, 340);
    try
      G := TaOwnGrid.Create(F);
      G.Parent := F;
      G.SetBounds(10, 10, 495, 315);
      G.SubKeyField := 'id';
      G.OnSubOpen := @Sub.Open;
      G.OnSubClose := @Sub.Close;
      Q.Close;
      G.DataSource := Ds;
      Q.Open;
      G.ExpandKey('1');
      G.ExpandKey('3');
      Finish('08_tablica_potkartica', F);
      G.CollapseAll;
    finally
      F.Free;
    end;
    { zamrznuti stupci }
    F := NewForm(520, 300);
    try
      G := TaOwnGrid.Create(F);
      G.Parent := F;
      G.SetBounds(10, 10, 495, 275);
      G.DataSource := nil;
      Q.Close;
      G.DataSource := Ds;
      Q.Open;
      for I := 0 to G.Columns.Count - 1 do G.Columns[I].Width := 200;
      G.FrozenColumns := 1;
      TaOwnGrid(G).Width := 495;
      Finish('09_tablica_zamrznuto', F);
    finally
      F.Free;
    end;
  finally
    Ds.Free;
    Db.Free;
  end;
end;

begin
  Application.Initialize;
  Application.Scaled := False;
  WindowFrames := False;
  SetBuiltinTheme(0, False, shRounded, False);
  SetPreferredProvider('own');
  Mode := 'check';
  if ParamCount >= 1 then Mode := ParamStr(1);
  GoldenDir := ExtractFilePath(ParamStr(0)) + 'golden';
  OutDir := ExtractFilePath(ParamStr(0)) + 'out';
  ForceDirectories(GoldenDir);
  ForceDirectories(OutDir);
  SceneEdits;
  ScenePopups;
  SceneMemoList;
  SceneCalendars;
  SceneGrids;
  SceneRich;
  SceneTree;
  SceneIcons;
  SceneBoard;
  SceneDash;
  SceneTimeline;
  WriteLn('slucajeva=', Total, ' razlika=', Failed);
  if Failed > 0 then Halt(1);
end.
