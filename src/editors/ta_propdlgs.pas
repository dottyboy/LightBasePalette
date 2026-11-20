unit ta_propdlgs;
{ Dijalozi za svojstva koja se inace pisala rukom: izvor podataka popisa (RowSource),
  akcija gumba, uvjetno oblikovanje i automatsko popunjavanje. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Dialogs, StdCtrls, ExtCtrls, Graphics, ta_meta, ta_condfmt, ta_controls, ta_formdef;

{ RowSource padajuce liste, popisa, grupe opcija ili grafikona. }
function RunRowSourceBuilder(AOwner: TComponent; ADb: TAppDb; const AKind: string; var AValue: string): Boolean;
{ OnClick gumba: "verb" ili "verb:argument". }
function RunActionBuilder(AOwner: TComponent; ADb: TAppDb; AControls: TStrings; var AValue: string): Boolean;
{ Pravila "izraz => #boja #pozadina bold ;; ..." }
function RunCondFormatBuilder(AOwner: TComponent; AFields: TStrings; var AValue: string): Boolean;
{ "polje>tablica.kljuc:odrediste=izvor,..." }
function RunAutoFillBuilder(AOwner: TComponent; ADb: TAppDb; AFormFields: TStrings; var AValue: string): Boolean;
{ Pravila izracuna (CalcRules): "a,b -> cilj = izraz ;; ..."; AFields su polja izvora ili podforme. }
function RunCalcRulesBuilder(AOwner: TComponent; AFields: TStrings; var AValue: string): Boolean;
{ Poredak izvjesca (SortBy): do 4 polja, svako uzlazno ili silazno; rezultat npr. "naziv, iznos DESC". }
function RunSortBuilder(AOwner: TComponent; AFields: TStrings; var AValue: string): Boolean;
{ Ponudeni poredci izvjesca (SortOptions): do 6 redaka "naziv = poredak", odabir pri ispisu. }
function RunSortOptionsBuilder(AOwner: TComponent; AFields: TStrings; var AValue: string): Boolean;

{ Popis vrijednosti (LOV, F9) kontrole: izvor, preslikavanje "stupac=kontrola;..." i provjera iz popisa.
  ATargets su nazivi kontrola forme. }
function RunLovBuilder(AOwner: TComponent; ADb: TAppDb; ATargets: TStrings; var ASource, AMap: string;
  var AValidate: Boolean): Boolean;
{ LOV po celiji tablice (GridLov): "polje | izvor | stupac=polje;... ;; ..."; AFormFields su stupci izvora forme. }
function RunGridLovBuilder(AOwner: TComponent; ADb: TAppDb; AFormFields: TStrings; var AValue: string): Boolean;
{ razdvaja/sastavlja zapis GridLov; za testove }
function GridLovEntry(const AValue, AField: string; out ASource, AMap: string): Boolean;
function GridLovSet(const AValue, AField, ASource, AMap: string): string;

{ Klasa svojstava (19.7): izbor svojstava kontrole koja idu u klasu, naziv klase, spremanje i brisanje.
  AName je ulaz i izlaz (naziv klase koja se postavlja kontroli). True = klasa je spremljena i AName je postavljen. }
function RunPropClassDialog(AOwner: TComponent; ADb: TAppDb; D: TaControlDef; var AName: string): Boolean;
{ Izbor jedne stavke iz popisa (npr. grupa kontrola za umetanje). }
function RunPickDialog(AOwner: TComponent; const ATitle, APrompt: string; AItems: TStrings; out ASel: string): Boolean;

{ SQL koji gradi RowSource iz tablice; za testove. }
function RowSourceSql(const ASource, AKey, ADisplay: string): string;
function ChartSourceSql(const ASource, ALabel, AValue, AFunc: string): string;

implementation

uses
  ta_i18n,
  CheckLst, ta_wizardgen, ta_params, ta_propclass;

function RowSourceSql(const ASource, AKey, ADisplay: string): string;
begin
  Result := 'SELECT ' + QuoteIdent(AKey) + ', ' + QuoteIdent(ADisplay) + ' FROM ' + QuoteIdent(ASource) + ' ORDER BY ' + QuoteIdent(ADisplay);
end;

function ChartSourceSql(const ASource, ALabel, AValue, AFunc: string): string;
begin
  Result := 'SELECT ' + QuoteIdent(ALabel) + ', ' + AFunc + '(' + QuoteIdent(AValue) + ') FROM ' + QuoteIdent(ASource) + ' GROUP BY ' + QuoteIdent(ALabel) +
    ' ORDER BY ' + QuoteIdent(ALabel);
end;

function FieldsOf(ADb: TAppDb; const ASource: string): TStringList;
var
  L: TaSourceFields;
  I: Integer;
begin
  Result := TStringList.Create;
  if (ADb = nil) or (Trim(ASource) = '') then Exit;
  Inc(ADb.QuietParams);
  try
    try
      L := SourceFieldList(ADb, ASource);
    except
      Exit;
    end;
  finally
    Dec(ADb.QuietParams);
  end;
  for I := 0 to High(L) do Result.Add(L[I].Name);
end;

function Cmb(AOwner: TComponent; AParent: TWinControl; X, Y, W: Integer; AEditable: Boolean = False): TComboBox;
begin
  Result := TComboBox.Create(AOwner);
  Result.Parent := AParent;
  if not AEditable then Result.Style := csDropDownList;
  Result.SetBounds(X, Y, W, 26);
end;

procedure Lbl(AOwner: TComponent; AParent: TWinControl; const ACap: string; X, Y: Integer);
begin
  with TLabel.Create(AOwner) do begin Parent := AParent; Caption := ACap; SetBounds(X, Y, 300, 18); end;
end;

{ ---------------- RowSource ---------------- }

type
  TRsDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    Kind: string;
    Mode: TRadioGroup;
    Src, KeyBox, DispBox, FuncBox: TComboBox;
    ListMemo, SqlMemo: TMemo;
    procedure SrcChange(Sender: TObject);
    procedure ModeClick(Sender: TObject);
  end;

procedure TRsDlg.SrcChange(Sender: TObject);
var
  F: TStringList;
begin
  F := FieldsOf(Db, Src.Text);
  try
    KeyBox.Items.Assign(F);
    DispBox.Items.Assign(F);
    if F.Count > 0 then KeyBox.ItemIndex := 0;
    if F.Count > 1 then DispBox.ItemIndex := 1 else if F.Count > 0 then DispBox.ItemIndex := 0;
  finally
    F.Free;
  end;
end;

procedure TRsDlg.ModeClick(Sender: TObject);
begin
  ListMemo.Visible := Mode.ItemIndex = 1;
  SqlMemo.Visible := Mode.ItemIndex = 2;
  Src.Enabled := Mode.ItemIndex = 0;
  KeyBox.Enabled := Mode.ItemIndex = 0;
  DispBox.Enabled := Mode.ItemIndex = 0;
  FuncBox.Enabled := (Mode.ItemIndex = 0) and (Kind = 'Chart');
end;

function RunRowSourceBuilder(AOwner: TComponent; ADb: TAppDb; const AKind: string; var AValue: string): Boolean;
var
  D: TRsDlg;
  T, Tmp: TStringList;
  Funcs: array[0..4] of string;
  FuncNames: array[0..4] of string;
  I: Integer;
  Out_: string;
begin
  Result := False;
  Funcs[0] := 'SUM'; Funcs[1] := 'COUNT'; Funcs[2] := 'AVG'; Funcs[3] := 'MIN'; Funcs[4] := 'MAX';
  FuncNames[0] := 'Zbroj'; FuncNames[1] := 'Broj'; FuncNames[2] := 'Prosjek'; FuncNames[3] := 'Najmanje'; FuncNames[4] := 'Najviše';
  D := TRsDlg.Create;
  D.Db := ADb;
  D.Kind := AKind;
  D.Form := TForm.CreateNew(AOwner);
  T := TStringList.Create;
  try
    D.Form.Caption := Tr('Data source for ') + AKind;
    D.Form.SetBounds(0, 0, 560, 470);
    D.Form.Position := poOwnerFormCenter;
    D.Mode := TRadioGroup.Create(D.Form);
    D.Mode.Parent := D.Form;
    D.Mode.SetBounds(12, 10, 530, 56);
    D.Mode.Columns := 3;
    D.Mode.Items.Add('Iz tablice ili upita');
    if AKind <> 'Chart' then D.Mode.Items.Add('Vlastiti popis') else D.Mode.Items.Add(Tr('(not possible)'));
    D.Mode.Items.Add('SQL upit');
    D.Mode.ItemIndex := 0;
    Tmp := ADb.UserTables;
    try T.AddStrings(Tmp); finally Tmp.Free; end;
    Tmp := ADb.ListObjects('_sys_queries');
    try T.AddStrings(Tmp); finally Tmp.Free; end;
    Lbl(D.Form, D.Form, Tr('Table or query'), 12, 76);
    D.Src := Cmb(D.Form, D.Form, 12, 96, 300);
    D.Src.Items.Assign(T);
    if AKind = 'Chart' then Lbl(D.Form, D.Form, Tr('Field for labels (X axis)'), 12, 130) else Lbl(D.Form, D.Form, Tr('Field that is stored (key)'), 12, 130);
    D.KeyBox := Cmb(D.Form, D.Form, 12, 150, 250);
    if AKind = 'Chart' then Lbl(D.Form, D.Form, Tr('Field for values'), 290, 130) else Lbl(D.Form, D.Form, Tr('Field that is shown'), 290, 130);
    D.DispBox := Cmb(D.Form, D.Form, 290, 150, 250);
    Lbl(D.Form, D.Form, Tr('Function (chart)'), 12, 184);
    D.FuncBox := Cmb(D.Form, D.Form, 12, 204, 200);
    for I := 0 to 4 do D.FuncBox.Items.Add(FuncNames[I]);
    D.FuncBox.ItemIndex := 0;
    D.ListMemo := TMemo.Create(D.Form);
    D.ListMemo.Parent := D.Form;
    D.ListMemo.SetBounds(12, 240, 530, 170);
    D.ListMemo.TextHint := Tr('one value per row');
    D.SqlMemo := TMemo.Create(D.Form);
    D.SqlMemo.Parent := D.Form;
    D.SqlMemo.SetBounds(12, 240, 530, 170);
    D.SqlMemo.Text := AValue;
    D.Src.OnChange := @D.SrcChange;
    D.Mode.OnClick := @D.ModeClick;
    if (Trim(AValue) <> '') then
    begin
      D.Mode.ItemIndex := 2;
      if (UpperCase(Copy(Trim(AValue), 1, 6)) <> 'SELECT') and (AKind <> 'Chart') then
      begin
        D.Mode.ItemIndex := 1;
        D.ListMemo.Text := StringReplace(AValue, ';', LineEnding, [rfReplaceAll]);
      end;
    end;
    D.ModeClick(nil);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(340, 424, 96, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(444, 424, 96, 30); end;
    if D.Form.ShowModal <> mrOk then Exit;
    case D.Mode.ItemIndex of
      0:
        begin
          if (D.Src.Text = '') or (D.KeyBox.Text = '') or (D.DispBox.Text = '') then Exit;
          if AKind = 'Chart' then Out_ := ChartSourceSql(D.Src.Text, D.KeyBox.Text, D.DispBox.Text, Funcs[D.FuncBox.ItemIndex])
          else Out_ := RowSourceSql(D.Src.Text, D.KeyBox.Text, D.DispBox.Text);
        end;
      1:
        begin
          Out_ := '';
          for I := 0 to D.ListMemo.Lines.Count - 1 do
            if Trim(D.ListMemo.Lines[I]) <> '' then
            begin
              if Out_ <> '' then Out_ := Out_ + ';';
              Out_ := Out_ + Trim(D.ListMemo.Lines[I]);
            end;
        end;
    else
      Out_ := Trim(D.SqlMemo.Text);
    end;
    AValue := Out_;
    Result := True;
  finally
    T.Free;
    D.Form.Free;
    D.Free;
  end;
end;

{ ---------------- akcija ---------------- }

type
  TActDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    Verb, Arg: TComboBox;
    ArgLbl: TLabel;
    Forms, Reports, Macros, Controls: TStringList;
    procedure VerbChange(Sender: TObject);
  end;

const
  ActVerbs: array[0..22] of string = (
    'first', 'prior', 'next', 'last', 'new', 'delete', 'save', 'undo', 'refresh', 'close', 'duplicate',
    'export', 'audit', 'openform', 'openreport', 'macro', 'run', 'msg', 'sql', 'filter', 'nofilter', 'goto', 'requery');

procedure TActDlg.VerbChange(Sender: TObject);
var
  V: string;
begin
  V := Verb.Text;
  Arg.Items.Clear;
  Arg.Enabled := True;
  ArgLbl.Caption := Tr('Argument');
  if V = 'openform' then begin ArgLbl.Caption := Tr('Form'); Arg.Items.Assign(Forms); end
  else if V = 'openreport' then begin ArgLbl.Caption := Tr('Report'); Arg.Items.Assign(Reports); end
  else if V = 'macro' then begin ArgLbl.Caption := Tr('Macro'); Arg.Items.Assign(Macros); end
  else if V = 'goto' then begin ArgLbl.Caption := Tr('Control'); Arg.Items.Assign(Controls); end
  else if V = 'run' then ArgLbl.Caption := Tr('Procedure (from a module)')
  else if V = 'msg' then ArgLbl.Caption := Tr('Message')
  else if V = 'sql' then ArgLbl.Caption := Tr('SQL statement')
  else if V = 'filter' then ArgLbl.Caption := Tr('Condition (SQL)')
  else if V = 'export' then ArgLbl.Caption := Tr('File (empty = ask)')
  else begin Arg.Text := ''; Arg.Enabled := False; ArgLbl.Caption := Tr('(no argument)'); end;
end;

function RunActionBuilder(AOwner: TComponent; ADb: TAppDb; AControls: TStrings; var AValue: string): Boolean;
var
  D: TActDlg;
  I, P: Integer;
  V, A: string;
  T: TStringList;
begin
  Result := False;
  D := TActDlg.Create;
  D.Db := ADb;
  D.Forms := TStringList.Create;
  D.Reports := TStringList.Create;
  D.Macros := TStringList.Create;
  D.Controls := TStringList.Create;
  D.Form := TForm.CreateNew(AOwner);
  try
    T := ADb.ListObjects('_sys_forms'); try D.Forms.AddStrings(T); finally T.Free; end;
    T := ADb.ListObjects('_sys_reports'); try D.Reports.AddStrings(T); finally T.Free; end;
    T := ADb.ListObjects('_sys_macros'); try D.Macros.AddStrings(T); finally T.Free; end;
    if AControls <> nil then D.Controls.AddStrings(AControls);
    D.Form.Caption := Tr('Button action');
    D.Form.SetBounds(0, 0, 480, 230);
    D.Form.Position := poOwnerFormCenter;
    Lbl(D.Form, D.Form, Tr('What the button does'), 12, 12);
    D.Verb := Cmb(D.Form, D.Form, 12, 32, 250);
    for I := 0 to High(ActVerbs) do D.Verb.Items.Add(ActVerbs[I]);
    D.ArgLbl := TLabel.Create(D.Form);
    D.ArgLbl.Parent := D.Form;
    D.ArgLbl.SetBounds(12, 72, 440, 18);
    D.Arg := Cmb(D.Form, D.Form, 12, 92, 440, True);
    D.Verb.OnChange := @D.VerbChange;
    P := Pos(':', AValue);
    if P > 0 then begin V := Copy(AValue, 1, P - 1); A := Copy(AValue, P + 1, MaxInt); end
    else begin V := Trim(AValue); A := ''; end;
    D.Verb.ItemIndex := D.Verb.Items.IndexOf(LowerCase(V));
    D.VerbChange(nil);
    D.Arg.Text := A;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(252, 170, 96, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(356, 170, 96, 30); end;
    if D.Form.ShowModal <> mrOk then Exit;
    if D.Verb.Text = '' then Exit;
    if Trim(D.Arg.Text) = '' then AValue := D.Verb.Text else AValue := D.Verb.Text + ':' + Trim(D.Arg.Text);
    Result := True;
  finally
    D.Forms.Free; D.Reports.Free; D.Macros.Free; D.Controls.Free;
    D.Form.Free;
    D.Free;
  end;
end;

{ ---------------- uvjetno oblikovanje ---------------- }

const
  CfRows = 5;
  CfOps: array[0..5] of string = ('=', '<>', '>', '<', '>=', '<=');

type
  TCfDlg = class
  public
    Form: TForm;
    Field, Op: array[0..CfRows - 1] of TComboBox;
    Val: array[0..CfRows - 1] of TEdit;
    Fore, Back: array[0..CfRows - 1] of TPanel;
    Bold: array[0..CfRows - 1] of TCheckBox;
    Extra: TMemo;
    procedure SwatchClick(Sender: TObject);
  end;

procedure TCfDlg.SwatchClick(Sender: TObject);
var
  P: TPanel;
  Cd: TColorDialog;
begin
  P := TPanel(Sender);
  Cd := TColorDialog.Create(Form);
  try
    if P.Tag = 0 then Cd.Color := clWhite else Cd.Color := P.Color;
    if Cd.Execute then
    begin
      P.Color := Cd.Color;
      P.Tag := 1;
      P.Caption := '';
    end
    else if MessageDlg(Tr('Remove the color?'), mtConfirmation, [mbYes, mbNo], 0) = mrYes then
    begin
      P.Tag := 0;
      P.Color := clBtnFace;
      P.Caption := Tr('(none)');
    end;
  finally
    Cd.Free;
  end;
end;

function SplitSimple(const AExpr: string; out AField, AOp, AVal: string): Boolean;
var
  E: string;
  I, P: Integer;
begin
  Result := False;
  E := Trim(AExpr);
  if (E = '') or (E[1] <> '[') then Exit;
  P := Pos(']', E);
  if P < 2 then Exit;
  AField := Copy(E, 2, P - 2);
  E := Trim(Copy(E, P + 1, MaxInt));
  for I := 0 to High(CfOps) do
    if (Copy(E, 1, Length(CfOps[I])) = CfOps[I]) and
       ((I >= 2) or (Copy(E, 1, 2) <> '<>')) then
    begin
      AOp := CfOps[I];
      if (AOp = '<') and (Copy(E, 1, 2) = '<>') then AOp := '<>'
      else if (AOp = '>') and (Copy(E, 1, 2) = '>=') then AOp := '>=';
      if (AOp = '<') and (Copy(E, 1, 2) = '<=') then AOp := '<=';
      AVal := Trim(Copy(E, Length(AOp) + 1, MaxInt));
      Exit((AVal <> '') and (Pos(' and ', LowerCase(AVal)) = 0) and (Pos(' or ', LowerCase(AVal)) = 0));
    end;
end;

function IsNumberText(const S: string): Boolean;
var
  I: Integer;
begin
  Result := S <> '';
  for I := 1 to Length(S) do
    if not (S[I] in ['0'..'9', '.', '-']) then Exit(False);
end;

function ColorText(P: TPanel): string;
begin
  if P.Tag = 0 then Result := '-' else Result := ColorToHex(P.Color);
end;

function RunCondFormatBuilder(AOwner: TComponent; AFields: TStrings; var AValue: string): Boolean;
var
  D: TCfDlg;
  Rules: TCondRules;
  I, N: Integer;
  F, O, V, Line, Out_: string;
  Y: Integer;
  Left_: TStringList;
begin
  Result := False;
  D := TCfDlg.Create;
  D.Form := TForm.CreateNew(AOwner);
  Left_ := TStringList.Create;
  try
    D.Form.Caption := Tr('Conditional formatting');
    D.Form.SetBounds(0, 0, 820, 470);
    D.Form.Position := poOwnerFormCenter;
    Lbl(D.Form, D.Form, Tr('If the field is...'), 12, 10);
    Lbl(D.Form, D.Form, Tr('value'), 250, 10);
    Lbl(D.Form, D.Form, Tr('text color'), 450, 10);
    Lbl(D.Form, D.Form, Tr('background'), 560, 10);
    Lbl(D.Form, D.Form, Tr('bold'), 660, 10);
    for I := 0 to CfRows - 1 do
    begin
      Y := 32 + I * 40;
      D.Field[I] := Cmb(D.Form, D.Form, 12, Y, 150, True);
      if AFields <> nil then D.Field[I].Items.Assign(AFields);
      D.Op[I] := Cmb(D.Form, D.Form, 168, Y, 70);
      D.Op[I].Items.CommaText := '=,<>,>,<,>=,<=';
      D.Op[I].ItemIndex := 2;
      D.Val[I] := TEdit.Create(D.Form);
      D.Val[I].Parent := D.Form;
      D.Val[I].SetBounds(244, Y, 190, 26);
      D.Fore[I] := TPanel.Create(D.Form);
      D.Fore[I].Parent := D.Form;
      D.Fore[I].SetBounds(450, Y, 90, 26);
      D.Fore[I].Caption := Tr('(none)');
      D.Fore[I].OnClick := @D.SwatchClick;
      D.Back[I] := TPanel.Create(D.Form);
      D.Back[I].Parent := D.Form;
      D.Back[I].SetBounds(560, Y, 90, 26);
      D.Back[I].Caption := Tr('(none)');
      D.Back[I].OnClick := @D.SwatchClick;
      D.Bold[I] := TCheckBox.Create(D.Form);
      D.Bold[I].Parent := D.Form;
      D.Bold[I].SetBounds(670, Y + 3, 30, 22);
    end;
    Lbl(D.Form, D.Form, Tr('More complex rules (expression => #color #background bold), separate several with ;;'), 12, 240);
    D.Extra := TMemo.Create(D.Form);
    D.Extra.Parent := D.Form;
    D.Extra.SetBounds(12, 262, 790, 110);
    { postojeca pravila: jednostavna idu u retke, ostala u memo }
    Rules := ParseCondFormat(AValue);
    N := 0;
    for I := 0 to High(Rules) do
    begin
      if (N < CfRows) and SplitSimple(Rules[I].Expr, F, O, V) then
      begin
        D.Field[N].Text := F;
        D.Op[N].ItemIndex := D.Op[N].Items.IndexOf(O);
        D.Val[N].Text := V;
        if Rules[I].Fore <> '' then begin D.Fore[N].Color := HexToColor(Rules[I].Fore, clBlack); D.Fore[N].Tag := 1; D.Fore[N].Caption := ''; end;
        if Rules[I].Back <> '' then begin D.Back[N].Color := HexToColor(Rules[I].Back, clWhite); D.Back[N].Tag := 1; D.Back[N].Caption := ''; end;
        D.Bold[N].Checked := Rules[I].Bold;
        Inc(N);
      end
      else
      begin
        Line := Rules[I].Expr + ' =>';
        if Rules[I].Fore <> '' then Line := Line + ' ' + Rules[I].Fore else Line := Line + ' -';
        if Rules[I].Back <> '' then Line := Line + ' ' + Rules[I].Back;
        if Rules[I].Bold then Line := Line + ' bold';
        Left_.Add(Line);
      end;
    end;
    D.Extra.Lines.Assign(Left_);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(600, 392, 96, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(704, 392, 96, 30); end;
    if D.Form.ShowModal <> mrOk then Exit;
    Out_ := '';
    for I := 0 to CfRows - 1 do
    begin
      if (Trim(D.Field[I].Text) = '') or (Trim(D.Val[I].Text) = '') then Continue;
      V := Trim(D.Val[I].Text);
      if not (IsNumberText(V) or (V[1] in ['"', '[', '#']) or (LowerCase(V) = 'true') or (LowerCase(V) = 'false') or (LowerCase(V) = 'null')) then
        V := '"' + V + '"';
      Line := '[' + Trim(D.Field[I].Text) + '] ' + CfOps[D.Op[I].ItemIndex] + ' ' + V + ' => ' + ColorText(D.Fore[I]);
      if D.Back[I].Tag <> 0 then Line := Line + ' ' + ColorText(D.Back[I]);
      if D.Bold[I].Checked then Line := Line + ' bold';
      if Out_ <> '' then Out_ := Out_ + ' ;; ';
      Out_ := Out_ + Line;
    end;
    for I := 0 to D.Extra.Lines.Count - 1 do
      if Trim(D.Extra.Lines[I]) <> '' then
      begin
        if Out_ <> '' then Out_ := Out_ + ' ;; ';
        Out_ := Out_ + Trim(D.Extra.Lines[I]);
      end;
    AValue := Out_;
    Result := True;
  finally
    Left_.Free;
    D.Form.Free;
    D.Free;
  end;
end;

{ ---------------- automatsko popunjavanje ---------------- }

const
  AfRows = 6;

type
  TAfDlg = class
  public
    Db: TAppDb;
    Form: TForm;
    LookupField, TableBox, KeyBox: TComboBox;
    Dest, SrcF: array[0..AfRows - 1] of TComboBox;
    procedure TableChange(Sender: TObject);
  end;

procedure TAfDlg.TableChange(Sender: TObject);
var
  F: TStringList;
  I: Integer;
begin
  F := FieldsOf(Db, TableBox.Text);
  try
    KeyBox.Items.Assign(F);
    if F.Count > 0 then KeyBox.ItemIndex := 0;
    for I := 0 to AfRows - 1 do SrcF[I].Items.Assign(F);
  finally
    F.Free;
  end;
end;

function RunAutoFillBuilder(AOwner: TComponent; ADb: TAppDb; AFormFields: TStrings; var AValue: string): Boolean;
var
  D: TAfDlg;
  T, Tmp, Pairs, Pr: TStringList;
  I, P, Q: Integer;
  Head, Rest, Out_: string;
begin
  Result := False;
  D := TAfDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  T := TStringList.Create;
  Pairs := TStringList.Create;
  try
    D.Form.Caption := Tr('Automatic filling');
    D.Form.SetBounds(0, 0, 640, 470);
    D.Form.Position := poOwnerFormCenter;
    Tmp := ADb.UserTables;
    try T.AddStrings(Tmp); finally Tmp.Free; end;
    Tmp := ADb.ListObjects('_sys_queries');
    try T.AddStrings(Tmp); finally Tmp.Free; end;
    Lbl(D.Form, D.Form, Tr('When the field changes'), 12, 10);
    D.LookupField := Cmb(D.Form, D.Form, 12, 30, 240, True);
    if AFormFields <> nil then D.LookupField.Items.Assign(AFormFields);
    Lbl(D.Form, D.Form, Tr('take data from the table'), 270, 10);
    D.TableBox := Cmb(D.Form, D.Form, 270, 30, 190);
    D.TableBox.Items.Assign(T);
    Lbl(D.Form, D.Form, Tr('by field (key)'), 475, 10);
    D.KeyBox := Cmb(D.Form, D.Form, 475, 30, 140);
    Lbl(D.Form, D.Form, Tr('Write to field'), 12, 72);
    Lbl(D.Form, D.Form, Tr('value from the column'), 330, 72);
    for I := 0 to AfRows - 1 do
    begin
      D.Dest[I] := Cmb(D.Form, D.Form, 12, 94 + I * 36, 300, True);
      if AFormFields <> nil then D.Dest[I].Items.Assign(AFormFields);
      D.SrcF[I] := Cmb(D.Form, D.Form, 330, 94 + I * 36, 285);
    end;
    D.TableBox.OnChange := @D.TableChange;
    { postojece pravilo }
    P := Pos('>', AValue);
    Q := Pos(':', AValue);
    if (P > 1) and (Q > P) then
    begin
      D.LookupField.Text := Trim(Copy(AValue, 1, P - 1));
      Head := Copy(AValue, P + 1, Q - P - 1);
      Rest := Copy(AValue, Q + 1, MaxInt);
      if Pos('.', Head) > 0 then
      begin
        D.TableBox.ItemIndex := D.TableBox.Items.IndexOf(Copy(Head, 1, Pos('.', Head) - 1));
        D.TableChange(nil);
        D.KeyBox.ItemIndex := D.KeyBox.Items.IndexOf(Copy(Head, Pos('.', Head) + 1, MaxInt));
        Pairs.Delimiter := ',';
        Pairs.StrictDelimiter := True;
        Pairs.DelimitedText := Rest;
        for I := 0 to Pairs.Count - 1 do
          if I < AfRows then
          begin
            D.Dest[I].Text := Trim(Copy(Pairs[I], 1, Pos('=', Pairs[I]) - 1));
            D.SrcF[I].ItemIndex := D.SrcF[I].Items.IndexOf(Trim(Copy(Pairs[I], Pos('=', Pairs[I]) + 1, MaxInt)));
          end;
      end;
    end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(420, 410, 96, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(524, 410, 96, 30); end;
    if D.Form.ShowModal <> mrOk then Exit;
    if (Trim(D.LookupField.Text) = '') or (D.TableBox.Text = '') or (D.KeyBox.Text = '') then Exit;
    Out_ := '';
    for I := 0 to AfRows - 1 do
      if (Trim(D.Dest[I].Text) <> '') and (D.SrcF[I].Text <> '') then
      begin
        if Out_ <> '' then Out_ := Out_ + ',';
        Out_ := Out_ + Trim(D.Dest[I].Text) + '=' + D.SrcF[I].Text;
      end;
    if Out_ = '' then Exit;
    AValue := Trim(D.LookupField.Text) + '>' + D.TableBox.Text + '.' + D.KeyBox.Text + ':' + Out_;
    Result := True;
  finally
    T.Free;
    Pairs.Free;
    D.Form.Free;
    D.Free;
  end;
  if Pr = nil then;
end;

{ ---------------- pravila izracuna (CalcRules) ---------------- }

const
  CrRows = 4;

type
  TCrDlg = class
  public
    Fields: TStrings;
    Form: TForm;
    Trig: array[0..CrRows - 1, 0..2] of TComboBox;
    Dest: array[0..CrRows - 1] of TComboBox;
    Expr: array[0..CrRows - 1] of TEdit;
    procedure PresetClick(Sender: TObject);
    procedure ClearClick(Sender: TObject);
    function HasField(const AName: string): Boolean;
    procedure SetRule(I: Integer; const ATrig: array of string; const ADest, AExpr: string);
  end;

function TCrDlg.HasField(const AName: string): Boolean;
begin
  Result := (Fields <> nil) and (Fields.IndexOf(AName) >= 0);
end;

procedure TCrDlg.SetRule(I: Integer; const ATrig: array of string; const ADest, AExpr: string);
var
  J: Integer;
begin
  for J := 0 to 2 do
    if J <= High(ATrig) then Trig[I, J].Text := ATrig[J] else Trig[I, J].Text := '';
  Dest[I].Text := ADest;
  Expr[I].Text := AExpr;
end;

procedure TCrDlg.ClearClick(Sender: TObject);
var
  I: Integer;
begin
  for I := 0 to CrRows - 1 do SetRule(I, [], '', '');
end;

{ gotov par pravila za racun: cijena, kolicina (i rabat) -> iznos, i iznos -> cijena }
procedure TCrDlg.PresetClick(Sender: TObject);
var
  Disc: string;
  Trg: array of string;
begin
  if not (HasField('kolicina') and HasField('cijena') and HasField('iznos')) then
  begin
    ShowMessage(Tr('The template needs the fields kolicina, cijena and iznos (rabat is optional). Not all of them are here.'));
    Exit;
  end;
  if HasField('rabat') then
  begin
    Disc := ' * (1 - [rabat] / 100)';
    SetLength(Trg, 3); Trg[0] := 'kolicina'; Trg[1] := 'cijena'; Trg[2] := 'rabat';
  end
  else
  begin
    Disc := '';
    SetLength(Trg, 2); Trg[0] := 'kolicina'; Trg[1] := 'cijena';
  end;
  ClearClick(nil);
  SetRule(0, Trg, 'iznos', 'Zaokruzi([kolicina] * [cijena]' + Disc + ', 2)');
  SetRule(1, ['iznos'], 'cijena', 'Zaokruzi([iznos] / ([kolicina]' + Disc + '), 4)');
end;

function RunCalcRulesBuilder(AOwner: TComponent; AFields: TStrings; var AValue: string): Boolean;
var
  D: TCrDlg;
  Txt, Rule, Head, Rest, Out_, One: string;
  P, Q, I, J, N: Integer;
  Names: TStringList;
begin
  Result := False;
  D := TCrDlg.Create;
  D.Fields := AFields;
  D.Form := TForm.CreateNew(AOwner);
  Names := TStringList.Create;
  try
    D.Form.Caption := Tr('Calculation rules');
    D.Form.SetBounds(0, 0, 1110, 400);
    D.Form.Position := poOwnerFormCenter;
    Lbl(D.Form, D.Form, Tr('When one of the fields changes...'), 12, 10);
    Lbl(D.Form, D.Form, Tr('...write to field'), 460, 10);
    Lbl(D.Form, D.Form, Tr('expression (e.g. Round([quantity] * [price], 2))'), 610, 10);
    for I := 0 to CrRows - 1 do
    begin
      for J := 0 to 2 do
      begin
        D.Trig[I, J] := Cmb(D.Form, D.Form, 12 + J * 146, 32 + I * 40, 138, True);
        if AFields <> nil then D.Trig[I, J].Items.Assign(AFields);
      end;
      D.Dest[I] := Cmb(D.Form, D.Form, 460, 32 + I * 40, 140, True);
      if AFields <> nil then D.Dest[I].Items.Assign(AFields);
      D.Expr[I] := TEdit.Create(D.Form);
      D.Expr[I].Parent := D.Form;
      D.Expr[I].SetBounds(610, 32 + I * 40, 488, 26);
    end;
    { postojeca pravila }
    Txt := AValue;
    N := 0;
    while (Trim(Txt) <> '') and (N < CrRows) do
    begin
      P := Pos(';;', Txt);
      if P = 0 then begin Rule := Txt; Txt := ''; end
      else begin Rule := Copy(Txt, 1, P - 1); Txt := Copy(Txt, P + 2, MaxInt); end;
      P := Pos('->', Rule);
      if P < 2 then Continue;
      Head := Trim(Copy(Rule, 1, P - 1));
      Rest := Copy(Rule, P + 2, MaxInt);
      Q := Pos('=', Rest);
      if Q < 2 then Continue;
      Names.Clear;
      Names.Delimiter := ',';
      Names.StrictDelimiter := True;
      Names.DelimitedText := Head;
      for J := 0 to 2 do
        if J < Names.Count then D.Trig[N, J].Text := Trim(Names[J]);
      D.Dest[N].Text := Trim(Copy(Rest, 1, Q - 1));
      D.Expr[N].Text := Trim(Copy(Rest, Q + 1, MaxInt));
      Inc(N);
    end;
    with TLabel.Create(D.Form) do
    begin
      Parent := D.Form;
      AutoSize := False;
      WordWrap := True;
      Caption := Tr('The same expression language as in expressions; fields are written in square brackets. The rules work in a grid, a subform and a single-record form. ') +
        Tr('A change that a rule only writes does not trigger other rules, so a two-way entry (price <-> amount) has no loop.');
      SetBounds(12, 205, 1080, 44);
    end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Template: price <-> amount'); SetBounds(12, 300, 230, 30); OnClick := @D.PresetClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Clear'); SetBounds(250, 300, 100, 30); OnClick := @D.ClearClick; end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(890, 350, 96, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(994, 350, 96, 30); end;
    if D.Form.ShowModal <> mrOk then Exit;
    Out_ := '';
    for I := 0 to CrRows - 1 do
    begin
      if (Trim(D.Dest[I].Text) = '') or (Trim(D.Expr[I].Text) = '') then Continue;
      One := '';
      for J := 0 to 2 do
        if Trim(D.Trig[I, J].Text) <> '' then
        begin
          if One <> '' then One := One + ',';
          One := One + Trim(D.Trig[I, J].Text);
        end;
      if One = '' then Continue;
      if Out_ <> '' then Out_ := Out_ + ' ;; ';
      Out_ := Out_ + One + ' -> ' + Trim(D.Dest[I].Text) + ' = ' + Trim(D.Expr[I].Text);
    end;
    AValue := Out_;
    Result := True;
  finally
    Names.Free;
    D.Form.Free;
    D.Free;
  end;
end;

{ ---------------- poredak izvjesca (SortBy) ---------------- }

const
  SbRows = 4;

function RunSortBuilder(AOwner: TComponent; AFields: TStrings; var AValue: string): Boolean;
var
  F: TForm;
  Fld: array[0..SbRows - 1] of TComboBox;
  Dir: array[0..SbRows - 1] of TComboBox;
  Parts: TStringList;
  I, P: Integer;
  One, Name, Out_: string;
begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  Parts := TStringList.Create;
  try
    F.Caption := Tr('Report order');
    F.SetBounds(0, 0, 520, 300);
    F.Position := poOwnerFormCenter;
    Lbl(F, F, Tr('Order by field'), 12, 10);
    Lbl(F, F, Tr('direction'), 300, 10);
    for I := 0 to SbRows - 1 do
    begin
      Fld[I] := Cmb(F, F, 12, 32 + I * 38, 270, True);
      if AFields <> nil then Fld[I].Items.Assign(AFields);
      Dir[I] := Cmb(F, F, 300, 32 + I * 38, 200);
      Dir[I].Items.CommaText := '"uzlazno (A–Z, 1–9)","silazno (Z–A, 9–1)"';
      Dir[I].ItemIndex := 0;
    end;
    { postojeci poredak: "naziv, iznos DESC" }
    Parts.Delimiter := ',';
    Parts.StrictDelimiter := True;
    Parts.DelimitedText := AValue;
    for I := 0 to Parts.Count - 1 do
      if I < SbRows then
      begin
        One := Trim(Parts[I]);
        Name := One;
        P := Pos(' ', One);
        if P > 0 then
        begin
          Name := Copy(One, 1, P - 1);
          if SameText(Trim(Copy(One, P + 1, MaxInt)), 'DESC') then Dir[I].ItemIndex := 1;
        end;
        Fld[I].Text := Name;
      end;
    with TLabel.Create(F) do
    begin
      Parent := F;
      AutoSize := False;
      WordWrap := True;
      Caption := Tr('Groups go in the order of their own values, and this order arranges the rows inside a group. For the order of entry, enter a key (e.g. id).');
      SetBounds(12, 192, 490, 40);
    end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(300, 245, 96, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(404, 245, 96, 30); end;
    if F.ShowModal <> mrOk then Exit;
    Out_ := '';
    for I := 0 to SbRows - 1 do
      if Trim(Fld[I].Text) <> '' then
      begin
        if Out_ <> '' then Out_ := Out_ + ', ';
        Out_ := Out_ + Trim(Fld[I].Text);
        if Dir[I].ItemIndex = 1 then Out_ := Out_ + ' DESC';
      end;
    AValue := Out_;
    Result := True;
  finally
    Parts.Free;
    F.Free;
  end;
end;

{ ---------------- ponudeni poredci izvjesca (SortOptions) ---------------- }

const
  SoRows = 6;

function RunSortOptionsBuilder(AOwner: TComponent; AFields: TStrings; var AValue: string): Boolean;
var
  F: TForm;
  Nm, Od: array[0..SoRows - 1] of TEdit;
  Txt, One, Out_: string;
  I, P, N: Integer;
begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := Tr('Orders offered for printing');
    F.SetBounds(0, 0, 640, 400);
    F.Position := poOwnerFormCenter;
    Lbl(F, F, Tr('Name (shown in the preview)'), 12, 10);
    Lbl(F, F, Tr('Order (fields and DESC), e.g. margin DESC, name'), 250, 10);
    for I := 0 to SoRows - 1 do
    begin
      Nm[I] := TEdit.Create(F);
      Nm[I].Parent := F;
      Nm[I].SetBounds(12, 32 + I * 36, 225, 26);
      Od[I] := TEdit.Create(F);
      Od[I].Parent := F;
      Od[I].SetBounds(250, 32 + I * 36, 372, 26);
    end;
    Txt := AValue;
    N := 0;
    while (Trim(Txt) <> '') and (N < SoRows) do
    begin
      P := Pos(';;', Txt);
      if P = 0 then begin One := Txt; Txt := ''; end
      else begin One := Copy(Txt, 1, P - 1); Txt := Copy(Txt, P + 2, MaxInt); end;
      P := Pos('=', One);
      if P < 2 then Continue;
      Nm[N].Text := Trim(Copy(One, 1, P - 1));
      Od[N].Text := Trim(Copy(One, P + 1, MaxInt));
      Inc(N);
    end;
    One := '';
    if AFields <> nil then One := 'Polja izvora: ' + StringReplace(AFields.CommaText, ',', ', ', [rfReplaceAll]) + '. ';
    with TLabel.Create(F) do
    begin
      Parent := F;
      AutoSize := False;
      WordWrap := True;
      Caption := One + Tr('The first row is the default order in the preview. The report preview shows an "Order" list, and you can set one for a button or a macro ') +
        'openreport:Izvješće#poredak=Naziv. Poredak po izračunatom polju (marža) traži to polje u izvoru izvješća.';
      SetBounds(12, 258, 610, 80);
    end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(420, 350, 96, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(524, 350, 96, 30); end;
    if F.ShowModal <> mrOk then Exit;
    Out_ := '';
    for I := 0 to SoRows - 1 do
      if (Trim(Nm[I].Text) <> '') and (Trim(Od[I].Text) <> '') then
      begin
        if Out_ <> '' then Out_ := Out_ + ' ;; ';
        Out_ := Out_ + Trim(Nm[I].Text) + '=' + Trim(Od[I].Text);
      end;
    AValue := Out_;
    Result := True;
  finally
    F.Free;
  end;
end;

{ ---------------- popis vrijednosti (LOV) ---------------- }

const
  LvRows = 5;

type
  TLvDlg = class
  public
    Db: TAppDb;
    Grid: Boolean;
    Form: TForm;
    FormFields: TStrings;
    Value: string;               { cijeli GridLov }
    FieldBox, SourceBox: TComboBox;
    Src: array[0..LvRows - 1] of TComboBox;
    Dest: array[0..LvRows - 1] of TComboBox;
    ValidateBox: TCheckBox;
    PrevField: string;
    procedure SourceChange(Sender: TObject);
    procedure FieldChange(Sender: TObject);
    procedure RemoveClick(Sender: TObject);
    procedure LoadEntry(const ASource, AMap: string);
    function MapText: string;
  end;

function GridLovEntry(const AValue, AField: string; out ASource, AMap: string): Boolean;
var
  Items, P: TStringList;
  I: Integer;
begin
  Result := False;
  ASource := ''; AMap := '';
  Items := TStringList.Create;
  P := TStringList.Create;
  try
    Items.Text := StringReplace(AValue, ';;', #10, [rfReplaceAll]);
    P.Delimiter := '|'; P.StrictDelimiter := True;
    for I := 0 to Items.Count - 1 do
    begin
      P.DelimitedText := Items[I];
      if (P.Count >= 2) and SameText(Trim(P[0]), AField) then
      begin
        ASource := Trim(P[1]);
        if P.Count >= 3 then AMap := Trim(P[2]);
        Exit(True);
      end;
    end;
  finally
    Items.Free; P.Free;
  end;
end;

{ zamijeni ili doda unos za polje; prazan izvor uklanja unos }
function GridLovSet(const AValue, AField, ASource, AMap: string): string;
var
  Items, P: TStringList;
  I: Integer;
  Entry: string;
  Done: Boolean;
begin
  Items := TStringList.Create;
  P := TStringList.Create;
  try
    Items.Text := StringReplace(AValue, ';;', #10, [rfReplaceAll]);
    for I := Items.Count - 1 downto 0 do if Trim(Items[I]) = '' then Items.Delete(I);
    P.Delimiter := '|'; P.StrictDelimiter := True;
    Entry := '';
    if Trim(ASource) <> '' then Entry := AField + ' | ' + Trim(ASource) + ' | ' + AMap;
    Done := False;
    for I := Items.Count - 1 downto 0 do
    begin
      P.DelimitedText := Items[I];
      if (P.Count >= 1) and SameText(Trim(P[0]), AField) then
      begin
        if Entry = '' then Items.Delete(I) else Items[I] := Entry;
        Done := True;
      end;
    end;
    if (not Done) and (Entry <> '') then Items.Add(Entry);
    Result := '';
    for I := 0 to Items.Count - 1 do
    begin
      if Result <> '' then Result := Result + ' ;; ';
      Result := Result + Trim(Items[I]);
    end;
  finally
    Items.Free; P.Free;
  end;
end;

procedure TLvDlg.SourceChange(Sender: TObject);
var
  F: TStringList;
  I: Integer;
begin
  F := FieldsOf(Db, Trim(SourceBox.Text));
  try
    for I := 0 to LvRows - 1 do Src[I].Items.Assign(F);
  finally
    F.Free;
  end;
end;

procedure TLvDlg.LoadEntry(const ASource, AMap: string);
var
  P: TStringList;
  I: Integer;
begin
  SourceBox.Text := ASource;
  SourceChange(nil);
  for I := 0 to LvRows - 1 do begin Src[I].Text := ''; Dest[I].Text := ''; end;
  P := TStringList.Create;
  try
    P.Delimiter := ';'; P.StrictDelimiter := True;
    P.DelimitedText := AMap;
    for I := 0 to P.Count - 1 do
      if I < LvRows then
      begin
        Src[I].Text := Trim(P.Names[I]);
        Dest[I].Text := Trim(P.ValueFromIndex[I]);
      end;
  finally
    P.Free;
  end;
end;

procedure TLvDlg.FieldChange(Sender: TObject);
var
  S, M: string;
begin
  { unos prethodnog stupca ostaje zapamcen dok se uredjuje drugi }
  if PrevField <> '' then Value := GridLovSet(Value, PrevField, Trim(SourceBox.Text), MapText);
  PrevField := Trim(FieldBox.Text);
  if GridLovEntry(Value, PrevField, S, M) then LoadEntry(S, M) else LoadEntry('', '');
end;

procedure TLvDlg.RemoveClick(Sender: TObject);
begin
  LoadEntry('', '');
end;

function TLvDlg.MapText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to LvRows - 1 do
    if (Trim(Src[I].Text) <> '') and (Trim(Dest[I].Text) <> '') then
    begin
      if Result <> '' then Result := Result + ';';
      Result := Result + Trim(Src[I].Text) + '=' + Trim(Dest[I].Text);
    end;
end;

function BuildLvDialog(AOwner: TComponent; ADb: TAppDb; ATargets: TStrings; AGrid: Boolean): TLvDlg;
var
  T, Tmp: TStringList;
  I: Integer;
begin
  Result := TLvDlg.Create;
  Result.Db := ADb;
  Result.Grid := AGrid;
  Result.FormFields := ATargets;
  Result.Form := TForm.CreateNew(AOwner);
  Result.Form.Position := poOwnerFormCenter;
  Result.Form.SetBounds(0, 0, 560, 400);
  T := TStringList.Create;
  try
    Tmp := ADb.UserTables;
    try T.AddStrings(Tmp); finally Tmp.Free; end;
    Tmp := ADb.ListObjects('_sys_queries');
    try T.AddStrings(Tmp); finally Tmp.Free; end;
    if AGrid then
    begin
      Lbl(Result.Form, Result.Form, Tr('Table column that opens the list (F9)'), 12, 8);
      Result.FieldBox := Cmb(Result.Form, Result.Form, 12, 28, 260, True);
      if ATargets <> nil then Result.FieldBox.Items.Assign(ATargets);
      Result.FieldBox.OnChange := @Result.FieldChange;
    end;
    Lbl(Result.Form, Result.Form, Tr('List source (table, query, sql:..., list:a;b;c, fgl:...)'), 12, 62);
    Result.SourceBox := Cmb(Result.Form, Result.Form, 12, 82, 530, True);
    Result.SourceBox.Items.Assign(T);
    Result.SourceBox.OnChange := @Result.SourceChange;
    Lbl(Result.Form, Result.Form, Tr('Take the source column'), 12, 118);
    if AGrid then Lbl(Result.Form, Result.Form, Tr('write to column'), 290, 118)
    else Lbl(Result.Form, Result.Form, Tr('write to control'), 290, 118);
    for I := 0 to LvRows - 1 do
    begin
      Result.Src[I] := Cmb(Result.Form, Result.Form, 12, 138 + I * 34, 260, True);
      Result.Dest[I] := Cmb(Result.Form, Result.Form, 290, 138 + I * 34, 252, True);
      if ATargets <> nil then Result.Dest[I].Items.Assign(ATargets);
    end;
    if not AGrid then
    begin
      Result.ValidateBox := TCheckBox.Create(Result.Form);
      Result.ValidateBox.Parent := Result.Form;
      Result.ValidateBox.Caption := Tr('Allow only values from the list (checked on save)');
      Result.ValidateBox.SetBounds(12, 318, 520, 22);
    end;
  finally
    T.Free;
  end;
end;

function RunLovBuilder(AOwner: TComponent; ADb: TAppDb; ATargets: TStrings; var ASource, AMap: string;
  var AValidate: Boolean): Boolean;
var
  D: TLvDlg;
begin
  Result := False;
  D := BuildLvDialog(AOwner, ADb, ATargets, False);
  try
    D.Form.Caption := Tr('List of values (LOV)');
    D.LoadEntry(ASource, AMap);
    D.ValidateBox.Checked := AValidate;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Remove list'); OnClick := @D.RemoveClick; SetBounds(12, 352, 120, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(334, 352, 96, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(438, 352, 96, 30); end;
    if D.Form.ShowModal <> mrOk then Exit;
    ASource := Trim(D.SourceBox.Text);
    AMap := D.MapText;
    AValidate := D.ValidateBox.Checked and (ASource <> '');
    Result := True;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

function RunGridLovBuilder(AOwner: TComponent; ADb: TAppDb; AFormFields: TStrings; var AValue: string): Boolean;
var
  D: TLvDlg;
  Fld, S, M: string;
  P: TStringList;
begin
  Result := False;
  D := BuildLvDialog(AOwner, ADb, AFormFields, True);
  P := TStringList.Create;
  try
    D.Form.Caption := Tr('List of values in a table (LOV per cell)');
    D.Value := AValue;
    { prvi postojeci unos }
    P.Delimiter := '|'; P.StrictDelimiter := True;
    P.DelimitedText := Copy(AValue, 1, Pos(';;', AValue + ';;') - 1);
    if P.Count > 0 then D.FieldBox.Text := Trim(P[0]);
    D.FieldChange(nil);
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Remove for column'); OnClick := @D.RemoveClick; SetBounds(12, 352, 140, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(334, 352, 96, 30); end;
    with TButton.Create(D.Form) do begin Parent := D.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(438, 352, 96, 30); end;
    if D.Form.ShowModal <> mrOk then Exit;
    Fld := Trim(D.FieldBox.Text);
    if Fld = '' then Exit;
    S := Trim(D.SourceBox.Text);
    M := D.MapText;
    AValue := GridLovSet(D.Value, Fld, S, M);
    Result := True;
  finally
    P.Free;
    D.Form.Free;
    D.Free;
  end;
end;

{ ---------------- klasa svojstava ---------------- }

type
  TPcDlg = class
  public
    Db: TAppDb;
    Ctl: TaControlDef;
    Form: TForm;
    NameBox: TComboBox;
    List: TCheckListBox;
    Names: TStringList;
    procedure LoadClass(Sender: TObject);
    procedure DeleteClick(Sender: TObject);
  end;

procedure TPcDlg.LoadClass(Sender: TObject);
var
  P: TStringList;
  I: Integer;
begin
  P := TStringList.Create;
  try
    if not PropClassLoad(Db, Trim(NameBox.Text), P) then Exit;
    { klasa vec postoji: oznaceno je ono sto ona nosi }
    for I := 0 to List.Count - 1 do List.Checked[I] := P.IndexOfName(Names[I]) >= 0;
  finally
    P.Free;
  end;
end;

procedure TPcDlg.DeleteClick(Sender: TObject);
begin
  if Trim(NameBox.Text) = '' then Exit;
  if MessageDlg(Tr('Delete class "') + Trim(NameBox.Text) + Tr('"? Controls that use it are left without it.'), mtConfirmation, [mbYes, mbNo], 0) = mrYes then
  begin
    PropClassDelete(Db, Trim(NameBox.Text));
    NameBox.Items.Delete(NameBox.Items.IndexOf(Trim(NameBox.Text)));
    NameBox.Text := '';
  end;
end;

function RunPropClassDialog(AOwner: TComponent; ADb: TAppDb; D: TaControlDef; var AName: string): Boolean;
var
  Dlg: TPcDlg;
  Cl, Vals, Props: TStringList;
  I: Integer;
  V: string;
begin
  Result := False;
  Dlg := TPcDlg.Create;
  Dlg.Db := ADb;
  Dlg.Ctl := D;
  Dlg.Names := PropClassNames;
  Vals := TStringList.Create;
  Props := TStringList.Create;
  Dlg.Form := TForm.CreateNew(AOwner);
  try
    Dlg.Form.Caption := Tr('Property class');
    Dlg.Form.SetBounds(0, 0, 460, 460);
    Dlg.Form.Position := poOwnerFormCenter;
    Lbl(Dlg.Form, Dlg.Form, Tr('Class name (e.g. AmountField)'), 12, 8);
    Dlg.NameBox := Cmb(Dlg.Form, Dlg.Form, 12, 28, 430, True);
    Cl := PropClassList(ADb);
    try Dlg.NameBox.Items.Assign(Cl); finally Cl.Free; end;
    Dlg.NameBox.Text := AName;
    Dlg.NameBox.OnChange := @Dlg.LoadClass;
    Lbl(Dlg.Form, Dlg.Form, Tr('Properties of this control that go into the class'), 12, 66);
    Dlg.List := TCheckListBox.Create(Dlg.Form);
    Dlg.List.Parent := Dlg.Form;
    Dlg.List.SetBounds(12, 88, 430, 280);
    PropClassCapture(D, Dlg.Names, Vals);
    for I := 0 to Dlg.Names.Count - 1 do
    begin
      V := Vals.Values[Dlg.Names[I]];
      Dlg.List.Items.Add(Dlg.Names[I] + ' = ' + V);
      Dlg.List.Checked[I] := V <> '';
      { svojstvo bez vrijednosti nema sto prenijeti }
      Dlg.List.ItemEnabled[I] := V <> '';
    end;
    with TButton.Create(Dlg.Form) do begin Parent := Dlg.Form; Caption := Tr('Delete class'); OnClick := @Dlg.DeleteClick; SetBounds(12, 384, 120, 30); end;
    with TButton.Create(Dlg.Form) do begin Parent := Dlg.Form; Caption := Tr('Save'); ModalResult := mrOk; SetBounds(236, 384, 100, 30); end;
    with TButton.Create(Dlg.Form) do begin Parent := Dlg.Form; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(344, 384, 100, 30); end;
    if Dlg.Form.ShowModal <> mrOk then Exit;
    if Trim(Dlg.NameBox.Text) = '' then Exit;
    for I := 0 to Dlg.Names.Count - 1 do
      if Dlg.List.Checked[I] and (Vals.Values[Dlg.Names[I]] <> '') then
        Props.Values[Dlg.Names[I]] := Vals.Values[Dlg.Names[I]];
    if Props.Count = 0 then Exit;
    PropClassSave(ADb, Trim(Dlg.NameBox.Text), Props);
    AName := Trim(Dlg.NameBox.Text);
    Result := True;
  finally
    Vals.Free;
    Props.Free;
    Dlg.Names.Free;
    Dlg.Form.Free;
    Dlg.Free;
  end;
end;

function RunPickDialog(AOwner: TComponent; const ATitle, APrompt: string; AItems: TStrings; out ASel: string): Boolean;
var
  F: TForm;
  Cb: TComboBox;
begin
  Result := False;
  ASel := '';
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := ATitle;
    F.SetBounds(0, 0, 380, 130);
    F.Position := poOwnerFormCenter;
    Lbl(F, F, APrompt, 12, 10);
    Cb := Cmb(F, F, 12, 32, 350);
    Cb.Items.Assign(AItems);
    if Cb.Items.Count > 0 then Cb.ItemIndex := 0;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('OK'); ModalResult := mrOk; SetBounds(176, 76, 90, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; SetBounds(272, 76, 90, 30); end;
    if (F.ShowModal = mrOk) and (Cb.ItemIndex >= 0) then
    begin
      ASel := Cb.Items[Cb.ItemIndex];
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

end.
