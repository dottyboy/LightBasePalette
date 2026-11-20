unit ta_propmap;
{ TaPropMap: tablica svojstava kontrole. Jedan redak po svojstvu govori gdje se vrijednost
  cuva u TaControlDef (polje ili Extra kljuc) i kako se pretvara. Ista tablica sluzi za
  preslikavanje definicija <-> objavljena svojstva komponente (paleta) i za .lfm.
  Za sada nista ne zamjenjuje: ta_controls.DefGet/DefSet ostaju, a smoke test provjerava
  da tablica daje isti rezultat. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_formdef;

type
  TaPropStore = (psField, psExtra);
  { pmText: kako je zadano; pmTextTrim: Trim; pmLower: mala slova; pmLowerTrim: Trim + mala slova;
    pmInt: cijeli broj (neispravan unos zadrzava staro); pmFlag: '1' ili prazno (zadano Ne);
    pmFlagOff: prazno ili '0' (zadano Da); pmFlagShow: '1' ili '0' (zadano Da);
    pmBool: logicko polje definicije }
  TaPropMapKind = (pmText, pmTextTrim, pmLower, pmLowerTrim, pmInt, pmFlag, pmFlagOff, pmFlagShow, pmBool);

  TaPropEntry = record
    Name: string;       { naziv svojstva (isti kao u Inspektoru) }
    Store: TaPropStore; { polje definicije ili Extra }
    Key: string;        { psField: naziv polja; psExtra: Extra kljuc }
    Kind: TaPropMapKind;
    Category: string;   { Podaci, Ponasanje, Izgled, Radnje, Raspored }
  end;

{ Svojstva s posebnom pretvorbom NISU u tablici i ostaju u ta_controls.DefGet/DefSet:
  Anchors, Dock, BorderSpacing (NormalizeSpacing), Items (pretvorba redaka), Picture (SVG/ikona/pohrana). }
const
  PropMap: array[0..66] of TaPropEntry = (
    (Name: 'Name';          Store: psField; Key: 'Name';          Kind: pmText;      Category: 'Podaci'),
    (Name: 'Caption';       Store: psField; Key: 'Caption';       Kind: pmText;      Category: 'Izgled'),
    (Name: 'ControlSource'; Store: psField; Key: 'ControlSource'; Kind: pmText;      Category: 'Podaci'),
    (Name: 'RowSource';     Store: psField; Key: 'RowSource';     Kind: pmText;      Category: 'Podaci'),
    (Name: 'LinkMaster';    Store: psField; Key: 'LinkMaster';    Kind: pmText;      Category: 'Podaci'),
    (Name: 'LinkChild';     Store: psField; Key: 'LinkChild';     Kind: pmText;      Category: 'Podaci'),
    (Name: 'OnClick';       Store: psField; Key: 'OnClick';       Kind: pmText;      Category: 'Radnje'),
    (Name: 'Format';        Store: psField; Key: 'Format';        Kind: pmText;      Category: 'Podaci'),
    (Name: 'Align';         Store: psField; Key: 'Align';         Kind: pmLower;     Category: 'Izgled'),
    (Name: 'Bold';          Store: psField; Key: 'Bold';          Kind: pmBool;      Category: 'Izgled'),
    (Name: 'Left';          Store: psField; Key: 'Left';          Kind: pmInt;       Category: 'Raspored'),
    (Name: 'Top';           Store: psField; Key: 'Top';           Kind: pmInt;       Category: 'Raspored'),
    (Name: 'Width';         Store: psField; Key: 'Width';         Kind: pmInt;       Category: 'Raspored'),
    (Name: 'Height';        Store: psField; Key: 'Height';        Kind: pmInt;       Category: 'Raspored'),
    (Name: 'Italic';        Store: psExtra; Key: 'italic';        Kind: pmFlag;      Category: 'Izgled'),
    (Name: 'Locked';        Store: psExtra; Key: 'locked';        Kind: pmFlag;      Category: 'Ponasanje'),
    (Name: 'Tip';           Store: psExtra; Key: 'tip';           Kind: pmText;      Category: 'Izgled'),
    (Name: 'VisibleIf';     Store: psExtra; Key: 'visibleIf';     Kind: pmText;      Category: 'Ponasanje'),
    (Name: 'EnabledIf';     Store: psExtra; Key: 'enabledIf';     Kind: pmText;      Category: 'Ponasanje'),
    (Name: 'FontName';      Store: psExtra; Key: 'fontName';      Kind: pmText;      Category: 'Izgled'),
    (Name: 'FontSize';      Store: psExtra; Key: 'fontSize';      Kind: pmText;      Category: 'Izgled'),
    (Name: 'ForeColor';     Store: psExtra; Key: 'foreColor';     Kind: pmText;      Category: 'Izgled'),
    (Name: 'BackColor';     Store: psExtra; Key: 'backColor';     Kind: pmText;      Category: 'Izgled'),
    (Name: 'BorderWidth';   Store: psExtra; Key: 'borderWidth';   Kind: pmText;      Category: 'Izgled'),
    (Name: 'CondFormat';    Store: psExtra; Key: 'condFormat';    Kind: pmText;      Category: 'Izgled'),
    (Name: 'ChartType';     Store: psExtra; Key: 'chartType';     Kind: pmLower;     Category: 'Izgled'),
    (Name: 'Accordion';     Store: psExtra; Key: 'accordion';     Kind: pmFlagOff;   Category: 'Izgled'),
    (Name: 'Search';        Store: psExtra; Key: 'search';        Kind: pmFlag;      Category: 'Ponasanje'),
    (Name: 'BarType';       Store: psExtra; Key: 'barType';       Kind: pmLowerTrim; Category: 'Izgled'),
    (Name: 'ShowText';      Store: psExtra; Key: 'showText';      Kind: pmFlagShow;  Category: 'Izgled'),
    (Name: 'SizeMode';      Store: psExtra; Key: 'sizeMode';      Kind: pmLower;     Category: 'Izgled'),
    (Name: 'CalcFields';    Store: psExtra; Key: 'calc';          Kind: pmText;      Category: 'Ponasanje'),
    (Name: 'AutoFill';      Store: psExtra; Key: 'autofill';      Kind: pmText;      Category: 'Ponasanje'),
    (Name: 'CalcRules';     Store: psExtra; Key: 'calcrules';     Kind: pmText;      Category: 'Ponasanje'),
    (Name: 'Min';          Store: psExtra; Key: 'min';          Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'Max';          Store: psExtra; Key: 'max';          Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'WarnAt';       Store: psExtra; Key: 'warnAt';       Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'DangerAt';     Store: psExtra; Key: 'dangerAt';     Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'Days';         Store: psExtra; Key: 'days';         Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'MenuItems';    Store: psExtra; Key: 'menuItems';    Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'Columns';      Store: psExtra; Key: 'columns';      Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'MinSelected';  Store: psExtra; Key: 'minSelected';  Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'MaxSelected';  Store: psExtra; Key: 'maxSelected';  Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'MultiSelect';  Store: psExtra; Key: 'multiSelect';  Kind: pmFlag; Category: 'Podaci'),
    (Name: 'Preview';      Store: psExtra; Key: 'preview';      Kind: pmFlag; Category: 'Podaci'),
    (Name: 'Expanded';     Store: psExtra; Key: 'expanded';     Kind: pmFlagOff; Category: 'Izgled'),
    (Name: 'MinSize';      Store: psExtra; Key: 'minSize';      Kind: pmTextTrim; Category: 'Izgled'),
    (Name: 'Mask';         Store: psExtra; Key: 'mask';         Kind: pmText; Category: 'Podaci'),
    (Name: 'ActivePage';   Store: psExtra; Key: 'active';       Kind: pmTextTrim; Category: 'Podaci'),
    (Name: 'Variant';       Store: psExtra; Key: 'variant';       Kind: pmLowerTrim; Category: 'Podaci'),
    (Name: 'PropertyClass'; Store: psExtra; Key: 'class';         Kind: pmTextTrim;  Category: 'Podaci'),
    (Name: 'Lov';           Store: psExtra; Key: 'lov';           Kind: pmText;      Category: 'Podaci'),
    (Name: 'LovMap';        Store: psExtra; Key: 'lovmap';        Kind: pmText;      Category: 'Podaci'),
    (Name: 'LovValidate';   Store: psExtra; Key: 'lovvalidate';   Kind: pmFlag;      Category: 'Ponasanje'),
    (Name: 'OnChange';      Store: psExtra; Key: 'onChange';      Kind: pmText;      Category: 'Radnje'),
    (Name: 'OnDblClick';    Store: psExtra; Key: 'onDblClick';    Kind: pmText;      Category: 'Radnje'),
    (Name: 'OnEnter';       Store: psExtra; Key: 'onEnter';       Kind: pmText;      Category: 'Radnje'),
    (Name: 'OnExit';        Store: psExtra; Key: 'onExit';        Kind: pmText;      Category: 'Radnje'),
    (Name: 'OnValidate';    Store: psExtra; Key: 'onValidate';    Kind: pmText;      Category: 'Radnje'),
    (Name: 'OnKey';         Store: psExtra; Key: 'onKey';         Kind: pmText;      Category: 'Radnje'),
    (Name: 'Container';     Store: psExtra; Key: 'container';     Kind: pmText;      Category: 'Raspored'),
    (Name: 'Page';          Store: psExtra; Key: 'page';          Kind: pmText;      Category: 'Raspored'),
    (Name: 'Icon';          Store: psExtra; Key: 'icon';          Kind: pmTextTrim;  Category: 'Izgled'),
    (Name: 'AnchorLeft';    Store: psExtra; Key: 'asl';           Kind: pmTextTrim;  Category: 'Raspored'),
    (Name: 'AnchorTop';     Store: psExtra; Key: 'ast';           Kind: pmTextTrim;  Category: 'Raspored'),
    (Name: 'AnchorRight';   Store: psExtra; Key: 'asr';           Kind: pmTextTrim;  Category: 'Raspored'),
    (Name: 'AnchorBottom';  Store: psExtra; Key: 'asb';           Kind: pmTextTrim;  Category: 'Raspored')
  );

{ indeks u PropMap ili -1 }
function PropMapFind(const AName: string): Integer;
{ vrijednost svojstva kao tekst; False ako svojstvo nije u tablici }
function PropMapGet(D: TaControlDef; const AName: string; out AValue: string): Boolean;
{ postavlja svojstvo; False ako svojstvo nije u tablici }
function PropMapSet(D: TaControlDef; const AName, AValue: string): Boolean;

implementation

function PropMapFind(const AName: string): Integer;
var
  I: Integer;
begin
  for I := Low(PropMap) to High(PropMap) do
    if SameText(PropMap[I].Name, AName) then Exit(I);
  Result := -1;
end;

function BoolText(B: Boolean): string;
begin
  if B then Result := 'True' else Result := 'False';
end;

function FieldGet(D: TaControlDef; const AKey: string): string;
begin
  Result := '';
  if AKey = 'Name' then Result := D.Name
  else if AKey = 'Caption' then Result := D.Caption
  else if AKey = 'ControlSource' then Result := D.ControlSource
  else if AKey = 'RowSource' then Result := D.RowSource
  else if AKey = 'LinkMaster' then Result := D.LinkMaster
  else if AKey = 'LinkChild' then Result := D.LinkChild
  else if AKey = 'OnClick' then Result := D.OnClick
  else if AKey = 'Format' then Result := D.Format
  else if AKey = 'Align' then Result := D.Align
  else if AKey = 'Bold' then Result := BoolText(D.Bold)
  else if AKey = 'Left' then Result := IntToStr(D.Left)
  else if AKey = 'Top' then Result := IntToStr(D.Top)
  else if AKey = 'Width' then Result := IntToStr(D.Width)
  else if AKey = 'Height' then Result := IntToStr(D.Height);
end;

procedure FieldSet(D: TaControlDef; const AKey, AValue: string);
begin
  if AKey = 'Name' then D.Name := AValue
  else if AKey = 'Caption' then D.Caption := AValue
  else if AKey = 'ControlSource' then D.ControlSource := AValue
  else if AKey = 'RowSource' then D.RowSource := AValue
  else if AKey = 'LinkMaster' then D.LinkMaster := AValue
  else if AKey = 'LinkChild' then D.LinkChild := AValue
  else if AKey = 'OnClick' then D.OnClick := AValue
  else if AKey = 'Format' then D.Format := AValue
  else if AKey = 'Align' then D.Align := AValue
  else if AKey = 'Bold' then D.Bold := StrToBoolDef(AValue, D.Bold)
  else if AKey = 'Left' then D.Left := StrToIntDef(AValue, D.Left)
  else if AKey = 'Top' then D.Top := StrToIntDef(AValue, D.Top)
  else if AKey = 'Width' then D.Width := StrToIntDef(AValue, D.Width)
  else if AKey = 'Height' then D.Height := StrToIntDef(AValue, D.Height);
end;

function PropMapGet(D: TaControlDef; const AName: string; out AValue: string): Boolean;
var
  I: Integer;
  E: TaPropEntry;
  Raw: string;
begin
  I := PropMapFind(AName);
  Result := I >= 0;
  AValue := '';
  if not Result then Exit;
  E := PropMap[I];
  if E.Store = psField then Raw := FieldGet(D, E.Key) else Raw := D.GetX(E.Key);
  case E.Kind of
    pmFlag: AValue := BoolText(Raw = '1');
    pmFlagOff, pmFlagShow: AValue := BoolText(Raw <> '0');
    else AValue := Raw;   { pmBool i pmInt su vec tekst iz FieldGet }
  end;
end;

function PropMapSet(D: TaControlDef; const AName, AValue: string): Boolean;
var
  I: Integer;
  E: TaPropEntry;
  V: string;
begin
  I := PropMapFind(AName);
  Result := I >= 0;
  if not Result then Exit;
  E := PropMap[I];
  case E.Kind of
    pmTextTrim: V := Trim(AValue);
    pmLower: V := LowerCase(AValue);
    pmLowerTrim: V := LowerCase(Trim(AValue));
    pmFlag: if StrToBoolDef(AValue, False) then V := '1' else V := '';
    pmFlagOff: if StrToBoolDef(AValue, True) then V := '' else V := '0';
    pmFlagShow: if StrToBoolDef(AValue, True) then V := '1' else V := '0';
  else
    V := AValue;
  end;
  if E.Store = psField then FieldSet(D, E.Key, V) else D.SetX(E.Key, V);
end;

end.
