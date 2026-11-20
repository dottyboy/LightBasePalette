unit ta_savedfinds;
{ Spremljena trazenja (FileMaker "saved finds"): upit po formi (F7/F8) pod imenom. Sprema se skup filtera "polje=uzorak"
  (isto sto forma drzi kao izvedeni upit), pa ga gumb ili makro moze opet primijeniti jednim klikom:
  savequery:Ime, loadquery:Ime, deletequery:Ime. Zapis je u tablici _sys_finds (forma, naziv, uzorci). }
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, ta_meta;

procedure FindsEnsure(ADb: TAppDb);
{ nazivi spremljenih trazenja za formu (abecedno) }
function FindsList(ADb: TAppDb; const AForm: string): TStringList;
procedure FindsSave(ADb: TAppDb; const AForm, AName: string; APatterns: TStrings);
function FindsLoad(ADb: TAppDb; const AForm, AName: string; APatterns: TStrings): Boolean;
function FindsDelete(ADb: TAppDb; const AForm, AName: string): Boolean;

implementation

uses
  ZDataset;

procedure FindsEnsure(ADb: TAppDb);
begin
  ADb.Conn.ExecuteDirect('CREATE TABLE IF NOT EXISTS _sys_finds (frm VARCHAR(190), nm VARCHAR(190), pat TEXT, PRIMARY KEY (frm, nm))');
end;

function FindsList(ADb: TAppDb; const AForm: string): TStringList;
var
  Q: TZQuery;
begin
  Result := TStringList.Create;
  FindsEnsure(ADb);
  Q := ADb.NewQuery('SELECT nm FROM _sys_finds WHERE frm = ' + ADb.QuoteLit(AForm) + ' ORDER BY nm');
  try
    Q.Open;
    while not Q.EOF do
    begin
      Result.Add(Q.Fields[0].AsString);
      Q.Next;
    end;
  finally
    Q.Free;
  end;
end;

procedure FindsSave(ADb: TAppDb; const AForm, AName: string; APatterns: TStrings);
begin
  FindsEnsure(ADb);
  ADb.Conn.ExecuteDirect('DELETE FROM _sys_finds WHERE frm = ' + ADb.QuoteLit(AForm) + ' AND nm = ' + ADb.QuoteLit(AName));
  ADb.Conn.ExecuteDirect('INSERT INTO _sys_finds (frm, nm, pat) VALUES (' + ADb.QuoteLit(AForm) + ', ' + ADb.QuoteLit(AName) +
    ', ' + ADb.QuoteLit(APatterns.Text) + ')');
end;

function FindsLoad(ADb: TAppDb; const AForm, AName: string; APatterns: TStrings): Boolean;
var
  Q: TZQuery;
begin
  Result := False;
  APatterns.Clear;
  FindsEnsure(ADb);
  Q := ADb.NewQuery('SELECT pat FROM _sys_finds WHERE frm = ' + ADb.QuoteLit(AForm) + ' AND nm = ' + ADb.QuoteLit(AName));
  try
    Q.Open;
    if Q.EOF then Exit;
    APatterns.Text := Q.Fields[0].AsString;
    Result := True;
  finally
    Q.Free;
  end;
end;

function FindsDelete(ADb: TAppDb; const AForm, AName: string): Boolean;
begin
  Result := FindsLoad(ADb, AForm, AName, TStringList.Create);
  FindsEnsure(ADb);
  ADb.Conn.ExecuteDirect('DELETE FROM _sys_finds WHERE frm = ' + ADb.QuoteLit(AForm) + ' AND nm = ' + ADb.QuoteLit(AName));
end;

end.
