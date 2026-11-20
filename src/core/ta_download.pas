unit ta_download;
{ Preuzimanje datoteka preko HTTPS-a (podaci o utakmicama). Isto ponasanje kao SmartBet (excel.py):
  - ako adresa football-data.co.uk ne odgovori ili vrati gresku 5xx, proba se drugi zapis adrese (s www i bez);
    4xx se ne ponavlja, jer znaci isto na oba;
  - ukupno vrijeme prijenosa je ogranicen satom (sporo servirani izvor ne smije visjeti vjecno);
  - datoteka se pise u privremenu pa se tek zatim premjesta, da prekinut prijenos ne ostavi pola datoteke. }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fphttpclient, opensslsockets;

{ True ako je datoteka preuzeta u ADest; inace AError opisuje zasto nije }
function HttpFetchToFile(const AUrl, ADest: string; ATimeoutSec: Integer; out AError: string): Boolean;
{ druga adresa istog izvora (www <-> bez www) ili '' }
function AlternateHost(const AUrl: string): string;

implementation

type
  TDeadline = class
  public
    Limit: QWord;
    procedure OnData(Sender: TObject; const ContentLength, CurrentPos: Int64);
  end;

procedure TDeadline.OnData(Sender: TObject; const ContentLength, CurrentPos: Int64);
begin
  if GetTickCount64 > Limit then raise Exception.Create('presporo');
end;

function AlternateHost(const AUrl: string): string;
begin
  if Pos('://www.football-data.co.uk', AUrl) > 0 then
    Result := StringReplace(AUrl, '://www.football-data.co.uk', '://football-data.co.uk', [])
  else if Pos('://football-data.co.uk', AUrl) > 0 then
    Result := StringReplace(AUrl, '://football-data.co.uk', '://www.football-data.co.uk', [])
  else
    Result := '';
end;

{ korijenski certifikati operativnog sustava (Debian/Ubuntu, Fedora, Arch/Alpine) }
function CaBundle: string;
const
  Paths: array[0..3] of string = ('/etc/ssl/certs/ca-certificates.crt', '/etc/pki/tls/certs/ca-bundle.crt',
    '/etc/ssl/cert.pem', '/etc/ssl/ca-bundle.pem');
var
  I: Integer;
begin
  for I := 0 to High(Paths) do
    if FileExists(Paths[I]) then Exit(Paths[I]);
  Result := '';
end;

{ jedan pokusaj; ACode: HTTP kod ili 0 kad nije stigao odgovor }
function Attempt(const AUrl, ATemp: string; ATimeoutSec: Integer; out AError: string; out ACode: Integer): Boolean;
var
  C: TFPHTTPClient;
  F: TFileStream;
  D: TDeadline;
begin
  Result := False;
  AError := '';
  ACode := 0;
  C := TFPHTTPClient.Create(nil);
  D := TDeadline.Create;
  F := nil;
  try
    try
      D.Limit := GetTickCount64 + QWord(ATimeoutSec) * 1000;
      C.AllowRedirect := True;
      C.MaxRedirects := 5;
      C.ConnectTimeout := ATimeoutSec * 1000;
      C.IOTimeout := ATimeoutSec * 1000;
      C.VerifySSLCertificate := True;
      C.CertCAFileName := CaBundle;
      C.TrustedCertsDir := '/etc/ssl/certs';
      C.AddHeader('User-Agent', 'smart-betting-app');
      C.OnDataReceived := @D.OnData;
      F := TFileStream.Create(ATemp, fmCreate);
      C.Get(AUrl, F);
      ACode := C.ResponseStatusCode;
      Result := ACode = 200;
      if not Result then AError := AUrl + ': HTTP ' + IntToStr(ACode);
    except
      on E: Exception do
      begin
        ACode := C.ResponseStatusCode;
        AError := AUrl + ': ' + E.Message;
      end;
    end;
  finally
    F.Free;
    D.Free;
    C.Free;
    if not Result then DeleteFile(ATemp);
  end;
end;

function HttpFetchToFile(const AUrl, ADest: string; ATimeoutSec: Integer; out AError: string): Boolean;
var
  Tmp, Alt, Err2: string;
  Code, Code2: Integer;
begin
  Tmp := ADest + '.part';
  ForceDirectories(ExtractFilePath(ExpandFileName(ADest)));
  Result := Attempt(AUrl, Tmp, ATimeoutSec, AError, Code);
  if not Result then
  begin
    { 4xx znaci isto na oba zapisa adrese; ponavlja se samo pri gresci veze ili 5xx }
    Alt := AlternateHost(AUrl);
    if (Alt <> '') and ((Code = 0) or (Code >= 500)) then
    begin
      Result := Attempt(Alt, Tmp, ATimeoutSec, Err2, Code2);
      if Result then AError := '';
    end;
  end;
  if Result then
  begin
    if FileExists(ADest) then DeleteFile(ADest);
    if not RenameFile(Tmp, ADest) then
    begin
      AError := 'ne mogu spremiti ' + ADest;
      Result := False;
    end;
  end;
end;

end.
