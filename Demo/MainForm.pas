unit MainForm;

interface

uses
  Winapi.Windows, Winapi.Messages,
  System.SysUtils, System.Classes,
  Vcl.Forms, Vcl.StdCtrls,
  Grep.Core;

type
  TFormMain = class(TForm)
    btnSearch: TButton;
    MemoResults: TMemo;
    procedure FormCreate(Sender: TObject);
    procedure btnSearchClick(Sender: TObject);
  private
    FGrep: TGrep;
  end;

var
  FormMain: TFormMain;

implementation

{$R *.dfm}

procedure TFormMain.FormCreate(Sender: TObject);
begin
  FGrep := TGrep.Create;

  FGrep.OnFileFound :=
    procedure(const aFilename: string)
    begin
      TThread.Queue(nil,
        procedure
        begin
          MemoResults.Lines.Add('Found: ' + aFilename);
        end);
    end;

  FGrep.OnRequestedContents :=
    procedure(aContents: TObjectList<TMatchedLines>)
    var
      ML: TMatchedLines;
    begin
      TThread.Queue(nil,
        procedure
        begin
          MemoResults.Lines.Add('--- Requested Contents ---');
          for ML in aContents do
            MemoResults.Lines.Add(
              Format('%s (%d): %s', [ML.Filename, ML.LineNumber, ML.MatchedValue])
            );
        end);
    end;
end;

procedure TFormMain.btnSearchClick(Sender: TObject);
begin
  FGrep.SearchMode := gsmText;
  FGrep.SearchText := 'TODO';
  FGrep.Wildcards := '*.pas';
  FGrep.IncludeSubfolders := True;

  FGrep.Search('C:\MyProject');
end;

end.
