unit ta_synhl;
{ Bojenje sintakse za SynEdit: 4GL (naredbe, tipovi, komentari -- i { }, nizovi, $parametri, sklapanje blokova
  MAIN/FUNCTION/IF/WHILE/FOR/... END ...) i jezik izraza ([polje], funkcije, nizovi, brojevi).
  Boje dolaze iz tokena teme (ApplyPalette), pa uredjivac prati svijetlu i tamnu temu i naglasak. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, SynEditTypes, SynEditHighlighter, SynEditHighlighterFoldBase,
  SynEditStrConst, LazEditTextAttributes, LazEditHighlighter, ta_tokens;

type
  TaSynLanguage = (slFgl, slExpression);

  TaSynTokenKind = (tkNull, tkSpace, tkComment, tkKeyword, tkType, tkFunction, tkIdent, tkNumber, tkString,
    tkSymbol, tkParam, tkUnknown);

  TaSynRange = (rsNone, rsBrace);

  TaSynFoldType = (cfbtNone, cfbtBlock);

  TaSynHighlighter = class(TSynCustomFoldHighlighter)
  private
    FLanguage: TaSynLanguage;
    FRange: TaSynRange;
    Run: Integer;
    FTokenPos: Integer;
    FTokenID: TaSynTokenKind;
    FFirstOnLine: Boolean;
    FCommentAttri, FKeyAttri, FTypeAttri, FFuncAttri, FIdentAttri, FNumberAttri, FSpaceAttri, FStringAttri,
      FSymbolAttri, FParamAttri: TLazEditHighlighterAttributes;
    procedure SetLanguage(AValue: TaSynLanguage);
    function WordKind(const AWord: string; ANextIsParen: Boolean): TaSynTokenKind;
    procedure ScanBrace;
  protected
    function GetFoldConfigInstance(Index: Integer): TSynCustomFoldConfig; override;
    function GetFoldConfigCount: Integer; override;
    function GetFoldConfigInternalCount: Integer; override;
    procedure CreateRootCodeFoldBlock; override;
    function GetIdentChars: TSynIdentChars; override;
  public
    class function GetLanguageName: string; override;
    constructor Create(AOwner: TComponent); override;
    function GetTokenClassAttribute(ATkClass: TLazEditTokenClass;
      ATkDetails: TLazEditTokenDetails = []): TLazEditTextAttribute; override;
    function GetEol: Boolean; override;
    function GetRange: Pointer; override;
    procedure SetRange(Value: Pointer); override;
    procedure ResetRange; override;
    procedure InitForScanningLine; override;
    function GetToken: String; override;
    procedure GetTokenEx(out TokenStart: PChar; out TokenLength: integer); override;
    function GetTokenAttribute: TLazEditTextAttribute; override;
    function GetTokenKind: integer; override;
    function GetTokenPos: Integer; override;
    procedure Next; override;
    { boje iz palete teme }
    procedure ApplyPalette(const P: TaEditorPalette);
    property Language: TaSynLanguage read FLanguage write SetLanguage;
  end;

{ rijeci jezika (mala slova), npr. za dopunu koda }
procedure FglKeywords(AList: TStrings);
procedure FglTypeNames(AList: TStrings);
procedure FglBuiltinFunctions(AList: TStrings);
procedure ExprKeywords(AList: TStrings);

implementation

const
  FglKeywordList: array[0..105] of string = (
    'main', 'function', 'return', 'returning', 'end', 'define', 'let', 'if', 'then', 'else', 'while', 'for', 'to',
    'step', 'foreach', 'case', 'when', 'otherwise', 'exit', 'continue', 'program', 'menu', 'command', 'input',
    'by', 'name', 'without', 'defaults', 'construct', 'on', 'from', 'declare', 'cursor', 'open', 'fetch', 'close',
    'free', 'prepare', 'execute', 'using', 'into', 'select', 'insert', 'update', 'delete', 'create', 'drop',
    'alter', 'where', 'order', 'group', 'having', 'values', 'set', 'table', 'begin', 'commit', 'rollback', 'work',
    'whenever', 'error', 'stop', 'message', 'display', 'prompt', 'call', 'globals', 'database', 'include', 'record',
    'array', 'of', 'like', 'null', 'and', 'or', 'not', 'is', 'between', 'in', 'sleep', 'initialize', 'columns',
    'emit', 'report', 'start', 'output', 'finish', 'format', 'first', 'page', 'header', 'trailer', 'after',
    'before', 'print', 'skip', 'need', 'screen', 'field', 'next', 'form', 'attribute', 'distinct', 'as', 'with');

  FglTypeList: array[0..13] of string = (
    'integer', 'int', 'smallint', 'bigint', 'decimal', 'numeric', 'float', 'smallfloat', 'char', 'varchar',
    'text', 'date', 'datetime', 'boolean');

  FglFuncList: array[0..33] of string = (
    'today', 'current', 'length', 'trim', 'upshift', 'downshift', 'substr', 'mdy', 'day', 'month', 'year',
    'weekday', 'abs', 'sqrt', 'mod', 'round', 'trunc', 'num_args', 'arg_val', 'fgl_getenv', 'status', 'count',
    'sum', 'avg', 'min', 'max', 'pageno', 'lineno', 'sqlca', 'int_flag', 'upper', 'lower', 'cast', 'coalesce');

  ExprKeywordList: array[0..6] of string = ('and', 'or', 'not', 'true', 'false', 'null', 'mod');

  FglOpeners: array[0..10] of string = (
    'main', 'function', 'report', 'if', 'while', 'for', 'foreach', 'case', 'menu', 'globals', 'screen');

procedure FillList(AList: TStrings; const A: array of string);
var
  I: Integer;
begin
  for I := 0 to High(A) do AList.Add(A[I]);
end;

procedure FglKeywords(AList: TStrings);
begin
  FillList(AList, FglKeywordList);
end;

procedure FglTypeNames(AList: TStrings);
begin
  FillList(AList, FglTypeList);
end;

procedure FglBuiltinFunctions(AList: TStrings);
begin
  FillList(AList, FglFuncList);
end;

procedure ExprKeywords(AList: TStrings);
begin
  FillList(AList, ExprKeywordList);
end;

function InSet(const AWord: string; const A: array of string): Boolean;
var
  I: Integer;
begin
  for I := 0 to High(A) do
    if A[I] = AWord then Exit(True);
  Result := False;
end;

{ ---------------- TaSynHighlighter ---------------- }

constructor TaSynHighlighter.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCommentAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrComment, SYNS_XML_AttrComment);
  FCommentAttri.Style := [fsItalic];
  AddAttribute(FCommentAttri);
  FKeyAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrKey, SYNS_XML_AttrKey);
  FKeyAttri.Style := [fsBold];
  AddAttribute(FKeyAttri);
  FTypeAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrDataType, SYNS_XML_AttrDataType);
  AddAttribute(FTypeAttri);
  FFuncAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrFunction, SYNS_XML_AttrFunction);
  AddAttribute(FFuncAttri);
  FIdentAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrIdentifier, SYNS_XML_AttrIdentifier);
  AddAttribute(FIdentAttri);
  FNumberAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrNumber, SYNS_XML_AttrNumber);
  AddAttribute(FNumberAttri);
  FSpaceAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrSpace, SYNS_XML_AttrSpace);
  AddAttribute(FSpaceAttri);
  FStringAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrString, SYNS_XML_AttrString);
  AddAttribute(FStringAttri);
  FSymbolAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrSymbol, SYNS_XML_AttrSymbol);
  AddAttribute(FSymbolAttri);
  FParamAttri := TLazEditHighlighterAttributes.Create(@SYNS_AttrVariable, SYNS_XML_AttrVariable);
  AddAttribute(FParamAttri);
  SetAttributesOnChange(@DefHighlightChange);
  FRange := rsNone;
  ApplyPalette(EditorPalette(ActiveTokens));
end;

procedure TaSynHighlighter.ApplyPalette(const P: TaEditorPalette);
begin
  FCommentAttri.Foreground := TokenColor(P.Comment);
  FKeyAttri.Foreground := TokenColor(P.Keyword);
  FTypeAttri.Foreground := TokenColor(P.Keyword);
  FTypeAttri.Style := [];
  FFuncAttri.Foreground := TokenColor(P.Symbol);
  FIdentAttri.Foreground := TokenColor(P.Identifier);
  FNumberAttri.Foreground := TokenColor(P.Number);
  FSpaceAttri.Foreground := clNone;
  FStringAttri.Foreground := TokenColor(P.StringLit);
  FSymbolAttri.Foreground := TokenColor(P.Symbol);
  FParamAttri.Foreground := TokenColor(P.Number);
  FParamAttri.Style := [fsUnderline];
  FParamAttri.Background := clNone;
  { pozadina svih atributa je prozirna: boju daje uredjivac }
  FCommentAttri.Background := clNone;
  FKeyAttri.Background := clNone;
  FTypeAttri.Background := clNone;
  FFuncAttri.Background := clNone;
  FIdentAttri.Background := clNone;
  FNumberAttri.Background := clNone;
  FStringAttri.Background := clNone;
  FSymbolAttri.Background := clNone;
end;

class function TaSynHighlighter.GetLanguageName: string;
begin
  Result := 'TyphAccess';
end;

procedure TaSynHighlighter.SetLanguage(AValue: TaSynLanguage);
begin
  if FLanguage = AValue then Exit;
  FLanguage := AValue;
  DefHighlightChange(Self);
end;

function TaSynHighlighter.GetFoldConfigInstance(Index: Integer): TSynCustomFoldConfig;
begin
  Result := inherited GetFoldConfigInstance(Index);
  Result.Enabled := True;
end;

function TaSynHighlighter.GetFoldConfigCount: Integer;
begin
  Result := Ord(High(TaSynFoldType)) - Ord(Low(TaSynFoldType));
end;

function TaSynHighlighter.GetFoldConfigInternalCount: Integer;
begin
  Result := Ord(High(TaSynFoldType)) - Ord(Low(TaSynFoldType)) + 1;
end;

procedure TaSynHighlighter.CreateRootCodeFoldBlock;
begin
  inherited CreateRootCodeFoldBlock;
  RootCodeFoldBlock.InitRootBlockType(Pointer(PtrInt(cfbtNone)));
end;

function TaSynHighlighter.GetIdentChars: TSynIdentChars;
begin
  Result := TSynValidStringChars;
end;

function TaSynHighlighter.GetTokenClassAttribute(ATkClass: TLazEditTokenClass;
  ATkDetails: TLazEditTokenDetails): TLazEditTextAttribute;
begin
  case ATkClass of
    tcComment: Result := FCommentAttri;
    tcKeyword: Result := FKeyAttri;
    tcString: Result := FStringAttri;
    tcWhiteSpace: Result := FSpaceAttri;
    tcSymbol: Result := FSymbolAttri;
    tcNumber: Result := FNumberAttri;
  else
    Result := nil;
  end;
end;

function TaSynHighlighter.GetEol: Boolean;
begin
  Result := FTokenID = tkNull;
end;

function TaSynHighlighter.GetRange: Pointer;
begin
  CodeFoldRange.RangeType := Pointer(PtrUInt(Ord(FRange)));
  Result := inherited GetRange;
end;

procedure TaSynHighlighter.SetRange(Value: Pointer);
begin
  inherited SetRange(Value);
  FRange := TaSynRange(Integer(PtrUInt(CodeFoldRange.RangeType)));
end;

procedure TaSynHighlighter.ResetRange;
begin
  inherited ResetRange;
  FRange := rsNone;
end;

procedure TaSynHighlighter.InitForScanningLine;
begin
  inherited InitForScanningLine;
  Run := 0;
  FFirstOnLine := True;
  Next;
end;

function TaSynHighlighter.WordKind(const AWord: string; ANextIsParen: Boolean): TaSynTokenKind;
var
  L: string;
begin
  L := LowerCase(AWord);
  if FLanguage = slExpression then
  begin
    if InSet(L, ExprKeywordList) then Exit(tkKeyword);
    if ANextIsParen then Exit(tkFunction);
    Exit(tkIdent);
  end;
  if InSet(L, FglKeywordList) then Exit(tkKeyword);
  if InSet(L, FglTypeList) then Exit(tkType);
  if InSet(L, FglFuncList) then Exit(tkFunction);
  if ANextIsParen then Exit(tkFunction);
  Result := tkIdent;
end;

{ nastavlja komentar { ... } na ovom retku }
procedure TaSynHighlighter.ScanBrace;
begin
  while (LinePtr[Run] <> #0) and (LinePtr[Run] <> '}') do Inc(Run);
  if LinePtr[Run] = '}' then
  begin
    Inc(Run);
    FRange := rsNone;
  end;
end;

procedure TaSynHighlighter.Next;
var
  C: Char;
  S: string;
  Q: Char;
  Start, J: Integer;
  K: TaSynTokenKind;
begin
  FTokenPos := Run;
  C := LinePtr[Run];
  if C = #0 then
  begin
    FTokenID := tkNull;
    Exit;
  end;
  { nastavak viseretkovnog komentara }
  if FRange = rsBrace then
  begin
    FTokenID := tkComment;
    ScanBrace;
    Exit;
  end;
  if C <= ' ' then
  begin
    FTokenID := tkSpace;
    while (LinePtr[Run] <> #0) and (LinePtr[Run] <= ' ') do Inc(Run);
    Exit;
  end;
  if (FLanguage = slFgl) and (C = '-') and (LinePtr[Run + 1] = '-') then
  begin
    FTokenID := tkComment;
    while LinePtr[Run] <> #0 do Inc(Run);
    FFirstOnLine := False;
    Exit;
  end;
  if (FLanguage = slFgl) and (C = '{') then
  begin
    FTokenID := tkComment;
    Inc(Run);
    FRange := rsBrace;
    ScanBrace;
    FFirstOnLine := False;
    Exit;
  end;
  if (C = '"') or (C = '''') then
  begin
    FTokenID := tkString;
    Q := C;
    Inc(Run);
    while LinePtr[Run] <> #0 do
    begin
      if LinePtr[Run] = Q then
      begin
        if LinePtr[Run + 1] = Q then begin Inc(Run, 2); Continue; end;
        Inc(Run);
        Break;
      end;
      Inc(Run);
    end;
    FFirstOnLine := False;
    Exit;
  end;
  if C in ['0'..'9'] then
  begin
    FTokenID := tkNumber;
    while LinePtr[Run] in ['0'..'9'] do Inc(Run);
    if (LinePtr[Run] = '.') and (LinePtr[Run + 1] in ['0'..'9']) then
    begin
      Inc(Run);
      while LinePtr[Run] in ['0'..'9'] do Inc(Run);
    end;
    FFirstOnLine := False;
    Exit;
  end;
  if (C = '$') and (FLanguage = slFgl) and (LinePtr[Run + 1] in ['A'..'Z', 'a'..'z', '_']) then
  begin
    FTokenID := tkParam;
    Inc(Run);
    while LinePtr[Run] in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.'] do Inc(Run);
    FFirstOnLine := False;
    Exit;
  end;
  if (C = '[') and (FLanguage = slExpression) then
  begin
    { [polje] ili [?parametar] kao jedan simbol }
    J := Run + 1;
    while (LinePtr[J] <> #0) and (LinePtr[J] <> ']') do Inc(J);
    if LinePtr[J] = ']' then
    begin
      FTokenID := tkParam;
      Run := J + 1;
      FFirstOnLine := False;
      Exit;
    end;
  end;
  if C in ['A'..'Z', 'a'..'z', '_'] then
  begin
    Start := Run;
    while LinePtr[Run] in ['A'..'Z', 'a'..'z', '0'..'9', '_'] do Inc(Run);
    SetString(S, LinePtr + Start, Run - Start);
    J := Run;
    while LinePtr[J] = ' ' do Inc(J);
    K := WordKind(S, LinePtr[J] = '(');
    FTokenID := K;
    if (FLanguage = slFgl) and (K = tkKeyword) then
    begin
      S := LowerCase(S);
      if FFirstOnLine then
      begin
        if S = 'end' then
        begin
          if TopCodeFoldBlockType = Pointer(PtrInt(cfbtBlock)) then EndCodeFoldBlock(True);
        end
        else if InSet(S, FglOpeners) then StartCodeFoldBlock(Pointer(PtrInt(cfbtBlock)), True);
      end;
    end;
    FFirstOnLine := False;
    Exit;
  end;
  { simbol }
  FTokenID := tkSymbol;
  Inc(Run);
  if (LinePtr[Run] <> #0) and (C in ['<', '>', '!', '|', ':']) and (LinePtr[Run] in ['=', '>', '|']) then Inc(Run);
  FFirstOnLine := False;
end;

function TaSynHighlighter.GetToken: String;
begin
  SetString(Result, LinePtr + FTokenPos, Run - FTokenPos);
end;

procedure TaSynHighlighter.GetTokenEx(out TokenStart: PChar; out TokenLength: integer);
begin
  TokenLength := Run - FTokenPos;
  TokenStart := LinePtr + FTokenPos;
end;

function TaSynHighlighter.GetTokenAttribute: TLazEditTextAttribute;
begin
  case FTokenID of
    tkComment: Result := FCommentAttri;
    tkKeyword: Result := FKeyAttri;
    tkType: Result := FTypeAttri;
    tkFunction: Result := FFuncAttri;
    tkIdent: Result := FIdentAttri;
    tkNumber: Result := FNumberAttri;
    tkSpace: Result := FSpaceAttri;
    tkString: Result := FStringAttri;
    tkSymbol: Result := FSymbolAttri;
    tkParam: Result := FParamAttri;
    tkUnknown: Result := FIdentAttri;
  else
    Result := nil;
  end;
end;

function TaSynHighlighter.GetTokenKind: integer;
begin
  Result := Ord(FTokenID);
end;

function TaSynHighlighter.GetTokenPos: Integer;
begin
  Result := FTokenPos;
end;

end.
