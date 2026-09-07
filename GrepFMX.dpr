program GrepFMX;

uses
  System.StartUpCopy,
  FMX.Forms,
  MainForm_FMX in 'Source\MainForm_FMX.pas' {MainForm},
  Grep.Core in 'Source\Grep.Core.pas',
  JSONConfig in 'Source\JSONConfig.pas',
  Logger in 'Source\Logger.pas',
  MatchesList in 'Source\MatchesList.pas',
  MatchesDisplay_FMX in 'Source\MatchesDisplay_FMX.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
