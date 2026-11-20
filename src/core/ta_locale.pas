unit ta_locale;
{ Hrvatski zapis brojeva u prikazima i izvjescima: 1.234,50.
  Pohrana i parsiranje ostaju nezavisni (InvariantFS / ParseFS imaju tocku). }

{$mode objfpc}{$H+}

interface

{ Postavlja zadane postavke formata (zarez za decimale, tocka za tisucice). }
procedure UseCroatianFormats;

implementation

uses
  SysUtils;

procedure UseCroatianFormats;
begin
  DefaultFormatSettings.DecimalSeparator := ',';
  DefaultFormatSettings.ThousandSeparator := '.';
  DefaultFormatSettings.DateSeparator := '.';
  DefaultFormatSettings.ShortDateFormat := 'dd.mm.yyyy';
  DefaultFormatSettings.CurrencyString := '€';
end;

end.
