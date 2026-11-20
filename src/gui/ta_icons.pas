unit ta_icons;
{ Ikone programa: ugradjene PNG slike (ta_iconsdata, generira tools/gen_icons.py) kao slike za gumbe, popise slika
  (izbornici, kartice) i crtanje u popisima. Slike se dekodiraju jednom i pamte. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Graphics, Controls, Buttons, ImgList, Menus, ComCtrls, StdCtrls, base64, LazUTF8, ta_iconsdata;

{ jedna slika; ASize je 16, 24 ili 32; nil ako ikone nema. Slika je vlasnistvo jedinice. }
function IconPng(const AName: string; ASize: Integer): TPortableNetworkGraphic;
{ tamna ili svijetla izvedba ikona (prema temi); mijenja i popise slika }
procedure SetIconDark(ADark: Boolean);
function IconDarkMode: Boolean;
{ popis svih ikona za izbornike i kartice; IconIndex daje mjesto ikone u njemu (-1 = nema) }
function IconList(ASize: Integer): TImageList;
function IconIndex(const AName: string): Integer;
{ gumb za alatnu traku s ikonom i natpisom (ili samo ikonom kad je natpis prazan) }
function MakeToolBtn(AParent: TWinControl; const ACaption, AIcon: string; X, Y, W, H: Integer;
  AClick: TNotifyEvent; const AHint: string = ''): TBitBtn;
{ ikona alatne trake za natpis gumba (Spremi, Pregled, Poništi...) }
function ToolIconFor(const ACaption: string): string;
{ postavlja sliku na gumb s natpisom }
procedure SetGlyph(AButton: TBitBtn; const AName: string; ASize: Integer = 16);
{ ikona za vrstu kontrole u paleti dizajnera: "TextBox" -> c_textbox }
function ControlIconName(const AKind: string): string;
{ ikone za stavke izbornika prema natpisu (Novi, Otvori, Obrisi, Pokreni...) }
procedure ApplyMenuIcons(AMenu: TMenu);
{ crta ikonu i natpis u popisu (OnDrawItem), za paletu dizajnera }
procedure DrawIconItem(AList: TListBox; AIndex: Integer; ARect: TRect; AState: TOwnerDrawState; const AIcon: string);
{ ikona programa za prozor }
procedure ApplyAppIcon;

implementation

uses
  Forms, LCLType;

var
  Cache: TStringList;
  Lists: array[Boolean, 0..2] of TImageList;
  DarkMode: Boolean = False;

procedure SetIconDark(ADark: Boolean);
begin
  DarkMode := ADark;
end;

function IconDarkMode: Boolean;
begin
  Result := DarkMode;
end;

{ korisnikova ikona ~/.config/TyphAccess/ikone/NAZIV[-tamna].png ima prednost pred ugradjenom }
function UserIconFile(const AName: string; ASize: Integer): string;
var
  Dir: string;
begin
  Result := '';
  Dir := GetAppConfigDir(False) + 'ikone' + PathDelim;
  if not DirectoryExists(Dir) then Exit;
  if DarkMode and FileExists(Dir + AName + '-tamna.png') then Exit(Dir + AName + '-tamna.png');
  if FileExists(Dir + AName + '.png') then Result := Dir + AName + '.png';
end;

function SizeSlot(ASize: Integer): Integer;
begin
  case ASize of
    16: Result := 0;
    24: Result := 1;
  else Result := 2;
  end;
end;

function IconPng(const AName: string; ASize: Integer): TPortableNetworkGraphic;
var
  Key, B64, Raw, UFile: string;
  Idx: Integer;
  Ms: TStringStream;
begin
  Key := AName + '@' + IntToStr(ASize) + '@' + IntToStr(Ord(DarkMode));
  if Cache = nil then
  begin
    Cache := TStringList.Create;
    Cache.CaseSensitive := True;
    Cache.OwnsObjects := True;
  end;
  Idx := Cache.IndexOf(Key);
  if Idx >= 0 then Exit(TPortableNetworkGraphic(Cache.Objects[Idx]));
  Result := nil;
  UFile := UserIconFile(AName, ASize);
  if UFile <> '' then
  begin
    Result := TPortableNetworkGraphic.Create;
    try
      Result.LoadFromFile(UFile);
    except
      FreeAndNil(Result);
    end;
    if Result <> nil then begin Cache.AddObject(Key, Result); Exit; end;
  end;
  B64 := IconDataPng(AName, ASize, DarkMode);
  if B64 = '' then Exit;
  Raw := DecodeStringBase64(B64);
  Ms := TStringStream.Create(Raw);
  try
    Result := TPortableNetworkGraphic.Create;
    try
      Result.LoadFromStream(Ms);
    except
      FreeAndNil(Result);
    end;
  finally
    Ms.Free;
  end;
  Cache.AddObject(Key, Result);
end;

function IconList(ASize: Integer): TImageList;
var
  Slot, I: Integer;
  P: TPortableNetworkGraphic;
  Bmp: TBitmap;
begin
  Slot := SizeSlot(ASize);
  if Lists[DarkMode, Slot] <> nil then Exit(Lists[DarkMode, Slot]);
  Lists[DarkMode, Slot] := TImageList.Create(nil);
  Lists[DarkMode, Slot].Width := ASize;
  Lists[DarkMode, Slot].Height := ASize;
  for I := 0 to IconDataCount - 1 do
  begin
    P := IconPng(IconDataName(I), ASize);
    Bmp := TBitmap.Create;
    try
      if P <> nil then Bmp.Assign(P);
      Lists[DarkMode, Slot].Add(Bmp, nil);
    finally
      Bmp.Free;
    end;
  end;
  Result := Lists[DarkMode, Slot];
end;

function IconIndex(const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to IconDataCount - 1 do
    if IconDataName(I) = AName then Exit(I);
  Result := -1;
end;

procedure SetGlyph(AButton: TBitBtn; const AName: string; ASize: Integer);
var
  P: TPortableNetworkGraphic;
begin
  P := IconPng(AName, ASize);
  if P = nil then Exit;
  AButton.Glyph.Assign(P);
  AButton.Layout := blGlyphLeft;
  AButton.Spacing := 4;
end;

function ToolIconFor(const ACaption: string): string;
var
  T: string;
begin
  T := LowerCase(ACaption);
  Result := '';
  if Pos('stranica i nalj', T) > 0 then Result := 'pagesetup'
  else if Pos('spremi', T) > 0 then Result := 'save'
  else if Pos('pregled', T) > 0 then Result := 'preview'
  else if Pos('poništi', T) > 0 then Result := 'undo'
  else if Pos('dupliciraj', T) > 0 then Result := 'duplicate'
  else if Pos('briši', T) > 0 then Result := 'delete'
  else if Pos('poravnaj', T) > 0 then Result := 'align_al'
  else if Pos('izraz', T) > 0 then Result := 'expression'
  else if Pos('dodaj', T) > 0 then Result := 'addfields'
  else if Pos('poredak', T) > 0 then Result := 'filter';
end;

function MakeToolBtn(AParent: TWinControl; const ACaption, AIcon: string; X, Y, W, H: Integer;
  AClick: TNotifyEvent; const AHint: string): TBitBtn;
begin
  Result := TBitBtn.Create(AParent);
  Result.Parent := AParent;
  Result.Caption := ACaption;
  Result.SetBounds(X, Y, W, H);
  Result.OnClick := AClick;
  if AIcon <> '' then SetGlyph(Result, AIcon, 16);
  if AHint <> '' then
  begin
    Result.Hint := AHint;
    Result.ShowHint := True;
  end;
end;

function ControlIconName(const AKind: string): string;
begin
  if AKind = 'MemoBox' then Exit('c_memo');
  Result := 'c_' + LowerCase(AKind);
  if IconIndex(Result) < 0 then Result := '';
end;

{ natpis stavke izbornika -> ikona (prvo poklapanje po dijelu teksta) }
function MenuIconFor(const ACaption: string): string;
const
  Map: array[0..43, 0..1] of string = (
    ('planer', 'run'), ('postavke', 'settings'), ('revizijski', 'search'), ('korisnici', 'info'), ('prava', 'info'),
    ('izgled', 'design'), ('predlošci', 'app'), ('fiskaliz', 'settings'), ('podaci o tvrtki', 'info'), ('priručnik', 'help'),
    ('nov', 'new'), ('otvori', 'open'), ('spremi', 'save'), ('obri', 'delete'), ('uredi', 'design'),
    ('dizajn', 'design'), ('pregled', 'preview'), ('pokreni', 'run'), ('čarobnjak', 'settings'),
    ('uvoz', 'import'), ('izvoz', 'export'), ('pdf', 'pdf'), ('word', 'word'), ('ispis', 'print'),
    ('pomoć', 'help'), ('kako da', 'help'), ('recepti', 'help'), ('pogreške', 'warning'),
    ('izbornika', 'home'), ('početnu', 'home'), ('relacije', 'database'), ('tablic', 'table'),
    ('forma', 'form'), ('upit', 'query'), ('izvješ', 'report'), ('dopis', 'letter'), ('modul', 'module'),
    ('makro', 'macro'), ('4gl', 'program'), ('kopij', 'duplicate'), ('osvježi', 'refresh'),
    ('traži', 'search'), ('filtr', 'filter'), ('sigurnosn', 'save'));
var
  T: string;
  I: Integer;
begin
  Result := '';
  T := UTF8LowerCase(StringReplace(ACaption, '&', '', [rfReplaceAll]));
  for I := 0 to High(Map) do
    if Pos(Map[I, 0], T) > 0 then Exit(Map[I, 1]);
end;

procedure ApplyMenuIcons(AMenu: TMenu);
var
  I: Integer;
  procedure Walk(AItem: TMenuItem);
  var
    I: Integer;
    N: string;
  begin
    for I := 0 to AItem.Count - 1 do
    begin
      N := MenuIconFor(AItem[I].Caption);
      if (N <> '') and (AItem[I].Caption <> '-') then AItem[I].ImageIndex := IconIndex(N);
      if AItem[I].Count > 0 then Walk(AItem[I]);
    end;
  end;
begin
  AMenu.Images := IconList(16);
  { naslovi izbornika u traci ostaju samo tekst; ikone su u padajucim stavkama }
  for I := 0 to AMenu.Items.Count - 1 do Walk(AMenu.Items[I]);
end;

procedure DrawIconItem(AList: TListBox; AIndex: Integer; ARect: TRect; AState: TOwnerDrawState; const AIcon: string);
var
  P: TPortableNetworkGraphic;
  Y: Integer;
begin
  with AList.Canvas do
  begin
    if odSelected in AState then
    begin
      if DarkMode then begin Brush.Color := $5F3A1E; Font.Color := $F0E8E2; end
      else begin Brush.Color := $F3DCC4; Font.Color := clBlack; end;
    end
    else
    begin
      Brush.Color := AList.Color;
      Font.Color := AList.Font.Color;
    end;
    FillRect(ARect);
    P := nil;
    if AIcon <> '' then P := IconPng(AIcon, 16);
    if P <> nil then Draw(ARect.Left + 4, ARect.Top + (ARect.Bottom - ARect.Top - 16) div 2, P);
    Y := ARect.Top + (ARect.Bottom - ARect.Top - TextHeight('Ag')) div 2;
    TextOut(ARect.Left + 26, Y, AList.Items[AIndex]);
  end;
end;

procedure ApplyAppIcon;
var
  P: TPortableNetworkGraphic;
begin
  P := IconPng('app', 32);
  if P <> nil then
    try
      Application.Icon.Assign(P);
    except
    end;
end;

initialization

finalization
  Cache.Free;

end.
