unit ta_memo;
{ Obitelj Memo: plain (TMemo), rich (nas uredjivac TaRichEdit, tekst se sprema kao mali HTML iz ta_richtext)
  i markdown (TMemo s mono fontom; izvorni markdown se sprema kao tekst, bez pregleda).
  Isti nacin kao Edit: domacin TaMemo, zamjenjivi pokretaci, Options, veza na polje, definicija <-> komponenta, .lfm. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, StdCtrls, ExtCtrls, Graphics, Variants, DB, DBCtrls, LCLType, ta_family, ta_formdef;

type
  TaMemoVariant = (mvPlain, mvRich, mvMarkdown);

const
  MemoVariantNames: array[TaMemoVariant] of string = ('plain', 'rich', 'markdown');
  MemoFamily = 'Memo';

type
  TaMemoOptions = class(TPersistent)
  private
    FWordWrap, FPreview: Boolean;
  public
    constructor Create;
    procedure Assign(ASource: TPersistent); override;
  published
    property WordWrap: Boolean read FWordWrap write FWordWrap default True;
    { markdown: umjesto izvornog teksta prikazuje oblikovan pregled (samo za citanje) }
    property Preview: Boolean read FPreview write FPreview default False;
  end;

  TaMemoPlainEngine = class(TaEngine)
  private
    FMemo: TMemo;
  protected
    function IsMono: Boolean; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure SetMaxLength(AValue: Integer); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
  end;

  { markdown: izvorni tekst u TMemo-u, a uz Options.Preview oblikovan pregled (naslovi #, **podebljano**, *kosa*, - natuknice) }
  TaMemoMarkdownEngine = class(TaEngine)
  private
    FRich: TObject;     { TaRichBase }
    FPreview: Boolean;
    procedure UpdatePreview;
  protected
    FRoot: TPanel;
    FEdit: TWinControl;     { polje za izvorni tekst: TMemo, a pod 'own' TaOwnMemo }
    procedure MemoChange(Sender: TObject);
    { polje za izvorni tekst; potomci ga zamjenjuju }
    function MakeEdit(AParent: TWinControl): TWinControl; virtual;
    function EdText: string; virtual;
    procedure EdSetText(const AValue: string); virtual;
    procedure EdReadOnly(AValue: Boolean); virtual;
    procedure EdMaxLength(AValue: Integer); virtual;
    procedure EdWrap(AValue: Boolean); virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure SetMaxLength(AValue: Integer); override;
    procedure ApplyOptions(AOptions: TPersistent); override;
    { je li pregled prikazan i sto prikazuje (za ispitivanje) }
    function PreviewShown: Boolean;
    function PreviewHtml: string;
  end;

  TaMemoRichEngine = class(TaEngine)
  private
    FRich: TObject;     { TaRichEdit }
    procedure RichChanged(Sender: TObject);
  public
    constructor Create(AHost: TaFamilyHost); override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
  end;

  TaMemo = class(TaFamilyHost)
  private
    FVariant: TaMemoVariant;
    FOptions: TaMemoOptions;
    FText: string;
    FReadOnly: Boolean;
    FMaxLength: Integer;
    FControlSource, FVisibleIf, FEnabledIf, FCondFormat, FExtra: string;
    FDataLink: TFieldDataLink;
    FUpdating, FSelfEdit: Boolean;
    function GetVariant: TaMemoVariant;
    procedure SetVariant(AValue: TaMemoVariant);
    function GetOptions: TaMemoOptions;
    procedure SetOptions(AValue: TaMemoOptions);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetMaxLength(AValue: Integer);
    function GetDataSource: TDataSource;
    procedure SetDataSource(AValue: TDataSource);
    function GetDataField: string;
    procedure SetDataField(const AValue: string);
    procedure DataChange(Sender: TObject);
    procedure UpdateData(Sender: TObject);
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    procedure EngineChanged; override;
    procedure EngineExit; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Notification(AComponent: TComponent; AOperation: TOperation); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    function VariantName: string;
  published
    property Variant: TaMemoVariant read GetVariant write SetVariant default mvPlain;
    { plain i markdown: tekst; rich: mali HTML }
    property Text;
    property Options: TaMemoOptions read GetOptions write SetOptions;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    property MaxLength: Integer read FMaxLength write SetMaxLength default 0;
    property ControlSource: string read FControlSource write FControlSource;
    property VisibleIf: string read FVisibleIf write FVisibleIf;
    property EnabledIf: string read FEnabledIf write FEnabledIf;
    property CondFormat: string read FCondFormat write FCondFormat;
    property Extra: string read FExtra write FExtra;
    property DataSource: TDataSource read GetDataSource write SetDataSource;
    property DataField: string read GetDataField write SetDataField;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property Hint;
    property ShowHint;
    property TabOrder;
    property PopupMenu;
    property OnEnter;
    property OnExit;
  end;

{ markdown (naslovi, podebljano, kosa slova, natuknice, odlomci) -> mali HTML iz ta_richtext }
function MarkdownToRt(const AMarkdown: string): string;
function IsMemoKind(const AKind: string): Boolean;
function MemoVariantFromName(const AName: string; ADefault: TaMemoVariant = mvPlain): TaMemoVariant;
function MemoFromDef(D: TaControlDef; AOwner: TComponent): TaMemo;
procedure MemoToDef(M: TaMemo; D: TaControlDef);
function MemoToLfm(M: TaMemo): string;
function MemoFromLfm(const ALfm: string; AOwner: TComponent): TaMemo;

implementation

uses
  StrUtils, LResources, ta_richedit, ta_richbase;

function IsMemoKind(const AKind: string): Boolean;
begin
  Result := SameText(AKind, 'Memo') or SameText(AKind, 'MemoBox') or SameText(AKind, 'RichText');
end;

function MemoVariantFromName(const AName: string; ADefault: TaMemoVariant): TaMemoVariant;
var
  V: TaMemoVariant;
begin
  for V := Low(TaMemoVariant) to High(TaMemoVariant) do
    if SameText(MemoVariantNames[V], AName) then Exit(V);
  Result := ADefault;
end;

constructor TaMemoOptions.Create;
begin
  inherited Create;
  FWordWrap := True;
end;

procedure TaMemoOptions.Assign(ASource: TPersistent);
begin
  if ASource is TaMemoOptions then
  begin
    FWordWrap := TaMemoOptions(ASource).FWordWrap;
    FPreview := TaMemoOptions(ASource).FPreview;
  end
  else inherited Assign(ASource);
end;

{ ---------------- pokretaci ---------------- }

constructor TaMemoPlainEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FMemo := TMemo.Create(nil);
  FMemo.ScrollBars := ssAutoVertical;
  FMemo.OnChange := @InnerChanged;
  if IsMono then FMemo.Font.Name := 'JetBrains Mono';
  AttachInner(FMemo);
end;

function TaMemoPlainEngine.IsMono: Boolean;
begin
  Result := False;
end;

function TaMemoPlainEngine.GetText: string;
begin
  Result := FMemo.Text;
end;

procedure TaMemoPlainEngine.SetText(const AValue: string);
begin
  if FMemo.Text <> AValue then FMemo.Text := AValue;
end;

procedure TaMemoPlainEngine.SetReadOnly(AValue: Boolean);
begin
  FMemo.ReadOnly := AValue;
end;

procedure TaMemoPlainEngine.SetMaxLength(AValue: Integer);
begin
  FMemo.MaxLength := AValue;
end;

procedure TaMemoPlainEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaMemoOptions then
  begin
    FMemo.WordWrap := TaMemoOptions(AOptions).WordWrap;
    if FMemo.WordWrap then FMemo.ScrollBars := ssAutoVertical else FMemo.ScrollBars := ssAutoBoth;
  end;
end;

function EscRt(const S: string): string;
begin
  Result := StringReplace(StringReplace(StringReplace(S, '&', '&amp;', [rfReplaceAll]), '<', '&lt;', [rfReplaceAll]), '>', '&gt;', [rfReplaceAll]);
end;

{ ugnijezdene oznake **podebljano**, *kosa*, _kosa_ i `kod` unutar jednog retka }
function InlineRt(const S: string): string;
var
  I, J: Integer;
  Tag: string;
begin
  Result := '';
  I := 1;
  while I <= Length(S) do
  begin
    if (Copy(S, I, 2) = '**') then
    begin
      J := PosEx('**', S, I + 2);
      if J > 0 then begin Result := Result + '<b>' + InlineRt(Copy(S, I + 2, J - I - 2)) + '</b>'; I := J + 2; Continue; end;
    end;
    if (S[I] = '*') or (S[I] = '_') then
    begin
      Tag := S[I];
      J := PosEx(Tag, S, I + 1);
      if (J > I + 1) then begin Result := Result + '<i>' + InlineRt(Copy(S, I + 1, J - I - 1)) + '</i>'; I := J + 1; Continue; end;
    end;
    if S[I] = '`' then
    begin
      J := PosEx('`', S, I + 1);
      if J > 0 then begin Result := Result + '<u>' + EscRt(Copy(S, I + 1, J - I - 1)) + '</u>'; I := J + 1; Continue; end;
    end;
    Result := Result + EscRt(S[I]);
    Inc(I);
  end;
end;

function MarkdownToRt(const AMarkdown: string): string;
var
  L: TStringList;
  I, Lvl: Integer;
  S: string;
begin
  Result := '';
  L := TStringList.Create;
  try
    L.Text := AMarkdown;
    for I := 0 to L.Count - 1 do
    begin
      S := TrimRight(L[I]);
      if Trim(S) = '' then Continue;
      Lvl := 0;
      while (Lvl < Length(S)) and (S[Lvl + 1] = '#') do Inc(Lvl);
      if (Lvl > 0) and (Lvl <= 6) and (Copy(S, Lvl + 1, 1) = ' ') then
        Result := Result + '<p><b><font size="' + IntToStr(20 - Lvl * 2) + '">' + InlineRt(Trim(Copy(S, Lvl + 1, MaxInt))) + '</font></b></p>'
      else if (Copy(TrimLeft(S), 1, 2) = '- ') or (Copy(TrimLeft(S), 1, 2) = '* ') then
        Result := Result + '<p list="1">' + InlineRt(Trim(Copy(TrimLeft(S), 3, MaxInt))) + '</p>'
      else
        Result := Result + '<p>' + InlineRt(Trim(S)) + '</p>';
    end;
  finally
    L.Free;
  end;
end;

constructor TaMemoMarkdownEngine.Create(AHost: TaFamilyHost);
var
  R: TaRichBase;
begin
  inherited Create(AHost);
  FRoot := TPanel.Create(nil);
  FRoot.BevelOuter := bvNone;
  FRoot.Caption := '';
  FEdit := MakeEdit(FRoot);
  FEdit.Align := alClient;
  R := NewRichEditor(FRoot);
  R.Parent := FRoot;
  R.Align := alClient;
  R.ReadOnly := True;
  R.Visible := False;
  FRich := R;
  AttachInner(FRoot);
end;

function TaMemoMarkdownEngine.MakeEdit(AParent: TWinControl): TWinControl;
var
  M: TMemo;
begin
  M := TMemo.Create(AParent);
  M.Parent := AParent;
  M.ScrollBars := ssAutoVertical;
  M.Font.Name := 'JetBrains Mono';
  M.OnChange := @MemoChange;
  Result := M;
end;

function TaMemoMarkdownEngine.EdText: string;
begin
  Result := TMemo(FEdit).Text;
end;

procedure TaMemoMarkdownEngine.EdSetText(const AValue: string);
begin
  TMemo(FEdit).Text := AValue;
end;

procedure TaMemoMarkdownEngine.EdReadOnly(AValue: Boolean);
begin
  TMemo(FEdit).ReadOnly := AValue;
end;

procedure TaMemoMarkdownEngine.EdMaxLength(AValue: Integer);
begin
  TMemo(FEdit).MaxLength := AValue;
end;

procedure TaMemoMarkdownEngine.EdWrap(AValue: Boolean);
begin
  TMemo(FEdit).WordWrap := AValue;
end;

procedure TaMemoMarkdownEngine.MemoChange(Sender: TObject);
begin
  UpdatePreview;
  InnerChanged(Sender);
end;

procedure TaMemoMarkdownEngine.UpdatePreview;
begin
  if FPreview then TaRichBase(FRich).Html := MarkdownToRt(EdText);
end;

function TaMemoMarkdownEngine.GetText: string;
begin
  Result := EdText;
end;

procedure TaMemoMarkdownEngine.SetText(const AValue: string);
begin
  if EdText <> AValue then EdSetText(AValue);
  UpdatePreview;
end;

procedure TaMemoMarkdownEngine.SetReadOnly(AValue: Boolean);
begin
  EdReadOnly(AValue);
end;

procedure TaMemoMarkdownEngine.SetMaxLength(AValue: Integer);
begin
  EdMaxLength(AValue);
end;

procedure TaMemoMarkdownEngine.ApplyOptions(AOptions: TPersistent);
begin
  if AOptions is TaMemoOptions then
  begin
    EdWrap(TaMemoOptions(AOptions).WordWrap);
    FPreview := TaMemoOptions(AOptions).Preview;
    TaRichBase(FRich).Visible := FPreview;
    FEdit.Visible := not FPreview;
    UpdatePreview;
  end;
end;

function TaMemoMarkdownEngine.PreviewShown: Boolean;
begin
  Result := FPreview and TaRichBase(FRich).Visible and not FEdit.Visible;
end;

function TaMemoMarkdownEngine.PreviewHtml: string;
begin
  Result := TaRichBase(FRich).Html;
end;

constructor TaMemoRichEngine.Create(AHost: TaFamilyHost);
var
  R: TaRichBase;
begin
  inherited Create(AHost);
  R := NewRichEditor(nil);
  R.OnChanged := @RichChanged;
  FRich := R;
  AttachInner(R);
end;

procedure TaMemoRichEngine.RichChanged(Sender: TObject);
begin
  InnerChanged(Sender);
end;

function TaMemoRichEngine.GetText: string;
begin
  Result := TaRichBase(FRich).Html;
end;

procedure TaMemoRichEngine.SetText(const AValue: string);
begin
  TaRichBase(FRich).Html := AValue;
end;

procedure TaMemoRichEngine.SetReadOnly(AValue: Boolean);
begin
  TaRichBase(FRich).ReadOnly := AValue;
end;

{ ---------------- TaMemo ---------------- }

constructor TaMemo.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FDataLink := TFieldDataLink.Create;
  FDataLink.Control := Self;
  FDataLink.OnDataChange := @DataChange;
  FDataLink.OnUpdateData := @UpdateData;
  FOptions := TaMemoOptions.Create;
  FVariant := mvPlain;
  Width := 200;
  Height := 90;
  ReplaceEngine;
  PushToEngine;
end;

destructor TaMemo.Destroy;
begin
  FDataLink.OnDataChange := nil;
  FDataLink.OnUpdateData := nil;
  FDataLink.Free;
  FOptions.Free;
  inherited Destroy;
end;

function TaMemo.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(MemoFamily, MemoVariantNames[FVariant]);
  if C = nil then C := FindEngine(MemoFamily, 'plain');
  Result := C.Create(Self);
end;

function TaMemo.VariantName: string;
begin
  Result := MemoVariantNames[FVariant];
end;

function TaMemo.GetVariant: TaMemoVariant;
begin
  Result := FVariant;
end;

procedure TaMemo.SetVariant(AValue: TaMemoVariant);
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

function TaMemo.GetOptions: TaMemoOptions;
begin
  Result := FOptions;
end;

procedure TaMemo.SetOptions(AValue: TaMemoOptions);
begin
  FOptions.Assign(AValue);
  if Engine <> nil then Engine.ApplyOptions(FOptions);
end;

procedure TaMemo.PushToEngine;
begin
  if Engine = nil then Exit;
  FUpdating := True;
  try
    Engine.ApplyOptions(FOptions);
    Engine.SetMaxLength(FMaxLength);
    Engine.SetText(FText);
    Engine.SetReadOnly(FReadOnly);
  finally
    FUpdating := False;
  end;
end;

procedure TaMemo.SetReadOnly(AValue: Boolean);
begin
  if FReadOnly = AValue then Exit;
  FReadOnly := AValue;
  if Engine <> nil then Engine.SetReadOnly(AValue);
end;

procedure TaMemo.SetMaxLength(AValue: Integer);
begin
  FMaxLength := AValue;
  if Engine <> nil then Engine.SetMaxLength(AValue);
end;

function TaMemo.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaMemo.RealSetText(const AValue: TCaption);
begin
  FText := AValue;
  if Engine <> nil then
  begin
    FUpdating := True;
    try
      Engine.SetText(AValue);
    finally
      FUpdating := False;
    end;
  end;
end;

procedure TaMemo.EngineChanged;
begin
  if FUpdating then Exit;
  if FDataLink.Active and not FReadOnly then
  begin
    FSelfEdit := True;
    try
      if FDataLink.Edit then FDataLink.Modified;
    finally
      FSelfEdit := False;
    end;
  end;
  inherited EngineChanged;
end;

procedure TaMemo.EngineExit;
begin
  if FDataLink.Active then
    try
      FDataLink.UpdateRecord;
    except
      FDataLink.Reset;
      raise;
    end;
  inherited EngineExit;
end;

function TaMemo.GetDataSource: TDataSource;
begin
  Result := FDataLink.DataSource;
end;

procedure TaMemo.SetDataSource(AValue: TDataSource);
begin
  FDataLink.DataSource := AValue;
  if AValue <> nil then AValue.FreeNotification(Self);
end;

function TaMemo.GetDataField: string;
begin
  Result := FDataLink.FieldName;
end;

procedure TaMemo.SetDataField(const AValue: string);
begin
  FDataLink.FieldName := AValue;
end;

procedure TaMemo.Notification(AComponent: TComponent; AOperation: TOperation);
begin
  inherited Notification(AComponent, AOperation);
  if (AOperation = opRemove) and (FDataLink <> nil) and (AComponent = FDataLink.DataSource) then
    FDataLink.DataSource := nil;
end;

procedure TaMemo.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

procedure TaMemo.DataChange(Sender: TObject);
var
  F: TField;
begin
  if FSelfEdit then Exit;
  F := FDataLink.Field;
  FUpdating := True;
  try
    if F = nil then
    begin
      if not (csDesigning in ComponentState) then Engine.SetText('');
    end
    else Engine.SetText(F.AsString);
  finally
    FUpdating := False;
  end;
end;

procedure TaMemo.UpdateData(Sender: TObject);
var
  F: TField;
  S: string;
begin
  F := FDataLink.Field;
  if F = nil then Exit;
  S := Engine.GetText;
  if S = '' then F.Clear else F.AsString := S;
end;

{ ---------------- definicija kontrole <-> komponenta ---------------- }

const
  OwnKeys = ',variant,tip,locked,visibleIf,enabledIf,condFormat,wordWrap,maxLength,preview,';

function ExtraWithout(const AExtra: string): string;
var
  L: TStringList;
  I: Integer;
  K: string;
begin
  L := TStringList.Create;
  try
    L.Text := AExtra;
    for I := L.Count - 1 downto 0 do
    begin
      K := L.Names[I];
      if (K <> '') and (Pos(',' + K + ',', OwnKeys) > 0) then L.Delete(I);
    end;
    Result := Trim(L.Text);
  finally
    L.Free;
  end;
end;

function MemoFromDef(D: TaControlDef; AOwner: TComponent): TaMemo;
var
  V: TaMemoVariant;
begin
  Result := TaMemo.Create(AOwner);
  try
    Result.Name := D.Name;
    Result.SetBounds(D.Left, D.Top, D.Width, D.Height);
    V := MemoVariantFromName(D.GetX('variant'), mvPlain);
    if SameText(D.Kind, 'RichText') and (D.GetX('variant') = '') then V := mvRich;
    Result.Variant := V;
    Result.ControlSource := D.ControlSource;
    Result.ReadOnly := D.GetX('locked') = '1';
    Result.MaxLength := StrToIntDef(D.GetX('maxLength'), 0);
    Result.Hint := D.GetX('tip');
    Result.VisibleIf := D.GetX('visibleIf');
    Result.EnabledIf := D.GetX('enabledIf');
    Result.CondFormat := D.GetX('condFormat');
    Result.Options.WordWrap := D.GetX('wordWrap') <> '0';
    Result.Options.Preview := D.GetX('preview') = '1';
    Result.Options := Result.Options;
    Result.Extra := ExtraWithout(D.Extra);
  except
    Result.Free;
    raise;
  end;
end;

procedure MemoToDef(M: TaMemo; D: TaControlDef);
begin
  if M.Variant = mvRich then D.Kind := 'RichText' else D.Kind := 'MemoBox';
  D.Name := M.Name;
  D.Left := M.Left; D.Top := M.Top; D.Width := M.Width; D.Height := M.Height;
  D.ControlSource := M.ControlSource;
  D.Extra := M.Extra;
  D.SetX('variant', IfThen(M.Variant in [mvPlain, mvRich], '', M.VariantName));
  D.SetX('locked', IfThen(M.ReadOnly, '1', ''));
  D.SetX('tip', M.Hint);
  D.SetX('visibleIf', M.VisibleIf);
  D.SetX('enabledIf', M.EnabledIf);
  D.SetX('condFormat', M.CondFormat);
  D.SetX('maxLength', IfThen(M.MaxLength > 0, IntToStr(M.MaxLength), ''));
  D.SetX('wordWrap', IfThen(M.Options.WordWrap, '', '0'));
  D.SetX('preview', IfThen(M.Options.Preview, '1', ''));
end;

function MemoToLfm(M: TaMemo): string;
var
  St: TMemoryStream;
  L: TStringList;
begin
  St := TMemoryStream.Create;
  L := TStringList.Create;
  try
    WriteComponentAsTextToStream(St, M);
    St.Position := 0;
    L.LoadFromStream(St);
    Result := L.Text;
  finally
    L.Free;
    St.Free;
  end;
end;

type
  TMemoLfmFinder = class
    procedure Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
  end;

procedure TMemoLfmFinder.Find(Reader: TReader; const AClassName: string; var AClass: TComponentClass);
begin
  if SameText(AClassName, 'TaMemo') then AClass := TaMemo;
end;

function MemoFromLfm(const ALfm: string; AOwner: TComponent): TaMemo;
var
  St: TMemoryStream;
  C: TComponent;
  F: TMemoLfmFinder;
begin
  St := TMemoryStream.Create;
  try
    if ALfm <> '' then St.WriteBuffer(ALfm[1], Length(ALfm));
    St.Position := 0;
    C := nil;
    F := TMemoLfmFinder.Create;
    try
      ReadComponentFromTextStream(St, C, @F.Find, AOwner);
    finally
      F.Free;
    end;
    Result := C as TaMemo;
  finally
    St.Free;
  end;
end;

initialization
  RegisterClass(TaMemo);
  RegisterEngine(MemoFamily, 'plain', TaMemoPlainEngine);
  RegisterEngine(MemoFamily, 'rich', TaMemoRichEngine);
  RegisterEngine(MemoFamily, 'markdown', TaMemoMarkdownEngine);

end.
