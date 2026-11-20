unit ta_richbase;
{ Zajednicka osnova uredjivaca formatiranog teksta: ista sucelja ima uredjivac na RichMemu (TaRichEdit)
  i vlastiti iscrtani (TaOwnRichEdit). Forma, obitelj Memo i testovi znaju samo za ovu osnovu. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Controls, ExtCtrls, ta_richtext;

type
  TaRichBase = class(TPanel)
  protected
    FOnChanged: TNotifyEvent;
    FReadOnly: Boolean;
    function GetHtml: string; virtual; abstract;
    procedure SetHtml(const AValue: string); virtual; abstract;
    procedure SetReadOnly(AValue: Boolean); virtual;
  public
    Tag2: Pointer;
    { opis kontrole na formi (TaControlDef); ta_controls ga postavlja }
    DefObj: TObject;
    property Html: string read GetHtml write SetHtml;
    property ReadOnly: Boolean read FReadOnly write SetReadOnly;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
    { za testove i izbornike: uredjivanje bez misa; AStart/ALen su znakovi cijelog teksta (odlomci spojeni novim retkom) }
    procedure SelectRange(AStart, ALen: Integer); virtual; abstract;
    procedure ApplyBold; virtual; abstract;
    procedure ApplyItalic; virtual; abstract;
    procedure ApplyUnderline; virtual; abstract;
    procedure ApplyColorRgb(ARgb: Integer); virtual; abstract;
    procedure ApplySizePt(APt: Integer); virtual; abstract;
    procedure ApplyAlign(AAlign: TRtAlign); virtual; abstract;
    procedure ApplyBullet; virtual; abstract;
  end;

  TaRichFactory = function(AOwner: TComponent): TaRichBase;

var
  { postavlja ih ta_richedit (RichMemo) i ta_ownrich (vlastiti) }
  RichLclFactory: TaRichFactory = nil;
  RichOwnFactory: TaRichFactory = nil;

{ novi uredjivac prema pruzatelju: 'own' daje vlastiti, inace RichMemo }
function NewRichEditor(AOwner: TComponent): TaRichBase;

implementation

uses
  ta_family;

procedure TaRichBase.SetReadOnly(AValue: Boolean);
begin
  FReadOnly := AValue;
end;

function NewRichEditor(AOwner: TComponent): TaRichBase;
begin
  if (PreferredProvider = 'own') and Assigned(RichOwnFactory) then Result := RichOwnFactory(AOwner)
  else Result := RichLclFactory(AOwner);
end;

end.
