unit ta_richtext;
{ Formatirani tekst u bazi: mali podskup HTML-a u obicnom tekstnom polju.
  Oznake: <p align="left|center|right" list="1"> (odlomak, list=1 je natuknica), <b> <i> <u>,
  <font color="#rrggbb" size="pt">, <br>. Znakovi < > & u tekstu su &lt; &gt; &amp;.
  Tekst bez oznaka (stari obicni tekst) cita se kao odlomci razdvojeni novim retkom.
  Isti model sluzi uredjivacu na formi i ispisu u izvjescu i dopisu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, Graphics;

type
  TRtAlign = (raLeft, raCenter, raRight);

  TRtRun = record
    Text: string;
    Bold, Italic, Underline: Boolean;
    Color: Integer;       { RGB kao $RRGGBB; -1 = zadana boja }
    SizePt: Integer;      { 0 = zadana velicina }
  end;

  TRtPara = class
  public
    Align: TRtAlign;
    Bullet: Boolean;
    Runs: array of TRtRun;
    procedure AddRun(const ARun: TRtRun);
    function PlainText: string;
  end;

  TRtDoc = class
  private
    FParas: TList;
    function GetCount: Integer;
    function GetPara(I: Integer): TRtPara;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    function AddPara: TRtPara;
    procedure LoadHtml(const AHtml: string);
    function ToHtml: string;
    function PlainText: string;
    property Count: Integer read GetCount;
    property Paras[I: Integer]: TRtPara read GetPara; default;
  end;

  { jedan smjesteni dio retka: tekst jednog stila na polozaju X unutar retka }
  TRtSeg = record
    X, W: Integer;
    Text: string;
    Bold, Italic, Underline: Boolean;
    Color: Integer;
    Px: Integer;
  end;

  TRtLine = record
    Y, H: Integer;
    Segs: array of TRtSeg;
  end;

  TRtLayout = record
    Lines: array of TRtLine;
    Height: Integer;
  end;

const
  RtFontName = 'DejaVu Sans';

{ obicni tekst -> HTML (znakovi se escapiraju, novi redak = novi odlomak) }
function RtFromPlain(const AText: string): string;
{ HTML -> obicni tekst (za pretrage, popise, izvoz) }
function RtToPlain(const AHtml: string): string;
{ je li tekst u ovom zapisu (ima nase oznake) }
function RtLooksRich(const AText: string): Boolean;
{ slaze odlomke u zadanu sirinu (px); ADefaultPx = zadana velicina fonta u px }
function RtLayoutDoc(ADoc: TRtDoc; AWidth, ADefaultPx: Integer; ADefaultColor: Integer): TRtLayout;

implementation

procedure TRtPara.AddRun(const ARun: TRtRun);
begin
  if ARun.Text = '' then Exit;
  SetLength(Runs, Length(Runs) + 1);
  Runs[High(Runs)] := ARun;
end;

function TRtPara.PlainText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(Runs) do Result := Result + Runs[I].Text;
end;

constructor TRtDoc.Create;
begin
  FParas := TList.Create;
end;

destructor TRtDoc.Destroy;
begin
  Clear;
  FParas.Free;
  inherited Destroy;
end;

procedure TRtDoc.Clear;
var
  I: Integer;
begin
  for I := 0 to FParas.Count - 1 do TRtPara(FParas[I]).Free;
  FParas.Clear;
end;

function TRtDoc.GetCount: Integer;
begin
  Result := FParas.Count;
end;

function TRtDoc.GetPara(I: Integer): TRtPara;
begin
  Result := TRtPara(FParas[I]);
end;

function TRtDoc.AddPara: TRtPara;
begin
  Result := TRtPara.Create;
  Result.Align := raLeft;
  FParas.Add(Result);
end;

{ ---------------- escapiranje ---------------- }

function Esc(const S: string): string;
begin
  Result := StringReplace(S, '&', '&amp;', [rfReplaceAll]);
  Result := StringReplace(Result, '<', '&lt;', [rfReplaceAll]);
  Result := StringReplace(Result, '>', '&gt;', [rfReplaceAll]);
end;

function Unesc(const S: string): string;
begin
  Result := StringReplace(S, '&nbsp;', ' ', [rfReplaceAll]);
  Result := StringReplace(Result, '&lt;', '<', [rfReplaceAll]);
  Result := StringReplace(Result, '&gt;', '>', [rfReplaceAll]);
  Result := StringReplace(Result, '&quot;', '"', [rfReplaceAll]);
  Result := StringReplace(Result, '&amp;', '&', [rfReplaceAll]);
end;

function RtLooksRich(const AText: string): Boolean;
begin
  Result := (Pos('<p', AText) > 0) or (Pos('<b>', AText) > 0) or (Pos('<font', AText) > 0) or (Pos('<i>', AText) > 0) or (Pos('<u>', AText) > 0);
end;

function RtFromPlain(const AText: string): string;
var
  L: TStringList;
  I: Integer;
begin
  L := TStringList.Create;
  try
    L.Text := AText;
    Result := '';
    for I := 0 to L.Count - 1 do Result := Result + '<p>' + Esc(L[I]) + '</p>';
    if Result = '' then Result := '<p></p>';
  finally
    L.Free;
  end;
end;

{ ---------------- citanje ---------------- }

function AttrOf(const ATag, AName: string): string;
var
  P, Q: Integer;
  T: string;
begin
  Result := '';
  T := LowerCase(ATag);
  P := Pos(' ' + AName + '=', T);
  if P = 0 then Exit;
  Inc(P, Length(AName) + 2);
  if (P <= Length(ATag)) and (ATag[P] in ['"', '''']) then
  begin
    Q := PosEx(ATag[P], ATag, P + 1);
    Result := Copy(ATag, P + 1, Q - P - 1);
  end
  else
  begin
    Q := P;
    while (Q <= Length(ATag)) and not (ATag[Q] in [' ', '>']) do Inc(Q);
    Result := Copy(ATag, P, Q - P);
  end;
end;

procedure TRtDoc.LoadHtml(const AHtml: string);
var
  I, J: Integer;
  S, Tag, Name, Buf: string;
  Cur: TRtPara;
  St: TRtRun;
  Stack: array of TRtRun;
  Closing: Boolean;

  procedure Flush;
  var
    R: TRtRun;
  begin
    if Buf = '' then Exit;
    R := St;
    R.Text := Unesc(Buf);
    Buf := '';
    if Cur = nil then Cur := AddPara;
    Cur.AddRun(R);
  end;

  procedure Push;
  begin
    SetLength(Stack, Length(Stack) + 1);
    Stack[High(Stack)] := St;
  end;

  procedure Pop;
  begin
    if Length(Stack) > 0 then
    begin
      St := Stack[High(Stack)];
      SetLength(Stack, Length(Stack) - 1);
    end;
  end;

  function ParseColor(const V: string): Integer;
  var
    H: string;
    N: Integer;
  begin
    H := Trim(V);
    if (H <> '') and (H[1] = '#') then Delete(H, 1, 1);
    N := StrToIntDef('$' + H, -1);
    Result := N;
  end;

begin
  Clear;
  S := AHtml;
  if not RtLooksRich(S) then
  begin
    { stari obicni tekst }
    S := RtFromPlain(S);
  end;
  Cur := nil;
  Buf := '';
  FillChar(St, SizeOf(St), 0);
  St.Color := -1;
  SetLength(Stack, 0);
  I := 1;
  while I <= Length(S) do
  begin
    if S[I] = '<' then
    begin
      J := I;
      while (J <= Length(S)) and (S[J] <> '>') do Inc(J);
      Tag := Copy(S, I + 1, J - I - 1);
      I := J + 1;
      Closing := (Tag <> '') and (Tag[1] = '/');
      if Closing then Delete(Tag, 1, 1);
      Name := LowerCase(Tag);
      J := 1;
      while (J <= Length(Name)) and not (Name[J] in [' ', '/']) do Inc(J);
      Name := Copy(Name, 1, J - 1);
      if Name = 'p' then
      begin
        Flush;
        if Closing then Cur := nil
        else
        begin
          Cur := AddPara;
          if AttrOf(' ' + Tag, 'align') = 'center' then Cur.Align := raCenter
          else if AttrOf(' ' + Tag, 'align') = 'right' then Cur.Align := raRight;
          Cur.Bullet := AttrOf(' ' + Tag, 'list') = '1';
        end;
      end
      else if Name = 'br' then
      begin
        Flush;
        Cur := nil;
      end
      else if (Name = 'b') or (Name = 'i') or (Name = 'u') or (Name = 'font') then
      begin
        Flush;
        if Closing then Pop
        else
        begin
          Push;
          if Name = 'b' then St.Bold := True
          else if Name = 'i' then St.Italic := True
          else if Name = 'u' then St.Underline := True
          else
          begin
            if AttrOf(' ' + Tag, 'color') <> '' then St.Color := ParseColor(AttrOf(' ' + Tag, 'color'));
            if AttrOf(' ' + Tag, 'size') <> '' then St.SizePt := StrToIntDef(AttrOf(' ' + Tag, 'size'), 0);
          end;
        end;
      end;
    end
    else
    begin
      if (S[I] = #10) or (S[I] = #13) then begin Inc(I); Continue; end;
      Buf := Buf + S[I];
      Inc(I);
    end;
  end;
  Flush;
  if Count = 0 then AddPara;
end;

{ ---------------- pisanje ---------------- }

function TRtDoc.ToHtml: string;
var
  I, J: Integer;
  P: TRtPara;
  R: TRtRun;
  T, Pre, Post: string;
begin
  Result := '';
  for I := 0 to Count - 1 do
  begin
    P := Paras[I];
    T := '<p';
    case P.Align of
      raCenter: T := T + ' align="center"';
      raRight: T := T + ' align="right"';
    end;
    if P.Bullet then T := T + ' list="1"';
    Result := Result + T + '>';
    for J := 0 to High(P.Runs) do
    begin
      R := P.Runs[J];
      Pre := ''; Post := '';
      if R.Bold then begin Pre := Pre + '<b>'; Post := '</b>' + Post; end;
      if R.Italic then begin Pre := Pre + '<i>'; Post := '</i>' + Post; end;
      if R.Underline then begin Pre := Pre + '<u>'; Post := '</u>' + Post; end;
      if (R.Color >= 0) or (R.SizePt > 0) then
      begin
        Pre := Pre + '<font';
        if R.Color >= 0 then Pre := Pre + ' color="#' + LowerCase(IntToHex(R.Color and $FFFFFF, 6)) + '"';
        if R.SizePt > 0 then Pre := Pre + ' size="' + IntToStr(R.SizePt) + '"';
        Pre := Pre + '>';
        Post := '</font>' + Post;
      end;
      Result := Result + Pre + Esc(R.Text) + Post;
    end;
    Result := Result + '</p>';
  end;
end;

function TRtDoc.PlainText: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Count - 1 do
  begin
    if I > 0 then Result := Result + LineEnding;
    if Paras[I].Bullet then Result := Result + '- ';
    Result := Result + Paras[I].PlainText;
  end;
end;

function RtToPlain(const AHtml: string): string;
var
  D: TRtDoc;
begin
  D := TRtDoc.Create;
  try
    D.LoadHtml(AHtml);
    Result := D.PlainText;
  finally
    D.Free;
  end;
end;

{ ---------------- slaganje ---------------- }

type
  TWord = record
    Text: string;
    Bold, Italic, Underline: Boolean;
    Color, Px, W: Integer;
    SpaceAfter: Boolean;
  end;

function RtLayoutDoc(ADoc: TRtDoc; AWidth, ADefaultPx: Integer; ADefaultColor: Integer): TRtLayout;
var
  Bmp: TBitmap;
  Words: array of TWord;
  I, J, K, N, LineStart, X, Y, Indent, Avail, LineH, SpW, TotalW: Integer;
  P: TRtPara;
  R: TRtRun;
  Px: Integer;
  Cur: string;
  Wd: TWord;
  Line: TRtLine;

  function MeasureW(const S: string; ABold, AItalic: Boolean; APx: Integer): Integer;
  begin
    with Bmp.Canvas do
    begin
      Font.Name := RtFontName;
      Font.Height := -APx;
      Font.Style := [];
      if ABold then Font.Style := Font.Style + [fsBold];
      if AItalic then Font.Style := Font.Style + [fsItalic];
      Result := TextWidth(S);
    end;
  end;

  procedure AddWord(const AText: string; const ARun: TRtRun; ASpace: Boolean);
  begin
    SetLength(Words, Length(Words) + 1);
    with Words[High(Words)] do
    begin
      Text := AText;
      Bold := ARun.Bold; Italic := ARun.Italic; Underline := ARun.Underline;
      if ARun.Color >= 0 then Color := ARun.Color else Color := ADefaultColor;
      if ARun.SizePt > 0 then Px := Round(ARun.SizePt * 96 / 72) else Px := ADefaultPx;
      W := MeasureW(AText, ARun.Bold, ARun.Italic, Px);
      SpaceAfter := ASpace;
    end;
  end;

  procedure FlushLine(AEnd: Integer; AAlign: TRtAlign; const AInd: Integer; ABullet: Boolean; AFirst: Boolean);
  var
    A, B, Lx, Mx: Integer;
    S: TRtSeg;
  begin
    if AEnd < LineStart then Exit;
    LineH := 0;
    TotalW := 0;
    for A := LineStart to AEnd do
    begin
      if Words[A].Px * 13 div 10 > LineH then LineH := Words[A].Px * 13 div 10;
      Inc(TotalW, Words[A].W);
      if (A < AEnd) and Words[A].SpaceAfter then Inc(TotalW, MeasureW(' ', Words[A].Bold, Words[A].Italic, Words[A].Px));
    end;
    if LineH = 0 then LineH := ADefaultPx * 13 div 10;
    Line.Y := Y;
    Line.H := LineH;
    SetLength(Line.Segs, 0);
    Lx := AInd;
    case AAlign of
      raCenter: Lx := AInd + (AWidth - AInd - TotalW) div 2;
      raRight: Lx := AWidth - TotalW;
    end;
    if Lx < AInd then Lx := AInd;
    if ABullet and AFirst then
    begin
      S.X := 0; S.W := AInd; S.Text := #$E2#$80#$A2;
      S.Bold := False; S.Italic := False; S.Underline := False; S.Color := ADefaultColor; S.Px := ADefaultPx;
      SetLength(Line.Segs, 1);
      Line.Segs[0] := S;
    end;
    Mx := Lx;
    for A := LineStart to AEnd do
    begin
      S.X := Mx; S.W := Words[A].W; S.Text := Words[A].Text;
      S.Bold := Words[A].Bold; S.Italic := Words[A].Italic; S.Underline := Words[A].Underline;
      S.Color := Words[A].Color; S.Px := Words[A].Px;
      B := Length(Line.Segs);
      SetLength(Line.Segs, B + 1);
      Line.Segs[B] := S;
      Inc(Mx, Words[A].W);
      if (A < AEnd) and Words[A].SpaceAfter then Inc(Mx, MeasureW(' ', Words[A].Bold, Words[A].Italic, Words[A].Px));
    end;
    SetLength(Result.Lines, Length(Result.Lines) + 1);
    Result.Lines[High(Result.Lines)] := Line;
    Inc(Y, LineH);
  end;

begin
  SetLength(Result.Lines, 0);
  Result.Height := 0;
  if AWidth < 20 then Exit;
  Bmp := TBitmap.Create;
  try
    Y := 0;
    for I := 0 to ADoc.Count - 1 do
    begin
      P := ADoc[I];
      SetLength(Words, 0);
      for J := 0 to High(P.Runs) do
      begin
        R := P.Runs[J];
        Cur := '';
        K := 1;
        N := Length(R.Text);
        while K <= N do
        begin
          if R.Text[K] = ' ' then
          begin
            if Cur <> '' then begin AddWord(Cur, R, True); Cur := ''; end
            else if Length(Words) > 0 then Words[High(Words)].SpaceAfter := True;
          end
          else Cur := Cur + R.Text[K];
          Inc(K);
        end;
        if Cur <> '' then AddWord(Cur, R, False);
      end;
      Indent := 0;
      if P.Bullet then Indent := ADefaultPx * 3 div 2;
      if Length(Words) = 0 then
      begin
        { prazan odlomak = prazan redak }
        LineStart := 0;
        SetLength(Result.Lines, Length(Result.Lines) + 1);
        Result.Lines[High(Result.Lines)].Y := Y;
        Result.Lines[High(Result.Lines)].H := ADefaultPx * 13 div 10;
        SetLength(Result.Lines[High(Result.Lines)].Segs, 0);
        Inc(Y, ADefaultPx * 13 div 10);
        Continue;
      end;
      Avail := AWidth - Indent;
      LineStart := 0;
      X := 0;
      for K := 0 to High(Words) do
      begin
        Wd := Words[K];
        SpW := 0;
        if (K > LineStart) and Words[K - 1].SpaceAfter then SpW := MeasureW(' ', Words[K - 1].Bold, Words[K - 1].Italic, Words[K - 1].Px);
        if (K > LineStart) and (X + SpW + Wd.W > Avail) then
        begin
          FlushLine(K - 1, P.Align, Indent, P.Bullet, LineStart = 0);
          LineStart := K;
          X := Wd.W;
        end
        else Inc(X, SpW + Wd.W);
      end;
      FlushLine(High(Words), P.Align, Indent, P.Bullet, LineStart = 0);
    end;
    Result.Height := Y;
  finally
    Bmp.Free;
  end;
end;

end.
