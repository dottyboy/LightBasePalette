unit ta_filestoredlg;
{ Dijalog "Pohrana datoteka": gdje se čuvaju slike, promjena mape, pretvorba starih slika iz baze. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, StdCtrls, Dialogs, ExtCtrls, ta_meta, ta_filestore;

procedure RunFileStoreDialog(AOwner: TComponent; ADb: TAppDb);

implementation

uses
  ta_i18n;


type
  TStoreDlg = class
  public
    Form: TForm;
    Info: TMemo;
    Db: TAppDb;
    procedure Refresh;
    procedure ChangeClick(Sender: TObject);
    procedure DefaultClick(Sender: TObject);
    procedure ConvertClick(Sender: TObject);
    procedure CleanClick(Sender: TObject);
  end;

procedure TStoreDlg.Refresh;
var
  Root, Src, S: string;
  Shared: Boolean;
  N: Integer;
  Size: Int64;
begin
  Root := FileStoreRoot(Db, Src, Shared);
  N := FileStoreStats(Db, Size);
  S := 'Mapa pohrane:' + LineEnding + '  ' + Root + LineEnding + LineEnding +
    Tr('Determined: ') + Src + LineEnding +
    'Datoteka u mapi: ' + IntToStr(N) + ' (' + IntToStr(Size div 1024) + ' KB)' + LineEnding + LineEnding +
    Tr('Only the link is kept in the database (e.g. slike/kupac/20261103-logo.png); the picture is a file in this folder.') + LineEnding +
    Tr('Order of choosing the folder: environment variable ') + StoreEnvVar + ', postavka baze, zadano.';
  if not Shared then
    S := S + LineEnding + LineEnding + Tr('WARNING: this is a folder in your user profile, it is not shared with other computers. ') +
      Tr('For network work set a shared folder (network drive) with the "Change folder" button.');
  Info.Text := S;
end;

procedure TStoreDlg.ChangeClick(Sender: TObject);
var
  D: TSelectDirectoryDialog;
begin
  D := TSelectDirectoryDialog.Create(nil);
  try
    D.Title := Tr('Folder for pictures and files');
    D.InitialDir := FileStoreRootOnly(Db);
    if D.Execute then
    begin
      SetFileStoreFolder(Db, D.FileName);
      ShowMessage(Tr('New files go to: ') + D.FileName + LineEnding +
        Tr('Existing files were not moved: copy the content of the old folder into the new one.'));
      Refresh;
    end;
  finally
    D.Free;
  end;
end;

procedure TStoreDlg.DefaultClick(Sender: TObject);
begin
  SetFileStoreFolder(Db, '');
  Refresh;
end;

procedure TStoreDlg.CleanClick(Sender: TObject);
var
  Orph, Log: TStringList;
  N, I: Integer;
  Lst: string;
begin
  Orph := TStringList.Create;
  Log := TStringList.Create;
  try
    try
      N := FindOrphanFiles(Db, Orph);
      if N = 0 then begin ShowMessage(Tr('All files in the store have a link in the database.')); Exit; end;
      Lst := '';
      for I := 0 to Orph.Count - 1 do
      begin
        if I >= 15 then begin Lst := Lst + LineEnding + Tr('... and ') + IntToStr(Orph.Count - 15); Break; end;
        Lst := Lst + LineEnding + Orph[I];
      end;
      if MessageDlg(Tr('File without a link in the database: ') + IntToStr(N) + LineEnding + Lst + LineEnding + LineEnding +
        Tr('Move them to the subfolder _neiskoristeno? (Nothing is deleted; you can delete the folder later or put the files back.) ') +
        Tr('Careful: files you use outside the Picture field and pictures in forms/reports (e.g. from 4GL programs) will also be on the list.'),
        mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
      N := MoveOrphanFiles(Db, Log);
      ShowMessage(Tr('Files moved: ') + IntToStr(N));
      Refresh;
    except
      on E: Exception do ShowMessage(Tr('Cleanup failed: ') + E.Message);
    end;
  finally
    Orph.Free;
    Log.Free;
  end;
end;

procedure TStoreDlg.ConvertClick(Sender: TObject);
var
  Log: TStringList;
  N, M: Integer;
begin
  if MessageDlg(Tr('Pictures stored in the database (BLOB fields and pictures embedded in forms and reports) are moved to files, and a link stays in the field. ') +
    Tr('It is recommended to make a backup of the database first. Continue?'), mtConfirmation, [mbYes, mbNo], 0) <> mrYes then Exit;
  Log := TStringList.Create;
  try
    try
      N := ConvertBlobPictures(Db, Log);
      M := ConvertDefinitionPictures(Db, Log);
      ShowMessage(Tr('Fields converted: ') + IntToStr(N) + LineEnding +
        Tr('Pictures converted in forms and reports: ') + IntToStr(M) + LineEnding + Log.Text);
    except
      on E: Exception do ShowMessage(Tr('Conversion failed: ') + E.Message + LineEnding + Log.Text);
    end;
  finally
    Log.Free;
  end;
  Refresh;
end;

procedure RunFileStoreDialog(AOwner: TComponent; ADb: TAppDb);
var
  D: TStoreDlg;
  Pn: TPanel;

  procedure Btn(const ACap: string; AX, AW: Integer; AHandler: TNotifyEvent);
  var
    B: TButton;
  begin
    B := TButton.Create(D.Form);
    B.Parent := Pn;
    B.Caption := ACap;
    B.SetBounds(AX, 6, AW, 28);
    B.OnClick := AHandler;
  end;

begin
  D := TStoreDlg.Create;
  D.Db := ADb;
  D.Form := TForm.CreateNew(AOwner);
  try
    D.Form.Caption := Tr('File store');
    D.Form.SetBounds(0, 0, 720, 420);
    D.Form.Position := poOwnerFormCenter;
    Pn := TPanel.Create(D.Form);
    Pn.Parent := D.Form;
    Pn.Align := alBottom;
    Pn.Height := 40;
    Pn.BevelOuter := bvNone;
    Btn(Tr('Change folder...'), 8, 140, @D.ChangeClick);
    Btn(Tr('Restore default'), 156, 110, @D.DefaultClick);
    Btn(Tr('Convert pictures from the database'), 274, 170, @D.ConvertClick);
    Btn(Tr('Clean up unused'), 452, 150, @D.CleanClick);
    with TButton.Create(D.Form) do
    begin
      Parent := Pn; Caption := Tr('Close'); ModalResult := mrOk; SetBounds(610, 6, 96, 28); Default := True;
    end;
    D.Info := TMemo.Create(D.Form);
    D.Info.Parent := D.Form;
    D.Info.Align := alClient;
    D.Info.ReadOnly := True;
    D.Info.ScrollBars := ssAutoVertical;
    D.Refresh;
    D.Form.ShowModal;
  finally
    D.Form.Free;
    D.Free;
  end;
end;

end.
