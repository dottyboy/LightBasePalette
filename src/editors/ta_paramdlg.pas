unit ta_paramdlg;
{ Dijalog "Unesi parametre" za upite s oznakama [?Naziv]. Registrira se kao
  ParamPromptHook, pa ga TAppDb sam otvori kad upit trazi vrijednosti. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs, ta_params;

{ ANames: sto se pita; AValues: Naziv=Vrijednost (zadane vrijednosti i odgovori). }
function PromptQueryParams(ANames, AValues: TStrings): Boolean;

{ Dijalog "Spoji na poslužitelj": Postgres ili MariaDB. Lozinka se ne pamti. }
function ConnectServerDialog(AOwner: TComponent; var AMaria: Boolean;
  var AHost: string; var APort: Integer; var ADb, AUser, APwd: string): Boolean;

implementation

uses
  ta_i18n;


function PromptQueryParams(ANames, AValues: TStrings): Boolean;
var
  F: TForm;
  Edits: array of TEdit;
  I, Y: Integer;
  Lb: TLabel;
  Ok, Cancel: TButton;
begin
  Result := False;
  if ANames.Count = 0 then Exit(True);
  F := TForm.CreateNew(nil);
  try
    F.Caption := Tr('Enter query parameters');
    F.Position := poScreenCenter;
    F.BorderStyle := bsDialog;
    SetLength(Edits, ANames.Count);
    Y := 14;
    for I := 0 to ANames.Count - 1 do
    begin
      Lb := TLabel.Create(F);
      Lb.Parent := F;
      Lb.Caption := ANames[I];
      Lb.SetBounds(14, Y, 380, 18);
      Edits[I] := TEdit.Create(F);
      Edits[I].Parent := F;
      Edits[I].SetBounds(14, Y + 20, 380, 26);
      Edits[I].Text := AValues.Values[ANames[I]];
      Inc(Y, 56);
    end;
    Lb := TLabel.Create(F);
    Lb.Parent := F;
    Lb.Caption := Tr('Date: 31.12.2026 or 2026-12-31. An empty field = no value (NULL).');
    Lb.SetBounds(14, Y - 4, 380, 32);
    Lb.WordWrap := True;
    Ok := TButton.Create(F);
    Ok.Parent := F; Ok.Caption := Tr('OK'); Ok.ModalResult := mrOk; Ok.Default := True;
    Ok.SetBounds(194, Y + 34, 96, 30);
    Cancel := TButton.Create(F);
    Cancel.Parent := F; Cancel.Caption := Tr('Cancel'); Cancel.ModalResult := mrCancel; Cancel.Cancel := True;
    Cancel.SetBounds(298, Y + 34, 96, 30);
    F.ClientWidth := 408;
    F.ClientHeight := Y + 78;
    if F.ShowModal = mrOk then
    begin
      for I := 0 to ANames.Count - 1 do AValues.Values[ANames[I]] := Edits[I].Text;
      Result := True;
    end;
  finally
    F.Free;
  end;
end;

function ConnectServerDialog(AOwner: TComponent; var AMaria: Boolean;
  var AHost: string; var APort: Integer; var ADb, AUser, APwd: string): Boolean;
var
  F: TForm;
  Kind: TComboBox;
  EHost, EPort, EDb, EUser, EPwd: TEdit;
  Ok, Cancel: TButton;

  function AddEdit(const ACaption, AText: string; Y: Integer): TEdit;
  var
    Lb: TLabel;
  begin
    Lb := TLabel.Create(F);
    Lb.Parent := F;
    Lb.Caption := ACaption;
    Lb.SetBounds(14, Y, 380, 18);
    Result := TEdit.Create(F);
    Result.Parent := F;
    Result.SetBounds(14, Y + 20, 380, 26);
    Result.Text := AText;
  end;

begin
  Result := False;
  F := TForm.CreateNew(AOwner);
  try
    F.Caption := Tr('Connect to a server');
    F.Position := poScreenCenter;
    F.BorderStyle := bsDialog;
    with TLabel.Create(F) do
    begin
      Parent := F; Caption := Tr('Database type'); SetBounds(14, 14, 380, 18);
    end;
    Kind := TComboBox.Create(F);
    Kind.Parent := F;
    Kind.Style := csDropDownList;
    Kind.Items.Add('PostgreSQL');
    Kind.Items.Add('MariaDB / MySQL');
    if AMaria then Kind.ItemIndex := 1 else Kind.ItemIndex := 0;
    Kind.SetBounds(14, 34, 380, 26);
    EHost := AddEdit('Poslužitelj', AHost, 70);
    EPort := AddEdit('Port (prazno = zadani)', IntToStr(APort), 126);
    EDb := AddEdit('Baza', ADb, 182);
    EUser := AddEdit('Korisnik', AUser, 238);
    EPwd := AddEdit('Lozinka', '', 294);
    EPwd.PasswordChar := '*';
    Ok := TButton.Create(F);
    Ok.Parent := F; Ok.Caption := Tr('Connect'); Ok.ModalResult := mrOk; Ok.Default := True;
    Ok.SetBounds(194, 358, 96, 30);
    Cancel := TButton.Create(F);
    Cancel.Parent := F; Cancel.Caption := Tr('Cancel'); Cancel.ModalResult := mrCancel; Cancel.Cancel := True;
    Cancel.SetBounds(298, 358, 96, 30);
    F.ClientWidth := 408;
    F.ClientHeight := 402;
    if F.ShowModal = mrOk then
    begin
      AMaria := Kind.ItemIndex = 1;
      AHost := Trim(EHost.Text);
      if AHost = '' then AHost := 'localhost';
      if AMaria then APort := StrToIntDef(Trim(EPort.Text), 3306)
      else APort := StrToIntDef(Trim(EPort.Text), 5432);
      ADb := Trim(EDb.Text);
      AUser := Trim(EUser.Text);
      APwd := EPwd.Text;
      Result := (ADb <> '') and (AUser <> '');
      if not Result then ShowMessage(Tr('The database and the user are required.'));
    end;
  finally
    F.Free;
  end;
end;

initialization
  ParamPromptHook := @PromptQueryParams;

end.
