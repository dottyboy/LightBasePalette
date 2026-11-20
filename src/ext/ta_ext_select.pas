unit ta_ext_select;
{ Bira zadanog pruzatelja pokretaca pri pokretanju: varijabla okoline TYPHACCESS_PROVIDER ('tachart' ili 'rx').
  Paket typhaccess_ext sam registrira pokretace, ali ih obitelji koriste tek kad je pruzatelj odabran; u IDE-u
  (Light) se tako bira bez prevodenja: TYPHACCESS_PROVIDER=tachart light/typhon-light.sh }
{$mode objfpc}{$H+}
interface

implementation

uses
  SysUtils, ta_family;

initialization
  if GetEnvironmentVariable('TYPHACCESS_PROVIDER') <> '' then
    SetPreferredProvider(GetEnvironmentVariable('TYPHACCESS_PROVIDER'));

end.
