unit ta_fiscalhook;
{ Kuke za neobavezni modul fiskalizacije (modules/fiskalizacija, nije dio objavljenog koda).
  Aplikacija se prevodi i radi bez njega: izbornik ne pokazuje fiskalizaciju, a brojevi dokumenata koriste 1/1.
  Modul pri pokretanju (jedinica ta_fiscalreg, uz -dTA_FISCAL) upisuje ove kuke. }

{$mode objfpc}{$H+}

interface

uses
  Classes, ta_meta;

type
  TFiscalSetupProc = procedure(AOwner: TComponent; ADb: TAppDb);
  TFiscalUseDbProc = procedure(ADb: TAppDb);
  { oznake poslovnog prostora i naplatnog uredaja iz postavki modula; False ako postavki nema }
  TFiscalMarksFunc = function(ADb: TAppDb; out APP, ANU: string; out AOnDevice: Boolean): Boolean;

var
  FiscalSetupHook: TFiscalSetupProc = nil;
  FiscalUseDbHook: TFiscalUseDbProc = nil;
  FiscalMarksHook: TFiscalMarksFunc = nil;

{ je li modul prisutan (izbornik "Fiskalizacija" se pokazuje samo tada) }
function FiscalAvailable: Boolean;

implementation

function FiscalAvailable: Boolean;
begin
  Result := Assigned(FiscalSetupHook);
end;

end.
