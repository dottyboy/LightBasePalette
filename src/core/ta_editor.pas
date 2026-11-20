unit ta_editor;
{ Obitelj Editor (uredjivac koda), poglavlje 5 plana: jedna komponenta TaEditor, varijanta bira jezik:
  fgl (4GL), sql, expression (izrazi), pascal (PascalScript), json, text. Pokretac je SynEdit.

  Daje: bojenje sintakse iz tokena teme (svijetla i tamna, naglasak), brojeve redaka, sklapanje blokova (4GL),
  dopunu koda (Ctrl+Space) iz rijeci jezika i iz baze (tablice, stupci, programi, izvjesca, forme),
  oznake gresaka iz parsera ("datoteka:redak:stupac: poruka") i jednoredni nacin za svojstva s izrazima. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, Graphics, Forms, StdCtrls, Menus, LCLType, Variants, SynEdit, SynEditTypes, SynEditMarkup,
  SynEditHighlighter, SynEditMiscClasses, LazEditHighlighter, SynCompletion, SynHighlighterSQL, SynHighlighterPas, SynHighlighterJScript, SynEditKeyCmds,
  ZDataset, ta_family, ta_tokens, ta_synhl, ta_meta;

type
  TaEditorVariant = (ewFgl, ewSql, ewExpression, ewPascal, ewJson, ewText);

const
  EditorVariantNames: array[TaEditorVariant] of string = ('4gl', 'sql', 'expression', 'pascal', 'json', 'text');
  EditorFamily = 'Editor';

type
  TaEditorError = record
    Line, Col: Integer;      { 1-based; Col 0 = cijeli redak }
    Msg: string;
  end;

  TaEditorWordsEvent = procedure(Sender: TObject; const APrefix: string; AWords: TStrings) of object;

  TaEditor = class;

  { ---------------- pokretac ---------------- }

  TaSynEngine = class(TaEngine)
  private
    FSyn: TSynEdit;
    FHl: TSynCustomHighlighter;
    FComp: TSynCompletion;
    FSingleLine: Boolean;
    procedure SynChange(Sender: TObject);
    procedure SynKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure SpecialLine(Sender: TObject; Line: Integer; var Special: Boolean; Markup: TSynSelectedColor);
    procedure CompExecute(Sender: TObject);
    procedure TokensChanged(Sender: TObject);
  protected
    function CreateHighlighter: TSynCustomHighlighter; virtual;
    function Variant: TaEditorVariant; virtual;
  public
    constructor Create(AHost: TaFamilyHost); override;
    destructor Destroy; override;
    function GetText: string; override;
    procedure SetText(const AValue: string); override;
    procedure SetReadOnly(AValue: Boolean); override;
    procedure ApplyTheme;
    procedure SetSingleLine(AValue: Boolean);
    property Syn: TSynEdit read FSyn;
  end;

  TaSynFglEngine = class(TaSynEngine)
  protected
    function CreateHighlighter: TSynCustomHighlighter; override;
    function Variant: TaEditorVariant; override;
  end;

  TaSynSqlEngine = class(TaSynEngine)
  protected
    function CreateHighlighter: TSynCustomHighlighter; override;
    function Variant: TaEditorVariant; override;
  end;

  TaSynExprEngine = class(TaSynEngine)
  protected
    function CreateHighlighter: TSynCustomHighlighter; override;
    function Variant: TaEditorVariant; override;
  end;

  TaSynPascalEngine = class(TaSynEngine)
  protected
    function CreateHighlighter: TSynCustomHighlighter; override;
    function Variant: TaEditorVariant; override;
  end;

  TaSynJsonEngine = class(TaSynEngine)
  protected
    function CreateHighlighter: TSynCustomHighlighter; override;
    function Variant: TaEditorVariant; override;
  end;

  TaSynTextEngine = class(TaSynEngine)
  protected
    function Variant: TaEditorVariant; override;
  end;

  { ---------------- TaEditor ---------------- }

  TaEditor = class(TaFamilyHost)
  private
    FVariant: TaEditorVariant;
    FText: string;
    FReadOnly: Boolean;
    FSingleLine: Boolean;
    FShowLineNumbers: Boolean;
    FErrors: array of TaEditorError;
    FContextWords: TStringList;
    FOnWords: TaEditorWordsEvent;
    function GetVariant: TaEditorVariant;
    procedure SetVariant(AValue: TaEditorVariant);
    procedure SetReadOnly(AValue: Boolean);
    procedure SetSingleLine(AValue: Boolean);
    procedure SetShowLineNumbers(AValue: Boolean);
    procedure SetContextWords(AValue: TStrings);
    function GetContextWords: TStrings;
    function GetSyn: TSynEdit;
    function GetLines: TStrings;
    procedure PushToEngine;
  protected
    function CreateEngine: TaEngine; override;
    function RealGetText: TCaption; override;
    procedure RealSetText(const AValue: TCaption); override;
    procedure Loaded; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    { oznake gresaka }
    procedure ClearErrors;
    procedure AddError(ALine, ACol: Integer; const AMsg: string);
    { poruke parsera oblika "datoteka:redak:stupac: poruka" ili "redak: poruka"; vraca broj prepoznatih }
    function SetErrorsFromLog(ALog: TStrings): Integer;
    function ErrorCount: Integer;
    function ErrorAt(ALine: Integer): string;
    procedure GotoLine(ALine: Integer);
    { rijeci za dopunu koda: jezik + kontekst + rijeci iz dogadaja }
    procedure Matches(const APrefix: string; AOut: TStrings);
    { tablice, stupci i objekti aplikacije kao rijeci za dopunu }
    procedure LoadWordsFromDb(ADb: TAppDb);
    { pregled za testove i alate }
    function HighlighterName: string;
    function TokenDump(ALine: Integer): string;
    function FoldOpenAt(ALine: Integer): Integer;
    function FoldCloseAt(ALine: Integer): Integer;
    function SynBackground: TColor;
    function SynFontName: string;
    function GutterTextColor: TColor;
    function KeywordColor: TColor;
    function GutterShown: Boolean;
    function LineCount: Integer;
    property Syn: TSynEdit read GetSyn;
    property Lines: TStrings read GetLines;
    property ContextWords: TStrings read GetContextWords write SetContextWords;
  published
    property Variant: TaEditorVariant read GetVariant write SetVariant default ewFgl;
    property Text;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly default False;
    { jednoredni nacin (za svojstva s izrazima): bez brojeva redaka, Enter se ne umece }
    property SingleLine: Boolean read FSingleLine write SetSingleLine default False;
    property ShowLineNumbers: Boolean read FShowLineNumbers write SetShowLineNumbers default True;
    property OnCompletionWords: TaEditorWordsEvent read FOnWords write FOnWords;
    property Align;
    property Anchors;
    property Enabled;
    property Visible;
    property TabOrder;
    property OnEnter;
    property OnExit;
  end;

implementation

uses
  StrUtils, Math;

const
  SqlKeywordList: array[0..44] of string = (
    'select', 'from', 'where', 'and', 'or', 'not', 'in', 'is', 'null', 'like', 'between', 'order', 'by', 'group',
    'having', 'join', 'left', 'right', 'inner', 'outer', 'on', 'as', 'distinct', 'union', 'all', 'insert', 'into',
    'values', 'update', 'set', 'delete', 'create', 'table', 'drop', 'alter', 'index', 'limit', 'offset', 'case',
    'when', 'then', 'else', 'end', 'count', 'sum');

  PascalKeywordList: array[0..21] of string = (
    'procedure', 'function', 'begin', 'end', 'if', 'then', 'else', 'while', 'do', 'for', 'to', 'downto', 'var',
    'const', 'repeat', 'until', 'case', 'of', 'try', 'except', 'finally', 'result');

{ ---------------- pokretac ---------------- }

constructor TaSynEngine.Create(AHost: TaFamilyHost);
begin
  inherited Create(AHost);
  FSyn := TSynEdit.Create(nil);
  FSyn.OnChange := @SynChange;
  FSyn.OnKeyDown := @SynKeyDown;
  FSyn.OnSpecialLineMarkup := @SpecialLine;
  FSyn.Options := FSyn.Options - [eoScrollPastEol] + [eoTabIndent, eoTrimTrailingSpaces];
  FSyn.RightEdge := 0;
  FSyn.TabWidth := 2;
  FHl := CreateHighlighter;
  if FHl <> nil then FSyn.Highlighter := FHl;
  FComp := TSynCompletion.Create(nil);
  FComp.Editor := FSyn;
  FComp.OnExecute := @CompExecute;
  FComp.ShortCut := ShortCut(VK_SPACE, [ssCtrl]);
  AttachInner(FSyn);
  ApplyTheme;
  AddTokensListener(@TokensChanged);
end;

destructor TaSynEngine.Destroy;
begin
  RemoveTokensListener(@TokensChanged);
  if FSyn <> nil then FSyn.Highlighter := nil;
  FComp.Free;
  FHl.Free;
  inherited Destroy;
end;

function TaSynEngine.CreateHighlighter: TSynCustomHighlighter;
begin
  Result := nil;
end;

function TaSynEngine.Variant: TaEditorVariant;
begin
  Result := ewText;
end;

procedure TaSynEngine.SynChange(Sender: TObject);
begin
  InnerChanged(Sender);
end;

procedure TaSynEngine.SynKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if FSingleLine and (Key = VK_RETURN) then Key := 0;
end;

function TaSynEngine.GetText: string;
begin
  Result := FSyn.Lines.Text;
  { SynEdit dodaje zavrsni prijelaz u novi red; tekst ostaje onakav kakav je upisan }
  if (Result <> '') and (Copy(Result, Length(Result) - Length(LineEnding) + 1, Length(LineEnding)) = LineEnding) then
    Result := Copy(Result, 1, Length(Result) - Length(LineEnding));
end;

procedure TaSynEngine.SetText(const AValue: string);
begin
  if GetText <> AValue then FSyn.Lines.Text := AValue;
end;

procedure TaSynEngine.SetReadOnly(AValue: Boolean);
begin
  FSyn.ReadOnly := AValue;
end;

procedure TaSynEngine.SetSingleLine(AValue: Boolean);
begin
  FSingleLine := AValue;
  FSyn.Gutter.Visible := not AValue;
  if AValue then
  begin
    FSyn.ScrollBars := ssNone;
  end
  else FSyn.ScrollBars := ssAutoBoth;
end;

procedure TaSynEngine.TokensChanged(Sender: TObject);
begin
  ApplyTheme;
end;

procedure TaSynEngine.ApplyTheme;
var
  T: TaThemeTokens;
  P: TaEditorPalette;
  I: Integer;
begin
  T := ActiveTokens;
  P := EditorPalette(T);
  FSyn.Color := TokenColor(P.Background);
  FSyn.Font.Name := T.FontFamily;
  FSyn.Font.Size := T.FontSize;
  FSyn.Font.Color := TokenColor(P.Text);
  FSyn.Gutter.Color := TokenColor(P.GutterBg);
  FSyn.Gutter.LineNumberPart.MarkupInfo.Foreground := TokenColor(P.GutterText);
  FSyn.Gutter.LineNumberPart.MarkupInfo.Background := TokenColor(P.GutterBg);
  FSyn.Gutter.CodeFoldPart.MarkupInfo.Foreground := TokenColor(P.GutterText);
  FSyn.Gutter.CodeFoldPart.MarkupInfo.Background := TokenColor(P.GutterBg);
  for I := 0 to FSyn.Gutter.Parts.Count - 1 do
    FSyn.Gutter.Parts[I].MarkupInfo.Background := TokenColor(P.GutterBg);
  FSyn.Gutter.SeparatorPart.Visible := False;
  FSyn.SelectedColor.Background := TokenColor(P.Selection);
  FSyn.SelectedColor.Foreground := TokenColor(P.Text);
  FSyn.LineHighlightColor.Background := TokenColor(P.CurrentLine);
  FSyn.LineHighlightColor.Foreground := clNone;
  if FHl is TaSynHighlighter then TaSynHighlighter(FHl).ApplyPalette(P);
  FSyn.Invalidate;
end;

procedure TaSynEngine.SpecialLine(Sender: TObject; Line: Integer; var Special: Boolean; Markup: TSynSelectedColor);
var
  H: TaEditor;
  T: TaThemeTokens;
begin
  H := TaEditor(Host);
  if (H <> nil) and (H.ErrorAt(Line) <> '') then
  begin
    T := ActiveTokens;
    Special := True;
    Markup.Background := TokenColor(T.DangerSoft);
    Markup.Foreground := clNone;
  end;
end;

procedure TaSynEngine.CompExecute(Sender: TObject);
var
  Prefix: string;
  L: TStringList;
begin
  Prefix := FComp.CurrentString;
  L := TStringList.Create;
  try
    TaEditor(Host).Matches(Prefix, L);
    FComp.ItemList.Assign(L);
  finally
    L.Free;
  end;
end;

{ ---------------- pokretaci po jeziku ---------------- }

function TaSynFglEngine.CreateHighlighter: TSynCustomHighlighter;
begin
  Result := TaSynHighlighter.Create(nil);
  TaSynHighlighter(Result).Language := slFgl;
end;

function TaSynFglEngine.Variant: TaEditorVariant;
begin
  Result := ewFgl;
end;

function TaSynSqlEngine.CreateHighlighter: TSynCustomHighlighter;
begin
  Result := TSynSQLSyn.Create(nil);
end;

function TaSynSqlEngine.Variant: TaEditorVariant;
begin
  Result := ewSql;
end;

function TaSynExprEngine.CreateHighlighter: TSynCustomHighlighter;
begin
  Result := TaSynHighlighter.Create(nil);
  TaSynHighlighter(Result).Language := slExpression;
end;

function TaSynExprEngine.Variant: TaEditorVariant;
begin
  Result := ewExpression;
end;

function TaSynPascalEngine.CreateHighlighter: TSynCustomHighlighter;
begin
  Result := TSynPasSyn.Create(nil);
end;

function TaSynPascalEngine.Variant: TaEditorVariant;
begin
  Result := ewPascal;
end;

function TaSynJsonEngine.CreateHighlighter: TSynCustomHighlighter;
begin
  Result := TSynJScriptSyn.Create(nil);
end;

function TaSynJsonEngine.Variant: TaEditorVariant;
begin
  Result := ewJson;
end;

function TaSynTextEngine.Variant: TaEditorVariant;
begin
  Result := ewText;
end;

{ ---------------- TaEditor ---------------- }

constructor TaEditor.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FContextWords := TStringList.Create;
  FContextWords.Sorted := True;
  FContextWords.Duplicates := dupIgnore;
  FContextWords.CaseSensitive := False;
  FVariant := ewFgl;
  FShowLineNumbers := True;
  SetInitialBounds(0, 0, 320, 160);
  ReplaceEngine;
  PushToEngine;
end;

destructor TaEditor.Destroy;
begin
  FContextWords.Free;
  inherited Destroy;
end;

function TaEditor.CreateEngine: TaEngine;
var
  C: TaEngineClass;
begin
  C := FindEngine(EditorFamily, EditorVariantNames[FVariant]);
  if C = nil then C := FindEngine(EditorFamily, 'text');
  Result := C.Create(Self);
end;

function TaEditor.GetSyn: TSynEdit;
begin
  if Engine is TaSynEngine then Result := TaSynEngine(Engine).Syn else Result := nil;
end;

function TaEditor.GetLines: TStrings;
begin
  Result := Syn.Lines;
end;

function TaEditor.GetVariant: TaEditorVariant;
begin
  Result := FVariant;
end;

procedure TaEditor.SetVariant(AValue: TaEditorVariant);
begin
  if AValue = FVariant then Exit;
  FText := RealGetText;
  FVariant := AValue;
  ReplaceEngine;
  PushToEngine;
end;

procedure TaEditor.PushToEngine;
begin
  if Engine = nil then Exit;
  Engine.SetText(FText);
  Engine.SetReadOnly(FReadOnly);
  if Engine is TaSynEngine then
  begin
    TaSynEngine(Engine).SetSingleLine(FSingleLine);
    if not FSingleLine then Syn.Gutter.LineNumberPart.Visible := FShowLineNumbers;
  end;
end;

procedure TaEditor.SetReadOnly(AValue: Boolean);
begin
  FReadOnly := AValue;
  if Engine <> nil then Engine.SetReadOnly(AValue);
end;

procedure TaEditor.SetSingleLine(AValue: Boolean);
begin
  FSingleLine := AValue;
  if Engine is TaSynEngine then TaSynEngine(Engine).SetSingleLine(AValue);
end;

procedure TaEditor.SetShowLineNumbers(AValue: Boolean);
begin
  FShowLineNumbers := AValue;
  if (Syn <> nil) and not FSingleLine then Syn.Gutter.LineNumberPart.Visible := AValue;
end;

function TaEditor.RealGetText: TCaption;
begin
  if Engine <> nil then Result := Engine.GetText else Result := FText;
end;

procedure TaEditor.RealSetText(const AValue: TCaption);
begin
  FText := AValue;
  if Engine <> nil then Engine.SetText(AValue);
end;

procedure TaEditor.Loaded;
begin
  inherited Loaded;
  PushToEngine;
end;

function TaEditor.GetContextWords: TStrings;
begin
  Result := FContextWords;
end;

procedure TaEditor.SetContextWords(AValue: TStrings);
begin
  FContextWords.Assign(AValue);
end;

{ ---------------- greske ---------------- }

procedure TaEditor.ClearErrors;
begin
  SetLength(FErrors, 0);
  if Syn <> nil then Syn.Invalidate;
end;

procedure TaEditor.AddError(ALine, ACol: Integer; const AMsg: string);
begin
  SetLength(FErrors, Length(FErrors) + 1);
  FErrors[High(FErrors)].Line := ALine;
  FErrors[High(FErrors)].Col := ACol;
  FErrors[High(FErrors)].Msg := AMsg;
  if Syn <> nil then Syn.Invalidate;
end;

function TaEditor.ErrorCount: Integer;
begin
  Result := Length(FErrors);
end;

function TaEditor.ErrorAt(ALine: Integer): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FErrors) do
    if FErrors[I].Line = ALine then Exit(FErrors[I].Msg);
end;

function TaEditor.SetErrorsFromLog(ALog: TStrings): Integer;
var
  I, P, Ln, Col: Integer;
  S, Rest: string;

  { cita broj do dvotocke; vraca False ako dio nije broj }
  function TakeNum(var AText: string; out ANum: Integer): Boolean;
  var
    Q: Integer;
  begin
    Q := Pos(':', AText);
    Result := (Q > 1) and TryStrToInt(Trim(Copy(AText, 1, Q - 1)), ANum);
    if Result then AText := Copy(AText, Q + 1, MaxInt);
  end;

begin
  ClearErrors;
  Result := 0;
  begin
    for I := 0 to ALog.Count - 1 do
    begin
      S := Trim(ALog[I]);
      if S = '' then Continue;
      { preskoci naziv datoteke: sve do prvog dijela koji je broj }
      Rest := S;
      Ln := 0; Col := 0;
      repeat
        P := Pos(':', Rest);
        if P = 0 then Break;
        if TryStrToInt(Trim(Copy(Rest, 1, P - 1)), Ln) then Break;
        Rest := Copy(Rest, P + 1, MaxInt);
      until False;
      if (P = 0) or (Ln <= 0) then Continue;
      Rest := Copy(Rest, P + 1, MaxInt);
      if TakeNum(Rest, Col) then
      begin
        { redak:stupac: poruka }
      end
      else Col := 0;
      AddError(Ln, Col, Trim(Rest));
      Inc(Result);
    end;
  end;
end;

procedure TaEditor.GotoLine(ALine: Integer);
begin
  if Syn = nil then Exit;
  Syn.CaretY := EnsureRange(ALine, 1, Max(Syn.Lines.Count, 1));
  Syn.CaretX := 1;
end;

{ ---------------- pregled ---------------- }

function TaEditor.HighlighterName: string;
begin
  if (Syn <> nil) and (Syn.Highlighter <> nil) then Result := Syn.Highlighter.ClassName else Result := '';
end;

{ "vrsta:tekst|..." za jedan redak (0-based), bez razmaka; vrste: 2 komentar, 3 kljucna rijec, 4 tip, 5 funkcija,
  6 identifikator, 7 broj, 8 niz, 9 simbol, 10 [polje] ili $parametar }
function TaEditor.TokenDump(ALine: Integer): string;
var
  Hl: TLazEditCustomHighlighter;
  Tk: string;
begin
  Result := '';
  if (Syn = nil) or (Syn.Highlighter = nil) then Exit;
  Hl := Syn.Highlighter;
  Hl.PrepareLines(ALine);
  Hl.StartAtLineIndex(ALine);
  while not Hl.GetEol do
  begin
    Tk := Hl.GetToken;
    if Trim(Tk) <> '' then Result := Result + IntToStr(Hl.GetTokenKind) + ':' + Tk + '|';
    Hl.Next;
  end;
end;

function TaEditor.FoldOpenAt(ALine: Integer): Integer;
begin
  Result := 0;
  if (Syn <> nil) and (Syn.Highlighter is TaSynHighlighter) then
  begin
    Syn.Highlighter.PrepareLines(ALine);
    Result := TaSynHighlighter(Syn.Highlighter).FoldOpenCount(ALine);
  end;
end;

function TaEditor.FoldCloseAt(ALine: Integer): Integer;
begin
  Result := 0;
  if (Syn <> nil) and (Syn.Highlighter is TaSynHighlighter) then
  begin
    Syn.Highlighter.PrepareLines(ALine);
    Result := TaSynHighlighter(Syn.Highlighter).FoldCloseCount(ALine);
  end;
end;

function TaEditor.SynBackground: TColor;
begin
  Result := Syn.Color;
end;

function TaEditor.SynFontName: string;
begin
  Result := Syn.Font.Name;
end;

function TaEditor.GutterTextColor: TColor;
begin
  Result := Syn.Gutter.LineNumberPart.MarkupInfo.Foreground;
end;

function TaEditor.KeywordColor: TColor;
begin
  Result := clNone;
  if Syn.Highlighter is TaSynHighlighter then
    Result := Syn.Highlighter.GetTokenClassAttribute(tcKeyword).Foreground;
end;

function TaEditor.GutterShown: Boolean;
begin
  Result := Syn.Gutter.Visible;
end;

function TaEditor.LineCount: Integer;
begin
  Result := Syn.Lines.Count;
end;

{ ---------------- dopuna koda ---------------- }

procedure TaEditor.Matches(const APrefix: string; AOut: TStrings);
var
  All: TStringList;
  I: Integer;
  P: string;
begin
  AOut.Clear;
  All := TStringList.Create;
  try
    All.Sorted := True;
    All.Duplicates := dupIgnore;
    All.CaseSensitive := False;
    case FVariant of
      ewFgl:
        begin
          FglKeywords(All);
          FglTypeNames(All);
          FglBuiltinFunctions(All);
        end;
      ewExpression: ExprKeywords(All);
      ewSql:
        for I := 0 to High(SqlKeywordList) do All.Add(SqlKeywordList[I]);
      ewPascal:
        for I := 0 to High(PascalKeywordList) do All.Add(PascalKeywordList[I]);
    end;
    All.AddStrings(FContextWords);
    if Assigned(FOnWords) then FOnWords(Self, APrefix, All);
    P := LowerCase(APrefix);
    for I := 0 to All.Count - 1 do
      if (P = '') or (Copy(LowerCase(All[I]), 1, Length(P)) = P) then AOut.Add(All[I]);
  finally
    All.Free;
  end;
end;

procedure TaEditor.LoadWordsFromDb(ADb: TAppDb);
var
  Tables, Objs: TStringList;
  I, J: Integer;
  Q: TZQuery;
begin
  FContextWords.Clear;
  if (ADb = nil) or not ADb.Connected then Exit;
  Tables := ADb.UserTables;
  try
    for I := 0 to Tables.Count - 1 do
    begin
      FContextWords.Add(Tables[I]);
      try
        Q := ADb.NewQuery('SELECT * FROM ' + ADb.QuoteId(Tables[I]) + ' WHERE 1 = 0');
        try
          Q.Open;
          for J := 0 to Q.FieldCount - 1 do FContextWords.Add(Q.Fields[J].FieldName);
        finally
          Q.Free;
        end;
      except
      end;
    end;
  finally
    Tables.Free;
  end;
  for J := 0 to 2 do
  begin
    case J of
      0: Objs := ADb.ListObjects('_sys_programs');
      1: Objs := ADb.ListObjects('_sys_reports');
    else
      Objs := ADb.ListObjects('_sys_forms');
    end;
    try
      FContextWords.AddStrings(Objs);
    finally
      Objs.Free;
    end;
  end;
end;

initialization
  RegisterClass(TaEditor);
  RegisterEngine(EditorFamily, '4gl', TaSynFglEngine);
  RegisterEngine(EditorFamily, 'sql', TaSynSqlEngine);
  RegisterEngine(EditorFamily, 'expression', TaSynExprEngine);
  RegisterEngine(EditorFamily, 'pascal', TaSynPascalEngine);
  RegisterEngine(EditorFamily, 'json', TaSynJsonEngine);
  RegisterEngine(EditorFamily, 'text', TaSynTextEngine);

end.
