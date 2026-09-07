unit MatchesDisplay_VCL;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Math,
  System.Types,
  System.IOUtils,
  System.Generics.Collections,
  Winapi.Windows,
  Winapi.Messages,
  Vcl.Controls,
  Vcl.ExtCtrls,
  Vcl.Forms,
  Vcl.Graphics,
  MatchesList;

type
  TMatchesData = MatchesList.TMatchesData;

  TMatchPanel = class(TCustomControl)
  private
    FData: TMatchesData;
    FMeasureBitmap: TBitmap;
    FTitleLines: TStringList;
    FMetaLines: TStringList;
    FAboveLines: TStringList;
    FMatchLines: TStringList;
    FBelowLines: TStringList;
    FTextLeft: Integer;
    FTextWidth: Integer;
    FOnToggle: TNotifyEvent;
    procedure DrawBackground(ACanvas: TCanvas);
    procedure DrawHeader(ACanvas: TCanvas; var ATop: Integer);
    procedure DrawContext(ACanvas: TCanvas; var ATop: Integer);
    procedure DrawHint(ACanvas: TCanvas; var ATop: Integer);
    procedure UpdateCachedText;
    procedure UpdateLayout;
  protected
    procedure Paint; override;
    procedure Resize; override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer); override;
  public
    constructor Create(AOwner: TComponent; AData: TMatchesData); reintroduce;
    destructor Destroy; override;
    procedure RecalculateLayout;
    property OnToggle: TNotifyEvent read FOnToggle write FOnToggle;
  end;

  TMatchesDisplay = class
  private
    FScrollBox: TScrollBox;
    FMatches: TMatchesList;
    FLayoutUpdating: Boolean;
    FLastContentWidth: Integer;
    function GetContentWidth: Integer;
    function GetNextPanelTop: Integer;
    procedure UpdateScrollRange;
    procedure AddPanelForMatch(const AData: TMatchesData);
    procedure RelayoutPanels(const ARecalculateLayout: Boolean);
    procedure RelayoutFromPanel(APanel: TMatchPanel; const ADeltaHeight: Integer);
    procedure MatchPanelToggled(Sender: TObject);
    procedure ScrollBoxResize(Sender: TObject);
  public
    constructor Create(AOwner: TComponent; AScrollBox: TScrollBox); overload;
    destructor Destroy; override;
    procedure SetScrollBox(AScrollBox: TScrollBox);
    procedure ClearBrowser;
    procedure AddMatch(const AData: TMatchesData);
    procedure AddMatches(const AData: TObjectList<TMatchesData>);
    function GetScrollBox: TScrollBox;
    property Matches: TMatchesList read FMatches;
  end;

implementation

const
  cPanelMargin = 16;
  cPanelPadding = 16;
  cPanelSpacing = 6;
  cMinPanelHeight = 92;
  cTitleFontSize = 11;
  cMetaFontSize = 9;
  cBodyFontSize = 10;

function NormalizeLineBreaks(const AText: string): string;
begin
  Result := StringReplace(AText, #13#10, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #13, #10, [rfReplaceAll]);
  Result := StringReplace(Result, #10, sLineBreak, [rfReplaceAll]);
end;

function TextLineHeight(ACanvas: TCanvas): Integer;
begin
  Result := ACanvas.TextHeight('Wg') + 1;
end;

procedure AddWrappedParagraph(ACanvas: TCanvas; ALines: TStrings; const AParagraph: string;
  const AMaxWidth: Integer);
var
  Words: TStringList;
  CurrentLine: string;
  Candidate: string;
  I: Integer;
begin
  if AParagraph = '' then
  begin
    ALines.Add('');
    Exit;
  end;

  Words := TStringList.Create;
  try
    ExtractStrings([' '], [], PChar(AParagraph), Words);
    if Words.Count = 0 then
    begin
      ALines.Add(AParagraph);
      Exit;
    end;

    CurrentLine := '';
    for I := 0 to Words.Count - 1 do
    begin
      if CurrentLine = '' then
        Candidate := Words[I]
      else
        Candidate := CurrentLine + ' ' + Words[I];

      if (AMaxWidth > 0) and (CurrentLine <> '') and (ACanvas.TextWidth(Candidate) > AMaxWidth) then
      begin
        ALines.Add(CurrentLine);
        CurrentLine := Words[I];
      end
      else
        CurrentLine := Candidate;
    end;

    if CurrentLine <> '' then
      ALines.Add(CurrentLine);
  finally
    Words.Free;
  end;
end;

procedure BuildWrappedLines(ACanvas: TCanvas; const AText: string; const AMaxWidth: Integer;
  ALines: TStrings);
var
  SourceLines: TStringList;
  I: Integer;
begin
  ALines.Clear;
  SourceLines := TStringList.Create;
  try
    SourceLines.Text := NormalizeLineBreaks(AText);
    if SourceLines.Count = 0 then
      SourceLines.Add('');

    for I := 0 to SourceLines.Count - 1 do
      AddWrappedParagraph(ACanvas, ALines, SourceLines[I], AMaxWidth);
  finally
    SourceLines.Free;
  end;
end;

procedure BuildWrappedSourceLines(ACanvas: TCanvas; ASourceLines, ADestination: TStrings;
  const AMaxWidth: Integer);
var
  I: Integer;
begin
  ADestination.Clear;
  for I := 0 to ASourceLines.Count - 1 do
    AddWrappedParagraph(ACanvas, ADestination, ASourceLines[I], AMaxWidth);
end;

{ TMatchPanel }

constructor TMatchPanel.Create(AOwner: TComponent; AData: TMatchesData);
begin
  inherited Create(AOwner);
  ControlStyle := ControlStyle + [csOpaque];
  FData := AData;
  FMeasureBitmap := TBitmap.Create;
  FTitleLines := TStringList.Create;
  FMetaLines := TStringList.Create;
  FAboveLines := TStringList.Create;
  FMatchLines := TStringList.Create;
  FBelowLines := TStringList.Create;
  Height := cMinPanelHeight;
  Align := alNone;
end;

destructor TMatchPanel.Destroy;
begin
  FBelowLines.Free;
  FMatchLines.Free;
  FAboveLines.Free;
  FMetaLines.Free;
  FTitleLines.Free;
  FMeasureBitmap.Free;
  inherited;
end;

procedure TMatchPanel.UpdateCachedText;
var
  FileNameOnly: string;
  MetaText: string;
begin
  FTextLeft := cPanelPadding;
  FTextWidth := Max(220, ClientWidth - FTextLeft - cPanelPadding);

  FileNameOnly := TPath.GetFileName(FData.Filename);
  if FileNameOnly = '' then
    FileNameOnly := FData.Filename;

  MetaText := Format('Line %d  •  %s  •  %s',
    [FData.LineNumber, FormatDateTime('yyyy-mm-dd hh:nn:ss', FData.FileTimestamp), FData.Filename]);

  FMeasureBitmap.Canvas.Font.Name := 'Segoe UI';
  FMeasureBitmap.Canvas.Font.Size := cTitleFontSize;
  FMeasureBitmap.Canvas.Font.Style := [fsBold];
  BuildWrappedLines(FMeasureBitmap.Canvas, FileNameOnly, FTextWidth, FTitleLines);

  FMeasureBitmap.Canvas.Font.Size := cMetaFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  BuildWrappedLines(FMeasureBitmap.Canvas, MetaText, FTextWidth, FMetaLines);

  FMeasureBitmap.Canvas.Font.Size := cBodyFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  BuildWrappedSourceLines(FMeasureBitmap.Canvas, FData.LinesAbove, FAboveLines, FTextWidth);
  BuildWrappedSourceLines(FMeasureBitmap.Canvas, FData.LinesBelow, FBelowLines, FTextWidth);

  FMeasureBitmap.Canvas.Font.Style := [fsBold];
  BuildWrappedLines(FMeasureBitmap.Canvas, FData.MatchValue, FTextWidth, FMatchLines);
end;

procedure TMatchPanel.UpdateLayout;
var
  TotalHeight: Integer;
  LineHeight: Integer;
begin
  if (Parent = nil) or (ClientWidth <= 0) then
    Exit;

  UpdateCachedText;

  FMeasureBitmap.Canvas.Font.Name := 'Segoe UI';
  TotalHeight := cPanelPadding;

  FMeasureBitmap.Canvas.Font.Size := cTitleFontSize;
  FMeasureBitmap.Canvas.Font.Style := [fsBold];
  LineHeight := TextLineHeight(FMeasureBitmap.Canvas);
  Inc(TotalHeight, Max(1, FTitleLines.Count) * LineHeight);
  Inc(TotalHeight, cPanelSpacing);

  FMeasureBitmap.Canvas.Font.Size := cMetaFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  LineHeight := TextLineHeight(FMeasureBitmap.Canvas);
  Inc(TotalHeight, Max(1, FMetaLines.Count) * LineHeight);
  Inc(TotalHeight, cPanelSpacing + 4);

  FMeasureBitmap.Canvas.Font.Size := cBodyFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  LineHeight := TextLineHeight(FMeasureBitmap.Canvas);
  if FData.Expanded then
    Inc(TotalHeight, FAboveLines.Count * LineHeight);

  FMeasureBitmap.Canvas.Font.Style := [fsBold];
  LineHeight := TextLineHeight(FMeasureBitmap.Canvas);
  Inc(TotalHeight, Max(1, FMatchLines.Count) * LineHeight);
  Inc(TotalHeight, cPanelSpacing);

  FMeasureBitmap.Canvas.Font.Style := [];
  LineHeight := TextLineHeight(FMeasureBitmap.Canvas);
  if FData.Expanded then
    Inc(TotalHeight, FBelowLines.Count * LineHeight);

  Inc(TotalHeight, LineHeight + cPanelPadding);
  Height := Max(cMinPanelHeight, TotalHeight);
end;

procedure TMatchPanel.DrawBackground(ACanvas: TCanvas);
begin
  ACanvas.Brush.Color := clWhite;
  ACanvas.FillRect(ClientRect);

  ACanvas.Pen.Color := RGB(224, 229, 236);
  ACanvas.MoveTo(0, Height - 1);
  ACanvas.LineTo(Width, Height - 1);
end;

procedure TMatchPanel.DrawHeader(ACanvas: TCanvas; var ATop: Integer);
var
  LineHeight: Integer;
  I: Integer;
begin
  FMeasureBitmap.Canvas.Font.Name := 'Segoe UI';
  FMeasureBitmap.Canvas.Font.Size := cTitleFontSize;
  FMeasureBitmap.Canvas.Font.Style := [fsBold];
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Size := cTitleFontSize;
  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := RGB(32, 45, 64);
  LineHeight := TextLineHeight(FMeasureBitmap.Canvas);
  for I := 0 to FTitleLines.Count - 1 do
  begin
    ACanvas.TextOut(FTextLeft, ATop, FTitleLines[I]);
    Inc(ATop, LineHeight);
  end;

  Inc(ATop, cPanelSpacing);

  FMeasureBitmap.Canvas.Font.Size := cMetaFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  ACanvas.Font.Size := cMetaFontSize;
  ACanvas.Font.Style := [];
  ACanvas.Font.Color := clGrayText;
  LineHeight := TextLineHeight(FMeasureBitmap.Canvas);
  for I := 0 to FMetaLines.Count - 1 do
  begin
    ACanvas.TextOut(FTextLeft, ATop, FMetaLines[I]);
    Inc(ATop, LineHeight);
  end;

  Inc(ATop, cPanelSpacing + 4);
end;

procedure TMatchPanel.DrawContext(ACanvas: TCanvas; var ATop: Integer);
var
  LineHeight: Integer;
  I: Integer;
  HighlightRect: TRect;
begin
  FMeasureBitmap.Canvas.Font.Name := 'Consolas';
  FMeasureBitmap.Canvas.Font.Size := cBodyFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  ACanvas.Font.Name := 'Consolas';
  ACanvas.Font.Size := cBodyFontSize;
  ACanvas.Font.Style := [];
  LineHeight := TextLineHeight(FMeasureBitmap.Canvas);

  if FData.Expanded then
  begin
    ACanvas.Font.Color := RGB(110, 117, 129);
    for I := 0 to FAboveLines.Count - 1 do
    begin
      ACanvas.TextOut(FTextLeft, ATop, FAboveLines[I]);
      Inc(ATop, LineHeight);
    end;
  end;

  HighlightRect := Rect(FTextLeft - 8, ATop - 2, FTextLeft + FTextWidth + 8,
    ATop + (Max(1, FMatchLines.Count) * LineHeight) + 2);
  ACanvas.Brush.Color := RGB(231, 242, 255);
  ACanvas.FillRect(HighlightRect);

  ACanvas.Font.Style := [fsBold];
  ACanvas.Font.Color := RGB(25, 61, 122);
  for I := 0 to FMatchLines.Count - 1 do
  begin
    ACanvas.TextOut(FTextLeft, ATop, FMatchLines[I]);
    Inc(ATop, LineHeight);
  end;

  ACanvas.Font.Style := [];
  ACanvas.Font.Color := RGB(110, 117, 129);
  Inc(ATop, cPanelSpacing);

  if FData.Expanded then
  begin
    for I := 0 to FBelowLines.Count - 1 do
    begin
      ACanvas.TextOut(FTextLeft, ATop, FBelowLines[I]);
      Inc(ATop, LineHeight);
    end;
  end;
end;

procedure TMatchPanel.DrawHint(ACanvas: TCanvas; var ATop: Integer);
var
  HintText: string;
begin
  if FData.Expanded then
    HintText := 'Click to collapse context'
  else
    HintText := 'Click to show surrounding lines';

  FMeasureBitmap.Canvas.Font.Name := 'Segoe UI';
  FMeasureBitmap.Canvas.Font.Size := cMetaFontSize;
  FMeasureBitmap.Canvas.Font.Style := [];
  ACanvas.Font.Name := 'Segoe UI';
  ACanvas.Font.Size := cMetaFontSize;
  ACanvas.Font.Style := [];
  ACanvas.Font.Color := RGB(90, 107, 129);
  ACanvas.TextOut(FTextLeft, ATop, HintText);
end;

procedure TMatchPanel.Paint;
var
  CurrentTop: Integer;
begin
  inherited;
  DrawBackground(Canvas);
  CurrentTop := cPanelPadding;
  DrawHeader(Canvas, CurrentTop);
  DrawContext(Canvas, CurrentTop);
  DrawHint(Canvas, CurrentTop);
end;

procedure TMatchPanel.Resize;
begin
  inherited;
end;

procedure TMatchPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: Integer);
begin
  inherited;
  if Button <> mbLeft then
    Exit;

  FData.Expanded := not FData.Expanded;
  if Assigned(FOnToggle) then
    FOnToggle(Self)
  else
  begin
    UpdateLayout;
    Invalidate;
  end;
end;

procedure TMatchPanel.RecalculateLayout;
begin
  UpdateLayout;
end;

{ TMatchesDisplay }

constructor TMatchesDisplay.Create(AOwner: TComponent; AScrollBox: TScrollBox);
begin
  FMatches := TMatchesList.Create(AOwner);
  FScrollBox := AScrollBox;
  FLastContentWidth := 0;
  if FScrollBox <> nil then
  begin
    FScrollBox.OnResize := ScrollBoxResize;
    FLastContentWidth := GetContentWidth;
  end;
end;

destructor TMatchesDisplay.Destroy;
begin
  FMatches.Free;
  inherited;
end;

procedure TMatchesDisplay.SetScrollBox(AScrollBox: TScrollBox);
begin
  FScrollBox := AScrollBox;
  if FScrollBox <> nil then
  begin
    FScrollBox.OnResize := ScrollBoxResize;
    FLastContentWidth := GetContentWidth;
  end;
  RelayoutPanels(True);
end;

procedure TMatchesDisplay.ClearBrowser;
var
  I: Integer;
begin
  FMatches.Clear;

  if FScrollBox = nil then
    Exit;

  for I := FScrollBox.ControlCount - 1 downto 0 do
    FScrollBox.Controls[I].Free;
  UpdateScrollRange;
end;

procedure TMatchesDisplay.AddMatch(const AData: TMatchesData);
begin
  FMatches.Add(AData);
  AddPanelForMatch(AData);
end;

procedure TMatchesDisplay.AddMatches(const AData: TObjectList<TMatchesData>);
var
  Item: TMatchesData;
  PreservePos: Integer;
begin
  if AData = nil then
    Exit;

  PreservePos := 0;
  if FScrollBox <> nil then
    PreservePos := FScrollBox.VertScrollBar.Position;

  if FScrollBox <> nil then
    FScrollBox.DisableAlign;
  try
    for Item in AData do
      AddMatch(Item);
  finally
    if FScrollBox <> nil then
      FScrollBox.EnableAlign;
    UpdateScrollRange;
    if FScrollBox <> nil then
    begin
      FScrollBox.Realign;
      FScrollBox.VertScrollBar.Position := PreservePos;
    end;
  end;
end;

procedure TMatchesDisplay.MatchPanelToggled(Sender: TObject);
var
  Panel: TMatchPanel;
  PreviousHeight: Integer;
  DeltaHeight: Integer;
  PreservePos: Integer;
begin
  if not (Sender is TMatchPanel) then
    Exit;

  FScrollBox.DisableAlign;
  try
    Panel := TMatchPanel(Sender);
    PreviousHeight := Panel.Height;
    PreservePos := 0;
    if FScrollBox <> nil then
      PreservePos := FScrollBox.VertScrollBar.Position;

    Panel.RecalculateLayout;
    DeltaHeight := Panel.Height - PreviousHeight;
    if DeltaHeight <> 0 then
      RelayoutFromPanel(Panel, DeltaHeight);

    Panel.Invalidate;
    if FScrollBox <> nil then
      FScrollBox.VertScrollBar.Position := PreservePos;
  finally
    FScrollBox.EnableAlign;
  end;
end;

procedure TMatchesDisplay.ScrollBoxResize(Sender: TObject);
var
  NewWidth: Integer;
begin
  NewWidth := GetContentWidth;
  if NewWidth = FLastContentWidth then
    Exit;

  FScrollBox.DisableAlign;
  try
    FLastContentWidth := NewWidth;
    if FMatches.Count > 400 then
      RelayoutPanels(False)
    else
      RelayoutPanels(True);
  finally
    FScrollBox.EnableAlign;
  end;
end;

function TMatchesDisplay.GetContentWidth: Integer;
begin
  if FScrollBox = nil then
    Exit(240);
  Result := Max(240, FScrollBox.ClientWidth - (cPanelMargin * 2));
end;

function TMatchesDisplay.GetNextPanelTop: Integer;
var
  LastCtrl: TControl;
begin
  Result := cPanelMargin;
  if (FScrollBox = nil) or (FScrollBox.ControlCount = 0) then
    Exit;

  LastCtrl := FScrollBox.Controls[FScrollBox.ControlCount - 1];
  Result := LastCtrl.Top + LastCtrl.Height + cPanelSpacing;
end;

procedure TMatchesDisplay.UpdateScrollRange;
var
  LastCtrl: TControl;
  ContentBottom: Integer;
begin
  if FScrollBox = nil then
    Exit;

  if FScrollBox.ControlCount = 0 then
    ContentBottom := cPanelMargin
  else
  begin
    LastCtrl := FScrollBox.Controls[FScrollBox.ControlCount - 1];
    ContentBottom := LastCtrl.Top + LastCtrl.Height + cPanelMargin;
  end;

  FScrollBox.VertScrollBar.Range := ContentBottom;
end;

procedure TMatchesDisplay.AddPanelForMatch(const AData: TMatchesData);
var
  Panel: TMatchPanel;
  ContentWidth: Integer;
  PanelTop: Integer;
begin
  if FScrollBox = nil then
    Exit;

  ContentWidth := GetContentWidth;
  PanelTop := GetNextPanelTop;

  Panel := TMatchPanel.Create(FScrollBox, AData);
  Panel.Parent := FScrollBox;
  Panel.OnToggle := MatchPanelToggled;
  Panel.SetBounds(cPanelMargin, PanelTop, ContentWidth, Panel.Height);
  Panel.RecalculateLayout;
  Panel.SetBounds(cPanelMargin, PanelTop, ContentWidth, Panel.Height);

  UpdateScrollRange;
end;

procedure TMatchesDisplay.RelayoutPanels(const ARecalculateLayout: Boolean);
var
  I: Integer;
  CurrentTop: Integer;
  ContentWidth: Integer;
  MatchPanel: TMatchPanel;
begin
  if (FScrollBox = nil) or FLayoutUpdating then
    Exit;

  FLayoutUpdating := True;
  FScrollBox.DisableAlign;
  try
    CurrentTop := cPanelMargin;
    ContentWidth := GetContentWidth;
    for I := 0 to FScrollBox.ControlCount - 1 do
    begin
      if FScrollBox.Controls[I] is TMatchPanel then
      begin
        MatchPanel := TMatchPanel(FScrollBox.Controls[I]);
        MatchPanel.SetBounds(cPanelMargin, CurrentTop, ContentWidth, MatchPanel.Height);
        if ARecalculateLayout then
          MatchPanel.RecalculateLayout;
        MatchPanel.SetBounds(cPanelMargin, CurrentTop, ContentWidth, MatchPanel.Height);
        Inc(CurrentTop, MatchPanel.Height + cPanelSpacing);
      end;
    end;
  finally
    FScrollBox.EnableAlign;
    FLayoutUpdating := False;
  end;

  UpdateScrollRange;
  FScrollBox.Realign;
  FScrollBox.Invalidate;
end;

procedure TMatchesDisplay.RelayoutFromPanel(APanel: TMatchPanel; const ADeltaHeight: Integer);
var
  I: Integer;
  CurrentControl: TControl;
begin
  if (FScrollBox = nil) or (ADeltaHeight = 0) then
    Exit;

  FScrollBox.DisableAlign;
  try
    for I := 0 to FScrollBox.ControlCount - 1 do
    begin
      CurrentControl := FScrollBox.Controls[I];
      if CurrentControl.Top > APanel.Top then
        CurrentControl.Top := CurrentControl.Top + ADeltaHeight;
    end;
  finally
    FScrollBox.EnableAlign;
  end;

  UpdateScrollRange;
  FScrollBox.Realign;
  FScrollBox.Invalidate;
end;

function TMatchesDisplay.GetScrollBox: TScrollBox;
begin
  Result := FScrollBox;
end;

end.
