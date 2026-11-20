unit ta_editdlg;
{ Sloj B dijalozi (poglavlje 9 plana): isti dijalozi za Inspektor objekata u IDE-u i za dizajner.
  Svaka funkcija prima kontekst i trenutnu vrijednost, a vraca True ako je korisnik potvrdio.
  Ne zna ni za Inspektor ni za dizajner. Zbog sudara imena s postojecim dijalogom je izraz EditExpr. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Dialogs, ta_meta, ta_tokens, ta_wizardgen, ta_propdlgs, ta_exprbuilder, ta_keymap;

type
  TaEditContext = class
  public
    Db: TAppDb;
    FormFields: TStringList;   { polja forme (parametri, izrazi, radnje) }
    Source: string;            { tablica ili upit ciji se stupci nude u izrazima }
    Owner: TComponent;
    constructor Create(ADb: TAppDb; AOwner: TComponent = nil; const ASource: string = '');
    destructor Destroy; override;
    { zadani izvor kad nije poznat: prva korisnicka tablica }
    function EffectiveSource: string;
    { polja izvora (ili FormFields ako su zadana) }
    procedure FieldsInto(AList: TStrings);
  end;

function EditSource(ACtx: TaEditContext; const AKind: string; var AValue: string): Boolean;
function EditAction(ACtx: TaEditContext; var AValue: string): Boolean;
function EditFormat(ACtx: TaEditContext; var AValue: string; const AKind: string): Boolean;
function EditCondFormat(ACtx: TaEditContext; var AValue: string): Boolean;
function EditRule(ACtx: TaEditContext; var AValue: string): Boolean;
function EditExpr(ACtx: TaEditContext; var AValue: string; const ATitle: string = 'Izraz'): Boolean;
function EditTheme(ACtx: TaEditContext; var AThemeJson: string): Boolean;
{ tipke neprekidne forme: AKeyMapJson je zapis ta_keymap; dijalog javlja sukobe tipki }
function EditKeyMap(ACtx: TaEditContext; var AKeyMapJson: string): Boolean;

{ za dizajnere: kontekst iz polja koja dizajner vec ima; zovu iste Edit* funkcije kao IDE }
function DesignEditSource(AOwner: TComponent; ADb: TAppDb; const AKind: string; var AValue: string): Boolean;
function DesignEditAction(AOwner: TComponent; ADb: TAppDb; AFields: TStrings; var AValue: string): Boolean;
function DesignEditCondFormat(AOwner: TComponent; ADb: TAppDb; AFields: TStrings; var AValue: string): Boolean;
function DesignEditRule(AOwner: TComponent; ADb: TAppDb; AFields: TStrings; var AValue: string): Boolean;

{ ponudeni formati za vrstu polja: broj, datum, tekst, iznos, postotak }
procedure FormatChoices(const AKind: string; AOut: TStrings);
{ JSON teme iz naglaska (#rrggbb), tamne/svijetle varijante i oblika (square/rounded/pill) }
function ThemeJsonFor(const AAccent: string; ADark: Boolean; const AShape: string): string;
{ za test i skripte: dijalog se ne otvara, vrijednost vraca ova funkcija (nil = pravi dijalog) }
type
  TaEditHook = function(const AName: string; var AValue: string): Boolean;
var
  EditDialogHook: TaEditHook = nil;

implementation

uses
  ta_i18n;


constructor TaEditContext.Create(ADb: TAppDb; AOwner: TComponent; const ASource: string);
begin
  Db := ADb;
  Owner := AOwner;
  Source := ASource;
  FormFields := TStringList.Create;
end;

destructor TaEditContext.Destroy;
begin
  FormFields.Free;
  inherited Destroy;
end;

function TaEditContext.EffectiveSource: string;
var
  T: TStringList;
begin
  Result := Source;
  if (Result = '') and (Db <> nil) then
  begin
    T := Db.UserTables;
    try
      if T.Count > 0 then Result := T[0];
    finally
      T.Free;
    end;
  end;
end;

procedure TaEditContext.FieldsInto(AList: TStrings);
var
  F: TaSourceFields;
  I: Integer;
begin
  AList.Clear;
  if FormFields.Count > 0 then begin AList.AddStrings(FormFields); Exit; end;
  if (Db = nil) or (EffectiveSource = '') then Exit;
  F := SourceFieldList(Db, EffectiveSource);
  for I := 0 to High(F) do AList.Add(F[I].Name);
end;

function Hooked(const AName: string; var AValue: string; out AResult: Boolean): Boolean;
begin
  Result := EditDialogHook <> nil;
  if Result then AResult := EditDialogHook(AName, AValue);
end;

function EditSource(ACtx: TaEditContext; const AKind: string; var AValue: string): Boolean;
begin
  if Hooked('source', AValue, Result) then Exit;
  Result := RunRowSourceBuilder(ACtx.Owner, ACtx.Db, AKind, AValue);
end;

function EditAction(ACtx: TaEditContext; var AValue: string): Boolean;
var
  F: TStringList;
begin
  if Hooked('action', AValue, Result) then Exit;
  F := TStringList.Create;
  try
    ACtx.FieldsInto(F);
    Result := RunActionBuilder(ACtx.Owner, ACtx.Db, F, AValue);
  finally
    F.Free;
  end;
end;

function EditCondFormat(ACtx: TaEditContext; var AValue: string): Boolean;
var
  F: TStringList;
begin
  if Hooked('condformat', AValue, Result) then Exit;
  F := TStringList.Create;
  try
    ACtx.FieldsInto(F);
    Result := RunCondFormatBuilder(ACtx.Owner, F, AValue);
  finally
    F.Free;
  end;
end;

function EditRule(ACtx: TaEditContext; var AValue: string): Boolean;
var
  F: TStringList;
begin
  if Hooked('rule', AValue, Result) then Exit;
  F := TStringList.Create;
  try
    ACtx.FieldsInto(F);
    Result := RunCalcRulesBuilder(ACtx.Owner, F, AValue);
  finally
    F.Free;
  end;
end;

function EditExpr(ACtx: TaEditContext; var AValue: string; const ATitle: string): Boolean;
begin
  if Hooked('expression', AValue, Result) then Exit;
  Result := EditExpression(ACtx.Owner, ACtx.Db, ACtx.EffectiveSource, ATitle, AValue);
end;

function DesignCtx(AOwner: TComponent; ADb: TAppDb; AFields: TStrings): TaEditContext;
begin
  Result := TaEditContext.Create(ADb, AOwner);
  if AFields <> nil then Result.FormFields.AddStrings(AFields);
end;

function DesignEditSource(AOwner: TComponent; ADb: TAppDb; const AKind: string; var AValue: string): Boolean;
var
  C: TaEditContext;
begin
  C := DesignCtx(AOwner, ADb, nil);
  try Result := EditSource(C, AKind, AValue); finally C.Free; end;
end;

function DesignEditAction(AOwner: TComponent; ADb: TAppDb; AFields: TStrings; var AValue: string): Boolean;
var
  C: TaEditContext;
begin
  C := DesignCtx(AOwner, ADb, AFields);
  try Result := EditAction(C, AValue); finally C.Free; end;
end;

function DesignEditCondFormat(AOwner: TComponent; ADb: TAppDb; AFields: TStrings; var AValue: string): Boolean;
var
  C: TaEditContext;
begin
  C := DesignCtx(AOwner, ADb, AFields);
  try Result := EditCondFormat(C, AValue); finally C.Free; end;
end;

function DesignEditRule(AOwner: TComponent; ADb: TAppDb; AFields: TStrings; var AValue: string): Boolean;
var
  C: TaEditContext;
begin
  C := DesignCtx(AOwner, ADb, AFields);
  try Result := EditRule(C, AValue); finally C.Free; end;
end;

procedure FormatChoices(const AKind: string; AOut: TStrings);
var
  K: string;
begin
  AOut.Clear;
  K := LowerCase(AKind);
  if (K = 'datum') or (K = 'date') then
  begin
    AOut.Add('dd.mm.yyyy');
    AOut.Add('dd.mm.yy');
    AOut.Add('yyyy-mm-dd');
    AOut.Add('d. mmmm yyyy');
    AOut.Add('dd.mm.yyyy hh:nn');
  end
  else if (K = 'iznos') or (K = 'currency') then
  begin
    AOut.Add('#,##0.00');
    AOut.Add('#,##0.00 €');
    AOut.Add('#,##0');
    AOut.Add('0.00');
  end
  else if (K = 'postotak') or (K = 'percent') then
  begin
    AOut.Add('0%');
    AOut.Add('0.0%');
    AOut.Add('0.00%');
  end
  else if (K = 'broj') or (K = 'number') then
  begin
    AOut.Add('0');
    AOut.Add('0.0');
    AOut.Add('0.00');
    AOut.Add('#,##0');
    AOut.Add('#,##0.00');
    AOut.Add('000000');
  end
  else
  begin
    AOut.Add('>');
    AOut.Add('<');
    AOut.Add('@@@-@@@');
  end;
end;

function EditFormat(ACtx: TaEditContext; var AValue: string; const AKind: string): Boolean;
var
  F: TForm;
  C: TComboBox;
  L: TLabel;
  B: TButton;
  Ch: TStringList;
begin
  if Hooked('format', AValue, Result) then Exit;
  F := TForm.CreateNew(ACtx.Owner);
  Ch := TStringList.Create;
  try
    F.Caption := Tr('Format');
    F.SetBounds(0, 0, 400, 150);
    F.Position := poScreenCenter;
    L := TLabel.Create(F); L.Parent := F; L.Caption := Tr('Format (') + AKind + '):'; L.SetBounds(12, 12, 360, 18);
    C := TComboBox.Create(F); C.Parent := F; C.Style := csDropDown; C.SetBounds(12, 36, 370, 28);
    FormatChoices(AKind, Ch);
    C.Items.Assign(Ch);
    C.Text := AValue;
    B := TButton.Create(F); B.Parent := F; B.Caption := Tr('OK'); B.ModalResult := mrOk; B.SetBounds(12, 84, 100, 30); B.Default := True;
    B := TButton.Create(F); B.Parent := F; B.Caption := Tr('Cancel'); B.ModalResult := mrCancel; B.SetBounds(122, 84, 100, 30);
    Result := F.ShowModal = mrOk;
    if Result then AValue := C.Text;
  finally
    Ch.Free;
    F.Free;
  end;
end;

function ThemeJsonFor(const AAccent: string; ADark: Boolean; const AShape: string): string;
var
  Sh: TaShape;
  T: TaThemeTokens;
begin
  Sh := shRounded;
  for Sh := Low(TaShape) to High(TaShape) do
    if SameText(ShapeNames[Sh], AShape) then Break;
  if not SameText(ShapeNames[Sh], AShape) then Sh := shRounded;
  T := DeriveTokens('Prilagodena', AAccent, ADark, Sh);
  Result := TokensToJson(T);
end;

function EditTheme(ACtx: TaEditContext; var AThemeJson: string): Boolean;
var
  F: TForm;
  E: TEdit;
  Dk: TCheckBox;
  Sh: TComboBox;
  L: TLabel;
  B: TButton;
  T: TaThemeTokens;
  W: string;
begin
  if Hooked('theme', AThemeJson, Result) then Exit;
  F := TForm.CreateNew(ACtx.Owner);
  try
    F.Caption := Tr('Theme');
    F.SetBounds(0, 0, 380, 230);
    F.Position := poScreenCenter;
    L := TLabel.Create(F); L.Parent := F; L.Caption := Tr('Accent (#rrggbb):'); L.SetBounds(12, 12, 300, 18);
    E := TEdit.Create(F); E.Parent := F; E.SetBounds(12, 34, 150, 26); E.Text := '#2563EB';
    if (AThemeJson <> '') and TokensFromJson(AThemeJson, T, W) then E.Text := T.Accent;
    Dk := TCheckBox.Create(F); Dk.Parent := F; Dk.Caption := Tr('Dark theme'); Dk.SetBounds(12, 72, 200, 22);
    L := TLabel.Create(F); L.Parent := F; L.Caption := Tr('Shape:'); L.SetBounds(12, 104, 100, 18);
    Sh := TComboBox.Create(F); Sh.Parent := F; Sh.Style := csDropDownList; Sh.SetBounds(12, 124, 150, 28);
    Sh.Items.Add('square'); Sh.Items.Add('rounded'); Sh.Items.Add('pill'); Sh.ItemIndex := 1;
    B := TButton.Create(F); B.Parent := F; B.Caption := Tr('OK'); B.ModalResult := mrOk; B.SetBounds(12, 170, 100, 30); B.Default := True;
    B := TButton.Create(F); B.Parent := F; B.Caption := Tr('Cancel'); B.ModalResult := mrCancel; B.SetBounds(122, 170, 100, 30);
    Result := F.ShowModal = mrOk;
    if Result then AThemeJson := ThemeJsonFor(E.Text, Dk.Checked, Sh.Text);
  finally
    F.Free;
  end;
end;

function EditKeyMap(ACtx: TaEditContext; var AKeyMapJson: string): Boolean;
var
  F: TForm;
  Map, Chk: TaKeyMap;
  A: TaKeyAction;
  Edits: array[TaKeyAction] of TEdit;
  L: TLabel;
  B: TButton;
  Y: Integer;
  Err, Conf: string;
  Msg: TLabel;
  Ok: Boolean;
begin
  if Hooked('keymap', AKeyMapJson, Result) then Exit;
  Map := TaKeyMap.Create;
  Chk := TaKeyMap.Create;
  F := TForm.CreateNew(ACtx.Owner);
  try
    if Trim(AKeyMapJson) <> '' then Map.FromJson(AKeyMapJson, Err);
    F.Caption := Tr('Keys of the continuous form');
    F.SetBounds(0, 0, 560, 560);
    F.Position := poScreenCenter;
    L := TLabel.Create(F); L.Parent := F; L.SetBounds(12, 8, 530, 18);
    L.Caption := Tr('One or more keys per action, separated by commas (e.g. Insert, Ctrl+N).');
    Y := 34;
    for A := Succ(Low(TaKeyAction)) to High(TaKeyAction) do
    begin
      L := TLabel.Create(F); L.Parent := F; L.Caption := ActionTitle(A); L.SetBounds(12, Y + 4, 260, 18);
      Edits[A] := TEdit.Create(F); Edits[A].Parent := F; Edits[A].SetBounds(280, Y, 260, 26);
      Edits[A].Text := Map.KeysOf(A);
      Inc(Y, 32);
    end;
    Msg := TLabel.Create(F); Msg.Parent := F; Msg.SetBounds(12, Y + 4, 530, 36); Msg.WordWrap := True;
    B := TButton.Create(F); B.Parent := F; B.Caption := Tr('OK'); B.ModalResult := mrOk; B.SetBounds(340, Y + 46, 100, 30); B.Default := True;
    B := TButton.Create(F); B.Parent := F; B.Caption := Tr('Cancel'); B.ModalResult := mrCancel; B.SetBounds(450, Y + 46, 90, 30);
    F.ClientHeight := Y + 90;
    repeat
      Result := F.ShowModal = mrOk;
      if not Result then Break;
      { provjera: ispravne tipke i bez sukoba }
      Ok := True;
      Chk.Clear;
      for A := Succ(Low(TaKeyAction)) to High(TaKeyAction) do
        if not Chk.SetKeys(A, Edits[A].Text, Err) then begin Msg.Caption := ActionTitle(A) + ': ' + Err; Ok := False; Break; end;
      if Ok then
      begin
        { sukob: ista kombinacija u dvije radnje }
        for A := Succ(Low(TaKeyAction)) to High(TaKeyAction) do
        begin
          if Trim(Chk.KeysOf(A)) = '' then Continue;
          Err := Chk.KeysOf(A);
          Conf := '';
          while Err <> '' do
          begin
            if Pos(',', Err) > 0 then begin Conf := Trim(Copy(Err, 1, Pos(',', Err) - 1)); Err := Trim(Copy(Err, Pos(',', Err) + 1, MaxInt)); end
            else begin Conf := Trim(Err); Err := ''; end;
            if Chk.ConflictOf(Conf, A) <> kaNone then
            begin
              Msg.Caption := Tr('Key ') + Conf + Tr(' is assigned to two actions: ') + ActionTitle(A) + ' i ' + ActionTitle(Chk.ConflictOf(Conf, A));
              Ok := False;
            end;
          end;
        end;
      end;
      if Ok then begin AKeyMapJson := Chk.ToJson; Break; end;
    until False;
  finally
    Chk.Free;
    Map.Free;
    F.Free;
  end;
end;


end.
