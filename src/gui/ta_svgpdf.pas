unit ta_svgpdf;
{ Pravi vektor u PDF-u: SVG (putanje, oblici, grupe, transformacije, use) pretvara se u PDF naredbe za crtanje,
  pa slika ostaje oštra na svakoj veličini i mala. Što nije podržano (gradijenti, tekst, isjecanje, filtri, CSS,
  crtkane linije, ugrađene slike) vraca False prije nego se išta nacrta; pozivatelj tada koristi sliku visoke razlučivosti. }

{$mode objfpc}{$H+}

interface

uses
  fppdf;

{ crta SVG u kutiju (X, Y, W, H) u jedinicama stranice (mm, ishodište gore lijevo kao u izvozu izvješća);
  AStretch = rastegni na cijelu kutiju, inace se cuva omjer i slika se centrira }
function PdfDrawSvg(APage: TPDFPage; const ASvg: string; X, Y, W, H: Double; AStretch: Boolean): Boolean;

implementation

uses
  Classes, SysUtils, Math, DOM, XMLRead;

type
  TMat = record A, B, C, D, E, F: Double; end;

  TStyle = record
    Fill, Stroke: Integer;        { -1 = nema, inace $RRGGBB }
    StrokeW: Double;
    Cap, Join: Integer;
    EvenOdd: Boolean;
    Mat: TMat;
  end;

  TPoint2 = record X, Y: Double; end;

  TDrawer = class
    Page: TPDFPage;
    Emit: Boolean;
    Failed: Boolean;
    Doc: TXMLDocument;
    Scale: Double;            { SVG jedinica -> mm (za debljinu crte) }
    procedure Fail;
    function FindById(const AId: string): TDOMElement;
    function Pt(const M: TMat; X, Y: Double): TPoint2;
    procedure Walk(N: TDOMNode; const S: TStyle; ADepth: Integer);
    procedure DrawPath(const D: string; const S: TStyle);
    procedure Paint(const S: TStyle);
  end;

var
  FS: TFormatSettings;

const
  IdentMat: TMat = (A: 1; B: 0; C: 0; D: 1; E: 0; F: 0);

function MatMul(const M1, M2: TMat): TMat;   { M1 primijenjen nakon M2: p' = M1 * (M2 * p) }
begin
  Result.A := M1.A * M2.A + M1.C * M2.B;
  Result.B := M1.B * M2.A + M1.D * M2.B;
  Result.C := M1.A * M2.C + M1.C * M2.D;
  Result.D := M1.B * M2.C + M1.D * M2.D;
  Result.E := M1.A * M2.E + M1.C * M2.F + M1.E;
  Result.F := M1.B * M2.E + M1.D * M2.F + M1.F;
end;

function Num(const S: string; ADef: Double): Double;
var
  T: string;
  Code: Integer;
  V: Double;
begin
  T := Trim(S);
  while (T <> '') and (T[Length(T)] in ['p', 'x', 't', 'm', '%']) do Delete(T, Length(T), 1);
  Val(T, V, Code);
  if (T = '') or (Code <> 0) then Result := ADef else Result := V;
end;

{ prvi broj iz niza vrijednosti odvojenih razmacima i zarezima }
function ParseNumbers(const S: string; out N: array of Double): Integer;
var
  I, J: Integer;
  T: string;
begin
  Result := 0;
  I := 1;
  while (I <= Length(S)) and (Result <= High(N)) do
  begin
    while (I <= Length(S)) and (S[I] in [' ', ',', #9, #10, #13]) do Inc(I);
    J := I;
    while (J <= Length(S)) and not (S[J] in [' ', ',', #9, #10, #13, ')']) do Inc(J);
    if J > I then
    begin
      T := Copy(S, I, J - I);
      N[Result] := Num(T, 0);
      Inc(Result);
    end;
    I := J + 1;
  end;
end;

function ParseTransform(const S: string; var AOk: Boolean): TMat;
var
  P, Q: Integer;
  Cmd, Args: string;
  V: array[0..5] of Double;
  N: Integer;
  T: TMat;
  Rad: Double;
begin
  Result := IdentMat;
  P := 1;
  while P <= Length(S) do
  begin
    while (P <= Length(S)) and (S[P] in [' ', ',', #9, #10, #13]) do Inc(P);
    Q := P;
    while (Q <= Length(S)) and (S[Q] <> '(') do Inc(Q);
    if Q > Length(S) then Break;
    Cmd := LowerCase(Trim(Copy(S, P, Q - P)));
    P := Q + 1;
    Q := P;
    while (Q <= Length(S)) and (S[Q] <> ')') do Inc(Q);
    Args := Copy(S, P, Q - P);
    P := Q + 1;
    FillChar(V, SizeOf(V), 0);
    N := ParseNumbers(Args, V);
    T := IdentMat;
    if Cmd = 'translate' then begin T.E := V[0]; if N > 1 then T.F := V[1]; end
    else if Cmd = 'scale' then begin T.A := V[0]; if N > 1 then T.D := V[1] else T.D := V[0]; end
    else if Cmd = 'matrix' then begin T.A := V[0]; T.B := V[1]; T.C := V[2]; T.D := V[3]; T.E := V[4]; T.F := V[5]; end
    else if Cmd = 'rotate' then
    begin
      Rad := V[0] * Pi / 180;
      T.A := Cos(Rad); T.B := Sin(Rad); T.C := -Sin(Rad); T.D := Cos(Rad);
      if N >= 3 then
      begin
        T.E := V[1] - T.A * V[1] - T.C * V[2];
        T.F := V[2] - T.B * V[1] - T.D * V[2];
      end;
    end
    else if Cmd = 'skewx' then T.C := Tan(V[0] * Pi / 180)
    else if Cmd = 'skewy' then T.B := Tan(V[0] * Pi / 180)
    else AOk := False;
    Result := MatMul(Result, T);
  end;
end;

{ boja: -1 = none, -2 = nije prepoznata/nepodrzana, inace $RRGGBB }
function ParseColor(const AValue: string; ACurrent: Integer): Integer;
var
  S: string;
  V: array[0..2] of Double;
  I, N, Code: Integer;
  R, G, B: Integer;
  Pct: Boolean;
  Hex: string;
  function Ch(X: Double): Integer;
  begin
    if Pct then Result := Round(X * 255 / 100) else Result := Round(X);
    if Result < 0 then Result := 0;
    if Result > 255 then Result := 255;
  end;
begin
  S := LowerCase(Trim(AValue));
  if (S = '') or (S = 'inherit') then Exit(ACurrent);
  if (S = 'none') or (S = 'transparent') then Exit(-1);
  if S = 'currentcolor' then Exit(0);
  if Copy(S, 1, 4) = 'url(' then Exit(-2);
  if S[1] = '#' then
  begin
    Hex := Copy(S, 2, MaxInt);
    if Length(Hex) = 3 then Hex := Hex[1] + Hex[1] + Hex[2] + Hex[2] + Hex[3] + Hex[3];
    if Length(Hex) <> 6 then Exit(-2);
    Val('$' + Hex, I, Code);
    if Code <> 0 then Exit(-2);
    Exit(I);
  end;
  if Copy(S, 1, 4) = 'rgb(' then
  begin
    Pct := Pos('%', S) > 0;
    N := ParseNumbers(StringReplace(Copy(S, 5, MaxInt), '%', '', [rfReplaceAll]), V);
    if N < 3 then Exit(-2);
    R := Ch(V[0]); G := Ch(V[1]); B := Ch(V[2]);
    Exit((R shl 16) or (G shl 8) or B);
  end;
  if S = 'black' then Exit(0);
  if S = 'white' then Exit($FFFFFF);
  if S = 'red' then Exit($FF0000);
  if S = 'green' then Exit($008000);
  if S = 'blue' then Exit($0000FF);
  if S = 'yellow' then Exit($FFFF00);
  if (S = 'gray') or (S = 'grey') then Exit($808080);
  if S = 'orange' then Exit($FFA500);
  if S = 'silver' then Exit($C0C0C0);
  Result := -2;
end;

procedure TDrawer.Fail;
begin
  Failed := True;
end;

function TDrawer.Pt(const M: TMat; X, Y: Double): TPoint2;
begin
  Result.X := M.A * X + M.C * Y + M.E;
  Result.Y := M.B * X + M.D * Y + M.F;
end;

function TDrawer.FindById(const AId: string): TDOMElement;
  function Rec(N: TDOMNode): TDOMElement;
  var
    C: TDOMNode;
    R: TDOMElement;
  begin
    Result := nil;
    C := N.FirstChild;
    while C <> nil do
    begin
      if C.NodeType = ELEMENT_NODE then
      begin
        if TDOMElement(C).AttribStrings['id'] = AId then Exit(TDOMElement(C));
        R := Rec(C);
        if R <> nil then Exit(R);
      end;
      C := C.NextSibling;
    end;
  end;
begin
  Result := Rec(Doc.DocumentElement);
end;

procedure TDrawer.Paint(const S: TStyle);
var
  Op: string;
begin
  if (S.Fill < 0) and (S.Stroke < 0) then Op := 'n'
  else if (S.Fill >= 0) and (S.Stroke >= 0) then begin if S.EvenOdd then Op := 'B*' else Op := 'B'; end
  else if S.Fill >= 0 then begin if S.EvenOdd then Op := 'f*' else Op := 'f'; end
  else Op := 'S';
  if Emit then Page.AddObject(TPDFFreeFormString.Create(Page.Document, Op + #13#10));
end;

procedure TDrawer.DrawPath(const D: string; const S: TStyle);
var
  P: Integer;
  Cmd, Last: Char;
  Cx, Cy, Sx, Sy, Lx, Ly: Double;
  HaveCtrl: Boolean;
  Open: Boolean;
  Lw: Double;

  function SkipSep: Boolean;
  begin
    while (P <= Length(D)) and (D[P] in [' ', ',', #9, #10, #13]) do Inc(P);
    Result := P <= Length(D);
  end;

  function NextNum(out V: Double): Boolean;
  var
    Q: Integer;
    T: string;
    Code: Integer;
    SeenDot, SeenExp: Boolean;
  begin
    Result := False;
    if not SkipSep then Exit;
    Q := P;
    SeenDot := False; SeenExp := False;
    if D[Q] in ['+', '-'] then Inc(Q);
    while Q <= Length(D) do
    begin
      if D[Q] in ['0'..'9'] then Inc(Q)
      else if (D[Q] = '.') and not SeenDot and not SeenExp then begin SeenDot := True; Inc(Q); end
      else if (D[Q] in ['e', 'E']) and not SeenExp and (Q > P) then
      begin
        SeenExp := True; Inc(Q);
        if (Q <= Length(D)) and (D[Q] in ['+', '-']) then Inc(Q);
      end
      else Break;
    end;
    if Q = P then Exit;
    T := Copy(D, P, Q - P);
    Val(T, V, Code);
    if Code <> 0 then Exit;
    P := Q;
    Result := True;
  end;

  function NextFlag(out V: Integer): Boolean;
  begin
    Result := False;
    if not SkipSep then Exit;
    if D[P] in ['0', '1'] then begin V := Ord(D[P]) - 48; Inc(P); Result := True; end;
  end;

  procedure MoveAbs(X, Y: Double);
  var
    Q: TPoint2;
  begin
    Q := Pt(S.Mat, X, Y);
    if Emit then Page.MoveTo(Q.X, Q.Y);
    Cx := X; Cy := Y; Sx := X; Sy := Y; Open := True;
  end;

  procedure LineAbs(X, Y: Double);
  var
    Q: TPoint2;
  begin
    Q := Pt(S.Mat, X, Y);
    if Emit then Page.DrawLine(Q.X, Q.Y, Q.X, Q.Y, Lw, False);
    Cx := X; Cy := Y;
  end;

  procedure CurveAbs(X1, Y1, X2, Y2, X, Y: Double);
  var
    A, B, C: TPoint2;
  begin
    A := Pt(S.Mat, X1, Y1); B := Pt(S.Mat, X2, Y2); C := Pt(S.Mat, X, Y);
    if Emit then Page.CubicCurveTo(A.X, A.Y, B.X, B.Y, C.X, C.Y, Lw, False);
    Lx := X2; Ly := Y2; HaveCtrl := True;
    Cx := X; Cy := Y;
  end;

  procedure ArcAbs(Rx, Ry, Rot: Double; LargeArc, Sweep: Integer; X, Y: Double);
  var
    Phi, CosP, SinP, Dx, Dy, X1p, Y1p, Lam, Co, Num2, Den, Xc, Yc, Cxp, Cyp: Double;
    Th1, Dth, T, Seg, Alpha: Double;
    N, I: Integer;
    Ax, Ay, Bx, By: Double;
    function Ang(Ux, Uy, Vx, Vy: Double): Double;
    var
      Dot, Len: Double;
    begin
      Dot := Ux * Vx + Uy * Vy;
      Len := Sqrt((Ux * Ux + Uy * Uy) * (Vx * Vx + Vy * Vy));
      if Len = 0 then Exit(0);
      Result := ArcCos(Max(-1, Min(1, Dot / Len)));
      if Ux * Vy - Uy * Vx < 0 then Result := -Result;
    end;
  begin
    if (Rx = 0) or (Ry = 0) or ((Cx = X) and (Cy = Y)) then begin LineAbs(X, Y); Exit; end;
    Rx := Abs(Rx); Ry := Abs(Ry);
    Phi := Rot * Pi / 180; CosP := Cos(Phi); SinP := Sin(Phi);
    Dx := (Cx - X) / 2; Dy := (Cy - Y) / 2;
    X1p := CosP * Dx + SinP * Dy;
    Y1p := -SinP * Dx + CosP * Dy;
    Lam := Sqr(X1p) / Sqr(Rx) + Sqr(Y1p) / Sqr(Ry);
    if Lam > 1 then begin Rx := Rx * Sqrt(Lam); Ry := Ry * Sqrt(Lam); end;
    Num2 := Sqr(Rx) * Sqr(Ry) - Sqr(Rx) * Sqr(Y1p) - Sqr(Ry) * Sqr(X1p);
    Den := Sqr(Rx) * Sqr(Y1p) + Sqr(Ry) * Sqr(X1p);
    if Den = 0 then Co := 0 else Co := Sqrt(Max(0, Num2 / Den));
    if LargeArc = Sweep then Co := -Co;
    Cxp := Co * Rx * Y1p / Ry;
    Cyp := -Co * Ry * X1p / Rx;
    Xc := CosP * Cxp - SinP * Cyp + (Cx + X) / 2;
    Yc := SinP * Cxp + CosP * Cyp + (Cy + Y) / 2;
    Th1 := Ang(1, 0, (X1p - Cxp) / Rx, (Y1p - Cyp) / Ry);
    Dth := Ang((X1p - Cxp) / Rx, (Y1p - Cyp) / Ry, (-X1p - Cxp) / Rx, (-Y1p - Cyp) / Ry);
    if (Sweep = 0) and (Dth > 0) then Dth := Dth - 2 * Pi
    else if (Sweep = 1) and (Dth < 0) then Dth := Dth + 2 * Pi;
    N := Ceil(Abs(Dth) / (Pi / 2) - 1E-9);
    if N < 1 then N := 1;
    Seg := Dth / N;
    Alpha := 4 / 3 * Tan(Seg / 4);
    T := Th1;
    for I := 1 to N do
    begin
      Ax := Cos(T); Ay := Sin(T);
      Bx := Cos(T + Seg); By := Sin(T + Seg);
      CurveAbs(
        Xc + CosP * Rx * (Ax - Alpha * Ay) - SinP * Ry * (Ay + Alpha * Ax),
        Yc + SinP * Rx * (Ax - Alpha * Ay) + CosP * Ry * (Ay + Alpha * Ax),
        Xc + CosP * Rx * (Bx + Alpha * By) - SinP * Ry * (By - Alpha * Bx),
        Yc + SinP * Rx * (Bx + Alpha * By) + CosP * Ry * (By - Alpha * Bx),
        Xc + CosP * Rx * Bx - SinP * Ry * By,
        Yc + SinP * Rx * Bx + CosP * Ry * By);
      T := T + Seg;
    end;
    Cx := X; Cy := Y;
  end;

var
  V: array[0..6] of Double;
  Rel: Boolean;
  Fa, Fs: Integer;
  X, Y: Double;
  First: Boolean;
begin
  Lw := Max(0.01, S.StrokeW * Scale);
  P := 1;
  Cx := 0; Cy := 0; Sx := 0; Sy := 0; Lx := 0; Ly := 0;
  HaveCtrl := False;
  Open := False;
  Last := ' ';
  Cmd := ' ';
  First := True;
  while SkipSep do
  begin
    if D[P] in ['A'..'Z', 'a'..'z'] then
    begin
      Cmd := D[P]; Inc(P);
      if Cmd in ['Z', 'z'] then
      begin
        if Emit then Page.ClosePath;
        Cx := Sx; Cy := Sy; HaveCtrl := False; Last := Cmd;
        Continue;
      end;
    end
    else if Cmd = ' ' then begin Fail; Exit; end;
    Rel := Cmd in ['a'..'z'];
    case UpCase(Cmd) of
      'M':
        begin
          if not (NextNum(V[0]) and NextNum(V[1])) then begin Fail; Exit; end;
          if Rel and not First then begin V[0] := V[0] + Cx; V[1] := V[1] + Cy; end;
          MoveAbs(V[0], V[1]);
          if Cmd = 'M' then Cmd := 'L' else Cmd := 'l';
          HaveCtrl := False;
        end;
      'L':
        begin
          if not (NextNum(V[0]) and NextNum(V[1])) then begin Fail; Exit; end;
          if Rel then begin V[0] := V[0] + Cx; V[1] := V[1] + Cy; end;
          LineAbs(V[0], V[1]); HaveCtrl := False;
        end;
      'H':
        begin
          if not NextNum(V[0]) then begin Fail; Exit; end;
          if Rel then V[0] := V[0] + Cx;
          LineAbs(V[0], Cy); HaveCtrl := False;
        end;
      'V':
        begin
          if not NextNum(V[0]) then begin Fail; Exit; end;
          if Rel then V[0] := V[0] + Cy;
          LineAbs(Cx, V[0]); HaveCtrl := False;
        end;
      'C':
        begin
          if not (NextNum(V[0]) and NextNum(V[1]) and NextNum(V[2]) and NextNum(V[3]) and NextNum(V[4]) and NextNum(V[5])) then begin Fail; Exit; end;
          if Rel then
          begin
            V[0] := V[0] + Cx; V[1] := V[1] + Cy; V[2] := V[2] + Cx; V[3] := V[3] + Cy; V[4] := V[4] + Cx; V[5] := V[5] + Cy;
          end;
          CurveAbs(V[0], V[1], V[2], V[3], V[4], V[5]);
        end;
      'S':
        begin
          if not (NextNum(V[2]) and NextNum(V[3]) and NextNum(V[4]) and NextNum(V[5])) then begin Fail; Exit; end;
          if Rel then begin V[2] := V[2] + Cx; V[3] := V[3] + Cy; V[4] := V[4] + Cx; V[5] := V[5] + Cy; end;
          if HaveCtrl and (UpCase(Last) in ['C', 'S']) then begin V[0] := 2 * Cx - Lx; V[1] := 2 * Cy - Ly; end
          else begin V[0] := Cx; V[1] := Cy; end;
          CurveAbs(V[0], V[1], V[2], V[3], V[4], V[5]);
        end;
      'Q':
        begin
          if not (NextNum(V[0]) and NextNum(V[1]) and NextNum(V[2]) and NextNum(V[3])) then begin Fail; Exit; end;
          if Rel then begin V[0] := V[0] + Cx; V[1] := V[1] + Cy; V[2] := V[2] + Cx; V[3] := V[3] + Cy; end;
          X := Cx; Y := Cy;
          CurveAbs(X + 2 / 3 * (V[0] - X), Y + 2 / 3 * (V[1] - Y), V[2] + 2 / 3 * (V[0] - V[2]), V[3] + 2 / 3 * (V[1] - V[3]), V[2], V[3]);
          Lx := V[0]; Ly := V[1];
        end;
      'T':
        begin
          if not (NextNum(V[2]) and NextNum(V[3])) then begin Fail; Exit; end;
          if Rel then begin V[2] := V[2] + Cx; V[3] := V[3] + Cy; end;
          if HaveCtrl and (UpCase(Last) in ['Q', 'T']) then begin V[0] := 2 * Cx - Lx; V[1] := 2 * Cy - Ly; end
          else begin V[0] := Cx; V[1] := Cy; end;
          X := Cx; Y := Cy;
          CurveAbs(X + 2 / 3 * (V[0] - X), Y + 2 / 3 * (V[1] - Y), V[2] + 2 / 3 * (V[0] - V[2]), V[3] + 2 / 3 * (V[1] - V[3]), V[2], V[3]);
          Lx := V[0]; Ly := V[1];
        end;
      'A':
        begin
          if not (NextNum(V[0]) and NextNum(V[1]) and NextNum(V[2]) and NextFlag(Fa) and NextFlag(Fs) and NextNum(V[3]) and NextNum(V[4])) then begin Fail; Exit; end;
          if Rel then begin V[3] := V[3] + Cx; V[4] := V[4] + Cy; end;
          ArcAbs(V[0], V[1], V[2], Fa, Fs, V[3], V[4]);
          HaveCtrl := False;
        end;
    else
      Fail; Exit;
    end;
    Last := Cmd;
    First := False;
  end;
  if Emit then Paint(S);
end;

procedure TDrawer.Walk(N: TDOMNode; const S: TStyle; ADepth: Integer);
var
  E: TDOMElement;
  St: TStyle;
  Nm, V, Href: string;
  C: TDOMNode;
  Ok: Boolean;
  T: TMat;
  X, Y, W, H, Rx, Ry, Cxv, Cyv, K: Double;
  Pts: array[0..99] of Double;
  Cnt, I: Integer;
  Props: TStringList;
  Ref: TDOMElement;
  Dd: string;

  procedure ReadProps;
  var
    Sty, Item: string;
    P, Q: Integer;
    A: Integer;
  begin
    Props.Clear;
    for A := 0 to E.Attributes.Length - 1 do
      Props.Values[E.Attributes[A].NodeName] := E.Attributes[A].NodeValue;
    Sty := E.AttribStrings['style'];
    P := 1;
    while P <= Length(Sty) do
    begin
      Q := P;
      while (Q <= Length(Sty)) and (Sty[Q] <> ';') do Inc(Q);
      Item := Copy(Sty, P, Q - P);
      P := Q + 1;
      if Pos(':', Item) > 0 then Props.Values[Trim(Copy(Item, 1, Pos(':', Item) - 1))] := Trim(Copy(Item, Pos(':', Item) + 1, MaxInt));
    end;
  end;

  procedure ApplyStyle;
  var
    Cl: Integer;
  begin
    V := Props.Values['fill'];
    if V <> '' then
    begin
      Cl := ParseColor(V, St.Fill);
      if Cl = -2 then Fail else St.Fill := Cl;
    end;
    V := Props.Values['stroke'];
    if V <> '' then
    begin
      Cl := ParseColor(V, St.Stroke);
      if Cl = -2 then Fail else St.Stroke := Cl;
    end;
    V := Props.Values['stroke-width'];
    if V <> '' then St.StrokeW := Num(V, 1);
    V := LowerCase(Props.Values['stroke-linecap']);
    if V = 'round' then St.Cap := 1 else if V = 'square' then St.Cap := 2 else if V = 'butt' then St.Cap := 0;
    V := LowerCase(Props.Values['stroke-linejoin']);
    if V = 'round' then St.Join := 1 else if V = 'bevel' then St.Join := 2 else if V = 'miter' then St.Join := 0;
    V := LowerCase(Props.Values['fill-rule']);
    if V <> '' then St.EvenOdd := V = 'evenodd';
    V := Props.Values['fill-opacity'];
    if (V <> '') and (Num(V, 1) <= 0) then St.Fill := -1;
    V := Props.Values['stroke-opacity'];
    if (V <> '') and (Num(V, 1) <= 0) then St.Stroke := -1;
    V := Props.Values['stroke-dasharray'];
    if (V <> '') and (LowerCase(V) <> 'none') then Fail;
    if (Props.Values['clip-path'] <> '') or (Props.Values['mask'] <> '') or (Props.Values['filter'] <> '') then Fail;
    V := Props.Values['display'];
    if LowerCase(V) = 'none' then St.Fill := -1;
    V := Props.Values['transform'];
    if V <> '' then
    begin
      Ok := True;
      T := ParseTransform(V, Ok);
      if not Ok then Fail;
      St.Mat := MatMul(St.Mat, T);
    end;
  end;

  procedure SetPenAndColors;
  begin
    if not Emit then Exit;
    if St.Fill >= 0 then Page.SetColor(Cardinal(St.Fill), False);
    if St.Stroke >= 0 then
    begin
      Page.SetColor(Cardinal(St.Stroke), True);
      Page.AddObject(TPDFFreeFormString.Create(Page.Document,
        Format('%.4f w %d J %d j' + #13#10, [Max(0.01, St.StrokeW * Scale) * 72 / 25.4, St.Cap, St.Join], FS)));
    end;
  end;

  procedure Shape(const APathData: string);
  begin
    SetPenAndColors;
    DrawPath(APathData, St);
  end;

begin
  if (N = nil) or (N.NodeType <> ELEMENT_NODE) or (ADepth > 40) then Exit;
  E := TDOMElement(N);
  Nm := LowerCase(E.TagName);
  if Pos(':', Nm) > 0 then Nm := Copy(Nm, Pos(':', Nm) + 1, MaxInt);
  if (Nm = 'defs') or (Nm = 'title') or (Nm = 'desc') or (Nm = 'metadata') or (Nm = 'namedview') then Exit;
  if (Nm <> 'svg') and (Nm <> 'g') and (Nm <> 'path') and (Nm <> 'rect') and (Nm <> 'circle') and (Nm <> 'ellipse') and
     (Nm <> 'line') and (Nm <> 'polyline') and (Nm <> 'polygon') and (Nm <> 'use') and (Nm <> 'symbol') then
  begin
    Fail;
    Exit;
  end;
  Props := TStringList.Create;
  try
    St := S;
    ReadProps;
    if Nm <> 'svg' then ApplyStyle
    else
    begin
      V := Props.Values['fill'];
      if V <> '' then begin I := ParseColor(V, St.Fill); if I = -2 then Fail else St.Fill := I; end;
    end;
    if Failed then Exit;
    if (Nm = 'svg') or (Nm = 'g') or (Nm = 'symbol') then
    begin
      C := E.FirstChild;
      while C <> nil do
      begin
        Walk(C, St, ADepth + 1);
        if Failed then Exit;
        C := C.NextSibling;
      end;
    end
    else if Nm = 'path' then Shape(E.AttribStrings['d'])
    else if Nm = 'rect' then
    begin
      X := Num(E.AttribStrings['x'], 0); Y := Num(E.AttribStrings['y'], 0);
      W := Num(E.AttribStrings['width'], 0); H := Num(E.AttribStrings['height'], 0);
      Rx := Num(E.AttribStrings['rx'], 0); Ry := Num(E.AttribStrings['ry'], Rx);
      if (Rx <= 0) and (Ry > 0) then Rx := Ry;
      if (W > 0) and (H > 0) then
      begin
        Rx := Min(Rx, W / 2); Ry := Min(Ry, H / 2);
        if (Rx > 0) and (Ry > 0) then
          Dd := Format('M %.5f %.5f H %.5f A %.5f %.5f 0 0 1 %.5f %.5f V %.5f A %.5f %.5f 0 0 1 %.5f %.5f H %.5f A %.5f %.5f 0 0 1 %.5f %.5f V %.5f A %.5f %.5f 0 0 1 %.5f %.5f Z',
            [X + Rx, Y, X + W - Rx, Rx, Ry, X + W, Y + Ry, Y + H - Ry, Rx, Ry, X + W - Rx, Y + H, X + Rx, Rx, Ry, X, Y + H - Ry, Y + Ry, Rx, Ry, X + Rx, Y], FS)
        else
          Dd := Format('M %.5f %.5f H %.5f V %.5f H %.5f Z', [X, Y, X + W, Y + H, X], FS);
        Shape(Dd);
      end;
    end
    else if (Nm = 'circle') or (Nm = 'ellipse') then
    begin
      Cxv := Num(E.AttribStrings['cx'], 0); Cyv := Num(E.AttribStrings['cy'], 0);
      if Nm = 'circle' then begin Rx := Num(E.AttribStrings['r'], 0); Ry := Rx; end
      else begin Rx := Num(E.AttribStrings['rx'], 0); Ry := Num(E.AttribStrings['ry'], 0); end;
      if (Rx > 0) and (Ry > 0) then
      begin
        Dd := Format('M %.5f %.5f A %.5f %.5f 0 1 1 %.5f %.5f A %.5f %.5f 0 1 1 %.5f %.5f Z',
          [Cxv - Rx, Cyv, Rx, Ry, Cxv + Rx, Cyv, Rx, Ry, Cxv - Rx, Cyv], FS);
        Shape(Dd);
      end;
    end
    else if Nm = 'line' then
    begin
      Dd := Format('M %.5f %.5f L %.5f %.5f', [Num(E.AttribStrings['x1'], 0), Num(E.AttribStrings['y1'], 0),
        Num(E.AttribStrings['x2'], 0), Num(E.AttribStrings['y2'], 0)], FS);
      K := St.Fill; St.Fill := -1;
      Shape(Dd);
    end
    else if (Nm = 'polyline') or (Nm = 'polygon') then
    begin
      Cnt := ParseNumbers(E.AttribStrings['points'], Pts);
      if Cnt >= 4 then
      begin
        Dd := Format('M %.5f %.5f', [Pts[0], Pts[1]], FS);
        I := 2;
        while I + 1 < Cnt do
        begin
          Dd := Dd + Format(' L %.5f %.5f', [Pts[I], Pts[I + 1]], FS);
          Inc(I, 2);
        end;
        if Nm = 'polygon' then Dd := Dd + ' Z' else St.Fill := -1;
        Shape(Dd);
      end;
    end
    else if Nm = 'use' then
    begin
      Href := E.AttribStrings['xlink:href'];
      if Href = '' then Href := E.AttribStrings['href'];
      if (Href = '') or (Href[1] <> '#') then begin Fail; Exit; end;
      Ref := FindById(Copy(Href, 2, MaxInt));
      if Ref = nil then begin Fail; Exit; end;
      T := IdentMat;
      T.E := Num(E.AttribStrings['x'], 0);
      T.F := Num(E.AttribStrings['y'], 0);
      St.Mat := MatMul(St.Mat, T);
      Walk(Ref, St, ADepth + 1);
    end;
  finally
    Props.Free;
  end;
end;

function PdfDrawSvg(APage: TPDFPage; const ASvg: string; X, Y, W, H: Double; AStretch: Boolean): Boolean;
var
  Dr: TDrawer;
  Ms: TStringStream;
  Root: TDOMElement;
  Vb: array[0..3] of Double;
  N: Integer;
  Sx, Sy, Sc: Double;
  S: TStyle;
  Pass: Integer;
  Vw, Vh: Double;
begin
  Result := False;
  if (APage = nil) or (ASvg = '') or (W <= 0) or (H <= 0) then Exit;
  Dr := TDrawer.Create;
  Ms := TStringStream.Create(ASvg);
  try
    try
      ReadXMLFile(Dr.Doc, Ms);
    except
      Exit;
    end;
    try
      Root := Dr.Doc.DocumentElement;
      if (Root = nil) or (LowerCase(Root.TagName) <> 'svg') then Exit;
      FillChar(Vb, SizeOf(Vb), 0);
      N := ParseNumbers(Root.AttribStrings['viewBox'], Vb);
      if N < 4 then
      begin
        Vb[0] := 0; Vb[1] := 0;
        Vb[2] := Num(Root.AttribStrings['width'], 0);
        Vb[3] := Num(Root.AttribStrings['height'], 0);
      end;
      if (Vb[2] <= 0) or (Vb[3] <= 0) then Exit;
      Vw := Vb[2]; Vh := Vb[3];
      Sx := W / Vw; Sy := H / Vh;
      if AStretch then Dr.Scale := Sqrt(Sx * Sy)
      else
      begin
        Sc := Min(Sx, Sy); Sx := Sc; Sy := Sc; Dr.Scale := Sc;
      end;
      FillChar(S, SizeOf(S), 0);
      S.Fill := 0; S.Stroke := -1; S.StrokeW := 1; S.Mat := IdentMat;
      S.Mat.A := Sx; S.Mat.D := Sy;
      S.Mat.E := X + (W - Vw * Sx) / 2 - Vb[0] * Sx;
      S.Mat.F := Y + (H - Vh * Sy) / 2 - Vb[1] * Sy;
      Dr.Page := APage;
      { prvi prolaz samo provjerava podrsku, drugi crta }
      for Pass := 0 to 1 do
      begin
        Dr.Emit := Pass = 1;
        Dr.Failed := False;
        if Dr.Emit then APage.PushGraphicsStack;
        Dr.Walk(Root, S, 0);
        if Dr.Emit then APage.PopGraphicsStack;
        if Dr.Failed then Exit;
      end;
      Result := True;
    finally
      Dr.Doc.Free;
    end;
  finally
    Ms.Free;
    Dr.Free;
  end;
end;

initialization
  FS := DefaultFormatSettings;
  FS.DecimalSeparator := '.';

end.
