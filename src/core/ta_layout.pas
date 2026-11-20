unit ta_layout;
{ Poravnanje i raspored vise kontrola kao u Lazarusu: matematika bez sucelja.
  Prva kontrola (ARef) je referentna. }

{$mode objfpc}{$H+}

interface

type
  TLBox = record
    L, T, W, H: Integer;
  end;
  TLBoxes = array of TLBox;

  TLayoutOp = (loAlignLeft, loAlignRight, loAlignTop, loAlignBottom, loCenterH, loCenterV,
    loSameWidth, loSameHeight, loSameSize, loSpaceH, loSpaceV);

const
  LayoutOpNames: array[TLayoutOp] of string = (
    'Poravnaj lijevo', 'Poravnaj desno', 'Poravnaj gore', 'Poravnaj dolje',
    'Centriraj vodoravno', 'Centriraj uspravno', 'Ista širina', 'Ista visina', 'Ista veličina',
    'Jednak razmak vodoravno', 'Jednak razmak uspravno');

const
  { koji rubovi se pomicu pri promjeni velicine (kao rucke u Lazarusu) }
  gmLeft = 1; gmTop = 2; gmRight = 4; gmBottom = 8;

{ Rucke oko kontrole: 0 SZ, 1 S, 2 SI, 3 I, 4 JI, 5 J, 6 JZ, 7 Z (sjever = gore). }
function GripMode(AGrip: Integer): Integer;
{ Koji rub(ovi) su pod pokazivacem unutar kontrole W x H; 0 = unutrasnjost. ABand = debljina ruba. }
function EdgeMode(X, Y, W, H, ABand: Integer): Integer;
{ Nova kutija nakon povlacenja rubova za (Dx, Dy). Pomaknuti rubovi se poravnavaju na mrezu AGrid
  (0/1 = bez); suprotni rub ostaje na mjestu; velicina ne pada ispod AMinW x AMinH; Left i Top ne idu ispod 0. }
function ResizeBox(const AOrig: TLBox; AMode, ADx, ADy, AMinW, AMinH, AGrid: Integer): TLBox;

{ Primjenjuje operaciju na kutije; ARef = indeks referentne. Vraca False ako nema sto mijenjati. }
function ApplyLayout(AOp: TLayoutOp; var ABoxes: TLBoxes; ARef: Integer): Boolean;

implementation

function GripMode(AGrip: Integer): Integer;
begin
  case AGrip of
    0: Result := gmLeft or gmTop;
    1: Result := gmTop;
    2: Result := gmRight or gmTop;
    3: Result := gmRight;
    4: Result := gmRight or gmBottom;
    5: Result := gmBottom;
    6: Result := gmLeft or gmBottom;
    7: Result := gmLeft;
  else
    Result := 0;
  end;
end;

function EdgeMode(X, Y, W, H, ABand: Integer): Integer;
begin
  Result := 0;
  if (X < 0) or (Y < 0) or (X >= W) or (Y >= H) then Exit;
  { na vrlo maloj kontroli rubovi se ne smiju preklopiti: ostavi srednju trecinu za povlacenje }
  if W >= 3 * ABand then
  begin
    if X < ABand then Result := Result or gmLeft
    else if X >= W - ABand then Result := Result or gmRight;
  end;
  if H >= 3 * ABand then
  begin
    if Y < ABand then Result := Result or gmTop
    else if Y >= H - ABand then Result := Result or gmBottom;
  end;
end;

function SnapEdge(V, AGrid: Integer): Integer;
begin
  if AGrid > 1 then Result := (V + AGrid div 2) div AGrid * AGrid else Result := V;
end;

function ResizeBox(const AOrig: TLBox; AMode, ADx, ADy, AMinW, AMinH, AGrid: Integer): TLBox;
var
  L, T, R, B: Integer;
begin
  L := AOrig.L; T := AOrig.T; R := AOrig.L + AOrig.W; B := AOrig.T + AOrig.H;
  if AMode and gmLeft <> 0 then L := SnapEdge(L + ADx, AGrid);
  if AMode and gmRight <> 0 then R := SnapEdge(R + ADx, AGrid);
  if AMode and gmTop <> 0 then T := SnapEdge(T + ADy, AGrid);
  if AMode and gmBottom <> 0 then B := SnapEdge(B + ADy, AGrid);
  if L < 0 then L := 0;
  if T < 0 then T := 0;
  if R - L < AMinW then
  begin
    if (AMode and gmLeft <> 0) and (AMode and gmRight = 0) then L := R - AMinW else R := L + AMinW;
  end;
  if B - T < AMinH then
  begin
    if (AMode and gmTop <> 0) and (AMode and gmBottom = 0) then T := B - AMinH else B := T + AMinH;
  end;
  Result.L := L; Result.T := T; Result.W := R - L; Result.H := B - T;
end;

function ApplyLayout(AOp: TLayoutOp; var ABoxes: TLBoxes; ARef: Integer): Boolean;
var
  I, J, N, Total, Gap, Pos_: Integer;
  Idx: array of Integer;
  Tmp: Integer;
  R: TLBox;
begin
  Result := False;
  N := Length(ABoxes);
  if (N < 2) or (ARef < 0) or (ARef >= N) then Exit;
  R := ABoxes[ARef];
  case AOp of
    loAlignLeft: for I := 0 to N - 1 do ABoxes[I].L := R.L;
    loAlignRight: for I := 0 to N - 1 do ABoxes[I].L := R.L + R.W - ABoxes[I].W;
    loAlignTop: for I := 0 to N - 1 do ABoxes[I].T := R.T;
    loAlignBottom: for I := 0 to N - 1 do ABoxes[I].T := R.T + R.H - ABoxes[I].H;
    loCenterH: for I := 0 to N - 1 do ABoxes[I].L := R.L + (R.W - ABoxes[I].W) div 2;
    loCenterV: for I := 0 to N - 1 do ABoxes[I].T := R.T + (R.H - ABoxes[I].H) div 2;
    loSameWidth: for I := 0 to N - 1 do ABoxes[I].W := R.W;
    loSameHeight: for I := 0 to N - 1 do ABoxes[I].H := R.H;
    loSameSize: for I := 0 to N - 1 do begin ABoxes[I].W := R.W; ABoxes[I].H := R.H; end;
    loSpaceH, loSpaceV:
      begin
        if N < 3 then Exit;
        { redoslijed po polozaju, krajnje ostaju na mjestu }
        SetLength(Idx, N);
        for I := 0 to N - 1 do Idx[I] := I;
        for I := 0 to N - 2 do
          for J := I + 1 to N - 1 do
            if (AOp = loSpaceH) and (ABoxes[Idx[J]].L < ABoxes[Idx[I]].L) or
               (AOp = loSpaceV) and (ABoxes[Idx[J]].T < ABoxes[Idx[I]].T) then
            begin
              Tmp := Idx[I]; Idx[I] := Idx[J]; Idx[J] := Tmp;
            end;
        if AOp = loSpaceH then
        begin
          Total := ABoxes[Idx[N - 1]].L + ABoxes[Idx[N - 1]].W - ABoxes[Idx[0]].L;
          for I := 0 to N - 1 do Dec(Total, ABoxes[Idx[I]].W);
          Gap := Total div (N - 1);
          Pos_ := ABoxes[Idx[0]].L + ABoxes[Idx[0]].W + Gap;
          for I := 1 to N - 2 do
          begin
            ABoxes[Idx[I]].L := Pos_;
            Pos_ := Pos_ + ABoxes[Idx[I]].W + Gap;
          end;
        end
        else
        begin
          Total := ABoxes[Idx[N - 1]].T + ABoxes[Idx[N - 1]].H - ABoxes[Idx[0]].T;
          for I := 0 to N - 1 do Dec(Total, ABoxes[Idx[I]].H);
          Gap := Total div (N - 1);
          Pos_ := ABoxes[Idx[0]].T + ABoxes[Idx[0]].H + Gap;
          for I := 1 to N - 2 do
          begin
            ABoxes[Idx[I]].T := Pos_;
            Pos_ := Pos_ + ABoxes[Idx[I]].H + Gap;
          end;
        end;
      end;
  end;
  for I := 0 to N - 1 do
  begin
    if ABoxes[I].L < 0 then ABoxes[I].L := 0;
    if ABoxes[I].T < 0 then ABoxes[I].T := 0;
    if ABoxes[I].W < 4 then ABoxes[I].W := 4;
    if ABoxes[I].H < 4 then ABoxes[I].H := 4;
  end;
  Result := True;
end;

end.
