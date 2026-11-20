unit ta_words;
{ Brojevi i iznosi slovima na hrvatskom (račun: "sto dvadeset tri eura i
  četrdeset pet centi"). Gramatika: rod (tisuća je ženskog roda, milijun
  muškog), te oblici jedan/jedna, dva/dvije i padeži jedinica. }

{$mode objfpc}{$H+}

interface

type
  TWordGender = (wgMasculine, wgFeminine);

{ 0 .. 999 999 999 999, negativni dobivaju "minus". }
function NumberToWordsHr(N: Int64; AGender: TWordGender = wgMasculine): string;
{ AStyle 0: i centi slovima, 1: i 45/100. Valuta euro/cent. }
function AmountToWordsHr(AValue: Double; AStyle: Integer = 0): string;

implementation

uses
  SysUtils, Math;

const
  Units: array[0..19] of string = (
    'nula', 'jedan', 'dva', 'tri', 'četiri', 'pet', 'šest', 'sedam', 'osam', 'devet', 'deset',
    'jedanaest', 'dvanaest', 'trinaest', 'četrnaest', 'petnaest', 'šesnaest', 'sedamnaest',
    'osamnaest', 'devetnaest');
  Tens: array[2..9] of string = (
    'dvadeset', 'trideset', 'četrdeset', 'pedeset', 'šezdeset', 'sedamdeset', 'osamdeset', 'devedeset');
  Hundreds: array[1..9] of string = (
    'sto', 'dvjesto', 'tristo', 'četiristo', 'petsto', 'šesto', 'sedamsto', 'osamsto', 'devetsto');

function Group(N: Integer; AGender: TWordGender): string;
var
  H, R: Integer;
  S: string;

  procedure Add(const W: string);
  begin
    if S <> '' then S := S + ' ';
    S := S + W;
  end;

  function Unit_(U: Integer): string;
  begin
    Result := Units[U];
    if AGender = wgFeminine then
      case U of
        1: Result := 'jedna';
        2: Result := 'dvije';
      end;
  end;

begin
  S := '';
  H := N div 100;
  R := N mod 100;
  if H > 0 then Add(Hundreds[H]);
  if R >= 20 then
  begin
    Add(Tens[R div 10]);
    if R mod 10 > 0 then Add(Unit_(R mod 10));
  end
  else if R > 0 then
  begin
    if R <= 2 then Add(Unit_(R)) else Add(Units[R]);
  end;
  Result := S;
end;

{ 0 = jedinstveni oblik za 1, 1 = 2..4, 2 = ostalo (11..14 su "ostalo") }
function PluralClass(N: Int64): Integer;
var
  L2, L1: Integer;
begin
  L2 := N mod 100;
  L1 := N mod 10;
  if (L1 = 1) and (L2 <> 11) then Exit(0);
  if (L1 in [2, 3, 4]) and not (L2 in [12, 13, 14]) then Exit(1);
  Result := 2;
end;

function NumberToWordsHr(N: Int64; AGender: TWordGender): string;
var
  G: array[0..3] of Integer;     { jedinice, tisuće, milijuni, milijarde }
  I: Integer;
  Rest: Int64;
  S, W: string;

  procedure Add(const X: string);
  begin
    if X = '' then Exit;
    if S <> '' then S := S + ' ';
    S := S + X;
  end;

begin
  if N = 0 then Exit('nula');
  if N < 0 then Exit('minus ' + NumberToWordsHr(-N, AGender));
  if N > 999999999999 then Exit(IntToStr(N));
  Rest := N;
  for I := 0 to 3 do
  begin
    G[I] := Rest mod 1000;
    Rest := Rest div 1000;
  end;
  S := '';
  { milijarde (ženski rod) }
  if G[3] > 0 then
  begin
    Add(Group(G[3], wgFeminine));
    case PluralClass(G[3]) of
      0: Add('milijarda');
      1: Add('milijarde');
    else Add('milijardi');
    end;
  end;
  if G[2] > 0 then
  begin
    Add(Group(G[2], wgMasculine));
    if PluralClass(G[2]) = 0 then Add('milijun') else Add('milijuna');
  end;
  if G[1] > 0 then
  begin
    if G[1] = 1 then Add('tisuću')
    else
    begin
      Add(Group(G[1], wgFeminine));
      case PluralClass(G[1]) of
        0: Add('tisuća');
        1: Add('tisuće');
      else Add('tisuća');
      end;
    end;
  end;
  if G[0] > 0 then Add(Group(G[0], AGender));
  W := S;
  Result := W;
end;

function AmountToWordsHr(AValue: Double; AStyle: Integer): string;
var
  Total, Euros, Cents: Int64;
  Neg: Boolean;
  E, C: string;
begin
  Neg := AValue < 0;
  Total := Round(Abs(AValue) * 100);
  Euros := Total div 100;
  Cents := Total mod 100;
  if PluralClass(Euros) = 0 then E := 'euro' else E := 'eura';
  Result := NumberToWordsHr(Euros, wgMasculine) + ' ' + E;
  if Cents > 0 then
  begin
    case PluralClass(Cents) of
      0: C := 'cent';
      1: C := 'centa';
    else C := 'centi';
    end;
    if AStyle = 1 then Result := Result + ' i ' + Format('%.2d', [Cents]) + '/100'
    else Result := Result + ' i ' + NumberToWordsHr(Cents, wgMasculine) + ' ' + C;
  end;
  if Neg and (Total > 0) then Result := 'minus ' + Result;
end;

end.
