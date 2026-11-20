unit ta_tokens;
{ Tokeni teme: sve boje, oblik, razmaci i font na jednom mjestu (poglavlje 6 plana).
  Cista logika bez sucelja: izvodenje cijele teme iz jednog naglaska, provjera kontrasta,
  JSON zapis teme (themes/*.json) i globalna "aktivna" tema koju citaju kontrole koje same crtaju
  (bocni izbornik, grafikon, ...). Primjenu na Qt (QSS) radi ta_theme. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics;

type
  TaShape = (shSquare, shRounded, shPill);

  TaThemeTokens = record
    Name: string;
    Dark: Boolean;
    Shape: TaShape;
    { boje kao '#RRGGBB' }
    Accent, AccentSoft, AccentHover, OnAccent: string;
    Bg, Surface, Soft, Header, Border, Text, TextSoft, Tip: string;
    Success, Warning, Danger, DangerSoft: string;
    RadiusButton, RadiusField, RadiusCard, ControlHeight: Integer;
    FontFamily: string;
    FontSize: Integer;
    Chart: array[0..7] of string;
  end;

const
  DefaultFontFamily = 'JetBrains Mono';
  DefaultFontSize = 10;
  ShapeNames: array[TaShape] of string = ('square', 'rounded', 'pill');

{ ---- boje ---- }
function TokenColor(const AHex: string): TColor;
function ColorHex(AColor: TColor): string;
function IsHexColor(const S: string): Boolean;
{ mjesavina: 0 = A, 1 = B }
function MixHex(const A, B: string; T: Double): string;
{ omjer kontrasta po WCAG (1..21) }
function ContrastRatio(const A, B: string): Double;

{ ---- teme ---- }
function BuiltinThemeCount: Integer;
function BuiltinThemeName(AIndex: Integer): string;
function BuiltinThemeIndex(const AName: string): Integer;
{ cijela tema iz naglasaka (svijetla varijanta ako ADark=False) }
function DeriveTokens(const AName, AAccent: string; ADark: Boolean; AShape: TaShape): TaThemeTokens;
{ ugradena tema po indeksu (0 = Plava, tocne vrijednosti iz plana) }
function BuiltinTokens(AIndex: Integer; ADark: Boolean; AShape: TaShape): TaThemeTokens;
{ postavlja oblik i polumjere }
procedure ApplyShape(var T: TaThemeTokens; AShape: TaShape);
{ prazno = u redu, inace opis greske (neispravna boja, premali kontrast teksta na naglasku) }
function ValidateTokens(const T: TaThemeTokens): string;

{ ---- JSON ---- }
function TokensToJson(const T: TaThemeTokens): string;
{ ucitava minimalni zapis {"name","accent","shape","dark"} uz neobavezna nadjacavanja "tokens":{...};
  AWarn dobiva upozorenja (nepoznati kljucevi). False = neispravan zapis (AWarn sadrzi razlog) }
function TokensFromJson(const AJson: string; out T: TaThemeTokens; out AWarn: string): Boolean;
function LoadThemeFile(const AFile: string; out T: TaThemeTokens; out AWarn: string): Boolean;
procedure SaveThemeFile(const AFile: string; const T: TaThemeTokens);

{ ---- aktivna tema (za kontrole koje same crtaju) ---- }
{ pismo teme (obitelj i velicina) za kontrole koje same crtaju: isti izgled na svakom sucelju }
procedure ApplyThemeFont(AFont: TFont);
function ActiveTokens: TaThemeTokens;
procedure SetActiveTokens(const T: TaThemeTokens);
procedure AddTokensListener(AListener: TNotifyEvent);
procedure RemoveTokensListener(AListener: TNotifyEvent);
function ActiveChartColor(AIndex: Integer): TColor;
{ ---- adapteri za biblioteke koje imaju vlastite atribute (SynEdit, TAChart): boje iz tokena ---- }
type
  TaEditorPalette = record
    Background, Text, Keyword, StringLit, Number, Comment, Identifier, Symbol, Error: string;
    CurrentLine, Selection, GutterBg, GutterText, Bracket: string;
  end;
  TaChartPalette = record
    Background, Axis, Grid, Text, Legend: string;
    Series: array[0..7] of string;
  end;

function EditorPalette(const T: TaThemeTokens): TaEditorPalette;
function ChartPalette(const T: TaThemeTokens): TaChartPalette;

{ mape u kojima se traze slova teme (uz izvrsnu datoteku, uz projekt, sustavna); redom }
function ThemeFontDirs(const AExtraDir: string = ''): TStringList;
{ puna putanja datoteke slova (npr. 'JetBrainsMono-Regular.ttf') ili '' }
function FindThemeFontFile(const AFileName: string): string;

implementation

uses
  fpjson, jsonparser, Math;

const
  BuiltinNames: array[0..5] of string = ('Plava', 'Zelena', 'Crvena', 'Ljubičasta', 'Narančasta', 'Grafit');
  BuiltinAccent: array[0..5] of string = ('#2563EB', '#16A34A', '#DC2626', '#7C3AED', '#EA580C', '#475569');
  BaseChart: array[0..7] of string = ('#2563EB', '#F97316', '#16A34A', '#DC2626', '#9333EA', '#0891B2', '#CA8A04', '#DB2777');

var
  GActive: TaThemeTokens;
  GActiveSet: Boolean = False;
  GListeners: array of TNotifyEvent;

{ ---------------- boje ---------------- }

function IsHexColor(const S: string): Boolean;
var
  I: Integer;
begin
  Result := (Length(S) = 7) and (S[1] = '#');
  if not Result then Exit;
  for I := 2 to 7 do
    if not (S[I] in ['0'..'9', 'A'..'F', 'a'..'f']) then Exit(False);
end;

procedure SplitRgb(const AHex: string; out R, G, B: Integer);
begin
  R := StrToIntDef('$' + Copy(AHex, 2, 2), 0);
  G := StrToIntDef('$' + Copy(AHex, 4, 2), 0);
  B := StrToIntDef('$' + Copy(AHex, 6, 2), 0);
end;

function RgbHex(R, G, B: Integer): string;
begin
  R := EnsureRange(R, 0, 255); G := EnsureRange(G, 0, 255); B := EnsureRange(B, 0, 255);
  Result := '#' + IntToHex(R, 2) + IntToHex(G, 2) + IntToHex(B, 2);
end;

function TokenColor(const AHex: string): TColor;
var
  R, G, B: Integer;
begin
  SplitRgb(AHex, R, G, B);
  Result := TColor(R or (G shl 8) or (B shl 16));
end;

function ColorHex(AColor: TColor): string;
var
  C: Integer;
begin
  C := ColorToRGB(AColor);
  Result := RgbHex(C and $FF, (C shr 8) and $FF, (C shr 16) and $FF);
end;

function MixHex(const A, B: string; T: Double): string;
var
  R1, G1, B1, R2, G2, B2: Integer;
begin
  SplitRgb(A, R1, G1, B1);
  SplitRgb(B, R2, G2, B2);
  Result := RgbHex(Round(R1 + (R2 - R1) * T), Round(G1 + (G2 - G1) * T), Round(B1 + (B2 - B1) * T));
end;

function Lum(const AHex: string): Double;
  function Ch(V: Integer): Double;
  var
    X: Double;
  begin
    X := V / 255;
    if X <= 0.03928 then Result := X / 12.92 else Result := Power((X + 0.055) / 1.055, 2.4);
  end;
var
  R, G, B: Integer;
begin
  SplitRgb(AHex, R, G, B);
  Result := 0.2126 * Ch(R) + 0.7152 * Ch(G) + 0.0722 * Ch(B);
end;

function ContrastRatio(const A, B: string): Double;
var
  L1, L2: Double;
begin
  L1 := Lum(A); L2 := Lum(B);
  if L1 < L2 then begin Result := L1; L1 := L2; L2 := Result; end;
  Result := (L1 + 0.05) / (L2 + 0.05);
end;

function Dist(const A, B: string): Double;
var
  R1, G1, B1, R2, G2, B2: Integer;
begin
  SplitRgb(A, R1, G1, B1);
  SplitRgb(B, R2, G2, B2);
  Result := Sqrt(Sqr(R1 - R2) + Sqr(G1 - G2) + Sqr(B1 - B2));
end;

{ ---------------- oblik ---------------- }

procedure ApplyShape(var T: TaThemeTokens; AShape: TaShape);
begin
  T.Shape := AShape;
  T.ControlHeight := 28;
  case AShape of
    shSquare: begin T.RadiusButton := 2; T.RadiusField := 2; T.RadiusCard := 2; end;
    shRounded: begin T.RadiusButton := 6; T.RadiusField := 5; T.RadiusCard := 8; end;
  else
    begin T.RadiusButton := T.ControlHeight div 2 - 1; T.RadiusField := T.ControlHeight div 2 - 3; T.RadiusCard := 8; end;
  end;
end;

{ ---------------- izvodenje teme ---------------- }

procedure FillNeutrals(var T: TaThemeTokens);
begin
  if not T.Dark then
  begin
    T.Bg := '#F1F5F9'; T.Surface := '#FFFFFF'; T.Soft := '#F8FAFC'; T.Header := '#E2E8F0';
    T.Border := '#CBD5E1'; T.Text := '#0F172A'; T.TextSoft := '#64748B'; T.Tip := '#1E293B';
    T.Success := '#16A34A'; T.Warning := '#D97706'; T.Danger := '#DC2626'; T.DangerSoft := '#FEE2E2';
  end
  else
  begin
    T.Bg := '#0F172A'; T.Surface := '#111827'; T.Soft := '#1E293B'; T.Header := '#1E293B';
    T.Border := '#334155'; T.Text := '#E2E8F0'; T.TextSoft := '#94A3B8'; T.Tip := '#334155';
    T.Success := '#4ADE80'; T.Warning := '#FBBF24'; T.Danger := '#F87171'; T.DangerSoft := '#4C1D1D';
  end;
end;

function PickOnAccent(const AAccent: string): string;
begin
  if ContrastRatio(AAccent, '#FFFFFF') >= ContrastRatio(AAccent, '#0F172A') then Result := '#FFFFFF'
  else Result := '#0F172A';
end;

procedure FillChart(var T: TaThemeTokens);
var
  I, N: Integer;
  C: string;
begin
  T.Chart[0] := T.Accent;
  N := 1;
  for I := 0 to High(BaseChart) do
  begin
    if N > 7 then Break;
    C := BaseChart[I];
    if T.Dark then C := MixHex(C, '#FFFFFF', 0.25);
    { preskoci boju koja je skoro jednaka naglasku (ne bi se razlikovala od prve serije) }
    if Dist(C, T.Accent) < 70 then Continue;
    T.Chart[N] := C;
    Inc(N);
  end;
  while N <= 7 do
  begin
    if T.Dark then T.Chart[N] := MixHex(T.Accent, '#FFFFFF', 0.3 + 0.05 * N)
    else T.Chart[N] := MixHex(T.Accent, '#000000', 0.3 + 0.05 * N);
    Inc(N);
  end;
end;

function DeriveTokens(const AName, AAccent: string; ADark: Boolean; AShape: TaShape): TaThemeTokens;
var
  Base: string;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.Name := AName;
  Result.Dark := ADark;
  Result.FontFamily := DefaultFontFamily;
  Result.FontSize := DefaultFontSize;
  FillNeutrals(Result);
  Base := AAccent;
  if not IsHexColor(Base) then Base := BuiltinAccent[0];
  if not ADark then
  begin
    Result.Accent := Base;
    Result.AccentSoft := MixHex(Base, '#FFFFFF', 0.86);
    Result.AccentHover := MixHex(Base, '#000000', 0.12);
  end
  else
  begin
    Result.Accent := MixHex(Base, '#FFFFFF', 0.40);
    Result.AccentSoft := MixHex(Result.Bg, Base, 0.35);
    Result.AccentHover := MixHex(Result.Accent, '#FFFFFF', 0.12);
  end;
  Result.OnAccent := PickOnAccent(Result.Accent);
  { greska ne smije izgledati kao naglasak: u crvenoj temi uzima se tamnija crvena }
  if Dist(Result.Accent, Result.Danger) < 90 then
  begin
    if ADark then Result.Danger := '#FCA5A5' else Result.Danger := '#991B1B';
  end;
  ApplyShape(Result, AShape);
  FillChart(Result);
end;

function BuiltinThemeCount: Integer;
begin
  Result := Length(BuiltinNames);
end;

function BuiltinThemeName(AIndex: Integer): string;
begin
  if (AIndex >= 0) and (AIndex <= High(BuiltinNames)) then Result := BuiltinNames[AIndex] else Result := '';
end;

function BuiltinThemeIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(BuiltinNames) do
    if SameText(BuiltinNames[I], AName) then Exit(I);
  Result := -1;
end;

function BuiltinTokens(AIndex: Integer; ADark: Boolean; AShape: TaShape): TaThemeTokens;
begin
  if (AIndex < 0) or (AIndex > High(BuiltinNames)) then AIndex := 0;
  Result := DeriveTokens(BuiltinNames[AIndex], BuiltinAccent[AIndex], ADark, AShape);
  if AIndex = 0 then
  begin
    { Plava: tocne vrijednosti iz plana (poglavlje 6.2), ista kao dosadasnja tema }
    if not ADark then
    begin
      Result.Accent := '#2563EB'; Result.AccentSoft := '#DBEAFE'; Result.AccentHover := '#1D4ED8';
    end
    else
    begin
      Result.Accent := '#60A5FA'; Result.AccentSoft := '#1E3A5F'; Result.AccentHover := '#93C5FD';
    end;
    Result.OnAccent := PickOnAccent(Result.Accent);
    FillChart(Result);
  end
  else if AIndex = 5 then
  begin
    { Grafit: neutralan, naglasak je sivo-plava; tamna varijanta svjetlija }
    if ADark then
    begin
      Result.Accent := '#94A3B8'; Result.AccentSoft := '#334155'; Result.AccentHover := '#CBD5E1';
      Result.OnAccent := PickOnAccent(Result.Accent);
      FillChart(Result);
    end;
  end;
end;

function ValidateTokens(const T: TaThemeTokens): string;
var
  Cols: array[0..16] of string;
  Names: array[0..16] of string;
  I: Integer;
begin
  Result := '';
  Cols[0] := T.Accent; Names[0] := 'accent';
  Cols[1] := T.AccentSoft; Names[1] := 'accentSoft';
  Cols[2] := T.AccentHover; Names[2] := 'accentHover';
  Cols[3] := T.OnAccent; Names[3] := 'onAccent';
  Cols[4] := T.Bg; Names[4] := 'bg';
  Cols[5] := T.Surface; Names[5] := 'surface';
  Cols[6] := T.Soft; Names[6] := 'soft';
  Cols[7] := T.Header; Names[7] := 'header';
  Cols[8] := T.Border; Names[8] := 'border';
  Cols[9] := T.Text; Names[9] := 'text';
  Cols[10] := T.TextSoft; Names[10] := 'textSoft';
  Cols[11] := T.Tip; Names[11] := 'tip';
  Cols[12] := T.Success; Names[12] := 'success';
  Cols[13] := T.Warning; Names[13] := 'warning';
  Cols[14] := T.Danger; Names[14] := 'danger';
  Cols[15] := T.DangerSoft; Names[15] := 'dangerSoft';
  Cols[16] := T.Chart[0]; Names[16] := 'chart0';
  for I := 0 to High(Cols) do
    if not IsHexColor(Cols[I]) then Exit('Neispravna boja za "' + Names[I] + '": ' + Cols[I]);
  if ContrastRatio(T.Accent, T.OnAccent) < 4.5 then
    Exit('Kontrast teksta na naglasku je premali (' + FormatFloat('0.0', ContrastRatio(T.Accent, T.OnAccent)) + ':1, najmanje 4.5:1)');
  if ContrastRatio(T.Surface, T.Text) < 4.5 then
    Exit('Kontrast teksta na plohi je premali');
end;

{ ---------------- JSON ---------------- }

function ShapeFromName(const S: string; ADefault: TaShape): TaShape;
var
  I: TaShape;
begin
  for I := Low(TaShape) to High(TaShape) do
    if SameText(ShapeNames[I], S) then Exit(I);
  Result := ADefault;
end;

function TokensToJson(const T: TaThemeTokens): string;
var
  O, Tk: TJSONObject;
  Ch: TJSONArray;
  I: Integer;
begin
  O := TJSONObject.Create;
  try
    O.Add('name', T.Name);
    O.Add('accent', T.Accent);
    O.Add('shape', ShapeNames[T.Shape]);
    O.Add('dark', T.Dark);
    Tk := TJSONObject.Create;
    Tk.Add('accent', T.Accent); Tk.Add('accentSoft', T.AccentSoft); Tk.Add('accentHover', T.AccentHover); Tk.Add('onAccent', T.OnAccent);
    Tk.Add('bg', T.Bg); Tk.Add('surface', T.Surface); Tk.Add('soft', T.Soft); Tk.Add('header', T.Header);
    Tk.Add('border', T.Border); Tk.Add('text', T.Text); Tk.Add('textSoft', T.TextSoft); Tk.Add('tip', T.Tip);
    Tk.Add('success', T.Success); Tk.Add('warning', T.Warning); Tk.Add('danger', T.Danger); Tk.Add('dangerSoft', T.DangerSoft);
    Tk.Add('radiusButton', T.RadiusButton); Tk.Add('radiusField', T.RadiusField); Tk.Add('radiusCard', T.RadiusCard);
    Tk.Add('controlHeight', T.ControlHeight); Tk.Add('fontFamily', T.FontFamily); Tk.Add('fontSize', T.FontSize);
    Ch := TJSONArray.Create;
    for I := 0 to 7 do Ch.Add(T.Chart[I]);
    Tk.Add('chart', Ch);
    O.Add('tokens', Tk);
    Result := O.FormatJSON;
  finally
    O.Free;
  end;
end;

function TokensFromJson(const AJson: string; out T: TaThemeTokens; out AWarn: string): Boolean;
var
  D: TJSONData;
  O, Tk: TJSONObject;
  I: Integer;
  K, V: string;
  Known: string;
  Idx: Integer;
begin
  Result := False;
  AWarn := '';
  FillChar(T, SizeOf(T), 0);
  try
    D := GetJSON(AJson);
  except
    on E: Exception do begin AWarn := 'Neispravan JSON: ' + E.Message; Exit; end;
  end;
  try
    if not (D is TJSONObject) then begin AWarn := 'Tema mora biti JSON objekt'; Exit; end;
    O := TJSONObject(D);
    if O.Find('accent') = nil then begin AWarn := 'Nedostaje "accent"'; Exit; end;
    V := O.Get('accent', '');
    if not IsHexColor(V) then begin AWarn := 'Naglasak nije boja oblika #RRGGBB: ' + V; Exit; end;
    T := DeriveTokens(O.Get('name', 'Vlastita'), V, O.Get('dark', False),
      ShapeFromName(O.Get('shape', 'rounded'), shRounded));
    Known := ',name,accent,shape,dark,tokens,';
    for I := 0 to O.Count - 1 do
      if Pos(',' + O.Names[I] + ',', Known) = 0 then
        AWarn := AWarn + 'Nepoznati kljuc "' + O.Names[I] + '"; ';
    if O.Find('tokens') is TJSONObject then
    begin
      Tk := TJSONObject(O.Find('tokens'));
      for I := 0 to Tk.Count - 1 do
      begin
        K := Tk.Names[I];
        Idx := 0;
        if Tk.Items[I].JSONType = jtString then V := Tk.Items[I].AsString else V := '';
        if K = 'accent' then T.Accent := V
        else if K = 'accentSoft' then T.AccentSoft := V
        else if K = 'accentHover' then T.AccentHover := V
        else if K = 'onAccent' then T.OnAccent := V
        else if K = 'bg' then T.Bg := V
        else if K = 'surface' then T.Surface := V
        else if K = 'soft' then T.Soft := V
        else if K = 'header' then T.Header := V
        else if K = 'border' then T.Border := V
        else if K = 'text' then T.Text := V
        else if K = 'textSoft' then T.TextSoft := V
        else if K = 'tip' then T.Tip := V
        else if K = 'success' then T.Success := V
        else if K = 'warning' then T.Warning := V
        else if K = 'danger' then T.Danger := V
        else if K = 'dangerSoft' then T.DangerSoft := V
        else if K = 'radiusButton' then T.RadiusButton := Tk.Items[I].AsInteger
        else if K = 'radiusField' then T.RadiusField := Tk.Items[I].AsInteger
        else if K = 'radiusCard' then T.RadiusCard := Tk.Items[I].AsInteger
        else if K = 'controlHeight' then T.ControlHeight := Tk.Items[I].AsInteger
        else if K = 'fontFamily' then T.FontFamily := V
        else if K = 'fontSize' then T.FontSize := Tk.Items[I].AsInteger
        else if (K = 'chart') and (Tk.Items[I] is TJSONArray) then
        begin
          for Idx := 0 to Min(7, TJSONArray(Tk.Items[I]).Count - 1) do
            T.Chart[Idx] := TJSONArray(Tk.Items[I]).Strings[Idx];
        end
        else AWarn := AWarn + 'Nepoznati token "' + K + '"; ';
      end;
    end;
    V := ValidateTokens(T);
    if V <> '' then begin AWarn := V; Exit; end;
    Result := True;
  finally
    D.Free;
  end;
end;

function LoadThemeFile(const AFile: string; out T: TaThemeTokens; out AWarn: string): Boolean;
var
  L: TStringList;
begin
  FillChar(T, SizeOf(T), 0);
  if not FileExists(AFile) then begin AWarn := 'Datoteka ne postoji: ' + AFile; Exit(False); end;
  L := TStringList.Create;
  try
    L.LoadFromFile(AFile);
    Result := TokensFromJson(L.Text, T, AWarn);
  finally
    L.Free;
  end;
end;

procedure SaveThemeFile(const AFile: string; const T: TaThemeTokens);
var
  L: TStringList;
begin
  L := TStringList.Create;
  try
    L.Text := TokensToJson(T);
    L.SaveToFile(AFile);
  finally
    L.Free;
  end;
end;

{ ---------------- aktivna tema ---------------- }

procedure ApplyThemeFont(AFont: TFont);
var
  T: TaThemeTokens;
begin
  T := ActiveTokens;
  if T.FontFamily <> '' then AFont.Name := T.FontFamily;
  if T.FontSize > 0 then AFont.Size := T.FontSize;
end;

function ActiveTokens: TaThemeTokens;
begin
  if not GActiveSet then
  begin
    GActive := BuiltinTokens(0, False, shRounded);
    GActiveSet := True;
  end;
  Result := GActive;
end;

procedure SetActiveTokens(const T: TaThemeTokens);
var
  I: Integer;
begin
  GActive := T;
  GActiveSet := True;
  for I := 0 to High(GListeners) do
    if Assigned(GListeners[I]) then GListeners[I](nil);
end;

procedure AddTokensListener(AListener: TNotifyEvent);
begin
  SetLength(GListeners, Length(GListeners) + 1);
  GListeners[High(GListeners)] := AListener;
end;

procedure RemoveTokensListener(AListener: TNotifyEvent);
var
  I, J: Integer;
begin
  for I := High(GListeners) downto 0 do
    if (TMethod(GListeners[I]).Code = TMethod(AListener).Code) and (TMethod(GListeners[I]).Data = TMethod(AListener).Data) then
    begin
      for J := I to High(GListeners) - 1 do GListeners[J] := GListeners[J + 1];
      SetLength(GListeners, Length(GListeners) - 1);
    end;
end;

function ActiveChartColor(AIndex: Integer): TColor;
begin
  Result := TokenColor(ActiveTokens.Chart[((AIndex mod 8) + 8) mod 8]);
end;

function ThemeFontDirs(const AExtraDir: string = ''): TStringList;
var
  Exe: string;
begin
  Result := TStringList.Create;
  Exe := ExtractFilePath(ParamStr(0));
  if AExtraDir <> '' then Result.Add(IncludeTrailingPathDelimiter(AExtraDir));
  Result.Add(Exe + 'fonts' + PathDelim);
  Result.Add(Exe + '..' + PathDelim + 'fonts' + PathDelim);
  Result.Add(Exe + '..' + PathDelim + '..' + PathDelim + 'LightPalette' + PathDelim + 'fonts' + PathDelim);
  Result.Add('/usr/share/fonts/truetype/JetBrainsMono/');
end;

function FindThemeFontFile(const AFileName: string): string;
var
  L: TStringList;
  I: Integer;
begin
  Result := '';
  L := ThemeFontDirs;
  try
    for I := 0 to L.Count - 1 do
      if FileExists(L[I] + AFileName) then Exit(L[I] + AFileName);
  finally
    L.Free;
  end;
end;

function EditorPalette(const T: TaThemeTokens): TaEditorPalette;
begin
  Result.Background := T.Surface;
  Result.Text := T.Text;
  Result.Identifier := T.Text;
  Result.Keyword := T.Accent;
  Result.StringLit := T.Success;
  Result.Number := T.Warning;
  Result.Comment := T.TextSoft;
  Result.Symbol := MixHex(T.Text, T.Accent, 0.4);
  Result.Error := T.Danger;
  Result.CurrentLine := MixHex(T.Surface, T.AccentSoft, 0.3);
  Result.Selection := T.AccentSoft;
  Result.GutterBg := T.Soft;
  Result.GutterText := T.TextSoft;
  Result.Bracket := T.AccentSoft;
end;

function ChartPalette(const T: TaThemeTokens): TaChartPalette;
var
  I: Integer;
begin
  Result.Background := T.Surface;
  Result.Axis := T.TextSoft;
  Result.Grid := T.Border;
  Result.Text := T.Text;
  Result.Legend := T.Text;
  for I := 0 to 7 do Result.Series[I] := T.Chart[I];
end;

end.
