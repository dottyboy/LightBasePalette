unit ta_templates;
{ Predlosci projekta za IDE (File > New): "TyphAccess aplikacija" (program s paketima palete i prvom formom)
  i "TyphAccess forma". Koriste se u CodeTyphonu (Light profil i puni IDE). }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, ProjectIntf, LazIDEIntf;

type
  TTaFormFileDescriptor = class(TFileDescPascalUnitWithResource)
  public
    constructor Create; override;
    function GetLocalizedName: string; override;
    function GetLocalizedDescription: string; override;
    function GetInterfaceUsesSection: string; override;
  end;

  TTaApplicationDescriptor = class(TProjectDescriptor)
  public
    constructor Create; override;
    function GetLocalizedName: string; override;
    function GetLocalizedDescription: string; override;
    function InitProject(AProject: TTyphonProject): TModalResult; override;
    function CreateStartFiles(AProject: TTyphonProject): TModalResult; override;
  end;

var
  TaFormFileDescriptor: TTaFormFileDescriptor;

procedure RegisterTemplates;

implementation

const
  ProjDescName = 'TyphAccess aplikacija';

constructor TTaFormFileDescriptor.Create;
begin
  inherited Create;
  Name := 'TyphAccess forma';
  ResourceClass := TForm;
  UseCreateFormStatements := True;
  RequiredPackages := 'adLCL,typhaccess_core,typhaccess_editors';
end;

function TTaFormFileDescriptor.GetLocalizedName: string;
begin
  Result := 'TyphAccess forma';
end;

function TTaFormFileDescriptor.GetLocalizedDescription: string;
begin
  Result := 'Forma za TyphAccess aplikaciju: polja obitelji Edit, baza, izrazi i izvješća iz palete "TyphAccess".';
end;

function TTaFormFileDescriptor.GetInterfaceUsesSection: string;
begin
  Result := inherited GetInterfaceUsesSection + ', Forms, Controls, Graphics, Dialogs, ta_edit, ta_components';
end;

constructor TTaApplicationDescriptor.Create;
begin
  inherited Create;
  Name := ProjDescName;
  Flags := Flags + [pfUseDefaultCompilerOptions];
end;

function TTaApplicationDescriptor.GetLocalizedName: string;
begin
  Result := 'TyphAccess aplikacija';
end;

function TTaApplicationDescriptor.GetLocalizedDescription: string;
begin
  Result := 'Aplikacija s bazom: paketi TyphAccess palete, Zeos i prva forma. Polja, baza i izvjesca slazu se iz palete "TyphAccess".';
end;

function TTaApplicationDescriptor.InitProject(AProject: TTyphonProject): TModalResult;
var
  Src: string;
  MainFile: TTyphonProjectFile;
begin
  Result := inherited InitProject(AProject);
  MainFile := AProject.CreateProjectFile('project1.ppr');
  MainFile.IsPartOfProject := True;
  AProject.AddFile(MainFile, False);
  AProject.MainFileID := 0;
  Src := 'program Project1;' + LineEnding + LineEnding +
    '{$mode objfpc}{$H+}' + LineEnding + LineEnding +
    'uses' + LineEnding +
    '  {$IFDEF UNIX}' + LineEnding +
    '  cthreads,' + LineEnding +
    '  {$ENDIF}' + LineEnding +
    '  Interfaces, // CodeTyphon adLCL widgetset' + LineEnding +
    '  Forms' + LineEnding +
    '  { dodajte jedinice nakon ove crte };' + LineEnding + LineEnding +
    'begin' + LineEnding +
    '  RequireDerivedFormResource := True;' + LineEnding +
    '  Application.Scaled := True;' + LineEnding +
    '  Application.Initialize;' + LineEnding +
    '  Application.Run;' + LineEnding +
    'end.' + LineEnding;
  AProject.MainFile.SetSourceText(Src, True);
  AProject.AddPackageDependency('adLCL');
  AProject.AddPackageDependency('pl_ZeosDBO');
  AProject.AddPackageDependency('typhaccess_core');
  AProject.AddPackageDependency('typhaccess_editors');
  AProject.AddPackageDependency('typhaccess_dsgn');
  AProject.TyphonCompilerOptions.Win32GraphicApp := True;
  AProject.TyphonCompilerOptions.UnitOutputDirectory := 'lib' + PathDelim + '$(TargetCPU)-$(TargetOS)';
  AProject.TyphonCompilerOptions.TargetFilename := 'project1';
end;

function TTaApplicationDescriptor.CreateStartFiles(AProject: TTyphonProject): TModalResult;
begin
  Result := TyphonIDE.DoNewEditorFile(TaFormFileDescriptor, '', '',
    [nfIsPartOfProject, nfOpenInEditor, nfCreateDefaultSrc]);
end;

procedure RegisterTemplates;
begin
  TaFormFileDescriptor := TTaFormFileDescriptor.Create;
  RegisterProjectFileDescriptor(TaFormFileDescriptor);
  RegisterProjectDescriptor(TTaApplicationDescriptor.Create);
end;

end.
