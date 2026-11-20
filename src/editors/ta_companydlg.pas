unit ta_companydlg;
{ Podaci o tvrtki (u postavkama baze): koriste ih izrazi Postavka("firma.naziv")
  i HUB3 barkod na računima. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, ta_meta;

const
  CompanyKeys: array[0..6] of string = (
    'firma.naziv', 'firma.adresa', 'firma.mjesto', 'firma.oib', 'firma.iban', 'firma.email', 'firma.telefon');

{ True kad su podaci spremljeni. }
function RunCompanyProfile(AOwner: TComponent; ADb: TAppDb): Boolean;

implementation

uses
  ta_i18n;


const
  Captions: array[0..6] of string = (
    'Naziv tvrtke', 'Adresa (ulica i broj)', 'Poštanski broj i mjesto', 'OIB', 'IBAN', 'E-mail', 'Telefon');

function RunCompanyProfile(AOwner: TComponent; ADb: TAppDb): Boolean;
var
  F: TForm;
  Edits: array[0..6] of TEdit;
  I: Integer;
begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := Tr('Company data');
    F.SetBounds(0, 0, 460, 420);
    F.Position := poOwnerFormCenter;
    for I := 0 to 6 do
    begin
      with TLabel.Create(F) do begin Parent := F; Caption := Tr(Captions[I]); SetBounds(14, 12 + I * 48, 400, 18); end;
      Edits[I] := TEdit.Create(F);
      Edits[I].Parent := F;
      Edits[I].SetBounds(14, 32 + I * 48, 420, 26);
      Edits[I].Text := ADb.LoadSetting(CompanyKeys[I]);
    end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Save'); ModalResult := mrOk; Default := True; SetBounds(230, 360, 100, 30); end;
    with TButton.Create(F) do begin Parent := F; Caption := Tr('Cancel'); ModalResult := mrCancel; Cancel := True; SetBounds(338, 360, 100, 30); end;
    if F.ShowModal = mrOk then
    begin
      for I := 0 to 6 do ADb.SaveSetting(CompanyKeys[I], Trim(Edits[I].Text));
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

end.
