program GrepVCL;

uses
  Vcl.Forms,
  MainForm_VCL in 'Source\MainForm_VCL.pas' {MainForm},
  Grep.Core in 'Source\Grep.Core.pas',
  JSONConfig in 'Source\JSONConfig.pas',
  Logger in 'Source\Logger.pas',
  MatchesList in 'Source\MatchesList.pas',
  MatchesDisplay_VCL in 'Source\MatchesDisplay_VCL.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
